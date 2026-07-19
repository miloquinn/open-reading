#!/usr/bin/env python3
"""Verify that the official-site arm64 APK is the release artifact just mirrored."""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import math
import os
import re
import ssl
import sys
import time
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import SplitResult, urljoin, urlsplit

OFFICIAL_HOST = "open.xxread.top"
MAX_DOWNLOAD_BYTES = 512 * 1024 * 1024
DEFAULT_IDLE_TIMEOUT_SECONDS = 30.0
DEFAULT_TOTAL_TIMEOUT_SECONDS = 15 * 60.0
MAX_REDIRECTS = 5
CHUNK_SIZE = 1024 * 1024
SHA256_PATTERN = re.compile(r"[0-9a-fA-F]{64}")
REDIRECT_STATUSES = frozenset({301, 302, 303, 307, 308})


class VerificationError(RuntimeError):
    """Raised when official release metadata or bytes violate the release contract."""


@dataclass(frozen=True, slots=True)
class ExpectedDownload:
    url: str
    size: int
    sha256: str


def _load_json_object(path: Path, label: str) -> dict[str, object]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise VerificationError(f"{label} is not valid JSON: {error}") from error
    if not isinstance(payload, dict):
        raise VerificationError(f"{label} must contain a JSON object")
    return payload


def _required_text(payload: dict[str, object], field: str, label: str) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value or value != value.strip():
        raise VerificationError(f"{label} field {field!r} must be a non-empty string")
    return value


def _build_number(value: object, label: str) -> str:
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise VerificationError(f"{label} must be a numeric build number")
    normalized = str(value)
    if not normalized.isdigit():
        raise VerificationError(f"{label} must be a numeric build number")
    return normalized


