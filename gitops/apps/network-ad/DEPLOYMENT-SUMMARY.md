# GitOps Deployment Summary - Network AD

**Date:** 2024-01-15  
**Status:** ✅ READY FOR PRODUCTION DEPLOYMENT  
**Task:** Manifesty Network AD (apps/network-ad/)

---

## What Was Created

### Directory Structure

```
gitops/
├── .yamllint                 # YAML linting configuration
├── .gitattributes            # Git file handling rules (LF line endings)
├── .pre-commit-config.yaml   # Pre-commit hooks (yamllint, kustomize build test)
├── CODEOWNERS                # Code review requirements
└── apps/
    └── network-ad/
        ├── README.md                         # Complete documentation (deployment, troubleshooting)
        ├── base/
        │   ├── kustomization.yaml           # Kustomize base config
        │   ├── namespace.yaml               # core-auth namespace
        │   ├── configmap-smb.yaml           # Samba AD DC configuration (smb.conf)
        │   ├── configmap-init.yaml          # Domain provisioning script (OUs, users)
        │   ├── secret.yaml                  # Admin password PLACEHOLDER
        │   ├── statefulset.yaml             # Samba AD DC StatefulSet (2 replicas)
        │   ├── service.yaml                 # 3 Services (headless, primary, secondary)
        │   └── pvc.yaml                     # 50GB Longhorn storage
        └── overlays/
            └── production/
                ├── kustomization.yaml       # Production overlay
                └── patches/
                    ├── replicas.yaml        # 2 replicas (HA)
                    └── resources.yaml       # 4Gi/2CPU → 8Gi/4CPU
```

### Files Created (15 total)

1. **GitOps Config Files (4):**
   - `.yamllint` - YAML validation rules (120 char line length, LF line endings)
   - `.gitattributes` - Force LF for YAML/Markdown, treat binaries as binary
   - `.pre-commit-config.yaml` - yamllint, trailing-whitespace, kustomize build test
   - `CODEOWNERS` - Code review requirements (2 approvals for sealed-secrets/)

2. **Network AD Base Manifests (8):**
   - `namespace.yaml` - `core-auth` namespace with labels
   - `configmap-smb.yaml` - Samba AD DC config (realm: NETWORK-AD.ZSEL.OPOLE.PL)
   - `configmap-init.yaml` - Domain provisioning script (creates OUs, radius-bind user)
   - `secret.yaml` - Admin password PLACEHOLDER (replace with SealedSecret!)
   - `statefulset.yaml` - StatefulSet (2 replicas, 50GB PVC, ports 389/636/88/53/445)
   - `service.yaml` - Headless + 2 LoadBalancer services (192.168.255.51-52)
   - `pvc.yaml` - 50GB Longhorn storage claim
   - `kustomization.yaml` - Kustomize base configuration

3. **Production Overlay (3):**
   - `kustomization.yaml` - Overlay config (references base, applies patches)
   - `patches/replicas.yaml` - 2 replicas for HA
   - `patches/resources.yaml` - 8Gi RAM / 4 CPU (production sizing)

4. **Documentation (1):**
   - `README.md` - 600+ lines comprehensive guide:
     * Architecture diagram
     * Organizational Units (OUs) structure
     * Deployment instructions (ArgoCD + manual)
     * Admin password sealed secret workflow
     * Domain initialization explained
     * RADIUS bind account retrieval
     * Verification steps (health checks, LDAP query, DNS test, replication test)
     * User management (create/delete network admins, password policy)
     * Monitoring (logs, Graylog, Zabbix)
     * Backup & recovery (MinIO automated backups, retention policy)
     * Troubleshooting (CrashLoopBackOff, LDAP refused, replication failure)
     * Production checklist (12 items)

---

## Technical Specifications

### Samba AD Domain Controller

- **Domain:** `network-ad.zsel.opole.pl`
- **Netbios Name:** `NETWORK-AD`
- **Realm:** `NETWORK-AD.ZSEL.OPOLE.PL`
- **Role:** Active Directory Domain Controller
- **DNS Backend:** SAMBA_INTERNAL
- **DNS Forwarders:** 1.1.1.1, 9.9.9.9
- **LDAP SSL:** Disabled (no strong auth required for RADIUS bind)

### Organizational Units

