🚨 Blue-Green Failover System Runbook
📋 Overview

This runbook provides operational guidance for the Blue-Green Deployment Failover System with real-time monitoring and alerting. The system automatically detects failovers between blue and green deployment pools and monitors upstream error rates, sending alerts to Slack when issues are detected.
🔧 System Architecture
text

┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│    Nginx    │───▶│  App Blue   │    │  Slack      │
│             │    │  Load       │    │  (v1.0.0)   │    │  Alerts     │
│             │    │  Balancer   │───▶│  App Green  │────│             │
└─────────────┘    └─────────────┘    │  (v2.0.0)   │    └─────────────┘
                               ┌──────▶│             │
                               │      └─────────────┘
                               │      ┌─────────────┐
                               │      │ Log Watcher │
                               └──────│ (Python)    │
                                      └─────────────┘

📊 Alert Types
1. 🚨 Failover Detected Alert

Slack Message Format:
text

:rotating_light: FAILOVER DETECTED

From: blue
To: green  
Time: 02/Nov/2025:10:57:55 +0000
Release: green-2.0.0
Request: GET /version

What This Means:

    The system has automatically switched traffic from one deployment pool to another

    This typically occurs when the primary pool experiences failures (5xx errors or timeouts)

    Nginx's proxy_next_upstream mechanism triggered the failover

Operator Actions:
🔍 Immediate Investigation (First 5 minutes)

    Check Service Health:
    bash

# Check which pool is currently serving traffic
curl http://localhost:8090/version | grep -o "blue\|green"

# Check health of both pools directly
curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

Review Container Status:
bash

docker-compose ps
docker-compose logs app_blue --tail=20
docker-compose logs app_green --tail=20

Check Error Patterns:
bash

# Count recent errors in nginx logs
docker-compose exec nginx grep " 500 " /var/log/nginx/access.log | wc -l

# View recent failovers
docker-compose logs alert_watcher | grep "FAILOVER DETECTED" | tail -5

🛠️ Remediation Actions

If Blue Pool Failed:
bash

# Investigate blue service issues
docker-compose logs app_blue --tail=50
docker-compose exec app_blue curl localhost:3000/healthz

# Restart if necessary
docker-compose restart app_blue

# Monitor recovery
watch -n 2 'curl -s http://localhost:8090/version | grep -o "blue\|green"'

If Green Pool Failed:
bash

# Investigate green service issues  
docker-compose logs app_green --tail=50
docker-compose exec app_green curl localhost:3000/healthz

# Restart if necessary
docker-compose restart app_green

✅ Recovery Confirmation

    Monitor for automatic failback when the original pool recovers

    Verify both pools are healthy:
    bash

curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

2. 📊 High Error Rate Alert

Slack Message Format:
text

:exclamation: HIGH ERROR RATE DETECTED

Error Rate: 40.0%
Threshold: 2.0%
Window Size: 200
Time: 02/Nov/2025:10:55:36 +0000
Details: 80 errors in last 200 requests

What This Means:

    More than 2% of requests in the last 200 requests returned 5xx errors

    This indicates potential instability in the upstream services

    The system is experiencing elevated error rates across both pools

Operator Actions:
🔍 Immediate Investigation

    Check Current Error Rate:
    bash

# Real-time error rate monitoring
watch -n 5 '
total=$(docker-compose exec nginx tail -100 /var/log/nginx/access.log | wc -l)
errors=$(docker-compose exec nginx tail -100 /var/log/nginx/access.log | grep " 500 " | wc -l)
rate=$((errors * 100 / total))
echo "Error rate: $rate% ($errors/$total errors)"
'

Identify Error Sources:
bash

# Check which pool is generating errors
docker-compose exec nginx grep " 500 " /var/log/nginx/access.log | grep -o "pool:[^ ]*" | sort | uniq -c

# Check specific error patterns
docker-compose exec nginx grep " 500 " /var/log/nginx/access.log | tail -10

Service Health Deep Dive:
bash

# Check both services
for service in app_blue app_green; do
  echo "=== $service ==="
  docker-compose logs $service --tail=20 | grep -i "error\|exception\|timeout"
done

# Resource usage
docker stats --no-stream $(docker-compose ps -q)

🛠️ Remediation Actions

For Widespread Errors (Both Pools):
bash

# Check for infrastructure issues
docker-compose logs nginx --tail=20
docker-compose logs alert_watcher --tail=20

# Restart affected services
docker-compose restart app_blue app_green

# Monitor recovery
watch -n 2 '
curl -s http://localhost:8081/healthz | grep -q healthy && echo "Blue: ✅" || echo "Blue: ❌"
curl -s http://localhost:8082/healthz | grep -q healthy && echo "Green: ✅" || echo "Green: ❌"
'

For Single Pool Errors:
bash

# Isolate problematic pool
if docker-compose exec nginx grep " 500 " /var/log/nginx/access.log | grep "pool:blue" | head -5; then
  echo "Blue pool has issues - investigate:"
  docker-compose logs app_blue --tail=30
elif docker-compose exec nginx grep " 500 " /var/log/nginx/access.log | grep "pool:green" | head -5; then
  echo "Green pool has issues - investigate:"
  docker-compose logs app_green --tail=30
