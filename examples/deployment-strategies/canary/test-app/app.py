#!/usr/bin/env python3
"""
Simple HTTP server for canary deployment testing
Provides health checks, metrics, and version identification
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import time
from datetime import datetime

VERSION = os.environ.get('VERSION', 'unknown')
FAIL_HEALTH = os.environ.get('FAIL_HEALTH', 'false').lower() == 'true'
REQUEST_COUNT = 0
START_TIME = time.time()


class RequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Log to stdout with timestamp"""
        print(f"[{datetime.now().isoformat()}] {format % args}")

    def do_GET(self):
        global REQUEST_COUNT
        REQUEST_COUNT += 1

        # Health check endpoint
        if self.path == '/health':
            if FAIL_HEALTH:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {'status': 'unhealthy', 'version': VERSION}
                self.wfile.write(json.dumps(response).encode())
            else:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {'status': 'healthy', 'version': VERSION}
                self.wfile.write(json.dumps(response).encode())
            return

        # Readiness check endpoint
        if self.path == '/ready':
            if FAIL_HEALTH:
                self.send_response(503)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {'status': 'not ready', 'version': VERSION}
                self.wfile.write(json.dumps(response).encode())
            else:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {'status': 'ready', 'version': VERSION}
                self.wfile.write(json.dumps(response).encode())
            return

        # Metrics endpoint
        if self.path == '/metrics':
            uptime = time.time() - START_TIME
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            metrics = f"""# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{{version="{VERSION}"}} {REQUEST_COUNT}

# HELP uptime_seconds Application uptime in seconds
# TYPE uptime_seconds gauge
uptime_seconds{{version="{VERSION}"}} {uptime:.2f}
"""
            self.wfile.write(metrics.encode())
            return

        # Root endpoint - returns version info
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = {
            'version': VERSION,
            'timestamp': datetime.now().isoformat(),
            'requests': REQUEST_COUNT,
            'uptime': time.time() - START_TIME
        }
        self.wfile.write(json.dumps(response, indent=2).encode())


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    server = HTTPServer(('0.0.0.0', port), RequestHandler)
    print(f"Starting server on port {port}, version={VERSION}, fail_health={FAIL_HEALTH}")
    server.serve_forever()
