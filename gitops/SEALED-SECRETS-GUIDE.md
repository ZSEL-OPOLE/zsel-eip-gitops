# Sealed Secrets Installation and Secret Management Guide

## Overview
Sealed Secrets provides secure, encrypted secret management for GitOps workflows. Secrets are encrypted with a public key and can only be decrypted by the Sealed Secrets controller running in the K3s cluster.

## Architecture
- **Public Key**: Used to encrypt secrets (can be safely stored in Git)
- **Private Key**: Stored in K3s cluster, used by controller to decrypt
- **SealedSecret CRD**: Encrypted version of K8s Secret
- **Controller**: Watches for SealedSecrets, decrypts and creates native Secrets

---

## Installation Steps

### 1. Install Sealed Secrets Controller

```bash
# Install latest Sealed Secrets controller (v0.24.0)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller to be ready
kubectl rollout status deployment sealed-secrets-controller -n kube-system

# Verify controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller
```

### 2. Install kubeseal CLI Tool

**Windows (PowerShell):**
```powershell
# Download kubeseal binary
Invoke-WebRequest -Uri "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-windows-amd64.tar.gz" -OutFile "kubeseal.tar.gz"

# Extract binary
tar -xzf kubeseal.tar.gz

# Move to PATH location
Move-Item -Path ".\kubeseal.exe" -Destination "C:\Windows\System32\kubeseal.exe"

# Verify installation
kubeseal --version
```

**Linux/Mac:**
```bash
# Download and install kubeseal
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Verify installation
kubeseal --version
```

### 3. Fetch Public Certificate

```bash
# Create directory for sealed secrets
mkdir -p environments/production/sealed-secrets

# Fetch public certificate from controller
kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=kube-system > environments/production/sealed-secrets/pub-cert.pem

# Verify certificate was created
cat environments/production/sealed-secrets/pub-cert.pem
```

**Note:** The `pub-cert.pem` file can be safely committed to Git. It's only used for encryption, not decryption.

---

## Creating Sealed Secrets

### General Process

1. Create a temporary Secret YAML file with plaintext values
2. Encrypt the Secret using `kubeseal` and the public certificate
3. Delete the temporary plaintext file
4. Commit the encrypted SealedSecret to Git
5. Deploy the SealedSecret to K3s (controller will decrypt and create native Secret)

### Example: Creating a Sealed Secret

**Step 1: Create temporary plaintext secret**
```yaml
# /tmp/my-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
stringData:
  username: "admin"
  password: "SuperSecretPassword123!"
```

**Step 2: Encrypt with kubeseal**
```bash
kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/my-secret.yaml \
  > environments/production/sealed-secrets/my-sealed-secret.yaml

# Delete plaintext file immediately
rm /tmp/my-secret.yaml
```

**Step 3: Commit encrypted SealedSecret**
```bash
git add environments/production/sealed-secrets/my-sealed-secret.yaml
git commit -m "Add encrypted my-secret SealedSecret"
git push
```

**Step 4: Deploy SealedSecret**
```bash
kubectl apply -f environments/production/sealed-secrets/my-sealed-secret.yaml

# Verify native Secret was created
kubectl get secret my-secret -n default
```

---

## Required Secrets for Infrastructure

### 1. Network AD Admin Credentials
**File:** `network-ad-admin-secret`  
**Namespace:** `core-network`  
**Keys:** `ADMIN_PASSWORD`

```bash
kubectl create secret generic network-ad-admin-secret \
  --namespace=core-network \
  --from-literal=ADMIN_PASSWORD='YOUR_NETWORK_AD_ADMIN_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/network-ad-admin-secret.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/network-ad-admin-secret.yaml \
  > environments/production/sealed-secrets/network-ad-admin-sealed-secret.yaml

rm /tmp/network-ad-admin-secret.yaml
```

### 2. User AD Admin Credentials
**File:** `user-ad-admin-secret`  
**Namespace:** `core-network`  
**Keys:** `ADMIN_PASSWORD`

```bash
kubectl create secret generic user-ad-admin-secret \
  --namespace=core-network \
  --from-literal=ADMIN_PASSWORD='YOUR_USER_AD_ADMIN_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/user-ad-admin-secret.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/user-ad-admin-secret.yaml \
  > environments/production/sealed-secrets/user-ad-admin-sealed-secret.yaml

rm /tmp/user-ad-admin-secret.yaml
```

