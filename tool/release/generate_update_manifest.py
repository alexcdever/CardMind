#!/usr/bin/env python3
"""Generate a CardMind update manifest from staged release assets.

NSH 产物现实（nsh_release.yml 上传名）：Windows 没有 Inno Setup 安装器，
`nsh package --target windows` 产出 zip；macOS 资产是 DMG。

资产缺失容忍：缺失/为空的平台只跳过并告警（publish 允许部分平台失败）；
一个资产都没有才失败（SystemExit，非零退出）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import quote


APP_ID = "com.cardmind.nsh"

ASSETS = {
    "windows-x64": "CardMind-Windows-x64.zip",
    "android": "CardMind-Android.apk",
    "linux-x64": "CardMind-Linux-x64.tar.gz",
    "macos-arm64": "CardMind-macOS-arm64.dmg",
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
            print(f"warning: missing or empty release asset, skipping {platform}: {path}")
            continue
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

    if not platforms:
        raise SystemExit(f"no release assets found in {root} (expected one of {sorted(ASSETS.values())})")

    return {
        "schemaVersion": 1,
        "appId": args.app_id,
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
    parser.add_argument("--app-id", default=APP_ID)
    args = parser.parse_args()

    manifest = build_manifest(args)
    output = Path(args.output)
    output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
