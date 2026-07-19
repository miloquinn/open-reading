from __future__ import annotations

import hashlib
import io
import json
from collections import deque
from pathlib import Path
from urllib.parse import SplitResult

import pytest

from scripts import verify_official_download as verifier

VERSION = "2.2.0"
BUILD_NUMBER = "14119"
DOWNLOAD_URL = "https://open.xxread.top/download/file/release-arm64"


class _FakeSocket:
    def __init__(self) -> None:
        self.timeouts: list[float] = []

    def settimeout(self, timeout: float) -> None:
        self.timeouts.append(timeout)


class _FakeResponse:
    def __init__(
        self,
        status: int,
        *,
        body: bytes = b"",
        headers: dict[str, str] | None = None,
        reason: str = "OK",
    ) -> None:
        self.status = status
        self.reason = reason
        self._body = io.BytesIO(body)
        self._headers = headers or {}
        self.closed = False

    def getheader(self, name: str) -> str | None:
        return self._headers.get(name)

    def read(self, amount: int) -> bytes:
        return self._body.read(amount)

    def read1(self, amount: int) -> bytes:
        return self._body.read(amount)

    def close(self) -> None:
        self.closed = True


class _FakeConnection:
    def __init__(self, response: _FakeResponse, url: str, timeout: float) -> None:
        self.response = response
        self.url = url
        self.initial_timeout = timeout
        self.sock = _FakeSocket()
        self.requests: list[tuple[str, str, dict[str, str]]] = []
        self.closed = False

    def request(self, method: str, target: str, *, headers: dict[str, str]) -> None:
        self.requests.append((method, target, headers))

    def getresponse(self) -> _FakeResponse:
        return self.response

    def close(self) -> None:
        self.closed = True


def _write_contract(
    tmp_path: Path,
    payload: bytes,
    *,
    asset_overrides: dict[str, object] | None = None,
    response_overrides: dict[str, object] | None = None,
) -> tuple[Path, Path, Path]:
    digest = hashlib.sha256(payload).hexdigest()
    asset: dict[str, object] = {
        "filename": f"OpenReading-Android-arm64-v8a-{VERSION}.apk",
        "platform": "android",
        "package_type": "apk",
        "architecture": "arm64-v8a",
        "build_number": BUILD_NUMBER,
        "size": len(payload),
        "sha256": digest,
    }
    asset.update(asset_overrides or {})
    manifest = {
        "schema_version": 1,
        "tag": f"v{VERSION}",
        "version": VERSION,
        "build_number": "12119",
        "channel": "stable",
        "assets": [asset],
    }
    latest: dict[str, object] = {
        "schema_version": 1,
        "version": VERSION,
        "build_number": BUILD_NUMBER,
        "platform": "android",
        "architecture": "arm64-v8a",
        "package_type": "apk",
        "channel": "stable",
        "download_url": DOWNLOAD_URL,
        "sha256": asset["sha256"],
        "file_size": asset["size"],
    }
    latest.update(response_overrides or {})

    manifest_path = tmp_path / "release-manifest.json"
    response_path = tmp_path / "official-latest.json"
    output_path = tmp_path / "verified-arm64.apk"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    response_path.write_text(json.dumps(latest), encoding="utf-8")
    return manifest_path, response_path, output_path


def _install_responses(
    monkeypatch: pytest.MonkeyPatch, responses: list[_FakeResponse]
) -> list[_FakeConnection]:
    queued = deque(responses)
    connections: list[_FakeConnection] = []

    def open_connection(parsed: SplitResult, timeout: float) -> _FakeConnection:
        if not queued:
            raise AssertionError("the verifier made an unexpected network request")
        connection = _FakeConnection(queued.popleft(), parsed.geturl(), timeout)
        connections.append(connection)
        return connection

    monkeypatch.setattr(verifier, "_open_connection", open_connection)
    return connections