fi

✅ Recovery Confirmation

    Monitor error rate dropping below threshold

    Verify alert cooldown has reset:
    bash

# Check if error rate has normalized
total=$(docker-compose exec nginx tail -50 /var/log/nginx/access.log | wc -l)
errors=$(docker-compose exec nginx tail -50 /var/log/nginx/access.log | grep " 500 " | wc -l)
echo "Current error rate: $((errors * 100 / total))%"

⚙️ Configuration Reference
Environment Variables (.env)
bash

# Required: Slack Webhook
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Alert Configuration
ERROR_RATE_THRESHOLD=2.0        # Percentage of errors to trigger alert
WINDOW_SIZE=200                 # Number of requests to monitor for error rate
ALERT_COOLDOWN_SEC=300          # Seconds between duplicate alerts

# System Configuration  
ACTIVE_POOL=blue                # Initial active pool
MAINTENANCE_MODE=false          # Set to true to suppress alerts during maintenance

Nginx Log Format
text

Log format: enhanced
Fields captured:
- pool: $upstream_http_x_app_pool
- release: $upstream_http_x_release_id  
- upstream_status: $upstream_status
- upstream: $upstream_addr
- request_time: $request_time
- upstream_response_time: $upstream_response_time

🛡️ Maintenance Procedures
Planned Maintenance Mode

Before starting maintenance:
bash

# Set maintenance mode to suppress alerts
export MAINTENANCE_MODE=true
docker-compose restart alert_watcher

# Verify maintenance mode is active
docker-compose exec alert_watcher python3 -c "import os; print('Maintenance mode:', os.getenv('MAINTENANCE_MODE'))"

During maintenance:

    Perform your deployment or maintenance tasks

    No alerts will be sent to Slack

    Logs continue to be processed and monitored

After maintenance:
bash

# Disable maintenance mode
export MAINTENANCE_MODE=false
docker-compose restart alert_watcher

# Verify system is back to normal
./complete_system_test.sh

Manual Pool Management

Force traffic to specific pool:
bash

# Stop one pool to force all traffic to the other
docker-compose stop app_green  # Force traffic to blue
# or
docker-compose stop app_blue   # Force traffic to green

# Restart stopped pool when ready
docker-compose start app_green

📈 Monitoring & Observability
Key Metrics to Monitor

    Failover Frequency
    bash

# Count failovers in last hour
docker-compose logs alert_watcher --since 1h | grep "FAILOVER DETECTED" | wc -l

Error Rate Trends
bash

# Error rate over time
docker-compose exec nginx sh -c "
  echo 'Time,TotalRequests,Errors,ErrorRate'
  for i in 1 2 3 4 5; do
    total=\$(tail -100 /var/log/nginx/access.log | wc -l)
    errors=\$(tail -100 /var/log/nginx/access.log | grep ' 500 ' | wc -l)
    rate=\$((errors * 100 / total))
    echo \"\$(date),\$total,\$errors,\$rate%\"
    sleep 60
  done
"

Response Time Monitoring
bash

# Check latency percentiles
docker-compose exec nginx tail -1000 /var/log/nginx/access.log | \
  grep -o 'request_time:[0-9.]*' | cut -d: -f2 | sort -n | \
  awk '{
    a[i++]=$0
  } END {
    print "P50:", a[int(i*0.5)]
    print "P95:", a[int(i*0.95)] 
    print "P99:", a[int(i*0.99)]
  }'

Health Check Endpoints
bash

# Application health
curl http://localhost:8081/healthz  # Blue pool
curl http://localhost:8082/healthz  # Green pool

# Nginx status
curl http://localhost:8090/version

# Watcher status
docker-compose logs alert_watcher --tail=5

🚨 Emergency Procedures
System Unresponsive
bash

# Restart entire stack
docker-compose down
docker-compose up -d

# Verify recovery
docker-compose ps
curl http://localhost:8090/healthz

Alert Storm
bash

# Temporarily increase cooldown period
export ALERT_COOLDOWN_SEC=600  # 10 minutes
docker-compose restart alert_watcher

# Or enable maintenance mode
export MAINTENANCE_MODE=true
docker-compose restart alert_watcher

Database/External Dependency Issues
bash

# Check for external dependency errors in logs
docker-compose logs app_blue app_green | grep -i "database\|connection\|timeout"

# If needed, disable chaos mode on both services
curl -X POST http://localhost:8081/chaos/stop
curl -X POST http://localhost:8082/chaos/stop

📞 Escalation Procedures
Level 1 (First 15 minutes)

    Follow runbook procedures above

    Attempt basic remediation (restart services)

    Document actions taken

Level 2 (15-30 minutes)

    Engage development team if application issues suspected

    Check for recent deployments or changes

    Consider rolling back to previous version

Level 3 (30+ minutes)

    Engage infrastructure team

    Consider failover to disaster recovery environment

    Executive communication if customer impact

✅ Success Criteria

Issue Resolved When:

    Error rate below 2% for 5 consecutive minutes

    No failover events for 10 minutes

    All health checks passing

    Alert cooldown periods respected

    Post-mortem scheduled if needed

Last Updated: November 2025
Maintainer: DevOps Team
Review Schedule: Quarterly
