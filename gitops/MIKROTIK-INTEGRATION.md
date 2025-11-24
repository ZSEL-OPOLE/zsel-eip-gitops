# ============================================
# MIKROTIK INTEGRATION - K3s SERVICES
# ============================================
# Date: 2024-11-22
# Purpose: Configure all MikroTik devices to use K3s infrastructure services
# Services: DNS, NTP, RADIUS (device + WiFi), Syslog (Graylog)
# ============================================

## DNS Configuration (192.168.255.53 - Bind9)

### All MikroTik Devices (57 devices)
```routeros
# Configure DNS servers
/ip dns
set servers=192.168.255.53,1.1.1.1
set allow-remote-requests=no
set cache-size=2048KiB

# Add static DNS entries for AD domains
/ip dns static
add name=network-ad.zsel.opole.pl address=192.168.255.51 comment="Network AD Primary"
add name=ad.zsel.opole.pl address=192.168.10.50 comment="User AD Primary"
add name=portal.zsel.opole.pl address=192.168.255.61 comment="WiFi Captive Portal"
add name=radius-network.zsel.opole.pl address=192.168.255.50 comment="RADIUS Network Devices"
add name=radius-wifi.zsel.opole.pl address=192.168.255.60 comment="RADIUS WiFi Users"
```

---

## NTP Configuration (192.168.255.54 - Chrony)

### All MikroTik Devices (57 devices)
```routeros
# Primary NTP: K3s Chrony (stratum 1-2 from pl.pool.ntp.org)
# Fallback: External NTP (stratum 2-3)

/system ntp client
set enabled=yes mode=unicast

/system ntp client servers
add address=192.168.255.54 comment="K3s Chrony Primary"
add address=pl.pool.ntp.org comment="External Fallback"
add address=tempus1.gum.gov.pl comment="Polish Time Server"
```

---

## RADIUS Configuration (Device Authentication)

### Routers (5 CCR2216)
```routeros
# RADIUS for SSH/Winbox/API login
# Backend: Network AD (network-ad.zsel.opole.pl)
# Users: IT Admins (OU=NetworkAdmins)

/radius
add address=192.168.255.50 \
    secret="<MIKROTIK_RADIUS_SECRET>" \
    service=login \
    timeout=3s \
    comment="FreeRADIUS Network (Network AD)"

/radius incoming
set accept=yes

# Enable RADIUS authentication (fallback to local)
/user aaa
set use-radius=yes default-group=read
```

### Switches AGG/DIST (22 devices: 6 CRS518 + 16 CRS354)
```routeros
/radius
add address=192.168.255.50 \
    secret="<MIKROTIK_RADIUS_SECRET>" \
    service=login \
    timeout=3s \
    comment="FreeRADIUS Network"

/user aaa
set use-radius=yes default-group=read
```

### Switches ACC/PoE (14 devices: 13 CRS326 + 1 CRS328)
```routeros
/radius
add address=192.168.255.50 \
    secret="<MIKROTIK_RADIUS_SECRET>" \
    service=login \
    timeout=3s \
    comment="FreeRADIUS Network"

/user aaa
set use-radius=yes default-group=read
```

---

## WiFi Configuration (CAPsMAN + Captive Portal)

### CCR2216 Controllers (CS-GW-CPD-01, CS-GW-CPD-02)

**RADIUS Configuration for WiFi:**
```routeros
# WiFi RADIUS authentication
# Backend: User AD (ad.zsel.opole.pl)
# Users: Teachers + Students (OU=Users)

/radius
add address=192.168.255.60 \
    secret="<WIFI_RADIUS_SECRET>" \
    service=wireless \
    timeout=3s \
    accounting=yes \
    comment="FreeRADIUS WiFi (User AD)"
```

**CAPsMAN Security Profile:**
```routeros
/caps-man security
add name=zsel-wifi-enterprise \
    authentication-types=wpa2-eap \
    encryption=aes-ccm \
    eap-methods=peap,eap-tls \
    eap-radius-accounting=yes \
    group-encryption=aes-ccm \
    comment="WPA2-Enterprise for Teachers/Students"
```

