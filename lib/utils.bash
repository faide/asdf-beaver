#!/usr/bin/env bash

set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_installation_type() {
  [[ $ASDF_INSTALL_TYPE == "version" ]] || {
    echo "ASDF_INSTALL_TYPE '${ASDF_INSTALL_TYPE}' not supported"
    exit 1
  } >&2
}

# Detect the tool name from the asdf plugin directory.
get_tool_name() {
  echo "beaver"
}

find_download_in_release_json() {
  local arg_release_json=$1
  local arg_tool=$2
  local arg_version=$3
  local arg_architecture=$4
  local arg_operating_system=$5

  echo "Searching for name=${arg_tool}, version=${arg_version} architecture=${arg_architecture}, operating_system=${arg_operating_system}" >&2

  jq -r -n \
    --argjson json "${arg_release_json}" \
    --arg tool "${arg_tool}" \
    --arg version "${arg_version}" \
    --arg arch "${arg_architecture}" \
    --arg ostype "${arg_operating_system}" '
    $json | [
      .assets.links[] |
      select(.name|ascii_downcase == "\($tool|ascii_downcase)_\($version|ascii_downcase)_\($ostype|ascii_downcase)_\($arch|ascii_downcase)")
    ] |
    first |
    .direct_asset_url // ""
  '
}

get_project_url() {
  local tool=$1

  echo "https://orus.io/api/v4/projects/orus-io%2fbeaver"
}

# Fetch the most appropriate download URL.
get_download_url() {
  local tool=$1
  local ostype=$2
  local uname_m=$3
  local version=$4

  local project_url
  project_url=$(get_project_url "${tool}")

  local release_url="${project_url}/releases/${version}"

  release_json=$(curl --silent --fail "${release_url}")
  readonly release_json

  if [[ -z $release_json ]]; then
    echo "Failed to download release information from ${release_url}" >&2
    return 1
  fi

  local operating_system
  local architecture

  # Pick OS.
  if [[ ${ostype} == "linux-"* ]]; then
    operating_system="Linux"
  elif [[ ${ostype} == "darwin"* ]]; then
    operating_system="Darwin"
  fi

  # Pick architecture.
  case "$uname_m" in
  aarch64_be | aarch64 | armv8b | armv8l | arm64)
    architecture="arm64"
    ;;
  *)
    architecture="x86_64"
    ;;
  esac

  download_url="$(find_download_in_release_json "$release_json" "$tool" "$version" "$architecture" "$operating_system")"

  if [[ $architecture == "arm64" ]] && [[ -z $download_url ]]; then
    # Fall back to x86_64 if an arm64 binary is unavailable.
    download_url="$(find_download_in_release_json "$release_json" "$tool" "$version" "x86_64" "$operating_system")"
  fi

  echo "$download_url"
}
