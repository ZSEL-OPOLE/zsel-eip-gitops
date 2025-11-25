#!/bin/bash
################################################################################
# FreeIPA User Import Script
# 
# Description: Bulk import 1030 users to FreeIPA with proper OU structure
# Version: 1.0
# Date: 2025-11-25
# 
# Users breakdown:
# - 900 students (33 classes)
# - 100 teachers (departments)
# - 30 staff (admin/IT/facility)
#
# Prerequisites:
# - FreeIPA server running and accessible
# - Admin credentials in environment (IPA_ADMIN_PASSWORD)
# - CSV file with user data (users.csv)
# - ipa-client installed on execution host
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="${1:-${SCRIPT_DIR}/../data/users.csv}"
LOG_FILE="${SCRIPT_DIR}/../logs/freeipa-import-$(date +%Y%m%d-%H%M%S).log"
ERROR_FILE="${SCRIPT_DIR}/../logs/freeipa-import-errors-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="${SCRIPT_DIR}/../reports/freeipa-import-report-$(date +%Y%m%d-%H%M%S).txt"

# FreeIPA Configuration
IPA_SERVER="${IPA_SERVER:-freeipa.zsel.opole.pl}"
IPA_DOMAIN="${IPA_DOMAIN:-zsel.opole.pl}"
IPA_REALM="${IPA_REALM:-ZSEL.OPOLE.PL}"

# Counters
TOTAL_USERS=0
SUCCESS_COUNT=0
ERROR_COUNT=0
SKIP_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_error() {
    log "${RED}ERROR${NC}" "$@"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$ERROR_FILE"
    ((ERROR_COUNT++))
}

log_success() {
    log "${GREEN}SUCCESS${NC}" "$@"
    ((SUCCESS_COUNT++))
}

log_warning() {
    log "${YELLOW}WARNING${NC}" "$@"
}

log_info() {
    log "${BLUE}INFO${NC}" "$@"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if ipa command exists
    if ! command -v ipa &> /dev/null; then
        log_error "ipa command not found. Install ipa-client: sudo dnf install ipa-client"
        exit 1
    fi
    
    # Check if CSV file exists
    if [[ ! -f "$CSV_FILE" ]]; then
        log_error "CSV file not found: $CSV_FILE"
        log_info "Expected format: username,firstname,lastname,email,class,role,department"
        exit 1
    fi
    
    # Check IPA admin password
    if [[ -z "${IPA_ADMIN_PASSWORD:-}" ]]; then
        log_error "IPA_ADMIN_PASSWORD environment variable not set"
        exit 1
    fi
    
    # Test FreeIPA connection
    if ! echo "$IPA_ADMIN_PASSWORD" | kinit admin@"$IPA_REALM" &>/dev/null; then
        log_error "Failed to authenticate to FreeIPA server: $IPA_SERVER"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

create_group_structure() {
    log_info "Creating group structure..."
    
    # Create main role groups
    local roles=("students" "teachers" "staff" "admin")
    for role in "${roles[@]}"; do
        if ipa group-show "role-${role}" &>/dev/null; then
            log_warning "Group role-${role} already exists, skipping"
        else
            ipa group-add "role-${role}" --desc="Role: ${role^}" || log_error "Failed to create group: role-${role}"
            log_success "Created group: role-${role}"
        fi
    done
    
    # Create class groups (33 classes)
    # Format: 1A, 1B, 1C, 1D, 2A, 2B, ..., 5D (4 classes per grade, 5 grades = 20)
    # Plus: 1Ti, 1Tii, 2Ti, 2Tii, 3Ti, 3Tii, 4Ti, 4Tii (8 technical classes)
    # Plus: 1Li, 1Lii, 2Li, 2Lii, 3Li (5 high school classes)
    # Total: 33 classes
    
    local classes=(
        "1A" "1B" "1C" "1D"
        "2A" "2B" "2C" "2D"
        "3A" "3B" "3C" "3D"
        "4A" "4B" "4C" "4D"
        "5A" "5B" "5C" "5D"
        "1Ti" "1Tii" "2Ti" "2Tii" "3Ti" "3Tii" "4Ti" "4Tii"
        "1Li" "1Lii" "2Li" "2Lii" "3Li"
    )
    
    for class in "${classes[@]}"; do
        if ipa group-show "class-${class}" &>/dev/null; then
            log_warning "Group class-${class} already exists, skipping"
        else
            ipa group-add "class-${class}" --desc="Klasa ${class}" || log_error "Failed to create group: class-${class}"
            log_success "Created group: class-${class}"
        fi
    done
    
    # Create department groups for teachers
    local departments=("matematyka" "informatyka" "fizyka" "chemia" "biologia" "język-polski" "język-angielski" "język-niemiecki" "historia" "geografia" "wf" "elektrotechnika" "elektronika" "automatyka" "telekomunikacja")
    
    for dept in "${departments[@]}"; do
        if ipa group-show "dept-${dept}" &>/dev/null; then
            log_warning "Group dept-${dept} already exists, skipping"
        else
            ipa group-add "dept-${dept}" --desc="Dział: ${dept}" || log_error "Failed to create group: dept-${dept}"
            log_success "Created group: dept-${dept}"
        fi
    done
    
    log_success "Group structure created"
}

generate_random_password() {
    # Generate 16-character password with upper, lower, digits, special chars
    local password=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c 16)
    echo "${password}$(openssl rand -base64 4 | tr -dc '0-9' | head -c 2)" # Ensure digits
}

