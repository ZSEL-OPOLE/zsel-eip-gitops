################################################################################
# Generate Secure User Passwords
# 
# Description: Generate secure random passwords for user accounts
# Version: 1.0
# Date: 2025-11-25
# 
# Features:
# - CSPRNG-based password generation
# - Configurable length and complexity
# - Batch generation from CSV
# - Integration with 1Password/Bitwarden
# - Export to encrypted file
################################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$InputCSV = ".\data\users.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = ".\data\user-passwords-$(Get-Date -Format 'yyyyMMdd').txt",
    
    [Parameter(Mandatory=$false)]
    [int]$PasswordLength = 16,
    
    [Parameter(Mandatory=$false)]
    [switch]$Export1Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportBitwarden,
    
    [Parameter(Mandatory=$false)]
    [switch]$EncryptOutput
)

################################################################################
# Configuration
################################################################################

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Password complexity requirements
$MinUpperCase = 2
$MinLowerCase = 2
$MinDigits = 2
$MinSpecialChars = 2

# Character sets
$UpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$LowerCase = "abcdefghijklmnopqrstuvwxyz"
$Digits = "0123456789"
$SpecialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"

# Statistics
$TotalUsers = 0
$SuccessCount = 0
$ErrorCount = 0

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

function Generate-SecurePassword {
    param(
        [Parameter(Mandatory=$false)]
        [int]$Length = 16
    )
    
    # Ensure minimum requirements can be met
    $minLength = $MinUpperCase + $MinLowerCase + $MinDigits + $MinSpecialChars
    if ($Length -lt $minLength) {
        $Length = $minLength
    }
    
    # Initialize password array
    $passwordChars = @()
    
    # Add minimum required characters
    for ($i = 0; $i -lt $MinUpperCase; $i++) {
        $passwordChars += Get-RandomChar -CharSet $UpperCase
    }
    
    for ($i = 0; $i -lt $MinLowerCase; $i++) {
        $passwordChars += Get-RandomChar -CharSet $LowerCase
    }
    
    for ($i = 0; $i -lt $MinDigits; $i++) {
        $passwordChars += Get-RandomChar -CharSet $Digits
    }
    
    for ($i = 0; $i -lt $MinSpecialChars; $i++) {
        $passwordChars += Get-RandomChar -CharSet $SpecialChars
    }
    
    # Fill remaining length with random characters from all sets
    $allChars = $UpperCase + $LowerCase + $Digits + $SpecialChars
    $remaining = $Length - $passwordChars.Count
    
    for ($i = 0; $i -lt $remaining; $i++) {
        $passwordChars += Get-RandomChar -CharSet $allChars
    }
    
    # Shuffle array using Fisher-Yates algorithm with CSPRNG
    for ($i = $passwordChars.Count - 1; $i -gt 0; $i--) {
        $j = Get-SecureRandom -Max ($i + 1)
        $temp = $passwordChars[$i]
        $passwordChars[$i] = $passwordChars[$j]
        $passwordChars[$j] = $temp
    }
    
    return -join $passwordChars
}

function Get-RandomChar {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CharSet
    )
    
    $index = Get-SecureRandom -Max $CharSet.Length
    return $CharSet[$index]
}

function Get-SecureRandom {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Max
    )
    
    # Use RNGCryptoServiceProvider for cryptographically secure random numbers
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] 4
    $rng.GetBytes($bytes)
    $rng.Dispose()
    
    $randomNumber = [System.BitConverter]::ToUInt32($bytes, 0)
    return $randomNumber % $Max
}

function Test-PasswordComplexity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Password
    )
    
    $hasUpper = $Password -cmatch '[A-Z]'
    $hasLower = $Password -cmatch '[a-z]'
    $hasDigit = $Password -match '\d'
    $hasSpecial = $Password -match '[^A-Za-z0-9]'
    
    $upperCount = ($Password.ToCharArray() | Where-Object { $_ -cmatch '[A-Z]' }).Count
    $lowerCount = ($Password.ToCharArray() | Where-Object { $_ -cmatch '[a-z]' }).Count
    $digitCount = ($Password.ToCharArray() | Where-Object { $_ -match '\d' }).Count
    $specialCount = ($Password.ToCharArray() | Where-Object { $_ -match '[^A-Za-z0-9]' }).Count
    
    return @{
        IsValid = ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and
                   $upperCount -ge $MinUpperCase -and $lowerCount -ge $MinLowerCase -and
                   $digitCount -ge $MinDigits -and $specialCount -ge $MinSpecialChars)
        UpperCount = $upperCount
        LowerCount = $lowerCount
        DigitCount = $digitCount
        SpecialCount = $specialCount
        Length = $Password.Length
    }
}

