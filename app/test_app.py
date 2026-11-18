import pytest

from app import MESSAGE, app


@pytest.fixture
def client():
    return app.test_client()


def test_message():
    assert MESSAGE == "Hello from AI-Powered DevOps!"


def test_index(client):
    res = client.get("/")
    assert res.status_code == 200
    assert MESSAGE in res.get_data(as_text=True)


def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200

    body = res.get_json()
    assert body["status"] == "ok"
    assert "version" in body
    assert "pod" in body
