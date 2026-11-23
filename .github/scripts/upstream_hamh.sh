#!/usr/bin/env bash
# Moves hamh_raumtyp to the newest stable Home-Assistant-Matter-Hub release.
# Builds the image to check that patch.mjs still applies. Opens a pull request, or an issue if
# the build fails. Needs GH_TOKEN. Run from the repository root.
set -euo pipefail

dir=hamh_raumtyp
repo=$(jq -r --arg d "${dir}" '.[$d].repo' .github/upstream.json)
url=${UPSTREAM_URL:-"https://github.com/${repo}"}
image=ghcr.io/riddix/home-assistant-matter-hub-addon

current=$(sed -nE "s#^FROM ${image}:([0-9.]+)\$#\\1#p" "${dir}/Dockerfile")
if [[ -z "${current}" ]]; then
  echo "No 'FROM ${image}:<version>' line in ${dir}/Dockerfile." >&2
  exit 1
fi
latest=$(git ls-remote --tags --refs "${url}" | sed 's#.*refs/tags/v\{0,1\}##' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
if [[ -z "${latest}" || "$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -1)" == "${current}" ]]; then
  echo "No new stable release (fork ${current}, upstream ${latest:-none})."
  exit 0
fi
if ! docker manifest inspect "${image}:${latest}" > /dev/null 2>&1; then
  echo "Upstream ${latest} has no image ${image}:${latest} yet. Next run checks again."
  exit 0
fi
echo "Upstream ${latest} is newer than ${current}."

branch="smith/upstream-hamh-${latest}"
title="Matter Hub (area type): update to ${latest}"
if [[ "$(gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("smith/upstream-hamh-"))] | length')" != "0" ]]; then
  echo "An upstream pull request for hamh_raumtyp is open. Merge or close it first."
  exit 0
fi
if [[ "$(gh issue list --state open --search "\"${title}\" in:title" --json title --jq "[.[] | select(.title == \"${title}\")] | length")" != "0" ]]; then
  echo "An open issue for ${latest} exists. Nothing to do."
  exit 0
fi

git checkout -q -b "${branch}"
# Version strings in the Dockerfile, the add-on description and the README. The add-on version
# restarts at raumtyp1 for each upstream version.
sed -i "s#${image}:${current}#${image}:${latest}#" "${dir}/Dockerfile"
sed -i -E "s#^version: \"${current//./\\.}-raumtyp[0-9]+\"#version: \"${latest}-raumtyp1\"#" "${dir}/config.yaml"
sed -i "s#${current//./\\.}#${latest}#g" "${dir}/config.yaml" "${dir}/README.md"

log=$(mktemp)
if ! docker build --pull -q -t hamh-raumtyp-check "${dir}" > "${log}" 2>&1; then
  cat "${log}"
  body=$(cat <<EOF
The image build of \`${dir}\` fails with Home-Assistant-Matter-Hub ${latest} (now ${current}).
Most likely \`patch.mjs\` no longer finds its anchors in the new CLI bundle.

\`\`\`
$(tail -40 "${log}")
\`\`\`

Upstream changes: ${url}/compare/v${current}...v${latest}
EOF
)
  gh issue create --title "${title}" --body "${body}"
  echo "Build failed. Opened an issue."
  exit 0
fi

git add "${dir}"
git commit -q -m "hamh_raumtyp: update to Matter Hub ${latest}"
# --force: a branch left over from a run that failed before the pull request is replaced.
git push -q --force origin "${branch}"
body=$(cat <<EOF
Moves the area type test add-on from Home-Assistant-Matter-Hub ${current} to ${latest}.
The image builds and \`patch.mjs\` applies (checked in the upstream check run, amd64).

Upstream changes: ${url}/compare/v${current}...v${latest}

After the merge, Home Assistant shows the update for "Matter Hub (area type test)". Make a backup
first, then test the Siri room commands for the vacuum.
EOF
)
gh pr create --base main --head "${branch}" --title "hamh_raumtyp: update to Matter Hub ${latest}" --body "${body}"
