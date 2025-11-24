# Infrastructure Deployment Order

## Overview
This document defines the deployment order for all K3s infrastructure services to ensure dependencies are met.

---

## Wave 0: ArgoCD Bootstrap (Manual)

**Pre-requisites:**
- K3s cluster running (9 Mac Pro M2 Ultra nodes: 3 control + 6 workers)
- Longhorn CSI provisioner installed
- MetalLB LoadBalancer configured (VLAN 600: 192.168.255.0/24)

**Commands:**
```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 3. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 4. Port-forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 5. Login to ArgoCD
argocd login localhost:8080

# 6. Deploy App-of-Apps
kubectl apply -f infrastruktura-k3s/gitops/argocd/app-of-apps.yaml
```

---

## Wave 5: Core Network Services (No Dependencies)

### 1. NTP (Chrony) - Priority: CRITICAL
**Sync Wave:** 5  
**Namespace:** `core-network`  
**IP:** 192.168.255.54  
**Dependencies:** None

**Components:**
- DaemonSet: 9 pods (one per K3s node)
- Upstream: pl.pool.ntp.org, tempus1/2.gum.gov.pl

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=ntp
kubectl logs -n core-network -l app.kubernetes.io/component=ntp --tail=20
chronyc tracking  # From any MikroTik device after config
```

**Why First:**
- No dependencies
- Required by all MikroTik devices
- Time sync critical for logs, certificates, authentication

---

## Wave 10: Identity Services

### 2. Network AD (Samba AD-DC)
**Sync Wave:** 10  
**Namespace:** `core-network`  
**IP:** 192.168.255.50  
**Domain:** network-ad.zsel.opole.pl

**Components:**
- StatefulSet: 2 replicas (HA)
- Storage: 50Gi PVC (Longhorn)

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=network-ad
samba-tool domain level show  # From pod
```

### 3. User AD (Samba AD-DC)
**Sync Wave:** 10  
**Namespace:** `core-network`  
**IP:** 192.168.255.60  
**Domain:** ad.zsel.opole.pl

**Components:**
- StatefulSet: 2 replicas (HA)
- Storage: 50Gi PVC (Longhorn)

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=user-ad
samba-tool domain level show  # From pod
```

---

## Wave 15: DNS Services (After AD)

### 4. DNS (Bind9)
**Sync Wave:** 15  
**Namespace:** `core-network`  
**IP:** 192.168.255.53  
**Dependencies:** Network AD, User AD (for split-horizon zones)

**Components:**
- Deployment: 3 replicas (HA)
- Zones: network-ad.zsel.opole.pl, ad.zsel.opole.pl, zsel.opole.pl
- Reverse zones: 192.168.255.0/24, 192.168.10.0/24

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=dns
dig @192.168.255.53 network-ad.zsel.opole.pl
dig @192.168.255.53 ad.zsel.opole.pl
dig @192.168.255.53 -x 192.168.255.50
```

---

## Wave 20: Authentication Services (After DNS + AD)

### 5. FreeRADIUS Network (Device Login)
**Sync Wave:** 20  
**Namespace:** `core-network`  
**IP:** 192.168.255.50 (same as Network AD)  
**Dependencies:** Network AD, DNS

**Components:**
- Deployment: 2 replicas (HA)
- Backend: LDAP bind to Network AD

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=freeradius-network
radtest admin PASSWORD 192.168.255.50 1812 testing123
```

### 6. FreeRADIUS WiFi (User WiFi Auth)
**Sync Wave:** 20  
**Namespace:** `core-network`  
**IP:** 192.168.255.60 (same as User AD)  
**Dependencies:** User AD, DNS

**Components:**
- Deployment: 2 replicas (HA)
- Backend: LDAP bind to User AD

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=freeradius-wifi
radtest user PASSWORD 192.168.255.60 1812 testing123
```

---

## Wave 25: Captive Portal (After RADIUS)

### 7. PacketFence
**Sync Wave:** 25  
**Namespace:** `core-network`  
**IP:** 192.168.255.65  
**Dependencies:** FreeRADIUS WiFi, DNS

