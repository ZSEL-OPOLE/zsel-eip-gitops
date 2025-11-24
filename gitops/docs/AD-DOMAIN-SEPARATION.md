# Active Directory Domain Separation Strategy
> Network Infrastructure vs User Identity - Complete Isolation

**Date:** 2025-11-22  
**Status:** 🔴 CRITICAL SECURITY DESIGN  
**Owner:** Łukasz Kołodziej (Cloud Architect)

---

## 🎯 Rationale

### Why Separate Domains?

**CRITICAL SECURITY PRINCIPLE: Network Infrastructure ≠ User Identity**

1. **Blast Radius Containment:**
   - User account compromise ≠ network device compromise
   - Network device breach ≠ user data exposure
   - Separate trust boundaries = defense in depth

2. **Compliance & Auditing:**
   - Network device access logs (RADIUS) isolated from user activity
   - Different retention policies (network: 90 days, users: 7 years GDPR)
   - Separate security groups for IT vs Teachers/Students

3. **Operational Independence:**
   - Network team can manage network-ad without affecting users
   - User AD can be migrated/upgraded without touching network infrastructure
   - Different backup/DR strategies

4. **Zero Trust Architecture:**
   - No implicit trust between domains
   - Explicit authentication required for cross-domain access
   - Principle of least privilege enforced at domain boundary

---

## 🏗️ Architecture

### Two Independent Domains

```
┌─────────────────────────────────────────────────────────────────┐
│                    ZSEL Network Infrastructure                   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────┐       │
│  │  Domain: network-ad.zsel.opole.pl                    │       │
│  │  ┌────────────────────────────────────────────────┐  │       │
│  │  │  Samba AD DC1: 192.168.255.51 (Primary)       │  │       │
│  │  │  Samba AD DC2: 192.168.255.52 (Secondary)     │  │       │
│  │  └────────────────────────────────────────────────┘  │       │
│  │                                                        │       │
│  │  OU Structure:                                        │       │
│  │  ├── NetworkDevices (57 MikroTik computer objects)  │       │
│  │  ├── ServiceAccounts (RADIUS, monitoring, backup)   │       │
│  │  └── NetworkAdmins (IT team network access only)    │       │
│  │                                                        │       │
│  │  Purpose: Infrastructure authentication ONLY          │       │
│  │  Scope:   MikroTik RADIUS, SNMP, monitoring          │       │
│  │  VLAN:    600 (Management - isolated)                │       │
│  └──────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘

                              ⚠️ NO TRUST ⚠️
                            (Firewall between)

┌─────────────────────────────────────────────────────────────────┐
│                    ZSEL User Identity System                     │
│                                                                   │
│  ┌──────────────────────────────────────────────────────┐       │
│  │  Domain: ad.zsel.opole.pl                            │       │
│  │  ┌────────────────────────────────────────────────┐  │       │
│  │  │  Samba AD DC1: 192.168.10.50 (Primary)        │  │       │
│  │  │  Samba AD DC2: 192.168.10.51 (Secondary)      │  │       │
│  │  │  Samba AD DC3: 192.168.10.52 (Tertiary)       │  │       │
│  │  └────────────────────────────────────────────────┘  │       │
│  │                                                        │       │
│  │  OU Structure:                                        │       │
│  │  ├── Users                                            │       │
│  │  │   ├── Teachers (nauczyciele)                      │       │
│  │  │   ├── Students (uczniowie - per class)           │       │
│  │  │   └── Staff (administracja)                       │       │
│  │  ├── Groups                                           │       │
│  │  │   ├── Moodle-Admins                               │       │
│  │  │   ├── BBB-Moderators                              │       │
│  │  │   └── WiFi-Users                                  │       │
│  │  ├── Computers (workstations, laptops)              │       │
│  │  └── ServiceAccounts (Moodle, BBB, etc.)            │       │
│  │                                                        │       │
│  │  Purpose: User authentication & authorization         │       │
│  │  Scope:   Moodle, BBB, WiFi, file shares, SSO        │       │
│  │  VLAN:    10 (Server - different network)            │       │
│  └──────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔒 Security Boundaries

### Network AD (network-ad.zsel.opole.pl)

**IP Allocation:**
- Primary DC: 192.168.255.51/28 (VLAN 600)
- Secondary DC: 192.168.255.52/28 (VLAN 600)
- **NO access from user VLANs (101-104, 110, 208-246)**

**Access Control:**
- LDAP/LDAPS: Only from VLAN 600 (management)
- Kerberos: Only from VLAN 600
- DNS: Only for `.network-ad.zsel.opole.pl` queries
- **Firewall rules block all traffic from user VLANs to 192.168.255.51-52**

**Authentication Scope:**
- MikroTik devices (57 total) via RADIUS
- Network monitoring systems (Zabbix, Prometheus)
- Network management tools (WinBox, SSH, Ansible)
- Backup services (MinIO S3 writes)

**User Accounts (Network AD):**
```
OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl
├── CN=admin-network-01  (IT Admin - full access)
├── CN=admin-network-02  (IT Admin - full access)
├── CN=operator-network-01  (Network Operator - read+write, no reboot)
├── CN=operator-network-02  (Network Operator)
└── CN=monitoring  (Read-only for dashboards)

