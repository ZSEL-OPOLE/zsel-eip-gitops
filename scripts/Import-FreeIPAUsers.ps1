################################################################################
# Import FreeIPA Users - PowerShell Wrapper
# 
# Description: PowerShell wrapper for freeipa-import-users.sh bash script
# Version: 1.0
# Date: 2025-11-25
# 
# Prerequisites:
# - Git Bash installed
# - SSH access to FreeIPA server
# - kinit authentication completed (ipa-admin credentials)
################################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$CSVFile = ".\data\users.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$PasswordFile = ".\data\user-passwords-20251125.txt",
    
    [Parameter(Mandatory=$false)]
    [string]$FreeIPAServer = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$LocalExecution
)

$ErrorActionPreference = "Stop"

################################################################################
# Configuration
################################################################################

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
$BashScriptPath = ".\scripts\freeipa-import-users.sh"

################################################################################
# Functions
################################################################################

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level INFO
    
    # Check Git Bash
    if (-not (Test-Path $GitBashPath)) {
        Write-Log "Git Bash not found at: $GitBashPath" -Level ERROR
        Write-Log "Please install Git for Windows from: https://git-scm.com/download/win" -Level ERROR
        return $false
    }
    Write-Log "  ✓ Git Bash found" -Level SUCCESS
    
    # Check bash script
    if (-not (Test-Path $BashScriptPath)) {
        Write-Log "Bash script not found: $BashScriptPath" -Level ERROR
        return $false
    }
    Write-Log "  ✓ FreeIPA import script found" -Level SUCCESS
    
    # Check CSV file
    if (-not (Test-Path $CSVFile)) {
        Write-Log "CSV file not found: $CSVFile" -Level ERROR
        return $false
    }
    Write-Log "  ✓ Users CSV file found" -Level SUCCESS
    
    # Check password file
    if (-not (Test-Path $PasswordFile)) {
        Write-Log "Password file not found: $PasswordFile" -Level WARNING
        Write-Log "  Passwords will be generated during import" -Level WARNING
    } else {
        Write-Log "  ✓ Password file found" -Level SUCCESS
    }
    
    return $true
}

################################################################################
# Main Execution
################################################################################

Write-Log "========================================" -Level INFO
Write-Log "FreeIPA User Import - PowerShell Wrapper" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed!" -Level ERROR
    exit 1
}

Write-Log ""
Write-Log "========================================" -Level INFO
Write-Log "Import Configuration" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "CSV File:      $CSVFile" -Level INFO
Write-Log "Password File: $PasswordFile" -Level INFO
Write-Log "Dry Run:       $DryRun" -Level INFO
Write-Log "Local:         $LocalExecution" -Level INFO
Write-Log ""

# Convert Windows paths to Unix paths for Git Bash
$csvUnixPath = $CSVFile -replace '\\', '/' -replace 'C:', '/c'
$bashScriptUnixPath = $BashScriptPath -replace '\\', '/' -replace 'C:', '/c'

if ($LocalExecution) {
    Write-Log "========================================" -Level INFO
    Write-Log "LOCAL EXECUTION MODE" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "This requires FreeIPA client tools installed locally." -Level WARNING
    Write-Log "Make sure you have authenticated with: kinit admin" -Level WARNING
    Write-Log ""
    
    # Execute bash script locally
    $bashCommand = "bash '$bashScriptUnixPath' '$csvUnixPath'"
    if ($DryRun) {
        $bashCommand += " --dry-run"
    }
    
    Write-Log "Executing: $bashCommand" -Level INFO
    Write-Log ""
    
    try {
        & $GitBashPath -c $bashCommand
        $exitCode = $LASTEXITCODE
        
        Write-Log ""
        if ($exitCode -eq 0) {
            Write-Log "Import completed successfully!" -Level SUCCESS
        } else {
            Write-Log "Import failed with exit code: $exitCode" -Level ERROR
            exit $exitCode
        }
    } catch {
        Write-Log "Error executing bash script: $_" -Level ERROR
        exit 1
    }
    
} else {
    Write-Log "========================================" -Level INFO
    Write-Log "REMOTE EXECUTION MODE" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log ""
    
    if ([string]::IsNullOrEmpty($FreeIPAServer)) {
        Write-Log "Please provide FreeIPA server address:" -Level INFO
        Write-Log "Example: -FreeIPAServer 'root@freeipa.zsel.opole.pl'" -Level INFO
        Write-Log ""
        Write-Log "Or use local execution: -LocalExecution" -Level INFO
        Write-Log ""
        Write-Log "========================================" -Level INFO
        Write-Log "MANUAL EXECUTION INSTRUCTIONS" -Level INFO
        Write-Log "========================================" -Level INFO
        Write-Log ""
        Write-Log "1. Copy files to FreeIPA server:" -Level INFO
        Write-Log "   scp $CSVFile $BashScriptPath root@freeipa-server:/tmp/" -Level INFO
        Write-Log ""
        Write-Log "2. SSH to FreeIPA server:" -Level INFO
        Write-Log "   ssh root@freeipa-server" -Level INFO
        Write-Log ""
        Write-Log "3. Execute import:" -Level INFO
        Write-Log "   cd /tmp" -Level INFO
        Write-Log "   chmod +x freeipa-import-users.sh" -Level INFO
        Write-Log "   kinit admin" -Level INFO
        Write-Log "   ./freeipa-import-users.sh users.csv" -Level INFO
        Write-Log ""
        Write-Log "4. Review HTML report:" -Level INFO
        Write-Log "   The script will generate: freeipa-import-report-YYYYMMDD-HHMMSS.html" -Level INFO
        Write-Log ""
        exit 0
    }
    
    Write-Log "Remote execution to: $FreeIPAServer" -Level INFO
    Write-Log ""
    Write-Log "Steps:" -Level INFO
    Write-Log "1. Copying files to FreeIPA server..." -Level INFO
    
    # Copy files using SCP
    $scpCSV = "scp '$CSVFile' '${FreeIPAServer}:/tmp/users.csv'"
    $scpScript = "scp '$BashScriptPath' '${FreeIPAServer}:/tmp/freeipa-import-users.sh'"
    
    Write-Log "   $scpCSV" -Level INFO
    & $GitBashPath -c $scpCSV
    
    Write-Log "   $scpScript" -Level INFO
    & $GitBashPath -c $scpScript
    
    Write-Log "2. Executing import on FreeIPA server..." -Level INFO
    
    # Execute on remote server
    $sshCommand = "ssh '${FreeIPAServer}' 'cd /tmp && chmod +x freeipa-import-users.sh && kinit admin && ./freeipa-import-users.sh users.csv'"
    
    Write-Log "   $sshCommand" -Level INFO
    Write-Log ""
    
    & $GitBashPath -c $sshCommand
    
    $exitCode = $LASTEXITCODE
    
    Write-Log ""
    if ($exitCode -eq 0) {
        Write-Log "Remote import completed successfully!" -Level SUCCESS
        Write-Log "Download HTML report from server: /tmp/freeipa-import-report-*.html" -Level INFO
    } else {
        Write-Log "Remote import failed with exit code: $exitCode" -Level ERROR
        exit $exitCode
    }
}

Write-Log ""
Write-Log "========================================" -Level INFO
Write-Log "Next Steps" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "1. Review HTML import report" -Level INFO
Write-Log "2. Verify users: ipa user-find --all | wc -l" -Level INFO
Write-Log "3. Check group memberships: ipa group-show students" -Level INFO
Write-Log "4. Distribute passwords to users securely" -Level INFO
Write-Log "5. Users should change password on first login" -Level INFO
Write-Log "========================================" -Level INFO
