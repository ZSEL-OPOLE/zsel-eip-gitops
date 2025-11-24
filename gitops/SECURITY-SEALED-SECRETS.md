# Security Policy - Sealed Secrets Management

**Last Updated:** 2024-11-22  
**Status:** 🔒 PRODUCTION SECURITY REQUIREMENTS

---

## 🎯 Zasady bezpieczeństwa sekretów

### Dwa niezależne źródła prawdy

#### 1. Network AD (`network-ad.zsel.opole.pl`)
- **Cel:** Urządzenia sieciowe TYLKO (MikroTik RADIUS)
- **Namespace:** `core-auth`
- **Użytkownicy:** ~10 IT adminów
- **Sekrety:**
  - `network-ad-admin-secret` - hasło administratora domeny
  - `radius-bind-secret` - hasło dla FreeRADIUS LDAP bind

#### 2. User AD (`ad.zsel.opole.pl`)
- **Cel:** SSO dla aplikacji (Moodle, BigBlueButton, Nextcloud, etc.)
- **Namespace:** `identity-system`
- **Użytkownicy:** ~1000 (nauczyciele + uczniowie)
- **Sekrety:**
  - `user-ad-admin-secret` - hasło administratora domeny
  - `sso-ldap-bind-secret` - hasło dla aplikacji SSO
  - `initial-user-passwords` - hasła startowe użytkowników (autogenerowane!)

---

## 🔐 Wymagania bezpieczeństwa

### ❌ ZABRONIONE w Git repository

```yaml
# NIGDY NIE COMMITOWAĆ TEGO DO GITA!
apiVersion: v1
kind: Secret
metadata:
  name: example-secret
stringData:
  password: "PlainTextPassword123!"  # ❌ NIEBEZPIECZNE!
```

### ✅ WYMAGANE - SealedSecret

```yaml
# TYLKO TO MOŻE BYĆ W GICIE!
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: example-secret
  namespace: identity-system
spec:
  encryptedData:
    password: AgBZXk7j... # ✅ Zaszyfrowane, bezpieczne
  template:
    metadata:
      name: example-secret
    type: Opaque
```

---

## 📋 Workflow tworzenia sekretów

### Krok 1: Wygeneruj silne hasło

```bash
# Minimum 32 znaki (litery + cyfry + znaki specjalne)
PASSWORD=$(openssl rand -base64 32)
echo "ZAPISZ TO HASŁO BEZPIECZNIE: $PASSWORD"

# Alternatywnie: pwgen
PASSWORD=$(pwgen -s 40 1)
```

### Krok 2: Utwórz tymczasowy Secret YAML

```bash
# Przykład: admin password dla User AD
kubectl create secret generic user-ad-admin-secret \
  --namespace=identity-system \
  --from-literal=admin-password="$PASSWORD" \
  --dry-run=client -o yaml > /tmp/secret.yaml

# NIGDY NIE ZAPISUJ /tmp/secret.yaml DO GITA!
```

### Krok 3: Zaszyfruj kubeseal

```bash
# Pobierz klucz publiczny (jednorazowo)
kubeseal --fetch-cert \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets-controller \
  > environments/production/sealed-secrets/pub-cert.pem

# Zaszyfruj secret
kubeseal --format=yaml \
  --cert=environments/production/sealed-secrets/pub-cert.pem \
  --scope=strict \
  < /tmp/secret.yaml \
  > apps/user-ad/overlays/production/sealed-secrets/user-ad-admin-secret.yaml
```

### Krok 4: USUŃ tymczasowe pliki

```bash
# KRYTYCZNE: Usuń plain secret!
rm /tmp/secret.yaml
unset PASSWORD

# Sprawdź historię bash (opcjonalnie wyczyść)
history -c  # wyczyść historię bieżącej sesji
```

### Krok 5: Commit SealedSecret do Git

```bash
git add apps/user-ad/overlays/production/sealed-secrets/
git commit -m "feat(user-ad): Add sealed admin password"
git push
```

---

## 🔄 Autogeneracja haseł użytkowników

### Problematyka

- 1000+ użytkowników (nauczyciele + uczniowie)
- Hasła startowe muszą być:
  - ✅ Unikalne per użytkownik
  - ✅ Silne (min. 12 znaków)
  - ✅ Zaszyfrowane w Git
  - ✅ Dostępne dla użytkownika (email/druk)