**Components:**
- Deployment: 2 replicas
- MariaDB: 1 replica, 20Gi
- Redis: 1 replica
- Portal: portal.zsel.opole.pl

**Verification:**
```bash
kubectl get pods -n core-network -l app.kubernetes.io/component=captive-portal
curl -k https://192.168.255.65/captive-portal/
```

---

## Wave 30: Monitoring & Logging (After DNS)

### 8. Graylog Stack
**Sync Wave:** 30  
**Namespace:** `logging-system`  
**IP:** 192.168.255.55  
**Dependencies:** DNS (for elasticsearch cluster discovery)

**Components:**
- MongoDB: 1 replica, 50Gi
- Elasticsearch: 3-node cluster, 200Gi × 3 = 600Gi
- Graylog Server: 2 replicas
- Ports: 9000 (HTTP), 514 UDP/TCP (Syslog), 12201 UDP/TCP (GELF)

**Verification:**
```bash
kubectl get pods -n logging-system
curl http://192.168.255.55:9000/api/system/lbstatus
# Login: admin / <GRAYLOG_ADMIN_PASSWORD>
```

**Storage:**
- Total: 650Gi (MongoDB 50Gi + Elasticsearch 600Gi)
- Retention: 90 days (1 index/day, max 90 indices)

### 9. Monitoring Stack (Prometheus + Grafana + AlertManager)
**Sync Wave:** 30  
**Namespace:** `monitoring-system`  
**IPs:** Prometheus: .56, Grafana: .57, AlertManager: .58  
**Dependencies:** DNS (for service discovery)

**Components:**
- **Prometheus:** StatefulSet 2 replicas, 500Gi × 2 = 1TB
  - SNMP Exporter: 3 replicas (for 57 MikroTik devices)
  - Node Exporter: DaemonSet (9 K3s nodes)
- **Grafana:** Deployment 2 replicas, 10Gi PVC
- **AlertManager:** Deployment 2 replicas

**Verification:**
```bash
kubectl get pods -n monitoring-system
curl http://192.168.255.56:9090/-/healthy  # Prometheus
curl http://192.168.255.57:3000/api/health  # Grafana
curl http://192.168.255.58:9093/-/healthy  # AlertManager
```

**Storage:**
- Total: 1.01TB (Prometheus 1TB + Grafana 10Gi)
- Retention: 90 days OR 450GB (whichever reached first)

**Targets:**
- 57 MikroTik devices (SNMP v3):
  - 5 CCR2216 routers
  - 6 CRS518 AGG switches
  - 16 CRS354 DIST switches
  - 14 CRS326/328 ACC switches
  - 16 cAP ax WiFi APs
- 9 K3s nodes (Node Exporter)
- All K8s pods (service discovery)

### 10. Zabbix Stack
**Sync Wave:** 30  
**Namespace:** `monitoring-system`  
**IP:** 192.168.255.59  
**Dependencies:** DNS

**Components:**
- PostgreSQL: StatefulSet 1 replica, 50Gi
- Zabbix Server: Deployment 1 replica
- Zabbix Web: Deployment 2 replicas
- Zabbix Agent: DaemonSet (9 K3s nodes)

**Verification:**
```bash
kubectl get pods -n monitoring-system -l app.kubernetes.io/name=zabbix
curl http://192.168.255.59/zabbix.php
# Login: Admin / zabbix
```

**Storage:**
- Total: 50Gi (PostgreSQL)
- Retention: 90 days metrics

---

## Wave 10: Storage Services (Early, Many Dependencies)

### 11. MinIO Distributed
**Sync Wave:** 10  
**Namespace:** `storage-system`  
**IPs:** API: 192.168.255.70, Console: 192.168.255.71  
**Dependencies:** None (can deploy early)

**Components:**
- StatefulSet: 4 nodes
- Storage: 2.5TB × 4 = 10TB total
- Erasure Coding: EC:2 (N/2 data + N/2 parity)

