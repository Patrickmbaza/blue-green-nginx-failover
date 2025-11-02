#!/usr/bin/env python3
import os
import time
import logging
import requests
import re
from collections import deque
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger()

class SlackNotifier:
    def __init__(self):
        self.webhook_url = os.getenv('SLACK_WEBHOOK_URL')
        self.cooldown_sec = int(os.getenv('ALERT_COOLDOWN_SEC', 300))
        self.last_alert_time = {}

    def send_alert(self, alert_type, message):
        if not self.webhook_url:
            logger.warning("No Slack webhook configured")
            return False

        current_time = time.time()
        last_time = self.last_alert_time.get(alert_type, 0)

        if current_time - last_time < self.cooldown_sec:
            logger.info(f"Alert cooldown active for {alert_type}")
            return False

        try:
            if alert_type == "failover":
                if message['from_pool'] != message['to_pool']:
                    payload = {
                        "text": f":rotating_light: FAILOVER DETECTED",
                        "attachments": [
                            {
                                "color": "warning",
                                "fields": [
                                    {"title": "From", "value": message['from_pool'], "short": True},
                                    {"title": "To", "value": message['to_pool'], "short": True},
                                    {"title": "Time", "value": datetime.now().strftime('%d/%b/%Y:%H:%M:%S +0000'), "short": True},    
                                    {"title": "Release", "value": message['release'], "short": True},
                                    {"title": "Request", "value": "GET /version", "short": False}
                                ]
                            }
                        ]
                    }

                    response = requests.post(self.webhook_url, json=payload, timeout=10)
                    if response.status_code == 200:
                        self.last_alert_time[alert_type] = current_time
                        logger.info(f"✅ FAILOVER alert sent to Slack: {message['from_pool']} → {message['to_pool']}")
                        return True
                    else:
                        logger.error(f"Slack error: {response.status_code}")
                        return False
                else:
                    logger.info(f"Skipping failover alert: {message['from_pool']} → {message['to_pool']} (no actual change)")
                    return False

            elif alert_type == "error_rate":
                payload = {
                    "text": f":exclamation: HIGH ERROR RATE DETECTED",
                    "attachments": [
                        {
                            "color": "danger",
                            "fields": [
                                {"title": "Error Rate", "value": f"{message['error_rate']:.1f}%", "short": True},
                                {"title": "Threshold", "value": f"{message['threshold']}%", "short": True},
                                {"title": "Window Size", "value": str(message['total_requests']), "short": True},
                                {"title": "Time", "value": datetime.now().strftime('%d/%b/%Y:%H:%M:%S +0000'), "short": True},        
                                {"title": "Details", "value": f"{message['errors']} errors in last {message['total_requests']} requests", "short": False}
                            ]
                        }
                    ]
                }

                response = requests.post(self.webhook_url, json=payload, timeout=10)
                if response.status_code == 200:
                    self.last_alert_time[alert_type] = current_time
                    logger.info(f"✅ ERROR_RATE alert sent to Slack: {message['error_rate']:.1f}%")
                    return True
                else:
                    logger.error(f"Slack error: {response.status_code}")
                    return False

        except Exception as e:
            logger.error(f"Slack error: {e}")
            return False

