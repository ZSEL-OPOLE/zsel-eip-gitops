# 🚀 Quick Start - Deployment ZSEL Infrastructure

## Przegląd
Kompletna infrastruktura 39 aplikacji dla 9 × Mac Pro M2 Ultra  
**Status:** ✅ Gotowe do deployment (dry-run validated)

---

## 📋 Wymagania wstępne

### Hardware:
- ✅ 9 × Mac Pro M2 Ultra (24-core CPU, 192GB RAM, 8TB NVMe każdy)
- ✅ Sieć: 10 Gbps Ethernet, VLAN segregation
- ✅ Storage: Synology NAS 200TB (dla NextCloud)

### Software:
```powershell
# Zainstaluj narzędzia
choco install kubernetes-cli          # kubectl
choco install kubernetes-helm         # helm
choco install kubeseal                # sealed-secrets
choco install terraform               # IaC
choco install argocd                  # GitOps

# Weryfikacja
kubectl version --client
helm version
kubeseal --version
terraform --version
argocd version --client
```

### K3s Cluster:
```bash
# Na każdym węźle Mac Pro (ARM64)
curl -sfL https://get.k3s.io | sh -s - --disable traefik

# Pobierz kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
```

---

## 🔐 Krok 1: Generowanie Sealed Secrets (15 minut)

### 1.1 Zainstaluj Sealed Secrets Controller
```powershell
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml

# Poczekaj na ready
kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n kube-system --timeout=300s
```

### 1.2 Wygeneruj wszystkie sekrety
```powershell
cd zsel-eip-gitops/scripts
.\generate-sealed-secrets.ps1

# Output: 50+ zaszyfrowanych plików w ../sealed-secrets/
```

### 1.3 Zapisz hasła administratorów
```powershell
# Skrypt wyświetli hasła na końcu - ZAPISZ JE BEZPIECZNIE!
# Przykład:
#   FreeIPA Admin: xK8m2P...
#   Keycloak Admin: 9fR4nT...
#   GitLab Root: hW7jQ5...
```

### 1.4 Commituj do Git
```powershell
cd ..
git add sealed-secrets/
git commit -m "feat: add sealed secrets for all 39 apps"
git push origin main
```

---

## 🏗️ Krok 2: Terraform - Infrastruktura (10 minut)

### 2.1 Inicjalizacja
```powershell
cd zsel-eip-terraform/environments/production
terraform init
```

### 2.2 Walidacja
```powershell
terraform validate
# Output: Success! The configuration is valid.

terraform plan
# Sprawdź: 450+ resources to create
```

### 2.3 Deployment
```powershell
terraform apply -auto-approve

# Co zostanie utworzone:
# ✅ 47 namespaces
# ✅ 141 RoleBindings (RBAC)
# ✅ 280 NetworkPolicies (Zero Trust)
# ✅ 3 StorageClasses (Longhorn tiers)
```

### 2.4 Weryfikacja
```powershell
kubectl get namespaces | findstr "core-\|edu-\|devops-\|mon-\|sec-\|ai-\|com-"
# Powinno być 47 namespaces
```

---

## 🎯 Krok 3: ArgoCD - GitOps Deployment (30 minut)

### 3.1 Zainstaluj ArgoCD
```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Poczekaj na ready (2-3 min)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s
```

### 3.2 Pobierz hasło administratora
```powershell
$ARGOCD_PASSWORD = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
Write-Host "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Ustaw port forwarding
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Otwórz: https://localhost:8080
# Login: admin / <hasło z powyższego>
```

### 3.3 Zastosuj App-of-Apps
```powershell
cd zsel-eip-gitops
kubectl apply -f apps/argocd-root/application.yaml

# ArgoCD automatycznie zdeployuje wszystkie 39 aplikacji!
```

### 3.4 Monitoruj deployment
```powershell
# CLI monitoring
kubectl get applications -n argocd --watch

# Lub w UI: https://localhost:8080
# Sekcja: Applications → Powinno być 39 aplikacji

# Sprawdź sync status
argocd app list
```

