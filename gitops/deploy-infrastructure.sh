#!/bin/bash
# Quick Deployment Script for K3s Infrastructure
# Usage: ./deploy-infrastructure.sh [--dry-run]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
  DRY_RUN=true
  echo -e "${YELLOW}DRY RUN MODE - No actual changes will be made${NC}"
fi

echo -e "${GREEN}=== K3s Infrastructure Deployment ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! kubectl version &> /dev/null; then
  echo -e "${RED}ERROR: kubectl not found${NC}"
  exit 1
fi

if ! kubectl get nodes &> /dev/null; then
  echo -e "${RED}ERROR: Cannot connect to K3s cluster${NC}"
  exit 1
fi

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -ne 9 ]; then
  echo -e "${YELLOW}WARNING: Expected 9 nodes, found $NODE_COUNT${NC}"
fi

# Check Longhorn
if ! kubectl get sc longhorn &> /dev/null; then
  echo -e "${RED}ERROR: Longhorn StorageClass not found${NC}"
  exit 1
fi

# Check MetalLB
if ! kubectl get pods -n metallb-system &> /dev/null; then
  echo -e "${RED}ERROR: MetalLB not found${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Install ArgoCD if not present
if ! kubectl get namespace argocd &> /dev/null; then
  echo -e "${YELLOW}Installing ArgoCD...${NC}"
  
  if [ "$DRY_RUN" = false ]; then
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    echo -e "${GREEN}✓ ArgoCD installed${NC}"
  else
    echo "[DRY RUN] Would install ArgoCD"
  fi
else
  echo -e "${GREEN}✓ ArgoCD already installed${NC}"
fi

# Get ArgoCD admin password
if [ "$DRY_RUN" = false ]; then
  echo ""
  echo -e "${YELLOW}ArgoCD Admin Password:${NC}"
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  echo ""
  echo ""
fi

# Deploy App-of-Apps
echo -e "${YELLOW}Deploying App-of-Apps...${NC}"

if [ "$DRY_RUN" = false ]; then
  kubectl apply -f infrastruktura-k3s/gitops/argocd/app-of-apps.yaml
  echo -e "${GREEN}✓ App-of-Apps deployed${NC}"
else
  echo "[DRY RUN] Would deploy App-of-Apps"
fi

# Wait for all apps to sync
if [ "$DRY_RUN" = false ]; then
  echo ""
  echo -e "${YELLOW}Waiting for applications to sync...${NC}"
  echo "This may take 5-10 minutes for all services to be healthy."
  echo ""
  
  # Monitor ArgoCD apps
  echo "Monitoring application status (Ctrl+C to stop monitoring):"
  echo ""
  
  while true; do
    kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status | grep -v NAME
    echo ""
    sleep 10
  done
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Install Sealed Secrets: See SEALED-SECRETS-GUIDE.md"
echo "3. Generate secrets: ./environments/production/sealed-secrets/create-all-secrets.sh"
echo "4. Configure MikroTik devices: ./konfiguracje-mikrotik/helpers/bulk-k3s-integration.sh"
echo ""
echo "Service URLs:"
echo "- Graylog: http://192.168.255.55:9000"
echo "- Prometheus: http://192.168.255.56:9090"
echo "- Grafana: http://192.168.255.57:3000"
echo "- AlertManager: http://192.168.255.58:9093"
echo "- Zabbix: http://192.168.255.59"
echo "- MinIO Console: http://192.168.255.71"