OU=ServiceAccounts,DC=network-ad,DC=zsel,DC=opole,DC=pl
├── CN=radius-bind  (FreeRADIUS LDAP queries)
├── CN=prometheus-snmp  (SNMP polling)
├── CN=zabbix-monitor  (Zabbix checks)
└── CN=backup-service  (MinIO backup writes)
```

**Total Users:** ~10 (IT staff only, NO students/teachers)

---

### User AD (ad.zsel.opole.pl)

**IP Allocation:**
- Primary DC: 192.168.10.50/24 (VLAN 10 - Server)
- Secondary DC: 192.168.10.51/24
- Tertiary DC: 192.168.10.52/24
- **Accessible from user VLANs (101-104, 110) for WiFi/Moodle auth**

**Access Control:**
- LDAP/LDAPS: From VLAN 10, 101-104, 110, 208-246 (controlled via firewall)
- Kerberos: Same as above
- DNS: For `.ad.zsel.opole.pl` queries
- **NO access to VLAN 600 (management) - firewall block**

**Authentication Scope:**
- Moodle LMS (teachers + students)
- BigBlueButton (video conferencing)
- WiFi (WPA2-Enterprise via RADIUS - separate instance)
- File shares (SMB/CIFS)
- Email (if integrated)
- SSO for web apps

**User Accounts (User AD):**
```
OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl
├── OU=Teachers (150 accounts)
│   ├── CN=Kowalski Jan
│   ├── CN=Nowak Anna
│   └── ...
├── OU=Students (800 accounts)
│   ├── OU=Class-1A
│   ├── OU=Class-1B
│   └── ...
├── OU=Staff (50 accounts)
│   └── CN=Sekretariat

OU=ServiceAccounts,DC=ad,DC=zsel,DC=opole,DC=pl
├── CN=moodle-ldap-bind
├── CN=bbb-auth
└── CN=wifi-radius-bind  # Different from network RADIUS!
```

**Total Users:** ~1000 (students + teachers + staff)

---

## 🚫 What's NOT Allowed

### Cross-Domain Trust = PROHIBITED

**NO trust relationship between network-ad.zsel.opole.pl ↔ ad.zsel.opole.pl**

❌ User in `ad.zsel.opole.pl` CANNOT log into MikroTik  
❌ Network admin in `network-ad.zsel.opole.pl` CANNOT access Moodle  
❌ Service account from one domain CANNOT query other domain  
❌ Replication between domains DISABLED  

**Rationale:**
- Student account compromise ≠ network infrastructure access
- Network device breach ≠ student data exposure
- Separate audit trails, separate backups, separate DR

---

## 🔐 Authentication Flows

### Flow 1: Network Engineer Logs into MikroTik

```
1. Engineer opens WinBox → CS-GW-CPD-01 (192.168.255.2)
2. Enters username: admin-network-01, password: ******
3. MikroTik sends RADIUS request → 192.168.255.50 (FreeRADIUS)
4. FreeRADIUS queries LDAP → network-ad.zsel.opole.pl (192.168.255.51)
5. Network AD validates credentials → returns group: IT-Admins
6. FreeRADIUS maps IT-Admins → MikroTik group: network-admin
7. MikroTik grants full access (read+write+reboot+policy)
8. Session logged to Graylog + Zabbix
```

**Domain Used:** `network-ad.zsel.opole.pl` ONLY

---

### Flow 2: Student Logs into WiFi

```
1. Student connects to SSID: ZSEL-Student
2. WPA2-Enterprise prompts for username/password
3. cAP ax sends RADIUS request → 192.168.10.100 (User RADIUS - DIFFERENT!)
4. User RADIUS queries LDAP → ad.zsel.opole.pl (192.168.10.50)
5. User AD validates student credentials → returns group: Students
6. User RADIUS maps Students → VLAN 110 (Student Network)
7. cAP ax assigns VLAN 110 + internet access (no VLAN 600 access)
8. Session logged to User AD logs (separate from network logs)
```

**Domain Used:** `ad.zsel.opole.pl` ONLY

**CRITICAL:** WiFi APs authenticate via CAPsMAN (network-ad) but WiFi USERS authenticate via User RADIUS (ad.zsel.opole.pl)

---

### Flow 3: Teacher Accesses Moodle

```
1. Teacher opens https://moodle.zsel.opole.pl
2. Clicks "Login with AD"
3. Moodle sends LDAP bind → ad.zsel.opole.pl (192.168.10.50)
4. User AD validates teacher credentials → returns groups: Teachers, Moodle-Admins
5. Moodle maps groups → permissions (course creation, grading)
6. Session established (no network device access)
```

**Domain Used:** `ad.zsel.opole.pl` ONLY

---

## 🛡️ Firewall Rules (MikroTik)

### Protect Network AD from Users

```routeros
# On CS-GW-CPD-01 (Core Router)

