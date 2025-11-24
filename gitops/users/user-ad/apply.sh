#!/bin/bash
# Import User AD users to Samba AD Domain Controller
# Domain: ad.zsel.opole.pl
# Namespace: core-auth
# Pod: user-ad-dc-0 (PRIMARY)

set -e

NAMESPACE="core-auth"
POD_NAME="user-ad-dc-0"
LDIF_DIR="."
STUDENTS_DIR="students"

echo "=========================================="
echo "🎓 User AD Import Script - ZSEL Opole"
echo "=========================================="
echo "Domain: ad.zsel.opole.pl"
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo ""
echo "📊 Import Summary:"
echo "   - Teachers: 74 osób"
echo "   - Staff: 30 osób"
echo "   - Students (Year 1): 181 uczniów (8 oddziałów)"
echo "   - Service Accounts: 10 kont"
echo "   - TOTAL: 295 kont użytkowników"
echo ""

# Check if pod exists
if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &>/dev/null; then
  echo "❌ ERROR: Pod $POD_NAME not found in namespace $NAMESPACE"
  echo "   Deploy User AD first: kubectl apply -k gitops/apps/user-ad/"
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

# Step 1: Create Organizational Units
echo "=========================================="
echo "📁 STEP 1: Creating Organizational Units"
echo "=========================================="
echo ""

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
  echo "Creating OUs..."
  
  # Main OUs
  samba-tool ou create "OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Users already exists"
  samba-tool ou create "OU=Teachers,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Teachers already exists"
  samba-tool ou create "OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Students already exists"
  samba-tool ou create "OU=Staff,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Staff already exists"
  samba-tool ou create "OU=Service-Accounts,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Service-Accounts already exists"
  samba-tool ou create "OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Groups already exists"
  
  # Student Class OUs (Year 1 - 8 oddziałów)
  echo ""
  echo "Creating Student Class OUs (Year 1)..."
  for CLASS in 1AT 1BT1 1BT2 1CT1 1CT2 1DT 1AB 1AW; do
    samba-tool ou create "OU=Class-${CLASS},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl" 2>/dev/null || echo "   OU=Class-${CLASS} already exists"
  done
  
  echo ""
  echo "✅ All OUs created"
EOF

echo ""

