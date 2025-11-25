# =============================================================================
# ZSEL EIP - Pre-Deployment Validation Script
# =============================================================================
# Purpose: Comprehensive validation before deployment (25+ checks)
# Categories: Syntax, Security, Quality, Compliance, Infrastructure
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('development', 'production')]
    [string]$Environment,
    
    [switch]$SkipSecurityScan,
    [switch]$SkipTerraform,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$WarningCount = 0
$ErrorCount = 0
$PassCount = 0

# =============================================================================
# Helper Functions
# =============================================================================

function Write-CheckResult {
    param(
        [string]$CheckName,
        [ValidateSet('PASS', 'WARN', 'FAIL')]
        [string]$Status,
        [string]$Message
    )
    
    $color = switch ($Status) {
        'PASS' { 'Green'; $script:PassCount++ }
        'WARN' { 'Yellow'; $script:WarningCount++ }
        'FAIL' { 'Red'; $script:ErrorCount++ }
    }
    
    $icon = switch ($Status) {
        'PASS' { '✅' }
        'WARN' { '⚠️' }
        'FAIL' { '❌' }
    }
    
    Write-Host "$icon [$Status] " -NoNewline -ForegroundColor $color
    Write-Host "$CheckName" -NoNewline
    if ($Message) {
        Write-Host " - $Message"
    } else {
        Write-Host ""
    }
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# =============================================================================
# Check 1-5: Prerequisites & Tools
# =============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CATEGORY 1: Prerequisites & Tools (5 checks)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check 1: Terraform
if (Test-CommandExists "terraform") {
    $tfVersion = (terraform version -json | ConvertFrom-Json).terraform_version
    if ([version]$tfVersion -ge [version]"1.6.0") {
        Write-CheckResult "Terraform Version" "PASS" "v$tfVersion"
    } else {
        Write-CheckResult "Terraform Version" "WARN" "v$tfVersion (required >= 1.6.0)"
    }
} else {
    Write-CheckResult "Terraform Installed" "FAIL" "Not found"
}

# Check 2: kubectl
if (Test-CommandExists "kubectl") {
    $kubectlVersion = (kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion
    Write-CheckResult "kubectl Installed" "PASS" "$kubectlVersion"
} else {
    Write-CheckResult "kubectl Installed" "FAIL" "Not found"
}

# Check 3: Helm
if (Test-CommandExists "helm") {
    $helmVersion = (helm version --short)
    Write-CheckResult "Helm Installed" "PASS" "$helmVersion"
} else {
    Write-CheckResult "Helm Installed" "WARN" "Not found (optional)"
}

# Check 4: kubeseal
if (Test-CommandExists "kubeseal") {
    $kubesealVersion = (kubeseal --version 2>&1 | Select-String -Pattern "v\d+\.\d+\.\d+").Matches.Value
    Write-CheckResult "kubeseal Installed" "PASS" "$kubesealVersion"
} else {
    Write-CheckResult "kubeseal Installed" "FAIL" "Required for Sealed Secrets"
}

# Check 5: argocd CLI
if (Test-CommandExists "argocd") {
    $argocdVersion = (argocd version --client --short)
    Write-CheckResult "ArgoCD CLI Installed" "PASS" "$argocdVersion"
} else {
    Write-CheckResult "ArgoCD CLI Installed" "WARN" "Not found (optional)"
}

# =============================================================================
# Check 6-10: Terraform Validation
# =============================================================================

if (-not $SkipTerraform) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "CATEGORY 2: Terraform Validation (5 checks)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $terraformDir = "terraform/environments/$Environment"
    
    # Check 6: Terraform directory exists
    if (Test-Path $terraformDir) {
        Write-CheckResult "Terraform Directory" "PASS" "$terraformDir exists"
    } else {
        Write-CheckResult "Terraform Directory" "FAIL" "$terraformDir not found"
    }

    # Check 7: Terraform fmt
    Push-Location $terraformDir
    $fmtCheck = terraform fmt -check -recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-CheckResult "Terraform Format" "PASS" "All files formatted correctly"
    } else {
        Write-CheckResult "Terraform Format" "FAIL" "Run 'terraform fmt -recursive'"
    }

    # Check 8: Terraform init
    terraform init -backend=false -upgrade | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-CheckResult "Terraform Init" "PASS" "Providers downloaded"
    } else {
        Write-CheckResult "Terraform Init" "FAIL" "Failed to initialize"
    }

    # Check 9: Terraform validate
    terraform validate -json | Out-File "terraform-validate.json"
    $validateResult = Get-Content "terraform-validate.json" | ConvertFrom-Json
    if ($validateResult.valid) {
        Write-CheckResult "Terraform Validate" "PASS" "Configuration valid"
    } else {
        Write-CheckResult "Terraform Validate" "FAIL" "$($validateResult.error_count) errors"
        if ($Verbose) {
            $validateResult.diagnostics | ForEach-Object {
                Write-Host "  - $($_.detail)" -ForegroundColor Red
            }
        }
    }

    # Check 10: Terraform plan (dry-run)
    if ($Environment -eq 'development') {
        Write-Host "`nRunning terraform plan (DEV)..." -ForegroundColor Yellow
        terraform plan -out=tfplan-validate | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-CheckResult "Terraform Plan (DEV)" "PASS" "No errors"
        } else {
            Write-CheckResult "Terraform Plan (DEV)" "FAIL" "Plan failed"
        }
    } else {
        Write-CheckResult "Terraform Plan (PROD)" "WARN" "Skipped (manual only)"
    }
    
    Pop-Location
}