### 3. FreeRADIUS Network - LDAP Bind Credentials
**File:** `radius-bind`  
**Namespace:** `core-network`  
**Keys:** `LDAP_BIND_PASSWORD`

```bash
kubectl create secret generic radius-bind \
  --namespace=core-network \
  --from-literal=LDAP_BIND_PASSWORD='YOUR_NETWORK_AD_RADIUS_BIND_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/radius-bind.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/radius-bind.yaml \
  > environments/production/sealed-secrets/radius-bind-sealed-secret.yaml

rm /tmp/radius-bind.yaml
```

### 4. FreeRADIUS WiFi - LDAP Bind Credentials
**File:** `sso-wifi-bind`  
**Namespace:** `core-network`  
**Keys:** `LDAP_BIND_PASSWORD`

```bash
kubectl create secret generic sso-wifi-bind \
  --namespace=core-network \
  --from-literal=LDAP_BIND_PASSWORD='YOUR_USER_AD_WIFI_BIND_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/sso-wifi-bind.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/sso-wifi-bind.yaml \
  > environments/production/sealed-secrets/sso-wifi-bind-sealed-secret.yaml

rm /tmp/sso-wifi-bind.yaml
```

### 5. MikroTik RADIUS Shared Secret (Device Login)
**File:** `mikrotik-radius-secret`  
**Namespace:** `core-network`  
**Keys:** `RADIUS_SECRET`

```bash
kubectl create secret generic mikrotik-radius-secret \
  --namespace=core-network \
  --from-literal=RADIUS_SECRET='YOUR_MIKROTIK_DEVICE_RADIUS_SECRET' \
  --dry-run=client -o yaml \
  > /tmp/mikrotik-radius-secret.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/mikrotik-radius-secret.yaml \
  > environments/production/sealed-secrets/mikrotik-radius-sealed-secret.yaml

rm /tmp/mikrotik-radius-secret.yaml
```

### 6. WiFi RADIUS Shared Secret (User WiFi Auth)
**File:** `wifi-radius-secret`  
**Namespace:** `core-network`  
**Keys:** `RADIUS_SECRET`

```bash
kubectl create secret generic wifi-radius-secret \
  --namespace=core-network \
  --from-literal=RADIUS_SECRET='YOUR_WIFI_RADIUS_SECRET' \
  --dry-run=client -o yaml \
  > /tmp/wifi-radius-secret.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/wifi-radius-secret.yaml \
  > environments/production/sealed-secrets/wifi-radius-sealed-secret.yaml

rm /tmp/wifi-radius-secret.yaml
```

### 7. PacketFence Database Credentials
**File:** `packetfence-db`  
**Namespace:** `core-network`  
**Keys:** `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `REDIS_PASSWORD`

```bash
kubectl create secret generic packetfence-db \
  --namespace=core-network \
  --from-literal=MYSQL_ROOT_PASSWORD='YOUR_MYSQL_ROOT_PASSWORD' \
  --from-literal=MYSQL_PASSWORD='YOUR_PACKETFENCE_DB_PASSWORD' \
  --from-literal=REDIS_PASSWORD='YOUR_REDIS_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/packetfence-db.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/packetfence-db.yaml \
  > environments/production/sealed-secrets/packetfence-db-sealed-secret.yaml

rm /tmp/packetfence-db.yaml
```

### 8. Graylog Admin Credentials
**File:** `graylog-password-secret`  
**Namespace:** `logging-system`  
**Keys:** `GRAYLOG_PASSWORD_SECRET`, `GRAYLOG_ROOT_PASSWORD_SHA2`

```bash
# Generate random password secret (96 chars minimum)
GRAYLOG_PASSWORD_SECRET=$(pwgen -N 1 -s 96)

# Generate root password hash (replace 'YOUR_GRAYLOG_ADMIN_PASSWORD' with actual password)
GRAYLOG_ROOT_PASSWORD_SHA2=$(echo -n 'YOUR_GRAYLOG_ADMIN_PASSWORD' | sha256sum | cut -d' ' -f1)

kubectl create secret generic graylog-password-secret \
  --namespace=logging-system \
  --from-literal=GRAYLOG_PASSWORD_SECRET="$GRAYLOG_PASSWORD_SECRET" \
  --from-literal=GRAYLOG_ROOT_PASSWORD_SHA2="$GRAYLOG_ROOT_PASSWORD_SHA2" \
  --dry-run=client -o yaml \
  > /tmp/graylog-password-secret.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/graylog-password-secret.yaml \
  > environments/production/sealed-secrets/graylog-password-sealed-secret.yaml