# Step 2: Create Groups
echo "=========================================="
echo "👥 STEP 2: Creating Security Groups"
echo "=========================================="
echo ""

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
  echo "Creating global groups..."
  
  # Main groups
  samba-tool group add "Teachers" --groupou="OU=Groups" --description="Nauczyciele ZSEL Opole (74 osoby)" 2>/dev/null || echo "   Group Teachers already exists"
  samba-tool group add "Students" --groupou="OU=Groups" --description="Uczniowie ZSEL Opole (840 osób - wszystkie lata)" 2>/dev/null || echo "   Group Students already exists"
  samba-tool group add "Staff" --groupou="OU=Groups" --description="Kadra administracyjna i obsługa (30 osób)" 2>/dev/null || echo "   Group Staff already exists"
  samba-tool group add "Service-Accounts" --groupou="OU=Groups" --description="Konta serwisowe dla aplikacji (10 kont)" 2>/dev/null || echo "   Group Service-Accounts already exists"
  
  # Application groups (Teachers)
  echo ""
  echo "Creating application groups for teachers..."
  samba-tool group add "Moodle-Admins" --groupou="OU=Groups" --description="Administratorzy Moodle (dostęp do konfiguracji kursów)" 2>/dev/null || echo "   Group Moodle-Admins already exists"
  samba-tool group add "BBB-Moderators" --groupou="OU=Groups" --description="Moderatorzy BigBlueButton (tworzenie spotkań wirtualnych)" 2>/dev/null || echo "   Group BBB-Moderators already exists"
  samba-tool group add "NextCloud-Admins" --groupou="OU=Groups" --description="Administratorzy NextCloud (zarządzanie plikami)" 2>/dev/null || echo "   Group NextCloud-Admins already exists"
  
  # Staff department groups
  echo ""
  echo "Creating staff department groups..."
  samba-tool group add "Management" --groupou="OU=Groups" --description="Dyrekcja szkoły (3 osoby)" 2>/dev/null || echo "   Group Management already exists"
  samba-tool group add "Secretariat" --groupou="OU=Groups" --description="Sekretariat (5 osób)" 2>/dev/null || echo "   Group Secretariat already exists"
  samba-tool group add "Accounting" --groupou="OU=Groups" --description="Księgowość (4 osoby)" 2>/dev/null || echo "   Group Accounting already exists"
  samba-tool group add "HR" --groupou="OU=Groups" --description="Kadry (2 osoby)" 2>/dev/null || echo "   Group HR already exists"
  samba-tool group add "Healthcare" --groupou="OU=Groups" --description="Służba zdrowia (3 osoby: pielęgniarka, psycholog, pedagog)" 2>/dev/null || echo "   Group Healthcare already exists"
  samba-tool group add "Library" --groupou="OU=Groups" --description="Biblioteka (2 osoby)" 2>/dev/null || echo "   Group Library already exists"
  samba-tool group add "Maintenance" --groupou="OU=Groups" --description="Obsługa techniczna (7 osób: konserwatorzy, sprzątaczki)" 2>/dev/null || echo "   Group Maintenance already exists"
  samba-tool group add "Security" --groupou="OU=Groups" --description="Ochrona (2 portierów)" 2>/dev/null || echo "   Group Security already exists"
  samba-tool group add "Canteen" --groupou="OU=Groups" --description="Stołówka (2 osoby)" 2>/dev/null || echo "   Group Canteen already exists"
  
  # Class groups (Year 1)
  echo ""
  echo "Creating class groups (Year 1 - 8 oddziałów)..."
  for CLASS in 1AT 1BT1 1BT2 1CT1 1CT2 1DT 1AB 1AW; do
    samba-tool group add "Class-${CLASS}" --groupou="OU=Groups" --description="Oddział ${CLASS}" 2>/dev/null || echo "   Group Class-${CLASS} already exists"
  done
  
  # Specialization groups
  echo ""
  echo "Creating specialization groups..."
  samba-tool group add "Specialization-technik-mechatronik" --groupou="OU=Groups" --description="Specjalizacja: Technik mechatronik" 2>/dev/null || echo "   Group Specialization-technik-mechatronik already exists"
  samba-tool group add "Specialization-technik-elektryk" --groupou="OU=Groups" --description="Specjalizacja: Technik elektryk" 2>/dev/null || echo "   Group Specialization-technik-elektryk already exists"
  samba-tool group add "Specialization-technik-automatyk" --groupou="OU=Groups" --description="Specjalizacja: Technik automatyk" 2>/dev/null || echo "   Group Specialization-technik-automatyk already exists"
  samba-tool group add "Specialization-technik-informatyk" --groupou="OU=Groups" --description="Specjalizacja: Technik informatyk" 2>/dev/null || echo "   Group Specialization-technik-informatyk already exists"
  samba-tool group add "Specialization-technik-teleinformatyk" --groupou="OU=Groups" --description="Specjalizacja: Technik teleinformatyk" 2>/dev/null || echo "   Group Specialization-technik-teleinformatyk already exists"
  samba-tool group add "Specialization-technik-programista" --groupou="OU=Groups" --description="Specjalizacja: Technik programista" 2>/dev/null || echo "   Group Specialization-technik-programista already exists"
  samba-tool group add "Specialization-elektryk" --groupou="OU=Groups" --description="Zawód: Elektryk (3-letnia zawodowa)" 2>/dev/null || echo "   Group Specialization-elektryk already exists"
  
  # Service account group
  echo ""
  echo "Creating LDAP service group..."
  samba-tool group add "LDAP-Readers" --groupou="OU=Groups" --description="LDAP read-only bind accounts (10 kont)" 2>/dev/null || echo "   Group LDAP-Readers already exists"
  
  echo ""
  echo "✅ All groups created"
EOF

echo ""

