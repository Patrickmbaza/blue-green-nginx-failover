#!/usr/bin/env python3
"""
Alert Watcher for Blue-Green Nginx Failover
- Matches EXACT Stage 3 requirements
- 2% error rate threshold with 200 request window
- 300 second cooldown for all alerts
- Maintenance mode support
- Active pool tracking
"""

import os
import time
import re
import logging
from typing import Optional, Dict, List
import requests
import json

# Configuration from environment variables - EXACTLY as required
LOG_FILE = "/var/log/nginx/access.log"
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")
ERROR_RATE_THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", "2.0"))
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", "200"))
ALERT_COOLDOWN_SEC = int(os.getenv("ALERT_COOLDOWN_SEC", "300"))
ACTIVE_POOL = os.getenv("ACTIVE_POOL", "blue")
MAINTENANCE_MODE = os.getenv("MAINTENANCE_MODE", "false").lower() == "true"

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class FailoverDetector:
    """Failover detection with maintenance mode support"""
    
    def __init__(self):
        self.last_pool: Optional[str] = None
        self.last_alert_time: float = 0
        self.initialized: bool = False
        
    def detect_failover(self, current_pool: str) -> tuple[bool, Optional[str], Optional[str]]:
        """
        Detect failover events with cooldown
        
        Args:
            current_pool: Current pool name from log
            
        Returns:
            tuple: (is_failover, from_pool, to_pool)
        """
        # Skip if maintenance mode is enabled
        if MAINTENANCE_MODE:
            return False, None, None
            
        # Validate pool name
        if not self._is_valid_pool(current_pool):
            return False, None, None
            
        current_time = time.time()
        
        # Initialize on first valid pool
        if not self.initialized:
            self.last_pool = current_pool
            self.initialized = True
            logger.info(f"Initialized failover detector with pool: {current_pool}")
            return False, None, None
        
        # Check for pool change
        if self.last_pool and self.last_pool != current_pool:
            from_pool = self.last_pool
            to_pool = current_pool
            
            # Cooldown check
            if current_time - self.last_alert_time < ALERT_COOLDOWN_SEC:
                logger.info(f"Alert cooldown active for failover: {from_pool} → {to_pool}")
                self.last_pool = current_pool
                return False, None, None
            
            logger.warning(f"🚨 FAILOVER DETECTED: {from_pool} → {to_pool}")
            self.last_pool = current_pool
            self.last_alert_time = current_time
            return True, from_pool, to_pool
            
        # Update current pool
        self.last_pool = current_pool
        return False, None, None
    
    def _is_valid_pool(self, pool: str) -> bool:
        """Validate pool name"""
        return pool and pool.strip() and pool in ['blue', 'green']


class ErrorRateMonitor:
    """Monitor error rates with 200 request window and 2% threshold"""
    
    def __init__(self):
        self.request_window: List[bool] = []  # True = error, False = success
        self.last_alert_time: float = 0
        
    def add_request(self, status_code: int):
        """Add request to monitoring window"""
        is_error = status_code >= 500  # Consider 5xx as errors
        self.request_window.append(is_error)
        
        # Maintain window size
        if len(self.request_window) > WINDOW_SIZE:
            self.request_window.pop(0)
    
    def should_alert(self) -> bool:
        """Check if error rate exceeds 2% threshold and cooldown has passed"""
        # Skip if maintenance mode is enabled
        if MAINTENANCE_MODE:
            return False
            
        if len(self.request_window) < WINDOW_SIZE:
            return False
            
        current_time = time.time()
        if current_time - self.last_alert_time < ALERT_COOLDOWN_SEC:
            return False
            
        error_count = sum(self.request_window)
        error_rate = (error_count / len(self.request_window)) * 100
        
        if error_rate >= ERROR_RATE_THRESHOLD:
            self.last_alert_time = current_time
            logger.warning(f"🚨 HIGH ERROR RATE: {error_rate:.1f}% ({error_count}/{len(self.request_window)}) - Threshold: {ERROR_RATE_THRESHOLD}%")
            return True
            
        return False
    
    def get_error_rate(self) -> float:
        """Get current error rate"""
        if not self.request_window:
            return 0.0
        return (sum(self.request_window) / len(self.request_window)) * 100