rm /tmp/graylog-password-secret.yaml
```

### 9. MongoDB Root Password (Graylog Backend)
**File:** `mongodb-root-password`  
**Namespace:** `logging-system`  
**Keys:** `MONGO_INITDB_ROOT_PASSWORD`

```bash
kubectl create secret generic mongodb-root-password \
  --namespace=logging-system \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD='YOUR_MONGODB_ROOT_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/mongodb-root-password.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/mongodb-root-password.yaml \
  > environments/production/sealed-secrets/mongodb-root-password-sealed-secret.yaml

rm /tmp/mongodb-root-password.yaml
```

### 10. Elasticsearch Password (Graylog Backend)
**File:** `elasticsearch-password`  
**Namespace:** `logging-system`  
**Keys:** `ELASTIC_PASSWORD`

```bash
kubectl create secret generic elasticsearch-password \
  --namespace=logging-system \
  --from-literal=ELASTIC_PASSWORD='YOUR_ELASTICSEARCH_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/elasticsearch-password.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/elasticsearch-password.yaml \
  > environments/production/sealed-secrets/elasticsearch-password-sealed-secret.yaml

rm /tmp/elasticsearch-password.yaml
```

### 11. Grafana Admin Credentials
**File:** `grafana-admin-credentials`  
**Namespace:** `monitoring-system`  
**Keys:** `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`

```bash
kubectl create secret generic grafana-admin-credentials \
  --namespace=monitoring-system \
  --from-literal=GF_SECURITY_ADMIN_USER='admin' \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD='YOUR_GRAFANA_ADMIN_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/grafana-admin-credentials.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/grafana-admin-credentials.yaml \
  > environments/production/sealed-secrets/grafana-admin-credentials-sealed-secret.yaml

rm /tmp/grafana-admin-credentials.yaml
```

### 12. SNMP v3 Credentials (MikroTik Monitoring)
**File:** `snmp-exporter-credentials`  
**Namespace:** `monitoring-system`  
**Keys:** `SNMP_AUTH_PASSWORD`, `SNMP_PRIV_PASSWORD`

```bash
kubectl create secret generic snmp-exporter-credentials \
  --namespace=monitoring-system \
  --from-literal=SNMP_AUTH_PASSWORD='YOUR_SNMP_AUTH_PASSWORD' \
  --from-literal=SNMP_PRIV_PASSWORD='YOUR_SNMP_PRIV_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/snmp-exporter-credentials.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/snmp-exporter-credentials.yaml \
  > environments/production/sealed-secrets/snmp-exporter-credentials-sealed-secret.yaml

rm /tmp/snmp-exporter-credentials.yaml
```

### 13. Zabbix Database Password
**File:** `zabbix-db-password`  
**Namespace:** `monitoring-system`  
**Keys:** `POSTGRES_PASSWORD`

```bash
kubectl create secret generic zabbix-db-password \
  --namespace=monitoring-system \
  --from-literal=POSTGRES_PASSWORD='YOUR_ZABBIX_DB_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/zabbix-db-password.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/zabbix-db-password.yaml \
  > environments/production/sealed-secrets/zabbix-db-password-sealed-secret.yaml

rm /tmp/zabbix-db-password.yaml
```

### 14. Zabbix Admin Password
**File:** `zabbix-admin-password`  
**Namespace:** `monitoring-system`  
**Keys:** `ZBX_ADMIN_PASSWORD`

```bash
kubectl create secret generic zabbix-admin-password \
  --namespace=monitoring-system \
  --from-literal=ZBX_ADMIN_PASSWORD='YOUR_ZABBIX_ADMIN_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/zabbix-admin-password.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/zabbix-admin-password.yaml \
  > environments/production/sealed-secrets/zabbix-admin-password-sealed-secret.yaml

rm /tmp/zabbix-admin-password.yaml
```

### 15. MinIO Root Credentials
**File:** `minio-root-credentials`  
**Namespace:** `storage-system`  
**Keys:** `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`

```bash
kubectl create secret generic minio-root-credentials \
  --namespace=storage-system \
  --from-literal=MINIO_ROOT_USER='minioadmin' \
  --from-literal=MINIO_ROOT_PASSWORD='YOUR_MINIO_ROOT_PASSWORD' \
  --dry-run=client -o yaml \
  > /tmp/minio-root-credentials.yaml

