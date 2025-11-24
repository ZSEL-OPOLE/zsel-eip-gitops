# PacketFence Captive Portal - WiFi Authentication

**URL:** https://portal.zsel.opole.pl  
**IP:** 192.168.255.61 (VLAN 600 Management)  
**Purpose:** WiFi captive portal for teachers and students  
**Namespace:** `identity-system`

---

## Architecture

```
User Device → cAP ax WiFi AP (16 devices)
  ↓ HTTP redirect
Captive Portal (portal.zsel.opole.pl)
  ↓ RADIUS Access-Request
FreeRADIUS User WiFi (192.168.255.60)
  ↓ LDAP Bind
User AD (ad.zsel.opole.pl)
  ↓ Check group membership
Teachers → VLAN 20
Students → VLAN 30
```

---

## Components

### 1. PacketFence (2 replicas)
- Captive portal web interface
- RADIUS integration (192.168.255.60)
- LDAP authentication (User AD)
- VLAN assignment based on AD groups
- Session management

### 2. MariaDB (1 replica)
- PacketFence database backend
- User sessions storage
- MAC address tracking
- 20Gi persistent storage (Longhorn)

### 3. Redis (1 replica)
- Session cache
- Rate limiting
- 256MB memory limit (LRU eviction)

---

## VLAN Assignment

| AD Group | VLAN | Network | Description |
|----------|------|---------|-------------|
| Teachers | 20 | 192.168.20.0/24 | Nauczyciele - full access |
| Students | 30 | 192.168.30.0/24 | Uczniowie - restricted |

---

## Deployment

### Prerequisites
1. User AD deployed (ad.zsel.opole.pl)
2. FreeRADIUS User WiFi deployed (192.168.255.60)
3. DNS record: `portal.zsel.opole.pl → 192.168.255.61`
4. cert-manager installed (for HTTPS)

### Install

```bash
# Deploy via ArgoCD
kubectl apply -f ../../argocd/apps/identity-apps.yaml

# Wait for sync
argocd app sync identity-system/captive-portal
argocd app wait identity-system/captive-portal --health

# Verify deployment
kubectl get pods -n identity-system -l app.kubernetes.io/name=captive-portal
```

---

## Configuration

### Retrieve sso-wifi-bind password

```bash
# From User AD pod
kubectl exec -it -n identity-system user-ad-dc-0 -- \
  samba-tool user show sso-wifi-bind

# Create sealed secret
PASSWORD="<retrieved_password>"
kubectl create secret generic packetfence-secrets \
  --namespace=identity-system \
  --from-literal=ldap-bind-password="$PASSWORD" \
  --from-literal=mysql-root-password="$(openssl rand -base64 32)" \
  --from-literal=mysql-password="$(openssl rand -base64 32)" \
  --from-literal=radius-secret="$(openssl rand -base64 32)" \
  --from-literal=redis-password="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml --cert=../../environments/production/sealed-secrets/pub-cert.pem \
  > overlays/production/sealed-secrets/packetfence-secrets.yaml
```

### MikroTik WiFi AP Configuration

```routeros
# On each cAP ax (16 devices)
/caps-man security
add name=zsel-wifi-security \
  authentication-types=wpa2-psk,wpa-eap \
  encryption=aes-ccm \
  eap-methods=peap \
  eap-radius-accounting=yes

# Configure RADIUS
/radius
add address=192.168.255.60 \
  secret="<WIFI_RADIUS_SECRET>" \
  service=wireless

# Create WiFi profile
/caps-man configuration
add name=zsel-wifi \
  ssid="ZSEL-WiFi" \
  security=zsel-wifi-security \
  datapath.client-to-client-forwarding=no

# Apply to APs
/caps-man provisioning
add action=create-dynamic-enabled \
  master-configuration=zsel-wifi \
  name-format=prefix-identity
```

---

## Testing

### 1. Connect to WiFi
```bash
# From student device
SSID: ZSEL-WiFi
# Browser redirect → https://portal.zsel.opole.pl
```

### 2. Login credentials
```
Username: jan.kowalski
Password: <user_ad_password>
```

### 3. Verify VLAN assignment
```bash
# On MikroTik router
/ip dhcp-server lease print where mac-address=<device_mac>
# Should show VLAN 20 (Teachers) or 30 (Students)
```

### 4. Check PacketFence logs
```bash
kubectl logs -n identity-system deployment/packetfence -f
```

---

## Monitoring

### Graylog Integration
- **Stream:** `WiFi-Authentication`
- **Inputs:** Syslog UDP 514 from 192.168.255.61
- **Retention:** 30 days

### Zabbix Monitoring
- **Host:** packetfence.identity-system
- **Items:**
  - HTTP portal availability (port 80/443)
  - RADIUS service (port 1812/1813)
  - MariaDB connections
  - Redis memory usage
  - Active sessions count

---

## Troubleshooting

### User cannot connect
```bash
# Check RADIUS logs (FreeRADIUS User WiFi)
kubectl logs -n identity-system deployment/freeradius-user-wifi -f

# Check PacketFence logs
kubectl logs -n identity-system deployment/packetfence -f

# Verify LDAP bind
kubectl exec -it -n identity-system user-ad-dc-0 -- \
  ldapsearch -x -H ldap://localhost \
  -D "CN=sso-wifi-bind,OU=SSOApps,OU=ServiceAccounts,DC=ad,DC=zsel,DC=opole,DC=pl" \
  -W -b "OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl" \
  "(sAMAccountName=jan.kowalski)"
```

### Wrong VLAN assignment
```bash
# Check AD group membership
kubectl exec -it -n identity-system user-ad-dc-0 -- \
  samba-tool group listmembers Teachers

# Verify PacketFence VLAN config
kubectl exec -it -n identity-system deployment/packetfence -- \
  cat /usr/local/pf/conf/pf.conf | grep vlan
```

### Portal not accessible
```bash
# Check Ingress
kubectl get ingress -n identity-system packetfence-portal

# Check certificate
kubectl get certificate -n identity-system packetfence-portal-tls

# Check DNS
nslookup portal.zsel.opole.pl
```

---

## Production Checklist

- [ ] Deploy User AD (ad.zsel.opole.pl)
- [ ] Deploy FreeRADIUS User WiFi (192.168.255.60)
- [ ] Retrieve sso-wifi-bind password
- [ ] Generate sealed secrets (5 secrets)
- [ ] Deploy PacketFence via ArgoCD
- [ ] Configure DNS: portal.zsel.opole.pl → 192.168.255.61
- [ ] Configure cert-manager for HTTPS
- [ ] Configure 16 cAP ax with RADIUS
- [ ] Test login with teacher account (VLAN 20)
- [ ] Test login with student account (VLAN 30)
- [ ] Configure Graylog stream
- [ ] Configure Zabbix monitoring
- [ ] Document troubleshooting procedures

---

**Maintained by:** IT Infrastructure Team  
**Contact:** it@zsel.opole.pl