### 3.5 Sync waves (automatyczne, ~30 min)
ArgoCD deployuje w kolejności:
```
Wave 0  (0 min):   ArgoCD Root (1 app)
Wave 5  (2 min):   Sealed Secrets (1 app)
Wave 10 (5 min):   Core Infra (6 apps: MetalLB, Traefik, FreeIPA, Keycloak, Longhorn, CoreDNS)
Wave 15 (15 min):  Security (10 apps: Prometheus, Loki, Falco, Trivy, etc.)
Wave 20 (20 min):  Databases (2 apps: PostgreSQL HA, MySQL HA)
Wave 25 (25 min):  Education (8 apps: Moodle, NextCloud, BBB, etc.)
Wave 30 (28 min):  DevOps + Comms (4 apps: GitLab, Harbor, Mailu, etc.)
Wave 40 (30 min):  AI/ML (3 apps: Ollama, JupyterHub, Qdrant)
```

---

## ✅ Krok 4: Post-Deployment Verification (15 minut)

### 4.1 Sprawdź wszystkie pody
```powershell
kubectl get pods -A | findstr -v "Running\|Completed"
# Powinno być PUSTE (wszystkie Running/Completed)

# Szczegóły per namespace
kubectl get pods -n core-freeipa
kubectl get pods -n core-keycloak
kubectl get pods -n edu-moodle
```

### 4.2 Sprawdź LoadBalancer IPs
```powershell
kubectl get svc -A | findstr "LoadBalancer"

# Oczekiwane:
# core-ingress      traefik           LoadBalancer   192.168.30.10
# core-freeipa      freeipa-ldap      LoadBalancer   192.168.30.50
# core-keycloak     keycloak          LoadBalancer   192.168.30.51
# net-wireguard     wireguard-vpn     LoadBalancer   192.168.30.60
# mon-zabbix        zabbix-server     LoadBalancer   192.168.30.61
```

### 4.3 Sprawdź storage
```powershell
# Longhorn dashboard
kubectl port-forward -n core-storage svc/longhorn-frontend 9000:80
# Otwórz: http://localhost:9000

# Sprawdź volumes
kubectl get pvc -A | findstr "Bound"
# Wszystkie powinny być Bound
```

### 4.4 Sprawdź ingress
```powershell
kubectl get ingress -A

# Test HTTP
curl -k https://grafana.zsel.opole.pl
curl -k https://moodle.zsel.opole.pl
```

### 4.5 Sprawdź LDAP (FreeIPA)
```powershell
# Port forward
kubectl port-forward -n core-freeipa svc/freeipa-ldap 389:389

# Test LDAP bind
ldapsearch -x -H ldap://localhost:389 -D "uid=admin,cn=users,dc=zsel,dc=opole,dc=pl" -W -b "dc=zsel,dc=opole,dc=pl" "(uid=*)" uid
```

---

## 🔍 Krok 5: Monitoring Setup (10 minut)

### 5.1 Grafana Dashboard
```powershell
# Port forward
kubectl port-forward -n mon-prometheus svc/prometheus-grafana 3000:80

# Otwórz: http://localhost:3000
# Login: admin / <hasło z sealed secret>

# Import dashboards:
# - Kubernetes Cluster Monitoring (ID: 7249)
# - Node Exporter Full (ID: 1860)
# - PostgreSQL Database (ID: 9628)
# - Longhorn (ID: 13032)
```

### 5.2 Prometheus Targets
```powershell
kubectl port-forward -n mon-prometheus svc/prometheus-kube-prometheus-prometheus 9090:9090

# Otwórz: http://localhost:9090/targets
# Sprawdź: Wszystkie targets "UP"
```

### 5.3 Loki Logs
```powershell
# W Grafana → Explore → Data Source: Loki
# Query przykład:
{namespace="edu-moodle"} |= "error"
```