**CAPsMAN Configuration Profile:**
```routeros
/caps-man configuration
add name=zsel-wifi-config \
    ssid="ZSEL-WiFi" \
    security=zsel-wifi-enterprise \
    country=poland \
    channel.frequency=5000-6000 \
    channel.width=20/40/80mhz-XXXX \
    datapath.client-to-client-forwarding=no \
    datapath.bridge=bridge-local \
    datapath.vlan-mode=use-tag \
    comment="Enterprise WiFi with Captive Portal"
```

**Captive Portal Integration:**
```routeros
# HTTP redirect to portal.zsel.opole.pl
/ip hotspot profile
add name=zsel-portal \
    login-by=http-chap,http-pap \
    use-radius=yes \
    html-directory=hotspot-custom \
    http-proxy=0.0.0.0:0

/ip hotspot
add name=zsel-wifi \
    interface=bridge-local \
    address-pool=pool-wifi-guest \
    profile=zsel-portal \
    idle-timeout=12h \
    keepalive-timeout=5m

# RADIUS accounting for captive portal
/radius
add address=192.168.255.60 \
    secret="<WIFI_RADIUS_SECRET>" \
    service=hotspot \
    timeout=3s \
    accounting=yes
```

**VLAN Assignment (based on AD group membership):**
```routeros
# Dynamic VLAN assignment via RADIUS attributes
# Teachers → VLAN 20 (192.168.20.0/24)
# Students → VLAN 30 (192.168.30.0/24)

/interface bridge vlan
add bridge=bridge-local tagged=bridge-local,sfp28-1,sfp28-2 vlan-ids=20 comment="Teachers WiFi"
add bridge=bridge-local tagged=bridge-local,sfp28-1,sfp28-2 vlan-ids=30 comment="Students WiFi"

# CAPsMAN provisioning with dynamic VLAN
/caps-man provisioning
add action=create-dynamic-enabled \
    master-configuration=zsel-wifi-config \
    name-format=prefix-identity \
    slave-configurations=zsel-wifi-config
```

---

## Syslog Configuration (Graylog 192.168.255.55)

### All MikroTik Devices (57 devices)
```routeros
# Send logs to Graylog via Syslog UDP 514

/system logging action
add name=remote-graylog \
    target=remote \
    remote=192.168.255.55 \
    remote-port=514 \
    src-address=<device_management_ip> \
    bsd-syslog=yes

# Log categories
/system logging
add action=remote-graylog topics=info,warning,error,critical prefix="<DEVICE_HOSTNAME>"
add action=remote-graylog topics=firewall prefix="FW-<DEVICE_HOSTNAME>"
add action=remote-graylog topics=system prefix="SYS-<DEVICE_HOSTNAME>"
add action=remote-graylog topics=wireless prefix="WIFI-<DEVICE_HOSTNAME>"

# Example for CCR2216-BCU-01
/system logging action
add name=remote-graylog \
    target=remote \
    remote=192.168.255.55 \
    remote-port=514 \
    src-address=192.168.255.2 \
    bsd-syslog=yes

/system logging
add action=remote-graylog topics=info,warning,error,critical prefix="CCR2216-BCU-01"
add action=remote-graylog topics=firewall prefix="FW-BCU-01"
```

---

## Deployment Checklist

### 1. Generate Secrets
```bash
# RADIUS secret for network devices (57 MikroTik)
MIKROTIK_RADIUS_SECRET=$(openssl rand -base64 32)
echo "MIKROTIK_RADIUS_SECRET: $MIKROTIK_RADIUS_SECRET"

# RADIUS secret for WiFi (16 cAP ax)
WIFI_RADIUS_SECRET=$(openssl rand -base64 32)
echo "WIFI_RADIUS_SECRET: $WIFI_RADIUS_SECRET"

# Save to sealed secrets
kubectl create secret generic freeradius-network-secrets \
  --namespace=core-auth \
  --from-literal=mikrotik-radius-secret="$MIKROTIK_RADIUS_SECRET" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml --cert=environments/production/sealed-secrets/pub-cert.pem \
  > apps/freeradius-network/overlays/production/sealed-secrets/mikrotik-radius.yaml

kubectl create secret generic freeradius-wifi-secrets \
  --namespace=identity-system \
  --from-literal=wifi-radius-secret="$WIFI_RADIUS_SECRET" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml --cert=environments/production/sealed-secrets/pub-cert.pem \
  > apps/freeradius-user-wifi/overlays/production/sealed-secrets/wifi-radius.yaml
```

