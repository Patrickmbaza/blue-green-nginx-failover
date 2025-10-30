Blue/Green Deployment Runbook
📋 Overview

This runbook documents the Blue/Green deployment system with automatic failover, observability, and alerting. The system consists of:

    Two Node.js applications (Blue and Green) behind Nginx load balancer

    Automatic failover when primary pool experiences failures

    Real-time monitoring via Python log watcher

    Slack alerts for failovers and high error rates

🏗️ Architecture
text

Client → Nginx (Port 8090) → [Blue (Port 8081) | Green (Port 8082)]
                              ↑
                      Python Watcher → Slack Alerts

🚨 Alert Types and Responses
🔄 FAILOVER DETECTED

What Happened: Traffic automatically switched from primary to backup pool due to failures.

Severity: HIGH

Immediate Actions:

    ✅ Check primary pool health: docker compose logs app_blue --tail=20

    ✅ Verify failover was successful: curl http://localhost:8090/version

    ✅ Check if chaos mode is active: curl http://localhost:8081/ | grep chaos_mode

    ✅ Monitor backup pool performance: docker compose logs app_green --tail=10

Investigation Steps:
bash

# 1. Check application logs for errors
docker compose logs app_blue --tail=50 | grep -i "error\|fail"

# 2. Verify resource usage
docker compose exec app_blue ps aux

# 3. Check network connectivity
docker compose exec app_blue ping app_green

# 4. Review recent requests
docker compose exec nginx tail -20 /var/log/nginx/access.log.custom

Recovery Procedure:
bash

# If primary issue is resolved, restore traffic to Blue:
curl -X POST "http://localhost:8081/chaos/stop"
docker compose restart nginx

🔴 HIGH ERROR RATE

What Happened: More than 2% of requests are returning 5xx errors in the last 200 requests.

Severity: MEDIUM

Immediate Actions:

    ✅ Check recent logs: docker compose logs nginx --tail=50

    ✅ Verify both pools are healthy:
    bash

curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

    ✅ Check for resource exhaustion: docker system stats

    ✅ Review application metrics

Error Rate Calculation:

    Threshold: 2% (configurable via ERROR_RATE_THRESHOLD)

    Window: 200 requests (configurable via WINDOW_SIZE)

    Cooldown: 300 seconds between alerts (configurable via ALERT_COOLDOWN_SEC)

Troubleshooting:
bash

# Check error patterns
docker compose exec nginx grep "status=5" /var/log/nginx/access.log.custom

# Monitor real-time traffic
watch -n 2 'curl -s http://localhost:8090/version | grep environment'

# Check watcher status
docker compose logs alert_watcher --tail=10

🛠️ Operational Procedures
Starting the System
bash

# 1. Set environment variables
cp .env.example .env
# Edit .env with your Slack webhook and configuration

# 2. Start all services
docker compose up -d

# 3. Verify all services are running
docker compose ps

# 4. Test initial setup
curl http://localhost:8090/version

Stopping the System
bash

# Graceful shutdown
docker compose down

# Force shutdown (removes volumes)
docker compose down -v

Maintenance Mode

To suppress alerts during planned maintenance:
bash

# 1. Set cooldown to maximum
echo "ALERT_COOLDOWN_SEC=86400" >> .env  # 24 hours

# 2. Restart watcher
docker compose restart alert_watcher

# 3. Perform maintenance tasks
# ... your maintenance here ...

# 4. Restore normal alerting
# Edit .env and set ALERT_COOLDOWN_SEC back to 300
docker compose restart alert_watcher

Manual Pool Switching
bash

# Switch to Green pool
docker compose stop app_blue
# Traffic will automatically failover to Green

# Switch back to Blue pool
docker compose start app_blue
docker compose restart nginx

🔧 Configuration Reference
Environment Variables (.env)
bash

# Application
ACTIVE_POOL=blue
RELEASE_ID_BLUE=blue-1.0.0
RELEASE_ID_GREEN=green-2.0.0

# Slack Integration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url

# Alert Configuration
ERROR_RATE_THRESHOLD=2.0
WINDOW_SIZE=200
ALERT_COOLDOWN_SEC=300

Nginx Configuration

    Listen Port: 8080 (mapped to 8090 on host)

    Failover: Automatic on 5xx errors or timeouts

    Timeouts:

        Connect: 1s

        Send: 2s

        Read: 2s

    Retry Policy: 2 attempts on errors/5xx

