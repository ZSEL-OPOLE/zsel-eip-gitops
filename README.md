# 🚀 ZSEL EIP GitOps Repository

**Kompletna infrastruktura edukacyjna dla Zespołu Szkół Elektronicznych i Logistycznych w Opolu**

[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo)](https://argoproj.github.io/cd/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform)](https://terraform.io/)

---

## 📋 Przegląd

### Infrastruktura
- **39 aplikacji** (LMS, GitLab, NextCloud, BigBlueButton, AI/ML...)
- **47 namespaces** (1 aplikacja = 1 namespace)
- **9 × Mac Pro M2 Ultra** (216 cores, 1728 GB RAM, 72 TB storage)
- **1030 użytkowników** (900 uczniów + 100 nauczycieli + 30 admin)
- **6 domen** (zsel.opole.pl, bcu.com.pl, sue.opole.pl, mrsu.pl, elektryk.opole.pl, k4tec.pl)

### Technologie
- **Kubernetes:** K3s (ARM64-optimized dla Apple Silicon)
- **GitOps:** ArgoCD (App-of-Apps pattern, 10 sync-waves)
- **Storage:** Longhorn distributed (3 tiers: critical/standard/bulk)
- **Security:** Sealed Secrets, Zero Trust (280 NetworkPolicies), FreeIPA LDAP
- **Monitoring:** Prometheus, Grafana, Loki, Zabbix, Falco
- **Backup:** Velero (cluster), Longhorn snapshots, DB dumps, offsite replication

---

## 🗂️ Struktura repozytorium

```
zsel-eip-gitops/
├── apps/                           # ArgoCD Application manifests (39 apps)
│   ├── argocd-root/                # [Wave 0] App-of-Apps
│   ├── sealed-secrets/             # [Wave 5] Secret encryption
│   ├── metallb/                    # [Wave 10] LoadBalancer
│   ├── traefik-ingress/            # [Wave 10] Ingress controller
│   ├── freeipa/                    # [Wave 10] LDAP/Kerberos/DNS
│   ├── keycloak/                   # [Wave 10] SSO (25 apps)
│   ├── longhorn/                   # [Wave 10] Distributed storage
│   ├── coredns/                    # [Wave 10] DNS
│   ├── prometheus/                 # [Wave 15] Metrics
│   ├── loki/                       # [Wave 15] Logs
│   ├── falco/                      # [Wave 15] Runtime security
│   ├── trivy-operator/             # [Wave 15] Vulnerability scanning
│   ├── opa-gatekeeper/             # [Wave 15] Policy enforcement
│   ├── wireguard-vpn/              # [Wave 15] VPN (100 users)
│   ├── zabbix/                     # [Wave 15] Infrastructure monitoring
│   ├── wazuh/                      # [Wave 15] SIEM
│   ├── postgresql-ha/              # [Wave 20] Database (16 apps)
│   ├── mysql-ha/                   # [Wave 20] Database (legacy)
│   ├── moodle/                     # [Wave 25] LMS (500GB)
│   ├── nextcloud/                  # [Wave 25] Cloud storage (150TB NAS)
│   ├── bigbluebutton/              # [Wave 25] Video conferencing
│   ├── mattermost/                 # [Wave 25] Chat/collaboration
│   ├── onlyoffice/                 # [Wave 25] Office suite
│   ├── etherpad/                   # [Wave 25] Collaborative editing
│   ├── calibre-web/                # [Wave 25] E-library (500GB)
│   ├── minio/                      # [Wave 25] S3 storage (8TB)
│   ├── gitlab/                     # [Wave 30] DevOps platform
│   ├── harbor/                     # [Wave 30] Container registry
│   ├── mailu/                      # [Wave 30] Mail server (6 domains)
│   ├── portainer/                  # [Wave 35] K8s management UI
│   ├── zammad/                     # [Wave 35] Helpdesk/ticketing
│   ├── ollama/                     # [Wave 40] LLM inference (4 models)
│   ├── jupyterhub/                 # [Wave 40] Data science notebooks
│   └── qdrant/                     # [Wave 40] Vector database
│
├── sealed-secrets/                 # Encrypted secrets (50+ files)
│   ├── core-freeipa-*.yaml
│   ├── core-keycloak-*.yaml
│   ├── db-postgres-*.yaml
│   ├── edu-moodle-*.yaml
│   └── ...
│
├── scripts/                        # Automation scripts
│   ├── generate-sealed-secrets.ps1 # Auto-generate 50+ secrets
│   ├── validate-images.ps1         # Check latest stable versions
│   └── backup-cluster.ps1          # Full cluster backup
│
├── docs/                           # Documentation
│   ├── SEALED-SECRETS-SECURITY.md  # Security documentation
│   ├── DEPLOYMENT-PLAN.md          # Detailed deployment guide
│   └── TROUBLESHOOTING.md          # Common issues & solutions
│
├── QUICKSTART.md                   # 🚀 Start here! (8-step guide)
├── README.md                       # This file
└── .gitignore                      # Excludes sensitive files

```

---

## 🎯 Quick Start (5 minut)

### Wymagania:
```powershell
choco install kubernetes-cli kubernetes-helm kubeseal terraform argocd
```

### Deployment (3 kroki):
```powershell
# 1. Wygeneruj sekrety
cd scripts
.\generate-sealed-secrets.ps1

# 2. Terraform infra
cd ../terraform/environments/production
terraform init && terraform apply -auto-approve

# 3. ArgoCD deployment
cd ../../gitops
kubectl apply -f apps/argocd-root/application.yaml

# Obserwuj: https://localhost:8080 (ArgoCD UI)
# Wszystkie 39 aplikacji zdeployują się automatycznie w ~30 minut!
```

**Szczegółowa instrukcja:** [QUICKSTART.md](QUICKSTART.md)

---

## 🌍 Środowiska

### DEV (Development)
- **Cel:** Testowanie, eksperymentowanie, CI/CD
- **Hardware:** 1-3 Mac Pro M2 Ultra (scale 1:3)
- **Namespaces:** 11 (subset PROD)
- **Replication:** 1 (no HA)
- **Network Policies:** Relaxed (debugging-friendly)
- **Deployment:** Auto-deploy from `develop` branch
- **URL:** https://dev.zsel.opole.pl

### PROD (Production)
- **Cel:** Usługi produkcyjne (1030 użytkowników)
- **Hardware:** 9 Mac Pro M2 Ultra (full scale)
- **Namespaces:** 47 (complete)
- **Replication:** 3 (HA for critical)
- **Network Policies:** Zero Trust (default-deny)
- **Deployment:** Manual approval gate (2/3 approvers)
- **URL:** https://zsel.opole.pl

**Terraform:** Separate configs in `terraform/environments/{development,production}`

---

## 📊 Aplikacje (39 total)

### Core Infrastructure (Wave 10)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **MetalLB** | LoadBalancer (IP pool: 192.168.30.20-100) | 512Mi, 500m | ✅ |
| **Traefik** | Ingress controller (SSL, HTTP/2, WebSocket) | 2Gi, 1 CPU | ✅ |
| **FreeIPA** | LDAP/Kerberos/DNS (1030 users, 2 replicas) | 16Gi, 8 CPU | ✅ |
| **Keycloak** | SSO for 25 apps (OIDC/SAML, FreeIPA federation) | 8Gi, 4 CPU | ✅ |
| **Longhorn** | Distributed storage (40TB, 3 tiers) | 36Gi, 18 CPU | ✅ |
| **CoreDNS** | Cluster DNS (FreeIPA forwarding) | 512Mi, 250m | ✅ |

### Security & Monitoring (Wave 15)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **Prometheus** | Metrics (30d retention, 200Gi) | 32Gi, 4 CPU | ✅ |
| **Grafana** | Dashboards (2 replicas) | 8Gi, 1 CPU | ✅ |
| **Loki** | Logs (2-year retention, 500Gi) | 48Gi, 6 CPU | ✅ |
| **Falco** | Runtime security (eBPF, syscall monitoring) | 2Gi, 1 CPU | ✅ |
| **Trivy** | Vulnerability scanning (daily) | 4Gi, 1 CPU | ✅ |
| **OPA** | Policy enforcement (280 policies) | 4Gi, 1 CPU | ✅ |
| **WireGuard** | VPN (100 users, 192.168.30.60) | 4Gi, 2 CPU | ✅ |
| **Zabbix** | Infra monitoring (9 nodes + 57 MikroTik) | 16Gi, 4 CPU | ✅ |
| **Wazuh** | SIEM (security events) | 8Gi, 2 CPU | ✅ |

### Databases (Wave 20)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **PostgreSQL HA** | 3-node cluster (1Ti per node, Patroni) | 72Gi, 12 CPU | ✅ |
| **MySQL HA** | 3-node Galera (500Gi per node) | 48Gi, 6 CPU | ✅ |

### Education (Wave 25)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **Moodle** | LMS (500GB, PostgreSQL, LDAP) | 16Gi, 8 CPU | ✅ |
| **NextCloud** | Cloud storage (150TB NAS) | 8Gi, 4 CPU | ✅ |
| **BigBlueButton** | Video conferencing (3 replicas, 3Ti recordings) | 96Gi, 24 CPU | ✅ |
| **Mattermost** | Team chat (PostgreSQL, SSO) | 16Gi, 4 CPU | ✅ |
| **OnlyOffice** | Office suite (NextCloud integration) | 32Gi, 8 CPU | ✅ |
| **Etherpad** | Collaborative editing (LDAP) | 8Gi, 2 CPU | ✅ |
| **Calibre-Web** | E-library (500GB books) | 4Gi, 1 CPU | ✅ |
| **MinIO** | S3 storage (4 replicas, 8Ti) | 64Gi, 8 CPU | ✅ |

### DevOps (Wave 30)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **GitLab** | DevOps platform (2Ti Gitaly, LDAP) | 32Gi, 8 CPU | ✅ |
| **Harbor** | Container registry (2Ti, Trivy, Notary) | 24Gi, 6 CPU | ✅ |
| **Portainer** | K8s management UI (SSO) | 4Gi, 1 CPU | ✅ |
| **Zammad** | Helpdesk/ticketing (Elasticsearch, LDAP) | 16Gi, 4 CPU | ✅ |

### Communication (Wave 30)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **Mailu** | Mail server (6 domains, 2Ti storage, antivirus) | 32Gi, 8 CPU | ✅ |

### AI/ML (Wave 40)
| Aplikacja | Opis | Zasoby | Status |
|-----------|------|--------|--------|
| **Ollama** | LLM inference (4 models: llama3, codellama, mistral, phi3) | 64Gi, 8 CPU | ✅ |
| **JupyterHub** | Data science notebooks (LDAP, 50Gi per user) | 16Gi, 2 CPU | ✅ |
| **Qdrant** | Vector database (500Gi, 2 replicas) | 64Gi, 8 CPU | ✅ |

**TOTAL:** ~720 GB RAM, ~204 CPU cores, ~29 TB storage

---

## 🔐 Security Features

### ✅ Implemented:
- **Zero Trust Network Policies:** 280 policies (47 namespaces × 6 rules)
- **Sealed Secrets:** 50+ encrypted credentials (Bitnami, RSA-4096)
- **RBAC:** 141 RoleBindings (admin, developer, viewer per namespace)
- **FreeIPA:** Centralized LDAP/Kerberos/DNS/CA (1030 users)
- **Keycloak SSO:** OIDC/SAML for 25 applications
- **Runtime Security:** Falco (eBPF syscall monitoring)
- **Vulnerability Scanning:** Trivy Operator (daily automated)
- **Policy Enforcement:** OPA Gatekeeper (admission control)
- **SIEM:** Wazuh (security event correlation)
- **VPN:** WireGuard (100 concurrent users, 192.168.30.60)

### 🔒 CI/CD Security Gates:
- **Stage 1:** Syntax & linting (Terraform, YAML, Markdown)
- **Stage 2:** Security scanning (Trivy, kubesec, Checkov, TFSec, Gitleaks)
- **Stage 3:** Quality checks (kubeconform, OPA, resource quotas)
- **Stage 4:** Integration testing (DEV deployment + smoke tests)
- **Stage 5:** Manual approval gate (PROD only, 2/3 approvers)
- **Stage 6:** Progressive PROD deployment with health checks
- **Stage 7:** Post-deployment validation (E2E, performance, security)

### 🔒 Compliance:
- **RODO/GDPR:** 90-day retention, encrypted backups, right to deletion
- **FIPS 140-2:** Cryptographic operations (Sealed Secrets, TLS)
- **Zero Trust:** Default-deny NetworkPolicies, explicit allow only

---

## 💾 Backup & Disaster Recovery

### 4-Layer Strategy:
1. **Cluster (Velero):** Daily full + hourly incremental
2. **Volumes (Longhorn):** Hourly snapshots (S3 backup to MinIO)
3. **Databases:** pg_dump/mysqldump every 6 hours
4. **Offsite:** Rsync to secondary location daily

### RTO/RPO:
- **RTO (Recovery Time Objective):** 4 hours
- **RPO (Recovery Point Objective):** 6 hours
- **Retention:** 90 days (RODO compliance)

**Dokumentacja:** [DR-BACKUP-SCALING-STRATEGY.md](../zsel-eip-dokumentacja/deployment/DR-BACKUP-SCALING-STRATEGY.md)

---

## 📈 Monitoring & Observability

### Metrics (Prometheus):
- 300+ targets (pods, services, nodes)
- 30-day retention (200Gi storage)
- 2-minute scrape interval
- **Dashboards:** 20+ Grafana dashboards

### Logs (Loki):
- 2-year retention (RODO requirement)
- 500Gi storage
- Promtail collectors on all nodes
- **Query:** `{namespace="edu-moodle"} |= "error"`

### Infrastructure (Zabbix):
- 9 × Mac Pro M2 Ultra nodes
- 57 × MikroTik routers/switches
- 39 × Application health checks
- **Alerting:** Mattermost webhooks

### Security (Falco + Wazuh):
- Syscall monitoring (eBPF)
- Intrusion detection
- SIEM event correlation
- **Alerts:** Prometheus + Mattermost

---

## 🚀 Deployment Architecture

### ArgoCD Sync Waves:
```
Wave 0  (0 min):   ArgoCD Root (App-of-Apps)
Wave 5  (2 min):   Sealed Secrets Controller
Wave 10 (5 min):   Core Infrastructure (6 apps)
Wave 15 (15 min):  Security & Monitoring (10 apps)
Wave 20 (20 min):  Databases (2 apps)
Wave 25 (25 min):  Education (8 apps)
Wave 30 (28 min):  DevOps + Communication (5 apps)
Wave 40 (30 min):  AI/ML (3 apps)
```

### GitOps Workflow:
```
Developer → Git Push → ArgoCD detects change → Sync → Kubernetes
                                                ↓
                                        Health Check
                                                ↓
                                        Rollback if failed
```

---

## 📚 Dokumentacja

| Dokument | Opis |
|----------|------|
| [QUICKSTART.md](QUICKSTART.md) | 🚀 Szybki start (8 kroków, 2.5h) |
| [DEPLOYMENT-PROCESS.md](../zsel-eip-dokumentacja/deployment/DEPLOYMENT-PROCESS.md) | 📋 **Procesy wdrożeniowe** (7-stage pipeline, quality gates) |
| [SEALED-SECRETS-SECURITY.md](docs/SEALED-SECRETS-SECURITY.md) | 🔐 Security documentation (50 secrets) |
| [IMAGE-VALIDATION-REPORT.md](../zsel-eip-dokumentacja/deployment/IMAGE-VALIDATION-REPORT.md) | ✅ Container image validation (39 apps) |
| [DR-BACKUP-SCALING-STRATEGY.md](../zsel-eip-dokumentacja/deployment/DR-BACKUP-SCALING-STRATEGY.md) | 💾 Disaster recovery (4-layer strategy) |
| [GITOPS-STRUCTURE.md](../zsel-eip-dokumentacja/deployment/GITOPS-STRUCTURE.md) | 📁 Repository structure (47 namespaces) |

### 🛠️ Scripts & Automation

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/generate-sealed-secrets.ps1` | Auto-generate 50+ secrets (CSPRNG, 191-512 bit entropy) | `.\generate-sealed-secrets.ps1` |
| `scripts/validate-pre-deployment.ps1` | 25-check validation (Terraform, YAML, security, compliance) | `.\validate-pre-deployment.ps1 -Environment production` |
| `scripts/security-scan.ps1` | Security scanning (Trivy, kubesec, kube-bench, OPA) | `.\security-scan.ps1 -ScanType full` |
| `.github/workflows/ci-cd-pipeline.yml` | GitHub Actions CI/CD (7 stages, approval gates) | Automatic on push/PR |

---

## 🔄 CI/CD Pipeline

### Workflow Stages
```
1. Pre-Validation    ← Syntax, linting (1-2 min)
2. Security Scan     ← Trivy, kubesec, Gitleaks (3-5 min)
3. Quality Checks    ← kubeconform, OPA, quotas (2-3 min)
4. DEV Deployment    ← Auto-deploy + integration tests (10-15 min)
5. Approval Gate     ← Manual review (PROD only, 2/3 approvers)
6. PROD Deployment   ← Progressive sync + health checks (20-30 min)
7. Post-Validation   ← E2E, performance, security (5-10 min)
```

### Quality Metrics
- **Security:** 0 CRITICAL, 0 HIGH vulnerabilities
- **Syntax:** 100% Terraform/YAML valid
- **Coverage:** 100% NetworkPolicies, 100% RBAC
- **Success Rate:** Target >= 95%

**Full documentation:** [DEPLOYMENT-PROCESS.md](../zsel-eip-dokumentacja/deployment/DEPLOYMENT-PROCESS.md)

---

## 📚 Dokumentacja (Legacy)

---

## 🛠️ Development

### Prerequisites:
```powershell
# Required tools
choco install git kubectl kubernetes-helm terraform argocd kubeseal

# Optional (for local testing)
choco install kind k3d docker-desktop
```

### Local Testing (kind cluster):
```powershell
# Create 3-node cluster
kind create cluster --config kind-config.yaml

# Deploy subset of apps
kubectl apply -f apps/argocd-root/application.yaml
kubectl apply -f apps/metallb/application.yaml
kubectl apply -f apps/traefik-ingress/application.yaml
```

### Contributing:
1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'feat: add amazing feature'`
4. Push: `git push origin feature/amazing-feature`
5. Open Pull Request

---

## 🆘 Support & Troubleshooting

### Common Issues:
| Problem | Solution |
|---------|----------|
| Pod in CrashLoopBackOff | `kubectl describe pod <name> -n <ns>` → check events |
| PVC Pending | Check Longhorn operational + storage available |
| Ingress not accessible | Verify Traefik running + DNS resolution |
| LDAP auth fails | Test FreeIPA: `kubectl exec -n core-freeipa freeipa-0 -- ipa ping` |

### Logs:
```powershell
# Application logs
kubectl logs -n <namespace> <pod-name> -f

# ArgoCD sync logs
argocd app logs <app-name> -f

# Sealed Secrets controller
kubectl logs -n kube-system -l name=sealed-secrets-controller -f
```

### Health Checks:
```powershell
# All applications status
kubectl get applications -n argocd

# Pods health
kubectl get pods -A | findstr -v "Running\|Completed"

# Storage
kubectl get pvc -A | findstr "Pending"
```

**Full guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 📊 Resource Allocation

| Category | Apps | CPU | RAM | Storage |
|----------|------|-----|-----|---------|
| Core Infrastructure | 6 | 31 | 62 GB | 400 GB |
| Security & Monitoring | 10 | 45 | 120 GB | 1.8 TB |
| Databases | 2 | 24 | 96 GB | 4 TB |
| Education | 8 | 52 | 210 GB | 11 TB |
| DevOps + Comms | 5 | 28 | 88 GB | 8.5 TB |
| AI/ML | 3 | 24 | 144 GB | 3 TB |
| **TOTAL** | **39** | **204** | **720 GB** | **29 TB** |
| **Hardware** | - | 216 | 1728 GB | 40 TB (Longhorn) + 150 TB (NAS) |
| **Buffer** | - | 6% | 58% | 27% + 150 TB |

**Hardware:** 9 × Mac Pro M2 Ultra (24-core CPU, 192GB RAM, 8TB NVMe each)

---

## 📞 Contact

**Organization:** Zespół Szkół Elektronicznych i Logistycznych w Opolu  
**Website:** https://zsel.opole.pl  
**Email:** it@zsel.opole.pl  
**GitHub:** https://github.com/zsel-opole/

**Maintainers:**
- DevOps Team: devops@zsel.opole.pl
- Security Team: security@zsel.opole.pl

---

## 📄 License

**Proprietary** - © 2025 ZSEL Opole. All rights reserved.

This repository contains proprietary software and configuration for ZSEL infrastructure.  
Unauthorized copying, distribution, or use is strictly prohibited.

---

## 🏆 Credits

Built with:
- [Kubernetes (K3s)](https://k3s.io/) - Lightweight Kubernetes
- [ArgoCD](https://argoproj.github.io/cd/) - GitOps continuous delivery
- [Terraform](https://terraform.io/) - Infrastructure as Code
- [Longhorn](https://longhorn.io/) - Distributed block storage
- [Prometheus](https://prometheus.io/) - Monitoring & alerting
- [FreeIPA](https://www.freeipa.org/) - Identity management

---

**Status:** ✅ Production Ready  
**Last updated:** 25 listopada 2025  
**Version:** 1.0.0
