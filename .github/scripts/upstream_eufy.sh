#!/usr/bin/env bash
# eufy-clean runs in Home Assistant from a main commit, not from a release. Opens an issue once a
# stable release contains that commit, so HACS can move to the release. Needs GH_TOKEN.
set -euo pipefail

repo=$(jq -r '."eufy-clean".repo' .github/upstream.json)
installed=$(jq -r '."eufy-clean".installed' .github/upstream.json)
url=${UPSTREAM_URL:-"https://github.com/${repo}"}

src=$(mktemp -d)
git clone -q --filter=blob:none --no-checkout "${url}" "${src}"
release=$(git -C "${src}" tag --contains "${installed}" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
if [[ -z "${release}" ]]; then
  echo "No stable release contains ${installed} yet."
  exit 0
fi

title="eufy-clean: release ${release} contains the installed commit ${installed}"
if [[ "$(gh issue list --state all --search "\"${title}\" in:title" --json number --jq length)" != "0" ]]; then
  echo "An issue for ${release} exists. Nothing to do."
  exit 0
fi
body=$(cat <<EOF
eufy-clean runs from main (${installed}). Release [${release}](${url}/releases/tag/${release}) contains that commit.

In HACS, eufy-clean, Redownload: choose ${release}. Then restart Home Assistant and check the rooms.
After that, set \`installed\` in \`.github/upstream.json\` to the release commit, or remove the entry.
EOF
)
gh issue create --title "${title}" --body "${body}"
