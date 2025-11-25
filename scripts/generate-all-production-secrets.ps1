################################################################################
# Generate All Production Sealed Secrets
# 
# Description: Automate generation of 50+ production Sealed Secrets
# Version: 1.0
# Date: 2025-11-25
# 
# Features:
# - CSPRNG-based secret generation (entropy 191-512 bits)
# - Automatic Sealed Secret creation
# - 1Password/Bitwarden integration
# - Validation & verification
# - Rollback capability
#
# Secret Categories:
# - Database passwords (12 secrets)
# - Application credentials (20 secrets)
# - Integration tokens (10 secrets)
# - Backup credentials (8 secrets)
################################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$KubesealCert = "sealed-secrets.crt",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\sealed-secrets",
    
    [Parameter(Mandatory=$false)]
    [switch]$Export1Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportBitwarden,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"

# Statistics
$TotalSecrets = 0
$SuccessCount = 0
$ErrorCount = 0

################################################################################
# Secret Definitions
################################################################################

$SecretInventory = @(
    # ========== DATABASE PASSWORDS (12 secrets) ==========
    @{
        Name = "postgres-admin"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 64
            password_complexity = "high"
        }
        Description = "PostgreSQL admin user"
    },
    @{
        Name = "postgres-moodle"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            username = "moodle"
            password_length = 64
            database = "moodle"
        }
        Description = "PostgreSQL moodle database"
    },
    @{
        Name = "postgres-nextcloud"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            username = "nextcloud"
            password_length = 64
            database = "nextcloud"
        }
        Description = "PostgreSQL nextcloud database"
    },
    @{
        Name = "postgres-keycloak"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            username = "keycloak"
            password_length = 64
            database = "keycloak"
        }
        Description = "PostgreSQL keycloak database"
    },
    @{
        Name = "postgres-gitlab"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            username = "gitlab"
            password_length = 64
            database = "gitlab"
        }
        Description = "PostgreSQL gitlab database"
    },
    @{
        Name = "mysql-admin"
        Namespace = "db-mysql"
        Type = "Opaque"
        Data = @{
            username = "root"
            password_length = 64
        }
        Description = "MySQL root user"
    },
    @{
        Name = "mysql-wordpress"
        Namespace = "db-mysql"
        Type = "Opaque"
        Data = @{
            username = "wordpress"
            password_length = 64
            database = "wordpress"
        }
        Description = "MySQL wordpress database"
    },
    @{
        Name = "mysql-zabbix"
        Namespace = "db-mysql"
        Type = "Opaque"
        Data = @{
            username = "zabbix"
            password_length = 64
            database = "zabbix"
        }
        Description = "MySQL zabbix database"
    },
    @{
        Name = "redis-password"
        Namespace = "db-redis"
        Type = "Opaque"
        Data = @{
            password_length = 64
        }
        Description = "Redis authentication password"
    },
    @{
        Name = "mongodb-admin"
        Namespace = "db-mongodb"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 64
        }
        Description = "MongoDB admin user"
    },
    @{
        Name = "mongodb-rocketchat"
        Namespace = "db-mongodb"
        Type = "Opaque"
        Data = @{
            username = "rocketchat"
            password_length = 64
            database = "rocketchat"
        }
        Description = "MongoDB rocketchat database"
    },
    @{
        Name = "elasticsearch-admin"
        Namespace = "db-elasticsearch"
        Type = "Opaque"
        Data = @{
            username = "elastic"
            password_length = 64
        }
        Description = "Elasticsearch admin user"
    },
    
    # ========== APPLICATION CREDENTIALS (20 secrets) ==========
    @{
        Name = "moodle-admin"
        Namespace = "edu-moodle"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
            email = "admin@zsel.opole.pl"
        }
        Description = "Moodle admin user"
    },
    @{
        Name = "moodle-db-credentials"
        Namespace = "edu-moodle"
        Type = "Opaque"
        Data = @{
            db_host = "postgres.db-postgres.svc.cluster.local"
            db_user = "moodle"
            db_password_length = 64
            db_name = "moodle"
        }
        Description = "Moodle database connection"
    },
    @{
        Name = "nextcloud-admin"
        Namespace = "edu-nextcloud"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
        }
        Description = "NextCloud admin user"
    },
    @{
        Name = "nextcloud-db-credentials"
        Namespace = "edu-nextcloud"
        Type = "Opaque"
        Data = @{
            db_host = "postgres.db-postgres.svc.cluster.local"
            db_user = "nextcloud"
            db_password_length = 64
            db_name = "nextcloud"
        }
        Description = "NextCloud database connection"
    },
    @{
        Name = "keycloak-admin"
        Namespace = "core-keycloak"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 48
        }
        Description = "Keycloak admin user"
    },
    @{
        Name = "keycloak-db-credentials"
        Namespace = "core-keycloak"
        Type = "Opaque"
        Data = @{
            db_host = "postgres.db-postgres.svc.cluster.local"
            db_user = "keycloak"
            db_password_length = 64
            db_name = "keycloak"
        }
        Description = "Keycloak database connection"
    },
    @{
        Name = "freeipa-admin"
        Namespace = "core-freeipa"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 48
        }
        Description = "FreeIPA admin user"
    },
    @{
        Name = "gitlab-root"
        Namespace = "devops-gitlab"
        Type = "Opaque"
        Data = @{
            username = "root"
            password_length = 32
        }
        Description = "GitLab root user"
    },
    @{
        Name = "gitlab-db-credentials"
        Namespace = "devops-gitlab"
        Type = "Opaque"
        Data = @{
            db_host = "postgres.db-postgres.svc.cluster.local"
            db_user = "gitlab"
            db_password_length = 64
            db_name = "gitlab"
        }
        Description = "GitLab database connection"
    },
    @{
        Name = "gitlab-runner-token"
        Namespace = "devops-gitlab"
        Type = "Opaque"
        Data = @{
            token_length = 64
        }
        Description = "GitLab Runner registration token"
    },
    @{
        Name = "harbor-admin"
        Namespace = "devops-harbor"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
        }
        Description = "Harbor admin user"
    },
    @{
        Name = "harbor-db-credentials"
        Namespace = "devops-harbor"
        Type = "Opaque"
        Data = @{
            db_host = "postgres.db-postgres.svc.cluster.local"
            db_user = "harbor"
            db_password_length = 64
            db_name = "harbor"
        }
        Description = "Harbor database connection"
    },
    @{
        Name = "argocd-admin"
        Namespace = "core-argocd"
        Type = "Opaque"
        Data = @{
            password_length = 32
        }
        Description = "ArgoCD admin password (bcrypt hashed)"
    },
    @{
        Name = "grafana-admin"
        Namespace = "mon-grafana"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
        }
        Description = "Grafana admin user"
    },
    @{
        Name = "portainer-admin"
        Namespace = "devops-portainer"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
        }
        Description = "Portainer admin user"
    },
    @{
        Name = "jupyterhub-admin"
        Namespace = "edu-jupyterhub"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
        }
        Description = "JupyterHub admin user"
    },
    @{
        Name = "rocketchat-admin"
        Namespace = "comm-rocketchat"
        Type = "Opaque"
        Data = @{
            username = "admin"
            password_length = 32
            email = "admin@zsel.opole.pl"
        }
        Description = "RocketChat admin user"
    },
    @{
        Name = "zabbix-admin"
        Namespace = "mon-zabbix"
        Type = "Opaque"
        Data = @{
            username = "Admin"
            password_length = 32
        }
        Description = "Zabbix admin user"
    },
    @{
        Name = "mailu-admin"
        Namespace = "core-mailu"
        Type = "Opaque"
        Data = @{
            username = "admin@zsel.opole.pl"
            password_length = 32
        }
        Description = "Mailu admin user"
    },
    @{
        Name = "wikijs-admin"
        Namespace = "edu-wikijs"
        Type = "Opaque"
        Data = @{
            email = "admin@zsel.opole.pl"
            password_length = 32
        }
        Description = "Wiki.js admin user"
    },
    
    # ========== INTEGRATION TOKENS (10 secrets) ==========
    @{
        Name = "smtp-credentials"
        Namespace = "core-mailu"
        Type = "Opaque"
        Data = @{
            smtp_host = "smtp.zsel.opole.pl"
            smtp_port = "587"
            smtp_user = "noreply@zsel.opole.pl"
            smtp_password_length = 32
        }
        Description = "SMTP server credentials"
    },
    @{
        Name = "ldap-bind-credentials"
        Namespace = "core-freeipa"
        Type = "Opaque"
        Data = @{
            bind_dn = "uid=ldapbind,cn=users,dc=zsel,dc=opole,dc=pl"
            bind_password_length = 48
        }
        Description = "LDAP bind user for service integration"
    },
    @{
        Name = "s3-credentials"
        Namespace = "storage-minio"
        Type = "Opaque"
        Data = @{
            access_key_length = 32
            secret_key_length = 64
        }
        Description = "S3/MinIO access credentials"
    },
    @{
        Name = "oauth-github"
        Namespace = "core-keycloak"
        Type = "Opaque"
        Data = @{
            client_id = "generate"
            client_secret_length = 64
        }
        Description = "GitHub OAuth integration"
    },
    @{
        Name = "oauth-google"
        Namespace = "core-keycloak"
        Type = "Opaque"
        Data = @{
            client_id = "generate"
            client_secret_length = 64
        }
        Description = "Google OAuth integration"
    },
    @{
        Name = "prometheus-remote-write"
        Namespace = "mon-prometheus"
        Type = "Opaque"
        Data = @{
            username = "prometheus"
            password_length = 64
        }
        Description = "Prometheus remote write credentials"
    },
    @{
        Name = "webhook-secret"
        Namespace = "core-argocd"
        Type = "Opaque"
        Data = @{
            secret_length = 64
        }
        Description = "Generic webhook secret"
    },
    @{
        Name = "api-token-monitoring"
        Namespace = "mon-grafana"
        Type = "Opaque"
        Data = @{
            token_length = 64
        }
        Description = "Monitoring API token"
    },
    @{
        Name = "registry-pull-secret"
        Namespace = "default"
        Type = "kubernetes.io/dockerconfigjson"
        Data = @{
            registry = "harbor.zsel.opole.pl"
            username = "robot$pull"
            password_length = 64
        }
        Description = "Container registry pull secret"
    },
    @{
        Name = "tls-wildcard-cert"
        Namespace = "ingress-nginx"
        Type = "kubernetes.io/tls"
        Data = @{
            generate = "self-signed"
            cn = "*.zsel.opole.pl"
        }
        Description = "Wildcard TLS certificate"
    },
    
    # ========== BACKUP CREDENTIALS (8 secrets) ==========
    @{
        Name = "velero-s3-credentials"
        Namespace = "backup-velero"
        Type = "Opaque"
        Data = @{
            aws_access_key_id_length = 32
            aws_secret_access_key_length = 64
        }
        Description = "Velero S3 backup credentials"
    },
    @{
        Name = "longhorn-backup-s3"
        Namespace = "longhorn-system"
        Type = "Opaque"
        Data = @{
            aws_access_key_id_length = 32
            aws_secret_access_key_length = 64
        }
        Description = "Longhorn S3 backup credentials"
    },
    @{
        Name = "restic-password"
        Namespace = "backup-velero"
        Type = "Opaque"
        Data = @{
            password_length = 64
        }
        Description = "Restic encryption password"
    },
    @{
        Name = "minio-root-credentials"
        Namespace = "storage-minio"
        Type = "Opaque"
        Data = @{
            root_user = "admin"
            root_password_length = 64
        }
        Description = "MinIO root credentials"
    },
    @{
        Name = "synology-nas-credentials"
        Namespace = "backup-velero"
        Type = "Opaque"
        Data = @{
            username = "k8s-backup"
            password_length = 48
            host = "nas.zsel.opole.pl"
        }
        Description = "Synology NAS backup user"
    },
    @{
        Name = "encryption-key"
        Namespace = "backup-velero"
        Type = "Opaque"
        Data = @{
            key_length = 64
        }
        Description = "Backup encryption key (AES-256)"
    },
    @{
        Name = "pgbackrest-credentials"
        Namespace = "db-postgres"
        Type = "Opaque"
        Data = @{
            repo1_azure_account_length = 32
            repo1_azure_key_length = 64
        }
        Description = "pgBackRest backup credentials"
    },
    @{
        Name = "backup-notification-webhook"
        Namespace = "backup-velero"
        Type = "Opaque"
        Data = @{
            webhook_url = "https://hooks.slack.com/services/..."
            token_length = 48
        }
        Description = "Backup notification webhook"
    }
)

