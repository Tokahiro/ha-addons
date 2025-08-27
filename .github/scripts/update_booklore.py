#!/usr/bin/env python3
import os
import sys
import json
import re
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]  # .github/scripts -> .github -> repo root


def http_get_json(url, token=None):
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "booklore-version-updater",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, headers=headers)
    with urlopen(req, timeout=30) as r:
        data = r.read()
        return json.loads(data.decode("utf-8"))


def fetch_latest_tag(repo, token):
    # releases/latest: latest non-draft, non-prerelease
    data = http_get_json(f"https://api.github.com/repos/{repo}/releases/latest", token)
    tag = str(data.get("tag_name", "")).strip()
    if not tag:
        raise RuntimeError("Failed to get latest tag_name from GitHub API")
    tag_with_v = tag if tag.lower().startswith("v") else f"v{tag}"
    tag_no_v = tag_with_v.lstrip("vV")
    return tag_with_v, tag_no_v


def read_current_versions(root: Path):
    current = {
        "build_booklore_ref": None,
        "config_version": None,
    }
    build_path = root / "booklore" / "build.yaml"
    if build_path.exists():
        txt = build_path.read_text(encoding="utf-8")
        m = re.search(
            r'(?m)^\s*BOOKLORE_REF:\s*["\']?(v?\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?)["\']?\s*$',
            txt,
        )
        if m:
            current["build_booklore_ref"] = m.group(1)

    config_path = root / "booklore" / "config.yaml"
    if config_path.exists():
        txt = config_path.read_text(encoding="utf-8")
        m = re.search(
            r'(?m)^\s*version:\s*["\']?(\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?)["\']?',
            txt,
        )
        if m:
            current["config_version"] = m.group(1)

    previous_tag = None
    if current["build_booklore_ref"]:
        prev = current["build_booklore_ref"]
        previous_tag = prev if prev.lower().startswith("v") else f"v{prev}"
    elif current["config_version"]:
        previous_tag = f'v{current["config_version"]}'
    return previous_tag, current


def replace_in_file(path: Path, pattern: str, repl: str) -> bool:
    if not path.exists():
        return False
    original = path.read_text(encoding="utf-8")
    new = re.sub(pattern, repl, original, flags=re.MULTILINE)
    if new != original:
        path.write_text(new, encoding="utf-8", newline="\n")
        return True
    return False


def update_files(root: Path, tag_with_v: str, tag_no_v: str):
    changed = []

    # booklore/build.yaml
    build_path = root / "booklore" / "build.yaml"
    if replace_in_file(
        build_path,
        r'(?m)^\s*BOOKLORE_REF:\s*["\']?v?\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?["\']?\s*$',
        f'BOOKLORE_REF: "{tag_with_v}"',
    ):
        changed.append(str(build_path.relative_to(root)))

    # booklore/config.yaml (version: "X.Y.Z"); do not alter 'homeassistant' key
    config_path = root / "booklore" / "config.yaml"
    if replace_in_file(
        config_path,
        r'(?m)^(\s*version:\s*["\']?)(\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?)(["\']?)',
        r"\g<1>" + tag_no_v + r"\g<3>",
    ):
        changed.append(str(config_path.relative_to(root)))

    # booklore/DOCS.md
    docs_path = root / "booklore" / "DOCS.md"
    if replace_in_file(
        docs_path,
        r"(Version\s+)(v?\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?)\b",
        r"\g<1>" + tag_no_v,
    ):
        changed.append(str(docs_path.relative_to(root)))

    # booklore/README.md: textual "Version X.Y.Z" and badge "badge/version-X.Y.Z-"
    readme_path = root / "booklore" / "README.md"
    changed_any = False
    if readme_path.exists():
        txt = readme_path.read_text(encoding="utf-8")
        new = re.sub(
            r"(Version\s+)(v?\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?)\b",
            r"\g<1>" + tag_no_v,
            txt,
        )
        new2 = re.sub(r"(badge/version-)(\d+\.\d+\.\d+)(-)", r"\g<1>" + tag_no_v + r"\g<3>", new)
        if new2 != txt:
            readme_path.write_text(new2, encoding="utf-8", newline="\n")
            changed_any = True
    if changed_any:
        changed.append(str(readme_path.relative_to(root)))

    # booklore/Dockerfile (ARG BOOKLORE_TAG)
    dockerfile_path = root / "booklore" / "Dockerfile"
    if replace_in_file(
        dockerfile_path,
        r'(?m)^(ARG\s+BOOKLORE_TAG\s*=\s*)(v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\s*$',
        r"\g<1>" + tag_with_v,
    ):
        changed.append(str(dockerfile_path.relative_to(root)))

    return changed


def write_outputs(outputs: dict):
    out_path = os.environ.get("GITHUB_OUTPUT")
    if not out_path:
        return
    with open(out_path, "a", encoding="utf-8") as f:
        for k, v in outputs.items():
            print(f"{k}={v}", file=f)


def main():
    # Args
    repo = "booklore-app/booklore"
    args = sys.argv[1:]
    if "--repo" in args:
        i = args.index("--repo")
        if i + 1 < len(args):
            repo = args[i + 1]

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")

    tag_with_v, tag_no_v = fetch_latest_tag(repo, token)
    previous_tag, _current = read_current_versions(ROOT)

    # No-op if already at latest
    if previous_tag and previous_tag == tag_with_v:
        write_outputs(
            {
                "tag_with_v": tag_with_v,
                "tag_no_v": tag_no_v,
                "previous_tag": previous_tag,
                "changed_files": "",
            }
        )
        print(f"No update needed (already at {tag_with_v})")
        return 0

    changed = update_files(ROOT, tag_with_v, tag_no_v)

    write_outputs(
        {
            "tag_with_v": tag_with_v,
            "tag_no_v": tag_no_v,
            "previous_tag": previous_tag or "",
            "changed_files": ",".join(changed),
        }
    )

    print(
        json.dumps(
            {"latest": tag_with_v, "previous": previous_tag, "changed_files": changed}
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())