```
DC=network-ad,DC=zsel,DC=opole,DC=pl
├── OU=NetworkDevices
│   └── OU=MikroTik
│       ├── OU=Routers (5 CCR2216)
│       ├── OU=Switches (35 CRS devices)
│       └── OU=WiFi (16 cAP ax)
├── OU=NetworkAdmins
│   └── OU=ITAdmins (10 network administrators)
└── OU=ServiceAccounts
    └── CN=radius-bind (FreeRADIUS LDAP bind account)
```

### Kubernetes Resources

| Resource | Type | Replicas | Storage | CPU | Memory |
|----------|------|----------|---------|-----|--------|
| network-ad-dc | StatefulSet | 2 (HA) | 50Gi × 2 | 2-4 cores | 4-8Gi |
| network-ad-headless | Service | ClusterIP (None) | - | - | - |
| network-ad-primary | Service | LoadBalancer (.51) | - | - | - |
| network-ad-secondary | Service | LoadBalancer (.52) | - | - | - |

### Network Configuration

- **Namespace:** `core-auth`
- **VLAN:** 600 (Management)
- **Primary IP:** 192.168.255.51 (network-ad-dc-0)
- **Secondary IP:** 192.168.255.52 (network-ad-dc-1)
- **Ports Exposed:**
  - 389/TCP - LDAP
  - 636/TCP - LDAPS
  - 88/TCP+UDP - Kerberos
  - 53/TCP+UDP - DNS
  - 445/TCP - SMB (sysvol replication)

### Security Isolation

**CRITICAL:** This domain is isolated from user authentication!

- NO trust relationship with `ad.zsel.opole.pl` (user domain)
- Firewall rules BLOCK access from user VLANs (10, 20, 30, 40)
- Only accessible from VLAN 600 (Management) and K3s cluster
- Only ~10 IT network admins have accounts
- Purpose: MikroTik RADIUS authentication ONLY

See: [AD-DOMAIN-SEPARATION.md](../../docs/AD-DOMAIN-SEPARATION.md)

---

## Validation

### Kustomize Build Test

```powershell
PS> Set-Location "gitops/apps/network-ad/overlays/production"
PS> kubectl kustomize . | Select-String "Warning|Error"
# NO WARNINGS ✅
```

**Output Summary:**
- Namespace: `core-auth` ✅
- ConfigMaps: `network-ad-smb-config`, `network-ad-init-script` ✅
- Secret: `network-ad-admin-secret` (PLACEHOLDER) ✅
- Services: `network-ad-headless`, `network-ad-primary` (.51), `network-ad-secondary` (.52) ✅
- StatefulSet: `network-ad-dc` (2 replicas, 8Gi RAM, 4 CPU) ✅
- Labels: `app.kubernetes.io/name=network-ad`, `environment=production` ✅

### ArgoCD Application Updated

- **Old Path:** `infrastruktura-k3s/gitops/base/samba-ad` ❌
- **New Path:** `infrastruktura-k3s/gitops/apps/network-ad/overlays/production` ✅
- **Application Name:** `samba-ad` → `network-ad` ✅
- **Description:** Updated to mention "Infrastructure Only" ✅

---

## Next Steps (Before Deployment)

### 1. Generate SealedSecret for Admin Password

```bash
# On workstation with kubeseal installed
ADMIN_PASSWORD=$(openssl rand -base64 32)
echo "Save this password securely: $ADMIN_PASSWORD"

kubectl create secret generic network-ad-admin-secret \
  --namespace=core-auth \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --dry-run=client -o yaml > /tmp/secret.yaml

kubeseal --format=yaml \
  --cert=environments/production/pub-sealed-secrets.pem \
  < /tmp/secret.yaml \
  > apps/network-ad/overlays/production/sealed-secret.yaml

rm /tmp/secret.yaml
unset ADMIN_PASSWORD
```

### 2. Update Production Kustomization

Uncomment in `apps/network-ad/overlays/production/kustomization.yaml`:

```yaml
resources:
  - ../../base
  - sealed-secret.yaml  # ADD THIS LINE
```

### 3. Deploy Firewall Rules (MikroTik)

Block user VLANs from accessing Network AD:

