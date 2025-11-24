# Network AD Users - network-ad.zsel.opole.pl

> **Domena:** network-ad.zsel.opole.pl  
> **Namespace:** core-auth  
> **IP:** 192.168.255.51 (PRIMARY), 192.168.255.52 (SECONDARY)  
> **Cel:** Autentykacja infrastruktury sieciowej (MikroTik) via RADIUS

## 👥 Użytkownicy Network AD

### IT Administrators (10 osób)
**OU:** `OU=ITAdmins,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl`

| Username | Imię Nazwisko | Email | Rola | Uprawnienia MikroTik |
|----------|---------------|-------|------|---------------------|
| lukasz.kolodziej | Łukasz Kołodziej | l.kolodziej@zsel.opole.pl | Cloud Architect | full (read+write+reboot+policy) |
| jan.kowalski | Jan Kowalski | j.kowalski@zsel.opole.pl | Network Engineer | full |
| anna.nowak | Anna Nowak | a.nowak@zsel.opole.pl | System Admin | full |
| piotr.wisniewski | Piotr Wiśniewski | p.wisniewski@zsel.opole.pl | IT Manager | full |
| maria.lewandowska | Maria Lewandowska | m.lewandowska@zsel.opole.pl | Security Engineer | full |
| tomasz.kaminski | Tomasz Kamiński | t.kaminski@zsel.opole.pl | DevOps Engineer | full |
| katarzyna.wojcik | Katarzyna Wójcik | k.wojcik@zsel.opole.pl | Network Admin | full |
| marcin.kowalczyk | Marcin Kowalczyk | m.kowalczyk@zsel.opole.pl | Infrastructure Lead | full |
| agnieszka.zielinska | Agnieszka Zielińska | a.zielinska@zsel.opole.pl | IT Support Lead | full |
| robert.szymanski | Robert Szymański | r.szymanski@zsel.opole.pl | Network Architect | full |

**Grupa AD:** `Domain Admins`  
**MikroTik Group:** `network-admin` (full access)

---

### Network Operators (5 osób)
**OU:** `OU=Operators,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl`

| Username | Imię Nazwisko | Email | Rola | Uprawnienia MikroTik |
|----------|---------------|-------|------|---------------------|
| operator01 | Operator Sieciowy 1 | operator01@zsel.opole.pl | Network Operator | read+write (NO reboot) |
| operator02 | Operator Sieciowy 2 | operator02@zsel.opole.pl | Network Operator | read+write (NO reboot) |
| operator03 | Operator Sieciowy 3 | operator03@zsel.opole.pl | Network Operator | read+write (NO reboot) |
| operator04 | Operator Sieciowy 4 | operator04@zsel.opole.pl | Network Operator | read+write (NO reboot) |
| operator05 | Operator Sieciowy 5 | operator05@zsel.opole.pl | Network Operator | read+write (NO reboot) |

**Grupa AD:** `Network-Operators`  
**MikroTik Group:** `network-operator` (read+write, NO reboot/policy)

---

### Service Accounts (5 kont)
**OU:** `OU=ServiceAccounts,DC=network-ad,DC=zsel,DC=opole,DC=pl`

| Username | Cel | Używane Przez | Hasło |
|----------|-----|---------------|-------|
| radius-bind | LDAP bind dla FreeRADIUS | FreeRADIUS Network (192.168.255.50) | 32-char random (Sealed Secret) |
| prometheus-snmp | SNMP polling MikroTik | Prometheus (namespace: mon-observability) | 32-char random (Sealed Secret) |
| zabbix-monitor | Zabbix monitoring | Zabbix Server (namespace: mon-zabbix) | 32-char random (Sealed Secret) |
| backup-service | Backupy konfiguracji | MinIO backup jobs | 32-char random (Sealed Secret) |
| monitoring-readonly | Read-only dashboards | Grafana (namespace: mon-observability) | 32-char random (Sealed Secret) |

**Grupa AD:** `Service-Accounts`  
**MikroTik Group:** N/A (te konta NIE logują się do MikroTik)

---

## 📁 Pliki LDIF

### admins.ldif
Zawiera 10 IT administratorów z pełnymi uprawnieniami.

### operators.ldif
Zawiera 5 operatorów sieciowych z ograniczonymi uprawnieniami (bez reboot).

### service-accounts.ldif
Zawiera 5 kont serwisowych dla integracji systemów.

---

## 🔐 Hasła

