#!/usr/bin/env python3
"""Resolve reproducible CardMind release metadata for GitHub Actions."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


STABLE_TAG = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)$")


def resolve(ref_name: str, run_number: int) -> dict[str, str]:
    if run_number <= 0:
        raise ValueError("run_number must be positive")

    stable_match = STABLE_TAG.fullmatch(ref_name)
    if stable_match:
        version = stable_match.group("version")
        build = 10_000 + run_number
        return {
            "APP_VERSION": version,
            "FLUTTER_VERSION": version,
            "WINDOWS_BUILD_NAME": version,
            "APP_BUILD": str(build),
            "WINDOWS_VERSION": f"{version}.{build}",
            "RELEASE_CHANNEL": "stable",
            "RELEASE_TAG": ref_name,
        }

    version = f"0.1.0-beta.{run_number}"
    build = 10_000 + run_number
    return {
        "APP_VERSION": version,
        "FLUTTER_VERSION": version,
        "WINDOWS_BUILD_NAME": "0.1.0",
        "APP_BUILD": str(build),
        "WINDOWS_VERSION": f"0.1.0.{build}",
        "RELEASE_CHANNEL": "beta",
        "RELEASE_TAG": f"beta-{version}",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref-name", required=True)
    parser.add_argument("--run-number", type=int, required=True)
    parser.add_argument("--github-env", type=Path)
    args = parser.parse_args()

    values = resolve(args.ref_name, args.run_number)
    if args.github_env:
        with args.github_env.open("a", encoding="utf-8", newline="\n") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    else:
        for key, value in values.items():
            print(f"{key}={value}")


if __name__ == "__main__":
    main()
