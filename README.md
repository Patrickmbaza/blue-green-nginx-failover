# Blue-Green Deployment with Nginx Auto-Failover

A production-ready blue-green deployment setup with automatic failover, zero-downtime deployments, and chaos testing capabilities using Docker Compose and Nginx.

## 🚀 Overview

This project implements a robust blue-green deployment strategy with the following features:

- **Blue-Green Deployment**: Two identical environments (Blue and Green) running simultaneously
- **Automatic Failover**: Nginx automatically routes traffic to the healthy environment
- **Zero Downtime**: Seamless switching between environments without service interruption
- **Chaos Testing**: Built-in endpoints to simulate failures and test resilience
- **Header Preservation**: Maintains application headers through the proxy layer

## 📁 Project Structure

blue-green-nginx/
├── docker-compose.yml # Service orchestration
├── nginx.conf # Nginx load balancer configuration
├── server.js # Node.js application
├── package.json # Node.js dependencies
├── Dockerfile.blue # Blue environment Dockerfile
├── Dockerfile.green # Green environment Dockerfile
├── .env.example # Environment variables template
├── README.md # This file
└── DECISION.md # Architecture decisions (optional)
text


## 🛠️ Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

## ⚡ Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd blue-green-nginx

2. Configure Environment
bash

# Copy the environment template
cp .env.example .env

# Edit with your preferred values
nano .env

3. Deploy
bash

# Build and start all services
docker-compose up -d

# Verify services are running
docker-compose ps

4. Access the Application

    Main Application: http://localhost:8090

    Blue Service Direct: http://localhost:8081

    Green Service Direct: http://localhost:8082

🔧 Configuration
Environment Variables (.env)
bash

BLUE_IMAGE=my-blue-app          # Blue environment image
GREEN_IMAGE=my-green-app        # Green environment image
RELEASE_ID_BLUE=blue-1.0.0      # Blue release identifier
RELEASE_ID_GREEN=green-2.0.0    # Green release identifier
ACTIVE_POOL=blue                # Initial active environment

Port Mapping
Service	Host Port	Container Port	Purpose
Nginx	8090	8080	Main application entry point
Blue App	8081	3000	Direct access to blue environment
Green App	8082	3000	Direct access to green environment
🎯 API Endpoints
Application Endpoints
Endpoint	Method	Description
/	GET	Application root (redirects to /version)
/version	GET	Returns version info with headers
/healthz	GET	Health check endpoint
Chaos Testing Endpoints
Endpoint	Method	Description
/chaos/start	POST	Start chaos mode (simulates failures)
/chaos/stop	POST	Stop chaos mode
Chaos Mode Parameters

    mode=error - Returns 500 errors

    mode=timeout - Simulates timeouts (not implemented)

🔄 Deployment Workflow
Normal Operation

    Blue is the active environment receiving 100% of traffic

    Green is the backup environment, ready for failover

    Nginx monitors Blue's health with aggressive timeouts

Failover Scenario

    Blue service starts failing (500 errors or timeouts)

    Nginx detects failures within 1-3 seconds

    Automatic traffic routing to Green environment

    Zero failed client requests (internal retry mechanism)

Manual Deployment Process
bash

# 1. Deploy new version to Green environment
# 2. Test Green environment directly (port 8082)
# 3. Update nginx.conf to switch traffic to Green
docker-compose exec nginx nginx -s reload

# 4. Blue becomes the new backup
# 5. Deploy next version to Blue when ready

🧪 Testing
Basic Health Check
bash

# Test main application
curl http://localhost:8090/version

# Test direct access
curl http://localhost:8081/version  # Blue
curl http://localhost:8082/version  # Green

Failover Testing
bash

# 1. Start with normal operation (all traffic to Blue)
curl http://localhost:8090/version

# 2. Induce chaos on Blue
curl -X POST "http://localhost:8081/chaos/start?mode=error"

# 3. Wait for failover (2-3 seconds)
sleep 3

# 4. Verify traffic is routed to Green
curl http://localhost:8090/version

# 5. Stop chaos
curl -X POST "http://localhost:8081/chaos/stop"

Headers Verification
bash

# Check preserved headers
curl -I http://localhost:8090/version

# Expected headers:
# X-App-Pool: blue|green
# X-Release-Id: blue-1.0.0|green-2.0.0

🏗️ Architecture
Components

    Nginx Load Balancer

        Primary/backup upstream configuration

        Fast failure detection (1 second timeouts)

        Automatic retry to backup server

        Header preservation

    Blue Environment

        Active production environment

        Receives 100% of traffic initially

        Monitored for health issues

    Green Environment

        Backup/staging environment

        Ready for immediate failover

        Used for testing new versions

Nginx Configuration Features

    Fast Failover: max_fails=1 fail_timeout=1s

    Aggressive Timeouts: 500ms connect/send/read timeouts

    Retry Logic: Automatic retry on 5xx errors and timeouts

    No Buffering: Immediate failure detection

    Backup Directive: Green only used when Blue fails

🚨 Monitoring & Logs
View Logs
bash

# Nginx logs
docker-compose logs nginx

# Application logs
docker-compose logs app_blue
docker-compose logs app_green

Health Monitoring
bash

# Check all services
docker-compose ps

# Test health endpoints
curl http://localhost:8081/healthz
curl http://localhost:8082/healthz

🔄 Management Commands
Service Management
bash

# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View service status
docker-compose ps

Nginx Management
bash

# Reload configuration
docker-compose exec nginx nginx -s reload

# Test configuration
docker-compose exec nginx nginx -t

# View current config
docker-compose exec nginx cat /etc/nginx/nginx.conf

🛡️ Production Considerations
Security

    Environment variables for configuration

    No sensitive data in version control

    Container isolation

    Port security

Reliability

    Fast failure detection (sub-second)

    Automatic recovery

    Health checking

    Graceful degradation

Scalability

    Easy to add more instances

    Load balancer ready

    Stateless application design

🐛 Troubleshooting
Common Issues

    Port Conflicts
    bash

# Check port usage
sudo netstat -tulpn | grep :8099

Container Issues
bash

# Check container status
docker-compose ps

# View logs
docker-compose logs

Nginx Configuration
bash

# Test configuration
docker-compose exec nginx nginx -t

# Reload configuration
docker-compose exec nginx nginx -s reload

Debugging Failover
bash

# Check if failover is working
curl -X POST "http://localhost:8081/chaos/start?mode=error"
sleep 3
for i in {1..5}; do curl -s http://localhost:8090/version | grep '"pool"'; done
curl -X POST "http://localhost:8081/chaos/stop"

📈 Performance

    Failover Time: 1-3 seconds

    Request Timeout: 500ms

    Health Check: Continuous

    Memory: Minimal overhead

🤝 Contributing

    Fork the repository

    Create a feature branch

    Make your changes

    Test thoroughly

    Submit a pull request

    Nginx for robust load balancing

    Docker for containerization

    Node.js for the application runtime



    # Rebuild with the fixed server.js
docker build -t my-blue-app -f Dockerfile.blue .
docker build -t my-green-app -f Dockerfile.green .

# Restart services
docker-compose down
docker-compose up -d
sleep 5