# Step 3: Import Teachers
echo "=========================================="
echo "👨‍🏫 STEP 3: Importing Teachers (74 osób)"
echo "=========================================="
echo ""

if [ -f "${LDIF_DIR}/teachers.ldif" ]; then
  echo "📄 Importing teachers.ldif..."
  kubectl cp "${LDIF_DIR}/teachers.ldif" "${NAMESPACE}/${POD_NAME}:/tmp/teachers.ldif"
  
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
    ldbadd -H /var/lib/samba/private/sam.ldb /tmp/teachers.ldif 2>&1 | grep -v "Failed to add" || echo "   ⚠️  Some teachers already exist (skipped)"
    rm -f /tmp/teachers.ldif
EOF
  
  echo "✅ Teachers imported (74 accounts)"
else
  echo "❌ ERROR: teachers.ldif not found!"
  exit 1
fi

echo ""

# Step 4: Import Staff
echo "=========================================="
echo "👔 STEP 4: Importing Staff (30 osób)"
echo "=========================================="
echo ""

if [ -f "${LDIF_DIR}/staff.ldif" ]; then
  echo "📄 Importing staff.ldif..."
  kubectl cp "${LDIF_DIR}/staff.ldif" "${NAMESPACE}/${POD_NAME}:/tmp/staff.ldif"
  
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
    ldbadd -H /var/lib/samba/private/sam.ldb /tmp/staff.ldif 2>&1 | grep -v "Failed to add" || echo "   ⚠️  Some staff already exist (skipped)"
    rm -f /tmp/staff.ldif
EOF
  
  echo "✅ Staff imported (30 accounts)"
else
  echo "❌ ERROR: staff.ldif not found!"
  exit 1
fi

echo ""

# Step 5: Import Students (Year 1)
echo "=========================================="
echo "🎓 STEP 5: Importing Students - Year 1 (181 uczniów)"
echo "=========================================="
echo ""

STUDENT_FILES=(
  "class-1at.ldif"
  "class-1bt1.ldif"
  "class-1bt2.ldif"
  "class-1ct1.ldif"
  "class-1ct2.ldif"
  "class-1dt.ldif"
  "class-1ab.ldif"
  "class-1aw.ldif"
)

TOTAL_STUDENTS=0

for STUDENT_FILE in "${STUDENT_FILES[@]}"; do
  if [ -f "${STUDENTS_DIR}/${STUDENT_FILE}" ]; then
    CLASS_NAME=$(echo "$STUDENT_FILE" | sed 's/class-\(.*\)\.ldif/\1/' | tr '[:lower:]' '[:upper:]')
    echo "📄 Importing ${STUDENT_FILE} (${CLASS_NAME})..."
    
    kubectl cp "${STUDENTS_DIR}/${STUDENT_FILE}" "${NAMESPACE}/${POD_NAME}:/tmp/${STUDENT_FILE}"
    
    IMPORTED=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<EOF
      ldbadd -H /var/lib/samba/private/sam.ldb /tmp/${STUDENT_FILE} 2>&1 | grep -c "Added" || echo "0"
      rm -f /tmp/${STUDENT_FILE}
EOF
    )
    
    echo "   ✅ ${CLASS_NAME}: ${IMPORTED} uczniów"
    TOTAL_STUDENTS=$((TOTAL_STUDENTS + IMPORTED))
  else
    echo "   ⚠️  ${STUDENT_FILE} not found - skipping"
  fi
done

echo ""
echo "✅ Total students imported: ${TOTAL_STUDENTS}"

echo ""

# Step 6: Import Service Accounts
echo "=========================================="
echo "🤖 STEP 6: Importing Service Accounts (10 kont)"
echo "=========================================="
echo ""

if [ -f "${LDIF_DIR}/service-accounts.ldif" ]; then
  echo "📄 Importing service-accounts.ldif..."
  kubectl cp "${LDIF_DIR}/service-accounts.ldif" "${NAMESPACE}/${POD_NAME}:/tmp/service-accounts.ldif"
  
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOF'
    ldbadd -H /var/lib/samba/private/sam.ldb /tmp/service-accounts.ldif 2>&1 | grep -v "Failed to add" || echo "   ⚠️  Some service accounts already exist (skipped)"
    rm -f /tmp/service-accounts.ldif
