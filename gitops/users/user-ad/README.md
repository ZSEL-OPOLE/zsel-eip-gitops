# User AD - Użytkownicy Szkolni (ad.zsel.opole.pl)

> **Domena:** ad.zsel.opole.pl  
> **Namespace:** identity-system  
> **IP:** 192.168.255.54 (PRIMARY), 192.168.255.55 (SECONDARY)  
> **Cel:** Autentykacja użytkowników szkolnych (nauczyciele, uczniowie, kadra)

---

## 👥 Użytkownicy User AD (944 osoby)

### 📚 Nauczyciele (74 osoby)
**OU:** `OU=Teachers,OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl`

**Uprawnienia:**
- ✅ Dostęp do Moodle jako moderatorzy kursów
- ✅ Dostęp do BigBlueButton jako moderatorzy
- ✅ Dostęp do WiFi "ZSEL-Staff" (WPA3-Enterprise)
- ✅ NextCloud (200 GB space per user)
- ✅ GitLab (projekty edukacyjne)
- ✅ Mattermost (komunikacja z uczniami)

**Grupy AD:**
- `Teachers` (podstawowa grupa)
- `Moodle-Admins` (tworzenie kursów)
- `BBB-Moderators` (prowadzenie lekcji online)
- `WiFi-Staff-Access` (RADIUS auth)

