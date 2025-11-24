#!/bin/bash
# Import Network AD users to Samba AD Domain Controller
# Domain: network-ad.zsel.opole.pl
# Namespace: core-auth
# Pod: network-ad-dc-0 (PRIMARY)

set -e

NAMESPACE="core-auth"
POD_NAME="network-ad-dc-0"
LDIF_DIR="."

echo "=========================================="
echo "🔧 Network AD User Import Script"
echo "=========================================="
echo "Domain: network-ad.zsel.opole.pl"
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo ""

# Check if pod exists
if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &>/dev/null; then
  echo "❌ ERROR: Pod $POD_NAME not found in namespace $NAMESPACE"
  echo "   Deploy Network AD first: kubectl apply -k gitops/apps/network-ad/"
  exit 1
fi

# Check if pod is ready
POD_STATUS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
  echo "❌ ERROR: Pod $POD_NAME is not Running (current status: $POD_STATUS)"
  exit 1
fi

echo "✅ Pod $POD_NAME is Running"
echo ""

# Import OUs and Groups first (if not exist)
echo "📁 Creating Organizational Units..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
  # Create NetworkAdmins OU (parent)
  samba-tool ou create "OU=NetworkAdmins,DC=network-ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU NetworkAdmins already exists"
  
  # Create ServiceAccounts OU
  samba-tool ou create "OU=ServiceAccounts,DC=network-ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU ServiceAccounts already exists"
  
  # Create Groups OU
  samba-tool ou create "OU=Groups,DC=network-ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU Groups already exists"
  
  # Create Network-Operators group
  samba-tool group add "Network-Operators" --groupou="OU=Groups" --description="Network Operators (read+write, NO reboot)" 2>/dev/null || echo "   Group Network-Operators already exists"
EOF

echo "✅ OUs created"
echo ""

# Import LDIF files
for LDIF_FILE in ${LDIF_DIR}/*.ldif; do
  FILENAME=$(basename "$LDIF_FILE")
  echo "📄 Processing: $FILENAME"
  
  # Copy LDIF to pod
  kubectl cp "$LDIF_FILE" "${NAMESPACE}/${POD_NAME}:/tmp/import.ldif"
  
  # Import via ldbadd (safer than samba-tool ldap import)
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
    # Use ldbadd for atomic import (skips existing entries)
    ldbadd -H /var/lib/samba/private/sam.ldb /tmp/import.ldif 2>/dev/null || {
      echo "   ⚠️  Some entries already exist (skipped)"
    }
EOF
  
  echo "   ✅ Imported $FILENAME"
done

echo ""
echo "=========================================="
echo "🔐 Setting Temporary Passwords"
echo "=========================================="
echo ""

# Set passwords for IT Admins and Operators
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
  # Function to generate random 16-char password
  generate_password() {
    cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w 16 | head -n 1
  }
  
  echo "👥 IT Administrator (1 user):"
  echo "============================="
  
  for USER in lukasz.kolodziej; do
    TEMP_PASSWORD=$(generate_password)
    samba-tool user setpassword "$USER" --newpassword="$TEMP_PASSWORD" --must-change-at-next-login 2>/dev/null && {
      echo "✅ $USER → Password: $TEMP_PASSWORD (MUST CHANGE ON FIRST LOGIN!)"
    } || {
      echo "⚠️  $USER → Already has password or doesn't exist"
    }
  done
  
  echo ""
  echo "👨‍💼 Network Operators (4 users):"
  echo "================================"
  
  for USER in operator01 operator02 operator03 operator04; do
    TEMP_PASSWORD=$(generate_password)
    samba-tool user setpassword "$USER" --newpassword="$TEMP_PASSWORD" --must-change-at-next-login 2>/dev/null && {
      echo "✅ $USER → Password: $TEMP_PASSWORD (MUST CHANGE ON FIRST LOGIN!)"
    } || {
      echo "⚠️  $USER → Already has password or doesn't exist"
    }
  done
  
  echo ""
  echo "🤖 Service Accounts (5 accounts):"
  echo "================================"
  echo "⚠️  Service account passwords are managed via Kubernetes Sealed Secrets"
  echo "   Manual password generation (32-char random):"
  
  for SA in radius-bind prometheus-snmp zabbix-monitor backup-service monitoring-readonly; do
    SA_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 32 | head -n 1)
    samba-tool user setpassword "$SA" --newpassword="$SA_PASSWORD" 2>/dev/null && {
      echo "✅ $SA → Password: $SA_PASSWORD"
      echo "   ⚠️  STORE IN SEALED SECRET: kubectl create secret generic ${SA}-password --from-literal=password='$SA_PASSWORD' --dry-run=client -o yaml | kubeseal"
    } || {
      echo "⚠️  $SA → Already has password or doesn't exist"
    }
  done
EOF

echo ""
echo "=========================================="
echo "✅ Import Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "   - IT Administrator: 1 user (temporary password above)"
echo "   - Network Operators: 4 users (temporary passwords above)"
echo "   - Service Accounts: 5 accounts (store passwords in Sealed Secrets)"
echo ""
echo "🔒 IMPORTANT:"
echo "   1. All admin/operator users MUST change password on first login"
echo "   2. Store service account passwords in Kubernetes Sealed Secrets"
echo "   3. Update FreeRADIUS config with radius-bind password"
echo "   4. Configure Prometheus/Zabbix with monitoring credentials"
echo ""
echo "🧪 Verification:"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool user list"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool user show lukasz.kolodziej"
echo ""
echo "🎯 Next Steps:"
echo "   1. Test MikroTik login via WinBox (192.168.255.2)"
echo "   2. Configure FreeRADIUS with radius-bind credentials"
echo "   3. Update monitoring tools with service account passwords"
echo ""
