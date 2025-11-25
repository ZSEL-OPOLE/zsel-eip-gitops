# =============================================================================
# ZSEL EIP - Security Scanning Automation Script
# =============================================================================
# Purpose: Automated security scanning for Kubernetes manifests and Terraform
# Tools: Trivy, kubesec, kube-bench, OPA, custom validators
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('quick', 'full', 'pre-commit')]
    [string]$ScanType,
    
    [string]$OutputFormat = 'table',  # table, json, sarif
    [string]$OutputFile = '',
    [switch]$FailOnHigh,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScanResults = @{
    Trivy = @{ Pass = 0; Warn = 0; Fail = 0 }
    Kubesec = @{ Pass = 0; Warn = 0; Fail = 0 }
    KubeBench = @{ Pass = 0; Warn = 0; Fail = 0 }
    OPA = @{ Pass = 0; Warn = 0; Fail = 0 }
}

# =============================================================================
# Helper Functions
# =============================================================================

function Write-ScanHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-ScanResult {
    param(
        [string]$Scanner,
        [string]$Target,
        [int]$Critical,
        [int]$High,
        [int]$Medium,
        [int]$Low
    )
    
    if ($Critical -gt 0) {
        Write-Host "❌ CRITICAL: $Critical" -ForegroundColor Red -NoNewline
        $ScanResults[$Scanner].Fail++
    } elseif ($High -gt 0) {
        Write-Host "⚠️  HIGH: $High" -ForegroundColor Yellow -NoNewline
        $ScanResults[$Scanner].Warn++
    } else {
        Write-Host "✅ CLEAN" -ForegroundColor Green -NoNewline
        $ScanResults[$Scanner].Pass++
    }
    
    if ($Medium -gt 0 -or $Low -gt 0) {
        Write-Host " (Med: $Medium, Low: $Low)" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# =============================================================================
# Scan 1: Trivy - Container Image Scanning
# =============================================================================

function Invoke-TrivyScan {
    Write-ScanHeader "Trivy - Container Image Vulnerability Scanning"
    
    if (-not (Test-CommandExists "trivy")) {
        Write-Host "❌ Trivy not installed. Install: choco install trivy" -ForegroundColor Red
        return
    }
    
    # Scan container images in manifests
    $imageFiles = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml" | 
                  Select-String -Pattern "image:\s*([^\s]+)" | 
                  Select-Object -ExpandProperty Matches | 
                  ForEach-Object { $_.Groups[1].Value } | 
                  Sort-Object -Unique
    
    Write-Host "`nFound $($imageFiles.Count) unique container images`n" -ForegroundColor Yellow
    
    foreach ($image in $imageFiles) {
        Write-Host "Scanning: $image..." -NoNewline
        
        $trivyResult = trivy image --severity CRITICAL,HIGH --format json $image 2>&1 | ConvertFrom-Json
        
        $critical = ($trivyResult.Results.Vulnerabilities | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $high = ($trivyResult.Results.Vulnerabilities | Where-Object { $_.Severity -eq "HIGH" }).Count
        $medium = ($trivyResult.Results.Vulnerabilities | Where-Object { $_.Severity -eq "MEDIUM" }).Count
        $low = ($trivyResult.Results.Vulnerabilities | Where-Object { $_.Severity -eq "LOW" }).Count
        
        Write-Host " " -NoNewline
        Write-ScanResult -Scanner "Trivy" -Target $image -Critical $critical -High $high -Medium $medium -Low $low
        
        if ($Verbose -and $critical -gt 0) {
            $trivyResult.Results.Vulnerabilities | 
                Where-Object { $_.Severity -eq "CRITICAL" } | 
                ForEach-Object {
                    Write-Host "  ├─ $($_.VulnerabilityID): $($_.Title)" -ForegroundColor Red
                    Write-Host "  │  Fix: $($_.FixedVersion)" -ForegroundColor Gray
                }
        }
    }
    
    # Scan Kubernetes manifests (config scan)
    Write-Host "`nScanning Kubernetes configurations..." -ForegroundColor Yellow
    trivy config --severity CRITICAL,HIGH --format json apps/ | Out-File "trivy-config-scan.json"
    $configResult = Get-Content "trivy-config-scan.json" | ConvertFrom-Json
    
    $configCritical = ($configResult.Results.Misconfigurations | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $configHigh = ($configResult.Results.Misconfigurations | Where-Object { $_.Severity -eq "HIGH" }).Count
    
    Write-Host "Kubernetes manifests: " -NoNewline
    Write-ScanResult -Scanner "Trivy" -Target "K8s Configs" -Critical $configCritical -High $configHigh -Medium 0 -Low 0
}

# =============================================================================
# Scan 2: kubesec - Kubernetes Security Risk Analysis
# =============================================================================

function Invoke-KubesecScan {
    Write-ScanHeader "kubesec - Kubernetes Security Risk Analysis"
    
    if (-not (Test-CommandExists "docker")) {
        Write-Host "❌ Docker required for kubesec. Install Docker Desktop" -ForegroundColor Red
        return
    }
    
    $workloads = Get-ChildItem -Path "apps" -Recurse -Filter "*deployment.yaml","*statefulset.yaml","*daemonset.yaml"
    
    Write-Host "`nScanning $($workloads.Count) workload manifests`n" -ForegroundColor Yellow
    
    foreach ($file in $workloads) {
        $fileName = $file.Name
        Write-Host "Scanning: $fileName..." -NoNewline
        
        $kubesecResult = docker run --rm -v ${PWD}:/workspace kubesec/kubesec:v2 scan /workspace/$($file.FullName) | ConvertFrom-Json
        
        $score = $kubesecResult.score
        $critical = ($kubesecResult.scoring.critical | Measure-Object).Count
        $passed = ($kubesecResult.scoring.passed | Measure-Object).Count
        
        Write-Host " Score: $score/10 " -NoNewline
        
        if ($score -lt 6) {
            Write-Host "❌ FAIL" -ForegroundColor Red
            $ScanResults.Kubesec.Fail++
            
            if ($Verbose) {
                $kubesecResult.scoring.critical | ForEach-Object {
                    Write-Host "  ├─ $($_.selector): $($_.reason)" -ForegroundColor Red
                }
            }
        } elseif ($score -lt 8) {
            Write-Host "⚠️  WARN" -ForegroundColor Yellow
            $ScanResults.Kubesec.Warn++
        } else {
            Write-Host "✅ PASS" -ForegroundColor Green
            $ScanResults.Kubesec.Pass++
        }
    }
}

# =============================================================================
# Scan 3: kube-bench - CIS Kubernetes Benchmark
# =============================================================================

function Invoke-KubeBenchScan {
    Write-ScanHeader "kube-bench - CIS Kubernetes Benchmark"
    
    if (-not (Test-CommandExists "kubectl")) {
        Write-Host "❌ kubectl not installed. Cannot run kube-bench" -ForegroundColor Red
        return
    }
    
    # Check if cluster is accessible
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Kubernetes cluster not accessible. Skipping kube-bench" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nRunning CIS Kubernetes Benchmark...`n" -ForegroundColor Yellow
    
    # Run kube-bench as job in cluster
    kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml | Out-Null
    Start-Sleep -Seconds 30
    
    $benchResults = kubectl logs -l app=kube-bench -n default
    
    # Parse results
    $passCount = ($benchResults | Select-String -Pattern "\[PASS\]").Matches.Count
    $warnCount = ($benchResults | Select-String -Pattern "\[WARN\]").Matches.Count
    $failCount = ($benchResults | Select-String -Pattern "\[FAIL\]").Matches.Count
    
    Write-Host "Results:" -ForegroundColor Cyan
    Write-Host "  ✅ PASS: $passCount" -ForegroundColor Green
    Write-Host "  ⚠️  WARN: $warnCount" -ForegroundColor Yellow
    Write-Host "  ❌ FAIL: $failCount" -ForegroundColor Red
    
    if ($failCount -gt 0) {
        $ScanResults.KubeBench.Fail++
    } elseif ($warnCount -gt 5) {
        $ScanResults.KubeBench.Warn++
    } else {
        $ScanResults.KubeBench.Pass++
    }
    
    # Cleanup
    kubectl delete job kube-bench -n default | Out-Null
    
    # Save full report
    $benchResults | Out-File "kube-bench-report.txt"
    Write-Host "`nFull report saved to: kube-bench-report.txt" -ForegroundColor Gray
}

# =============================================================================
# Scan 4: OPA - Policy Validation
# =============================================================================

function Invoke-OPAScan {
    Write-ScanHeader "OPA - Open Policy Agent Policy Validation"
    
    if (-not (Test-Path "policies")) {
        Write-Host "⚠️  No policies directory found. Skipping OPA scan" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-CommandExists "docker")) {
        Write-Host "❌ Docker required for OPA. Install Docker Desktop" -ForegroundColor Red
        return
    }
    
    Write-Host "`nValidating OPA policies...`n" -ForegroundColor Yellow
    
    # Test policies
    $opaResult = docker run --rm -v ${PWD}:/workspace openpolicyagent/opa:latest test /workspace/policies/ -v 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ All OPA policies valid and tests passed" -ForegroundColor Green
        $ScanResults.OPA.Pass++
    } else {
        Write-Host "❌ OPA policy validation failed" -ForegroundColor Red
        $ScanResults.OPA.Fail++
        
        if ($Verbose) {
            Write-Host $opaResult -ForegroundColor Red
        }
    }
    
    # Validate manifests against policies
    Write-Host "`nValidating manifests against OPA policies...`n" -ForegroundColor Yellow
    
    $manifests = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml"
    $violations = 0
    
    foreach ($manifest in $manifests) {
        $opaCheck = docker run --rm -v ${PWD}:/workspace openpolicyagent/opa:latest `
                    eval -i json -d /workspace/policies /workspace/$($manifest.FullName) 2>&1
        
        if ($opaCheck -match "VIOLATION") {
            $violations++
            Write-Host "❌ Policy violation: $($manifest.Name)" -ForegroundColor Red
        }
    }
    
    if ($violations -eq 0) {
        Write-Host "✅ No policy violations found" -ForegroundColor Green
    } else {
        Write-Host "❌ Found $violations policy violations" -ForegroundColor Red
    }
}

# =============================================================================
# Scan 5: Custom Security Validators
# =============================================================================

function Invoke-CustomSecurityChecks {
    Write-ScanHeader "Custom Security Validators"
    
    $checks = @()
    
    # Check 1: No privileged containers
    Write-Host "`nChecking for privileged containers..." -NoNewline
    $privileged = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml" | 
                  Select-String -Pattern "privileged:\s*true"
    
    if ($privileged.Count -eq 0) {
        Write-Host " ✅ PASS" -ForegroundColor Green
    } else {
        Write-Host " ❌ FAIL ($($privileged.Count) found)" -ForegroundColor Red
        $checks += "privileged-containers"
    }
    
    # Check 2: No hostNetwork
    Write-Host "Checking for hostNetwork usage..." -NoNewline
    $hostNetwork = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml" | 
                   Select-String -Pattern "hostNetwork:\s*true"
    
    if ($hostNetwork.Count -eq 0) {
        Write-Host " ✅ PASS" -ForegroundColor Green
    } else {
        Write-Host " ⚠️  WARN ($($hostNetwork.Count) found)" -ForegroundColor Yellow
        $checks += "host-network"
    }
    
    # Check 3: No hostPath volumes (except for specific cases)
    Write-Host "Checking for hostPath volumes..." -NoNewline
    $hostPath = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml" | 
                Select-String -Pattern "hostPath:"
    
    if ($hostPath.Count -eq 0) {
        Write-Host " ✅ PASS" -ForegroundColor Green
    } else {
        Write-Host " ⚠️  WARN ($($hostPath.Count) found)" -ForegroundColor Yellow
        $checks += "host-path-volumes"
    }
    
    # Check 4: All images have tags (no :latest)
    Write-Host "Checking for :latest image tags..." -NoNewline
    $latestTags = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml" | 
                  Select-String -Pattern "image:.*:latest"
    
    if ($latestTags.Count -eq 0) {
        Write-Host " ✅ PASS" -ForegroundColor Green
    } else {
        Write-Host " ⚠️  WARN ($($latestTags.Count) found)" -ForegroundColor Yellow
        $checks += "latest-tags"
    }
    
    # Check 5: All services have NetworkPolicies
    Write-Host "Checking NetworkPolicy coverage..." -NoNewline
    $namespaces = Get-ChildItem -Path "apps" -Directory
    $withNetPol = 0
    
    foreach ($ns in $namespaces) {
        if (Test-Path "$($ns.FullName)/network-policy.yaml") {
            $withNetPol++
        }
    }
    
    $coverage = [math]::Round(($withNetPol / $namespaces.Count) * 100)
    
    if ($coverage -ge 80) {
        Write-Host " ✅ PASS ($coverage%)" -ForegroundColor Green
    } else {
        Write-Host " ❌ FAIL ($coverage% < 80%)" -ForegroundColor Red
        $checks += "network-policy-coverage"
    }
    
    return $checks
}

# =============================================================================
# Main Execution
# =============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║  ZSEL EIP Security Scanning Automation                      ║
║  Scan Type: $ScanType                                       ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

$startTime = Get-Date

# Execute scans based on scan type
switch ($ScanType) {
    'quick' {
        Invoke-TrivyScan
        Invoke-CustomSecurityChecks
    }
    'pre-commit' {
        Invoke-CustomSecurityChecks
        # Quick Trivy scan (config only)
        trivy config --severity CRITICAL --format json apps/ | Out-Null
    }
    'full' {
        Invoke-TrivyScan
        Invoke-KubesecScan
        Invoke-KubeBenchScan
        Invoke-OPAScan
        Invoke-CustomSecurityChecks
    }
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# =============================================================================
# Final Summary
# =============================================================================

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " SCAN SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nScanner Results:" -ForegroundColor White
$ScanResults.GetEnumerator() | ForEach-Object {
    $scanner = $_.Key
    $results = $_.Value
    $total = $results.Pass + $results.Warn + $results.Fail
    
    if ($total -gt 0) {
        Write-Host "  $scanner`: " -NoNewline
        Write-Host "✅ $($results.Pass) " -NoNewline -ForegroundColor Green
        Write-Host "⚠️  $($results.Warn) " -NoNewline -ForegroundColor Yellow
        Write-Host "❌ $($results.Fail)" -ForegroundColor Red
    }
}

Write-Host "`nDuration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Gray

# Determine overall status
$totalFails = ($ScanResults.Values | Measure-Object -Property Fail -Sum).Sum
$totalWarns = ($ScanResults.Values | Measure-Object -Property Warn -Sum).Sum

Write-Host "`n"
if ($totalFails -eq 0 -and $totalWarns -eq 0) {
    Write-Host "✅ ALL SCANS PASSED - Safe to deploy" -ForegroundColor Green
    exit 0
} elseif ($totalFails -eq 0) {
    Write-Host "⚠️  SCANS PASSED WITH WARNINGS - Review recommended" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "❌ SCANS FAILED - Fix $totalFails critical issues before deployment" -ForegroundColor Red
    if ($FailOnHigh) {
        exit 1
    } else {
        exit 0
    }
}
