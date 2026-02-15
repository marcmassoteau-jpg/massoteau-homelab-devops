"""Tests for the demo Flask application."""

import json
import pytest
from app import app


@pytest.fixture
def client():
    """Create a test client."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["name"] == "demo-app"
    assert "version" in data
    assert "environment" in data


def test_health(client):
    """Test health endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["status"] == "healthy"


def test_ready(client):
    """Test readiness endpoint."""
    response = client.get("/ready")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["status"] == "ready"


def test_version(client):
    """Test version endpoint."""
    response = client.get("/version")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "version" in data
    assert "environment" in data
    assert "timestamp" in data


def test_metrics(client):
    """Test metrics endpoint."""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"app_info" in response.data