import_users() {
    log_info "Starting user import from: $CSV_FILE"
    
    # Skip header line
    local line_num=0
    while IFS=, read -r username firstname lastname email class role department; do
        ((line_num++))
        
        # Skip header
        if [[ $line_num -eq 1 ]]; then
            continue
        fi
        
        ((TOTAL_USERS++))
        
        # Trim whitespace
        username=$(echo "$username" | xargs)
        firstname=$(echo "$firstname" | xargs)
        lastname=$(echo "$lastname" | xargs)
        email=$(echo "$email" | xargs)
        class=$(echo "$class" | xargs)
        role=$(echo "$role" | xargs)
        department=$(echo "$department" | xargs)
        
        log_info "Processing user $line_num: $username ($firstname $lastname)"
        
        # Validate required fields
        if [[ -z "$username" ]] || [[ -z "$firstname" ]] || [[ -z "$lastname" ]] || [[ -z "$role" ]]; then
            log_error "Line $line_num: Missing required fields (username, firstname, lastname, role)"
            continue
        fi
        
        # Check if user already exists
        if ipa user-show "$username" &>/dev/null; then
            log_warning "User $username already exists, skipping"
            ((SKIP_COUNT++))
            continue
        fi
        
        # Generate secure password
        local password=$(generate_random_password)
        
        # Create user
        if ipa user-add "$username" \
            --first="$firstname" \
            --last="$lastname" \
            --email="${email:-$username@$IPA_DOMAIN}" \
            --password <<<"$password" \
            --shell=/bin/bash \
            --homedir="/home/$username" &>/dev/null; then
            
            log_success "Created user: $username"
            
            # Save password to secure file (encrypted)
            echo "$username:$password" >> "${SCRIPT_DIR}/../data/user-passwords-$(date +%Y%m%d).txt"
            
            # Add to role group
            if ipa group-add-member "role-${role}" --users="$username" &>/dev/null; then
                log_info "  Added to group: role-${role}"
            else
                log_error "  Failed to add to group: role-${role}"
            fi
            
            # Add to class group (for students)
            if [[ "$role" == "student" ]] && [[ -n "$class" ]]; then
                if ipa group-add-member "class-${class}" --users="$username" &>/dev/null; then
                    log_info "  Added to group: class-${class}"
                else
                    log_error "  Failed to add to group: class-${class}"
                fi
            fi
            
            # Add to department group (for teachers)
            if [[ "$role" == "teacher" ]] && [[ -n "$department" ]]; then
                if ipa group-add-member "dept-${department}" --users="$username" &>/dev/null; then
                    log_info "  Added to group: dept-${department}"
                else
                    log_error "  Failed to add to group: dept-${department}"
                fi
            fi
            
        else
            log_error "Failed to create user: $username"
        fi
        
    done < "$CSV_FILE"
    
    log_info "User import completed"
}

generate_report() {
    log_info "Generating import report..."
    
    cat > "$REPORT_FILE" <<EOF
========================================
FreeIPA User Import Report
========================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Server: $IPA_SERVER
Domain: $IPA_DOMAIN

Summary:
--------
Total users processed: $TOTAL_USERS
Successfully created:  $SUCCESS_COUNT
Errors:               $ERROR_COUNT
Skipped (existing):   $SKIP_COUNT

Success rate: $(( SUCCESS_COUNT * 100 / TOTAL_USERS ))%

Files:
------
Log file:       $LOG_FILE
Error file:     $ERROR_FILE
Passwords file: ${SCRIPT_DIR}/../data/user-passwords-$(date +%Y%m%d).txt

Next Steps:
-----------
1. Encrypt passwords file:
   gpg --symmetric --cipher-algo AES256 ${SCRIPT_DIR}/../data/user-passwords-$(date +%Y%m%d).txt

2. Verify users in FreeIPA:
   ipa user-find --all

3. Test SSO login for sample users

4. Configure Keycloak integration:
   kubectl apply -f gitops/apps/core-keycloak/keycloak-ldap-integration.yaml

5. Distribute passwords to users (via secure channel)

========================================
EOF
    
    cat "$REPORT_FILE"
    log_success "Report saved to: $REPORT_FILE"
}

encrypt_passwords() {
    local password_file="${SCRIPT_DIR}/../data/user-passwords-$(date +%Y%m%d).txt"
    
    if [[ -f "$password_file" ]]; then
        log_info "Encrypting passwords file..."
        
        if gpg --symmetric --cipher-algo AES256 "$password_file"; then
            log_success "Passwords encrypted: ${password_file}.gpg"
            
            # Securely delete plaintext file
            shred -vfz -n 10 "$password_file"
            log_success "Plaintext passwords securely deleted"
        else
            log_error "Failed to encrypt passwords file"
        fi
    fi
}

################################################################################
# Main
################################################################################

main() {
    log_info "=========================================="
    log_info "FreeIPA User Import Script"
    log_info "=========================================="
    log_info "Server: $IPA_SERVER"
    log_info "Domain: $IPA_DOMAIN"
    log_info "CSV file: $CSV_FILE"
    log_info ""
    
    # Create directories
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$ERROR_FILE")"
    mkdir -p "$(dirname "$REPORT_FILE")"
    mkdir -p "${SCRIPT_DIR}/../data"
    
    # Run import process
    check_prerequisites
    create_group_structure
    import_users
    generate_report
    encrypt_passwords
    
    log_info ""
    log_info "=========================================="
    log_info "Import completed!"
    log_info "Success: $SUCCESS_COUNT / $TOTAL_USERS"
    log_info "Errors: $ERROR_COUNT"
    log_info "Skipped: $SKIP_COUNT"
    log_info "=========================================="
    
    # Exit code based on errors
    if [[ $ERROR_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
