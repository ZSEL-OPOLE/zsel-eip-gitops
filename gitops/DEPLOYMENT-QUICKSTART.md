# Infrastructure Deployment - Quick Start

## 🚀 Ready to Deploy!

All infrastructure services are configured and ready for deployment via ArgoCD GitOps.

---

## 📦 What Will Be Deployed

### Core Services (11 applications)

| Service | Namespace | IPs | Storage | Purpose |
|---------|-----------|-----|---------|---------|
| **NTP (Chrony)** | core-network | .54 | - | Time sync for 57 MikroTik devices |
| **DNS (Bind9)** | core-network | .53 | - | Split-horizon DNS (3 zones) |
| **Network AD** | core-network | .50 | 50Gi | Device authentication domain |
| **User AD** | core-network | .60 | 50Gi | User authentication domain |
| **FreeRADIUS Network** | core-network | .50 | - | Device login (57 MikroTik) |
| **FreeRADIUS WiFi** | core-network | .60 | - | WiFi user auth (WPA2-Enterprise) |
| **PacketFence** | core-network | .65 | 20Gi | Captive portal |
| **Graylog** | logging-system | .55 | 650Gi | Log aggregation (MongoDB + ES + Graylog) |
| **Monitoring Stack** | monitoring-system | .56/.57/.58 | 1.01TB | Prometheus + Grafana + AlertManager |
| **Zabbix** | monitoring-system | .59 | 50Gi | SNMP monitoring + Agent |
| **MinIO** | storage-system | .70/.71 | 10TB | S3 backup storage (4 nodes) |

**Total:** 11 services, ~11.78TB storage, 57 MikroTik devices integrated

---

## ⚡ Quick Deploy (5 minutes)

### Windows (PowerShell)

```powershell
cd c:\Users\kolod\Desktop\LKP\05_BCU\BCU\zsel-opole-org\infrastruktura-k3s\gitops
.\deploy-infrastructure.ps1
```

### Linux/Mac (Bash)

```bash
cd /path/to/zsel-opole-org/infrastruktura-k3s/gitops
chmod +x deploy-infrastructure.sh
./deploy-infrastructure.sh
```

**What it does:**
1. ✓ Checks prerequisites (kubectl, K3s, Longhorn, MetalLB)
2. ✓ Installs ArgoCD (if not present)
3. ✓ Deploys App-of-Apps (triggers all 11 services)
4. ✓ Monitors sync status

---

## 🔐 Post-Deployment: Sealed Secrets (Required!)

All services need encrypted credentials. Follow this guide:

📖 **[SEALED-SECRETS-GUIDE.md](./SEALED-SECRETS-GUIDE.md)**

**Quick steps:**

```bash
# 1. Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# 2. Fetch public certificate
kubeseal --fetch-cert > environments/production/sealed-secrets/pub-cert.pem

# 3. Generate all 15 secrets (interactive prompts)
chmod +x environments/production/sealed-secrets/create-all-secrets.sh
./environments/production/sealed-secrets/create-all-secrets.sh

# 4. Commit & apply SealedSecrets
git add environments/production/sealed-secrets/*.yaml
git commit -m "Add encrypted SealedSecrets"
git push
kubectl apply -f environments/production/sealed-secrets/

# 5. Restart services to load secrets
kubectl rollout restart deployment -n core-network
kubectl rollout restart deployment -n logging-system
kubectl rollout restart deployment -n monitoring-system
kubectl rollout restart deployment -n storage-system
```

**15 Secrets Required:**
- Network AD + User AD admin passwords
- RADIUS bind credentials (2)
- MikroTik + WiFi RADIUS shared secrets (2)
- PacketFence DB (MariaDB + Redis)
- Graylog (admin + MongoDB + Elasticsearch)
- Grafana admin credentials
- SNMP v3 credentials
- Zabbix (DB + admin)
- MinIO root credentials

---

## 📡 MikroTik Integration (56 devices)