**Verification:**
```bash
kubectl get pods -n storage-system -l app.kubernetes.io/component=storage
curl http://192.168.255.70:9000/minio/health/live
# Console: http://192.168.255.71 (minioadmin / <MINIO_ROOT_PASSWORD>)
```

**Use Cases:**
- Graylog log archives
- Prometheus metrics backups (via remote write)
- Zabbix database backups
- K3s etcd backups
- Samba AD backups (sysvol, LDAP)

---

## Deployment Summary

| Wave | Service | Namespace | IP | Dependencies | Storage |
|------|---------|-----------|----|--------------| -------|
| 5 | NTP (Chrony) | core-network | .54 | None | - |
| 10 | Network AD | core-network | .50 | NTP | 50Gi |
| 10 | User AD | core-network | .60 | NTP | 50Gi |
| 10 | MinIO | storage-system | .70/.71 | None | 10TB |
| 15 | DNS (Bind9) | core-network | .53 | AD | - |
| 20 | FreeRADIUS Network | core-network | .50 | Network AD, DNS | - |
| 20 | FreeRADIUS WiFi | core-network | .60 | User AD, DNS | - |
| 25 | PacketFence | core-network | .65 | FreeRADIUS WiFi, DNS | 20Gi |
| 30 | Graylog | logging-system | .55 | DNS | 650Gi |
| 30 | Monitoring Stack | monitoring-system | .56/.57/.58 | DNS | 1.01TB |
| 30 | Zabbix | monitoring-system | .59 | DNS | 50Gi |

**Total Storage:** ~11.78TB

---

## Post-Deployment Configuration

### 1. Install Sealed Secrets Controller

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller
kubectl rollout status deployment sealed-secrets-controller -n kube-system

# Fetch public certificate
mkdir -p environments/production/sealed-secrets
kubeseal --fetch-cert > environments/production/sealed-secrets/pub-cert.pem
```

### 2. Generate All Secrets

```bash
# Run automated secret creation script
cd infrastruktura-k3s/gitops
chmod +x environments/production/sealed-secrets/create-all-secrets.sh
./environments/production/sealed-secrets/create-all-secrets.sh