### Rozwiązanie: Kubernetes Job

```yaml
# apps/user-ad/base/job-generate-passwords.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: user-ad-generate-passwords
  namespace: identity-system
spec:
  template:
    spec:
      containers:
      - name: password-generator
        image: python:3.11-alpine
        command:
        - python3
        - /scripts/generate-passwords.py
        volumeMounts:
        - name: user-list
          mountPath: /data/users.csv
          subPath: users.csv
        - name: script
          mountPath: /scripts
        env:
        - name: AD_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: user-ad-admin-secret
              key: admin-password
      volumes:
      - name: user-list
        configMap:
          name: user-ad-initial-users
      - name: script
        configMap:
          name: user-ad-password-generator-script
      restartPolicy: OnFailure
```

### Skrypt generujący hasła

```python
# configmap: user-ad-password-generator-script
import csv
import secrets
import string
from ldap3 import Server, Connection, ALL

def generate_password(length=16):
    """Generuj silne hasło (litery + cyfry + znaki)"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*()"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def create_user_with_password(conn, username, first_name, last_name, email, group):
    """Utwórz użytkownika w AD z wygenerowanym hasłem"""
    password = generate_password(16)
    
    # Utwórz użytkownika w AD
    dn = f"CN={first_name} {last_name},OU={group},DC=ad,DC=zsel,DC=opole,DC=pl"
    conn.add(dn, ['user'], {
        'sAMAccountName': username,
        'userPrincipalName': f"{username}@ad.zsel.opole.pl",
        'givenName': first_name,
        'sn': last_name,
        'mail': email,
        'userAccountControl': 512  # Aktywne konto
    })
    
    # Ustaw hasło (wymusza zmianę przy pierwszym logowaniu)
    conn.modify(dn, {
        'unicodePwd': [(MODIFY_REPLACE, [f'"{password}"'.encode('utf-16-le')])]
    })
    conn.modify(dn, {
        'pwdLastSet': [(MODIFY_REPLACE, [0])]  # Wymusza zmianę hasła
    })
    
    # Zapisz do SealedSecret (do późniejszego dostarczenia użytkownikowi)
    return {
        'username': username,
        'email': email,
        'initial_password': password
    }

# Główna pętla
server = Server('ldap://user-ad-primary.identity-system.svc.cluster.local', get_info=ALL)
conn = Connection(server, user='CN=Administrator,CN=Users,DC=ad,DC=zsel,DC=opole,DC=pl',
                  password=os.environ['AD_ADMIN_PASSWORD'], auto_bind=True)

with open('/data/users.csv', 'r') as f:
    reader = csv.DictReader(f)
    passwords = []
    for row in reader:
        result = create_user_with_password(
            conn,
            username=row['username'],
            first_name=row['first_name'],
            last_name=row['last_name'],
            email=row['email'],
            group=row['group']  # Teachers / Students
        )
        passwords.append(result)

# Eksportuj hasła do Kubernetes Secret (do późniejszego zaszyfrowania)
import json
with open('/tmp/initial-passwords.json', 'w') as f:
    json.dump(passwords, f)

# Wyślij email z hasłami (opcjonalnie)
# send_password_emails(passwords)
```

---

## 📂 Struktura sealed-secrets w repo

```
gitops/
├── apps/
│   ├── network-ad/
│   │   └── overlays/production/sealed-secrets/
│   │       ├── network-ad-admin-secret.yaml        # ✅ Zaszyfrowane
│   │       └── radius-bind-secret.yaml             # ✅ Zaszyfrowane
│   │
│   └── user-ad/
│       └── overlays/production/sealed-secrets/
│           ├── user-ad-admin-secret.yaml           # ✅ Zaszyfrowane
│           ├── sso-ldap-bind-secret.yaml           # ✅ Zaszyfrowane
│           └── initial-user-passwords.yaml         # ✅ Zaszyfrowane (1000+ użytkowników)
│
└── environments/production/sealed-secrets/
    ├── pub-cert.pem                                 # Klucz publiczny do szyfrowania
    └── README.md                                    # Instrukcje użycia
```

---

## 🔍 Weryfikacja bezpieczeństwa

### Pre-commit hook (automatyczna blokada plain secrets)