# Rule 1: Block all user VLANs from accessing Network AD DCs
/ip firewall filter
add chain=forward \
    src-address-list=user-vlans \
    dst-address=192.168.255.51,192.168.255.52 \
    action=drop \
    comment="BLOCK: Users cannot access Network AD"

# Rule 2: Block all user VLANs from accessing FreeRADIUS (network)
add chain=forward \
    src-address-list=user-vlans \
    dst-address=192.168.255.50 \
    protocol=udp dst-port=1812,1813 \
    action=drop \
    comment="BLOCK: Users cannot query network RADIUS"

# Rule 3: Allow only VLAN 600 (management) to Network AD
add chain=forward \
    src-address=192.168.255.0/28 \
    dst-address=192.168.255.51,192.168.255.52 \
    protocol=tcp dst-port=389,636,88 \
    action=accept \
    comment="ALLOW: Management VLAN to Network AD"

# Address list for user VLANs
/ip firewall address-list
add list=user-vlans address=192.168.101.0/24 comment="VLAN 101 - Dydaktyka P0"
add list=user-vlans address=192.168.102.0/24 comment="VLAN 102 - Dydaktyka P1"
add list=user-vlans address=192.168.103.0/24 comment="VLAN 103 - Dydaktyka P2"
add list=user-vlans address=192.168.104.0/24 comment="VLAN 104 - Dydaktyka P3"
add list=user-vlans address=192.168.110.0/24 comment="VLAN 110 - WiFi Student"
# ... (all 54 user VLANs)
```

### Protect Management VLAN from Users

```routeros
# Rule 4: Block all user VLANs from accessing management VLAN
/ip firewall filter
add chain=forward \
    src-address-list=user-vlans \
    dst-address=192.168.255.0/28 \
    action=drop \
    comment="BLOCK: Users cannot access management VLAN 600"

# Exception: Allow DNS queries to management DNS (192.168.255.53)
add chain=forward \
    src-address-list=user-vlans \
    dst-address=192.168.255.53 \
    protocol=udp dst-port=53 \
    action=accept \
    comment="ALLOW: DNS queries from users"
