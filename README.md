🔄 Blue-Green Failover System with Observability & Slack Alerts
📋 Overview

A production-ready blue-green deployment system with automatic failover detection, real-time monitoring, and Slack alerts. This system provides high availability by automatically routing traffic between two application pools (blue and green) and alerting operators when issues are detected.

Key Features:

    🚀 Blue-Green deployment with automatic failover

    📊 Real-time error rate monitoring

    🚨 Slack alerts for failovers and high error rates

    ⚡ Configurable thresholds and cooldown periods

    🔍 Structured logging with full observability

🏗️ Architecture
text

Client → Nginx Load Balancer → [App Blue (v1.0.0) | App Green (v2.0.0)]
                              ↓
                      Python Log Watcher → Slack Alerts

🚀 Quick Start
Prerequisites

    Docker & Docker Compose

    Slack workspace with incoming webhook permissions

    Git

1. Clone and Setup
bash

git clone <your-repository-url>
cd blue-green-nginx-failover

2. Environment Configuration

Copy the example environment file and configure your settings:
bash

cp .env.example .env

Edit .env with your configuration:
bash

# Slack Configuration (REQUIRED)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your-webhook-here

# Alert Configuration
ERROR_RATE_THRESHOLD=2.0        # % of errors to trigger alert
WINDOW_SIZE=200                 # Requests to monitor for error rate
ALERT_COOLDOWN_SEC=300          # Seconds between duplicate alerts

# System Configuration
ACTIVE_POOL=blue                # Initial active pool
MAINTENANCE_MODE=false          # Set true to suppress alerts during maintenance

3. Start the System
bash

docker-compose up -d

4. Verify Services

Check all services are running:
bash

docker-compose ps

Expected output:
text

NAME                                  COMMAND                  SERVICE             STATUS              PORTS
blue-green-nginx-failover-app_blue_1   "docker-entrypoint.sh"   app_blue            running             0.0.0.0:8081->3000/tcp
blue-green-nginx-failover-app_green_1  "docker-entrypoint.sh"   app_green           running             0.0.0.0:8082->3000/tcp  
blue-green-nginx-failover-nginx_1      "/docker-entrypoint.sh"  nginx               running             0.0.0.0:8090->8080/tcp
blue-green-nginx-failover-alert_watcher_1 "python watcher.py"   alert_watcher       running

🧪 Testing & Verification
Basic Connectivity Test
bash

# Test load balancer
curl http://localhost:8090/

# Test version endpoint (shows which pool served request)
curl http://localhost:8090/version

# Test health checks
curl http://localhost:8090/healthz
curl http://localhost:8081/healthz  # Blue pool directly
curl http://localhost:8082/healthz  # Green pool directly

Chaos Testing - Trigger Failovers
1. Test Failover Detection
bash

# Enable chaos mode on blue service (simulates failures)
curl -X POST http://localhost:8081/chaos/start

# Generate traffic that will trigger failover to green
for i in {1..10}; do
  curl -s http://localhost:8090/version > /dev/null
  sleep 0.5
  echo -n "."
done

# Disable chaos
curl -X POST http://localhost:8081/chaos/stop

2. Test Error Rate Alerts
bash

# Enable chaos on both services to generate high error rate
curl -X POST http://localhost:8081/chaos/start
curl -X POST http://localhost:8082/chaos/start

# Generate concentrated errors
for i in {1..25}; do
  curl -s http://localhost:8090/version > /dev/null
  echo -n "E"
done

# Disable chaos
curl -X POST http://localhost:8081/chaos/stop
curl -X POST http://localhost:8082/chaos/stop

Complete System Test

Run the comprehensive test script:
bash

chmod +x complete_system_test.sh
./complete_system_test.sh

📊 Monitoring & Logs
View Real-time Logs
bash

# Watch all services
docker-compose logs -f

# Watch specific service
docker-compose logs -f alert_watcher
docker-compose logs -f nginx
docker-compose logs -f app_blue

Check Alert Status
bash

# View all sent alerts
docker-compose logs alert_watcher | grep "✅.*alert sent to Slack"

# View recent failover detections
docker-compose logs alert_watcher | grep "FAILOVER DETECTED"

# View error rate calculations
docker-compose logs alert_watcher | grep "HIGH ERROR RATE"

View Structured Nginx Logs
bash

# See structured log format with all observability fields
docker-compose exec nginx tail -f /var/log/nginx/access.log

Example log line:
text

172.18.0.1 - - [02/Nov/2025:10:57:55 +0000] "GET /version HTTP/1.1" 500 134 "-" "curl/7.81.0" "-" pool:blue release:blue-1.0.0 upstream_status:500 upstream:172.18.0.3:3000 request_time:0.002 upstream_response_time:0.001

🔔 Slack Alert Verification
Expected Slack Alerts
1. Failover Alert
text

:rotating_light: FAILOVER DETECTED

From: blue
To: green
Time: 02/Nov/2025:10:57:55 +0000  
Release: green-2.0.0
Request: GET /version