# Commit SealedSecrets to Git
git add environments/production/sealed-secrets/*.yaml
git commit -m "Add encrypted SealedSecrets for infrastructure services"
git push

# Apply SealedSecrets
kubectl apply -f environments/production/sealed-secrets/
```

**15 Secrets Created:**
1. network-ad-admin-secret (Network AD)
2. user-ad-admin-secret (User AD)
3. radius-bind (FreeRADIUS Network → Network AD)
4. sso-wifi-bind (FreeRADIUS WiFi → User AD)
5. mikrotik-radius-secret (57 MikroTik devices)
6. wifi-radius-secret (WiFi user auth)
7. packetfence-db (MariaDB + Redis)
8. graylog-password-secret (Graylog admin)
9. mongodb-root-password (Graylog backend)
10. elasticsearch-password (Graylog backend)
11. grafana-admin-credentials (Grafana login)
12. snmp-exporter-credentials (SNMP v3 for MikroTik)
13. zabbix-db-password (PostgreSQL)
14. zabbix-admin-password (Zabbix login)
15. minio-root-credentials (MinIO S3)

### 3. Configure MikroTik Devices

```bash
# Generate config snippets for 56 remaining devices
cd konfiguracje-mikrotik/helpers
chmod +x bulk-k3s-integration.sh
./bulk-k3s-integration.sh

# Deploy configs manually via WinBox/SSH:
# 1. Connect to each device
# 2. Import .rsc file: /import file=<device>-UPDATE.rsc
# 3. Verify services work
```

**Configuration Updates Per Device:**
- DNS: Primary 192.168.255.53 + 10 static entries
- NTP: Primary 192.168.255.54
- RADIUS Device Login: 192.168.255.50 (Network AD)
- RADIUS WiFi Auth: 192.168.255.60 (User AD) - cAP only
- Graylog Syslog: 192.168.255.55:514
- SNMP v3: Enable monitoring (Prometheus + Zabbix)

**56 Devices:**
- 4 CCR2216 routers (BCU-02 through BCU-05) - Note: BCU-01 already configured
- 6 CRS518 AGG switches
- 16 CRS354 DIST switches
- 14 CRS326/328 ACC switches
- 16 cAP ax WiFi APs

### 4. Verify All Services

**DNS:**
```bash
dig @192.168.255.53 network-ad.zsel.opole.pl +short
dig @192.168.255.53 ad.zsel.opole.pl +short
```

**NTP:**
```bash
# From any MikroTik device
/system ntp client print
```

**RADIUS:**
```bash
# From MikroTik device
/radius monitor [find]
```

**Graylog:**
- UI: http://192.168.255.55:9000
- Login: admin / <GRAYLOG_ADMIN_PASSWORD>
- Check: 57 MikroTik syslog streams active

**Prometheus:**
- UI: http://192.168.255.56:9090
- Check: 57 MikroTik SNMP targets + 9 K3s nodes up
- Metrics: `up{job="mikrotik-snmp"}` should show 57 instances

**Grafana:**
- UI: http://192.168.255.57:3000
- Login: admin / <GRAFANA_ADMIN_PASSWORD>
- Import dashboards: MikroTik, K3s, Infrastructure

**AlertManager:**
- UI: http://192.168.255.58:9093
- Check: Alerting rules loaded
- Test: Silence an alert

**Zabbix:**
- UI: http://192.168.255.59
- Login: Admin / zabbix (change immediately!)
- Add hosts: 57 MikroTik devices + 9 K3s nodes
- Apply templates: MikroTik RouterOS SNMPv3

**MinIO:**
- Console: http://192.168.255.71
- Login: minioadmin / <MINIO_ROOT_PASSWORD>
- Create buckets: graylog-archives, prometheus-backups, zabbix-backups, k3s-backups, ad-backups

---

## Monitoring Dashboards

### Grafana Dashboards to Import

1. **MikroTik Overview** (ID: 14420)
   - All 57 devices status
   - CPU, Memory, Disk usage
   - Interface traffic

2. **MikroTik Interfaces** (ID: 13063)
   - Per-interface metrics
   - Traffic graphs
   - Error rates

3. **Kubernetes Cluster** (ID: 15758)
   - 9 K3s nodes overview
   - Pod status
   - Resource usage

4. **Node Exporter** (ID: 1860)
   - Per-node metrics
   - CPU, Memory, Disk, Network

5. **Prometheus Stats** (ID: 2)
   - Prometheus internal metrics
   - Scrape duration
   - TSDB stats

6. **AlertManager** (ID: 9578)
   - Active alerts
   - Alert history
   - Receiver status

### Alert Rules Summary

**9 Alert Rules Configured:**

**MikroTik Health:**
1. Device Down (2min threshold)
2. High CPU (>80%, 5min)
3. High Memory (>85%, 5min)
4. Interface Down (2min)

**K3s Health:**
5. Node Down (5min)
6. Node High CPU (>80%, 10min)
7. Node High Memory (>85%, 10min)
8. Disk Space Low (<15%, 10min)
9. Pod CrashLooping (5min)

**Alert Routing:**
- Critical → Email (it-admin@zsel.opole.pl) + Graylog webhook
- Warning → Email (it-team@zsel.opole.pl)

---

## Backup Strategy

### Daily Backups (MinIO)

**Graylog:**
```bash
# Elasticsearch snapshots to MinIO
curl -XPUT "http://192.168.255.55:9200/_snapshot/minio_repository" -H 'Content-Type: application/json' -d'{
  "type": "s3",
  "settings": {
    "bucket": "graylog-archives",
    "endpoint": "http://192.168.255.70:9000",
    "access_key": "minioadmin",
    "secret_key": "<MINIO_ROOT_PASSWORD>"
  }
}'
```

**Prometheus:**
```bash
# Remote write to MinIO via Thanos (optional)
# OR use Prometheus snapshots
curl -XPOST http://192.168.255.56:9090/api/v1/admin/tsdb/snapshot
```

**Zabbix:**
```bash
# PostgreSQL backups to MinIO
kubectl exec -n monitoring-system zabbix-postgresql-0 -- pg_dump -U zabbix zabbix | \
  mc pipe minio/zabbix-backups/zabbix-$(date +%Y%m%d).sql
```

**K3s etcd:**
```bash
# Automated etcd snapshots
kubectl exec -n kube-system etcd-control-01 -- etcdctl snapshot save /tmp/etcd-backup.db
kubectl cp kube-system/etcd-control-01:/tmp/etcd-backup.db ./etcd-backup.db
mc cp etcd-backup.db minio/k3s-backups/etcd-$(date +%Y%m%d).db
```

**Samba AD:**
```bash
# sysvol + LDAP backup
kubectl exec -n core-network network-ad-0 -- samba-tool domain backup offline --targetdir=/tmp
kubectl cp core-network/network-ad-0:/tmp/samba-backup.tar.bz2 ./network-ad-backup.tar.bz2
mc cp network-ad-backup.tar.bz2 minio/ad-backups/network-ad-$(date +%Y%m%d).tar.bz2
```

---

## Troubleshooting

### Service Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n <namespace> <pod-name> --tail=100

# Describe pod
kubectl describe pod -n <namespace> <pod-name>
```

### DNS Resolution Issues

```bash
# Test from K3s node
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- dig @192.168.255.53 network-ad.zsel.opole.pl

# Test from MikroTik
/ping 192.168.255.53
/tool dns-lookup name=network-ad.zsel.opole.pl server=192.168.255.53
```

### RADIUS Auth Failures

```bash
# Check RADIUS logs
kubectl logs -n core-network -l app.kubernetes.io/component=freeradius-network --tail=50 -f

# Test from MikroTik
/radius monitor [find]

# Manual radtest
kubectl exec -it -n core-network <freeradius-pod> -- radtest admin PASSWORD localhost 1812 testing123
```

### Monitoring Gaps

```bash
# Check Prometheus targets
curl http://192.168.255.56:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Check SNMP exporter
kubectl logs -n monitoring-system -l app.kubernetes.io/component=snmp-exporter --tail=50

# Verify SNMP v3 from MikroTik
/snmp print
```

---

## Success Criteria

✅ **All pods running:**
```bash
kubectl get pods --all-namespaces | grep -v "Running\|Completed"
# Should return no results
```

✅ **All LoadBalancer IPs assigned:**
```bash
kubectl get svc --all-namespaces -o wide | grep LoadBalancer
# Should show 11 services with EXTERNAL-IP assigned
```

✅ **All 57 MikroTik devices monitored:**
```bash
# Prometheus
curl -s http://192.168.255.56:9090/api/v1/query?query=up{job="mikrotik-snmp"} | jq '.data.result | length'
# Should return: 57

# Graylog
curl -s http://192.168.255.55:9000/api/system/inputs | jq '.inputs[] | select(.type == "org.graylog2.inputs.syslog.udp.SyslogUDPInput") | .metrics.incomingMessages'
# Should show message counts from all devices
```

✅ **No critical alerts firing:**
```bash
curl -s http://192.168.255.58:9093/api/v1/alerts | jq '.data[] | select(.status.state == "firing" and .labels.severity == "critical")'
# Should return empty array
```

---

## Deployment Complete! 🎉

**Infrastructure Summary:**
- 11 services deployed
- 57 MikroTik devices integrated
- 9 K3s nodes monitored
- ~11.78TB storage provisioned
- 15 secrets sealed
- Full monitoring stack operational

**Access Points:**
- ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443
- Graylog: http://192.168.255.55:9000
- Prometheus: http://192.168.255.56:9090
- Grafana: http://192.168.255.57:3000
- AlertManager: http://192.168.255.58:9093
- Zabbix: http://192.168.255.59
- MinIO Console: http://192.168.255.71

**Next Steps:**
1. Import Grafana dashboards
2. Configure Zabbix templates for MikroTik
3. Set up MinIO backup schedules
4. Configure alert notification channels
5. Document runbooks for common issues
