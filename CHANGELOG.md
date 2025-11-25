# Changelog - ZSEL EIP Infrastructure

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2025-11-25

### 🎉 Major Features Added

#### Environment Separation (DEV vs PROD)
- **DEV Environment:**
  - Created separate Terraform configuration (`terraform/environments/development/`)
  - 11 namespaces (subset of PROD for testing)
  - Single replica (no HA, faster testing)
  - Relaxed network policies (allow-all for debugging)
  - Auto-deploy from `develop` branch
  - 7-day metrics retention, 30-day logs
  - URL: https://dev.zsel.opole.pl

- **PROD Environment:**
  - Enhanced Terraform configuration (`terraform/environments/production/`)
  - 47 namespaces (complete production setup)
  - 3-replica HA for critical services
  - Zero Trust network policies (default-deny)
  - Manual approval gate (2/3 approvers required)
  - 30-day metrics retention, 2-year logs (RODO compliance)
  - URL: https://zsel.opole.pl

#### CI/CD Pipeline with Quality Gates
- **GitHub Actions Workflow** (`.github/workflows/ci-cd-pipeline.yml`)
  - **Stage 1:** Pre-validation (Terraform fmt/validate, YAML lint, Markdown lint)
  - **Stage 2:** Security scanning (Trivy, kubesec, Checkov, TFSec, Gitleaks)
  - **Stage 3:** Quality checks (kubeconform, OPA, resource quotas, RODO compliance)
  - **Stage 4:** Integration testing (DEV auto-deploy + smoke tests)
  - **Stage 5:** Manual approval gate (PROD only, GitHub Environment Protection)
  - **Stage 6:** Progressive PROD deployment (sync waves + health checks)
  - **Stage 7:** Post-deployment validation (E2E tests, performance, security scan)

#### Validation & Security Scripts
- **Pre-Deployment Validator** (`scripts/validate-pre-deployment.ps1`)
  - 25 comprehensive checks across 5 categories:
    1. Prerequisites & Tools (5 checks)
    2. Terraform Validation (5 checks)
    3. YAML Validation (5 checks)
    4. Security Checks (5 checks)
    5. Quality & Compliance (5 checks)
  - Exit codes: 0 (pass), 1 (fail - blocking)
  - Colored output with pass/warn/fail indicators
  - Verbose mode for detailed error messages

- **Security Scanner** (`scripts/security-scan.ps1`)
  - Integrated security tools:
    - **Trivy:** Container image vulnerability scanning
    - **kubesec:** Kubernetes security risk analysis
    - **kube-bench:** CIS Kubernetes benchmark
    - **OPA:** Policy validation
    - **Custom validators:** 5 additional security checks
  - Scan modes: quick, full, pre-commit
  - JSON/SARIF output formats
  - Fail-on-high option for CI/CD

#### Process Documentation
- **Deployment Process Guide** (`docs/DEPLOYMENT-PROCESS.md`)
  - Complete 7-stage workflow with detailed instructions
  - Quality metrics and SLOs
  - Approval process and checklists
  - Rollback procedures
  - Troubleshooting section
  - Contact information for on-call team

### 🔒 Security Enhancements

#### Automated Security Scanning
- Container image vulnerability scanning (Trivy)
- Kubernetes security posture validation (kubesec)
- CIS benchmark compliance (kube-bench)
- Infrastructure as Code security (Checkov, TFSec)
- Secret detection in git history (Gitleaks)
- Custom security validators (5 checks)

#### Quality Gates
- **Mandatory checks before deployment:**
  - 0 CRITICAL vulnerabilities
  - 0 HIGH vulnerabilities (or approved exceptions)
  - 100% Terraform syntax valid
  - 100% YAML syntax valid
  - >= 80% NetworkPolicy coverage
  - >= 90% resource limits defined
  - RODO/GDPR compliance verified

#### Approval Workflow
- **PROD deployments require 2/3 approvals from:**
  - DevOps Lead
  - Security Lead
  - IT Director
- GitHub Environment Protection with required reviewers
- Approval checklist with 7 verification points
- Automatic rollback on health check failure

### 📊 Monitoring & Compliance

#### Metrics Tracking
- **Code Quality:**
  - Terraform format compliance: 100%
  - YAML lint errors: 0
  - Kubernetes manifest validity: 100%
  - Markdown lint warnings: < 5

- **Security:**
  - CRITICAL vulnerabilities: 0
  - HIGH vulnerabilities: 0
  - Hardcoded secrets: 0
  - Untrusted image sources: 0
  - NetworkPolicy coverage: 100%

- **Deployment:**
  - Target success rate: >= 95%
  - Target rollback rate: < 5%
  - DEV deployment time: < 15 min
  - PROD deployment time: < 30 min
  - Zero downtime deployments

#### RODO/GDPR Compliance
- Automated retention policy checks
- Encryption at rest verification
- Backup compliance validation
- Right to deletion procedures
- Data protection measures documented

### 🛠️ Developer Experience

#### Improved Workflows
- Clear separation of DEV and PROD environments
- Faster feedback loop (DEV auto-deploy in ~15 min)
- Automated security checks (no manual scans)
- Pre-commit validation available
- Comprehensive error messages

#### Documentation
- Process documentation with flowcharts
- Troubleshooting guides
- Contact information for escalations
- Approval checklists
- Rollback procedures

