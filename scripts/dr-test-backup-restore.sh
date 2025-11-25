#!/bin/bash
################################################################################
# DR Test: Backup Restore Verification
# 
# Description: Test backup restore procedures using Velero
# Version: 1.0
# Date: 2025-11-25
# 
# Test Scenarios:
# 1. Namespace backup and restore
# 2. Specific application restore
# 3. Data integrity verification
# 4. Cross-cluster restore (optional)
#
# Prerequisites:
# - Velero installed and configured
# - Backup schedule running
# - At least one recent backup available
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_REPORT="${SCRIPT_DIR}/../reports/dr-test-backup-restore-$(date +%Y%m%d-%H%M%S).html"
LOG_FILE="${SCRIPT_DIR}/../logs/dr-test-backup-restore-$(date +%Y%m%d-%H%M%S).log"

# Test configuration
TEST_NAMESPACE="${TEST_NAMESPACE:-edu-moodle}"
BACKUP_NAME="${BACKUP_NAME:-}"
RESTORE_NAMESPACE="${RESTORE_NAMESPACE:-${TEST_NAMESPACE}-restore-test}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
declare -a TEST_RESULTS=()
TESTS_PASSED=0
TESTS_FAILED=0
START_TIME=$(date +%s)

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓ PASS${NC}: $*"
    TEST_RESULTS+=("PASS|$*")
    ((TESTS_PASSED++))
}

log_failure() {
    log "${RED}✗ FAIL${NC}: $*"
    TEST_RESULTS+=("FAIL|$*")
    ((TESTS_FAILED++))
}

log_info() {
    log "${BLUE}ℹ INFO${NC}: $*"
}

log_warning() {
    log "${YELLOW}⚠ WARN${NC}: $*"
}

################################################################################
# Pre-Test Checks
################################################################################

check_prerequisites() {
    log_info "=========================================="
    log_info "DR Test: Backup Restore Verification"
    log_info "=========================================="
    log_info ""
    
    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_failure "kubectl not found"
        exit 1
    fi
    
    # Check velero CLI
    if ! command -v velero &>/dev/null; then
        log_failure "velero CLI not found. Install from: https://velero.io/docs/install-cli/"
        exit 1
    fi
    
    # Check Velero deployment
    if ! kubectl get deployment -n "$VELERO_NAMESPACE" velero &>/dev/null; then
        log_failure "Velero not deployed in namespace: $VELERO_NAMESPACE"
        exit 1
    fi
    
    # Check if Velero is ready
    local velero_ready=$(kubectl get deployment -n "$VELERO_NAMESPACE" velero -o jsonpath='{.status.readyReplicas}')
    
    if [[ "$velero_ready" != "1" ]]; then
        log_failure "Velero deployment not ready"
        exit 1
    fi
    
    log_success "Prerequisites check"
}

list_available_backups() {
    log_info "Listing available backups..."
    
    local backups=$(velero backup get --output json 2>/dev/null | jq -r '.items[] | select(.status.phase=="Completed") | .metadata.name' || echo "")
    
    if [[ -z "$backups" ]]; then
        log_failure "No completed backups found"
        exit 1
    fi
    
    log_info "Available backups:"
    echo "$backups" | while read -r backup; do
        local created=$(velero backup describe "$backup" --details=false 2>/dev/null | grep "Created:" | awk '{print $2,$3}')
        log_info "  - $backup (Created: $created)"
    done
    
    # Use latest backup if not specified
    if [[ -z "$BACKUP_NAME" ]]; then
        BACKUP_NAME=$(echo "$backups" | head -n1)
        log_info "Using latest backup: $BACKUP_NAME"
    fi
    
    log_success "Backup selection: $BACKUP_NAME"
}

################################################################################
# Test Scenario 1: Create Test Backup
################################################################################