def test_downloads_and_verifies_arm64_apk_through_same_host_redirect(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = b"PK\x03\x04official-arm64-apk"
    manifest, response, output = _write_contract(tmp_path, payload)
    connections = _install_responses(
        monkeypatch,
        [
            _FakeResponse(302, headers={"Location": "/files/release-arm64/app.apk"}),
            _FakeResponse(
                200,
                body=payload,
                headers={"Content-Length": str(len(payload))},
            ),
        ],
    )

    result = verifier.verify_official_download(
        manifest,
        response,
        output,
        idle_timeout=5,
        total_timeout=30,
    )

    assert result == output
    assert output.read_bytes() == payload
    assert not output.with_name(f"{output.name}.part").exists()
    assert [connection.url for connection in connections] == [
        DOWNLOAD_URL,
        "https://open.xxread.top/files/release-arm64/app.apk",
    ]
    assert connections[1].sock.timeouts
    assert max(connections[1].sock.timeouts) <= 5
    assert all(connection.closed and connection.response.closed for connection in connections)


def test_rejects_hash_mismatch_and_removes_partial_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = b"official-arm64-apk"
    wrong_digest = hashlib.sha256(b"different-build").hexdigest()
    manifest, response, output = _write_contract(
        tmp_path,
        payload,
        asset_overrides={"sha256": wrong_digest},
        response_overrides={"sha256": wrong_digest},
    )
    part_path = output.with_name(f"{output.name}.part")
    part_path.write_bytes(b"stale-partial-download")
    _install_responses(
        monkeypatch,
        [
            _FakeResponse(
                200,
                body=payload,
                headers={"Content-Length": str(len(payload))},
            )
        ],
    )

    with pytest.raises(verifier.VerificationError, match="SHA-256"):
        verifier.verify_official_download(manifest, response, output)

    assert not part_path.exists()
    assert not output.exists()


def test_rejects_asset_over_512_mib_before_network_access(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    declared_size = verifier.MAX_DOWNLOAD_BYTES + 1
    manifest, response, output = _write_contract(
        tmp_path,
        b"small-payload",
        asset_overrides={"size": declared_size},
        response_overrides={"file_size": declared_size},
    )
    connections = _install_responses(monkeypatch, [])

    with pytest.raises(verifier.VerificationError, match="download limit"):
        verifier.verify_official_download(manifest, response, output)

    assert connections == []
    assert not output.exists()


@pytest.mark.parametrize(
    "download_url",
    [
        "http://open.xxread.top/download/file/release-arm64",
        "https://downloads.xxread.top/app.apk",
        "https://open.xxread.top@attacker.example/app.apk",
        "https://open.xxread.top:8443/app.apk",
    ],
    ids=["non-https", "different-host", "userinfo-confusion", "nonstandard-port"],
)
def test_rejects_untrusted_download_url_before_network_access(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, download_url: str
) -> None:
    manifest, response, output = _write_contract(
        tmp_path,
        b"official-arm64-apk",
        response_overrides={"download_url": download_url},
    )
    connections = _install_responses(monkeypatch, [])

    with pytest.raises(verifier.VerificationError):
        verifier.verify_official_download(manifest, response, output)

    assert connections == []


@pytest.mark.parametrize(
    "redirect_url",
    [
        "https://cdn.example.com/app.apk",
        "http://open.xxread.top/files/app.apk",
        "//attacker.example/app.apk",
    ],
    ids=["cross-domain", "https-downgrade", "scheme-relative-cross-domain"],
)
def test_rejects_cross_domain_or_non_https_redirect(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, redirect_url: str
) -> None:
    manifest, response, output = _write_contract(tmp_path, b"official-arm64-apk")
    connections = _install_responses(
        monkeypatch,
        [_FakeResponse(302, headers={"Location": redirect_url})],
    )

    with pytest.raises(verifier.VerificationError):
        verifier.verify_official_download(manifest, response, output)

    assert len(connections) == 1
    assert not output.with_name(f"{output.name}.part").exists()


@pytest.mark.parametrize(
    "overrides",
    [
        {"version": "2.2.1"},
        {"build_number": "14120"},
        {"architecture": "x86_64"},
        {"file_size": 999},
        {"sha256": "f" * 64},
    ],
    ids=["version", "build", "architecture", "size", "sha256"],
)
def test_rejects_latest_metadata_that_does_not_match_manifest(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    overrides: dict[str, object],
) -> None:
    manifest, response, output = _write_contract(
        tmp_path,
        b"official-arm64-apk",
        response_overrides=overrides,
    )
    connections = _install_responses(monkeypatch, [])

    with pytest.raises(verifier.VerificationError, match="did not match"):
        verifier.verify_official_download(manifest, response, output)

    assert connections == []


def test_rejects_body_that_exceeds_declared_size(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = b"official-arm64-apk"
    declared_size = len(payload) - 1
    manifest, response, output = _write_contract(
        tmp_path,
        payload,
        asset_overrides={"size": declared_size},
        response_overrides={"file_size": declared_size},
    )
    _install_responses(monkeypatch, [_FakeResponse(200, body=payload)])

    with pytest.raises(verifier.VerificationError, match="exceeded its declared file size"):
        verifier.verify_official_download(manifest, response, output)

    assert not output.exists()
    assert not output.with_name(f"{output.name}.part").exists()


def test_enforces_total_download_deadline_and_removes_partial_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = b"official-arm64-apk"
    manifest, response, output = _write_contract(tmp_path, payload)
    _install_responses(monkeypatch, [_FakeResponse(200, body=payload)])
    timestamps = iter((0.0, 0.0, 0.0, 0.0, 2.0))
    monkeypatch.setattr(verifier.time, "monotonic", lambda: next(timestamps))

    with pytest.raises(verifier.VerificationError, match="total time limit"):
        verifier.verify_official_download(
            manifest,
            response,
            output,
            idle_timeout=1,
            total_timeout=1,
        )

    assert not output.exists()
    assert not output.with_name(f"{output.name}.part").exists()