kubeseal --cert environments/production/sealed-secrets/pub-cert.pem \
  --format yaml \
  < /tmp/minio-root-credentials.yaml \
  > environments/production/sealed-secrets/minio-root-credentials-sealed-secret.yaml

rm /tmp/minio-root-credentials.yaml
```

---

## Automated Secret Creation Script

Create this helper script for batch secret generation:

**File:** `environments/production/sealed-secrets/create-all-secrets.sh`

```bash
#!/bin/bash
set -e

CERT_PATH="environments/production/sealed-secrets/pub-cert.pem"

if [ ! -f "$CERT_PATH" ]; then
  echo "Error: Public certificate not found at $CERT_PATH"
  echo "Run: kubeseal --fetch-cert > $CERT_PATH"
  exit 1
fi

# Function to create and seal a secret
seal_secret() {
  local NAME=$1
  local NAMESPACE=$2
  local TMP_FILE="/tmp/${NAME}.yaml"
  local OUTPUT_FILE="environments/production/sealed-secrets/${NAME}-sealed-secret.yaml"
  
  echo "Creating sealed secret: $NAME in namespace $NAMESPACE"
  
  # Pipe stdin to kubeseal
  cat > "$TMP_FILE"
  
  kubeseal --cert "$CERT_PATH" --format yaml < "$TMP_FILE" > "$OUTPUT_FILE"
  
  rm "$TMP_FILE"
  
  echo "✓ Created: $OUTPUT_FILE"
}

echo "=== Sealed Secrets Batch Creation ==="
echo "This script will prompt you for all required passwords."
echo ""

# 1. Network AD
read -sp "Network AD Admin Password: " NETWORK_AD_PASS
echo ""
kubectl create secret generic network-ad-admin-secret \
  --namespace=core-network \
  --from-literal=ADMIN_PASSWORD="$NETWORK_AD_PASS" \
  --dry-run=client -o yaml | seal_secret "network-ad-admin" "core-network"

# 2. User AD
read -sp "User AD Admin Password: " USER_AD_PASS
echo ""
kubectl create secret generic user-ad-admin-secret \
  --namespace=core-network \
  --from-literal=ADMIN_PASSWORD="$USER_AD_PASS" \
  --dry-run=client -o yaml | seal_secret "user-ad-admin" "core-network"

# 3. RADIUS Network Bind
read -sp "RADIUS Network LDAP Bind Password: " RADIUS_NETWORK_BIND
echo ""
kubectl create secret generic radius-bind \
  --namespace=core-network \
  --from-literal=LDAP_BIND_PASSWORD="$RADIUS_NETWORK_BIND" \
  --dry-run=client -o yaml | seal_secret "radius-bind" "core-network"

# 4. RADIUS WiFi Bind
read -sp "RADIUS WiFi LDAP Bind Password: " RADIUS_WIFI_BIND
echo ""
kubectl create secret generic sso-wifi-bind \
  --namespace=core-network \
  --from-literal=LDAP_BIND_PASSWORD="$RADIUS_WIFI_BIND" \
  --dry-run=client -o yaml | seal_secret "sso-wifi-bind" "core-network"

# 5. MikroTik RADIUS Secret
read -sp "MikroTik Device RADIUS Shared Secret: " MIKROTIK_RADIUS
echo ""
kubectl create secret generic mikrotik-radius-secret \
  --namespace=core-network \
  --from-literal=RADIUS_SECRET="$MIKROTIK_RADIUS" \
  --dry-run=client -o yaml | seal_secret "mikrotik-radius" "core-network"

# 6. WiFi RADIUS Secret
read -sp "WiFi RADIUS Shared Secret: " WIFI_RADIUS
echo ""
kubectl create secret generic wifi-radius-secret \
  --namespace=core-network \
  --from-literal=RADIUS_SECRET="$WIFI_RADIUS" \
  --dry-run=client -o yaml | seal_secret "wifi-radius" "core-network"