**Hasło:**
- Format: Losowe 16-znaków (A-Za-z0-9!@#$%^&*)
- Policy: Must change at next login = YES
- Expiration: 180 dni

---

### 🎓 Uczniowie (840 osób, 28 oddziałów technicznych)
**OU:** `OU=Students,OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl`

**Struktura oddziałów (28 klas technicznych):**
```
OU=Students
├── ROK 1 (6 oddziałów, 180 uczniów)
│   ├── OU=Class-1AT (technik mechatronik, 30 uczniów)
│   ├── OU=Class-1BT (technik elektryk/automatyk, 30 uczniów)
│   ├── OU=Class-1CT (technik programista/teleinformatyk, 30 uczniów)
│   ├── OU=Class-1DT (technik informatyk, 30 uczniów)
│   ├── OU=Class-1AB (elektryk, 30 uczniów)
│   └── OU=Class-1AW (technik elektryk, 30 uczniów)
│
├── ROK 2 (3 oddziały, 90 uczniów)
│   ├── OU=Class-2AT (technik automatyk/mechatronik, 30 uczniów)
│   ├── OU=Class-2BT (technik elektryk/teleinformatyk, 30 uczniów)
│   ├── OU=Class-2CT (technik programista/informatyk, 30 uczniów)
│   └── OU=Class-2AB (elektryk, 30 uczniów)
│
├── ROK 3 (7 oddziałów, 210 uczniów)
│   ├── OU=Class-3AT (technik mechatronik, 30 uczniów)
│   ├── OU=Class-3BT (technik elektryk, 30 uczniów)
│   ├── OU=Class-3CT (technik teleinformatyk/programista, 30 uczniów)
│   ├── OU=Class-3DT (technik informatyk, 30 uczniów)
│   ├── OU=Class-3ET (technik informatyk, 30 uczniów)
│   ├── OU=Class-3FT (technik automatyk 311909, 30 uczniów)
│   └── OU=Class-3AB (elektryk, 30 uczniów)
│   └── OU=Class-3BB (elektryk, 30 uczniów)
│
├── ROK 4 (6 oddziałów, 180 uczniów)
│   ├── OU=Class-4AT (technik mechatronik, 30 uczniów)
│   ├── OU=Class-4BT (technik elektryk, 30 uczniów)
│   ├── OU=Class-4CT (technik teleinformatyk, 30 uczniów)
│   ├── OU=Class-4DT (technik informatyk, 30 uczniów)
│   ├── OU=Class-4ET (technik informatyk, 30 uczniów)
│   └── OU=Class-4FT (technik automatyk 311909, 30 uczniów)
│
└── ROK 5 (5 oddziałów, 150 uczniów)
    ├── OU=Class-5AT (technik mechatronik, 30 uczniów)
    ├── OU=Class-5BT (technik automatyk 311909, 30 uczniów)
    ├── OU=Class-5CT (technik elektryk/teleinformatyk, 30 uczniów)
    ├── OU=Class-5DT (technik informatyk, 30 uczniów)
    └── OU=Class-5ET (technik informatyk, 30 uczniów)
```

**Kierunki zawodowe:**
- 🔧 **Technik mechatronik** - oddziały: 1AT, 2AT, 3AT, 4AT, 5AT
- ⚡ **Technik elektryk** - oddziały: 1BT, 1AW, 3BT, 4BT, 5CT (mix z teleinformatyką)
- 🤖 **Technik automatyk** - oddziały: 1BT (mix), 2AT (mix), 3FT, 4FT, 5BT
- 💻 **Technik informatyk** - oddziały: 1DT, 2CT, 3DT, 3ET, 4DT, 4ET, 5DT, 5ET
- 🌐 **Technik teleinformatyk** - oddziały: 1CT, 2BT, 3CT, 4CT, 5CT
- 👨‍💻 **Technik programista** - oddziały: 1CT (mix), 2CT (mix), 3CT (mix)
- 🔌 **Elektryk** (zawodówka 3-letnia) - oddziały: 1AB, 2AB, 3AB, 3BB
```

**Uprawnienia:**
- ✅ Dostęp do Moodle jako uczniowie (kursy przypisane przez nauczycieli)
- ✅ Dostęp do BigBlueButton (uczestnicy lekcji)
- ✅ Dostęp do WiFi "ZSEL-Student" (WPA3-Enterprise)
- ✅ NextCloud (50 GB space per user)
- ⛔ BRAK dostępu do GitLab, Portainer, Grafana, Zabbix

**Grupy AD:**
- `Students` (podstawowa grupa)
- `Class-1AT`, `Class-1BT`, ... `Class-5ET` (grupy per oddział dla przypisywania kursów w Moodle)
- `Specialization-Mechatronik`, `Specialization-Elektryk`, `Specialization-Informatyk`, `Specialization-Teleinformatyk`, `Specialization-Programista`, `Specialization-Automatyk` (grupy per kierunek dla materiałów branżowych)
- `WiFi-Student-Access` (RADIUS auth)

**Hasła:**
- Format: `{OddziałNazwa}{Rok}` (np. `1AT2025`, `2BT2025`, `3DT2025`)
- Policy: Must change = NO (proste hasła dla uczniów)
- Expiration: 30 czerwca każdego roku (koniec roku szkolnego)

---

### 👔 Kadra Administracyjna (30 osób)
**OU:** `OU=Staff,OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl`

**Role:**
- Dyrekcja (5 osób) - pełny dostęp do Moodle, BBB, NextCloud, Mattermost
- Księgowość (5 osób) - dostęp do NextCloud (faktury, dokumenty finansowe)
- Kadry (3 osoby) - dostęp do NextCloud (dokumenty pracownicze)
- Sekretariat (5 osób) - dostęp do Moodle (ogłoszenia), NextCloud
- Biblioteka (3 osoby) - dostęp do NextCloud (katalog książek)
- Pielęgniarka (2 osoby) - dostęp do NextCloud (dokumenty medyczne uczniów)
- Woźni/Konserwacja (7 osób) - BRAK dostępu do systemów IT (tylko WiFi podstawowy)

**Hasło:**
- Format: Losowe 12-znaków (A-Za-z0-9!@#$%)
- Policy: Must change at next login = YES
- Expiration: 365 dni

---

### 🤖 Service Accounts (10 kont)
**OU:** `OU=ServiceAccounts,DC=ad,DC=zsel,DC=opole,DC=pl`

| Username | Cel | Używane Przez | Hasło |
|----------|-----|---------------|-------|
| moodle-ldap-bind | LDAP bind dla Moodle | Moodle (namespace: edu-platform) | 32-char (Sealed Secret) |
| bbb-auth | BigBlueButton LDAP auth | BigBlueButton (namespace: edu-platform) | 32-char (Sealed Secret) |
| wifi-radius-bind | RADIUS dla WiFi uczniów | FreeRADIUS User WiFi (192.168.255.56) | 32-char (Sealed Secret) |
| nextcloud-ldap | NextCloud LDAP sync | NextCloud (namespace: files-collaboration) | 32-char (Sealed Secret) |
| gitlab-ldap | GitLab LDAP auth | GitLab (namespace: devops-tools) | 32-char (Sealed Secret) |
| mattermost-ldap | Mattermost LDAP auth | Mattermost (namespace: communication) | 32-char (Sealed Secret) |
| zammad-ldap | Zammad (helpdesk) LDAP | Zammad (namespace: communication) | 32-char (Sealed Secret) |
| mailu-ldap | Mailu (email) LDAP | Mailu (namespace: communication) | 32-char (Sealed Secret) |
| portainer-ldap | Portainer LDAP auth | Portainer (namespace: mgmt-orchestration) | 32-char (Sealed Secret) |
| grafana-ldap | Grafana LDAP auth | Grafana (namespace: mon-observability) | 32-char (Sealed Secret) |

---

## 🔐 PROSTY SYSTEM NADZOROWANIA

### 🎯 **DLA NAUCZYCIELI - Panel Samoobsługi**

#### 1. **Grafana Dashboard - "Teacher Overview"**
```
https://grafana.zsel.opole.pl/d/teacher-overview

Sekcje:
- 📊 Moi Uczniowie (lista uczniów w moich klasach)
- 📚 Aktywność w Moodle (liczba zalogowań ostatnie 7 dni)
- 🎥 Statystyki BBB (uczestnictwo w lekcjach online)
- 📁 Użycie NextCloud (top 10 uczniów wg użycia dysku)
- ⚠️ Alerty (uczniowie bez logowania >7 dni)
- 🔐 Reset Haseł (przycisk do resetu hasła ucznia)
```

**Filtrowanie:**
- Nauczyciel widzi TYLKO swoje klasy (filtr LDAP: `memberOf=Class-2A`)
- Wybór klasy z dropdown: `Class-2A`, `Class-2B`, etc.
- Wybór okresu: Ostatnie 7 dni / 30 dni / cały rok szkolny

**Przykładowa karta ucznia w dashboardzie:**
```
┌─────────────────────────────────────────────────┐
│ 🧑 Adam Kowalski (adam.kowalski)               │
│ 📚 Klasa: 2B                                   │
│ ────────────────────────────────────────────   │
│ 🟢 Moodle: 15 logowań (ostatnie 7 dni)        │
│ 🟢 BBB: 5 uczestnictw (ostatnie 7 dni)        │
│ 🟠 NextCloud: 45.2 GB / 50 GB (90%)           │
│ 🔴 WiFi: Brak logowania od 10 dni ⚠️          │
│ ────────────────────────────────────────────   │
│ [🔄 Reset Hasła] [📧 Wyślij Email]            │
└─────────────────────────────────────────────────┘
```

---

#### 2. **Moodle - Lista Uczniów w Kursie**
```
https://moodle.zsel.opole.pl/course/view.php?id=123

Sekcja: "Uczestnicy" → Widok nauczyciela:
- 🎯 Ostatnie logowanie ucznia
- 📊 Postęp w kursie (%)
- ✅ Zadania oddane / niepoddane
- 📧 Przycisk "Wyślij Email" (przypomnienie)
```

**Automatyczne Alerty Email do Nauczyciela:**
- Uczeń nie zalogował się >7 dni → Email do wychowawcy
- Uczeń nie oddał zadania w terminie → Email do nauczyciela przedmiotu
- Uczeń użył >90% przestrzeni NextCloud → Email do wychowawcy

---

#### 3. **NextCloud - Folder Klasy**
```
https://nextcloud.zsel.opole.pl/files/Class-2B/

Struktura:
├── Materialy-Dydaktyczne/ (tylko odczyt dla uczniów)
│   ├── Matematyka/
│   ├── Język-Polski/
│   └── Historia/
├── Prace-Uczniow/ (upload dla uczniów, każdy widzi tylko swoje)
│   ├── adam.kowalski/
│   ├── maria.nowak/
│   └── ...
└── Ogłoszenia/ (tylko odczyt dla uczniów)
```

**Uprawnienia:**
- Wychowawca klasy → Owner (pełny dostęp)
- Nauczyciele przedmiotów → Can Edit (mogą dodawać materiały)
- Uczniowie → Can Read (odczyt) + Upload do swojego folderu

---

### 🎓 **DLA UCZNIÓW - Prosty Portal**

#### 1. **Strona Główna (Landing Page)**
```
https://portal.zsel.opole.pl (po zalogowaniu via SSO)

Kafelki:
┌─────────┬─────────┬─────────┐
│ 📚      │ 🎥      │ 📁      │
│ Moodle  │   BBB   │NextCloud│
│ Kursy   │ Lekcje  │ Pliki   │
└─────────┴─────────┴─────────┘

┌─────────┬─────────┬─────────┐
│ 💬      │ 📧      │ 🆘      │
│Mattermost│  Email │ Pomoc  │
│  Chat   │ Skrzynka│Helpdesk │
└─────────┴─────────┴─────────┘

Pasek u góry:
🟢 Zalogowany jako: Adam Kowalski (Klasa 2B)
📊 NextCloud: 45.2 GB / 50 GB
🔐 Hasło: 2B2025 (nie zmieniaj!)
```

---

#### 2. **Grafana Dashboard - "Student Self-Service"**
```
https://grafana.zsel.opole.pl/d/student-overview

Sekcje (TYLKO dla ucznia - widzi tylko swoje dane):
- 📊 Moja Aktywność (wykres logowań ostatnie 30 dni)
- 📚 Moje Kursy Moodle (lista + postęp)
- 📁 Moje Pliki NextCloud (użycie dysku + top 10 plików wg rozmiaru)
- 🎥 Historia BBB (uczestnictwo w lekcjach)
- ⚠️ Moje Alerty (np. "Brak zadania z Matematyki!")
```

**Przykład sekcji "Moja Aktywność":**
```
📊 Statystyki Aktywności (ostatnie 30 dni)
────────────────────────────────────────
🟢 Moodle: 42 logowania (średnia: 1.4/dzień)
🟢 BBB: 18 uczestnictw (średnia: 3.6/tydzień)
🟠 NextCloud: 45.2 GB / 50 GB (⚠️ 90% wykorzystane!)
🟢 WiFi: Ostatnie logowanie: 2025-11-22 08:15:32

📈 Trend: ⬆️ +15% aktywności vs poprzedni miesiąc
```

---

### 🛠️ **Narzędzia dla Administratora (IT)**

#### 1. **Zabbix - Monitoring Kont AD**
```
https://zabbix.zsel.opole.pl

Trigger Alerts:
⚠️ CRITICAL: User account locked (5+ failed login attempts)
⚠️ WARNING: Student password expired (>365 days old - SHOULDN'T HAPPEN!)
⚠️ INFO: New user created in AD (audit log)
⚠️ HIGH: Service account password not rotated (>90 days)
```

**Auto-remediation:**
- Locked account → Automatyczne odblokowanie po 30 min + Email do admina
- Expired password (nauczyciel) → Email z linkiem do resetu

---

#### 2. **Graylog - Audit Logs**
```
https://graylog.zsel.opole.pl

Predefiniowane Queries:
- "Failed logins last 24h" → Lista użytkowników z nieudanymi logowaniami
- "Password changes" → Kto zmienił hasło (audit trail)
- "Student account created" → Nowi uczniowie dodani do AD
- "Teacher access to admin panels" → Kto z nauczycieli zalogował się do Portainer/Grafana
```

---

#### 3. **Portainer - Quick Actions**
```
https://portainer.zsel.opole.pl

Custom Templates (przycisk "Deploy"):
┌────────────────────────────────────┐
│ 🔄 Reset Hasła Ucznia              │
│ Input: username, new_password      │
│ Wykonuje: kubectl exec user-ad →  │
│           samba-tool user setpwd   │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ 🔓 Odblokuj Konto                  │
│ Input: username                    │
│ Wykonuje: samba-tool user unlock   │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ 📊 Raport Aktywności Klasy         │
│ Input: class_name (np. 2B)         │
│ Output: CSV z logowaniami          │
└────────────────────────────────────┘
```

---

## 📋 **Workflow: Codzienne Operacje**

### Scenariusz 1: Nauczyciel chce zobaczyć aktywność swojego oddziału
```bash
1. Wejdź na: https://grafana.zsel.opole.pl/d/teacher-overview
2. Zaloguj się (SSO via user-ad.zsel.opole.pl - np. d.dobrowolski)
3. Wybierz oddział z dropdown: "Class-2AT" (technik automatyk/mechatronik)
4. Wybierz okres: "Ostatnie 7 dni"
5. Zobaczysz listę uczniów + ich aktywność:
   - 🟢 25 uczniów: aktywni (logowanie <7 dni temu)
   - 🟠 3 uczniów: nieaktywni (7-14 dni)
   - 🔴 2 uczniów: brak logowania >14 dni ⚠️
6. Kliknij "Reset Hasła" przy uczniu → Nowe hasło: 2AT2025
7. Wyślij email do ucznia: "Twoje hasło zostało zresetowane na: 2AT2025"
```

---

### Scenariusz 2: Uczeń zapomniał hasła
```bash
OPCJA A: Nauczyciel resetuje hasło przez Grafanę
1. Nauczyciel → Grafana → Teacher Overview
2. Znajdź ucznia na liście
3. Kliknij [🔄 Reset Hasła]
4. Nowe hasło: {KlasaNazwa}{Rok} (np. 2B2025)
5. Nauczyciel mówi uczniowi hasło ustnie (bezpieczeństwo!)

OPCJA B: IT Admin resetuje przez Portainer
1. Portainer → Templates → "Reset Hasła Ucznia"
2. Input: adam.kowalski
3. Output: "Password reset to 2B2025"
4. IT kontaktuje się z wychowawcą klasy

OPCJA C: Automatyczny reset (Self-Service)
1. Uczeń wchodzi na: https://password-reset.zsel.opole.pl
2. Wprowadza swój email: adam.kowalski@student.zsel.opole.pl
3. Weryfikacja: Wpisz swój PESEL (ostatnie 4 cyfry)
4. Nowe hasło wysłane na email rodzica (zapisany w AD)
```

---

### Scenariusz 3: Nowy rok szkolny (rotacja klas)
```bash
# 1 września każdego roku:
cd gitops/users/user-ad/students/

# 1. Usuń absolwentów (klasy 4*)
rm class-4a.ldif class-4b.ldif class-4c.ldif class-4d.ldif class-4e.ldif class-4f.ldif

# 2. Przenieś klasy o 1 w górę (MANUAL!)
# Przykład: class-1a.ldif → zmień wszystkie "Class-1A" na "Class-2A"
sed -i 's/Class-1A/Class-2A/g' class-1a.ldif
sed -i 's/Class-1B/Class-2B/g' class-1b.ldif
# ... powtórz dla wszystkich klas

# 3. Wygeneruj nowe klasy 1* (nowi uczniowie z CSV)
python ../../scripts/generate-student-ldif.py \
  --csv nowi-uczniowie-2026.csv \
  --output-dir . \
  --classes 1A,1B,1C,1D,1E,1F,1G,1H

# 4. Commit + Deploy
git add .
git commit -m "feat(users): rotacja roczna 2026 - nowe klasy 1A-1H"
git push
../../user-ad/apply.sh

# 5. Zmień hasła na nowe (1A2026, 1B2026, ...)
kubectl exec -n identity-system user-ad-dc-0 -- bash -c '
  for CLASS in 1A 1B 1C 1D 1E 1F 1G 1H; do
    NEW_PASSWORD="${CLASS}2026"
    ldapsearch -x -H ldap://localhost \
      -b "OU=Class-${CLASS},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl" \
      "(objectClass=user)" sAMAccountName | \
    grep "sAMAccountName:" | awk "{print \$2}" | while read USER; do
      samba-tool user setpassword "$USER" --newpassword="$NEW_PASSWORD"
      echo "✅ $USER → hasło: $NEW_PASSWORD"
    done
  done
'

# 6. Wydrukuj hasła dla wychowawców (PDF)
kubectl exec -n identity-system user-ad-dc-0 -- bash -c '
  for CLASS in 1A 1B 1C 1D 1E 1F 1G 1H; do
    echo "========================================" > /tmp/passwords-${CLASS}.txt
    echo "HASŁA KLASY ${CLASS} - ROK 2026/2027" >> /tmp/passwords-${CLASS}.txt
    echo "========================================" >> /tmp/passwords-${CLASS}.txt
    echo "" >> /tmp/passwords-${CLASS}.txt
    echo "Wspólne hasło dla całej klasy: ${CLASS}2026" >> /tmp/passwords-${CLASS}.txt
    echo "" >> /tmp/passwords-${CLASS}.txt
    echo "INSTRUKCJA DLA UCZNIA:" >> /tmp/passwords-${CLASS}.txt
    echo "1. Połącz się z WiFi: ZSEL-Student" >> /tmp/passwords-${CLASS}.txt
    echo "2. Username: twoje.imie.nazwisko" >> /tmp/passwords-${CLASS}.txt
    echo "3. Password: ${CLASS}2026" >> /tmp/passwords-${CLASS}.txt
    echo "" >> /tmp/passwords-${CLASS}.txt
    echo "Wejdź na: https://portal.zsel.opole.pl" >> /tmp/passwords-${CLASS}.txt
    echo "" >> /tmp/passwords-${CLASS}.txt
  done
'
kubectl cp identity-system/user-ad-dc-0:/tmp/passwords-1A.txt ./passwords-1A.txt
# Przekonwertuj na PDF + wydrukuj dla wychowawców
```

---

## 🔒 **Bezpieczeństwo**

### Separation of Duties (podział obowiązków)
```
┌─────────────────────────────────────────────────────┐
│ ROLA             │ DOSTĘP DO                        │
├──────────────────┼──────────────────────────────────┤
│ IT Administrator │ - Pełny dostęp do wszystkiego    │
│ (Łukasz)         │ - Reset haseł nauczycieli/kadry  │
│                  │ - Tworzenie/usuwanie kont        │
├──────────────────┼──────────────────────────────────┤
│ Wychowawca Klasy │ - Reset haseł swoich uczniów     │
│ (Nauczyciel)     │ - Widok aktywności swoich uczniów│
│                  │ - BRAK dostępu do innych klas    │
├──────────────────┼──────────────────────────────────┤
│ Nauczyciel       │ - Widok uczniów w swoich kursach │
│ (Przedmiot)      │ - BRAK możliwości resetu haseł   │
│                  │ - Tylko statystyki Moodle/BBB    │
├──────────────────┼──────────────────────────────────┤
│ Uczeń            │ - Widok tylko swoich danych      │
│                  │ - Self-service password reset    │
│                  │ - BRAK dostępu do innych uczniów │
├──────────────────┼──────────────────────────────────┤
│ Kadra Admin      │ - Dostęp tylko do NextCloud      │
│                  │ - BRAK dostępu do Moodle/BBB     │
└──────────────────┴──────────────────────────────────┘
```

### Audit Trail (ślad audytowy)
```
Każda operacja jest logowana:
- Reset hasła → Graylog: "User lukasz.kolodziej reset password for adam.kowalski"
- Odblokowanie konta → Graylog: "Account adam.kowalski unlocked by operator02"
- Nowy użytkownik → Graylog: "New student adam.kowalski created in Class-2B"
- Zmiana grupy → Graylog: "User maria.nowak added to group Moodle-Admins"

Retencja logów: 365 dni (wymóg RODO)
```

---

## 📞 **Kontakt**

**IT Support:**
- Email: it@zsel.opole.pl
- Helpdesk: https://zammad.zsel.local (VPN required)
- Telefon: +48 77 xxx xx xx (pon-pt 8:00-16:00)

**Cloud Architect:**
- Łukasz Kołodziej - l.kolodziej@zsel.opole.pl

---

**Status:** Production Ready ✅  
**Ostatnia aktualizacja:** 2025-11-22