```yaml
# .pre-commit-config.yaml (już dodany)
- repo: https://github.com/Yelp/detect-secrets
  rev: v1.4.0
  hooks:
    - id: detect-secrets
      args: [--baseline, .secrets.baseline]
```

### Skanowanie przed każdym commitem

```bash
# Wykryj plain secrets
pre-commit run detect-secrets --all-files

# Wykryj hasła w historii Git
git-secrets --scan
```

### CI/CD pipeline (GitHub Actions)

```yaml
# .github/workflows/security-scan.yaml
name: Security Scan

on: [push, pull_request]

jobs:
  scan-secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Skanuj plain secrets
      - name: Detect Secrets
        uses: reviewdog/action-detect-secrets@v1
        with:
          fail_on_error: true
      
      # Skanuj Kubernetes manifests
      - name: Kubesec Scan
        run: |
          docker run --rm -v $(pwd):/project \
            kubesec/kubesec:v2 scan /project/apps/*/base/*.yaml
      
      # Sprawdź czy SealedSecrets są prawidłowe
      - name: Validate SealedSecrets
        run: |
          find apps/ -name "*.yaml" -type f -exec grep -l "kind: SealedSecret" {} \; | \
          xargs -I {} kubeseal --validate --cert environments/production/sealed-secrets/pub-cert.pem < {}
```

---

## 📋 Checklist bezpieczeństwa (przed wdrożeniem)

### Network AD (`network-ad.zsel.opole.pl`)
- [ ] Wygenerować `network-ad-admin-secret` (SealedSecret)
- [ ] Wygenerować `radius-bind-secret` (SealedSecret)
- [ ] Usunąć plain Secret z `apps/network-ad/base/secret.yaml`
- [ ] Sprawdzić `git log` - czy plain secret nigdy nie było w historii

### User AD (`ad.zsel.opole.pl`)
- [ ] Wygenerować `user-ad-admin-secret` (SealedSecret)
- [ ] Wygenerować `sso-ldap-bind-secret` (SealedSecret)
- [ ] Przygotować CSV z listą użytkowników (1000+)
- [ ] Uruchomić Job do autogeneracji haseł użytkowników
- [ ] Wyeksportować hasła startowe (zaszyfrowane) do SealedSecret
- [ ] Zaimplementować dostarczanie haseł (email/druk)

### Infrastruktura
- [ ] Zainstalować Sealed Secrets Controller
- [ ] Pobrać klucz publiczny (`pub-cert.pem`)
- [ ] Skonfigurować pre-commit hooks
- [ ] Skonfigurować CI/CD security scans
- [ ] Przetestować rotację sekretów

### Compliance
- [ ] Dokumentacja procedury rotacji haseł (co 90 dni)
- [ ] Backup klucza prywatnego Sealed Secrets Controller (KRYTYCZNE!)
- [ ] Test disaster recovery (restore z backupu)
- [ ] Szkolenie zespołu IT z zarządzania sekretami

---

## 🚨 Disaster Recovery - Klucz prywatny

### Backup klucza prywatnego (KRYTYCZNY!)

```bash
# Klucz prywatny to JEDYNY sposób na odszyfrowanie SealedSecrets!
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-private-key-backup.yaml

# Zaszyfruj backup (GPG)
gpg --encrypt --recipient admin@zsel.opole.pl \
  sealed-secrets-private-key-backup.yaml

# Zapisz w bezpiecznym miejscu (POZA Git repo!)
# - Pendrive w sejfie
# - Password manager (1Password/Bitwarden)
# - Azure Key Vault (jako ostateczny backup)
```

### Restore klucza (po utracie klastra)

```bash
# 1. Zainstaluj Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# 2. Usuń wygenerowany klucz
kubectl delete secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key

# 3. Restore z backupu
gpg --decrypt sealed-secrets-private-key-backup.yaml.gpg | kubectl apply -f -

# 4. Restart controllera
kubectl rollout restart deployment -n sealed-secrets sealed-secrets-controller

# 5. Sprawdź czy SealedSecrets są odszyfrowane
kubectl get secrets -n core-auth network-ad-admin-secret
kubectl get secrets -n identity-system user-ad-admin-secret
```

---

## 📚 Dodatkowe zasoby

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

---

**Maintained by:** IT Security Team  
**Contact:** security@zsel.opole.pl  
**Emergency:** +48 XXX XXX XXX (on-call SRE)