### 5.4 Zabbix Monitoring
```powershell
kubectl port-forward -n mon-zabbix svc/zabbix-web 8080:8080

# Otwórz: http://localhost:8080
# Login: Admin / <hasło z sealed secret>

# Dodaj hosts:
# - 9 × Mac Pro M2 Ultra (K3s nodes)
# - 57 × MikroTik routers/switches
```

---

## 🎓 Krok 6: Konfiguracja aplikacji edukacyjnych (30 minut)

### 6.1 FreeIPA - Import użytkowników
```powershell
# Port forward
kubectl port-forward -n core-freeipa svc/freeipa 443:443

# Otwórz: https://localhost:443
# Login: admin / <hasło z sealed secret>

# Import LDIF (1030 użytkowników)
kubectl exec -n core-freeipa freeipa-0 -- ipa user-add --first=Jan --last=Kowalski --cn="Jan Kowalski" jkowalski

# Bulk import via CSV (przygotuj skrypt)
```

### 6.2 Keycloak - Konfiguracja SSO
```powershell
# Port forward
kubectl port-forward -n core-keycloak svc/keycloak 8443:8443

# Otwórz: https://localhost:8443
# Login: admin / <hasło z sealed secret>

# 1. Utwórz realm: "zsel"
# 2. Dodaj LDAP federation (FreeIPA)
# 3. Skonfiguruj OIDC clients dla:
#    - Moodle
#    - NextCloud
#    - GitLab
#    - Harbor
#    - Grafana
#    - Portainer
#    ... (25 aplikacji total)
```

### 6.3 Moodle - Pierwsze uruchomienie
```powershell
# Otwórz: https://moodle.zsel.opole.pl
# Setup wizard:
# 1. Database: PostgreSQL (automatically configured)
# 2. Admin account: z FreeIPA LDAP
# 3. LDAP config: ldap://freeipa-ldap.core-freeipa.svc:389
```

### 6.4 NextCloud - Montowanie NAS
```powershell
# External storage config (w UI):
# Type: SMB/CIFS
# Host: synology-nas.local
# Share: /nextcloud-data
# Size: 150TB
```

---

## 📊 Krok 7: Backup & DR Validation (20 minut)

### 7.1 Velero - Cluster Backup
```powershell
# Zainstaluj Velero
velero install `
  --provider aws `
  --bucket longhorn-backup `
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.edu-minio.svc:9000 `
  --use-volume-snapshots=false

# Testowy backup
velero backup create test-backup-1

# Weryfikacja
velero backup describe test-backup-1
```

### 7.2 Longhorn Snapshots
```powershell
# Dashboard
kubectl port-forward -n core-storage svc/longhorn-frontend 9000:80

# Utwórz recurring snapshot policy:
# - Critical data: hourly (retain 168h = 7 days)
# - Standard data: daily (retain 30 days)
```

### 7.3 Database Backups
```powershell
# PostgreSQL dump
kubectl exec -n db-postgres postgresql-ha-0 -- pg_dumpall -U postgres > postgres-backup.sql

# MySQL dump
kubectl exec -n db-mysql mysql-ha-0 -- mysqldump --all-databases -u root -p > mysql-backup.sql

# Zaplanuj CronJob (co 6h)
```

### 7.4 Disaster Recovery Test
```powershell
# Symulacja awarii pojedynczego node
kubectl drain k3s-worker-1 --ignore-daemonsets --delete-emptydir-data

# Obserwuj automatyczny restart podów na innych nodach
kubectl get pods -A -o wide | findstr "k3s-worker-1"

# Przywróć node
kubectl uncordon k3s-worker-1
```

---

## 🔒 Krok 8: Security Hardening (15 minut)

