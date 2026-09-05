import unittest

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

    def test_stable_tag_is_stable_release(self):
        result = resolve("v0.1.0", 42)
        self.assertEqual(result["APP_VERSION"], "0.1.0")
        self.assertEqual(result["FLUTTER_VERSION"], "0.1.0")
        self.assertEqual(result["WINDOWS_BUILD_NAME"], "0.1.0")
        self.assertEqual(result["APP_BUILD"], "10042")
        self.assertEqual(result["WINDOWS_VERSION"], "0.1.0.10042")
        self.assertEqual(result["RELEASE_CHANNEL"], "stable")
        self.assertEqual(result["RELEASE_TAG"], "v0.1.0")


if __name__ == "__main__":
    unittest.main()