After services are running, configure MikroTik devices:

```bash
cd konfiguracje-mikrotik/helpers
chmod +x bulk-k3s-integration.sh
./bulk-k3s-integration.sh
```

**What it does:**
- Generates 56 `.rsc` config files (one per device)
- Updates: DNS, NTP, RADIUS, Graylog, SNMP v3
- Device types: 4 routers, 6 AGG, 16 DIST, 14 ACC, 16 cAP

**Manual deployment per device:**
1. Connect via WinBox/SSH
2. Import: `/import file=<device>-UPDATE.rsc`
3. Verify: `/ping 192.168.255.53`

📖 **[MIKROTIK-INTEGRATION.md](./MIKROTIK-INTEGRATION.md)**

---

## 🎯 Service Access

### ArgoCD (GitOps UI)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# URL: https://localhost:8080
# User: admin
# Pass: (get from script output or kubectl get secret)
```

### Monitoring Dashboards

| Service | URL | Default Login |
|---------|-----|---------------|
| Graylog | http://192.168.255.55:9000 | admin / (from secret) |
| Prometheus | http://192.168.255.56:9090 | (no auth) |
| Grafana | http://192.168.255.57:3000 | admin / (from secret) |
| AlertManager | http://192.168.255.58:9093 | (no auth) |
| Zabbix | http://192.168.255.59 | Admin / zabbix |
| MinIO Console | http://192.168.255.71 | minioadmin / (from secret) |

---

## ✅ Verification Checklist

### 1. All Pods Running
```bash
kubectl get pods --all-namespaces | grep -v "Running\|Completed"
# Should return no results (empty)
```

### 2. All LoadBalancer IPs Assigned
```bash
kubectl get svc --all-namespaces | grep LoadBalancer
# Should show 11 services with EXTERNAL-IP assigned (.50-.71)
```

### 3. DNS Working
```bash
dig @192.168.255.53 network-ad.zsel.opole.pl +short
# Should return: 192.168.255.50

dig @192.168.255.53 ad.zsel.opole.pl +short
# Should return: 192.168.255.60
```

### 4. Prometheus Scraping
```bash
curl -s http://192.168.255.56:9090/api/v1/query?query=up{job="mikrotik-snmp"} | jq '.data.result | length'
# Should return: 57 (all MikroTik devices)
```

### 5. Graylog Receiving Logs
```bash
curl -s http://192.168.255.55:9000/api/system/inputs
# Should show syslog input with message counts
```

### 6. No Critical Alerts
```bash
curl -s http://192.168.255.58:9093/api/v1/alerts | jq '.data[] | select(.labels.severity == "critical")'
# Should return empty array []
```

---

## 📊 Monitoring Setup

### Grafana Dashboards (Import these)

1. **MikroTik Overview** → ID: 14420
2. **MikroTik Interfaces** → ID: 13063
3. **Kubernetes Cluster** → ID: 15758
4. **Node Exporter** → ID: 1860
5. **Prometheus Stats** → ID: 2
6. **AlertManager** → ID: 9578

**Import in Grafana:**
1. Go to http://192.168.255.57:3000
2. Login: admin / (secret password)
3. Dashboards → Import → Enter dashboard ID

### Alert Rules (Already Configured)

**9 Alert Rules Active:**
- MikroTik: Device down, High CPU/Memory, Interface down
- K3s: Node down, High CPU/Memory, Disk low, Pod crashlooping

**Alert Routing:**
- Critical → Email (it-admin@zsel.opole.pl) + Graylog webhook
- Warning → Email (it-team@zsel.opole.pl)

---

## 🔄 Backup Strategy

### MinIO Buckets (Create in Console)

```bash
mc alias set minio http://192.168.255.70:9000 minioadmin <PASSWORD>
mc mb minio/graylog-archives
mc mb minio/prometheus-backups
mc mb minio/zabbix-backups
mc mb minio/k3s-backups
mc mb minio/ad-backups
```

### Automated Backups (Daily)

**Graylog (Elasticsearch snapshots):**
```bash
curl -XPUT "http://192.168.255.55:9200/_snapshot/minio_repository" -H 'Content-Type: application/json' -d'{
  "type": "s3",
  "settings": {
    "bucket": "graylog-archives",
    "endpoint": "http://192.168.255.70:9000"
  }
}'
```

**Zabbix (PostgreSQL backups):**
```bash
kubectl exec -n monitoring-system zabbix-postgresql-0 -- \
  pg_dump -U zabbix zabbix | \
  mc pipe minio/zabbix-backups/zabbix-$(date +%Y%m%d).sql
