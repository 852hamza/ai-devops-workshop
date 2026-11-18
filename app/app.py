import hashlib
import os
import socket
import time

from flask import Flask, jsonify, render_template_string, request

app = Flask(__name__)

MESSAGE = "Hello from AI-Powered DevOps!"
VERSION = os.getenv("APP_VERSION", "dev")
# Kubernetes sets POD_NAME (see k8s/deployment.yaml). Locally we fall back to the hostname.
POD_NAME = os.getenv("POD_NAME", socket.gethostname())
STARTED_AT = time.time()

PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  {% if watch %}<meta http-equiv="refresh" content="2">{% endif %}
  <title>AI-Powered DevOps</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center;
           font-family: system-ui, sans-serif; background: #f3f5f7; color: #1f2933; }
    main { background: #fff; padding: 2rem 2.5rem; border-radius: 12px;
           border-top: 8px solid {{ color }}; box-shadow: 0 2px 12px rgba(0, 0, 0, .08); }
    h1 { margin-top: 0; color: {{ color }}; }
    dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem 1.2rem; margin: 0; }
    dt { color: #616e7c; }
    dd { margin: 0; font-family: ui-monospace, monospace; }
  </style>
</head>
<body>
  <main>
    <h1>{{ message }}</h1>
    <dl>
      <dt>Version</dt><dd>{{ version }}</dd>
      <dt>Pod</dt><dd>{{ pod }}</dd>
      <dt>Uptime</dt><dd>{{ uptime }}</dd>
    </dl>
  </main>
</body>
</html>
"""


def version_color(version):
    # Same version -> same colour, so you can see a new release go live.
    hue = int(hashlib.sha256(version.encode()).hexdigest()[:4], 16) % 360
    return f"hsl({hue} 60% 38%)"


def uptime():
    seconds = int(time.time() - STARTED_AT)
    minutes, seconds = divmod(seconds, 60)
    return f"{minutes}m {seconds}s" if minutes else f"{seconds}s"


@app.get("/")
def index():
    return render_template_string(
        PAGE,
        message=MESSAGE,
        version=VERSION,
        pod=POD_NAME,
        uptime=uptime(),
        color=version_color(VERSION),
        watch="watch" in request.args,  # open /?watch to auto-refresh every 2s
    )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", version=VERSION, pod=POD_NAME, uptime=uptime())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