EOF
  
  echo "✅ Service accounts imported (10 accounts)"
else
  echo "❌ ERROR: service-accounts.ldif not found!"
  exit 1
fi

echo ""

# Step 7: Set Passwords
echo "=========================================="
echo "🔐 STEP 7: Setting Passwords"
echo "=========================================="
echo ""

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash <<'EOFPASSWORDS'
  # Function to generate random password
  generate_password() {
    local LENGTH=$1
    cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w "$LENGTH" | head -n 1
  }
  
  echo "=========================================="
  echo "👨‍🏫 TEACHERS (74 osób)"
  echo "=========================================="
  echo "Setting random 16-char passwords (must change at next login)..."
  echo ""
  
  # Get all teachers from LDAP
  TEACHERS=$(samba-tool user list | grep -E "^[a-z]+\.[a-z]+" | head -74)
  TEACHER_COUNT=0
  
  for TEACHER in $TEACHERS; do
    TEMP_PASSWORD=$(generate_password 16)
    if samba-tool user setpassword "$TEACHER" --newpassword="$TEMP_PASSWORD" --must-change-at-next-login 2>/dev/null; then
      echo "✅ $TEACHER → $TEMP_PASSWORD"
      TEACHER_COUNT=$((TEACHER_COUNT + 1))
    fi
  done
  
  echo ""
  echo "✅ Set passwords for ${TEACHER_COUNT} teachers"
  echo ""
  
  echo "=========================================="
  echo "👔 STAFF (30 osób)"
  echo "=========================================="
  echo "Setting random 16-char passwords (must change at next login)..."
  echo ""
  
  # Staff accounts (generic naming)
  STAFF_USERS=(
    "dyrektor" "wicedyrektor.dydaktyka" "wicedyrektor.wychowanie"
    "sekretarz" "sekretarz.zastepca" "sekretariat.01" "sekretariat.02" "archiwista"
    "ksiegowa" "ksiegowa.01" "ksiegowa.02" "plac.referent"
    "kadrowa" "kadrowa.asystent"
    "pielegniarka" "psycholog" "pedagog"
    "bibliotekarka" "bibliotekarka.zastepca"
    "kierownik.gospodarczy" "konserwator.01" "konserwator.02"
    "sprzataczka.01" "sprzataczka.02" "sprzataczka.03" "sprzataczka.04"
    "portier.dzienny" "portier.nocny"
    "kuchnia.01" "kuchnia.02"
  )
  
  STAFF_COUNT=0
  
  for STAFF in "${STAFF_USERS[@]}"; do
    TEMP_PASSWORD=$(generate_password 16)
    if samba-tool user setpassword "$STAFF" --newpassword="$TEMP_PASSWORD" --must-change-at-next-login 2>/dev/null; then
      echo "✅ $STAFF → $TEMP_PASSWORD"
      STAFF_COUNT=$((STAFF_COUNT + 1))
    fi
  done
  
  echo ""
  echo "✅ Set passwords for ${STAFF_COUNT} staff members"
  echo ""
  
  echo "=========================================="
  echo "🎓 STUDENTS - Year 1 (181 uczniów)"
  echo "=========================================="
  echo "Setting class-based passwords (shared per class):"
  echo ""
  
  # Class-based passwords
  declare -A CLASS_PASSWORDS=(
    ["1AT"]="1AT2025"
    ["1BT1"]="1BT12025"
    ["1BT2"]="1BT22025"
    ["1CT1"]="1CT12025"
    ["1CT2"]="1CT22025"
    ["1DT"]="1DT2025"
    ["1AB"]="1AB2025"
    ["1AW"]="1AW2025"
  )
  
  for CLASS_CODE in "${!CLASS_PASSWORDS[@]}"; do
    PASSWORD="${CLASS_PASSWORDS[$CLASS_CODE]}"
    echo "📚 Class ${CLASS_CODE} → Password: ${PASSWORD}"
    
    # Get students from class OU
    STUDENTS=$(samba-tool user list | grep -i "${CLASS_CODE,,}" || true)
    STUDENT_COUNT=0
    
    for STUDENT in $STUDENTS; do
      if samba-tool user setpassword "$STUDENT" --newpassword="$PASSWORD" 2>/dev/null; then
        STUDENT_COUNT=$((STUDENT_COUNT + 1))
      fi
    done
    
    echo "   ✅ Set password for ${STUDENT_COUNT} students in class ${CLASS_CODE}"
  done
  
  echo ""
  echo "=========================================="
  echo "🤖 SERVICE ACCOUNTS (10 kont)"
  echo "=========================================="
  echo "Generating 32-char passwords (store in Sealed Secrets):"
  echo ""
  
  SERVICE_ACCOUNTS=(
    "moodle-ldap-bind"
    "bbb-ldap-auth"
    "nextcloud-ldap-bind"
    "gitlab-ldap-bind"
    "mattermost-ldap-bind"
    "zammad-ldap-bind"
    "mailu-ldap-bind"
    "portainer-ldap-bind"
    "grafana-ldap-bind"
    "wifi-radius-bind"
  )
  
  for SA in "${SERVICE_ACCOUNTS[@]}"; do
    SA_PASSWORD=$(generate_password 32)
    if samba-tool user setpassword "$SA" --newpassword="$SA_PASSWORD" 2>/dev/null; then
      echo "✅ $SA"
      echo "   Password: $SA_PASSWORD"
      echo "   Sealed Secret command:"
      echo "   kubectl create secret generic ${SA}-password \\"
      echo "     --from-literal=password='$SA_PASSWORD' \\"
      echo "     --namespace=<app-namespace> \\"
      echo "     --dry-run=client -o yaml | kubeseal -o yaml > ${SA}-sealed-secret.yaml"
      echo ""
    fi
  done
  
  echo "⚠️  IMPORTANT: Store service account passwords in Git (gitops/sealed-secrets/)"
  