class AlertHandler:
    """Handle alert delivery to Slack"""
    
    def __init__(self):
        self.last_alert_times: Dict[str, float] = {}
        
    def send_slack_alert(self, message: str, alert_type: str = "info"):
        """Send alert to Slack"""
        if not SLACK_WEBHOOK_URL:
            logger.warning("Slack webhook URL not configured")
            return False
            
        # Skip if maintenance mode is enabled
        if MAINTENANCE_MODE:
            logger.info("Maintenance mode active - skipping alert")
            return False
            
        # Cooldown check
        current_time = time.time()
        if alert_type in self.last_alert_times:
            if current_time - self.last_alert_times[alert_type] < ALERT_COOLDOWN_SEC:
                logger.info(f"Alert cooldown active for {alert_type}")
                return False
        
        try:
            # Create Slack message
            if "failover" in alert_type:
                color = "warning"
                title = "🚨 Failover Detected"
            elif "error_rate" in alert_type:
                color = "danger" 
                title = "🚨 High Error Rate"
            else:
                color = "good"
                title = "ℹ️ Alert"
            
            payload = {
                "attachments": [
                    {
                        "color": color,
                        "title": title,
                        "text": message,
                        "ts": time.time(),
                        "footer": "Nginx Failover Monitor - Stage 3",
                        "fields": [
                            {
                                "title": "Environment",
                                "value": "Production",
                                "short": True
                            },
                            {
                                "title": "Maintenance Mode",
                                "value": "Enabled" if MAINTENANCE_MODE else "Disabled",
                                "short": True
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(
                SLACK_WEBHOOK_URL,
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                self.last_alert_times[alert_type] = current_time
                logger.info(f"✅ {alert_type.upper()} alert sent to Slack: {message}")
                return True
            else:
                logger.error(f"Failed to send Slack alert: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending Slack alert: {e}")
            return False
    
    def send_failover_alert(self, from_pool: str, to_pool: str):
        """Send failover alert"""
        message = f"Failover from *{from_pool}* → *{to_pool}*"
        return self.send_slack_alert(message, "failover")
    
    def send_error_rate_alert(self, error_rate: float, error_count: int):
        """Send error rate alert"""
        message = f"High error rate detected: *{error_rate:.1f}%* ({error_count}/{WINDOW_SIZE} requests)\n*Threshold: {ERROR_RATE_THRESHOLD}%*"
        return self.send_slack_alert(message, "error_rate")


class LogProcessor:
    """Process nginx access logs"""
    
    def __init__(self):
        self.failover_detector = FailoverDetector()
        self.error_monitor = ErrorRateMonitor()
        self.alert_handler = AlertHandler()
        self.last_position = 0
        
    def extract_pool_from_line(self, line: str) -> Optional[str]:
        """Extract pool name from log line"""
        try:
            # Look for pool:xxx pattern in the log
            pool_match = re.search(r'pool:(\w+)', line)
            if pool_match:
                pool = pool_match.group(1).strip().lower()
                if pool in ['blue', 'green']:
                    return pool
                    
            # Alternative: look for release:xxx pattern
            release_match = re.search(r'release:(\w+)-', line)
            if release_match:
                pool = release_match.group(1).strip().lower()
                if pool in ['blue', 'green']:
                    return pool
                    
            return None
        except Exception as e:
            logger.debug(f"Error extracting pool from line: {e}")
            return None
    
    def extract_status_code(self, line: str) -> Optional[int]:
        """Extract HTTP status code from log line"""
        try:
            # Look for HTTP status code pattern
            status_match = re.search(r'"\s+(\d{3})\s+', line)
            if status_match:
                return int(status_match.group(1))
            return None
        except Exception as e:
            logger.debug(f"Error extracting status code: {e}")
            return None
    
    def process_line(self, line: str):
        """Process a single log line"""
        if not line.strip():
            return
            
        # Extract pool information
        current_pool = self.extract_pool_from_line(line)
        if current_pool:
            # Check for failover
            is_failover, from_pool, to_pool = self.failover_detector.detect_failover(current_pool)
            if is_failover and from_pool and to_pool:
                self.alert_handler.send_failover_alert(from_pool, to_pool)
        
        # Extract status code for error monitoring
        status_code = self.extract_status_code(line)
        if status_code:
            self.error_monitor.add_request(status_code)
            
            # Check error rate
            if self.error_monitor.should_alert():
                error_rate = self.error_monitor.get_error_rate()
                error_count = sum(self.error_monitor.request_window)
                self.alert_handler.send_error_rate_alert(error_rate, error_count)
    
    def process_existing_logs(self):
        """Process existing log content on startup"""
        logger.info("Processing existing log content...")
        logger.info(f"Configuration: {WINDOW_SIZE} request window, {ERROR_RATE_THRESHOLD}% threshold, {ALERT_COOLDOWN_SEC}s cooldown")
        logger.info(f"Active pool: {ACTIVE_POOL}, Maintenance mode: {MAINTENANCE_MODE}")
        
        try:
            with open(LOG_FILE, 'r') as f:
                # Skip already processed lines
                if self.last_position > 0:
                    f.seek(self.last_position)
                
                line_count = 0
                for line in f:
                    self.process_line(line)
                    line_count += 1
                    
                self.last_position = f.tell()
                logger.info(f"Processed {line_count} existing log lines")
                
            logger.info("Finished processing existing log content")
        except Exception as e:
            logger.error(f"Error processing existing logs: {e}")
    
    def tail_logs(self):
        """Tail new log entries"""
        logger.info(f"Starting to tail new content from position: {self.last_position}")
        
        try:
            with open(LOG_FILE, 'r') as f:
                # Seek to last position
                if self.last_position > 0:
                    f.seek(self.last_position)
                else:
                    # Start from end if no previous position
                    f.seek(0, 2)
                    self.last_position = f.tell()
                
                while True:
                    line = f.readline()
                    if line:
                        self.process_line(line)
                        self.last_position = f.tell()
                    else:
                        time.sleep(1)  # Wait for new content
                        
        except Exception as e:
            logger.error(f"Error tailing logs: {e}")
            time.sleep(5)  # Wait before retrying
            self.tail_logs()  # Recursive retry


def main():
    """Main application entry point"""
    logger.info("Starting Stage 3 Alert Watcher...")
    logger.info(f"Monitoring log file: {LOG_FILE}")
    
    if not os.path.exists(LOG_FILE):
        logger.error(f"Log file not found: {LOG_FILE}")
        return
    
    processor = LogProcessor()
    
    # Process existing logs first
    processor.process_existing_logs()
    
    # Start tailing new logs
    processor.tail_logs()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Alert watcher stopped by user")
    except Exception as e:
        logger.error(f"Alert watcher crashed: {e}")
        raise