### 8.1 NetworkPolicies - Weryfikacja
```powershell
kubectl get networkpolicies -A
# Powinno być 280 policies (47 namespaces × 6 policies)

# Test izolacji
kubectl run test-pod --image=busybox --rm -it -- wget -O- http://moodle.edu-moodle.svc
# Powinno być: connection refused (jeśli nie w allowed namespaces)
```

### 8.2 RBAC - Weryfikacja
```powershell
kubectl get rolebindings -A | findstr "admin\|developer\|viewer"
# Powinno być 141 RoleBindings (47 × 3)

# Test uprawnień
kubectl auth can-i create pods --as=system:serviceaccount:edu-moodle:developer -n edu-moodle
# YES

kubectl auth can-i delete pods --as=system:serviceaccount:edu-moodle:viewer -n edu-moodle
# NO
```

### 8.3 Trivy - Vulnerability Scan
```powershell
# Sprawdź raporty
kubectl get vulnerabilityreports -A

# Szczegóły per image
kubectl describe vulnerabilityreport -n edu-moodle <report-name>
```

### 8.4 Falco - Runtime Monitoring
```powershell
# Sprawdź alerty
kubectl logs -n sec-falco -l app=falco -f

# Test: Uruchom suspicious command
kubectl exec -n edu-moodle moodle-0 -- sh -c "curl http://malicious-site.com"
# Falco powinien wykryć i zaalertować
```

---

## 🎯 Completion Checklist

Po wykonaniu wszystkich kroków sprawdź:

- [ ] **Infrastruktura:**
  - [ ] 47 namespaces utworzone
  - [ ] 280 NetworkPolicies aktywne
  - [ ] 141 RoleBindings skonfigurowane
  
- [ ] **Aplikacje:**
  - [ ] 39/39 aplikacji Running
  - [ ] Wszystkie Ingress accessible
  - [ ] LoadBalancer IPs assigned
  
- [ ] **Storage:**
  - [ ] Longhorn operational (40TB usable)
  - [ ] NAS mounted (150TB dla NextCloud)
  - [ ] PVC Bound dla wszystkich aplikacji
  
- [ ] **Security:**
  - [ ] Sealed Secrets zacommitowane
  - [ ] FreeIPA LDAP działa (1030 users)
  - [ ] Keycloak SSO skonfigurowane (25 apps)
  - [ ] WireGuard VPN operational
  
- [ ] **Monitoring:**
  - [ ] Prometheus scraping (all targets UP)
  - [ ] Grafana dashboards configured
  - [ ] Loki ingesting logs
  - [ ] Zabbix monitoring 9 nodes + 57 MikroTik
  
- [ ] **Backup/DR:**
  - [ ] Velero backups scheduled
  - [ ] Longhorn snapshots running
  - [ ] Database dumps automated
  - [ ] DR test successful

---

## 🆘 Troubleshooting

### Problem: Pod w CrashLoopBackOff
```powershell
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

### Problem: PVC Pending
```powershell
kubectl describe pvc <pvc-name> -n <namespace>
# Sprawdź: Longhorn operational, storage available
```

### Problem: Ingress nie działa
```powershell
kubectl describe ingress <ingress-name> -n <namespace>
# Sprawdź: Traefik running, DNS resolution OK
```

### Problem: LDAP authentication fails
```powershell
# Test FreeIPA connectivity
kubectl exec -n core-freeipa freeipa-0 -- ipa ping

# Check service account
kubectl exec -n core-freeipa freeipa-0 -- ipa service-show <service-name>
```

---

## 📞 Support

**Dokumentacja:**
- `zsel-eip-dokumentacja/deployment/`
- `zsel-eip-dokumentacja/architektura/`

**Issues:**
- GitHub: https://github.com/zsel-opole/zsel-eip-gitops/issues

**Contact:**
- IT Team: it@zsel.opole.pl
- DevOps: devops@zsel.opole.pl

---

**Status deployment:** ✅ Ready for production  
**Estimated total time:** ~2.5 hours (sequential) | ~1.5 hours (parallel)  
**Last updated:** 25 listopada 2025