📊 Monitoring and Logging
Accessing Logs
bash

# Nginx access logs (structured format)
docker compose exec nginx tail -f /var/log/nginx/access.log.custom

# Application logs
docker compose logs -f app_blue
docker compose logs -f app_green

# Watcher logs
docker compose logs -f alert_watcher

# All services combined
docker compose logs -f

Log Format

Nginx logs include:
text

time=[timestamp]|method=[HTTP_METHOD]|uri=[URI]|status=[STATUS]|
upstream_addr=[UPSTREAM]|upstream_status=[UPSTREAM_STATUS]|
upstream_response_time=[TIME]|request_time=[TIME]|
pool=[blue|green]|release=[RELEASE_ID]

Health Checks
bash

# Application health
curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

# Through load balancer
curl http://localhost:8090/healthz

# Version info (includes pool info)
curl http://localhost:8090/version

🧪 Testing Procedures
Failover Test
bash

# 1. Induce failures on Blue
curl -X POST "http://localhost:8081/chaos/start?mode=error"

# 2. Generate traffic to trigger failover
for i in {1..10}; do
  curl -s http://localhost:8090/version > /dev/null
done

# 3. Verify failover occurred
curl http://localhost:8090/version  # Should show "green"

# 4. Check for Slack alert
# ... check your Slack channel ...

# 5. Restore normal operation
curl -X POST "http://localhost:8081/chaos/stop"
docker compose restart nginx

Error Rate Test
bash

# Generate enough errors to trigger alert
for i in {1..50}; do
  curl -s http://localhost:8081/ > /dev/null  # Direct to Blue with chaos
done

# Check watcher logs for error rate alert
docker compose logs alert_watcher --tail=20

🚒 Emergency Procedures
Service Unavailable
bash

# Check all services status
docker compose ps

# Restart specific service
docker compose restart [service_name]

# Complete restart
docker compose restart

Watcher Not Working
bash

# Check if watcher is running
docker compose ps alert_watcher

# Check watcher process
docker compose exec alert_watcher ps aux

# Restart watcher
docker compose restart alert_watcher

# Manual test
docker compose run --rm alert_watcher python simple_watcher.py

Slack Alerts Not Working
bash

# Test webhook manually
docker compose run --rm alert_watcher python test_slack.py

# Check environment variable
docker compose exec alert_watcher env | grep SLACK

# Verify webhook URL in Slack app settings

📈 Performance Metrics
Key Metrics to Monitor

    Response Time: upstream_response_time in logs

    Error Rate: Percentage of 5xx responses

    Failover Frequency: How often pools switch

    Request Volume: Requests per minute

Log Analysis Commands
bash

# Count requests per pool
docker compose exec nginx grep -c "pool=blue" /var/log/nginx/access.log.custom
docker compose exec nginx grep -c "pool=green" /var/log/nginx/access.log.custom

# Error rate calculation
docker compose exec nginx awk -F'|' '$4 ~ /status=5[0-9][0-9]/ {count++} END {print "5xx errors:", count}' /var/log/nginx/access.log.custom

# Average response time
docker compose exec nginx awk -F'|' '{split($7,a,"="); sum+=a[2]; count++} END {print "Avg response time:", sum/count}' /var/log/nginx/access.log.custom

🔄 Recovery Scenarios
Scenario 1: Blue Pool Failing

Symptoms: High error rate, failover to Green
Recovery:

    Investigate Blue pool issues

    Fix underlying problem

    Stop chaos mode: curl -X POST "http://localhost:8081/chaos/stop"

    Restart nginx to restore Blue: docker compose restart nginx

Scenario 2: Both Pools Failing

Symptoms: All requests failing, no healthy upstream
Recovery:

    Check infrastructure issues

    Restart all services: docker compose restart

    Verify health checks pass

    Monitor traffic restoration

Scenario 3: Watcher Process Stopped

Symptoms: No Slack alerts, watcher container exited
Recovery:

    Restart watcher: docker compose restart alert_watcher

    Check logs for errors: docker compose logs alert_watcher

    Verify Python dependencies: docker compose exec alert_watcher pip list

📞 Contact Information

    Primary On-call: [Team Lead]

    Secondary On-call: [Backup Engineer]

    Slack Channel: #blue-green-alerts

    Documentation: [Link to internal docs]

Last Updated: October 2025
Maintainer: DevOps Team
Review Schedule: Quarterly