```

**K3s etcd (Control plane backups):**
```bash
kubectl exec -n kube-system etcd-control-01 -- \
  etcdctl snapshot save /tmp/etcd-backup.db
kubectl cp kube-system/etcd-control-01:/tmp/etcd-backup.db ./etcd-backup.db
mc cp etcd-backup.db minio/k3s-backups/etcd-$(date +%Y%m%d).db
```

---

## 🛠️ Troubleshooting

### Pods Not Starting

```bash
# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check pod logs
kubectl logs -n <namespace> <pod-name> --tail=100

# Describe pod (shows errors)
kubectl describe pod -n <namespace> <pod-name>
```

### LoadBalancer IP Not Assigned

```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l component=controller

# Check IP pool
kubectl get ipaddresspool -n metallb-system
```

### Storage Not Provisioning

```bash
# Check Longhorn
kubectl get pods -n longhorn-system
kubectl get pvc --all-namespaces | grep Pending

# Check Longhorn UI
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80
```

### DNS Not Resolving

```bash
# Test from K3s node
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  dig @192.168.255.53 network-ad.zsel.opole.pl

# Check DNS pod logs
kubectl logs -n core-network -l app.kubernetes.io/component=dns
```

---

## 📚 Documentation

- **[DEPLOYMENT-ORDER.md](./DEPLOYMENT-ORDER.md)** - Full deployment guide with dependencies
- **[SEALED-SECRETS-GUIDE.md](./SEALED-SECRETS-GUIDE.md)** - Complete secret management
- **[MIKROTIK-INTEGRATION.md](./MIKROTIK-INTEGRATION.md)** - MikroTik config guide
- **[SECURITY-SEALED-SECRETS.md](./SECURITY-SEALED-SECRETS.md)** - Security best practices

---

## 🎉 Success!

When deployment is complete, you'll have:

✅ **11 services running** (DNS, NTP, AD, RADIUS, Graylog, Monitoring, Zabbix, MinIO)  
✅ **57 MikroTik devices** monitored (SNMP + Syslog)  
✅ **9 K3s nodes** monitored (Prometheus + Zabbix)  
✅ **~11.78TB storage** provisioned (Longhorn)  
✅ **15 encrypted secrets** deployed (Sealed Secrets)  
✅ **Full GitOps workflow** (ArgoCD auto-sync)  

**Next:** Configure alert notification channels (Email, Slack, PagerDuty) in AlertManager!

---

## 🆘 Need Help?

**Quick diagnostics:**
```bash
# Overall cluster health
kubectl get nodes
kubectl get pods --all-namespaces | grep -v "Running\|Completed"

# ArgoCD app status
kubectl get applications -n argocd

# Service endpoints
kubectl get svc --all-namespaces | grep LoadBalancer

# Recent events (spot issues)
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50
```

**Common issues:**
- **Pods CrashLooping:** Check logs, verify secrets exist
- **IP not assigned:** Check MetalLB, IP pool exhausted
- **PVC Pending:** Check Longhorn, insufficient disk space
- **ArgoCD not syncing:** Check GitHub connection, branch name

**Contact:**
- Maintainer: Łukasz Kołodziej <lkolodziej@aircloud.pl>
- Repository: https://github.com/zsel-opole/zsel-opole-org