function Export-To1Password {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$Password,
        
        [Parameter(Mandatory=$false)]
        [string]$Email,
        
        [Parameter(Mandatory=$false)]
        [string]$Role,
        
        [Parameter(Mandatory=$false)]
        [string]$Class
    )
    
    # Check if 1Password CLI is installed
    if (-not (Get-Command "op" -ErrorAction SilentlyContinue)) {
        Write-Log "1Password CLI (op) not found. Skipping 1Password export." -Level WARNING
        return $false
    }
    
    try {
        $title = "ZSEL-User-$Username"
        $vault = "ZSEL-Production"
        
        # Create item in 1Password
        $opItem = @{
            title = $title
            vault = $vault
            category = "login"
            fields = @(
                @{ label = "username"; value = $Username }
                @{ label = "password"; value = $Password; type = "concealed" }
                @{ label = "email"; value = $Email }
                @{ label = "role"; value = $Role }
                @{ label = "class"; value = $Class }
                @{ label = "domain"; value = "zsel.opole.pl" }
            )
        }
        
        $opJson = $opItem | ConvertTo-Json -Depth 10
        $opJson | op item create --vault=$vault
        
        Write-Log "  Exported to 1Password: $title" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "  Failed to export to 1Password: $_" -Level ERROR
        return $false
    }
}

function Export-ToBitwarden {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$Password,
        
        [Parameter(Mandatory=$false)]
        [string]$Email,
        
        [Parameter(Mandatory=$false)]
        [string]$Role,
        
        [Parameter(Mandatory=$false)]
        [string]$Class
    )
    
    # Check if Bitwarden CLI is installed
    if (-not (Get-Command "bw" -ErrorAction SilentlyContinue)) {
        Write-Log "Bitwarden CLI (bw) not found. Skipping Bitwarden export." -Level WARNING
        return $false
    }
    
    try {
        $name = "ZSEL-User-$Username"
        
        # Create item template
        $bwItem = @{
            organizationId = $null
            folderId = $null
            type = 1  # Login type
            name = $name
            notes = "Role: $Role`nClass: $Class"
            favorite = $false
            login = @{
                username = $Username
                password = $Password
                totp = $null
            }
            fields = @(
                @{ name = "Email"; value = $Email; type = 0 }
                @{ name = "Role"; value = $Role; type = 0 }
                @{ name = "Class"; value = $Class; type = 0 }
                @{ name = "Domain"; value = "zsel.opole.pl"; type = 0 }
            )
        }
        
        $bwJson = $bwItem | ConvertTo-Json -Depth 10
        $encodedJson = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bwJson))
        bw create item $encodedJson | Out-Null
        
        Write-Log "  Exported to Bitwarden: $name" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "  Failed to export to Bitwarden: $_" -Level ERROR
        return $false
    }
}