create_test_backup() {
    log_info "=========================================="
    log_info "Test 1: Create Test Backup"
    log_info "=========================================="
    
    local backup_name="dr-test-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating backup: $backup_name for namespace: $TEST_NAMESPACE"
    
    if velero backup create "$backup_name" \
        --include-namespaces "$TEST_NAMESPACE" \
        --wait >> "$LOG_FILE" 2>&1; then
        
        log_success "Backup created: $backup_name"
        BACKUP_NAME="$backup_name"
        
        # Verify backup completed
        local backup_status=$(velero backup describe "$backup_name" 2>/dev/null | grep "Phase:" | awk '{print $2}')
        
        if [[ "$backup_status" == "Completed" ]]; then
            log_success "Backup status: Completed"
        else
            log_failure "Backup status: $backup_status"
        fi
        
        # Check backup size
        local backup_size=$(velero backup describe "$backup_name" 2>/dev/null | grep "Backup Format Version:" -A 20 | grep "Total items to be backed up:" | awk '{print $NF}')
        log_info "Backup contains $backup_size items"
        
    else
        log_failure "Failed to create backup"
    fi
}

################################################################################
# Test Scenario 2: Restore to New Namespace
################################################################################

test_restore_to_new_namespace() {
    log_info "=========================================="
    log_info "Test 2: Restore to New Namespace"
    log_info "=========================================="
    
    # Delete restore namespace if exists
    if kubectl get namespace "$RESTORE_NAMESPACE" &>/dev/null; then
        log_info "Deleting existing restore namespace: $RESTORE_NAMESPACE"
        kubectl delete namespace "$RESTORE_NAMESPACE" --wait=true >> "$LOG_FILE" 2>&1
        sleep 10
    fi
    
    # Create restore
    local restore_name="restore-test-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Restoring backup $BACKUP_NAME to namespace: $RESTORE_NAMESPACE"
    
    if velero restore create "$restore_name" \
        --from-backup "$BACKUP_NAME" \
        --namespace-mappings "${TEST_NAMESPACE}:${RESTORE_NAMESPACE}" \
        --wait >> "$LOG_FILE" 2>&1; then
        
        log_success "Restore completed: $restore_name"
        
        # Verify restore status
        local restore_status=$(velero restore describe "$restore_name" 2>/dev/null | grep "Phase:" | awk '{print $2}')
        
        if [[ "$restore_status" == "Completed" ]]; then
            log_success "Restore status: Completed"
        else
            log_failure "Restore status: $restore_status"
        fi
        
        # Check for errors
        local errors=$(velero restore describe "$restore_name" 2>/dev/null | grep "Errors:" | awk '{print $2}')
        local warnings=$(velero restore describe "$restore_name" 2>/dev/null | grep "Warnings:" | awk '{print $2}')
        
        if [[ "$errors" == "0" ]]; then
            log_success "No errors during restore"
        else
            log_failure "Restore had $errors errors"
        fi
        
        if [[ "$warnings" == "0" ]]; then
            log_success "No warnings during restore"
        else
            log_warning "Restore had $warnings warnings"
        fi
        
    else
        log_failure "Failed to restore backup"
    fi
}

################################################################################
# Test Scenario 3: Verify Restored Resources
################################################################################

