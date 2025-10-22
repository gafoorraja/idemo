#!/usr/bin/env python3
"""
Simple Hello World microservice for interview demo
Provides health check and basic API endpoints
"""

from flask import Flask, jsonify
import os
import socket
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    """Main hello world endpoint"""
    return jsonify({
        "message": "Hello World from Python microservice!",
        "timestamp": datetime.utcnow().isoformat(),
        "hostname": socket.gethostname(),
        "version": "1.0.0"
    })

@app.route('/health')
def health():
    """Health check endpoint for load balancers and monitoring"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "hello-world-python",
        "version": "1.0.0"
    })

@app.route('/ready')
def ready():
    """Readiness check endpoint"""
    return jsonify({
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "hello-world-python"
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8085))
    host = os.environ.get('HOST', '0.0.0.0')
    
    print(f"Starting Hello World microservice on {host}:{port}")
    app.run(host=host, port=port, debug=False)
