# GitOps Repository Structure
> Production-grade Kubernetes manifests for ZSEL Network Services

**Date:** 2025-11-22  
**ArgoCD Version:** 2.9+  
**Kustomize Version:** 5.0+  
**Repository:** https://github.com/zsel-opole/zsel-opole-org.git

---

## 📂 Directory Structure (Production Best Practices)

```
infrastruktura-k3s/gitops/
│
├── README.md                              # This file
├── .gitattributes                         # Git LFS for large files
├── .yamllint                              # YAML linting rules
├── .pre-commit-config.yaml                # Pre-commit hooks
├── CODEOWNERS                             # Code review ownership
│
├── docs/                                  # Documentation
│   ├── AD-DOMAIN-SEPARATION.md            # Network AD vs User AD design
│   ├── DEPLOYMENT-GUIDE.md                # Step-by-step deployment
│   ├── TROUBLESHOOTING.md                 # Common issues & solutions
│   ├── RUNBOOK.md                         # Operational procedures
│   └── SECURITY-POLICY.md                 # Security requirements
│
├── clusters/                              # Per-cluster configuration
│   └── zsel-k3s-prod/                     # Production K3s cluster
│       ├── cluster-info.yaml              # Cluster metadata
│       ├── cluster-resources.yaml         # StorageClass, PriorityClass
│       └── metallb-config.yaml            # MetalLB IP pool
│
├── argocd/                                # ArgoCD configuration
│   ├── bootstrap/                         # Bootstrap ArgoCD itself
│   │   ├── argocd-install.yaml            # ArgoCD installation
│   │   ├── argocd-cm.yaml                 # ConfigMap (repos, settings)
│   │   └── argocd-rbac-cm.yaml            # RBAC policy
│   │
│   ├── projects/                          # AppProject CRDs
│   │   ├── core-services.yaml             # Core infra (auth, network, storage)
│   │   ├── monitoring.yaml                # Monitoring stack
│   │   └── user-services.yaml             # User AD, Moodle (future)
│   │
│   ├── applications/                      # Application CRDs
│   │   ├── core-auth/                     # Authentication services
│   │   │   ├── network-ad.yaml            # Network AD for MikroTik
│   │   │   └── freeradius.yaml            # RADIUS for MikroTik
│   │   ├── core-network/                  # Network services
│   │   │   ├── dns.yaml                   # Bind9 DNS
│   │   │   ├── ntp.yaml                   # Chrony NTP
│   │   │   └── dhcp.yaml                  # Kea DHCP
│   │   ├── core-storage/                  # Storage services
│   │   │   └── minio.yaml                 # MinIO S3 backup
│   │   ├── mon-observability/             # Metrics & dashboards
│   │   │   ├── prometheus.yaml            # Prometheus
│   │   │   ├── grafana.yaml               # Grafana
│   │   │   └── alertmanager.yaml          # AlertManager
│   │   ├── mon-logging/                   # Log aggregation
│   │   │   └── graylog.yaml               # Graylog
│   │   └── mon-zabbix/                    # Enterprise monitoring
│   │       └── zabbix.yaml                # Zabbix
│   │
│   └── app-of-apps.yaml                   # Root Application (App of Apps)
│
├── apps/                                  # Application manifests (per-app)
│   ├── network-ad/                        # Network AD (Samba)
│   │   ├── base/                          # Base Kustomize
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── statefulset.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap-smb.yaml
│   │   │   ├── configmap-init.yaml
│   │   │   ├── secret.yaml
│   │   │   └── pvc.yaml
│   │   ├── overlays/                      # Environment overlays
│   │   │   ├── dev/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── patches/
│   │   │   │       └── replicas.yaml      # 1 replica for dev
│   │   │   └── production/
│   │   │       ├── kustomization.yaml
│   │   │       └── patches/
│   │   │           ├── replicas.yaml      # 2 replicas for prod
│   │   │           └── resources.yaml     # Higher CPU/RAM
│   │   └── README.md                      # App-specific docs
│   │
│   ├── freeradius/                        # FreeRADIUS
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap-ldap.yaml
│   │   │   ├── configmap-clients.yaml
│   │   │   ├── configmap-users.yaml
│   │   │   └── secret.yaml
│   │   ├── overlays/
│   │   │   ├── dev/
│   │   │   └── production/
│   │   └── README.md
│   │
│   ├── dns/                               # Bind9 DNS
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap-named.yaml
│   │   │   ├── configmap-zones.yaml
│   │   │   └── configmap-reverse-zones.yaml
│   │   ├── overlays/
│   │   │   ├── dev/
│   │   │   └── production/
│   │   └── README.md
│   │
│   ├── ntp/                               # Chrony NTP
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── daemonset.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   ├── overlays/
│   │   │   ├── dev/
│   │   │   └── production/
│   │   └── README.md
│   │
│   ├── dhcp/                              # Kea DHCP
│   │   ├── base/
│   │   ├── overlays/
│   │   └── README.md
│   │
│   ├── minio/                             # MinIO S3
│   │   ├── base/
│   │   ├── overlays/
│   │   └── README.md
│   │
│   ├── prometheus/                        # Prometheus
│   │   ├── base/
│   │   ├── overlays/
│   │   └── README.md
│   │
│   ├── grafana/                           # Grafana
│   │   ├── base/
│   │   ├── overlays/
│   │   └── README.md
│   │
│   ├── alertmanager/                      # AlertManager
│   │   ├── base/
│   │   ├── overlays/
│   │   └── README.md
│   │
│   ├── graylog/                           # Graylog
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── statefulset-elasticsearch.yaml
│   │   │   ├── statefulset-mongodb.yaml
│   │   │   ├── deployment-graylog.yaml
│   │   │   ├── service-*.yaml
│   │   │   ├── pvc-*.yaml
│   │   │   └── configmap-*.yaml
│   │   ├── overlays/
│   │   └── README.md
│   │
│   └── zabbix/                            # Zabbix
│       ├── base/
│       │   ├── kustomization.yaml
│       │   ├── statefulset-server.yaml
│       │   ├── statefulset-postgresql.yaml
│       │   ├── deployment-web.yaml
│       │   ├── daemonset-agent.yaml
│       │   ├── service-*.yaml
│       │   ├── pvc-*.yaml
│       │   └── configmap-*.yaml
│       ├── overlays/
│       └── README.md
│
├── components/                            # Shared/reusable components
│   ├── sealed-secrets/                    # Sealed Secrets manifests
│   │   ├── controller.yaml
│   │   └── README.md
│   ├── cert-manager/                      # Cert-manager (if needed)
│   │   └── ...
│   └── metallb/                           # MetalLB (if not in cluster/)
│       └── ...
│
└── environments/                          # Environment-wide config
    ├── dev/                               # Development environment
    │   ├── kustomization.yaml             # Includes all apps with dev overlays
    │   ├── namespace-quotas.yaml          # Resource limits per namespace
    │   └── network-policies.yaml          # NetworkPolicy for dev
    │
    ├── staging/                           # Staging environment (optional)
    │   ├── kustomization.yaml
    │   └── ...
    │
    └── production/                        # Production environment
        ├── kustomization.yaml             # Includes all apps with prod overlays
        ├── namespace-quotas.yaml          # Higher limits for prod
        ├── network-policies.yaml          # Strict NetworkPolicy
        ├── priority-classes.yaml          # PriorityClass (critical > high > normal)
        └── sealed-secrets/                # Encrypted secrets (safe to commit)
            ├── network-ad-admin.yaml
            ├── freeradius-secret.yaml
            ├── minio-credentials.yaml
            ├── zabbix-db-password.yaml
            └── grafana-admin.yaml
```

