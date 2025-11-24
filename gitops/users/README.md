# User Management - LDIF Files for Active Directory

> **Cel:** Zarządzanie użytkownikami jako kod (Infrastructure as Code) dla łatwego odtwarzania i disaster recovery

## 📁 Struktura Katalogów

```
users/
├── README.md                           # Ten plik
├── network-ad/                         # Network AD (network-ad.zsel.opole.pl)
│   ├── README.md                       # Instrukcje Network AD
│   ├── admins.ldif                     # 10 IT Administrators
│   ├── operators.ldif                  # 5 Network Operators
│   ├── service-accounts.ldif           # radius-bind, monitoring, backup
│   └── apply.sh                        # Skrypt importu do Samba AD
├── user-ad/                            # User AD (ad.zsel.opole.pl)
│   ├── README.md                       # Instrukcje User AD
│   ├── teachers.ldif                   # 74 nauczycieli (prawdziwe dane)
│   ├── staff.ldif                      # 30 kadra administracyjna
│   ├── service-accounts.ldif           # moodle-bind, bbb-bind, etc.
│   ├── students/                       # Uczniowie (28 oddziałów technicznych)
│   │   ├── class-1at.ldif              # 1AT technik mechatronik (30 uczniów)
│   │   ├── class-1bt.ldif              # 1BT technik elektryk/automatyk (30 uczniów)
│   │   ├── class-1ct.ldif              # 1CT technik programista/teleinformatyk (30 uczniów)
│   │   ├── class-1dt.ldif              # 1DT technik informatyk (30 uczniów)
│   │   ├── ...                         # (28 oddziałów total)
│   │   └── class-5et.ldif              # 5ET technik informatyk (30 uczniów)
│   └── apply.sh                        # Skrypt importu
├── scripts/                            # Narzędzia automatyzacji
│   ├── generate-student-ldif.py        # Generator LDIF z CSV
│   ├── generate-passwords.sh           # Generator haseł
│   ├── bulk-password-reset.sh          # Masowa zmiana haseł
│   └── sync-from-csv.py                # Sync użytkowników z arkusza
└── templates/                          # Szablony LDIF
    ├── user-template.ldif              # Szablon użytkownika
    ├── class-template.ldif             # Szablon klasy
    └── service-account-template.ldif   # Szablon konta serwisowego
```

---

## 📊 Statystyki Użytkowników

| Kategoria | Ilość | Domena | Lokalizacja |
|-----------|-------|--------|-------------|
| **IT Administrator** | 1 | network-ad.zsel.opole.pl | `network-ad/admins.ldif` |
| **Network Operators** | 4 | network-ad.zsel.opole.pl | `network-ad/operators.ldif` |
| **Service Accounts (Network)** | 5 | network-ad.zsel.opole.pl | `network-ad/service-accounts.ldif` |
| **Nauczyciele** | 74 | ad.zsel.opole.pl | `user-ad/teachers.ldif` |
| **Uczniowie** | 840 | ad.zsel.opole.pl | `user-ad/students/class-*.ldif` (28 plików) |
| **Kadra Administracyjna** | 30 | ad.zsel.opole.pl | `user-ad/staff.ldif` |
| **Service Accounts (User AD)** | 10 | ad.zsel.opole.pl | `user-ad/service-accounts.ldif` |
| **TOTAL** | **964** | - | **35 plików LDIF** |

---

## 🔐 Strategia Haseł