### IT Administrators & Operators
- **Format:** Losowe 16-znaków (A-Za-z0-9!@#$%^&*)
- **Policy:** Must change at next login = YES
- **Expiration:** 90 dni
- **Complexity:** Wymagane (min. 3 z 4 kategorii)

**Przykład generowania hasła:**
```bash
cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w 16 | head -n 1
# Output: Xy9#mK2pQr4$vL8z
```

### Service Accounts
- **Format:** Losowe 32-znaków (A-Za-z0-9)
- **Policy:** Never expires, password never changes
- **Storage:** Kubernetes Sealed Secrets

**Przykład generowania hasła serwisowego:**
```bash
cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 32 | head -n 1
# Output: 7Km9Pq2Xv5Lr8Wy3Zt6Nb4Hg1Jd0Fc9
```

---

## 🚀 Deployment

### 1. Import użytkowników

```bash
cd gitops/users/network-ad/
./apply.sh
```

Skrypt automatycznie:
- Kopiuje LDIF do pod `network-ad-dc-0`
- Importuje via `samba-tool ldap import`
- Ustawia hasła tymczasowe dla adminów/operatorów
- Wymaga zmiany hasła przy pierwszym logowaniu

### 2. Weryfikacja

```bash
# Lista wszystkich użytkowników
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool user list

# Szczegóły użytkownika
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool user show lukasz.kolodziej

# LDAP query test
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  ldapsearch -x -H ldap://localhost \
  -b "DC=network-ad,DC=zsel,DC=opole,DC=pl" \
  "(objectClass=user)" sAMAccountName
```

### 3. Test logowania MikroTik

```bash
# Z Windows (WinBox):
# 1. Otwórz WinBox → Connect to: 192.168.255.2 (CS-GW-CPD-01)
# 2. Username: lukasz.kolodziej
# 3. Password: [hasło z output apply.sh]
# 4. Zostaniesz poproszony o zmianę hasła

# Z Linux/Mac (SSH):
ssh lukasz.kolodziej@192.168.255.2
# Password: [wprowadź hasło tymczasowe]
# New password: [ustaw nowe hasło]
```

---

## 📋 Troubleshooting

### Problem: User nie może się zalogować do MikroTik

```bash
# 1. Sprawdź czy user istnieje w AD
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool user show lukasz.kolodziej

# 2. Sprawdź czy RADIUS działa
kubectl logs -n core-auth deployment/freeradius-network -f

# 3. Sprawdź logi MikroTik
# WinBox → Log → Filter: "radius"

# 4. Test LDAP bind
kubectl exec -it -n core-auth freeradius-network-xxxx -- \
  ldapsearch -x -H ldap://192.168.255.51 \
  -D "CN=radius-bind,OU=ServiceAccounts,DC=network-ad,DC=zsel,DC=opole,DC=pl" \
  -W -b "OU=ITAdmins,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl"
```

### Problem: Hasło wygasło

```bash
# Reset hasła + wymuś zmianę
kubectl exec -it -n core-auth network-ad-dc-0 -- bash
samba-tool user setpassword lukasz.kolodziej --newpassword="TempPassword123!" --must-change-at-next-login
```

### Problem: User zablokowany (lockout)

```bash
# Odblokuj konto
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool user unlock lukasz.kolodziej
```

---

## 🔄 Operacje Konserwacyjne

### Dodanie nowego IT Admina

1. Edytuj `admins.ldif`:
```ldif
dn: CN=nowy.admin,OU=ITAdmins,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl
objectClass: user
cn: nowy.admin
sAMAccountName: nowy.admin
givenName: Nowy
sn: Admin
displayName: Nowy Admin
mail: nowy.admin@zsel.opole.pl
userPrincipalName: nowy.admin@network-ad.zsel.opole.pl
description: IT Administrator
memberOf: CN=Domain Admins,CN=Users,DC=network-ad,DC=zsel,DC=opole,DC=pl
```

2. Commit + Import:
```bash
git add admins.ldif
git commit -m "feat(network-ad): dodaj IT admina Nowy Admin"
git push
./apply.sh
```

### Usunięcie użytkownika

```bash
kubectl exec -it -n core-auth network-ad-dc-0 -- \
  samba-tool user delete stary.admin

# Usuń z LDIF + commit
vim admins.ldif  # usuń wpis
git add admins.ldif
git commit -m "chore(network-ad): usuń stary.admin (zwolnienie)"
git push
```

---

## 📞 Kontakt

**IT Infrastructure Team:**
- Email: it@zsel.opole.pl
- Helpdesk: https://zammad.zsel.local (VPN required)
- Cloud Architect: Łukasz Kołodziej - l.kolodziej@zsel.opole.pl

---

**Status:** Production Ready ✅  
**Ostatnia aktualizacja:** 2025-11-22
