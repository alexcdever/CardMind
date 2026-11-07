#!/usr/bin/env python3
"""Resolve reproducible CardMind release metadata for GitHub Actions.

NSH 时代输出键沿用旧流水线字段名（FLUTTER_VERSION/WINDOWS_*），workflow 只消费
APP_VERSION / APP_BUILD / RELEASE_CHANNEL / RELEASE_TAG 四个键。

通道语义（与 nsh_release.yml 一致）：
- ref `vX.Y.Z` → stable：version 直接取 tag 里的 X.Y.Z；
- 其余 ref（main、workflow_dispatch 等）→ beta：base version 从
  nsh-app/nsh.json 的 `version` 读，再拼 `-beta.<run>` 后缀。
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


STABLE_TAG = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)$")

DEFAULT_NSH_JSON = Path(__file__).resolve().parents[2] / "nsh-app" / "nsh.json"


def app_version(nsh_json: Path) -> str:
    data = json.loads(Path(nsh_json).read_text(encoding="utf-8"))
    version = data["version"]
    if not isinstance(version, str) or not version:
        raise ValueError(f"invalid version in {nsh_json}: {version!r}")
    return version


def resolve(ref_name: str, run_number: int, nsh_json: Path = DEFAULT_NSH_JSON) -> dict[str, str]:
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

    base = app_version(nsh_json)
    version = f"{base}-beta.{run_number}"
    build = 10_000 + run_number
    return {
        "APP_VERSION": version,
        "FLUTTER_VERSION": version,
        "WINDOWS_BUILD_NAME": base,
        "APP_BUILD": str(build),
        "WINDOWS_VERSION": f"{base}.{build}",
        "RELEASE_CHANNEL": "beta",
        "RELEASE_TAG": f"beta-{version}",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref-name", required=True)
    parser.add_argument("--run-number", type=int, required=True)
    parser.add_argument("--github-env", type=Path)
    parser.add_argument(
        "--nsh-json",
        type=Path,
        default=DEFAULT_NSH_JSON,
        help="nsh-app/nsh.json 路径（beta 的 base version 来源）",
    )
    args = parser.parse_args()

    values = resolve(args.ref_name, args.run_number, nsh_json=args.nsh_json)
    if args.github_env:
        with args.github_env.open("a", encoding="utf-8", newline="\n") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    else:
        for key, value in values.items():
            print(f"{key}={value}")


if __name__ == "__main__":
    main()
