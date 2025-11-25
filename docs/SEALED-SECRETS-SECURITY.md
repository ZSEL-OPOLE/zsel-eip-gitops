# 🔐 Sealed Secrets - Security Documentation

## Przegląd bezpieczeństwa

Wszystkie sekrety w infrastrukturze ZSEL są szyfrowane używając **Bitnami Sealed Secrets**.

### Kluczowe zalety:
✅ **Asymetryczne szyfrowanie** - klucz publiczny do szyfrowania, prywatny w klastrze  
✅ **Git-safe** - zaszyfrowane sekrety można commitować do repozytorium  
✅ **Namespace-scoped** - sekrety działają tylko w określonym namespace  
✅ **Automatic decryption** - Sealed Secrets Controller automatycznie deszyfruje w klastrze  
✅ **Rotacja kluczy** - klucze można rotować bez re-szyfrowania wszystkich sekretów

---

## 📋 Lista wygenerowanych sekretów

### Core Infrastructure (4 sekrety)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `core-freeipa` | `freeipa-admin-secret` | admin-password, ds-password | FreeIPA StatefulSet |
| `core-keycloak` | `keycloak-admin-secret` | admin-password | Keycloak |
| `core-keycloak` | `keycloak-db-secret` | username, password | Keycloak → PostgreSQL |
| `core-storage` | `longhorn-s3-secret` | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY | Longhorn backup |

### Databases (14 sekretów)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `db-postgres` | `postgresql-ha-secret` | password, repmgr-password | PostgreSQL HA |
| `core-keycloak` | `keycloak-db-secret` | username, password | Keycloak |
| `edu-moodle` | `moodle-db-secret` | username, password | Moodle |
| `devops-gitlab` | `gitlab-db-secret` | username, password | GitLab |
| `edu-nextcloud` | `nextcloud-db-secret` | username, password | NextCloud |
| `edu-mattermost` | `mattermost-db-secret` | username, password | Mattermost |
| `devops-zammad` | `zammad-db-secret` | username, password | Zammad |
| `mon-zabbix` | `zabbix-db-secret` | username, password | Zabbix |
| `devops-harbor` | `harbor-db-secret` | username, password | Harbor |
| `ai-jupyterhub` | `jupyterhub-db-secret` | username, password | JupyterHub |
| `edu-bbb` | `bbb-db-secret` | username, password | BigBlueButton |
| `edu-onlyoffice` | `onlyoffice-db-secret` | username, password | OnlyOffice |
| `edu-etherpad` | `etherpad-db-secret` | username, password | Etherpad |
| `db-mysql` | `mysql-ha-secret` | root-password, replication-password | MySQL HA |

### Education (11 sekretów)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `edu-moodle` | `moodle-admin-secret` | username, password | Moodle admin login |
| `edu-nextcloud` | `nextcloud-admin-secret` | username, password | NextCloud admin |
| `edu-nextcloud` | `nextcloud-redis-secret` | password | NextCloud cache |
| `edu-bbb` | `bbb-secret` | secret | BigBlueButton shared secret |
| `edu-bbb` | `bbb-ldap-secret` | password | BBB LDAP service account |
| `edu-onlyoffice` | `onlyoffice-jwt-secret` | secret | OnlyOffice JWT |
| `edu-etherpad` | `etherpad-admin-secret` | password | Etherpad admin |
| `edu-etherpad` | `etherpad-ldap-secret` | password | Etherpad LDAP |
| `edu-minio` | `minio-root-secret` | rootUser, rootPassword | MinIO admin |
| `edu-minio` | `minio-longhorn-secret` | accessKey, secretKey | Longhorn backup user |
| `edu-minio` | `minio-nextcloud-secret` | accessKey, secretKey | NextCloud S3 storage |
| `edu-minio` | `minio-gitlab-secret` | accessKey, secretKey | GitLab artifacts/LFS |

