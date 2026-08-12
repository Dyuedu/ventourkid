#!/usr/bin/env python3
import argparse
import json
import math
from pathlib import Path

import requests


def l2_normalize(values: list[float]) -> list[float]:
    norm = math.sqrt(sum(value * value for value in values))
    if norm == 0:
        raise ValueError("Embedding norm is zero")
    return [value / norm for value in values]


def load_mobile_embedding(path: Path) -> list[float]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        raw_embedding = payload
    elif isinstance(payload, dict):
        raw_embedding = payload.get("embedding")
        if raw_embedding is None and isinstance(payload.get("face"), dict):
            raw_embedding = payload["face"].get("embedding")
    else:
        raw_embedding = None

    if not isinstance(raw_embedding, list) or not raw_embedding:
        raise ValueError("Mobile embedding JSON must be a list or contain an embedding field")
    return l2_normalize([float(value) for value in raw_embedding])


def load_backend_embedding(base_url: str, image_path: Path, api_key: str | None) -> list[float]:
    headers = {}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    with image_path.open("rb") as image_file:
        response = requests.post(
            f"{base_url.rstrip('/')}/embed",
            files={"image": (image_path.name, image_file, "application/octet-stream")},
            headers=headers,
            timeout=60,
        )
    response.raise_for_status()
    faces = response.json().get("faces")
    if not isinstance(faces, list) or len(faces) != 1:
        raise ValueError(f"Expected exactly one backend face, got {0 if not faces else len(faces)}")
    embedding = faces[0].get("embedding")
    if not isinstance(embedding, list) or not embedding:
        raise ValueError("Backend response does not contain an embedding")
    return l2_normalize([float(value) for value in embedding])


def cosine(left: list[float], right: list[float]) -> float:
    if len(left) != len(right):
        raise ValueError(f"Embedding dimension mismatch: mobile={len(left)} backend={len(right)}")
    return sum(a * b for a, b in zip(left, right))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare a mobile offline face embedding with the backend InsightFace embedding for the same image."
    )
    parser.add_argument("--image", required=True, type=Path, help="Single-face image used by both mobile and backend")
    parser.add_argument("--mobile-embedding", required=True, type=Path, help="JSON file containing the mobile embedding")
    parser.add_argument("--backend-url", default="http://localhost:8088", help="InsightFace service base URL")
    parser.add_argument("--api-key", default=None, help="InsightFace API key, if configured")
    parser.add_argument("--min-cosine", default=0.98, type=float, help="Minimum accepted cosine similarity")
    args = parser.parse_args()

    mobile = load_mobile_embedding(args.mobile_embedding)
    backend = load_backend_embedding(args.backend_url, args.image, args.api_key)
    score = cosine(mobile, backend)
    print(f"cosine={score:.6f} threshold={args.min_cosine:.6f}")
    return 0 if score >= args.min_cosine else 2


if __name__ == "__main__":
    raise SystemExit(main())