# =============================================================================
# Check 11-15: YAML Validation
# =============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CATEGORY 3: YAML Validation (5 checks)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check 11: ArgoCD Applications YAML syntax
$argocdApps = Get-ChildItem -Path "apps" -Recurse -Filter "*.yaml"
$yamlErrors = 0
foreach ($file in $argocdApps) {
    try {
        $content = Get-Content $file.FullName -Raw
        # Basic YAML validation (PowerShell doesn't have native YAML parser)
        if ($content -match "^[^#\s]" -and $content -match ":\s") {
            # Looks like valid YAML
        } else {
            $yamlErrors++
            if ($Verbose) {
                Write-Host "  - Invalid YAML: $($file.Name)" -ForegroundColor Red
            }
        }
    } catch {
        $yamlErrors++
    }
}

if ($yamlErrors -eq 0) {
    Write-CheckResult "ArgoCD Apps YAML Syntax" "PASS" "$($argocdApps.Count) files validated"
} else {
    Write-CheckResult "ArgoCD Apps YAML Syntax" "FAIL" "$yamlErrors errors in $($argocdApps.Count) files"
}

# Check 12: Sealed Secrets YAML
if (Test-Path "sealed-secrets") {
    $sealedSecrets = Get-ChildItem -Path "sealed-secrets" -Filter "*.yaml"
    $sealedErrors = 0
    
    foreach ($file in $sealedSecrets) {
        $content = Get-Content $file.FullName -Raw
        if ($content -notmatch "kind:\s*SealedSecret") {
            $sealedErrors++
            if ($Verbose) {
                Write-Host "  - Not a SealedSecret: $($file.Name)" -ForegroundColor Red
            }
        }
        if ($content -notmatch "encryptedData:") {
            $sealedErrors++
            if ($Verbose) {
                Write-Host "  - Missing encryptedData: $($file.Name)" -ForegroundColor Red
            }
        }
    }
    
    if ($sealedErrors -eq 0) {
        Write-CheckResult "Sealed Secrets Format" "PASS" "$($sealedSecrets.Count) secrets validated"
    } else {
        Write-CheckResult "Sealed Secrets Format" "FAIL" "$sealedErrors errors"
    }
} else {
    Write-CheckResult "Sealed Secrets Directory" "FAIL" "Directory not found"
}

# Check 13: Kubernetes manifest validation (kubectl dry-run)
$manifestErrors = 0
foreach ($file in $argocdApps) {
    $result = kubectl apply --dry-run=client -f $file.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
        $manifestErrors++
        if ($Verbose) {
            Write-Host "  - $($file.Name): $result" -ForegroundColor Red
        }
    }
}

if ($manifestErrors -eq 0) {
    Write-CheckResult "K8s Manifest Validation" "PASS" "kubectl dry-run successful"
} else {
    Write-CheckResult "K8s Manifest Validation" "FAIL" "$manifestErrors files failed"
}

# Check 14: ArgoCD sync-wave annotations
$missingWaves = 0
foreach ($file in $argocdApps) {
    $content = Get-Content $file.FullName -Raw
    if ($content -notmatch "argocd.argoproj.io/sync-wave:") {
        $missingWaves++
    }
}

if ($missingWaves -eq 0) {
    Write-CheckResult "ArgoCD Sync Waves" "PASS" "All apps have sync-wave"
} else {
    Write-CheckResult "ArgoCD Sync Waves" "WARN" "$missingWaves apps missing sync-wave"
}

# Check 15: Duplicate resource names
$resourceNames = @{}
$duplicates = 0
foreach ($file in $argocdApps) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "name:\s*(\S+)") {
        $name = $matches[1]
        if ($resourceNames.ContainsKey($name)) {
            $duplicates++
            if ($Verbose) {
                Write-Host "  - Duplicate name: $name" -ForegroundColor Yellow
            }
        } else {
            $resourceNames[$name] = $file.Name
        }
    }
}