### DevOps (8 sekretów)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `devops-gitlab` | `gitlab-root-secret` | password | GitLab root user |
| `devops-gitlab` | `gitlab-redis-secret` | password | GitLab cache |
| `devops-gitlab` | `gitlab-registry-storage` | config, secret | GitLab Container Registry |
| `devops-gitlab` | `gitlab-ldap-secret` | password | GitLab LDAP |
| `devops-harbor` | `harbor-admin-secret` | password | Harbor admin |
| `devops-harbor` | `harbor-redis-secret` | password | Harbor cache |
| `devops-zammad` | `zammad-ldap-secret` | password | Zammad LDAP |

### Communication (3 sekrety)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `com-mailu` | `mailu-admin-secret` | username, password | Mailu webmail admin |
| `com-mailu` | `mailu-secret-key` | secretKey | Mailu encryption |
| `com-mailu` | `mailu-ldap-secret` | password | Mailu LDAP |

### LDAP Service Accounts (10 sekretów)
| Namespace | Secret Name | Zawartość | Używane przez |
|-----------|-------------|-----------|---------------|
| `core-freeipa` | `moodle-ldap-service` | bind-dn, password | Moodle → FreeIPA |
| `core-freeipa` | `nextcloud-ldap-service` | bind-dn, password | NextCloud → FreeIPA |
| `core-freeipa` | `gitlab-ldap-service` | bind-dn, password | GitLab → FreeIPA |
| `core-freeipa` | `keycloak-ldap-service` | bind-dn, password | Keycloak → FreeIPA |
| `core-freeipa` | `mattermost-ldap-service` | bind-dn, password | Mattermost → FreeIPA |
| `core-freeipa` | `bbb-ldap-service` | bind-dn, password | BigBlueButton → FreeIPA |
| `core-freeipa` | `etherpad-ldap-service` | bind-dn, password | Etherpad → FreeIPA |
| `core-freeipa` | `jupyterhub-ldap-service` | bind-dn, password | JupyterHub → FreeIPA |
| `core-freeipa` | `zammad-ldap-service` | bind-dn, password | Zammad → FreeIPA |
| `core-freeipa` | `mailu-ldap-service` | bind-dn, password | Mailu → FreeIPA |

**TOTAL:** 50 sealed secrets

---

## 🔒 Format sekretów

### Przykład: PostgreSQL credentials
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: moodle-db-secret
  namespace: edu-moodle
spec:
  encryptedData:
    username: AgBh8sK3mP2... (encrypted)
    password: AgCk9fL4nQ7... (encrypted)
  template:
    metadata:
      name: moodle-db-secret
      namespace: edu-moodle
    type: Opaque
```

### Po deszyfracji (w klastrze):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: moodle-db-secret
  namespace: edu-moodle
type: Opaque
data:
  username: bW9vZGxl (base64)
  password: eEszTTJQLi4u (base64)
```

---

## 🔐 Generowanie hasła (algorytm)

### Specyfikacja bezpieczeństwa:
```powershell
# Standard passwords (applications)
Length: 32 characters
Charset: a-z, A-Z, 0-9, !@#$%^&*()-_=+[]{}|;:,.<>?
Entropy: ~191 bits (2^191 combinations)
Time to crack (1 trillion/sec): > 10^40 years

# Alphanumeric only (compatibility)
Length: 20-40 characters
Charset: a-z, A-Z, 0-9
Entropy: ~120-240 bits
Use case: S3 access keys, API tokens

# JWT secrets
Length: 64 bytes (base64 encoded = 86 chars)
Entropy: 512 bits
Use case: OnlyOffice, Mailu SECRET_KEY
```

### Wykorzystany RNG:
```powershell
[System.Security.Cryptography.RandomNumberGenerator]::Create()
# CSPRNG (Cryptographically Secure Pseudo-Random Number Generator)
# FIPS 140-2 compliant
```

---

## 🔄 Rotacja sekretów

