#!/bin/bash

echo "🚀 QUICK SLACK ALERT TEST"

# 1. First, make sure services are running
echo "1. Checking services..."
docker-compose ps
sleep 2

# 2. Test failover detection
echo "2. Testing FAILOVER detection..."
echo "Starting chaos on blue..."
curl -X POST http://localhost:8081/chaos/start

echo "Generating traffic..."
for i in {1..10}; do
  curl -s http://localhost:8090/version > /dev/null
  sleep 0.5
  echo -n "."
done
echo ""

curl -X POST http://localhost:8081/chaos/stop
echo "Waiting 8 seconds for alert..."
sleep 8

# 3. Test error rate alert
echo "3. Testing ERROR RATE alert..."
echo "Starting chaos on both services..."
curl -X POST http://localhost:8081/chaos/start
curl -X POST http://localhost:8082/chaos/start

echo "Generating errors..."
for i in {1..25}; do
  curl -s http://localhost:8090/version > /dev/null
  echo -n "E"
done
echo ""

curl -X POST http://localhost:8081/chaos/stop
curl -X POST http://localhost:8082/chaos/stop
echo "Waiting 10 seconds for error rate alert..."
sleep 10

# 4. Show results
echo "4. RESULTS:"
echo "Recent alerts:"
docker-compose logs alert_watcher | grep "✅.*alert sent to Slack" | tail -5

echo ""
echo "📱 CHECK YOUR SLACK CHANNEL NOW!"
echo "You should see both:"
echo "  • FAILOVER DETECTED alert"
echo "  • HIGH ERROR RATE alert"