#!/usr/bin/env bash
# Merges a new upstream release of homebridge-ring-secure-video into the fork folder.
# Opens a pull request (draft if lint or tests fail), or an issue if the merge has conflicts.
# Needs GH_TOKEN. Run from the repository root.
set -euo pipefail

dir=homebridge-ring-secure-video
cfg=.github/upstream.json
repo=$(jq -r --arg d "${dir}" '.[$d].repo' "${cfg}")
base=$(jq -r --arg d "${dir}" '.[$d].base' "${cfg}")
url=${UPSTREAM_URL:-"https://github.com/${repo}"}

latest=$(git ls-remote --tags --refs "${url}" | sed 's#.*refs/tags/##' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
if [[ -z "${latest}" || "$(printf '%s\n%s\n' "${base}" "${latest}" | sort -V | tail -1)" == "${base}" ]]; then
  echo "No new upstream release (fork base ${base}, upstream ${latest:-none})."
  exit 0
fi
echo "Upstream ${latest} is newer than the fork base ${base}."

branch="smith/upstream-ring-${latest}"
title="Ring plugin: merge upstream ${latest}"
if git ls-remote --exit-code --heads origin "${branch}" > /dev/null; then
  echo "Branch ${branch} exists. Nothing to do."
  exit 0
fi
if [[ "$(gh issue list --state open --search "\"${title}\" in:title" --json number --jq length)" != "0" ]]; then
  echo "An open issue for ${latest} exists. Nothing to do."
  exit 0
fi

git fetch -q --no-tags "${url}" "refs/tags/${base}:refs/tags/up-${base}" "refs/tags/${latest}:refs/tags/up-${latest}"
git checkout -q -b "${branch}"

# package.json, package-lock.json and CHANGELOG.md are merged apart: name, version and changelog stay ours.
patch=$(mktemp)
git diff "up-${base}" "up-${latest}" -- . ':!.github' ':!package.json' ':!package-lock.json' ':!CHANGELOG.md' > "${patch}"
conflicts=""
if [[ -s "${patch}" ]] && ! git apply --3way --directory="${dir}" "${patch}"; then
  conflicts=$(git diff --name-only --diff-filter=U)
  conflicts=${conflicts:-"git apply failed (see the workflow log)"}
fi
tmp=$(mktemp -d)
git show "up-${base}:package.json" > "${tmp}/base.json"
git show "up-${latest}:package.json" > "${tmp}/theirs.json"
if ! keys=$(node .github/scripts/merge_package_json.mjs "${tmp}/base.json" "${dir}/package.json" "${tmp}/theirs.json"); then
  conflicts=$(printf '%s\n%s/package.json (keys: %s)' "${conflicts}" "${dir}" "$(echo "${keys}" | paste -sd, -)")
fi

if [[ -n "${conflicts//[[:space:]]/}" ]]; then
  body=$(cat <<EOF
Upstream ${latest} of [${repo}](${url}) does not merge cleanly into \`${dir}\` (fork base ${base}).

Files with conflicts:

\`\`\`
${conflicts}
\`\`\`

Upstream changes: ${url}/compare/${base}...${latest}

Reproduce: fetch both tags, then
\`git diff <base> <latest> -- . ':!.github' ':!package.json' ':!package-lock.json' ':!CHANGELOG.md' | git apply --3way --directory=${dir}\`.
After the merge, set \`base\` in \`.github/upstream.json\` to \`${latest}\`.
EOF
)
  gh issue create --title "${title}" --body "${body}"
  echo "Conflicts. Opened an issue."
  exit 0
fi

cd "${dir}"
npm install --package-lock-only --ignore-scripts --no-audit --no-fund > /dev/null
version=$(npm version minor --no-git-tag-version | tr -d v)
entry=$(printf '## %s (%s)\n\n- Merged upstream homebridge-ring-secure-video %s (from %s). Changes: %s/blob/%s/CHANGELOG.md\n' \
  "${version}" "$(date -u +%F)" "${latest}" "${base}" "${url}" "${latest}")
awk -v e="${entry}" 'NR == 1 { print; print ""; print e; next } { print }' CHANGELOG.md > "${tmp}/cl" && mv "${tmp}/cl" CHANGELOG.md

checks="Lint and tests passed in the upstream check run."
draft=""
if ! { npm ci --no-audit --no-fund && npm run lint && npm test; } > "${tmp}/check.log" 2>&1; then
  tail -50 "${tmp}/check.log"
  checks="Lint or tests FAILED in the upstream check run. Last lines:

\`\`\`
$(tail -30 "${tmp}/check.log")
\`\`\`"
  draft="--draft"
fi
cd - > /dev/null

jq --arg d "${dir}" --arg v "${latest}" '.[$d].base = $v' "${cfg}" > "${tmp}/cfg" && mv "${tmp}/cfg" "${cfg}"
git add "${dir}" "${cfg}"
git commit -q -m "homebridge-ring-secure-video ${version}: merge upstream ${latest}"
git push -q origin "${branch}"

body=$(cat <<EOF
Merges upstream [${repo}](${url}) ${latest} into the fork (base was ${base}). The fork version is now ${version}.

- Upstream changes: ${url}/compare/${base}...${latest}
- name, version, description and links in package.json stay the fork's. package-lock.json is regenerated.

${checks}

Workflows do not run on pull requests opened by this workflow. Push a commit or close and reopen the PR to run the tests here.
Merging publishes ${version} on npm. Test it in Homebridge first.
EOF
)
# shellcheck disable=SC2086
gh pr create ${draft} --base main --head "${branch}" --title "homebridge-ring-secure-video ${version}: merge upstream ${latest}" --body "${body}"