### 2. Deploy K3s Services
```bash
# Deploy DNS
argocd app sync dns
argocd app wait dns --health

# Deploy NTP (coming next)
argocd app sync ntp
argocd app wait ntp --health

# Verify services
kubectl get svc -n core-network bind9
kubectl get svc -n core-network ntp
kubectl get svc -n core-auth freeradius-network
kubectl get svc -n identity-system freeradius-user-wifi
```

### 3. Update MikroTik Configs

**Option A: Bulk deployment (all devices)**
```bash
# Create deployment script
cd konfiguracje-mikrotik/helpers
./deploy-k3s-integration.sh --all --dns --ntp --radius --syslog
```

**Option B: Manual per device**
```bash
# Copy sections from this guide to each device
# SSH to device
ssh admin@192.168.255.2 -p 2222

# Paste config sections
/ip dns set servers=192.168.255.53,1.1.1.1
/system ntp client servers add address=192.168.255.54
/radius add address=192.168.255.50 secret="<SECRET>" service=login
```

### 4. Test Integration

**DNS Test:**
```routeros
/ping network-ad.zsel.opole.pl
/ping ad.zsel.opole.pl
/ping portal.zsel.opole.pl
```

**NTP Test:**
```routeros
/system ntp client print
# Should show: status=synchronized, stratum=2-3
```

**RADIUS Test (Device Login):**
```bash
# From workstation, login to MikroTik via SSH
ssh admin@192.168.255.2 -p 2222
# Should authenticate against Network AD (network-ad.zsel.opole.pl)
```

**WiFi Test:**
```bash
# Connect to SSID: ZSEL-WiFi
# Should redirect to portal.zsel.opole.pl
# Login with AD credentials (teacher/student)
# Verify VLAN assignment (20 or 30)
```

---

## Configuration Summary

| Service | IP | Port | MikroTik Config Section |
|---------|----|----|------------------------|
| DNS (Bind9) | 192.168.255.53 | 53 UDP/TCP | `/ip dns` |
| NTP (Chrony) | 192.168.255.54 | 123 UDP | `/system ntp client` |
| RADIUS Network | 192.168.255.50 | 1812/1813 UDP | `/radius` service=login |
| RADIUS WiFi | 192.168.255.60 | 1812/1813/3799 UDP | `/radius` service=wireless |
| Captive Portal | 192.168.255.61 | 80/443 TCP | `/ip hotspot` |
| Graylog | 192.168.255.55 | 514 UDP | `/system logging action` |

---

## Device Categories

### Category 1: Routers (5 CCR2216)
- DNS + NTP + RADIUS (device login) + Syslog
- **Plus CAPsMAN:** WiFi RADIUS + Captive Portal (BCU-01, BCU-02 only)

### Category 2: Switches AGG/DIST (22 devices)
- DNS + NTP + RADIUS (device login) + Syslog

### Category 3: Switches ACC/PoE (14 devices)
- DNS + NTP + RADIUS (device login) + Syslog

### Category 4: WiFi APs (16 cAP ax)
- Managed by CAPsMAN (no local config)
- RADIUS + Captive Portal configured on controllers

---

**Next Steps:**
1. ✅ DNS (Bind9) deployed
2. 🔄 NTP (Chrony) - creating next
3. ⏳ MikroTik config updates - after NTP deployment
4. ⏳ Sealed secrets generation
5. ⏳ Production testing

**Maintained by:** IT Infrastructure Team  
**Contact:** it@zsel.opole.pl
