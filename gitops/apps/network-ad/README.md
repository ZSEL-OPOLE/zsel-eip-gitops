# Network AD - Samba Active Directory Domain Controller

**Domain:** `network-ad.zsel.opole.pl`  
**Purpose:** Infrastructure authentication ONLY (MikroTik devices via RADIUS)  
**Namespace:** `core-auth`  
**IP Addresses:** 192.168.255.51 (PRIMARY), 192.168.255.52 (SECONDARY)  
**VLAN:** 600 (Management)

## 🔒 SECURITY CRITICAL

**This AD domain is ISOLATED from user authentication!**
- **NO trust relationship** with `ad.zsel.opole.pl` (user domain)
- **NO access** from user VLANs (10, 20, 30, 40)
- Firewall rules **BLOCK** 192.168.255.51-52 from non-management VLANs
- Only ~10 IT network admins have accounts here

See: [AD-DOMAIN-SEPARATION.md](../../docs/AD-DOMAIN-SEPARATION.md)

---

## Architecture

```
Network AD Domain Controller (HA)
├── Primary DC: 192.168.255.51 (network-ad-dc-0)
├── Secondary DC: 192.168.255.52 (network-ad-dc-1)
├── Replication: Multi-master DFS-R
└── Services:
    ├── LDAP: 389/TCP (FreeRADIUS bind)
    ├── LDAPS: 636/TCP (encrypted)
    ├── Kerberos: 88/TCP+UDP
    ├── DNS: 53/TCP+UDP (internal zone)
    └── SMB: 445/TCP (sysvol replication)
```

### Organizational Units (OUs)

```
DC=network-ad,DC=zsel,DC=opole,DC=pl
├── OU=NetworkDevices
│   └── OU=MikroTik
│       ├── OU=Routers (5 CCR2216)
│       ├── OU=Switches (35 CRS devices)
│       └── OU=WiFi (16 cAP ax)
├── OU=NetworkAdmins
│   └── OU=ITAdmins (10 users)
└── OU=ServiceAccounts
    └── CN=radius-bind (FreeRADIUS LDAP bind)
```

---

## Deployment

### Prerequisites

1. **K3s cluster** operational with Longhorn CSI
2. **MetalLB** configured with `vlan600-management` address pool
3. **Firewall rules** blocking user VLANs from 192.168.255.51-52

### Install with ArgoCD

```bash
# Deploy via ArgoCD (recommended)
kubectl apply -f ../../argocd/applications/core-auth/network-ad.yaml

# Wait for sync
argocd app sync core-auth/network-ad --prune
argocd app wait core-auth/network-ad --health
```

### Manual Install (for testing)

```bash
# Build production kustomization
kubectl kustomize overlays/production/ > /tmp/network-ad-prod.yaml

# Review manifests
cat /tmp/network-ad-prod.yaml

# Apply (ENSURE SECRET IS SEALED FIRST!)
kubectl apply -f /tmp/network-ad-prod.yaml

# Watch deployment
kubectl get pods -n core-auth -l app.kubernetes.io/name=network-ad -w
```

---

## Configuration

### Admin Password (CRITICAL!)

**NEVER commit plain passwords to Git!**

#### For Production (SealedSecret)

```bash
# 1. Generate strong password
ADMIN_PASSWORD=$(openssl rand -base64 32)
echo "Save this password: $ADMIN_PASSWORD"

# 2. Create plain secret (temporary)
kubectl create secret generic network-ad-admin-secret \
  --namespace=core-auth \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 3. Seal the secret
kubeseal --format=yaml --cert=../../environments/production/pub-sealed-secrets.pem \
  < /tmp/secret.yaml > overlays/production/sealed-secret.yaml

# 4. SECURELY DELETE plain secret
rm /tmp/secret.yaml
unset ADMIN_PASSWORD

# 5. Commit sealed secret
git add overlays/production/sealed-secret.yaml
git commit -m "feat(network-ad): Add sealed admin password"
```

#### Sealed Secret Example

```yaml
# overlays/production/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: network-ad-admin-secret
  namespace: core-auth
spec:
  encryptedData:
    admin-password: AgBZXk... (encrypted base64)
  template:
    metadata:
      name: network-ad-admin-secret
      namespace: core-auth
    type: Opaque
```

### Domain Initialization

Domain provisioning happens automatically on first boot via `configmap-init.yaml`:

1. Check if `/var/lib/samba/private/sam.ldb` exists
2. If NO → Provision domain with `samba-tool domain provision`
3. Create OUs (NetworkDevices, NetworkAdmins, ServiceAccounts)
4. Create service account `radius-bind` (random password)
5. Create example admin user (MUST change password on first login!)
6. Start Samba AD DC