function Process-Users {
    Write-Log "Reading users from: $InputCSV" -Level INFO
    
    if (-not (Test-Path $InputCSV)) {
        Write-Log "CSV file not found: $InputCSV" -Level ERROR
        exit 1
    }
    
    # Create output directory
    $outputDir = Split-Path -Parent $OutputFile
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Read CSV and filter out comments
    $users = Import-Csv -Path $InputCSV | Where-Object { 
        $_.username -and 
        $_.username -notmatch '^#' -and 
        $_.username.Trim() -ne '' 
    }
    $script:TotalUsers = $users.Count
    
    Write-Log "Processing $TotalUsers users..." -Level INFO
    
    # Initialize output file
    "# User Passwords - Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $OutputFile -Encoding UTF8
    "# Format: username:password" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    "" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    
    # Process each user
    $progress = 0
    foreach ($user in $users) {
        $progress++
        Write-Progress -Activity "Generating passwords" -Status "Processing $($user.username)" -PercentComplete (($progress / $TotalUsers) * 100)
        
        try {
            Write-Log "[$progress/$TotalUsers] Processing: $($user.username) ($($user.firstname) $($user.lastname))" -Level INFO
            
            # Generate password
            $password = Generate-SecurePassword -Length $PasswordLength
            
            # Verify complexity
            $complexity = Test-PasswordComplexity -Password $password
            
            if (-not $complexity.IsValid) {
                Write-Log "  Generated password does not meet complexity requirements. Regenerating..." -Level WARNING
                $password = Generate-SecurePassword -Length $PasswordLength
                $complexity = Test-PasswordComplexity -Password $password
            }
            
            Write-Log "  Password generated: Length=$($complexity.Length), Upper=$($complexity.UpperCount), Lower=$($complexity.LowerCount), Digits=$($complexity.DigitCount), Special=$($complexity.SpecialCount)" -Level INFO
            
            # Save to file
            "$($user.username):$password" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
            
            # Export to password managers
            if ($Export1Password) {
                Export-To1Password -Username $user.username -Password $password -Email $user.email -Role $user.role -Class $user.class
            }
            
            if ($ExportBitwarden) {
                Export-ToBitwarden -Username $user.username -Password $password -Email $user.email -Role $user.role -Class $user.class
            }
            
            $script:SuccessCount++
            Write-Log "  ✓ Success" -Level SUCCESS
        }
        catch {
            $script:ErrorCount++
            Write-Log "  ✗ Error: $_" -Level ERROR
        }
    }
    
    Write-Progress -Activity "Generating passwords" -Completed
}

function Encrypt-OutputFile {
    Write-Log "Encrypting output file..." -Level INFO
    
    try {
        # Check if GPG is available
        if (-not (Get-Command "gpg" -ErrorAction SilentlyContinue)) {
            Write-Log "GPG not found. Install GPG4Win or GnuPG to encrypt output." -Level WARNING
            return
        }
        
        # Encrypt using AES256
        $encryptedFile = "$OutputFile.gpg"
        gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase-fd 0 --output $encryptedFile $OutputFile
        
        if (Test-Path $encryptedFile) {
            Write-Log "File encrypted: $encryptedFile" -Level SUCCESS
            
            # Securely delete plaintext file (PowerShell equivalent of shred)
            $bytes = New-Object byte[] (Get-Item $OutputFile).Length
            $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
            
            for ($i = 0; $i -lt 10; $i++) {
                $rng.GetBytes($bytes)
                [System.IO.File]::WriteAllBytes($OutputFile, $bytes)
            }
            
            $rng.Dispose()
            Remove-Item -Path $OutputFile -Force
            
            Write-Log "Plaintext file securely deleted" -Level SUCCESS
        }
    }
    catch {
        Write-Log "Failed to encrypt file: $_" -Level ERROR
    }
}

function Show-Summary {
    Write-Log "" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "Password Generation Summary" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "Total users:    $TotalUsers" -Level INFO
    Write-Log "Success:        $SuccessCount" -Level SUCCESS
    Write-Log "Errors:         $ErrorCount" -Level ERROR
    Write-Log "Output file:    $OutputFile" -Level INFO
    
    if ($EncryptOutput -and (Test-Path "$OutputFile.gpg")) {
        Write-Log "Encrypted file: $OutputFile.gpg" -Level SUCCESS
    }
    
    Write-Log "========================================" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "Next Steps:" -Level INFO
    Write-Log "1. Review passwords file (encrypted)" -Level INFO
    Write-Log "2. Import users to FreeIPA: ./freeipa-import-users.sh" -Level INFO
    Write-Log "3. Distribute passwords to users securely" -Level INFO
    Write-Log "4. Users should change password on first login" -Level INFO
    Write-Log "========================================" -Level INFO
}

################################################################################
# Main
################################################################################

Write-Log "========================================" -Level INFO
Write-Log "Secure Password Generator" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Password Length: $PasswordLength" -Level INFO
Write-Log "Minimum Requirements:" -Level INFO
Write-Log "  - Uppercase: $MinUpperCase" -Level INFO
Write-Log "  - Lowercase: $MinLowerCase" -Level INFO
Write-Log "  - Digits: $MinDigits" -Level INFO
Write-Log "  - Special: $MinSpecialChars" -Level INFO
Write-Log "" -Level INFO

Process-Users

if ($EncryptOutput) {
    Encrypt-OutputFile
}

Show-Summary

exit ($ErrorCount -gt 0 ? 1 : 0)
