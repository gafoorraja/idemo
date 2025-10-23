import unittest
import pytest

from demo.quickapp import app

# pylint & mbalck 
def test_app_running():
    # Placeholder test to ensure the app module loads correctly    
    pytest.raises(Exception, lambda: None)  # Dummy assertion to use pytest
    assert app is not None

def test_hello_endpoint():
    tester = app.test_client()
    response = tester.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert data["message"] == "Hello World from Python microservice!"
    assert "timestamp" in data
    assert "hostname" in data
    assert data["version"] == "1.0.0"