---

## 🎯 Design Principles

### 1. Separation of Concerns

**apps/** = Application-specific manifests (one directory per app)
- Each app is self-contained
- Base manifests + environment overlays
- App-specific README with configuration details

**argocd/** = ArgoCD configuration (meta-layer)
- Projects (RBAC boundaries)
- Applications (pointers to apps/)
- Bootstrap (ArgoCD itself)

**environments/** = Cross-cutting environment config
- Namespace quotas (ResourceQuota)
- Network policies (NetworkPolicy)
- Priority classes (PriorityClass)
- Sealed secrets (production only)

**clusters/** = Cluster-specific config
- MetalLB IP pools
- StorageClass definitions
- Cluster metadata

**components/** = Reusable shared components
- Sealed Secrets controller
- Cert-manager
- Common RBAC roles

---

### 2. Kustomize Over Helm

**Why Kustomize?**
- ✅ Native to kubectl/ArgoCD
- ✅ No templating complexity (pure YAML)
- ✅ Declarative overlays (patches)
- ✅ Easy to review in Git diffs
- ✅ No Tiller/Helm 3 runtime dependencies

**base/ vs overlays/**
- **base/**: Common manifests (work in any environment)
- **overlays/dev/**: Low resources, 1 replica, relaxed security
- **overlays/production/**: High resources, 2-3 replicas, strict security, sealed secrets

---

### 3. GitOps Workflow

**Single Branch Strategy (main):**
```
main (protected)
 ├── Direct commits: FORBIDDEN
 ├── Merge via Pull Request: REQUIRED
 └── Reviewers: 2+ approvals (CODEOWNERS)
```

**Feature Branch Workflow:**
```bash
# 1. Create feature branch
git checkout -b feature/network-ad-high-availability

# 2. Edit manifests
vim apps/network-ad/overlays/production/patches/replicas.yaml

# 3. Validate locally
kubectl kustomize apps/network-ad/overlays/production | kubectl apply --dry-run=client -f -

# 4. Commit with conventional commits
git commit -m "feat(network-ad): increase replicas to 3 for HA"

# 5. Push & create PR
git push origin feature/network-ad-high-availability

# 6. CI/CD runs:
#    - yamllint (YAML validation)
#    - kustomize build (syntax check)
#    - kubeconform (Kubernetes schema validation)
#    - trivy (security scan)

# 7. Code review (2+ approvals)

# 8. Merge to main
#    - ArgoCD detects change (polling 3min or webhook instant)
#    - Auto-syncs to cluster
#    - Health checks verify deployment
```

---

## 🔒 Security & Secrets

### Sealed Secrets (Production)

**Setup:**
```bash
# Install Sealed Secrets controller (one-time)
kubectl apply -f components/sealed-secrets/controller.yaml

# Fetch public key
kubeseal --fetch-cert > sealed-secrets-public-key.pem
```

**Create sealed secret:**
```bash
# 1. Create plain secret (DO NOT COMMIT!)
kubectl create secret generic network-ad-admin \
    --from-literal=password='SUPER_SECRET_PASSWORD' \
    --dry-run=client -o yaml > /tmp/network-ad-admin.yaml

# 2. Seal it (encrypted, safe to commit)
kubeseal --cert sealed-secrets-public-key.pem \
    --format yaml < /tmp/network-ad-admin.yaml \
    > environments/production/sealed-secrets/network-ad-admin.yaml

# 3. Commit sealed secret to Git
git add environments/production/sealed-secrets/network-ad-admin.yaml
git commit -m "chore(secrets): add sealed secret for Network AD admin"

# 4. Delete plain secret
rm /tmp/network-ad-admin.yaml
```

**In kustomization.yaml:**
```yaml
# apps/network-ad/overlays/production/kustomization.yaml
resources:
  - ../../base
  - ../../../../environments/production/sealed-secrets/network-ad-admin.yaml
```

---

## 📝 Naming Conventions

### File Naming

**Manifests:**
- `<kind>-<name>.yaml` (e.g., `statefulset-network-ad.yaml`)
- `configmap-<purpose>.yaml` (e.g., `configmap-smb-conf.yaml`)
- `secret.yaml` (generic name, details in labels)

**Directories:**
- Lowercase with hyphens: `network-ad`, `freeradius`, `mon-logging`
- No underscores, no camelCase

### Resource Naming (in manifests)

**Kubernetes resources:**
```yaml
# Format: <app>-<component>-<optional-descriptor>
metadata:
  name: network-ad-primary         # StatefulSet
  name: freeradius-ldap-config     # ConfigMap
  name: prometheus-snmp-exporter   # Deployment
```

**Labels (mandatory):**
```yaml
metadata:
  labels:
    app.kubernetes.io/name: network-ad
    app.kubernetes.io/component: domain-controller
    app.kubernetes.io/part-of: core-auth
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/instance: network-ad-prod
    environment: production
```

---

## 🚀 Deployment

### Bootstrap Process

**1. Install ArgoCD:**
```bash
kubectl apply -f argocd/bootstrap/argocd-install.yaml
kubectl apply -f argocd/bootstrap/argocd-cm.yaml
kubectl apply -f argocd/bootstrap/argocd-rbac-cm.yaml
```

**2. Add Git repository:**
```bash
argocd repo add https://github.com/zsel-opole/zsel-opole-org.git \
    --ssh-private-key-path ~/.ssh/id_ed25519 \
    --name zsel-infra
```

**3. Deploy App of Apps:**
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

**4. Wait for sync:**
```bash
argocd app wait app-of-apps --health
```

**5. Verify all applications:**
```bash
argocd app list
# Expected: 12 applications (network-ad, freeradius, dns, ntp, dhcp, minio, prometheus, grafana, alertmanager, graylog, zabbix, user-ad)
```

---

## 🧪 Testing & Validation

### Pre-commit Hooks

**Install:**
```bash
pip install pre-commit
pre-commit install
```

**`.pre-commit-config.yaml`:**
```yaml
repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.32.0
    hooks:
      - id: yamllint
        args: [--strict, -c, .yamllint]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-merge-conflict

  - repo: local
    hooks:
      - id: kustomize-build
        name: Kustomize Build Test
        entry: bash -c 'kubectl kustomize apps/*/overlays/production'
        language: system
        pass_filenames: false
