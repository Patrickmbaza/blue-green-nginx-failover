#!/bin/bash

echo "🌪️  Testing Auto-Failover"
echo "=========================="

echo "Step 1: Current state (should be Blue)"
curl -s http://localhost:8090/version | jq -r '. | "Pool: \(.pool), Release: \(.release)"'

echo ""
echo "Step 2: Testing direct chaos endpoints"
echo "Blue chaos start:"
curl -s -X POST http://localhost:8081/chaos/start | jq .
echo "Green chaos start:"
curl -s -X POST http://localhost:8082/chaos/start | jq .

echo ""
echo "Step 3: Simulating Blue failure by stopping container"
docker-compose stop app_blue

echo ""
echo "Step 4: Testing failover to Green (waiting 10 seconds for failover)..."
sleep 10

echo "Making 10 requests to verify failover:"
blue_count=0
green_count=0

for i in {1..10}; do
    response=$(curl -s http://localhost:8090/version)
    pool=$(echo $response | grep -o '"pool":"[^"]*' | cut -d'"' -f4)
    echo "Request $i: $pool"
    
    if [ "$pool" = "blue" ]; then
        ((blue_count++))
    elif [ "$pool" = "green" ]; then
        ((green_count++))
    fi
    sleep 1
done

echo ""
echo "📊 Failover Results:"
echo "Blue responses: $blue_count"
echo "Green responses: $green_count"

if [ $green_count -gt 0 ]; then
    echo "✅ FAILOVER SUCCESSFUL - Traffic switched to Green"
else
    echo "❌ FAILOVER FAILED - Still routing to Blue"
fi

echo ""
echo "Step 5: Restoring Blue service"
docker-compose start app_blue
sleep 10

echo ""
echo "Step 6: Back to normal routing"
curl -s http://localhost:8090/version | jq -r '. | "Pool: \(.pool), Release: \(.release)"'

echo "✅ Failover test complete!"