def _size(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise VerificationError(f"{label} must be a positive integer")
    if value > MAX_DOWNLOAD_BYTES:
        raise VerificationError(
            f"{label} exceeds the {MAX_DOWNLOAD_BYTES}-byte download limit"
        )
    return value


def _sha256(value: object, label: str) -> str:
    if not isinstance(value, str) or SHA256_PATTERN.fullmatch(value) is None:
        raise VerificationError(f"{label} must be a 64-character SHA-256 digest")
    return value.lower()


def _validate_url(value: str, label: str) -> SplitResult:
    has_control_character = any(
        ord(character) < 32 or ord(character) == 127 for character in value
    )
    if value != value.strip() or has_control_character:
        raise VerificationError(f"{label} contains whitespace or control characters")
    parsed = urlsplit(value)
    try:
        port = parsed.port
    except ValueError as error:
        raise VerificationError(f"{label} has an invalid port") from error
    if parsed.scheme.lower() != "https":
        raise VerificationError(f"{label} must use HTTPS")
    if parsed.hostname != OFFICIAL_HOST:
        raise VerificationError(f"{label} must stay on {OFFICIAL_HOST}")
    if parsed.username is not None or parsed.password is not None:
        raise VerificationError(f"{label} must not contain user credentials")
    if parsed.fragment:
        raise VerificationError(f"{label} must not contain a URL fragment")
    if port not in (None, 443):
        raise VerificationError(f"{label} must use the standard HTTPS port")
    return parsed


def _select_expected_download(
    manifest: dict[str, object], latest: dict[str, object]
) -> ExpectedDownload:
    if manifest.get("schema_version") != 1:
        raise VerificationError("release manifest schema_version must be 1")
    if latest.get("schema_version") != 1:
        raise VerificationError("official latest response schema_version must be 1")

    version = _required_text(manifest, "version", "release manifest")
    if _required_text(manifest, "channel", "release manifest") != "stable":
        raise VerificationError("release manifest channel must be 'stable'")

    raw_assets = manifest.get("assets")
    if not isinstance(raw_assets, list):
        raise VerificationError("release manifest field 'assets' must be a list")
    matches: list[dict[str, object]] = []
    for asset in raw_assets:
        if not isinstance(asset, dict):
            raise VerificationError("every release manifest asset must be an object")
        if asset.get("platform") == "android" and asset.get("architecture") == "arm64-v8a":
            matches.append(asset)
    if len(matches) != 1:
        raise VerificationError(
            "release manifest must contain exactly one android/arm64-v8a asset"
        )

    asset = matches[0]
    if asset.get("package_type") != "apk":
        raise VerificationError("android/arm64-v8a manifest asset must be an APK")
    asset_build = _build_number(
        asset.get("build_number"), "android/arm64-v8a manifest asset build_number"
    )
    asset_size = _size(asset.get("size"), "android/arm64-v8a manifest asset size")
    asset_sha256 = _sha256(
        asset.get("sha256"), "android/arm64-v8a manifest asset sha256"
    )

    expected_fields = {
        "version": version,
        "platform": "android",
        "architecture": "arm64-v8a",
        "package_type": "apk",
        "channel": "stable",
    }
    for field, expected in expected_fields.items():
        actual = latest.get(field)
        if actual != expected:
            raise VerificationError(
                f"official latest field {field!r} did not match the release manifest"
            )

    latest_build = _build_number(latest.get("build_number"), "official latest build_number")
    if latest_build != asset_build:
        raise VerificationError(
            "official latest field 'build_number' did not match the arm64 APK"
        )
    latest_size = _size(latest.get("file_size"), "official latest file_size")
    if latest_size != asset_size:
        raise VerificationError(
            "official latest field 'file_size' did not match the arm64 APK"
        )
    latest_sha256 = _sha256(latest.get("sha256"), "official latest sha256")
    if latest_sha256 != asset_sha256:
        raise VerificationError(
            "official latest field 'sha256' did not match the arm64 APK"
        )

    download_url = _required_text(latest, "download_url", "official latest response")
    _validate_url(download_url, "official latest download_url")
    return ExpectedDownload(url=download_url, size=asset_size, sha256=asset_sha256)


def _remaining_seconds(deadline: float) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise VerificationError("official APK download exceeded its total time limit")
    return remaining


def _open_connection(parsed: SplitResult, timeout: float) -> http.client.HTTPSConnection:
    return http.client.HTTPSConnection(
        parsed.hostname,
        port=parsed.port,
        timeout=timeout,
        context=ssl.create_default_context(),
    )


def _set_socket_timeout(
    response: http.client.HTTPResponse,
    connection: object,
    timeout: float,
) -> None:
    sock = getattr(connection, "sock", None)
    if sock is None:
        response_file = getattr(response, "fp", None)
        raw_socket_file = getattr(response_file, "raw", None)
        sock = getattr(raw_socket_file, "_sock", None)
    if sock is not None:
        sock.settimeout(timeout)


def _request_target(parsed: SplitResult) -> str:
    target = parsed.path or "/"
    if parsed.query:
        target = f"{target}?{parsed.query}"
    return target


def _close_quietly(resource: object | None) -> None:
    if resource is None:
        return
    with suppress(OSError):
        resource.close()  # type: ignore[attr-defined]


def _stream_response(
    response: http.client.HTTPResponse,
    connection: http.client.HTTPSConnection,
    destination: Path,
    expected: ExpectedDownload,
    *,
    idle_timeout: float,
    deadline: float,
) -> None:
    content_length = response.getheader("Content-Length")
    if content_length is not None:
        try:
            response_size = int(content_length)
        except ValueError as error:
            raise VerificationError(
                "official APK response has an invalid Content-Length"
            ) from error
        if response_size != expected.size:
            raise VerificationError(
                "official APK Content-Length did not match the declared file size"
            )

    digest = hashlib.sha256()
    received = 0
    with destination.open("wb") as output:
        while True:
            remaining = _remaining_seconds(deadline)
            _set_socket_timeout(response, connection, min(idle_timeout, remaining))
            read_size = min(CHUNK_SIZE, expected.size - received + 1)
            chunk = response.read1(read_size)
            _remaining_seconds(deadline)
            if not chunk:
                break
            received += len(chunk)
            if received > expected.size:
                raise VerificationError("official APK exceeded its declared file size")
            digest.update(chunk)
            output.write(chunk)
        output.flush()
        os.fsync(output.fileno())

    if received != expected.size:
        raise VerificationError(
            f"official APK size mismatch: expected {expected.size} bytes, received {received}"
        )
    if digest.hexdigest() != expected.sha256:
        raise VerificationError("official APK SHA-256 did not match the release manifest")


def _download(
    expected: ExpectedDownload,
    destination: Path,
    *,
    idle_timeout: float,
    total_timeout: float,
) -> None:
    deadline = time.monotonic() + total_timeout
    current_url = expected.url
    for redirect_count in range(MAX_REDIRECTS + 1):
        parsed = _validate_url(current_url, "official APK URL")
        connection: http.client.HTTPSConnection | None = None
        response: http.client.HTTPResponse | None = None
        try:
            remaining = _remaining_seconds(deadline)
            connection = _open_connection(parsed, min(idle_timeout, remaining))
            connection.request(
                "GET",
                _request_target(parsed),
                headers={
                    "Accept": "application/vnd.android.package-archive, application/octet-stream",
                    "Accept-Encoding": "identity",
                    "Connection": "close",
                    "User-Agent": "open-reading-release-verifier/1",
                },
            )
            response = connection.getresponse()
            _remaining_seconds(deadline)
            if response.status in REDIRECT_STATUSES:
                location = response.getheader("Location")
                if not location:
                    raise VerificationError("official APK redirect has no Location header")
                if redirect_count >= MAX_REDIRECTS:
                    raise VerificationError("official APK exceeded the redirect limit")
                redirected_url = urljoin(current_url, location)
                _validate_url(redirected_url, "official APK redirect URL")
                current_url = redirected_url
                continue
            if response.status != 200:
                raise VerificationError(
                    f"official APK download returned HTTP {response.status} {response.reason}"
                )
            _stream_response(
                response,
                connection,
                destination,
                expected,
                idle_timeout=idle_timeout,
                deadline=deadline,
            )
            return
        finally:
            _close_quietly(response)
            _close_quietly(connection)
    raise VerificationError("official APK exceeded the redirect limit")


def verify_official_download(
    manifest_path: Path,
    latest_response_path: Path,
    output_path: Path,
    *,
    idle_timeout: float = DEFAULT_IDLE_TIMEOUT_SECONDS,
    total_timeout: float = DEFAULT_TOTAL_TIMEOUT_SECONDS,
) -> Path:
    """Validate release metadata, download the official arm64 APK, and verify its bytes."""

    for value, label in (
        (idle_timeout, "idle timeout"),
        (total_timeout, "total timeout"),
    ):
        if not math.isfinite(value) or value <= 0:
            raise VerificationError(f"{label} must be a positive finite number")

    part_path = output_path.with_name(f"{output_path.name}.part")
    part_path.unlink(missing_ok=True)
    completed = False
    try:
        manifest = _load_json_object(manifest_path, "release manifest")
        latest = _load_json_object(latest_response_path, "official latest response")
        expected = _select_expected_download(manifest, latest)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        _download(
            expected,
            part_path,
            idle_timeout=idle_timeout,
            total_timeout=total_timeout,
        )
        os.replace(part_path, output_path)
        completed = True
        return output_path
    finally:
        if not completed:
            part_path.unlink(missing_ok=True)


def _positive_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be a number") from error
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("must be a positive finite number")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download and verify the official-site Android arm64 release artifact."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--response", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--idle-timeout",
        type=_positive_float,
        default=DEFAULT_IDLE_TIMEOUT_SECONDS,
        help="maximum seconds without socket progress (default: %(default)s)",
    )
    parser.add_argument(
        "--total-timeout",
        type=_positive_float,
        default=DEFAULT_TOTAL_TIMEOUT_SECONDS,
        help="maximum total download seconds (default: %(default)s)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        output = verify_official_download(
            args.manifest,
            args.response,
            args.output,
            idle_timeout=args.idle_timeout,
            total_timeout=args.total_timeout,
        )
    except (VerificationError, OSError, http.client.HTTPException) as error:
        print(f"official APK verification failed: {error}", file=sys.stderr)
        return 1
    print(f"verified official APK: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