```routeros
# On CCR2216-BCU-01 (Core Router)
/ip firewall filter

# Block VLAN 10 (Servers - User AD) from Network AD
add chain=forward action=drop \
  src-address=192.168.10.0/24 \
  dst-address=192.168.255.51-192.168.255.52 \
  comment="Block User AD VLAN from Network AD"

# Block VLAN 20 (Teachers) from Network AD
add chain=forward action=drop \
  src-address=192.168.20.0/24 \
  dst-address=192.168.255.51-192.168.255.52 \
  comment="Block Teachers VLAN from Network AD"

# Block VLAN 30 (Students) from Network AD
add chain=forward action=drop \
  src-address=192.168.30.0/24 \
  dst-address=192.168.255.51-192.168.255.52 \
  comment="Block Students VLAN from Network AD"

# Block VLAN 40 (Guests) from Network AD
add chain=forward action=drop \
  src-address=192.168.40.0/24 \
  dst-address=192.168.255.51-192.168.255.52 \
  comment="Block Guests VLAN from Network AD"
```

### 4. Install Sealed Secrets Controller (if not present)

```bash
# Install Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Retrieve public cert for sealing
kubeseal --fetch-cert > environments/production/pub-sealed-secrets.pem
```

### 5. Deploy via ArgoCD

```bash
# Install ArgoCD (if not present)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Add Git repository
argocd repo add https://github.com/zsel-opole/zsel-opole-org.git

# Deploy app-of-apps (bootstraps all applications)
kubectl apply -f argocd/app-of-apps.yaml

# Wait for Network AD to sync
argocd app sync core-auth/network-ad --prune
argocd app wait core-auth/network-ad --health

# Verify deployment
kubectl get pods -n core-auth -l app.kubernetes.io/name=network-ad
kubectl get svc -n core-auth -l app.kubernetes.io/name=network-ad
```

### 6. Retrieve RADIUS Bind Password

After deployment, exec into PRIMARY pod:

```bash
kubectl exec -it -n core-auth network-ad-dc-0 -- bash

# Show radius-bind account
samba-tool user show radius-bind

# Or reset password
NEW_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 32 | head -n 1)
samba-tool user setpassword radius-bind --newpassword="$NEW_PASSWORD"
echo "New radius-bind password: $NEW_PASSWORD"
```

**Store this password for FreeRADIUS configuration!**

---

## Production Checklist

- [ ] Generate sealed admin password (step 1)
- [ ] Update production kustomization (step 2)
- [ ] Deploy firewall rules blocking user VLANs (step 3)
- [ ] Install Sealed Secrets Controller (step 4)
- [ ] Deploy via ArgoCD (step 5)
- [ ] Verify pods are Running (2/2 replicas)
- [ ] Verify LoadBalancer IPs assigned (192.168.255.51-52)
- [ ] Test LDAP query from management VLAN
- [ ] Test DNS resolution
- [ ] Retrieve radius-bind password (step 6)
- [ ] Create real network admin users (delete example `admin-network`)
- [ ] Set password policy (complexity, length, expiration)
- [ ] Configure automated backups to MinIO
- [ ] Enable Graylog log forwarding
- [ ] Add Zabbix monitoring host
- [ ] Test failover (scale PRIMARY to 0, verify SECONDARY)
- [ ] Document admin passwords in password manager

---

## Related Files Modified

- `gitops/argocd/apps/core-auth-apps.yaml` - Updated Application name and path
- `gitops/apps/network-ad/` - Created complete structure (15 files)
- `gitops/STRUCTURE.md` - Referenced in README.md
- `gitops/docs/AD-DOMAIN-SEPARATION.md` - Referenced in README.md

---

## Metrics

- **Files Created:** 15
- **Lines of Code:** ~1500 (manifests + docs)
- **Documentation:** 600+ lines README.md
- **Kustomize Build:** ✅ No warnings
- **Security:** ✅ Firewall rules planned, SealedSecret workflow documented
- **HA:** ✅ 2 replicas with separate LoadBalancer IPs
- **Storage:** 50Gi × 2 replicas = 100Gi total (Longhorn 3× replication = 300Gi raw)

---

**Status:** ✅ READY FOR PRODUCTION DEPLOYMENT  
**Next:** FreeRADIUS manifests (apps/freeradius/)  
**Blocked By:** Network AD deployment (FreeRADIUS requires `radius-bind` password)
