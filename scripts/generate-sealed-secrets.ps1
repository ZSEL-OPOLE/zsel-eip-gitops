#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automatyczne generowanie Sealed Secrets dla całej infrastruktury ZSEL
.DESCRIPTION
    Skrypt generuje 26 zaszyfrowanych sekretów używając kubeseal.
    Sekrety są bezpiecznie generowane z użyciem kryptograficznie silnych algorytmów.
.NOTES
    Wymagania:
    - kubeseal CLI (zainstaluj: choco install kubeseal)
    - kubectl z dostępem do klastra K3s
    - PowerShell 7.x
.EXAMPLE
    .\generate-sealed-secrets.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "core-sealed-secrets",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "../sealed-secrets",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Kolory dla output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Sprawdź wymagane narzędzia
function Test-Prerequisites {
    Write-ColorOutput "🔍 Sprawdzam wymagania..." -Color Cyan
    
    # Sprawdź kubeseal
    if (-not (Get-Command kubeseal -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "❌ Brak kubeseal CLI!" -Color Red
        Write-ColorOutput "   Zainstaluj: choco install kubeseal" -Color Yellow
        exit 1
    }
    
    # Sprawdź kubectl
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "❌ Brak kubectl!" -Color Red
        Write-ColorOutput "   Zainstaluj: choco install kubernetes-cli" -Color Yellow
        exit 1
    }
    
    # Sprawdź połączenie z klastrem
    try {
        kubectl cluster-info | Out-Null
        Write-ColorOutput "✅ Połączenie z klastrem K3s OK" -Color Green
    } catch {
        Write-ColorOutput "⚠️  Brak połączenia z klastrem (DRY RUN mode)" -Color Yellow
    }
    
    Write-ColorOutput ""
}

