import os
import socket

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

MESSAGE = "Hello from AI-Powered DevOps!"
VERSION = os.getenv("APP_VERSION", "dev")
# Kubernetes sets POD_NAME (see k8s/deployment.yaml). Locally we fall back to the hostname.
POD_NAME = os.getenv("POD_NAME", socket.gethostname())

PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AI-Powered DevOps</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center;
           font-family: system-ui, sans-serif; background: #f3f5f7; color: #1f2933; }
    main { background: #fff; padding: 2rem 2.5rem; border-radius: 12px;
           box-shadow: 0 2px 12px rgba(0, 0, 0, .08); }
    h1 { margin-top: 0; color: #0f766e; }
    code { font-size: 1.05rem; }
  </style>
</head>
<body>
  <main>
    <h1>{{ message }}</h1>
    <p>Version: <code>{{ version }}</code></p>
    <p>Served by: <code>{{ pod }}</code></p>
  </main>
</body>
</html>
"""


@app.get("/")
def index():
    return render_template_string(PAGE, message=MESSAGE, version=VERSION, pod=POD_NAME)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", version=VERSION, pod=POD_NAME)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
