#!/bin/bash
set -euo pipefail
set -x
IFS=$'\n\t'

HEADERS="Accept: application/vnd.github.v3+json"

kloon_fork_branch_to_local_branch() {
  local pull_request_json="$1"
  local commit="$2"
  local clone_url=$(echo "${pull_request_json}" | jq -r ".head.repo.clone_url")
  local author=$(echo "${pull_request_json}" | jq -r ".head.user.login")
  local branch_name=$(echo "${pull_request_json}" | jq -r ".head.ref")
  local new_branch_name="fork/${author}/${branch_name}"

  git remote add fork "${clone_url}"
  git fetch fork
  git branch -D "${new_branch_name}" || true
  git checkout -b "${new_branch_name}"
  git reset "$commit" --hard
  git push --set-upstream origin "${new_branch_name}" -f
}

parse_comment(){
  local line=$(echo "${KBOT_COMMENT}" | head -n 1)
  local at=$(echo "${line}" | awk '{print $1}')
  local cmd=$(echo "${line}" | awk '{print $2}')
  local commit=$(echo "${line}" | awk '{print $3}' | tr -d '\n\r ')

  if [[ ${at} == "@kloonbot" ]]; then
    case "${cmd}" in
      run_ci|run_benchmark)
        if [[ ! ${commit} =~ ^[0-9a-fA-F]{7,40}$ ]]; then
          echo "parse_comment: '${commit}' does not look like a commit sha" 1>&2
          exit 1;
        fi
        echo "${cmd} ${commit}"
        ;;
      *)
        echo "parse_comment: Could not parse comment" 1>&2
        exit 1;
        ;;
    esac
  else
    # When the comment is not directed @kloonbot, return an empty string.
    echo ""
    exit 0;
  fi
}

dispatch_benchmark() {
  local pull_request_json="$1"
  local commit="$2"
  local head_sha=$(echo "${pull_request_json}" | jq -r ".head.sha")

  # Accept only the current PR head (a prefix match permits short shas).
  # This makes sure a maintainer approves the commit that they reviewed,
  # and that benchmark-pr.yml can fetch the sha through refs/pull/N/head.
  if [[ "${head_sha}" != "${commit}"* ]]; then
    echo "dispatch_benchmark: '${commit}' is not the current PR head (${head_sha})" 1>&2
    exit 1;
  fi

  curl --fail-with-body -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/actions/workflows/benchmark-pr.yml/dispatches" \
    -d "{\"ref\": \"${GITHUB_REF_NAME}\", \"inputs\": {\"pr_number\": \"${KBOT_PR_NUMBER}\", \"sha\": \"${head_sha}\"}}"
}

if [[ $KBOT_AUTHOR_ASSOC =~ ^(OWNER|MEMBER|COLLABORATOR)$ ]]; then
  parsed=$(parse_comment)

  # If the comment is empty, do nothing successfully.
  if [[ ! -z ${parsed} ]]; then
    cmd=$(echo "${parsed}" | awk '{print $1}')
    commit=$(echo "${parsed}" | awk '{print $2}')
    pull_request_json=$(curl -H "${HEADERS}" "${KBOT_PULL_REQUEST_URL}")

    case "${cmd}" in
      run_ci)
        is_fork=$(echo "$pull_request_json" | jq -r ".head.repo.fork")

        if [[ ${is_fork} == "true" ]]; then
          # At this point we've established that:
          #
          #  1. This pull request is coming from a forked repo
          #  2. A comment was made by someone trusted
          #  3. The comment indicated CI should be run on local runners
          kloon_fork_branch_to_local_branch "${pull_request_json}" "${commit}"
        fi
        ;;
      run_benchmark)
        # A trusted user approved a benchmark of this commit. Start
        # benchmark-pr.yml through a workflow_dispatch event.
        dispatch_benchmark "${pull_request_json}" "${commit}"
        ;;
    esac
  fi
fi
