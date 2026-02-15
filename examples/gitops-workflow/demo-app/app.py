"""
Demo Flask Application for GitOps Workflow
Demonstrates the hybrid CI/CD + GitOps deployment pattern.

GitLab CI builds, tests, and packages this application.
ArgoCD deploys it to Kubernetes from the GitOps repository.
"""

import os
import json
from datetime import datetime, timezone
from flask import Flask, jsonify

app = Flask(__name__)

# Configuration from environment
APP_ENV = os.getenv("APP_ENV", "development")
APP_VERSION = os.getenv("APP_VERSION", "0.0.1")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info")
APP_TRACK = os.getenv("APP_TRACK", "stable")


@app.route("/")
def index():
    """Root endpoint returning application information."""
    return jsonify({
        "name": "demo-app",
        "version": APP_VERSION,
        "environment": APP_ENV,
        "track": APP_TRACK,
        "message": "Hello from the GitOps demo application!",
    })


@app.route("/health")
def health():
    """Liveness probe endpoint."""
    return jsonify({"status": "healthy"}), 200


@app.route("/ready")
def ready():
    """Readiness probe endpoint."""
    return jsonify({"status": "ready"}), 200


@app.route("/version")
def version():
    """Version information endpoint."""
    return jsonify({
        "version": APP_VERSION,
        "environment": APP_ENV,
        "track": APP_TRACK,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })


@app.route("/metrics")
def metrics():
    """Basic metrics endpoint (Prometheus-compatible in production)."""
    return (
        f'# HELP app_info Application information\n'
        f'# TYPE app_info gauge\n'
        f'app_info{{version="{APP_VERSION}",env="{APP_ENV}",track="{APP_TRACK}"}} 1\n'
    ), 200, {"Content-Type": "text/plain"}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    debug = APP_ENV == "development"
    app.run(host="0.0.0.0", port=port, debug=debug)