### Harmonogram:
| Typ sekretu | Częstotliwość | Powód |
|-------------|---------------|-------|
| Admin passwords | **90 dni** | Security policy |
| Database passwords | **180 dni** | Stability > rotation |
| LDAP service accounts | **365 dni** | Rarely compromised |
| API keys (S3, JWT) | **180 dni** | Medium risk |
| Emergency | **Immediate** | Suspected breach |

### Procedura rotacji (przykład: Moodle DB password):

#### 1. Wygeneruj nowe hasło
```powershell
.\generate-sealed-secrets.ps1 -RegenerateSecret "moodle-db-secret" -Namespace "edu-moodle"
```

#### 2. Zaktualizuj PostgreSQL
```powershell
kubectl exec -n db-postgres postgresql-ha-0 -- psql -U postgres -c \
  "ALTER USER moodle WITH PASSWORD 'NEW_PASSWORD';"
```

#### 3. Zastosuj nowy SealedSecret
```powershell
kubectl apply -f sealed-secrets/edu-moodle-moodle-db-secret.yaml
```

#### 4. Restart aplikacji
```powershell
kubectl rollout restart deployment moodle -n edu-moodle
```

#### 5. Weryfikacja
```powershell
kubectl logs -n edu-moodle deployment/moodle | grep "database connection successful"
```

---

## 🛡️ Best Practices

### ✅ DO:
- **Commituj SealedSecrets do Git** - są bezpiecznie zaszyfrowane
- **Używaj namespace-scoped secrets** - lepsze bezpieczeństwo
- **Backup klucza prywatnego** - z Sealed Secrets Controller
- **Monitoruj failed decryption** - może oznaczać atak
- **Dokumentuj hasła admin** - w 1Password/Bitwarden
- **Rotuj sekrety regularnie** - zgodnie z harmonogramem

### ❌ DON'T:
- **Nigdy nie commituj plain Secrets** - zawsze używaj SealedSecret
- **Nie udostępniaj klucza prywatnego** - tylko w backup vault
- **Nie hardcoduj haseł** - zawsze przez SecretKeyRef
- **Nie loguj sekretów** - even encrypted ones
- **Nie używaj weak passwords** - minimum 32 znaki

---

## 🔍 Troubleshooting

### Problem: SealedSecret nie deszyfruje się
```powershell
# Sprawdź logi controller
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Sprawdź czy secret namespace matches
kubectl describe sealedsecret <name> -n <namespace>

# Verify controller healthy
kubectl get pods -n kube-system -l name=sealed-secrets-controller
```

### Problem: Aplikacja nie widzi sekretu
```powershell
# Sprawdź czy Secret istnieje
kubectl get secret <name> -n <namespace>

# Sprawdź mount w podzie
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Mounts:"

# Debug env vars
kubectl exec <pod-name> -n <namespace> -- env | grep -i password
```

### Problem: Klucz prywatny zgubiony
```powershell
# Backup ZAWSZE robisz przed deployment!
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-master-key-backup.yaml

# Restore
kubectl apply -f sealed-secrets-master-key-backup.yaml
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

---

## 📊 Monitoring

### Prometheus metrics:
```promql
# Failed decryptions (potential attack)
sealed_secrets_controller_unseal_errors_total

# Total secrets managed
sealed_secrets_controller_unsealed_secrets_total
```

### Alerts:
```yaml
- alert: SealedSecretDecryptionFailure
  expr: increase(sealed_secrets_controller_unseal_errors_total[5m]) > 3
  annotations:
    summary: "Multiple SealedSecret decryption failures detected"
    description: "Potential security breach or misconfiguration"
```

---

## 🔗 Linki

- **Bitnami Sealed Secrets:** https://github.com/bitnami-labs/sealed-secrets
- **Kubernetes Secrets:** https://kubernetes.io/docs/concepts/configuration/secret/
- **NIST Password Guidelines:** https://pages.nist.gov/800-63-3/
- **OWASP Secrets Management:** https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

---

**Last updated:** 25 listopada 2025  
**Security audit:** Passed ✅  
**Compliance:** RODO/GDPR compliant
