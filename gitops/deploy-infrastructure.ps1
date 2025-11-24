# Quick Deployment Script for K3s Infrastructure (PowerShell)
# Usage: .\deploy-infrastructure.ps1 [-DryRun]

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

Write-Host "=== K3s Infrastructure Deployment ===" -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Info "DRY RUN MODE - No actual changes will be made"
    Write-Host ""
}

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check kubectl
try {
    kubectl version --client=true | Out-Null
} catch {
    Write-Error-Custom "kubectl not found. Please install kubectl."
    exit 1
}

# Check K3s cluster connection
try {
    kubectl get nodes | Out-Null
} catch {
    Write-Error-Custom "Cannot connect to K3s cluster. Check your kubeconfig."
    exit 1
}

# Check node count
$nodeCount = (kubectl get nodes --no-headers | Measure-Object).Count
if ($nodeCount -ne 9) {
    Write-Info "WARNING: Expected 9 nodes, found $nodeCount"
}

# Check Longhorn
try {
    kubectl get sc longhorn | Out-Null
    Write-Success "Longhorn StorageClass found"
} catch {
    Write-Error-Custom "Longhorn StorageClass not found"
    exit 1
}

# Check MetalLB
try {
    kubectl get pods -n metallb-system | Out-Null
    Write-Success "MetalLB found"
} catch {
    Write-Error-Custom "MetalLB not found"
    exit 1
}

Write-Success "Prerequisites OK"
Write-Host ""

# Install ArgoCD if not present
try {
    kubectl get namespace argocd | Out-Null
    Write-Success "ArgoCD already installed"
} catch {
    Write-Info "Installing ArgoCD..."
    
    if (-not $DryRun) {
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        Write-Host "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
        
        Write-Success "ArgoCD installed"
    } else {
        Write-Host "[DRY RUN] Would install ArgoCD"
    }
}

# Get ArgoCD admin password
if (-not $DryRun) {
    Write-Host ""
    Write-Info "ArgoCD Admin Password:"
    $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host $decodedPassword -ForegroundColor Cyan
    Write-Host ""
}

# Deploy App-of-Apps
Write-Info "Deploying App-of-Apps..."

if (-not $DryRun) {
    kubectl apply -f infrastruktura-k3s/gitops/argocd/app-of-apps.yaml
    Write-Success "App-of-Apps deployed"
} else {
    Write-Host "[DRY RUN] Would deploy App-of-Apps"
}

# Wait for all apps to sync
if (-not $DryRun) {
    Write-Host ""
    Write-Info "Waiting for applications to sync..."
    Write-Host "This may take 5-10 minutes for all services to be healthy."
    Write-Host ""
    
    Write-Host "Monitoring application status (Ctrl+C to stop monitoring):"
    Write-Host ""
    
    while ($true) {
        kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
        Write-Host ""
        Start-Sleep -Seconds 10
    }
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
Write-Host "2. Install Sealed Secrets: See SEALED-SECRETS-GUIDE.md"
Write-Host "3. Generate secrets: bash ./environments/production/sealed-secrets/create-all-secrets.sh (use WSL or Git Bash)"
Write-Host "4. Configure MikroTik devices: bash ./konfiguracje-mikrotik/helpers/bulk-k3s-integration.sh"
Write-Host ""
Write-Host "Service URLs:"
Write-Host "- Graylog: http://192.168.255.55:9000"
Write-Host "- Prometheus: http://192.168.255.56:9090"
Write-Host "- Grafana: http://192.168.255.57:3000"
Write-Host "- AlertManager: http://192.168.255.58:9093"
Write-Host "- Zabbix: http://192.168.255.59"
Write-Host "- MinIO Console: http://192.168.255.71"
Write-Host ""
Write-Host "For ArgoCD CLI access:"
Write-Host "  argocd login localhost:8080 --username admin --password <password-from-above>"
