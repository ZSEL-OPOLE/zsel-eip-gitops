# Sealed Secrets - Production Environment

**DO NOT COMMIT PLAIN SECRETS TO THIS DIRECTORY!**

This directory contains:
- `pub-cert.pem` - Public certificate for sealing secrets (safe to commit)
- Instructions for sealing secrets

---

## Quick Start - Seal a Secret

```bash
# 1. Generate strong password
PASSWORD=$(openssl rand -base64 32)
echo "Save this password: $PASSWORD"

# 2. Create plain secret (temporary)
kubectl create secret generic my-secret \
  --namespace=my-namespace \
  --from-literal=password="$PASSWORD" \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 3. Seal the secret
kubeseal --format=yaml \
  --cert=environments/production/sealed-secrets/pub-cert.pem \
  --scope=strict \
  < /tmp/secret.yaml \
  > apps/my-app/overlays/production/sealed-secrets/my-secret.yaml

# 4. DELETE plain secret
rm /tmp/secret.yaml
unset PASSWORD

# 5. Commit sealed secret
git add apps/my-app/overlays/production/sealed-secrets/
git commit -m "feat(my-app): Add sealed secret"
```

---

## Fetch Public Certificate

```bash
# Install Sealed Secrets Controller first:
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets --timeout=120s

# Fetch public cert
kubeseal --fetch-cert \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets-controller \
  > environments/production/sealed-secrets/pub-cert.pem

# Commit public cert
git add environments/production/sealed-secrets/pub-cert.pem
git commit -m "chore: Add Sealed Secrets public certificate"
```

---

## Required Sealed Secrets for ZSEL

### Network AD (namespace: core-auth)
```bash
# network-ad-admin-secret
PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic network-ad-admin-secret \
  --namespace=core-auth \
  --from-literal=admin-password="$PASSWORD" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml --cert=environments/production/sealed-secrets/pub-cert.pem \
  > apps/network-ad/overlays/production/sealed-secrets/network-ad-admin-secret.yaml

# radius-bind-secret (retrieve from pod after network-ad deployment)
```

### User AD (namespace: identity-system)
```bash
# user-ad-admin-secret
PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic user-ad-admin-secret \
  --namespace=identity-system \
  --from-literal=admin-password="$PASSWORD" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml --cert=environments/production/sealed-secrets/pub-cert.pem \
  > apps/user-ad/overlays/production/sealed-secrets/user-ad-admin-secret.yaml

# sso-moodle-bind-secret (retrieve from pod after user-ad deployment)
# sso-bbb-bind-secret (retrieve from pod after user-ad deployment)
# sso-nextcloud-bind-secret (retrieve from pod after user-ad deployment)
```

---

## Backup Private Key (CRITICAL!)

```bash
# Backup private key (ONLY ONCE, STORE SECURELY!)
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-private-key-backup.yaml

# Encrypt with GPG
gpg --encrypt --recipient admin@zsel.opole.pl \
  sealed-secrets-private-key-backup.yaml

# Store encrypted backup in:
# - Password manager (1Password/Bitwarden)
# - USB drive in safe
# - Azure Key Vault (as ultimate backup)

# DELETE unencrypted backup
rm sealed-secrets-private-key-backup.yaml
```

---

See: `gitops/SECURITY-SEALED-SECRETS.md` for full documentation
