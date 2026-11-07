import json
import tempfile
import unittest
from pathlib import Path

from release_metadata import resolve


class ReleaseMetadataTest(unittest.TestCase):
    def test_main_ref_is_beta_pre_release(self):
        self.assertEqual(
            resolve("main", 7),
            {
                "APP_VERSION": "0.1.0-beta.7",
                "FLUTTER_VERSION": "0.1.0-beta.7",
                "WINDOWS_BUILD_NAME": "0.1.0",
                "APP_BUILD": "10007",
                "WINDOWS_VERSION": "0.1.0.10007",
                "RELEASE_CHANNEL": "beta",
                "RELEASE_TAG": "beta-0.1.0-beta.7",
            },
        )

    def test_beta_base_version_comes_from_nsh_json(self):
        with tempfile.TemporaryDirectory() as directory:
            nsh_json = Path(directory) / "nsh.json"
            nsh_json.write_text(
                json.dumps({"name": "cardmind", "id": "com.cardmind.nsh", "version": "0.2.5"}),
                encoding="utf-8",
            )
            result = resolve("main", 3, nsh_json=nsh_json)

        self.assertEqual(result["APP_VERSION"], "0.2.5-beta.3")
        self.assertEqual(result["WINDOWS_BUILD_NAME"], "0.2.5")
        self.assertEqual(result["WINDOWS_VERSION"], "0.2.5.10003")
        self.assertEqual(result["RELEASE_TAG"], "beta-0.2.5-beta.3")
        self.assertEqual(result["RELEASE_CHANNEL"], "beta")

    def test_non_tag_ref_is_beta(self):
        for ref_name in ("nonsense", "feature/foo", "beta-0.1.0-beta.1"):
            with self.subTest(ref_name=ref_name):
                result = resolve(ref_name, 7)
                self.assertEqual(result["RELEASE_CHANNEL"], "beta")
                self.assertEqual(result["APP_VERSION"], "0.1.0-beta.7")

    def test_stable_tag_is_stable_release(self):
        result = resolve("v0.1.0", 42)
        self.assertEqual(result["APP_VERSION"], "0.1.0")
        self.assertEqual(result["FLUTTER_VERSION"], "0.1.0")
        self.assertEqual(result["WINDOWS_BUILD_NAME"], "0.1.0")
        self.assertEqual(result["APP_BUILD"], "10042")
        self.assertEqual(result["WINDOWS_VERSION"], "0.1.0.10042")
        self.assertEqual(result["RELEASE_CHANNEL"], "stable")
        self.assertEqual(result["RELEASE_TAG"], "v0.1.0")

    def test_stable_tag_does_not_read_nsh_json(self):
        result = resolve("v9.9.9", 1, nsh_json=Path("/nonexistent/nsh.json"))
        self.assertEqual(result["APP_VERSION"], "9.9.9")
        self.assertEqual(result["RELEASE_CHANNEL"], "stable")


if __name__ == "__main__":
    unittest.main()
