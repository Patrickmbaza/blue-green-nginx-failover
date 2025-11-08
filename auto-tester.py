#!/usr/bin/env python3
"""
Auto-tester for Blue-Green failover and error rate alerts
"""

import os
import time
import requests
import threading
import logging
from datetime import datetime, timedelta

# Configuration
NGINX_URL = "http://localhost:8090"
BLUE_URL = "http://localhost:8081"
GREEN_URL = "http://localhost:8082"
COOLDOWN_PERIOD = 300  # 5 minutes
REQUESTS_PER_TEST = 250

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class AutoTester:
    def __init__(self):
        self.results = {
            'error_rate_test': False,
            'failover_test': False
        }
    
    def make_request(self, url, timeout=2):
        """Make a single request with error handling"""
        try:
            response = requests.get(url, timeout=timeout)
            return response.status_code
        except requests.exceptions.RequestException:
            return 0  # Consider timeouts as errors for our test
    
    def generate_load(self, num_requests, description):
        """Generate concurrent load"""
        logger.info(f"📊 Generating {num_requests} requests: {description}")
        
        def worker():
            for i in range(num_requests // 10):  # Divide among workers
                self.make_request(NGINX_URL)
        
        # Use multiple threads for concurrent requests
        threads = []
        for _ in range(10):
            t = threading.Thread(target=worker)
            t.start()
            threads.append(t)
        
        for t in threads:
            t.join()
        
        logger.info(f"✅ Load generation complete: {num_requests} requests")
    
    def monitor_docker_logs(self, search_pattern, timeout=60):
        """Monitor docker logs for specific patterns"""
        import subprocess
        import re
        
        logger.info(f"👀 Monitoring logs for: {search_pattern}")
        
        # Start docker logs process
        cmd = ['docker', 'logs', 'alert_watcher', '--tail', '0', '-f']
        process = subprocess.Popen(
            cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            text=True
        )
        
        start_time = time.time()
        try:
            while time.time() - start_time < timeout:
                line = process.stdout.readline()
                if line:
                    print(f"📝 {line.strip()}")  # Show log activity
                    if re.search(search_pattern, line, re.IGNORECASE):
                        process.terminate()
                        logger.info(f"✅ Pattern detected: {search_pattern}")
                        return True
                time.sleep(0.1)
        except Exception as e:
            logger.error(f"Error monitoring logs: {e}")
        finally:
            process.terminate()
        
        logger.warning(f"❌ Pattern not detected within {timeout}s: {search_pattern}")
        return False
    
    def wait_with_progress(self, seconds, message="Waiting"):
        """Wait with progress indicator"""
        logger.info(f"⏳ {message} for {seconds}s")
        for i in range(seconds):
            print(f"\r⏳ {message}: {i+1}/{seconds}s", end="", flush=True)
            time.sleep(1)
        print()  # New line after progress
    
    def test_error_rate_alert(self):
        """Test high error rate alert"""
        logger.info("🧪 Starting Error Rate Alert Test")
        
        try:
            # Start chaos on both pools
            logger.info("🔴 Starting chaos mode on both pools")
            requests.post(f"{BLUE_URL}/chaos/start", timeout=5)
            requests.post(f"{GREEN_URL}/chaos/start", timeout=5)
            
            # Generate enough requests to trigger 2% threshold
            self.generate_load(REQUESTS_PER_TEST, "Triggering error rate threshold")
            
            # Monitor for error rate alert
            success = self.monitor_docker_logs("HIGH ERROR RATE")
            
            # Stop chaos
            logger.info("🟢 Stopping chaos mode")
            requests.post(f"{BLUE_URL}/chaos/stop", timeout=5)
            requests.post(f"{GREEN_URL}/chaos/stop", timeout=5)
            
            self.results['error_rate_test'] = success
            return success
            
        except Exception as e:
            logger.error(f"Error during error rate test: {e}")
            # Ensure chaos is stopped even on error
            try:
                requests.post(f"{BLUE_URL}/chaos/stop", timeout=5)
                requests.post(f"{GREEN_URL}/chaos/stop", timeout=5)
            except:
                pass
            return False
    
    def test_failover_alert(self):
        """Test failover alert"""
        logger.info("🧪 Starting Failover Alert Test")
        
        try:
            # Start chaos only on blue pool
            logger.info("🔴 Starting chaos mode on blue pool only")
            requests.post(f"{BLUE_URL}/chaos/start", timeout=5)
            
            # Generate load to trigger failover
            self.generate_load(REQUESTS_PER_TEST // 2, "Triggering blue→green failover")
            
            # Monitor for failover alert
            success = self.monitor_docker_logs("FAILOVER DETECTED.*blue.*green")
            
            # Stop chaos
            logger.info("🟢 Stopping chaos mode")
            requests.post(f"{BLUE_URL}/chaos/stop", timeout=5)
            
            self.results['failover_test'] = success
            return success
            
        except Exception as e:
            logger.error(f"Error during failover test: {e}")
            # Ensure chaos is stopped even on error
            try:
                requests.post(f"{BLUE_URL}/chaos/stop", timeout=5)
            except:
                pass
            return False
    
    def run_full_test_suite(self):
        """Run complete test suite"""
        logger.info("🚀 Starting Automated Test Suite")
        
        # Initial cooldown
        self.wait_with_progress(10, "Initial cooldown")
        
        # Test 1: Error Rate Alert
        error_test_success = self.test_error_rate_alert()
        
        # Wait for cooldown between tests
        self.wait_with_progress(COOLDOWN_PERIOD, "Cooldown between tests")
        
        # Test 2: Failover Alert
        failover_test_success = self.test_failover_alert()
        
        # Report results
        logger.info("📊 TEST RESULTS:")
        logger.info(f"  Error Rate Test: {'✅ PASS' if error_test_success else '❌ FAIL'}")
        logger.info(f"  Failover Test: {'✅ PASS' if failover_test_success else '❌ FAIL'}")
        
        if error_test_success and failover_test_success:
            logger.info("🎉 ALL TESTS PASSED! Both alerts are working correctly.")
        else:
            logger.error("💥 SOME TESTS FAILED! Check the logs above.")
        
        return error_test_success and failover_test_success

def main():
    tester = AutoTester()
    
    try:
        success = tester.run_full_test_suite()
        exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("Script interrupted by user")
        exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        exit(1)

if __name__ == "__main__":
    main()