### RADIUS Bind Account

After deployment, retrieve `radius-bind` password:

```bash
# Exec into PRIMARY pod
kubectl exec -it -n core-auth network-ad-dc-0 -- bash

# Get radius-bind password (stored in domain)
samba-tool user show radius-bind

# Or reset password
NEW_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 32 | head -n 1)
samba-tool user setpassword radius-bind --newpassword="$NEW_PASSWORD"
echo "New radius-bind password: $NEW_PASSWORD"
```

**Configure FreeRADIUS with this password!**

---

## Verification

### Health Checks

```bash
# Check pod status
kubectl get pods -n core-auth -l app.kubernetes.io/name=network-ad

# Expected output:
# NAME              READY   STATUS    RESTARTS   AGE
# network-ad-dc-0   1/1     Running   0          10m
# network-ad-dc-1   1/1     Running   0          10m

# Check services
kubectl get svc -n core-auth -l app.kubernetes.io/name=network-ad

# Expected output:
# NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
# network-ad-headless    ClusterIP      None            <none>            389/TCP,636/TCP,...
# network-ad-primary     LoadBalancer   10.43.100.51    192.168.255.51    389:30389/TCP,...
# network-ad-secondary   LoadBalancer   10.43.100.52    192.168.255.52    389:30389/TCP,...

# Check PVC
kubectl get pvc -n core-auth -l app.kubernetes.io/name=network-ad

# Expected output:
# NAME                         STATUS   VOLUME                                     CAPACITY
# samba-data-network-ad-dc-0   Bound    pvc-abc123...                              50Gi
# samba-data-network-ad-dc-1   Bound    pvc-def456...                              50Gi
```

### LDAP Query Test

```bash
# From management VLAN (192.168.600.0/24) or K3s node
ldapsearch -x -H ldap://192.168.255.51 \
  -D "CN=Administrator,CN=Users,DC=network-ad,DC=zsel,DC=opole,DC=pl" \
  -W \
  -b "DC=network-ad,DC=zsel,DC=opole,DC=pl" \
  "(objectClass=organizationalUnit)"

# Expected output: List of OUs (NetworkDevices, NetworkAdmins, ServiceAccounts)
```

### DNS Test

```bash
# Resolve domain controller (from management VLAN)
nslookup network-ad.zsel.opole.pl 192.168.255.51

# Expected output:
# Server:   192.168.255.51
# Address:  192.168.255.51#53
# Name:     network-ad.zsel.opole.pl
# Address:  192.168.255.51
```

### Replication Test

```bash
# Check replication status on PRIMARY
kubectl exec -it -n core-auth network-ad-dc-0 -- samba-tool drs showrepl

# Expected output: Show replication from network-ad-dc-1 with recent timestamp
```

---

## User Management

### Create Network Admin User

```bash
# Exec into PRIMARY pod
kubectl exec -it -n core-auth network-ad-dc-0 -- bash

# Create user
samba-tool user create jkowalski "TempPassword123!" \
  --given-name="Jan" \
  --surname="Kowalski" \
  --mail-address="j.kowalski@zsel.opole.pl" \
  --description="Network Administrator" \
  --must-change-at-next-login=yes

# Move to ITAdmins OU
samba-tool user move jkowalski "OU=ITAdmins,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl"

# Grant Domain Admins (full access)
samba-tool group addmembers "Domain Admins" jkowalski
```

### Delete User

```bash
# Disable first (audit trail)
samba-tool user disable jkowalski

# Delete after confirmation
samba-tool user delete jkowalski
```

### Password Policy

```bash
# View current policy
samba-tool domain passwordsettings show

# Set strict policy (production recommended)
samba-tool domain passwordsettings set --complexity=on
samba-tool domain passwordsettings set --min-pwd-length=14
samba-tool domain passwordsettings set --min-pwd-age=1
samba-tool domain passwordsettings set --max-pwd-age=90
samba-tool domain passwordsettings set --history-length=24
```

---

## Monitoring

### Logs

```bash
# Pod logs
kubectl logs -n core-auth network-ad-dc-0 -f

# Samba logs (inside pod)
kubectl exec -it -n core-auth network-ad-dc-0 -- tail -f /var/log/samba/samba.log
```

### Prometheus Metrics

(TODO: Add samba_exporter sidecar)

### Graylog Integration

Samba logs forwarded to Graylog (192.168.255.55):

- **Stream:** `Network-AD-Authentication`
- **Retention:** 90 days (compliance)
- **Alerts:** Failed logins, replication errors, LDAP bind failures

### Zabbix Monitoring