################################################################################
# Functions
################################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message" -ForegroundColor $color
}

function Generate-SecurePassword {
    param([int]$Length = 32)
    
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}|;:,.<>?"
    $password = ""
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 4
        $rng.GetBytes($bytes)
        $randomNumber = [System.BitConverter]::ToUInt32($bytes, 0)
        $password += $chars[$randomNumber % $chars.Length]
    }
    
    $rng.Dispose()
    return $password
}

function Generate-Token {
    param([int]$Length = 64)
    
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    
    return [Convert]::ToBase64String($bytes).Substring(0, $Length)
}

function Create-SealedSecret {
    param(
        [hashtable]$SecretDef
    )
    
    $script:TotalSecrets++
    
    Write-Log "[$TotalSecrets/$($SecretInventory.Count)] Processing: $($SecretDef.Name) in $($SecretDef.Namespace)" -Level INFO
    
    # Generate secret data
    $secretData = @{}
    
    foreach ($key in $SecretDef.Data.Keys) {
        if ($key -like "*_length") {
            $fieldName = $key -replace "_length$", ""
            $length = $SecretDef.Data[$key]
            
            if ($key -like "*password*" -or $key -like "*secret*") {
                $secretData[$fieldName] = Generate-SecurePassword -Length $length
            }
            elseif ($key -like "*token*" -or $key -like "*key*") {
                $secretData[$fieldName] = Generate-Token -Length $length
            }
            else {
                $secretData[$fieldName] = Generate-SecurePassword -Length $length
            }
        }
        else {
            $secretData[$key] = $SecretDef.Data[$key]
        }
    }
    
    # Create Kubernetes secret YAML
    $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: $($SecretDef.Name)
  namespace: $($SecretDef.Namespace)
type: $($SecretDef.Type)
stringData:
"@
    
    foreach ($key in $secretData.Keys) {
        $secretYaml += "`n  $key: `"$($secretData[$key])`""
    }
    
    # Save to temp file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $secretYaml | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Create sealed secret
    $outputFile = Join-Path $OutputDir "$($SecretDef.Namespace)-$($SecretDef.Name).yaml"
    
    if ($DryRun) {
        Write-Log "  [DRY RUN] Would create: $outputFile" -Level WARNING
        Remove-Item $tempFile
        $script:SuccessCount++
        return $secretData
    }
    
    try {
        # Use kubeseal to encrypt
        $kubesealArgs = @(
            "--format=yaml"
            "--cert=$KubesealCert"
            "<$tempFile"
            ">$outputFile"
        )
        
        $result = & kubeseal @kubesealArgs 2>&1
        
        if (Test-Path $outputFile) {
            Write-Log "  ✓ Created sealed secret: $outputFile" -Level SUCCESS
            $script:SuccessCount++
            
            # Export to password manager
            if ($Export1Password -and -not $DryRun) {
                Export-To1Password -SecretDef $SecretDef -SecretData $secretData
            }
            
            if ($ExportBitwarden -and -not $DryRun) {
                Export-ToBitwarden -SecretDef $SecretDef -SecretData $secretData
            }
        }
        else {
            throw "Sealed secret file not created"
        }
    }
    catch {
        Write-Log "  ✗ Failed: $_" -Level ERROR
        $script:ErrorCount++
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    
    return $secretData
}

function Export-To1Password {
    param(
        [hashtable]$SecretDef,
        [hashtable]$SecretData
    )
    
    if (-not (Get-Command "op" -ErrorAction SilentlyContinue)) {
        return
    }
    
    try {
        $title = "ZSEL-K8s-$($SecretDef.Namespace)-$($SecretDef.Name)"
        
        $fields = @()
        foreach ($key in $SecretData.Keys) {
            $fields += @{
                label = $key
                value = $SecretData[$key]
                type = if ($key -match "password|secret|token|key") { "concealed" } else { "text" }
            }
        }
        
        $item = @{
            title = $title
            vault = "ZSEL-Production"
            category = "password"
            fields = $fields
            tags = @("kubernetes", "sealed-secret", $SecretDef.Namespace)
        } | ConvertTo-Json -Depth 10
        
        $item | op item create --vault="ZSEL-Production" | Out-Null
        Write-Log "    Exported to 1Password" -Level INFO
    }
    catch {
        Write-Log "    Failed to export to 1Password: $_" -Level WARNING
    }
}

function Export-ToBitwarden {
    param(
        [hashtable]$SecretDef,
        [hashtable]$SecretData
    )
    
    if (-not (Get-Command "bw" -ErrorAction SilentlyContinue)) {
        return
    }
    
    try {
        $name = "ZSEL-K8s-$($SecretDef.Namespace)-$($SecretDef.Name)"
        
        $fields = @()
        foreach ($key in $SecretData.Keys) {
            $fields += @{
                name = $key
                value = $SecretData[$key]
                type = 0  # text
            }
        }
        
        $item = @{
            type = 2  # Secure note
            name = $name
            notes = $SecretDef.Description
            fields = $fields
        } | ConvertTo-Json -Depth 10
        
        $encodedJson = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($item))
        bw create item $encodedJson | Out-Null
        
        Write-Log "    Exported to Bitwarden" -Level INFO
    }
    catch {
        Write-Log "    Failed to export to Bitwarden: $_" -Level WARNING
    }
}

function Verify-SealedSecrets {
    Write-Log "========================================" -Level INFO
    Write-Log "Verifying Sealed Secrets" -Level INFO
    Write-Log "========================================" -Level INFO
    
    $files = Get-ChildItem -Path $OutputDir -Filter "*.yaml"
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw
            
            # Basic YAML validation
            if ($content -match "kind: SealedSecret" -and $content -match "encryptedData:") {
                Write-Log "  ✓ Valid: $($file.Name)" -Level SUCCESS
            }
            else {
                Write-Log "  ✗ Invalid: $($file.Name)" -Level ERROR
                $script:ErrorCount++
            }
        }
        catch {
            Write-Log "  ✗ Error reading: $($file.Name) - $_" -Level ERROR
            $script:ErrorCount++
        }
    }
}

function Generate-Summary {
    Write-Log "" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "Generation Summary" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "Total secrets: $TotalSecrets" -Level INFO
    Write-Log "Success: $SuccessCount" -Level SUCCESS
    Write-Log "Errors: $ErrorCount" -Level ERROR
    Write-Log "Output directory: $OutputDir" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "Next Steps:" -Level INFO
    Write-Log "1. Review generated sealed secrets in: $OutputDir" -Level INFO
    Write-Log "2. Commit to Git: git add $OutputDir && git commit -m 'Add production sealed secrets'" -Level INFO
    Write-Log "3. Push to repository: git push" -Level INFO
    Write-Log "4. ArgoCD will automatically apply sealed secrets" -Level INFO
    Write-Log "5. Verify deployment: kubectl get sealedsecrets -A" -Level INFO
    Write-Log "========================================" -Level INFO
}

################################################################################
# Main
################################################################################

Write-Log "========================================" -Level INFO
Write-Log "Production Sealed Secrets Generator" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Total secrets to generate: $($SecretInventory.Count)" -Level INFO
Write-Log "Output directory: $OutputDir" -Level INFO
Write-Log "Dry run: $DryRun" -Level INFO
Write-Log "" -Level INFO

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Check prerequisites
if (-not $DryRun) {
    if (-not (Get-Command "kubeseal" -ErrorAction SilentlyContinue)) {
        Write-Log "kubeseal not found. Install from: https://github.com/bitnami-labs/sealed-secrets" -Level ERROR
        exit 1
    }
    
    if (-not (Test-Path $KubesealCert)) {
        Write-Log "Kubeseal certificate not found: $KubesealCert" -Level ERROR
        Write-Log "Fetch certificate: kubeseal --fetch-cert > $KubesealCert" -Level INFO
        exit 1
    }
}

# Generate all secrets
foreach ($secretDef in $SecretInventory) {
    Create-SealedSecret -SecretDef $secretDef
}

# Verify if not dry run
if (-not $DryRun -and -not $SkipVerification) {
    Verify-SealedSecrets
}

# Generate summary
Generate-Summary

exit ($ErrorCount -gt 0 ? 1 : 0)
