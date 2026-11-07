import argparse
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

# `python3 -m unittest discover -s tool/release` 从仓库根跑时 `tool.release`
# 可导入；从 tool/release 目录内部跑则把仓库根补进 sys.path。
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.release.generate_update_manifest import build_manifest

ALL_ASSETS = (
    "CardMind-Windows-x64.zip",
    "CardMind-Android.apk",
    "CardMind-Linux-x64.tar.gz",
    "CardMind-macOS-arm64.dmg",
)


def make_args(directory, **overrides):
    values = dict(
        assets_dir=directory,
        output=str(Path(directory) / "update.json"),
        repository="alexcdever/CardMind",
        tag="beta-0.1.0-beta.7",
        channel="beta",
        version="0.1.0-beta.7",
        build=10007,
        published_at="2026-09-05T00:00:00Z",
        minimum_supported_version="0.1.0-beta.1",
        release_notes=["测试版本"],
        app_id="com.cardmind.nsh",
    )
    values.update(overrides)
    return argparse.Namespace(**values)


class GenerateUpdateManifestTest(unittest.TestCase):
    def test_manifest_contains_all_platform_assets_and_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for filename in ALL_ASSETS:
                (root / filename).write_bytes(filename.encode())

            manifest = build_manifest(make_args(directory))

            self.assertEqual(manifest["channel"], "beta")
            self.assertEqual(manifest["appId"], "com.cardmind.nsh")
            self.assertEqual(
                set(manifest["platforms"]),
                {"windows-x64", "android", "linux-x64", "macos-arm64"},
            )
            for platform in manifest["platforms"].values():
                path = root / platform["artifact"]
                self.assertEqual(platform["size"], path.stat().st_size)
                self.assertEqual(
                    platform["sha256"], hashlib.sha256(path.read_bytes()).hexdigest()
                )
                self.assertTrue(platform["url"].startswith("https://"))
                self.assertIn(
                    "channel-beta/beta.json",
                    platform["channelManifestUrl"],
                )

    def test_missing_assets_are_skipped_not_fatal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for filename in (
                "CardMind-Android.apk",
                "CardMind-Linux-x64.tar.gz",
            ):
                (root / filename).write_bytes(filename.encode())

            manifest = build_manifest(make_args(directory))

            self.assertEqual(
                set(manifest["platforms"]),
                {"android", "linux-x64"},
            )

    def test_all_assets_missing_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(SystemExit):
                build_manifest(make_args(directory))

    def test_empty_asset_is_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "CardMind-Android.apk").write_bytes(b"real")
            (root / "CardMind-Linux-x64.tar.gz").write_bytes(b"")

            manifest = build_manifest(make_args(directory))

            self.assertEqual(set(manifest["platforms"]), {"android"})

    def test_app_id_is_parameterizable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "CardMind-Android.apk").write_bytes(b"apk")

            manifest = build_manifest(make_args(directory, app_id="com.example.other"))

            self.assertEqual(manifest["appId"], "com.example.other")


if __name__ == "__main__":
    unittest.main()