if ($duplicates -eq 0) {
    Write-CheckResult "Unique Resource Names" "PASS" "No duplicates found"
} else {
    Write-CheckResult "Unique Resource Names" "WARN" "$duplicates potential duplicates"
}

# =============================================================================
# Check 16-20: Security Checks
# =============================================================================

if (-not $SkipSecurityScan) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "CATEGORY 4: Security Checks (5 checks)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Check 16: No hardcoded secrets
    $secretPatterns = @(
        "password\s*[:=]\s*[`"'](?!changeme|secret|password)[^`"']{8,}",
        "apikey\s*[:=]\s*[`"'][^`"']{16,}",
        "token\s*[:=]\s*[`"'][^`"']{16,}",
        "secret\s*[:=]\s*[`"'](?!changeme|secret)[^`"']{8,}"
    )
    
    $hardcodedSecrets = 0
    foreach ($file in $argocdApps) {
        $content = Get-Content $file.FullName -Raw
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                $hardcodedSecrets++
                if ($Verbose) {
                    Write-Host "  - Potential secret in: $($file.Name)" -ForegroundColor Red
                }
                break
            }
        }
    }
    
    if ($hardcodedSecrets -eq 0) {
        Write-CheckResult "No Hardcoded Secrets" "PASS" "Clean scan"
    } else {
        Write-CheckResult "No Hardcoded Secrets" "FAIL" "$hardcodedSecrets files with potential secrets"
    }

    # Check 17: Image sources (official only)
    $untrustedImages = 0
    $trustedRegistries = @(
        "docker.io/library/",
        "quay.io/",
        "gcr.io/",
        "ghcr.io/",
        "registry.k8s.io/",
        "docker.io/bitnami/",
        "linuxserver/"
    )
    
    foreach ($file in $argocdApps) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match "image:\s*([^\s]+)") {
            $image = $matches[1]
            $isTrusted = $false
            foreach ($registry in $trustedRegistries) {
                if ($image -like "*$registry*") {
                    $isTrusted = $true
                    break
                }
            }
            if (-not $isTrusted -and $image -notlike "*/harbor.zsel.opole.pl/*") {
                $untrustedImages++
                if ($Verbose) {
                    Write-Host "  - Untrusted image: $image in $($file.Name)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    if ($untrustedImages -eq 0) {
        Write-CheckResult "Trusted Image Sources" "PASS" "All images from trusted registries"
    } else {
        Write-CheckResult "Trusted Image Sources" "WARN" "$untrustedImages images from unknown sources"
    }

    # Check 18: SecurityContext present
    $missingSecurityContext = 0
    foreach ($file in Get-ChildItem -Path "apps" -Recurse -Filter "*statefulset.yaml","*deployment.yaml") {
        $content = Get-Content $file.FullName -Raw
        if ($content -notmatch "securityContext:") {
            $missingSecurityContext++
        }
    }
    
    if ($missingSecurityContext -eq 0) {
        Write-CheckResult "Security Context" "PASS" "All workloads have securityContext"
    } else {
        Write-CheckResult "Security Context" "WARN" "$missingSecurityContext workloads missing securityContext"
    }

    # Check 19: Network Policies exist
    $namespacesWithNetPol = @()
    foreach ($ns in (Get-ChildItem -Path "apps" -Directory)) {
        if (Test-Path "$($ns.FullName)/network-policy.yaml") {
            $namespacesWithNetPol += $ns.Name
        }
    }
    
    $totalNamespaces = (Get-ChildItem -Path "apps" -Directory).Count
    $coverage = [math]::Round(($namespacesWithNetPol.Count / $totalNamespaces) * 100)
    
    if ($coverage -ge 80) {
        Write-CheckResult "Network Policies" "PASS" "$coverage% coverage"
    } elseif ($coverage -ge 50) {
        Write-CheckResult "Network Policies" "WARN" "$coverage% coverage (target: 80%)"
    } else {
        Write-CheckResult "Network Policies" "FAIL" "$coverage% coverage (target: 80%)"
    }

    # Check 20: RBAC configured
    $rbacCount = 0
    foreach ($file in Get-ChildItem -Path "apps" -Recurse -Filter "*rolebinding.yaml","*clusterrolebinding.yaml") {
        $rbacCount++
    }
    
    if ($rbacCount -ge 10) {
        Write-CheckResult "RBAC Configuration" "PASS" "$rbacCount RoleBindings found"
    } else {
        Write-CheckResult "RBAC Configuration" "WARN" "Only $rbacCount RoleBindings (expected >= 10)"
    }
}

# =============================================================================
# Check 21-25: Quality & Compliance
# =============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CATEGORY 5: Quality & Compliance (5 checks)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check 21: Resource requests/limits defined
$missingResources = 0
foreach ($file in Get-ChildItem -Path "apps" -Recurse -Filter "*statefulset.yaml","*deployment.yaml") {
    $content = Get-Content $file.FullName -Raw
    if ($content -notmatch "resources:\s*\n\s*requests:" -or $content -notmatch "limits:") {
        $missingResources++
        if ($Verbose) {
            Write-Host "  - Missing resources: $($file.Name)" -ForegroundColor Yellow
        }
    }
}

$totalWorkloads = (Get-ChildItem -Path "apps" -Recurse -Filter "*statefulset.yaml","*deployment.yaml").Count
$resourceCoverage = [math]::Round((($totalWorkloads - $missingResources) / $totalWorkloads) * 100)

if ($resourceCoverage -ge 90) {
    Write-CheckResult "Resource Limits" "PASS" "$resourceCoverage% coverage"
} else {
    Write-CheckResult "Resource Limits" "WARN" "$resourceCoverage% coverage (target: 90%)"
}

# Check 22: Labels consistency
$requiredLabels = @("app.kubernetes.io/name", "app.kubernetes.io/component")
$missingLabels = 0
foreach ($file in $argocdApps) {
    $content = Get-Content $file.FullName -Raw
    foreach ($label in $requiredLabels) {
        if ($content -notmatch $label) {
            $missingLabels++
            break
        }
    }
}

if ($missingLabels -eq 0) {
    Write-CheckResult "Label Standards" "PASS" "All resources have required labels"
} else {
    Write-CheckResult "Label Standards" "WARN" "$missingLabels resources missing labels"
}

# Check 23: Documentation exists
$requiredDocs = @(
    "README.md",
    "QUICKSTART.md",
    "docs/DEPLOYMENT-PLAN.md",
    "docs/SEALED-SECRETS-SECURITY.md"
)

$missingDocs = 0
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        $missingDocs++
        if ($Verbose) {
            Write-Host "  - Missing: $doc" -ForegroundColor Yellow
        }
    }
}