### 🔄 Changed

#### Terraform
- Split configuration into `environments/development` and `environments/production`
- DEV: Reduced resource quotas (1/3 of PROD)
- DEV: Single replica for all services
- DEV: Relaxed network policies (allow-all by default)
- PROD: Enhanced with approval gates

#### ArgoCD
- DEV: Auto-sync from `develop` branch
- PROD: Manual approval required (from `main` branch)
- Progressive sync with health checks per wave
- Automatic rollback on degraded state

#### Documentation
- Updated README.md with environment information
- Added CI/CD pipeline documentation
- Added security scanning documentation
- Added deployment process guide

### 🐛 Fixed

#### Terraform
- Fixed DEV environment Terraform syntax
- Corrected variable definitions for DEV
- Aligned storage class configuration

#### YAML
- Fixed indentation errors in FreeIPA manifests
- Fixed indentation errors in BigBlueButton manifests
- Validated all ArgoCD Application specs

#### Container Images
- Updated Keycloak to 24.0.1 (from 18.4.0 - EOL)
- Updated WireGuard to latest (from 2021 version)
- Updated MinIO to RELEASE.2024-11-07 (from old version)
- Added imagePullPolicy to all manifests

### 📁 File Structure Changes

```
zsel-eip-terraform/
├── environments/
│   ├── development/          # NEW: DEV environment
│   │   ├── main.tf           # NEW: DEV Terraform config
│   │   └── variables.tf      # NEW: DEV variables (11 namespaces)
│   └── production/           # UPDATED: PROD environment
│       ├── main.tf           # Existing
│       └── variables.tf      # Existing (47 namespaces)

zsel-eip-gitops/
├── .github/
│   └── workflows/
│       └── ci-cd-pipeline.yml  # NEW: 7-stage CI/CD pipeline
├── scripts/
│   ├── generate-sealed-secrets.ps1      # Existing
│   ├── validate-pre-deployment.ps1      # NEW: 25-check validator
│   └── security-scan.ps1                # NEW: Security automation
└── README.md                            # UPDATED: Added DEV/PROD info

zsel-eip-dokumentacja/
└── deployment/
    ├── DEPLOYMENT-PROCESS.md            # NEW: Process documentation
    ├── IMAGE-VALIDATION-REPORT.md       # Existing
    └── DR-BACKUP-SCALING-STRATEGY.md    # Existing
```

---

## [1.0.0] - 2025-11-24

### 🎉 Initial Release

#### Infrastructure
- 39 ArgoCD Applications (100% complete)
- 47 Kubernetes namespaces (Terraform managed)
- 280 Network Policies (Zero Trust)
- 141 RBAC RoleBindings
- 50+ Sealed Secrets (automated generation)

#### Documentation
- QUICKSTART.md (8-step deployment guide)
- SEALED-SECRETS-SECURITY.md (comprehensive security docs)
- IMAGE-VALIDATION-REPORT.md (39 apps validated)
- DR-BACKUP-SCALING-STRATEGY.md (4-layer backup)
- GITOPS-STRUCTURE.md (repository structure)

#### Security
- Sealed Secrets with CSPRNG (191-512 bit entropy)
- All container images from official sources
- Zero Trust network policies
- RBAC for all namespaces
- RODO/GDPR compliant

---

## Upgrade Guide

### From 1.0.0 to 1.1.0

#### 1. Update Git Repository
```bash
git pull origin main
```

#### 2. Choose Environment

**For DEV cluster:**
```bash
cd terraform/environments/development
terraform init
terraform plan
terraform apply
```

**For PROD cluster:**
```bash
cd terraform/environments/production
terraform init
terraform plan
# Review plan carefully
terraform apply
```

#### 3. Run Pre-Deployment Validation
```powershell
.\scripts\validate-pre-deployment.ps1 -Environment production
```

#### 4. Run Security Scan
```powershell
.\scripts\security-scan.ps1 -ScanType full
```

#### 5. Deploy via CI/CD
```bash
# For DEV (auto-deploy)
git push origin develop

# For PROD (requires approval)
git push origin main
# Wait for approval from 2/3 reviewers
```

---

## Security Advisories

### [1.1.0] Critical Updates
- **Keycloak 18.4.0 → 24.0.1**: Fixed EOL version with known CVEs
- **WireGuard 2021 → latest**: Fixed 4-year-old version with security issues
- **MinIO → RELEASE.2024-11-07**: Performance and security improvements

### Recommendations
1. Run security scan before every deployment
2. Review approval checklist for PROD deployments
3. Monitor first 24 hours after PROD deployment
4. Keep DEV environment updated weekly
5. Rotate Sealed Secrets every 90 days (admin) / 180 days (services)

---

## Contributors

- **DevOps Team:** devops@zsel.opole.pl
- **Security Team:** security@zsel.opole.pl
- **IT Director:** it-director@zsel.opole.pl

---

## Links

- **Repository:** https://github.com/zsel-opole/zsel-eip-gitops
- **Documentation:** https://docs.zsel.opole.pl
- **CI/CD Dashboard:** https://github.com/zsel-opole/zsel-eip-gitops/actions
- **Monitoring:** https://grafana.zsel.opole.pl

---

**Maintained by:** ZSEL Opole IT Team  
**Last updated:** 2025-11-25