# 7. PacketFence DB
read -sp "MySQL Root Password: " MYSQL_ROOT
echo ""
read -sp "PacketFence DB Password: " PF_DB_PASS
echo ""
read -sp "Redis Password: " REDIS_PASS
echo ""
kubectl create secret generic packetfence-db \
  --namespace=core-network \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT" \
  --from-literal=MYSQL_PASSWORD="$PF_DB_PASS" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASS" \
  --dry-run=client -o yaml | seal_secret "packetfence-db" "core-network"

# 8. Graylog
read -sp "Graylog Admin Password: " GRAYLOG_ADMIN
echo ""
GRAYLOG_PASSWORD_SECRET=$(pwgen -N 1 -s 96)
GRAYLOG_ROOT_PASSWORD_SHA2=$(echo -n "$GRAYLOG_ADMIN" | sha256sum | cut -d' ' -f1)
kubectl create secret generic graylog-password-secret \
  --namespace=logging-system \
  --from-literal=GRAYLOG_PASSWORD_SECRET="$GRAYLOG_PASSWORD_SECRET" \
  --from-literal=GRAYLOG_ROOT_PASSWORD_SHA2="$GRAYLOG_ROOT_PASSWORD_SHA2" \
  --dry-run=client -o yaml | seal_secret "graylog-password" "logging-system"

# 9. MongoDB
read -sp "MongoDB Root Password: " MONGO_ROOT
echo ""
kubectl create secret generic mongodb-root-password \
  --namespace=logging-system \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT" \
  --dry-run=client -o yaml | seal_secret "mongodb-root-password" "logging-system"

# 10. Elasticsearch
read -sp "Elasticsearch Password: " ELASTIC_PASS
echo ""
kubectl create secret generic elasticsearch-password \
  --namespace=logging-system \
  --from-literal=ELASTIC_PASSWORD="$ELASTIC_PASS" \
  --dry-run=client -o yaml | seal_secret "elasticsearch-password" "logging-system"

# 11. Grafana
read -sp "Grafana Admin Password: " GRAFANA_ADMIN
echo ""
kubectl create secret generic grafana-admin-credentials \
  --namespace=monitoring-system \
  --from-literal=GF_SECURITY_ADMIN_USER='admin' \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN" \
  --dry-run=client -o yaml | seal_secret "grafana-admin-credentials" "monitoring-system"

# 12. SNMP v3
read -sp "SNMP v3 Auth Password: " SNMP_AUTH
echo ""
read -sp "SNMP v3 Priv Password: " SNMP_PRIV
echo ""
kubectl create secret generic snmp-exporter-credentials \
  --namespace=monitoring-system \
  --from-literal=SNMP_AUTH_PASSWORD="$SNMP_AUTH" \
  --from-literal=SNMP_PRIV_PASSWORD="$SNMP_PRIV" \
  --dry-run=client -o yaml | seal_secret "snmp-exporter-credentials" "monitoring-system"

# 13. Zabbix DB
read -sp "Zabbix PostgreSQL Password: " ZABBIX_DB
echo ""
kubectl create secret generic zabbix-db-password \
  --namespace=monitoring-system \
  --from-literal=POSTGRES_PASSWORD="$ZABBIX_DB" \
  --dry-run=client -o yaml | seal_secret "zabbix-db-password" "monitoring-system"

# 14. Zabbix Admin
read -sp "Zabbix Admin Password: " ZABBIX_ADMIN
echo ""
kubectl create secret generic zabbix-admin-password \
  --namespace=monitoring-system \
  --from-literal=ZBX_ADMIN_PASSWORD="$ZABBIX_ADMIN" \
  --dry-run=client -o yaml | seal_secret "zabbix-admin-password" "monitoring-system"

# 15. MinIO
read -sp "MinIO Root Password (min 8 chars): " MINIO_ROOT_PASS
echo ""
kubectl create secret generic minio-root-credentials \
  --namespace=storage-system \
  --from-literal=MINIO_ROOT_USER='minioadmin' \
  --from-literal=MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASS" \
  --dry-run=client -o yaml | seal_secret "minio-root-credentials" "storage-system"

echo ""
echo "=== All Sealed Secrets Created ==="
echo "Next steps:"
echo "1. Review generated SealedSecret files in environments/production/sealed-secrets/"
echo "2. Commit SealedSecret files to Git: git add environments/production/sealed-secrets/*.yaml"
echo "3. Deploy SealedSecrets: kubectl apply -f environments/production/sealed-secrets/"
echo "4. Verify native Secrets were created: kubectl get secrets --all-namespaces"
```

Make the script executable:
```bash
chmod +x environments/production/sealed-secrets/create-all-secrets.sh
```

---

## Deployment Workflow

### 1. Generate All Secrets
```bash
# Run automated script
./environments/production/sealed-secrets/create-all-secrets.sh

