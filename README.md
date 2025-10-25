Blue/Green Deployment with Nginx Auto-Failover
🚀 Quick Start
1. Clone and Setup
bash

# Copy the environment template (if you have one)
cp .env.example .env  # Optional - variables can be set via command line

2. Start the Deployment
bash

# Start all services with Blue as active
BLUE_IMAGE=node:18-alpine GREEN_IMAGE=node:18-alpine docker-compose up -d

3. Verify Setup
bash

# Test through Nginx proxy (port 8090)
curl http://localhost:8090/version

# You should see JSON response with headers:
# X-App-Pool: blue
# X-Release-Id: blue-release-v1.0.0

🏗 Architecture Overview
text

Client Request (Port 8090)
     ↓
Nginx Reverse Proxy
     ↓
┌─────────────────┐
│  Upstream Pool  │
│  • Blue (8081)  │ ← Primary (Active)
│  • Green (8082) │ ← Backup (Passive)
└─────────────────┘

Port Mapping

    Nginx Proxy: http://localhost:8090 (Note: Using 8090 to avoid Jenkins conflict)

    Blue App Direct: http://localhost:8081

    Green App Direct: http://localhost:8082

🧪 Testing Auto-Failover
Automated Testing
bash

# Run comprehensive test suite
chmod +x test-simple.sh test-failover.sh

# Test basic functionality
./test-simple.sh

# Test auto-failover (requires services to be running)
./test-failover.sh

Manual Testing
Step 1: Baseline (Blue Active)
bash

# All requests should go to Blue
curl http://localhost:8090/version

Step 2: Simulate Blue Failure
bash

# Stop Blue container to simulate failure
docker-compose stop app_blue

# Or use chaos endpoint (returns 500)
curl -X POST http://localhost:8081/chaos/start

Step 3: Verify Automatic Failover
bash

# Wait 5-10 seconds for failover, then test
curl http://localhost:8090/version
# Should now show:
# X-App-Pool: green
# X-Release-Id: green-release-v1.0.0

Step 4: Restore Blue
bash

# Start Blue container again
docker-compose start app_blue

# Stop chaos (if used)
curl -X POST http://localhost:8081/chaos/stop

📊 Monitoring Endpoints
Service Health
bash

# Check overall health through Nginx
curl http://localhost:8090/healthz

# Check Blue directly
curl http://localhost:8081/healthz

# Check Green directly  
curl http://localhost:8082/healthz

Version Information
bash

# Through proxy (respects active pool)
curl http://localhost:8090/version

# Direct to Blue
curl http://localhost:8081/version

# Direct to Green
curl http://localhost:8082/version

Chaos Engineering Endpoints
bash

# Simulate errors (returns HTTP 500)
curl -X POST http://localhost:8081/chaos/start
curl -X POST http://localhost:8082/chaos/start

# Stop chaos simulation
curl -X POST http://localhost:8081/chaos/stop
curl -X POST http://localhost:8082/chaos/stop

⚙️ Configuration
Environment Variables

All configuration is parameterized via environment variables:
Variable	Purpose	Default
BLUE_IMAGE	Docker image for Blue service	node:18-alpine
GREEN_IMAGE	Docker image for Green service	node:18-alpine
ACTIVE_POOL	Which pool starts as active	blue
RELEASE_ID_BLUE	Release identifier for Blue	blue-release-v1.0.0
RELEASE_ID_GREEN	Release identifier for Green	green-release-v1.0.0
BLUE_PORT	Internal port for Blue app	3000
GREEN_PORT	Internal port for Green app	3000

Usage Examples:
bash

# Custom images and release IDs
BLUE_IMAGE=your-app:blue-1.2.0 \
GREEN_IMAGE=your-app:green-1.2.0 \
RELEASE_ID_BLUE=release-1.2.0-blue \
RELEASE_ID_GREEN=release-1.2.0-green \
docker-compose up -d

Nginx Failover Settings

    Failure Detection: 2 failures within 5 seconds

    Timeouts: Connect=2s, Read=5s, Send=5s

    Retry Logic: Automatic retry on errors, timeouts, and 5xx status codes

    Max Retries: 2 attempts with 5s timeout

    Header Preservation: All application headers forwarded to clients

🎯 Key Features

    ✅ Zero-downtime failover - Automatic switch to Green when Blue fails

    ✅ Zero failed client requests - Failed requests automatically retried to backup

    ✅ Fast failover - Typically within 5-10 seconds

    ✅ Health checking - Active monitoring with tight timeouts

    ✅ Header preservation - X-App-Pool and X-Release-Id headers forwarded

    ✅ Chaos engineering ready - Built-in failure simulation endpoints

    ✅ Port conflict resolved - Using port 8090 to avoid Jenkins conflicts

🐛 Troubleshooting
Check Container Status
bash

docker-compose ps
docker-compose logs

Verify Nginx Routing
bash

# Check which upstream handled the request
curl -I http://localhost:8090/version

# Check nginx access logs
docker-compose logs nginx | grep upstream

Test Direct Access
bash

# Bypass Nginx to test apps directly
curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

Common Issues

    Port 8090 in use: Change to another port in docker-compose.yml

    Health checks failing: Check if Node.js services started properly

    No failover: Verify max_fails and fail_timeout in nginx config

📝 File Structure
text

blue-green-nginx/
├── docker-compose.yml          # Service orchestration
├── nginx.conf                  # Nginx configuration with failover
├── test-simple.sh              # Basic functionality test
├── test-failover.sh            # Auto-failover test
├── README.md                   # This file
└── DECISION.md                 # Architecture decisions

🛑 Cleanup
bash

# Stop and remove containers
docker-compose down

# Stop and remove with volumes
docker-compose down -v

# Remove all images
docker-compose down --rmi all

🔧 Development
Modifying the Setup

    Change ports: Update ports in docker-compose.yml

    Adjust failover timing: Modify max_fails and fail_timeout in nginx.conf

    Custom health checks: Update healthcheck section in docker-compose.yml

Adding New Endpoints

All application endpoints are automatically proxied through Nginx. The failover logic applies to all routes.
📈 Performance Characteristics

    Failover Time: 5-10 seconds (configurable)

    Request Timeout: Maximum 10 seconds (5s primary + 5s retry)

    Health Check Interval: 5 seconds

    Concurrent Connections: 1024 workers

🚨 Important Notes

    Port 8090: Using this port instead of 8080 to avoid conflicts with Jenkins

    Direct Access: Use ports 8081/8082 only for chaos testing, not normal traffic

    Header Verification: Always check X-App-Pool header to see which service handled the request

    **Zero

# Link to Google doc:
https://docs.google.com/document/d/1_MaPoWV088N5-RLDkujilLwDg5wkO0iuM6O-ysXZ1Ts/edit?usp=sharing