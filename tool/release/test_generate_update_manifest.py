import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from generate_update_manifest import build_manifest
import argparse


class GenerateUpdateManifestTest(unittest.TestCase):
    def test_manifest_contains_all_platform_assets_and_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for filename in (
                "CardMind-Setup.exe",
                "CardMind-Android.apk",
                "CardMind-Linux-x64.tar.gz",
            ):
                (root / filename).write_bytes(filename.encode())

            manifest = build_manifest(
                argparse.Namespace(
                    assets_dir=directory,
                    output=str(root / "update.json"),
                    repository="alexcdever/CardMind",
                    tag="beta-0.1.0-beta.7",
                    channel="beta",
                    version="0.1.0-beta.7",
                    build=10007,
                    published_at="2026-09-05T00:00:00Z",
                    minimum_supported_version="0.1.0-beta.1",
                    release_notes=["测试版本"],
                )
            )

            self.assertEqual(manifest["channel"], "beta")
            self.assertEqual(set(manifest["platforms"]), {"windows-x64", "android", "linux-x64"})
            for platform in manifest["platforms"].values():
                path = root / platform["artifact"]
                self.assertEqual(platform["size"], path.stat().st_size)
                self.assertEqual(
                    platform["sha256"], hashlib.sha256(path.read_bytes()).hexdigest()
                )
                self.assertTrue(platform["url"].startswith("https://"))
                self.assertIn(
                    f"channel-beta/beta.json",
                    platform["channelManifestUrl"],
                )


if __name__ == "__main__":
    unittest.main()