```

### CI/CD Pipeline (GitHub Actions)

**`.github/workflows/gitops-validate.yaml`:**
```yaml
name: GitOps Validation
on:
  pull_request:
    paths:
      - 'infrastruktura-k3s/gitops/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: YAML Lint
        run: yamllint -c .yamllint infrastruktura-k3s/gitops/
      
      - name: Kustomize Build
        run: |
          for app in apps/*/overlays/production; do
            echo "Building $app..."
            kubectl kustomize $app
          done
      
      - name: Kubeconform Schema Validation
        uses: docker://ghcr.io/yannh/kubeconform:latest
        with:
          args: -summary -output json apps/*/overlays/production
      
      - name: Trivy Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: 'infrastruktura-k3s/gitops/'
```

---

## 🔍 Monitoring

### ArgoCD Health Status

**Green (Healthy):**
- All pods Running + Ready
- Services have endpoints
- StatefulSets have all replicas

**Yellow (Progressing):**
- Deployment rolling update
- StatefulSet updating pods
- PVC provisioning

**Red (Degraded):**
- Pods CrashLoopBackOff
- ImagePullBackOff
- OOMKilled

**Check via CLI:**
```bash
argocd app get network-ad --show-operation
```

**Check via UI:**
- https://argocd.zsel.internal/applications

---

## 📚 CODEOWNERS

**`CODEOWNERS` file:**
```
# GitOps Repository Code Owners

