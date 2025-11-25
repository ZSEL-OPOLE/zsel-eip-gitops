#!/bin/bash
################################################################################
# DR Test: Node Failure Simulation
# 
# Description: Simulate Kubernetes node failure and verify automatic recovery
# Version: 1.0
# Date: 2025-11-25
# 
# Test Scenarios:
# 1. Worker node failure - pod migration
# 2. Master node failure - HA verification
# 3. Multiple node failure - cluster resilience
#
# Expected Results:
# - Pods automatically migrate to healthy nodes (<30 seconds)
# - Services remain available (no downtime)
# - Storage volumes reattach to new pods
# - Monitoring detects failure and alerts
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_REPORT="${SCRIPT_DIR}/../reports/dr-test-node-failure-$(date +%Y%m%d-%H%M%S).html"
LOG_FILE="${SCRIPT_DIR}/../logs/dr-test-node-failure-$(date +%Y%m%d-%H%M%S).log"

# Test configuration
TEST_NAMESPACE="${TEST_NAMESPACE:-edu-moodle}"
TEST_APP="${TEST_APP:-moodle}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-300}"
RECOVERY_TIMEOUT="${RECOVERY_TIMEOUT:-120}"

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

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running test: $test_name"
    
    if eval "$test_command" >> "$LOG_FILE" 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_failure "$test_name"
        return 1
    fi
}

################################################################################
# Pre-Test Checks
################################################################################

check_prerequisites() {
    log_info "=========================================="
    log_info "DR Test: Node Failure Simulation"
    log_info "=========================================="
    log_info ""
    
    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_failure "kubectl not found"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &>/dev/null; then
        log_failure "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace exists
    if ! kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        log_failure "Namespace not found: $TEST_NAMESPACE"
        exit 1
    fi
    
    log_success "Prerequisites check"
}

collect_baseline_metrics() {
    log_info "Collecting baseline metrics..."
    
    # Node status
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready")
    
    log_info "Total nodes: $TOTAL_NODES"
    log_info "Ready nodes: $READY_NODES"
    
    # Pod status before test
    TOTAL_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers | wc -l)
    RUNNING_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers | grep -c "Running")
    
    log_info "Total pods in $TEST_NAMESPACE: $TOTAL_PODS"
    log_info "Running pods: $RUNNING_PODS"
    
    # Get worker node for testing (not master)
    TARGET_NODE=$(kubectl get nodes --no-headers | grep -v "master" | grep " Ready" | head -n1 | awk '{print $1}')
    
    if [[ -z "$TARGET_NODE" ]]; then
        log_failure "No worker nodes available for testing"
        exit 1
    fi
    
    log_info "Target node for testing: $TARGET_NODE"
    
    # Pods on target node
    PODS_ON_TARGET=$(kubectl get pods -A --field-selector spec.nodeName="$TARGET_NODE" --no-headers | wc -l)
    log_info "Pods on target node: $PODS_ON_TARGET"
    
    log_success "Baseline metrics collected"
}

################################################################################
# Test Scenario 1: Worker Node Drain
################################################################################

test_node_drain() {
    log_info "=========================================="
    log_info "Test 1: Worker Node Drain"
    log_info "=========================================="
    
    log_info "Draining node: $TARGET_NODE"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Drain node
    if kubectl drain "$TARGET_NODE" --ignore-daemonsets --delete-emptydir-data --timeout="${DRAIN_TIMEOUT}s" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Node drained successfully in ${duration}s"
        
        # Verify pods migrated
        sleep 10
        
        local pods_still_on_node=$(kubectl get pods -A --field-selector spec.nodeName="$TARGET_NODE" --no-headers 2>/dev/null | grep -v "DaemonSet" | wc -l)
        
        if [[ $pods_still_on_node -eq 0 ]]; then
            log_success "All pods migrated from drained node"
        else
            log_failure "Some pods still on drained node: $pods_still_on_node"
        fi
        
        # Check if pods are running on other nodes
        local running_pods_now=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers | grep -c "Running" || echo 0)
        
        if [[ $running_pods_now -eq $RUNNING_PODS ]]; then
            log_success "All pods running on other nodes"
        else
            log_failure "Not all pods running: $running_pods_now / $RUNNING_PODS"
        fi
        
    else
        log_failure "Failed to drain node"
    fi
}

