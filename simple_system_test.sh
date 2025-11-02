#!/bin/bash

# simple_system_test.sh
# Simple and robust test for Blue-Green Failover System

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
NGINX_URL="http://localhost:8090"
BLUE_URL="http://localhost:8081" 
GREEN_URL="http://localhost:8082"

echo "================================================"
print_info "BLUE-GREEN FAILOVER SYSTEM TEST"
print_info "Starting at: $(date)"
echo "================================================"
echo ""

# Function to check service status
check_services() {
    print_info "1. Checking Docker services..."
    if docker-compose ps | grep -q "Up"; then
        print_success "All services are running"
    else
        print_error "Some services are not running"
        docker-compose ps
        exit 1
    fi
    echo ""
}

# Function to test basic endpoints
test_endpoints() {
    print_info "2. Testing basic endpoints..."
    
    # Test root endpoint
    if curl -s --connect-timeout 5 "$NGINX_URL/" | grep -q "service"; then
        print_success "✓ Root endpoint working"
    else
        print_error "✗ Root endpoint failed"
    fi
    
    # Test version endpoint
    if curl -s --connect-timeout 5 "$NGINX_URL/version" | grep -q "version"; then
        print_success "✓ Version endpoint working"
    else
        print_error "✗ Version endpoint failed"
    fi
    
    # Test healthz endpoint
    if curl -s --connect-timeout 5 "$NGINX_URL/healthz" | grep -q "healthy"; then
        print_success "✓ Healthz endpoint working"
    else
        print_error "✗ Healthz endpoint failed"
    fi
    echo ""
}

# Function to test direct services
test_direct_services() {
    print_info "3. Testing direct service access..."
    
    # Test blue service
    if curl -s --connect-timeout 5 "$BLUE_URL/version" | grep -q "blue"; then
        print_success "✓ Blue service accessible"
    else
        print_error "✗ Blue service failed"
    fi
    
    # Test green service
    if curl -s --connect-timeout 5 "$GREEN_URL/version" | grep -q "green"; then
        print_success "✓ Green service accessible"
    else
        print_error "✗ Green service failed"
    fi
    echo ""
}

# Function to test chaos endpoints
test_chaos_endpoints() {
    print_info "4. Testing chaos endpoints..."
    
    # Test blue chaos
    if curl -s -X POST --connect-timeout 5 "$BLUE_URL/chaos/start" | grep -q "chaos_started"; then
        print_success "✓ Blue chaos start working"
        sleep 1
        curl -s -X POST "$BLUE_URL/chaos/stop" > /dev/null
        print_success "✓ Blue chaos stop working"
    else
        print_error "✗ Blue chaos endpoints failed"
    fi
    
    # Test green chaos
    if curl -s -X POST --connect-timeout 5 "$GREEN_URL/chaos/start" | grep -q "chaos_started"; then
        print_success "✓ Green chaos start working"
        sleep 1
        curl -s -X POST "$GREEN_URL/chaos/stop" > /dev/null
        print_success "✓ Green chaos stop working"
    else
        print_error "✗ Green chaos endpoints failed"
    fi
    echo ""
}

# Function to test failover detection
test_failover() {
    print_info "5. Testing failover detection..."
    
    # Get current alert count
    CURRENT_ALERTS=$(docker-compose logs alert_watcher 2>/dev/null | grep "FAILOVER alert sent to Slack" | wc -l)
    print_info "Current failover alerts: $CURRENT_ALERTS"
    
    print_info "Starting chaos on blue service..."
    curl -s -X POST "$BLUE_URL/chaos/start" > /dev/null
    
    print_info "Generating traffic (10 requests)..."
    for i in {1..10}; do
        curl -s "$NGINX_URL/version" > /dev/null
        sleep 0.5
        echo -n "."
    done
    echo ""
    
    print_info "Stopping chaos..."
    curl -s -X POST "$BLUE_URL/chaos/stop" > /dev/null
    
    print_info "Waiting for alert processing..."
    sleep 5
    
    # Check for new alerts
    NEW_ALERTS=$(docker-compose logs alert_watcher 2>/dev/null | grep "FAILOVER alert sent to Slack" | wc -l)
    
    if [ "$NEW_ALERTS" -gt "$CURRENT_ALERTS" ]; then
        print_success "✓ Failover detection WORKING - new alerts detected"
    else
        print_warning "⚠ No new failover alerts detected"
    fi
    echo ""
}

# Function to test error rate alert
test_error_rate() {
    print_info "6. Testing error rate alert..."
    
    # Get current error rate alert count
    CURRENT_ERROR_ALERTS=$(docker-compose logs alert_watcher 2>/dev/null | grep "ERROR_RATE alert sent to Slack" | wc -l)
    print_info "Current error rate alerts: $CURRENT_ERROR_ALERTS"
    
    print_info "Starting chaos on both services..."
    curl -s -X POST "$BLUE_URL/chaos/start" > /dev/null
    curl -s -X POST "$GREEN_URL/chaos/start" > /dev/null
    
    print_info "Generating high error rate traffic (20 requests)..."
    for i in {1..20}; do
        curl -s "$NGINX_URL/version" > /dev/null
        echo -n "E"
    done
    echo ""
    
    print_info "Stopping chaos..."
    curl -s -X POST "$BLUE_URL/chaos/stop" > /dev/null
    curl -s -X POST "$GREEN_URL/chaos/stop" > /dev/null
    
    print_info "Waiting for error rate calculation..."
    sleep 8
    
    # Check for new error rate alerts
    NEW_ERROR_ALERTS=$(docker-compose logs alert_watcher 2>/dev/null | grep "ERROR_RATE alert sent to Slack" | wc -l)
    
    if [ "$NEW_ERROR_ALERTS" -gt "$CURRENT_ERROR_ALERTS" ]; then
        print_success "✓ Error rate alert WORKING - new alerts detected"
    else
        print_warning "⚠ No new error rate alerts detected"
    fi
    echo ""
}

# Function to show final status
show_final_status() {
    print_info "7. Final System Status"
    echo "----------------------------------------"
    
    # Show recent alerts
    print_info "Recent alerts in logs:"
    docker-compose logs alert_watcher 2>/dev/null | grep "✅.*alert sent to Slack" | tail -5
    
    # Show watcher status
    print_info "Watcher processing status:"
    docker-compose logs alert_watcher 2>/dev/null | grep "Processing" | tail -3
    
    # Show configuration
    print_info "Current configuration:"
    docker-compose exec alert_watcher python3 -c "
import os
print('Window size:', os.getenv('WINDOW_SIZE', '200'))
print('Error threshold:', os.getenv('ERROR_RATE_THRESHOLD', '10.0'), '%')
print('Alert cooldown:', os.getenv('ALERT_COOLDOWN_SEC', '300'), 'seconds')
" 2>/dev/null || print_warning "Could not read configuration"
    
    echo ""
    print_info "=== TEST COMPLETE ==="
    print_info "Please check your Slack channel for alerts!"
    print_info "End time: $(date)"
    echo "================================================"
}

# Main execution
main() {
    check_services
    test_endpoints
    test_direct_services
    test_chaos_endpoints
    test_failover
    test_error_rate
    show_final_status
}

# Run with error handling
main "$@" || {
    print_error "Test script encountered an error"
    exit 1
}