### Network AD (Administratorzy)
- **Format:** Losowe 16-znaków (A-Za-z0-9!@#$%^&*)
- **Policy:** Must change at next login = YES
- **Expiration:** 90 dni
- **Complexity:** Wymagane (min. 3 z 4 kategorii znaków)

### User AD (Nauczyciele)
- **Format:** Losowe 16-znaków
- **Policy:** Must change at next login = YES
- **Expiration:** 180 dni
- **Complexity:** Wymagane

### User AD (Uczniowie)
- **Format:** `{KlasaNazwa}{Rok}` (np. `1A2025`, `2B2025`)
- **Policy:** Must change = NO (łatwe do zapamiętania)
- **Expiration:** Koniec roku szkolnego (30 czerwca)
- **Complexity:** NIE wymagane (prosty format)

### User AD (Kadra)
- **Format:** Losowe 12-znaków
- **Policy:** Must change at next login = YES
- **Expiration:** 365 dni

### Service Accounts
- **Format:** Losowe 32-znaków (zapisane w Sealed Secrets)
- **Policy:** Never expires, password never changes
- **Storage:** Kubernetes Sealed Secrets + 1Password/Bitwarden

---

## 🚀 Workflow: Dodanie Nowego Użytkownika

### Scenariusz 1: Nowy Uczeń (Adam Kowalski, oddział 2AT technik automatyk)

```bash
# 1. Edytuj plik LDIF oddziału
cd gitops/users/user-ad/students/
vim class-2at.ldif

# Dodaj wpis:
dn: CN=adam.kowalski,OU=Class-2AT,OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl
objectClass: user
cn: adam.kowalski
sAMAccountName: adam.kowalski
givenName: Adam
sn: Kowalski
displayName: Adam Kowalski
mail: adam.kowalski@student.zsel.opole.pl
userPrincipalName: adam.kowalski@ad.zsel.opole.pl
description: Technik automatyk/mechatronik
homeDirectory: \\nextcloud.zsel.opole.pl\home\adam.kowalski
homeDrive: H:
scriptPath: logon-student.bat

# 2. Commit do Git
git add class-2at.ldif
git commit -m "feat(users): dodaj ucznia Adam Kowalski (oddział 2AT)"
git push origin main

# 3. Uruchom import
cd ../../
./user-ad/apply.sh

# 4. Weryfikacja
kubectl exec -it -n identity-system user-ad-dc-0 -- \
  samba-tool user show adam.kowalski

# 5. Test logowania
# WiFi: SSID "ZSEL-Student", username: adam.kowalski, hasło: 2AT2025
# Moodle: https://moodle.zsel.opole.pl (te same credentials)
```

---

### Scenariusz 2: Nowy Nauczyciel (Anna Nowak, matematyka)

```bash
# 1. Edytuj plik teachers.ldif
cd gitops/users/user-ad/
vim teachers.ldif

# Dodaj wpis przed końcem pliku:
dn: CN=anna.nowak,OU=Teachers,OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl
objectClass: user
cn: anna.nowak
sAMAccountName: anna.nowak
givenName: Anna
sn: Nowak
displayName: Anna Nowak
mail: a.nowak@zsel.opole.pl
userPrincipalName: anna.nowak@ad.zsel.opole.pl
description: Nauczyciel Matematyki
homeDirectory: \\nextcloud.zsel.opole.pl\home\anna.nowak
homeDrive: H:
memberOf: CN=Teachers,OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl
memberOf: CN=Moodle-Admins,OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl

# 2. Commit
git add teachers.ldif
git commit -m "feat(users): dodaj nauczyciela Anna Nowak (matematyka)"
git push

# 3. Import
./apply.sh

# 4. Hasło tymczasowe zostanie wygenerowane automatycznie
# Wyświetli się w logach: "Teacher anna.nowak temp password: Xy9#mK2pQr4$vL8z"
```

---

### Scenariusz 3: Nowy IT Admin (Piotr Zieliński)

```bash
# 1. Edytuj admins.ldif
cd gitops/users/network-ad/
vim admins.ldif

# Dodaj wpis:
dn: CN=piotr.zielinski,OU=ITAdmins,OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl
objectClass: user
cn: piotr.zielinski
sAMAccountName: piotr.zielinski
givenName: Piotr
sn: Zieliński
displayName: Piotr Zieliński
mail: p.zielinski@zsel.opole.pl
userPrincipalName: piotr.zielinski@network-ad.zsel.opole.pl
description: Network Engineer - MikroTik specialist
memberOf: CN=Domain Admins,CN=Users,DC=network-ad,DC=zsel,DC=opole,DC=pl

# 2. Commit + Import
git add admins.ldif
git commit -m "feat(users): dodaj IT admina Piotr Zieliński"
git push
./apply.sh

# 3. Piotr może teraz logować się do:
# - WinBox (MikroTik) via RADIUS
# - Portainer: https://portainer.zsel.opole.pl
# - Grafana: https://grafana.zsel.opole.pl
# - Zabbix: https://zabbix.zsel.opole.pl
```

---

## 🔄 Workflow: Rotacja Roczna Uczniów

**Każdy rok szkolny (1 września):**

```bash
cd gitops/users/user-ad/students/

# 1. Usuń absolwentów (klasy 4*)
git rm class-4*.ldif
git commit -m "chore(users): usuń absolwentów 2025"

# 2. Przenieś klasy o 1 w górę (MANUAL EDIT!)
# class-1a.ldif → class-2a.ldif
# class-2a.ldif → class-3a.ldif
# class-3a.ldif → class-4a.ldif

# 3. Wygeneruj nowe oddziały 1* (nowi uczniowie)
python ../../scripts/generate-student-ldif.py \
  --csv nowi-uczniowie-2026.csv \
  --output-dir . \
  --classes 1AT,1BT,1CT,1DT,1AB,1AW

# 4. Commit + Deploy
git add .
git commit -m "feat(users): rotacja roczna 2026 - nowe oddziały pierwszego roku"
git push

# 5. Import do AD
../../user-ad/apply.sh

# 6. Zmień hasła na nowe (1AT2026, 1BT2026, ...)
kubectl exec -it -n identity-system user-ad-dc-0 -- bash <<'EOF'
  for CLASS in 1AT 1BT 1CT 1DT 1AB 1AW; do
    NEW_PASSWORD="${CLASS}2026"
    ldapsearch -x -H ldap://localhost \
      -b "OU=Class-${CLASS},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl" \
      "(objectClass=user)" sAMAccountName | \
    grep "sAMAccountName:" | awk '{print $2}' | while read USER; do
      samba-tool user setpassword "$USER" --newpassword="$NEW_PASSWORD"
      echo "✅ $USER → hasło: $NEW_PASSWORD"
    done
  done
EOF
```

---

## 🛠️ Narzędzia Pomocnicze

### 1. Generator LDIF z CSV

**Plik: `scripts/generate-student-ldif.py`**

```bash
# Przykładowy CSV (nowi-uczniowie-2026.csv):
# imie,nazwisko,klasa,email
# Adam,Nowak,1A,adam.nowak@student.zsel.opole.pl
# Maria,Kowalska,1A,maria.kowalska@student.zsel.opole.pl

python scripts/generate-student-ldif.py \
  --csv nowi-uczniowie-2026.csv \
  --output-dir user-ad/students/
```

### 2. Bulk Password Reset

```bash
# Reset haseł dla całej klasy
scripts/bulk-password-reset.sh --class 2B --new-password 2B2025

# Reset haseł dla wszystkich nauczycieli
scripts/bulk-password-reset.sh --group Teachers --random
```

### 3. Sync z Google Sheets / Office 365

```bash
# Automatyczny import z arkusza kalkulacyjnego (Excel/Google Sheets)
python scripts/sync-from-csv.py \
  --source "https://docs.google.com/spreadsheets/d/XXXXX/export?format=csv" \
  --target user-ad/students/ \
  --dry-run

# Bez --dry-run: automatyczny commit + push + apply
```

---

## 📋 Checklist Przed Deploymentem

### Network AD
- [ ] Zaktualizować `admins.ldif` (10 IT adminów)
- [ ] Zaktualizować `operators.ldif` (5 operatorów)
- [ ] Zaktualizować `service-accounts.ldif` (radius-bind, monitoring)
- [ ] Uruchomić `./network-ad/apply.sh`
- [ ] Zweryfikować import: `kubectl exec -n core-auth network-ad-dc-0 -- samba-tool user list`
- [ ] Przetestować logowanie do MikroTik via WinBox

### User AD
- [ ] Zaktualizować `teachers.ldif` (100 nauczycieli)
- [ ] Zaktualizować `staff.ldif` (30 kadra)
- [ ] Wygenerować 30 plików `students/class-*.ldif` (900 uczniów)
- [ ] Zaktualizować `service-accounts.ldif` (10 kont serwisowych)
- [ ] Uruchomić `./user-ad/apply.sh`
- [ ] Zweryfikować import: `kubectl exec -n identity-system user-ad-dc-0 -- samba-tool user list`
- [ ] Przetestować logowanie WiFi (student + nauczyciel)
- [ ] Przetestować logowanie Moodle (student + nauczyciel)

---

## 🔒 Bezpieczeństwo

### Hasła w Git
- ⚠️ **NIGDY NIE COMMITUJ HASEŁ DO GIT!**
- LDIF pliki zawierają tylko strukturę użytkowników (bez atrybutu `userPassword`)
- Hasła są ustawiane przez skrypty `apply.sh` AFTER import
- Hasła tymczasowe dla adminów/nauczycieli są wyświetlane w stdout (należy je skopiować do 1Password/Bitwarden)

### Service Accounts
- Hasła service accounts (radius-bind, moodle-bind, etc.) są generowane losowo (32 znaki)
- Zapisywane w **Kubernetes Sealed Secrets**
- NIE są nigdy commitowane do Git w plaintext

### Backup LDIF
- Automatyczny export LDIF codziennie o 02:00 AM
- Backupy przechowywane w MinIO bucket: `s3://zsel-backups/ldap/`
- Retencja: 90 dni

---

## 📞 Pomoc

**Dodanie użytkownika:**
```bash
# Krótka instrukcja
cat users/README.md | grep -A 20 "Workflow: Dodanie"
```

**Troubleshooting:**
```bash
# Sprawdź logi importu
kubectl logs -n core-auth network-ad-dc-0 --tail=100

# Sprawdź czy użytkownik istnieje
kubectl exec -it -n identity-system user-ad-dc-0 -- \
  samba-tool user show adam.kowalski
```

**Kontakt IT:**
- Email: it@zsel.opole.pl
- Helpdesk: https://zammad.zsel.local (VPN required)
- Telefon: +48 77 xxx xx xx

---

**Ostatnia aktualizacja:** 2025-11-22  
**Maintainer:** Łukasz Kołodziej (Cloud Architect)  
**Status:** Production Ready ✅
