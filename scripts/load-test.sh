#!/bin/bash
# Simple load test to validate scalability and performance 📈
# Shows how the service handles concurrent requests

set -e

# Configuration
TARGET_URL="http://localhost:8080"
CONCURRENT_USERS=10
REQUESTS_PER_USER=50
TOTAL_REQUESTS=$((CONCURRENT_USERS * REQUESTS_PER_USER))

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service is available
check_service() {
    log_info "Checking if service is available at ${TARGET_URL}"
    
    if curl -s -f "${TARGET_URL}/read" > /dev/null; then
        log_info "✅ Service is healthy and ready for load testing"
    else
        log_error "❌ Service is not available. Please ensure it's running:"
        log_error "  kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80"
        exit 1
    fi
}

# Run load test
run_load_test() {
    log_info "🚀 Starting load test with ${CONCURRENT_USERS} concurrent users"
    log_info "📊 Each user will make ${REQUESTS_PER_USER} requests (${TOTAL_REQUESTS} total)"
    
    # Create temporary directory for results
    TEMP_DIR=$(mktemp -d)
    
    # Function to make requests
    make_requests() {
        local user_id=$1
        local success=0
        local errors=0
        
        for ((i=1; i<=REQUESTS_PER_USER; i++)); do
            # Alternate between read and write operations
            if [ $((i % 2)) -eq 0 ]; then
                if curl -s -f "${TARGET_URL}/read" > /dev/null 2>&1; then
                    ((success++))
                else
                    ((errors++))
                fi
            else
                if curl -s -f -X POST "${TARGET_URL}/write" > /dev/null 2>&1; then
                    ((success++))
                else
                    ((errors++))
                fi
            fi
        done
        
        echo "${success},${errors}" > "${TEMP_DIR}/user_${user_id}.result"
    }
    
    # Start timestamp
    START_TIME=$(date +%s)
    
    # Launch concurrent users
    for ((user=1; user<=CONCURRENT_USERS; user++)); do
        make_requests $user &
    done
    
    # Wait for all background jobs to complete
    wait
    
    # End timestamp
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Collect results
    total_success=0
    total_errors=0
    
    for result_file in "${TEMP_DIR}"/user_*.result; do
        if [ -f "$result_file" ]; then
            IFS=',' read -r success errors < "$result_file"
            total_success=$((total_success + success))
            total_errors=$((total_errors + errors))
        fi
    done
    
    # Calculate metrics
    requests_per_second=$(echo "scale=2; $total_success / $DURATION" | bc -l)
    success_rate=$(echo "scale=2; $total_success * 100 / $TOTAL_REQUESTS" | bc -l)
    
    # Display results
    echo
    log_info "📈 Load Test Results:"
    echo "  Duration: ${DURATION}s"
    echo "  Total Requests: ${TOTAL_REQUESTS}"
    echo "  Successful Requests: ${total_success}"
    echo "  Failed Requests: ${total_errors}"
    echo "  Success Rate: ${success_rate}%"
    echo "  Requests/Second: ${requests_per_second}"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    # Evaluation
    if [ "$total_errors" -eq 0 ] && [ $(echo "$requests_per_second > 10" | bc -l) -eq 1 ]; then
        log_info "🎉 Load test passed! Service is performing well under load"
    elif [ "$total_errors" -eq 0 ]; then
        log_warn "⚠️  Load test passed but performance could be improved"
    else
        log_error "❌ Load test failed with ${total_errors} errors"
        exit 1
    fi
}

# Check final counter value
check_final_state() {
    log_info "📊 Checking final counter state"
    
    final_count=$(curl -s "${TARGET_URL}/read" | jq -r '.value' 2>/dev/null || echo "unknown")
    expected_writes=$((CONCURRENT_USERS * REQUESTS_PER_USER / 2))
    
    echo "  Final counter value: ${final_count}"
    echo "  Expected writes: ~${expected_writes}"
    
    if [ "$final_count" != "unknown" ] && [ "$final_count" -gt 0 ]; then
        log_info "✅ Counter is working correctly"
    else
        log_warn "⚠️  Counter value seems incorrect"
    fi
}

# Main execution
main() {
    echo "🔥 tikky Load Test - Let's see what this bad boy can do!"
    echo
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed"
        exit 1
    fi
    
    # Run the test
    check_service
    run_load_test
    check_final_state
    
    echo
    log_info "🎯 Load test completed! Your service is ready for production traffic"
}

# Handle help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [TARGET_URL]"
    echo ""
    echo "Load test the tikky API service"
    echo ""
    echo "Arguments:"
    echo "  TARGET_URL    Base URL for the service (default: http://localhost:8080)"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 http://localhost:8080"
    exit 0
fi

# Override target URL if provided
if [ -n "$1" ]; then
    TARGET_URL="$1"
fi

main