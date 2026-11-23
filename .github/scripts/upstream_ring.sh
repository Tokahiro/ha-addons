#!/usr/bin/env bash
# Merges a new upstream release of homebridge-ring-secure-video into the fork folder.
# Three steps, so that upstream code never runs next to a token that can write:
#   merge <out>  no token. Merges upstream into the working tree, commits, writes <out>/meta.json
#                and <out>/merge.patch (or the conflict list).
#   check <out>  no token. Runs npm ci, lint and tests on the merged tree (upstream code runs here),
#                writes <out>/check.md.
#   open <merge-out> <check-out>  GH_TOKEN, fresh checkout. Opens the pull request (draft if the
#                check failed), or an issue if the merge has conflicts.
# Run from the repository root.
set -euo pipefail

dir=homebridge-ring-secure-video
cfg=.github/upstream.json
repo=$(jq -r --arg d "${dir}" '.[$d].repo' "${cfg}")
base=$(jq -r --arg d "${dir}" '.[$d].base' "${cfg}")
url=${UPSTREAM_URL:-"https://github.com/${repo}"}
prefix=smith/upstream-ring-

merge() {
  local out=$1 latest patch conflicts="" tmp keys version entry
  mkdir -p "${out}"
  latest=$(git ls-remote --tags --refs "${url}" | sed 's#.*refs/tags/##' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  if [[ -z "${latest}" || "$(printf '%s\n%s\n' "${base}" "${latest}" | sort -V | tail -1)" == "${base}" ]]; then
    echo "No new upstream release (fork base ${base}, upstream ${latest:-none})."
    jq -n '{status: "none"}' > "${out}/meta.json"
    return
  fi
  echo "Upstream ${latest} is newer than the fork base ${base}."

  git fetch -q --no-tags "${url}" "refs/tags/${base}:refs/tags/up-${base}" "refs/tags/${latest}:refs/tags/up-${latest}"
  # package.json, package-lock.json and CHANGELOG.md are merged apart: name, version and changelog
  # stay ours. The upstream .github folder (dependabot, CI) does not belong in the fork folder.
  patch=$(mktemp)
  git diff --binary "up-${base}" "up-${latest}" -- . ':!.github' ':!package.json' ':!package-lock.json' ':!CHANGELOG.md' > "${patch}"
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
    printf '%s\n' "${conflicts}" > "${out}/conflicts.txt"
    jq -n --arg l "${latest}" '{status: "conflict", latest: $l}' > "${out}/meta.json"
    echo "Conflicts:"
    cat "${out}/conflicts.txt"
    return
  fi

  (
    cd "${dir}"
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund > /dev/null
    npm version minor --no-git-tag-version > /dev/null
  )
  version=$(jq -r .version "${dir}/package.json")
  entry=$(printf '## %s (%s)\n\n- Merged upstream homebridge-ring-secure-video %s (from %s). Changes: %s/blob/%s/CHANGELOG.md\n' \
    "${version}" "$(date -u +%F)" "${latest}" "${base}" "${url}" "${latest}")
  awk -v e="${entry}" 'NR == 1 { print; print ""; print e; next } { print }' "${dir}/CHANGELOG.md" > "${tmp}/cl"
  mv "${tmp}/cl" "${dir}/CHANGELOG.md"
  jq --arg d "${dir}" --arg v "${latest}" '.[$d].base = $v' "${cfg}" > "${tmp}/cfg" && mv "${tmp}/cfg" "${cfg}"
  git add "${dir}" "${cfg}"
  git commit -q -m "homebridge-ring-secure-video ${version}: merge upstream ${latest}"
  git format-patch -1 --binary --stdout > "${out}/merge.patch"
  jq -n --arg l "${latest}" --arg v "${version}" '{status: "pr", latest: $l, version: $v}' > "${out}/meta.json"
}

check() {
  local out=$1 log
  mkdir -p "${out}"
  log=$(mktemp)
  if (cd "${dir}" && npm ci --no-audit --no-fund && npm run lint && npm test) > "${log}" 2>&1; then
    echo "Lint and tests passed in the upstream check run." > "${out}/check.md"
  else
    tail -50 "${log}"
    printf 'Lint or tests FAILED in the upstream check run. Last lines:\n\n```\n%s\n```\n' "$(tail -30 "${log}")" > "${out}/check.md"
  fi
}

# Number of open pull requests from upstream-ring branches, and of open issues with this title.
open_prs() {
  gh pr list --state open --json headRefName --jq "[.[] | select(.headRefName | startswith(\"${prefix}\"))] | length"
}
open_issues() {
  gh issue list --state open --search "\"$1\" in:title" --json title --jq "[.[] | select(.title == \"$1\")] | length"
}

open() {
  local m=$1 c=$2 status latest version branch title body checks draft=""
  status=$(jq -r .status "${m}/meta.json")
  latest=$(jq -r '.latest // empty' "${m}/meta.json")
  [[ "${status}" == "none" ]] && { echo "Nothing to do."; return; }
  [[ "${latest}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Bad meta.json." >&2; return 1; }
  if [[ "$(open_prs)" != "0" ]]; then
    echo "An upstream pull request for the Ring plugin is open. Merge or close it first."
    return
  fi
  title="Ring plugin: merge upstream ${latest}"

  if [[ "${status}" == "conflict" ]]; then
    if [[ "$(open_issues "${title}")" != "0" ]]; then
      echo "An open issue for ${latest} exists. Nothing to do."
      return
    fi
    body=$(cat <<EOF
Upstream ${latest} of [${repo}](${url}) does not merge cleanly into \`${dir}\` (fork base ${base}).

Files with conflicts:

\`\`\`
$(cat "${m}/conflicts.txt")
\`\`\`

Upstream changes: ${url}/compare/${base}...${latest}

Reproduce: fetch both tags, then
\`git diff --binary <base> <latest> -- . ':!.github' ':!package.json' ':!package-lock.json' ':!CHANGELOG.md' | git apply --3way --directory=${dir}\`.
Merge package.json with \`.github/scripts/merge_package_json.mjs\`, raise the minor version, add a
CHANGELOG entry and set \`base\` in \`.github/upstream.json\` to \`${latest}\`.
EOF
)
    gh issue create --title "${title}" --body "${body}"
    return
  fi

  version=$(jq -r .version "${m}/meta.json")
  branch="${prefix}${latest}"
  checks=$(cat "${c}/check.md" 2> /dev/null || echo "The check did not run.")
  [[ "${checks}" == "Lint and tests passed"* ]] || draft="--draft"
  git checkout -q -B "${branch}"
  git am -q "${m}/merge.patch"
  # --force: a branch left over from a run that failed before the pull request is replaced.
  git push -q --force origin "${branch}"
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
}

case "${1:-}" in
  merge) merge "$2" ;;
  check) check "$2" ;;
  open) open "$2" "$3" ;;
  *) echo "Usage: $0 merge <out> | check <out> | open <merge-out> <check-out>" >&2; exit 2 ;;
esac