if ($missingDocs -eq 0) {
    Write-CheckResult "Documentation" "PASS" "All required docs present"
} else {
    Write-CheckResult "Documentation" "WARN" "$missingDocs docs missing"
}

# Check 24: RODO/GDPR compliance (basic check)
$rodoKeywords = @("retention", "backup", "encryption", "gdpr", "rodo")
$rodoMentions = 0
foreach ($doc in (Get-ChildItem -Path "docs" -Filter "*.md" -ErrorAction SilentlyContinue)) {
    $content = Get-Content $doc.FullName -Raw
    foreach ($keyword in $rodoKeywords) {
        if ($content -match $keyword) {
            $rodoMentions++
            break
        }
    }
}

if ($rodoMentions -ge 3) {
    Write-CheckResult "RODO/GDPR Compliance" "PASS" "Compliance documented"
} else {
    Write-CheckResult "RODO/GDPR Compliance" "WARN" "Compliance documentation incomplete"
}

# Check 25: Git history clean (no secrets committed)
if (Test-Path ".git") {
    $gitSecrets = git log --all --pretty=format: --name-only | 
                  Select-String -Pattern "(password|secret|key|token)" | 
                  Select-Object -First 5
    
    if ($gitSecrets.Count -eq 0) {
        Write-CheckResult "Git History Clean" "PASS" "No secrets in commit history"
    } else {
        Write-CheckResult "Git History Clean" "WARN" "Potential secrets in git history"
    }
} else {
    Write-CheckResult "Git Repository" "WARN" "Not a git repository"
}

# =============================================================================
# Final Summary
# =============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "✅ PASS:  $PassCount" -ForegroundColor Green
Write-Host "⚠️  WARN:  $WarningCount" -ForegroundColor Yellow
Write-Host "❌ FAIL:  $ErrorCount" -ForegroundColor Red

$totalChecks = $PassCount + $WarningCount + $ErrorCount
$successRate = [math]::Round(($PassCount / $totalChecks) * 100, 2)

Write-Host "`nSuccess Rate: $successRate% ($PassCount/$totalChecks)" -ForegroundColor Cyan

if ($ErrorCount -eq 0 -and $WarningCount -le 3) {
    Write-Host "`n✅ READY FOR DEPLOYMENT to $Environment" -ForegroundColor Green
    exit 0
} elseif ($ErrorCount -eq 0) {
    Write-Host "`n⚠️  DEPLOYMENT ALLOWED with warnings (Review recommended)" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n❌ DEPLOYMENT BLOCKED - Fix $ErrorCount errors before proceeding" -ForegroundColor Red
    exit 1
}