# OR create secrets individually (see sections above)
```

### 2. Commit SealedSecrets to Git
```bash
git add environments/production/sealed-secrets/*.yaml
git commit -m "Add encrypted SealedSecrets for infrastructure services"
git push
```

### 3. Deploy SealedSecrets to K3s
```bash
# Apply all SealedSecrets
kubectl apply -f environments/production/sealed-secrets/

# Verify controller decrypted and created native Secrets
kubectl get secrets -n core-network
kubectl get secrets -n logging-system
kubectl get secrets -n monitoring-system
kubectl get secrets -n storage-system
```

### 4. Verify Services Can Access Secrets
```bash
# Check Network AD pod logs
kubectl logs -n core-network -l app.kubernetes.io/component=network-ad --tail=50

# Check Graylog pod logs
kubectl logs -n logging-system -l app.kubernetes.io/component=graylog --tail=50

# Check Grafana pod logs
kubectl logs -n monitoring-system -l app.kubernetes.io/component=grafana --tail=50
```

---

## Secret Rotation

When passwords need to be rotated:

1. **Generate new SealedSecret** with updated password
2. **Delete old SealedSecret**: `kubectl delete sealedsecret <name> -n <namespace>`
3. **Apply new SealedSecret**: `kubectl apply -f <new-sealed-secret>.yaml`
4. **Restart affected pods**: `kubectl rollout restart deployment/<name> -n <namespace>`

---

## Backup and Recovery

### Backup Controller Private Key
```bash
# Backup controller private key (CRITICAL - store securely)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-controller-key-backup.yaml

# Store backup in secure location (e.g., encrypted USB drive, password manager)
```

### Restore Controller Private Key
```bash
# Restore controller private key (e.g., after cluster rebuild)
kubectl apply -f sealed-secrets-controller-key-backup.yaml

# Restart controller to load key
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

**IMPORTANT:** Without the controller private key, all SealedSecrets become permanently unrecoverable. Always maintain secure backups.

---

## Troubleshooting

### Issue: SealedSecret not decrypting
```bash
# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller --tail=100

# Check SealedSecret status
kubectl describe sealedsecret <name> -n <namespace>

# Verify public cert matches controller
kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=kube-system
```

### Issue: kubeseal command fails
```bash
# Verify controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check service endpoint
kubectl get svc -n kube-system sealed-secrets-controller

# Test connectivity
kubeseal --fetch-cert
```

### Issue: Secret not available to pods
```bash
# Check Secret exists
kubectl get secret <secret-name> -n <namespace>

# Check Secret data (base64 encoded)
kubectl get secret <secret-name> -n <namespace> -o yaml

# Check pod can mount secret
kubectl describe pod <pod-name> -n <namespace>
```

---

## Security Best Practices

1. **Never commit plaintext secrets** to Git (use /tmp for temporary files)
2. **Delete temporary files immediately** after sealing (rm /tmp/*.yaml)
3. **Backup controller private key** securely (encrypted storage only)
4. **Rotate passwords regularly** (every 90 days recommended)
5. **Use strong passwords** (minimum 16 chars, mixed case, numbers, symbols)
6. **Limit access to pub-cert.pem** (read-only for CI/CD, developers)
7. **Audit SealedSecret deployments** (track who created/modified secrets)
8. **Monitor controller logs** (detect decryption failures, unauthorized access)

---

## Summary

- **Controller installed:** `kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml`
- **Public cert fetched:** `kubeseal --fetch-cert > environments/production/sealed-secrets/pub-cert.pem`
- **15 SealedSecrets created:** AD, RADIUS, WiFi, Graylog, Grafana, Zabbix, MinIO
- **All secrets committed to Git:** Encrypted, safe to version control
- **Controller decrypts automatically:** Native Secrets created when SealedSecrets are applied
- **Backup controller key:** Store `sealed-secrets-controller-key-backup.yaml` securely

**Next Steps:**
1. Run `./environments/production/sealed-secrets/create-all-secrets.sh`
2. Commit SealedSecrets to Git
3. Deploy infrastructure services via ArgoCD
4. Verify all services start successfully with encrypted secrets