- **Host Group:** `Core Services / Authentication`
- **Template:** `Active Directory Domain Controller`
- **Items:**
  - LDAP service port 389 (check)
  - Kerberos service port 88 (check)
  - Replication lag (via `samba-tool drs showrepl`)
  - Database size (`/var/lib/samba/private/sam.ldb`)
- **Triggers:**
  - LDAP port down (High severity)
  - Replication lag > 1 hour (Average severity)
  - Database size > 40GB (Warning)

---

## Backup & Recovery

### Automated Backups (MinIO)

```bash
# Backup script (runs as CronJob in core-auth namespace)
kubectl exec -it -n core-auth network-ad-dc-0 -- bash -c '
  samba-tool domain backup offline --targetdir=/tmp/backup
  tar czf /tmp/network-ad-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp/backup .
  mc cp /tmp/network-ad-backup-*.tar.gz minio/network-ad-backups/
  rm -rf /tmp/backup /tmp/network-ad-backup-*.tar.gz
'
```

**Retention Policy:**
- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

### Manual Backup

```bash
# Offline backup (requires service downtime!)
kubectl scale statefulset -n core-auth network-ad-dc --replicas=0

kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool domain backup offline --targetdir=/var/lib/samba/backup

# Copy backup to local
kubectl cp core-auth/network-ad-dc-0:/var/lib/samba/backup ./network-ad-backup-$(date +%Y%m%d)

kubectl scale statefulset -n core-auth network-ad-dc --replicas=2
```

### Recovery from Backup

```bash
# 1. Stop StatefulSet
kubectl scale statefulset -n core-auth network-ad-dc --replicas=0

# 2. Delete PVCs (CAUTION!)
kubectl delete pvc -n core-auth samba-data-network-ad-dc-0
kubectl delete pvc -n core-auth samba-data-network-ad-dc-1

# 3. Restore backup to new PVC (use Longhorn snapshot restore)

# 4. Restart StatefulSet
kubectl scale statefulset -n core-auth network-ad-dc --replicas=2

# 5. Verify replication
kubectl exec -it -n core-auth network-ad-dc-0 -- samba-tool drs showrepl
```

---

## Troubleshooting

### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -n core-auth network-ad-dc-0 --previous

# Common causes:
# - Invalid admin password (check Secret)
# - PVC mount failure (check Longhorn)
# - Port conflict (check Services)
```

### LDAP Connection Refused

```bash
# Check if service is listening
kubectl exec -it -n core-auth network-ad-dc-0 -- netstat -tuln | grep 389

# Test LDAP from pod
kubectl exec -it -n core-auth network-ad-dc-0 -- ldapsearch -x -H ldap://localhost -b ""

# Check firewall rules (from MikroTik)
/ip firewall filter print where dst-address=192.168.255.51
```

### Replication Failure

```bash
# Force replication sync
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool drs replicate network-ad-dc-1 network-ad-dc-0 \
  DC=network-ad,DC=zsel,DC=opole,DC=pl --full-sync

# Check replication status
kubectl exec -it -n core-auth network-ad-dc-0 -- samba-tool drs showrepl
```

### DNS Not Resolving

```bash
# Check DNS forwarders
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool dns query localhost network-ad.zsel.opole.pl @ ALL

# Update DNS forwarders (if needed)
# Edit configmap-smb.yaml: dns forwarder = 1.1.1.1 9.9.9.9
kubectl rollout restart statefulset -n core-auth network-ad-dc
```

---

## Production Checklist

- [ ] Replace PLACEHOLDER admin password with SealedSecret
- [ ] Configure firewall rules blocking user VLANs from 192.168.255.51-52
- [ ] Retrieve `radius-bind` password and configure FreeRADIUS
- [ ] Create real network admin users (delete example `admin-network`)
- [ ] Set password policy (complexity, length, expiration)
- [ ] Configure automated backups to MinIO
- [ ] Enable Graylog log forwarding
- [ ] Add Zabbix monitoring host
- [ ] Test LDAP connectivity from FreeRADIUS pod
- [ ] Test failover (scale PRIMARY to 0, verify SECONDARY takes over)
- [ ] Document admin passwords in organization password manager (1Password/Bitwarden)

---

## Related Documentation

- [AD Domain Separation Strategy](../../docs/AD-DOMAIN-SEPARATION.md)
- [Network Services Architecture](../../NETWORK-SERVICES-ARCHITECTURE.md)
- [FreeRADIUS Configuration](../freeradius/README.md)
- [GitOps Structure](../../STRUCTURE.md)

---

**Maintained by:** IT Infrastructure Team  
**Last Updated:** 2024-01-15  
**Contact:** it-admins@zsel.opole.pl