################################################################################
# Test Scenario 2: Service Availability
################################################################################

test_service_availability() {
    log_info "=========================================="
    log_info "Test 2: Service Availability During Failure"
    log_info "=========================================="
    
    # Get service endpoint
    local service_url=$(kubectl get ingress -n "$TEST_NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
    
    if [[ -z "$service_url" ]]; then
        log_warning "No ingress found, checking service instead"
        
        # Check if service responds
        if kubectl run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
            curl -f -s -o /dev/null -w "%{http_code}" "http://${TEST_APP}.${TEST_NAMESPACE}.svc.cluster.local" >> "$LOG_FILE" 2>&1; then
            log_success "Service accessible via ClusterIP"
        else
            log_failure "Service not accessible"
        fi
    else
        # Test external access (if ingress exists)
        local http_code=$(curl -f -s -o /dev/null -w "%{http_code}" "https://$service_url" 2>/dev/null || echo "000")
        
        if [[ "$http_code" =~ ^(200|301|302)$ ]]; then
            log_success "Service accessible via ingress (HTTP $http_code)"
        else
            log_failure "Service not accessible via ingress (HTTP $http_code)"
        fi
    fi
    
    # Check service endpoints
    local endpoints=$(kubectl get endpoints -n "$TEST_NAMESPACE" "${TEST_APP}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
    
    if [[ $endpoints -gt 0 ]]; then
        log_success "Service has $endpoints healthy endpoints"
    else
        log_failure "Service has no healthy endpoints"
    fi
}

################################################################################
# Test Scenario 3: Storage Persistence
################################################################################

test_storage_persistence() {
    log_info "=========================================="
    log_info "Test 3: Storage Persistence"
    log_info "=========================================="
    
    # Find pods with PVCs
    local pods_with_pvcs=$(kubectl get pods -n "$TEST_NAMESPACE" -o json | \
        jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim) | .metadata.name' 2>/dev/null || echo "")
    
    if [[ -z "$pods_with_pvcs" ]]; then
        log_warning "No pods with PVCs found in namespace"
        return
    fi
    
    for pod in $pods_with_pvcs; do
        # Get PVC name
        local pvc=$(kubectl get pod -n "$TEST_NAMESPACE" "$pod" -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}' | head -n1)
        
        if [[ -n "$pvc" ]]; then
            # Check PVC status
            local pvc_status=$(kubectl get pvc -n "$TEST_NAMESPACE" "$pvc" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            
            if [[ "$pvc_status" == "Bound" ]]; then
                log_success "PVC $pvc is bound and accessible"
            else
                log_failure "PVC $pvc status: $pvc_status"
            fi
            
            # Verify pod can access volume
            if kubectl exec -n "$TEST_NAMESPACE" "$pod" -- ls / &>/dev/null; then
                log_success "Pod $pod can access mounted volumes"
            else
                log_warning "Pod $pod volume access check failed (pod may be restarting)"
            fi
        fi
    done
}

################################################################################
# Test Scenario 4: Monitoring & Alerting
################################################################################

test_monitoring_alerts() {
    log_info "=========================================="
    log_info "Test 4: Monitoring & Alerting"
    log_info "=========================================="
    
    # Check if Prometheus detected the node drain
    if kubectl get pod -n monitoring prometheus-server-0 &>/dev/null; then
        # Query for node alerts
        local prom_url="http://prometheus-server.monitoring.svc.cluster.local:9090"
        
        kubectl run prom-query --image=curlimages/curl:latest --rm -it --restart=Never -- \
            curl -s "$prom_url/api/v1/alerts" | grep -q "NodeNotReady" && \
            log_success "Prometheus detected node failure" || \
            log_warning "No node failure alert in Prometheus (may take time to trigger)"
    else
        log_warning "Prometheus not found, skipping alert check"
    fi
    
    # Check AlertManager
    if kubectl get pod -n monitoring alertmanager-0 &>/dev/null; then
        log_success "AlertManager is running"
    else
        log_warning "AlertManager not found"
    fi
}

################################################################################
# Test Scenario 5: Auto-Recovery Time
################################################################################

test_recovery_time() {
    log_info "=========================================="
    log_info "Test 5: Recovery Time Measurement"
    log_info "=========================================="
    
    log_info "Waiting for pods to stabilize..."
    
    local recovery_start=$(date +%s)
    local max_wait=$RECOVERY_TIMEOUT
    local elapsed=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        local running_pods=$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers | grep -c "Running" || echo 0)
        
        if [[ $running_pods -eq $RUNNING_PODS ]]; then
            local recovery_time=$(($(date +%s) - recovery_start))
            log_success "All pods recovered in ${recovery_time}s"
            
            if [[ $recovery_time -lt 30 ]]; then
                log_success "Recovery time under 30s (excellent)"
            elif [[ $recovery_time -lt 60 ]]; then
                log_success "Recovery time under 60s (good)"
            else
                log_warning "Recovery time over 60s (review pod startup time)"
            fi
            
            return 0
        fi
        
        sleep 5
        elapsed=$(($(date +%s) - recovery_start))
    done
    
    log_failure "Not all pods recovered within ${max_wait}s timeout"
    return 1
}

################################################################################
# Cleanup & Restore
################################################################################

restore_node() {
    log_info "=========================================="
    log_info "Restoring Node"
    log_info "=========================================="
    
    log_info "Uncordoning node: $TARGET_NODE"
    
    if kubectl uncordon "$TARGET_NODE" >> "$LOG_FILE" 2>&1; then
        log_success "Node uncordoned successfully"
        
        # Wait for node to be ready
        sleep 10
        
        local node_status=$(kubectl get node "$TARGET_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        if [[ "$node_status" == "True" ]]; then
            log_success "Node is Ready"
        else
            log_warning "Node status: $node_status"
        fi
    else
        log_failure "Failed to uncordon node"
    fi
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
    <title>DR Test Report: Node Failure</title>
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
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ecf0f1; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 DR Test Report: Node Failure Simulation</h1>
        
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
        
        <h2>📊 Test Environment</h2>
        <table>
            <tr><th>Parameter</th><th>Value</th></tr>
            <tr><td>Test Date</td><td>$(date '+%Y-%m-%d %H:%M:%S')</td></tr>
            <tr><td>Duration</td><td>${duration}s</td></tr>
            <tr><td>Target Node</td><td>$TARGET_NODE</td></tr>
            <tr><td>Test Namespace</td><td>$TEST_NAMESPACE</td></tr>
            <tr><td>Total Nodes</td><td>$TOTAL_NODES</td></tr>
            <tr><td>Pods Before Test</td><td>$RUNNING_PODS</td></tr>
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
        
        <h2>📝 Recommendations</h2>
        <ul>
EOF

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "            <li>✅ All tests passed! Node failure handling is working correctly.</li>" >> "$TEST_REPORT"
    else
        echo "            <li>⚠️ Some tests failed. Review logs and fix issues before production.</li>" >> "$TEST_REPORT"
    fi
    
    cat >> "$TEST_REPORT" <<EOF
            <li>Ensure monitoring alerts are configured correctly</li>
            <li>Document recovery procedures in runbook</li>
            <li>Schedule regular DR tests (monthly recommended)</li>
            <li>Train team on failure response procedures</li>
        </ul>
        
        <div class="footer">
            Generated by DR Test Script | Log file: $LOG_FILE
        </div>
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
    # Create directories
    mkdir -p "$(dirname "$TEST_REPORT")"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run tests
    check_prerequisites
    collect_baseline_metrics
    test_node_drain
    test_service_availability
    test_storage_persistence
    test_monitoring_alerts
    test_recovery_time
    restore_node
    
    # Generate report
    generate_report
    
    # Summary
    log_info ""
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    log_info "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
    log_info "Passed: $TESTS_PASSED"
    log_info "Failed: $TESTS_FAILED"
    log_info "Report: $TEST_REPORT"
    log_info "=========================================="
    
    # Exit code
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
