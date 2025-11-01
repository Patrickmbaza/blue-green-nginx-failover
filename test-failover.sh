#!/bin/bash

# === CONFIGURATION ===
NGINX_URL="http://localhost:8090/"
BLUE_CHAOS="http://localhost:8081/chaos"
GREEN_CHAOS="http://localhost:8082/chaos"

# === FUNCTION TO CHECK WHICH ENVIRONMENT IS ACTIVE ===
check_pool() {
  RESPONSE=$(curl -s -i "$NGINX_URL")
  ACTIVE_POOL=$(echo "$RESPONSE" | grep -i "x-app-pool:" | awk -F': ' '{print $2}' | tr -d '\r')
  RELEASE_ID=$(echo "$RESPONSE" | grep -i "x-release-id:" | awk -F': ' '{print $2}' | tr -d '\r')
  HTTP_STATUS=$(echo "$RESPONSE" | grep -i "HTTP/" | awk '{print $2}')

  echo "HTTP Status: $HTTP_STATUS"
  echo "Active pool: ${ACTIVE_POOL:-unknown}"
  echo "Release ID: ${RELEASE_ID:-unknown}"
}

# === STEP 1: Initial Status ===
echo "🔍 Checking initial active environment..."
check_pool

# === STEP 2: Start Blue Chaos ===
echo -e "\n💥 Simulating failure in Blue environment..."
curl -s -X POST "${BLUE_CHAOS}/start" >/dev/null
sleep 5  # Increased sleep for failover detection

# === STEP 3: Check if Nginx switched to Green ===
echo -e "\n🧭 Checking if Nginx switched to Green..."
check_pool

# === STEP 4: Stop Blue Chaos (recover Blue) ===
echo -e "\n🔧 Restoring Blue environment..."
curl -s -X POST "${BLUE_CHAOS}/stop" >/dev/null
sleep 5  # Increased sleep for recovery detection

# === STEP 5: Verify Blue is back and Nginx routes correctly ===
echo -e "\n✅ Verifying recovery..."
check_pool