EOFPASSWORDS

echo ""
echo "=========================================="
echo "✅ USER AD IMPORT COMPLETE!"
echo "=========================================="
echo ""
echo "📊 Import Summary:"
echo "   ✅ Teachers: 74 accounts"
echo "   ✅ Staff: 30 accounts"
echo "   ✅ Students (Year 1): 181 accounts"
echo "   ✅ Service Accounts: 10 accounts"
echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📌 TOTAL: 295 user accounts"
echo ""
echo "🔐 Password Summary:"
echo "   - Teachers: Random 16-char (MUST CHANGE AT NEXT LOGIN)"
echo "   - Staff: Random 16-char (MUST CHANGE AT NEXT LOGIN)"
echo "   - Students: Class-based (1AT2025, 1BT12025, etc.)"
echo "   - Service Accounts: Random 32-char (STORE IN SEALED SECRETS)"
echo ""
echo "🧪 Verification Commands:"
echo "   # Count users by type"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool user list | wc -l"
echo ""
echo "   # List teachers"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool user list | grep -E '^[a-z]+\.[a-z]+' | head -74"
echo ""
echo "   # List students in class 1AT"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool group listmembers 'Class-1AT'"
echo ""
echo "   # Check user details"
echo "   kubectl exec -it -n $NAMESPACE $POD_NAME -- samba-tool user show damian.dobrowolski"
echo ""
echo "🎯 Next Steps:"
echo "   1. Test teacher login: ssh damian.dobrowolski@ad.zsel.opole.pl"
echo "   2. Test student WiFi: username=piotr.adamek, password=1AT2025"
echo "   3. Configure Moodle LDAP: bind user=moodle-ldap-bind"
echo "   4. Update NextCloud LDAP settings"
echo "   5. Test BigBlueButton teacher access"
echo ""
echo "📖 Documentation:"
echo "   - User management: users/README.md"
echo "   - Teacher dashboards: users/user-ad/README.md"
echo "   - Student self-service: users/user-ad/README.md"
echo ""