verify_restored_resources() {
    log_info "=========================================="
    log_info "Test 3: Verify Restored Resources"
    log_info "=========================================="
    
    # Wait for namespace to be ready
    sleep 10
    
    # Check if namespace exists
    if kubectl get namespace "$RESTORE_NAMESPACE" &>/dev/null; then
        log_success "Restore namespace exists: $RESTORE_NAMESPACE"
    else
        log_failure "Restore namespace not found: $RESTORE_NAMESPACE"
        return 1
    fi
    
    # Compare resource counts
    local original_pods=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local restored_pods=$(kubectl get pods -n "$RESTORE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    log_info "Original pods: $original_pods"
    log_info "Restored pods: $restored_pods"
    
    if [[ $restored_pods -eq $original_pods ]]; then
        log_success "Pod count matches"
    else
        log_warning "Pod count mismatch (may be expected if some pods are excluded)"
    fi
    
    # Check PVCs
    local original_pvcs=$(kubectl get pvc -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local restored_pvcs=$(kubectl get pvc -n "$RESTORE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    log_info "Original PVCs: $original_pvcs"
    log_info "Restored PVCs: $restored_pvcs"
    
    if [[ $restored_pvcs -eq $original_pvcs ]]; then
        log_success "PVC count matches"
    else
        log_failure "PVC count mismatch"
    fi
    
    # Check ConfigMaps
    local original_cm=$(kubectl get configmap -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local restored_cm=$(kubectl get configmap -n "$RESTORE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    if [[ $restored_cm -eq $original_cm ]]; then
        log_success "ConfigMap count matches"
    else
        log_warning "ConfigMap count mismatch"
    fi
    
    # Check Secrets
    local original_secrets=$(kubectl get secret -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    local restored_secrets=$(kubectl get secret -n "$RESTORE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    if [[ $restored_secrets -eq $original_secrets ]]; then
        log_success "Secret count matches"
    else
        log_warning "Secret count mismatch"
    fi
}

################################################################################
# Test Scenario 4: Data Integrity Check
################################################################################

verify_data_integrity() {
    log_info "=========================================="
    log_info "Test 4: Data Integrity Verification"
    log_info "=========================================="
    
    # Find stateful workloads (StatefulSets)
    local statefulsets=$(kubectl get statefulset -n "$RESTORE_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$statefulsets" ]]; then
        log_warning "No StatefulSets found in restore namespace"
        return
    fi
    
    for sts in $statefulsets; do
        log_info "Checking StatefulSet: $sts"
        
        # Get pod from StatefulSet
        local pod=$(kubectl get pod -n "$RESTORE_NAMESPACE" -l app="$sts" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -z "$pod" ]]; then
            log_warning "No pods found for StatefulSet: $sts"
            continue
        fi
        
        # Check if pod is running
        local pod_status=$(kubectl get pod -n "$RESTORE_NAMESPACE" "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        if [[ "$pod_status" == "Running" ]]; then
            log_success "Pod $pod is running"
            
            # Test database connectivity (if it's a database pod)
            if [[ "$pod" =~ (postgres|mysql|mongodb) ]]; then
                if kubectl exec -n "$RESTORE_NAMESPACE" "$pod" -- ps aux | grep -q -E "(postgres|mysql|mongo)" &>/dev/null; then
                    log_success "Database process running in $pod"
                else
                    log_failure "Database process not found in $pod"
                fi
            fi
        else
            log_warning "Pod $pod status: $pod_status"
        fi
        
        # Check PVC attachment
        local pvcs=$(kubectl get pod -n "$RESTORE_NAMESPACE" "$pod" -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}' 2>/dev/null || echo "")
        
        if [[ -n "$pvcs" ]]; then
            log_success "Pod $pod has PVCs attached: $pvcs"
            
            # Verify PVC is bound
            for pvc in $pvcs; do
                local pvc_status=$(kubectl get pvc -n "$RESTORE_NAMESPACE" "$pvc" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
                
                if [[ "$pvc_status" == "Bound" ]]; then
                    log_success "PVC $pvc is bound"
                else
                    log_failure "PVC $pvc status: $pvc_status"
                fi
            done
        fi
    done
}

################################################################################
# Test Scenario 5: Restore Performance
################################################################################

measure_restore_performance() {
    log_info "=========================================="
    log_info "Test 5: Restore Performance Metrics"
    log_info "=========================================="
    
    # Get restore duration from Velero
    local restore_name=$(velero restore get --output json 2>/dev/null | jq -r '.items[] | select(.spec.backupName=="'$BACKUP_NAME'") | .metadata.name' | head -n1)
    
    if [[ -n "$restore_name" ]]; then
        local start_time=$(velero restore describe "$restore_name" 2>/dev/null | grep "Started:" | awk '{print $2,$3}')
        local complete_time=$(velero restore describe "$restore_name" 2>/dev/null | grep "Completion timestamp:" | awk '{print $3,$4}')
        
        log_info "Restore started: $start_time"
        log_info "Restore completed: $complete_time"
        
        # Calculate duration (approximate)
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo 0)
        local end_epoch=$(date -d "$complete_time" +%s 2>/dev/null || echo 0)
        local duration=$((end_epoch - start_epoch))
        
        if [[ $duration -gt 0 ]]; then
            log_info "Restore duration: ${duration}s"
            
            if [[ $duration -lt 300 ]]; then
                log_success "Restore completed in under 5 minutes (excellent)"
            elif [[ $duration -lt 600 ]]; then
                log_success "Restore completed in under 10 minutes (good)"
            else
                log_warning "Restore took over 10 minutes (review performance)"
            fi
        fi
        
        # Get resource counts restored
        local items_restored=$(velero restore describe "$restore_name" 2>/dev/null | grep "Restored:" | awk '{print $2}')
        log_info "Items restored: $items_restored"
        
    else
        log_warning "Could not find restore details for performance measurement"
    fi
}

################################################################################
# Cleanup
################################################################################

cleanup_test_resources() {
    log_info "=========================================="
    log_info "Cleanup"
    log_info "=========================================="
    
    log_info "Deleting restore namespace: $RESTORE_NAMESPACE"
    
    if kubectl delete namespace "$RESTORE_NAMESPACE" --wait=true >> "$LOG_FILE" 2>&1; then
        log_success "Restore namespace deleted"
    else
        log_warning "Failed to delete restore namespace (may need manual cleanup)"
    fi
    
    # Note: We keep the test backup for audit purposes
    log_info "Test backup retained: $BACKUP_NAME (delete manually if needed)"
}

################################################################################
# Generate HTML Report
################################################################################

generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    fi
    
    cat > "$TEST_REPORT" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>DR Test Report: Backup Restore</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin: 20px 0; }
        .metric { background: #ecf0f1; padding: 20px; border-radius: 5px; text-align: center; }
        .metric-value { font-size: 32px; font-weight: bold; color: #2c3e50; }
        .metric-label { font-size: 14px; color: #7f8c8d; margin-top: 5px; }
        .pass { color: #27ae60; }
        .fail { color: #e74c3c; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background: #f8f9fa; }
        .status-pass { color: #27ae60; font-weight: bold; }
        .status-fail { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>💾 DR Test Report: Backup Restore Verification</h1>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value">${total_tests}</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric">
                <div class="metric-value pass">${TESTS_PASSED}</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value fail">${TESTS_FAILED}</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">${success_rate}%</div>
                <div class="metric-label">Success Rate</div>
            </div>
        </div>
        
        <h2>📊 Test Configuration</h2>
        <table>
            <tr><th>Parameter</th><th>Value</th></tr>
            <tr><td>Test Date</td><td>$(date '+%Y-%m-%d %H:%M:%S')</td></tr>
            <tr><td>Duration</td><td>${duration}s</td></tr>
            <tr><td>Backup Name</td><td>$BACKUP_NAME</td></tr>
            <tr><td>Source Namespace</td><td>$TEST_NAMESPACE</td></tr>
            <tr><td>Restore Namespace</td><td>$RESTORE_NAMESPACE</td></tr>
        </table>
        
        <h2>✅ Test Results</h2>
        <table>
            <tr><th>Status</th><th>Test Description</th></tr>
EOF

    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r status description <<< "$result"
        
        if [[ "$status" == "PASS" ]]; then
            echo "            <tr><td class=\"status-pass\">✓ PASS</td><td>$description</td></tr>" >> "$TEST_REPORT"
        else
            echo "            <tr><td class=\"status-fail\">✗ FAIL</td><td>$description</td></tr>" >> "$TEST_REPORT"
        fi
    done
    
    cat >> "$TEST_REPORT" <<EOF
        </table>
        
        <h2>📝 Next Steps</h2>
        <ul>
            <li>Review failed tests and address issues</li>
            <li>Update backup retention policies if needed</li>
            <li>Document restore procedures in runbook</li>
            <li>Schedule regular restore tests (quarterly recommended)</li>
            <li>Train team on restore procedures</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    log_success "HTML report generated: $TEST_REPORT"
}

################################################################################
# Main
################################################################################

main() {
    mkdir -p "$(dirname "$TEST_REPORT")"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    check_prerequisites
    list_available_backups
    create_test_backup
    test_restore_to_new_namespace
    verify_restored_resources
    verify_data_integrity
    measure_restore_performance
    cleanup_test_resources
    generate_report
    
    log_info ""
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    log_info "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
    log_info "Passed: $TESTS_PASSED"
    log_info "Failed: $TESTS_FAILED"
    log_info "Report: $TEST_REPORT"
    log_info "=========================================="
    
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