# Global owners (all files)
* @zsel-opole/it-admins

# Core authentication (Network AD, RADIUS)
/infrastruktura-k3s/gitops/apps/network-ad/ @lkolodziej @network-admin
/infrastruktura-k3s/gitops/apps/freeradius/ @lkolodziej @network-admin

# Monitoring (Prometheus, Grafana, Zabbix)
/infrastruktura-k3s/gitops/apps/prometheus/ @monitoring-team
/infrastruktura-k3s/gitops/apps/grafana/ @monitoring-team
/infrastruktura-k3s/gitops/apps/zabbix/ @monitoring-team

# Sealed secrets (require 2 approvals)
/infrastruktura-k3s/gitops/environments/production/sealed-secrets/ @lkolodziej @security-admin

# ArgoCD config (require 2 approvals)
/infrastruktura-k3s/gitops/argocd/ @lkolodziej @it-manager
```

---

## ✅ Best Practices Checklist

- [ ] All manifests pass yamllint
- [ ] All apps have base + overlays (dev/production)
- [ ] Secrets use Sealed Secrets (production only)
- [ ] Resources have CPU/memory limits
- [ ] PVCs use correct StorageClass (longhorn-fast)
- [ ] Services use correct type (ClusterIP/LoadBalancer)
- [ ] All resources have labels (app.kubernetes.io/*)
- [ ] All apps have README.md with configuration
- [ ] CODEOWNERS defined for sensitive paths
- [ ] Pre-commit hooks enabled
- [ ] CI/CD validates on every PR

---

**Status:** 🟢 Production Ready  
**Next Action:** Start implementing app manifests (network-ad first)  
**Owner:** Łukasz Kołodziej (Cloud Architect)

---

**Document Version:** 2.0  
**Last Updated:** 2025-11-22  
**Related Documents:**
- [AD-DOMAIN-SEPARATION.md](./docs/AD-DOMAIN-SEPARATION.md)
- [DEPLOYMENT-GUIDE.md](./docs/DEPLOYMENT-GUIDE.md)
- [NETWORK-SERVICES-ARCHITECTURE.md](../NETWORK-SERVICES-ARCHITECTURE.md)