2. High Error Rate Alert
text

:exclamation: HIGH ERROR RATE DETECTED

Error Rate: 40.0%
Threshold: 2.0%
Window Size: 200
Time: 02/Nov/2025:10:55:36 +0000
Details: 80 errors in last 200 requests

Verify Alert Delivery

    Check your Slack channel for incoming webhook messages

    Look for both alert types in your designated channel

    Verify timestamps match your test times

    Check alert details contain correct pool and error rate information

Troubleshooting Slack Alerts
bash

# Check if alerts are being sent
docker-compose logs alert_watcher | grep -i "slack"

# Verify webhook configuration
docker-compose exec alert_watcher python3 -c "import os; print('Webhook configured:', bool(os.getenv('SLACK_WEBHOOK_URL')))"

# Check for Slack errors
docker-compose logs alert_watcher | grep -i "error"

📸 Screenshots for Submission

For your Stage 3 submission, ensure you capture the following screenshots:
Required Screenshots:

    slack-failover-alert.png - Slack message showing failover detection

        Shows "FAILOVER DETECTED" message

        Clear view of from/to pools and timestamp

        Full message content visible

    slack-error-rate-alert.png - Slack message showing high error rate alert

        Shows "HIGH ERROR RATE DETECTED" message

        Clear view of error rate percentage and threshold

        Full message details visible

    nginx-structured-logs.png - Nginx log lines showing structured format

        Shows log lines with all required fields:

            pool:blue/green

            release:version-number

            upstream_status:200/500

            upstream:address:port

            request_time:value

            upstream_response_time:value

How to Capture Screenshots:
bash

# For log screenshots
docker-compose exec nginx tail -5 /var/log/nginx/access.log

# For alert verification
docker-compose logs alert_watcher | grep "✅.*alert sent" | tail -3

⚙️ Configuration Reference
Environment Variables
Variable	Default	Description
SLACK_WEBHOOK_URL	-	Required Slack incoming webhook URL
ERROR_RATE_THRESHOLD	2.0	Error percentage to trigger alert
WINDOW_SIZE	200	Request window for error rate calculation
ALERT_COOLDOWN_SEC	300	Seconds between duplicate alerts
ACTIVE_POOL	blue	Initial active deployment pool
MAINTENANCE_MODE	false	Suppress alerts during maintenance
Nginx Configuration

    Port: 8090 (external) → 8080 (internal)

    Load Balancing: Round-robin with failover

    Health Checks: Automatic upstream monitoring

    Log Format: Enhanced structured logging

Application Endpoints
Service	Port	Endpoints
Nginx	8090	/, /version, /healthz
Blue App	8081	/version, /healthz, /chaos/start, /chaos/stop
Green App	8082	/version, /healthz, /chaos/start, /chaos/stop
🛠️ Maintenance
Enable Maintenance Mode
bash

# Suppress alerts during planned maintenance
export MAINTENANCE_MODE=true
docker-compose restart alert_watcher

Update Configuration
bash

# Edit environment variables
nano .env

# Apply changes
docker-compose restart alert_watcher

Stop and Cleanup
bash

# Stop services
docker-compose down

# Remove volumes (warning: deletes logs)
docker-compose down -v

🐛 Troubleshooting
Common Issues

Slack alerts not working:

    Verify SLACK_WEBHOOK_URL in .env

    Check Slack channel permissions

    View watcher logs for errors

No failover detected:

    Check if chaos mode is active: curl http://localhost:8081/chaos/start

    Verify both services are healthy

    Check nginx error logs: docker-compose logs nginx

High error rate but no alert:

    Check cooldown period: ALERT_COOLDOWN_SEC=300

    Verify window size: WINDOW_SIZE=200

    Check error threshold: ERROR_RATE_THRESHOLD=2.0

Diagnostic Commands
bash

# Check service health
docker-compose ps
docker-compose logs --tail=10

# Verify configuration
docker-compose exec alert_watcher python3 -c "
import os
print('Webhook:', bool(os.getenv('SLACK_WEBHOOK_URL')))
print('Window size:', os.getenv('WINDOW_SIZE'))
print('Error threshold:', os.getenv('ERROR_RATE_THRESHOLD'))
print('Cooldown:', os.getenv('ALERT_COOLDOWN_SEC'))
"

# Monitor real-time traffic
watch -n 2 'curl -s http://localhost:8090/version | grep -o "blue\|green"'

📚 Documentation

    Runbook - Operational procedures and emergency response

    Stage 2 Implementation - Base blue-green functionality

    Nginx Configuration - Load balancing and logging setup

    Watcher Service - Alert logic and monitoring

🎯 Acceptance Criteria Verified

✅ Nginx structured logs with all required fields
✅ Slack failover alerts on pool transitions
✅ Error rate alerts when threshold exceeded
✅ Alert cooldown prevents spam
✅ Maintenance mode for planned work
✅ Complete runbook with operator guidance
✅ Working chaos testing generates alerts