```

---

## 📊 Comparison Matrix

| Feature | Network AD (network-ad.zsel.opole.pl) | User AD (ad.zsel.opole.pl) |
|---------|----------------------------------------|----------------------------|
| **Purpose** | Network device authentication | User identity & authorization |
| **Users** | ~10 IT staff | ~1000 students + teachers |
| **Devices** | 57 MikroTik, monitoring | Workstations, laptops, mobile |
| **VLAN** | 600 (Management) | 10 (Server), 101-104, 110, 208-246 |
| **IP Range** | 192.168.255.51-52 | 192.168.10.50-52 |
| **RADIUS** | FreeRADIUS (network) @ .50 | User RADIUS @ 192.168.10.100 |
| **Access from Users** | ❌ BLOCKED | ✅ Allowed (controlled) |
| **Access from Mgmt** | ✅ Allowed | ❌ NO (one-way only) |
| **Trust Relationship** | ❌ NO | ❌ NO |
| **Replication** | DC1 ↔ DC2 (internal) | DC1 ↔ DC2 ↔ DC3 (internal) |
| **Backup** | MinIO S3 (network) | QNAP NAS (user data) |
| **Retention** | 90 days (compliance) | 7 years (GDPR) |
| **Monitoring** | Zabbix + Prometheus | User activity logs |
| **K8s Namespace** | `core-auth` | `identity-system` |
| **ArgoCD Project** | `core-services` | `user-services` |

---

## 🚀 Deployment Strategy

### Phase 1: Deploy Network AD (First)
1. Create namespace `core-auth`
2. Deploy Samba AD StatefulSet (network-ad.zsel.opole.pl)
3. Initialize domain, create OUs
4. Deploy FreeRADIUS (LDAP bind to network AD)
5. Configure MikroTik RADIUS clients
6. Test: IT admin login to MikroTik via RADIUS

### Phase 2: Deploy User AD (Later - Separate Project)
1. Create namespace `identity-system`
2. Deploy Samba AD StatefulSet (ad.zsel.opole.pl)
3. Initialize domain, create student/teacher OUs
4. Deploy User RADIUS (LDAP bind to user AD)
5. Configure Moodle LDAP
6. Configure WiFi WPA2-Enterprise
7. Test: Student login to WiFi, teacher login to Moodle

### Phase 3: Enforce Isolation
1. Apply firewall rules (block cross-domain traffic)
2. Verify NO trust between domains
3. Audit logs: separate Graylog streams
4. Monitor: separate Zabbix host groups

---

## 🔍 Monitoring & Auditing

### Separate Log Streams

**Graylog Configuration:**
```yaml
# Stream 1: Network AD Events
stream:
  name: "Network-AD-Authentication"
  rules:
    - field: "source"
      value: "192.168.255.51|192.168.255.52"
    - field: "application"
      value: "samba-ad|freeradius"
  retention: 90 days

# Stream 2: User AD Events
stream:
  name: "User-AD-Authentication"
  rules:
    - field: "source"
      value: "192.168.10.50|192.168.10.51|192.168.10.52"
    - field: "application"
      value: "samba-ad|user-radius|moodle"
  retention: 7 years  # GDPR compliance
```

### Separate Zabbix Host Groups

```
Zabbix Host Groups:
├── Network-Infrastructure
│   ├── Network-AD-DCs (2 hosts)
│   ├── FreeRADIUS (3 hosts)
│   └── MikroTik-Devices (57 hosts)
└── User-Services
    ├── User-AD-DCs (3 hosts)
    ├── User-RADIUS (2 hosts)
    └── Moodle-Servers (2 hosts)
```

---

## ✅ Validation Checklist

### Network AD Isolation
- [ ] Network AD accessible only from VLAN 600
- [ ] User VLANs CANNOT reach 192.168.255.51-52
- [ ] Firewall rules tested (ping, LDAP, Kerberos)
- [ ] RADIUS authentication working for MikroTik
- [ ] NO trust relationship with User AD
- [ ] Separate backup to MinIO S3

### User AD Isolation
- [ ] User AD accessible from user VLANs
- [ ] User AD CANNOT reach VLAN 600
- [ ] WiFi authentication working (students)
- [ ] Moodle LDAP working (teachers)
- [ ] NO trust relationship with Network AD
- [ ] Separate backup to QNAP NAS

### Cross-Domain Verification
- [ ] User from ad.zsel.opole.pl CANNOT login to MikroTik
- [ ] Network admin from network-ad CANNOT login to Moodle
- [ ] Service accounts isolated (no cross-domain queries)
- [ ] Logs separated in Graylog
- [ ] Monitoring separated in Zabbix

---

## 📚 References

- [Active Directory Forest Design](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/forest-design-models)
- [Zero Trust Network Architecture](https://www.nist.gov/publications/zero-trust-architecture)
- [RADIUS Best Practices](https://freeradius.org/radiusd/man/rlm_ldap.html)
- [Samba AD DC Documentation](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller)

---

**Status:** 🟢 Design Approved  
**Next Action:** Implement Network AD manifests (Phase 1)  
**Owner:** Łukasz Kołodziej  
**Reviewed:** IT Team ZSEL + Network Engineer

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-22  
**Related Documents:**
- [NETWORK-SERVICES-ARCHITECTURE.md](../NETWORK-SERVICES-ARCHITECTURE.md)
- [GitOps README.md](./README.md)
- [Security Policy](../../docs/SECURITY-POLICY.md)
