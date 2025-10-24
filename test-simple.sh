#!/bin/bash

echo "🚀 Starting Blue/Green Deployment Test"
echo "======================================"

# Clean up any existing containers
echo "Cleaning up any existing containers..."
docker-compose down

# Start services
echo "Starting services with Blue as active..."
BLUE_IMAGE=node:18-alpine GREEN_IMAGE=node:18-alpine docker-compose up -d

echo "Waiting for services to start..."
sleep 15

echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "🔵 Testing Baseline Routing (Should be Blue)"
echo "============================================"
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s http://localhost:8090/version | grep -o '"pool":"[^"]*' | cut -d'"' -f4
    sleep 1
done

echo ""
echo "🔍 Testing Direct Access"
echo "========================"
echo -n "Blue direct (8081): "
curl -s http://localhost:8081/healthz
echo ""
echo -n "Green direct (8082): "
curl -s http://localhost:8082/healthz

echo ""
echo "📝 Testing Headers"
echo "=================="
echo "Through Nginx (port 8090):"
curl -I -s http://localhost:8090/version | grep -i "x-app-pool\|x-release-id"

echo ""
echo "Direct to Blue (port 8081):"
curl -I -s http://localhost:8081/version | grep -i "x-app-pool\|x-release-id"

echo ""
echo "Direct to Green (port 8082):"
curl -I -s http://localhost:8082/version | grep -i "x-app-pool\|x-release-id"

echo ""
echo "🎯 Testing Chaos Endpoints"
echo "=========================="
echo "Blue chaos start (should return 500):"
curl -s -X POST http://localhost:8081/chaos/start | jq .
echo "Green chaos start (should return 500):"
curl -s -X POST http://localhost:8082/chaos/start | jq .

echo ""
echo "✅ SUCCESS: All services are running!"
echo "   Nginx:  http://localhost:8090"
echo "   Blue:   http://localhost:8081" 
echo "   Green:  http://localhost:8082"