class LogWatcher:
    def __init__(self):
        self.slack = SlackNotifier()
        self.window_size = int(os.getenv('WINDOW_SIZE', 200))
        self.error_threshold = float(os.getenv('ERROR_RATE_THRESHOLD', 2.0))
        self.request_window = deque(maxlen=self.window_size)
        self.last_release = os.getenv('ACTIVE_POOL', 'blue')
        self.maintenance_mode = os.getenv('MAINTENANCE_MODE', 'false').lower() == 'true'
        self.alert_sent_error_rate = False

    def parse_log_line(self, line):
        """Parse nginx log line and extract structured data"""
        try:
            data = {}

            # Extract HTTP status code
            status_match = re.search(r'" (\d{3}) ', line)
            if status_match:
                data['status'] = int(status_match.group(1))

            # Extract release and determine pool from it
            if 'release:' in line:
                release_full = line.split('release:')[1].split()[0]
                data['release'] = release_full
                # Extract pool from release (blue-1.0.0 -> blue)
                if '-' in release_full:
                    data['pool'] = release_full.split('-')[0]
                else:
                    data['pool'] = None

            data['timestamp'] = datetime.now()
            return data

        except Exception as e:
            logger.debug(f"Error parsing log line: {e}")
            return None

    def process_log_line(self, line):
        """Process a single log line and check for alerts"""
        if self.maintenance_mode:
            return

        data = self.parse_log_line(line)
        if not data:
            return

        # Track request for error rate calculation
        is_error = data.get('status', 200) >= 500
        self.request_window.append(is_error)

        # Check for failover using release field
        current_release = data.get('release')
        current_pool = data.get('pool')

        if current_release and current_release != self.last_release:
            # Extract pools from releases for the alert message
            from_pool = self.last_release.split('-')[0] if '-' in self.last_release else self.last_release
            to_pool = current_release.split('-')[0] if '-' in current_release else current_release

            logger.warning(f"🚨 FAILOVER DETECTED: {from_pool} → {to_pool}")

            # Send failover alert
            self.slack.send_alert("failover", {
                'from_pool': from_pool,
                'to_pool': to_pool,
                'release': current_release
            })
            self.last_release = current_release

        # Check error rate (only alert once per error condition)
        if len(self.request_window) >= 10:  # Minimum window for meaningful stats
            error_count = sum(self.request_window)
            total_requests = len(self.request_window)
            error_rate = (error_count / total_requests) * 100

            if error_rate > self.error_threshold and not self.alert_sent_error_rate:
                logger.warning(f"🚨 HIGH ERROR RATE: {error_rate:.1f}% ({error_count}/{total_requests})")
                if self.slack.send_alert("error_rate", {
                    'error_rate': error_rate,
                    'threshold': self.error_threshold,
                    'total_requests': total_requests,
                    'errors': error_count
                }):
                    self.alert_sent_error_rate = True
            elif error_rate <= self.error_threshold:
                self.alert_sent_error_rate = False

    def tail_logs(self, log_file):
        """Tail the nginx log file - FIXED VERSION that reads existing content"""
        logger.info(f"Starting to tail log file: {log_file}")

        # Wait for log file to exist
        while not os.path.exists(log_file):
            logger.info(f"Waiting for log file: {log_file}")
            time.sleep(2)

        logger.info("Log file found, starting to monitor...")

        # FIRST: Read all existing content to initialize the watcher state
        try:
            with open(log_file, 'r') as f:
                existing_lines = f.readlines()
                logger.info(f"Reading {len(existing_lines)} existing log lines...")
                
                for line_num, line in enumerate(existing_lines, 1):
                    line = line.strip()
                    if line:
                        logger.info(f"Processing existing line {line_num}: {line[:80]}...")
                        self.process_log_line(line)
                
                logger.info("Finished processing existing log content")
        except Exception as e:
            logger.error(f"Error reading existing log content: {e}")

        # SECOND: Now tail for new content
        last_size = os.path.getsize(log_file)
        logger.info(f"Starting to tail new content from position: {last_size}")

        while True:
            try:
                current_size = os.path.getsize(log_file)

                if current_size < last_size:
                    # File was truncated/rotated
                    logger.info("Log file was rotated, reopening from beginning...")
                    last_size = 0

                if current_size > last_size:
                    # New content available
                    with open(log_file, 'r') as f:
                        f.seek(last_size)
                        new_lines = f.readlines()
                        
                        if new_lines:
                            logger.info(f"Found {len(new_lines)} new log lines")
                            
                            for line in new_lines:
                                line = line.strip()
                                if line:
                                    logger.info(f"Processing new line: {line[:80]}...")
                                    self.process_log_line(line)

                        last_size = current_size
                else:
                    # No new content
                    time.sleep(0.5)

            except Exception as e:
                logger.error(f"Error in tail loop: {e}")
                time.sleep(2)

def main():
    logger.info("Starting Log Watcher Service")
    logger.info(f"Window size: {os.getenv('WINDOW_SIZE', '200')}, Error threshold: {os.getenv('ERROR_RATE_THRESHOLD', '2.0')}%")      

    if not os.getenv('SLACK_WEBHOOK_URL'):
        logger.warning("SLACK_WEBHOOK_URL not set - alerts will be logged but not sent")

    watcher = LogWatcher()

    # Start tailing nginx logs
    log_file = "/var/log/nginx/access.log"
    watcher.tail_logs(log_file)

if __name__ == "__main__":
    main()