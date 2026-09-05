#!/usr/bin/env python3
"""Generate a CardMind update manifest from staged release assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import quote


ASSETS = {
    "windows-x64": "CardMind-Setup.exe",
    "android": "CardMind-Android.apk",
    "linux-x64": "CardMind-Linux-x64.tar.gz",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(args: argparse.Namespace) -> dict:
    root = Path(args.assets_dir)
    platforms = {}
    for platform, filename in ASSETS.items():
        path = root / filename
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing or empty release asset: {path}")
        platforms[platform] = {
            "artifact": filename,
            "url": (
                f"https://github.com/{args.repository}/releases/download/"
                f"{quote(args.tag, safe='')}/{quote(filename)}"
            ),
            "channelManifestUrl": (
                f"https://github.com/{args.repository}/releases/download/"
                f"channel-{args.channel}/{quote(args.channel + '.json', safe='')}"
            ),
            "size": path.stat().st_size,
            "sha256": sha256(path),
        }

    return {
        "schemaVersion": 1,
        "appId": "com.cardmind.v2",
        "channel": args.channel,
        "version": args.version,
        "build": args.build,
        "publishedAt": args.published_at,
        "minimumSupportedVersion": args.minimum_supported_version,
        "mandatory": False,
        "releaseNotes": args.release_notes,
        "releasePage": f"https://github.com/{args.repository}/releases/tag/{quote(args.tag, safe='')}",
        "platforms": platforms,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--channel", choices=("stable", "beta"), required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", type=int, required=True)
    parser.add_argument("--published-at", required=True)
    parser.add_argument("--minimum-supported-version", required=True)
    parser.add_argument("--release-notes", nargs="*", default=[])
    args = parser.parse_args()

    manifest = build_manifest(args)
    output = Path(args.output)
    output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