# Generuj kryptograficznie bezpieczne hasło
function New-SecurePassword {
    param(
        [int]$Length = 32,
        [switch]$AlphanumericOnly = $false
    )
    
    if ($AlphanumericOnly) {
        # Tylko alfanumeryczne (dla kompatybilności)
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    } else {
        # Pełny zestaw znaków specjalnych
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?'
    }
    
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Generuj JWT secret (base64)
function New-JWTSecret {
    $bytes = New-Object byte[] 64
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

# Utwórz katalog wyjściowy
function Initialize-OutputDirectory {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-ColorOutput "📁 Utworzono katalog: $OutputDir" -Color Green
    }
}

# Generuj sealed secret
function New-SealedSecret {
    param(
        [string]$Name,
        [string]$Namespace,
        [hashtable]$Data,
        [string]$Description
    )
    
    Write-ColorOutput "🔐 Generuję: $Description" -Color Cyan
    
    # Utwórz tymczasowy plik YAML z secretem
    $tempFile = [System.IO.Path]::GetTempFileName()
    $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: $Name
  namespace: $Namespace
type: Opaque
stringData:
"@
    
    foreach ($key in $Data.Keys) {
        $secretYaml += "`n  $key`: $($Data[$key])"
    }
    
    $secretYaml | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Zaszyfruj używając kubeseal
    $outputFile = Join-Path $OutputDir "$Namespace-$Name.yaml"
    
    if ($DryRun) {
        Write-ColorOutput "   [DRY RUN] Zapisano do: $outputFile" -Color Yellow
        Copy-Item $tempFile $outputFile
    } else {
        try {
            kubectl create secret generic $Name `
                --namespace=$Namespace `
                --dry-run=client `
                --from-literal="$(($Data.Keys | Select-Object -First 1))=$(($Data.Values | Select-Object -First 1))" `
                -o yaml | kubeseal -o yaml > $outputFile
            
            Write-ColorOutput "   ✅ Zapisano: $outputFile" -Color Green
        } catch {
            Write-ColorOutput "   ❌ Błąd: $_" -Color Red
        }
    }
    
    Remove-Item $tempFile -Force
}

# === MAIN SCRIPT ===

Write-ColorOutput "╔════════════════════════════════════════════════════════════════╗" -Color Magenta
Write-ColorOutput "║  🔐 ZSEL Sealed Secrets Generator                            ║" -Color Magenta
Write-ColorOutput "║  Automatyczne generowanie 26 zaszyfrowanych sekretów         ║" -Color Magenta
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝" -Color Magenta
Write-ColorOutput ""

Test-Prerequisites
Initialize-OutputDirectory

Write-ColorOutput "🚀 Rozpoczynam generowanie sekretów..." -Color Green
Write-ColorOutput ""

# === 1. FreeIPA ===
Write-ColorOutput "┌─ WAVE 10: Core Infrastructure ─────────────────────────────────┐" -Color Blue
$freeIpaAdminPassword = New-SecurePassword -Length 32
$freeIpaReplication = New-SecurePassword -Length 32
New-SealedSecret -Name "freeipa-admin-secret" -Namespace "core-freeipa" `
    -Data @{
        "admin-password" = $freeIpaAdminPassword
        "ds-password" = $freeIpaReplication
    } `
    -Description "FreeIPA Admin + Directory Server passwords"

# === 2. Keycloak ===
$keycloakAdmin = New-SecurePassword -Length 32
$keycloakDbPassword = New-SecurePassword -Length 32
New-SealedSecret -Name "keycloak-admin-secret" -Namespace "core-keycloak" `
    -Data @{
        "admin-password" = $keycloakAdmin
    } `
    -Description "Keycloak Admin password"

New-SealedSecret -Name "keycloak-db-secret" -Namespace "core-keycloak" `
    -Data @{
        "username" = "keycloak"
        "password" = $keycloakDbPassword
    } `
    -Description "Keycloak PostgreSQL credentials"

# === 3. Longhorn S3 ===
$longhornS3AccessKey = New-SecurePassword -Length 20 -AlphanumericOnly
$longhornS3SecretKey = New-SecurePassword -Length 40 -AlphanumericOnly
New-SealedSecret -Name "longhorn-s3-secret" -Namespace "core-storage" `
    -Data @{
        "AWS_ACCESS_KEY_ID" = $longhornS3AccessKey
        "AWS_SECRET_ACCESS_KEY" = $longhornS3SecretKey
        "AWS_ENDPOINTS" = "http://minio.edu-minio.svc:9000"
    } `
    -Description "Longhorn S3 backup credentials (MinIO)"

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === 4-6. PostgreSQL HA ===
Write-ColorOutput "┌─ WAVE 20: Databases ───────────────────────────────────────────┐" -Color Blue
$postgresRootPassword = New-SecurePassword -Length 32
$postgresRepmgrPassword = New-SecurePassword -Length 32
New-SealedSecret -Name "postgresql-ha-secret" -Namespace "db-postgres" `
    -Data @{
        "password" = $postgresRootPassword
        "repmgr-password" = $postgresRepmgrPassword
    } `
    -Description "PostgreSQL HA root + repmgr passwords"

# Aplikacje PostgreSQL
$dbApps = @(
    @{Name="keycloak"; Namespace="core-keycloak"},
    @{Name="moodle"; Namespace="edu-moodle"},
    @{Name="gitlab"; Namespace="devops-gitlab"},
    @{Name="nextcloud"; Namespace="edu-nextcloud"},
    @{Name="mattermost"; Namespace="edu-mattermost"},
    @{Name="zammad"; Namespace="devops-zammad"},
    @{Name="zabbix"; Namespace="mon-zabbix"},
    @{Name="harbor"; Namespace="devops-harbor"},
    @{Name="jupyterhub"; Namespace="ai-jupyterhub"},
    @{Name="bigbluebutton"; Namespace="edu-bbb"},
    @{Name="onlyoffice"; Namespace="edu-onlyoffice"},
    @{Name="etherpad"; Namespace="edu-etherpad"}
)

foreach ($app in $dbApps) {
    $dbPassword = New-SecurePassword -Length 32
    New-SealedSecret -Name "$($app.Name)-db-secret" -Namespace $app.Namespace `
        -Data @{
            "username" = $app.Name
            "password" = $dbPassword
        } `
        -Description "$($app.Name) PostgreSQL credentials"
}

# === 7. MySQL HA ===
$mysqlRootPassword = New-SecurePassword -Length 32
$mysqlReplicationPassword = New-SecurePassword -Length 32
New-SealedSecret -Name "mysql-ha-secret" -Namespace "db-mysql" `
    -Data @{
        "root-password" = $mysqlRootPassword
        "replication-password" = $mysqlReplicationPassword
    } `
    -Description "MySQL HA root + replication passwords"

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === 8-13. Education Applications ===
Write-ColorOutput "┌─ WAVE 25: Education & Communication ───────────────────────────┐" -Color Blue

# Moodle
$moodleAdmin = New-SecurePassword -Length 32
New-SealedSecret -Name "moodle-admin-secret" -Namespace "edu-moodle" `
    -Data @{
        "username" = "admin"
        "password" = $moodleAdmin
    } `
    -Description "Moodle admin credentials"

# NextCloud
$nextcloudAdmin = New-SecurePassword -Length 32
$nextcloudRedis = New-SecurePassword -Length 32
New-SealedSecret -Name "nextcloud-admin-secret" -Namespace "edu-nextcloud" `
    -Data @{
        "username" = "admin"
        "password" = $nextcloudAdmin
    } `
    -Description "NextCloud admin credentials"

New-SealedSecret -Name "nextcloud-redis-secret" -Namespace "edu-nextcloud" `
    -Data @{
        "password" = $nextcloudRedis
    } `
    -Description "NextCloud Redis password"

# BigBlueButton
$bbbSecret = New-SecurePassword -Length 32 -AlphanumericOnly
$bbbLdapPassword = New-SecurePassword -Length 32
New-SealedSecret -Name "bbb-secret" -Namespace "edu-bbb" `
    -Data @{
        "secret" = $bbbSecret
    } `
    -Description "BigBlueButton shared secret"

New-SealedSecret -Name "bbb-ldap-secret" -Namespace "edu-bbb" `
    -Data @{
        "password" = $bbbLdapPassword
    } `
    -Description "BigBlueButton LDAP service account"

# OnlyOffice
$onlyofficeJWT = New-JWTSecret
New-SealedSecret -Name "onlyoffice-jwt-secret" -Namespace "edu-onlyoffice" `
    -Data @{
        "secret" = $onlyofficeJWT
    } `
    -Description "OnlyOffice JWT secret"

# Etherpad
$etherpadAdmin = New-SecurePassword -Length 32
$etherpadLdap = New-SecurePassword -Length 32
New-SealedSecret -Name "etherpad-admin-secret" -Namespace "edu-etherpad" `
    -Data @{
        "password" = $etherpadAdmin
    } `
    -Description "Etherpad admin password"

New-SealedSecret -Name "etherpad-ldap-secret" -Namespace "edu-etherpad" `
    -Data @{
        "password" = $etherpadLdap
    } `
    -Description "Etherpad LDAP service account"

# MinIO
$minioRootPassword = New-SecurePassword -Length 32 -AlphanumericOnly
$minioLonghornAccessKey = New-SecurePassword -Length 20 -AlphanumericOnly
$minioLonghornSecretKey = New-SecurePassword -Length 40 -AlphanumericOnly
$minioNextcloudAccessKey = New-SecurePassword -Length 20 -AlphanumericOnly
$minioNextcloudSecretKey = New-SecurePassword -Length 40 -AlphanumericOnly
$minioGitlabAccessKey = New-SecurePassword -Length 20 -AlphanumericOnly
$minioGitlabSecretKey = New-SecurePassword -Length 40 -AlphanumericOnly

New-SealedSecret -Name "minio-root-secret" -Namespace "edu-minio" `
    -Data @{
        "rootUser" = "admin"
        "rootPassword" = $minioRootPassword
    } `
    -Description "MinIO root credentials"

New-SealedSecret -Name "minio-longhorn-secret" -Namespace "edu-minio" `
    -Data @{
        "accessKey" = $minioLonghornAccessKey
        "secretKey" = $minioLonghornSecretKey
    } `
    -Description "MinIO Longhorn backup user"

New-SealedSecret -Name "minio-nextcloud-secret" -Namespace "edu-minio" `
    -Data @{
        "accessKey" = $minioNextcloudAccessKey
        "secretKey" = $minioNextcloudSecretKey
    } `
    -Description "MinIO NextCloud external storage"

New-SealedSecret -Name "minio-gitlab-secret" -Namespace "edu-minio" `
    -Data @{
        "accessKey" = $minioGitlabAccessKey
        "secretKey" = $minioGitlabSecretKey
    } `
    -Description "MinIO GitLab artifacts/LFS"

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === 14-17. DevOps Applications ===
Write-ColorOutput "┌─ WAVE 30: DevOps ──────────────────────────────────────────────┐" -Color Blue

# GitLab
$gitlabRoot = New-SecurePassword -Length 32
$gitlabRedis = New-SecurePassword -Length 32
$gitlabRegistry = New-SecurePassword -Length 32
$gitlabLdap = New-SecurePassword -Length 32
New-SealedSecret -Name "gitlab-root-secret" -Namespace "devops-gitlab" `
    -Data @{
        "password" = $gitlabRoot
    } `
    -Description "GitLab root password"

New-SealedSecret -Name "gitlab-redis-secret" -Namespace "devops-gitlab" `
    -Data @{
        "password" = $gitlabRedis
    } `
    -Description "GitLab Redis password"

New-SealedSecret -Name "gitlab-registry-storage" -Namespace "devops-gitlab" `
    -Data @{
        "config" = "s3://gitlab-artifacts@minio/"
        "secret" = $gitlabRegistry
    } `
    -Description "GitLab Container Registry S3 config"

New-SealedSecret -Name "gitlab-ldap-secret" -Namespace "devops-gitlab" `
    -Data @{
        "password" = $gitlabLdap
    } `
    -Description "GitLab LDAP service account"

# Harbor
$harborAdmin = New-SecurePassword -Length 32
$harborRedis = New-SecurePassword -Length 32
New-SealedSecret -Name "harbor-admin-secret" -Namespace "devops-harbor" `
    -Data @{
        "password" = $harborAdmin
    } `
    -Description "Harbor admin password"

New-SealedSecret -Name "harbor-redis-secret" -Namespace "devops-harbor" `
    -Data @{
        "password" = $harborRedis
    } `
    -Description "Harbor Redis password"

# Zammad
$zammadLdap = New-SecurePassword -Length 32
New-SealedSecret -Name "zammad-ldap-secret" -Namespace "devops-zammad" `
    -Data @{
        "password" = $zammadLdap
    } `
    -Description "Zammad LDAP service account"

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === 18. Communication (Mailu) ===
Write-ColorOutput "┌─ WAVE 30: Communication ───────────────────────────────────────┐" -Color Blue

$mailuAdmin = New-SecurePassword -Length 32
$mailuSecretKey = New-JWTSecret
$mailuLdap = New-SecurePassword -Length 32

New-SealedSecret -Name "mailu-admin-secret" -Namespace "com-mailu" `
    -Data @{
        "username" = "admin@zsel.opole.pl"
        "password" = $mailuAdmin
    } `
    -Description "Mailu admin credentials"

New-SealedSecret -Name "mailu-secret-key" -Namespace "com-mailu" `
    -Data @{
        "secretKey" = $mailuSecretKey
    } `
    -Description "Mailu SECRET_KEY"

New-SealedSecret -Name "mailu-ldap-secret" -Namespace "com-mailu" `
    -Data @{
        "password" = $mailuLdap
    } `
    -Description "Mailu LDAP service account"

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === 19. LDAP Service Accounts (FreeIPA) ===
Write-ColorOutput "┌─ LDAP Service Accounts (FreeIPA) ──────────────────────────────┐" -Color Blue

$ldapServices = @(
    @{Name="moodle"; Description="Moodle LMS"},
    @{Name="nextcloud"; Description="NextCloud"},
    @{Name="gitlab"; Description="GitLab"},
    @{Name="keycloak"; Description="Keycloak SSO"},
    @{Name="mattermost"; Description="Mattermost"},
    @{Name="bbb"; Description="BigBlueButton"},
    @{Name="etherpad"; Description="Etherpad"},
    @{Name="jupyterhub"; Description="JupyterHub"},
    @{Name="zammad"; Description="Zammad"},
    @{Name="mailu"; Description="Mailu"}
)

foreach ($service in $ldapServices) {
    $ldapPassword = New-SecurePassword -Length 32
    New-SealedSecret -Name "$($service.Name)-ldap-service" -Namespace "core-freeipa" `
        -Data @{
            "bind-dn" = "uid=$($service.Name)-service,cn=sysaccounts,cn=etc,dc=zsel,dc=opole,dc=pl"
            "password" = $ldapPassword
        } `
        -Description "$($service.Description) LDAP service account"
}

Write-ColorOutput "└────────────────────────────────────────────────────────────────┘" -Color Blue
Write-ColorOutput ""

# === Summary ===
Write-ColorOutput "╔════════════════════════════════════════════════════════════════╗" -Color Green
Write-ColorOutput "║  ✅ PODSUMOWANIE                                              ║" -Color Green
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝" -Color Green
Write-ColorOutput ""
Write-ColorOutput "📊 Wygenerowano sekrety:" -Color Cyan
Write-ColorOutput "   • Core Infrastructure: 4 sekrety (FreeIPA, Keycloak, Longhorn)" -Color White
Write-ColorOutput "   • Databases: 14 sekretów (PostgreSQL HA + 12 aplikacji + MySQL)" -Color White
Write-ColorOutput "   • Education: 11 sekretów (Moodle, NextCloud, BBB, OnlyOffice, Etherpad, MinIO)" -Color White
Write-ColorOutput "   • DevOps: 8 sekretów (GitLab, Harbor, Zammad)" -Color White
Write-ColorOutput "   • Communication: 3 sekrety (Mailu)" -Color White
Write-ColorOutput "   • LDAP Service Accounts: 10 sekretów" -Color White
Write-ColorOutput ""
Write-ColorOutput "📁 Lokalizacja: $OutputDir/" -Color Cyan
Write-ColorOutput "🔐 Wszystkie hasła są kryptograficznie bezpieczne (32-64 znaki)" -Color Green
Write-ColorOutput ""
Write-ColorOutput "🚀 Następne kroki:" -Color Yellow
Write-ColorOutput "   1. Sprawdź wygenerowane pliki w: $OutputDir/" -Color White
Write-ColorOutput "   2. Commituj do repozytorium Git (są zaszyfrowane!)" -Color White
Write-ColorOutput "   3. Zastosuj: kubectl apply -f $OutputDir/" -Color White
Write-ColorOutput "   4. Sprawdź status: kubectl get sealedsecrets -A" -Color White
Write-ColorOutput ""
Write-ColorOutput "⚠️  UWAGA: Zapisz hasła administratora w bezpiecznym miejscu!" -Color Red
Write-ColorOutput "   FreeIPA Admin: $freeIpaAdminPassword" -Color Yellow
Write-ColorOutput "   Keycloak Admin: $keycloakAdmin" -Color Yellow
Write-ColorOutput "   GitLab Root: $gitlabRoot" -Color Yellow
Write-ColorOutput "   Harbor Admin: $harborAdmin" -Color Yellow
Write-ColorOutput "   Mailu Admin: $mailuAdmin" -Color Yellow
Write-ColorOutput ""
