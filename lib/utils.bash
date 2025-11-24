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

  local operating_system
  local architecture

  # Pick OS.
  if [[ ${ostype} == "linux-"* ]]; then
    operating_system="linux"
  elif [[ ${ostype} == "darwin"* ]]; then
    operating_system="darwin"
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

  # Construct download URL directly (following asdf-plugin-template best practice)
  # URL pattern: https://orus.io/api/v4/projects/3711/packages/generic/beaver/{version}/beaver_{version}_{os}_{arch}
  local download_url="https://orus.io/api/v4/projects/3711/packages/generic/${tool}/${version}/${tool}_${version}_${operating_system}_${architecture}"

  # Try arm64 first, fallback to x86_64 if needed
  if [[ $architecture == "arm64" ]]; then
    # Check if arm64 binary exists
    if ! curl --silent --fail --head "$download_url" > /dev/null 2>&1; then
      # Fall back to x86_64 if an arm64 binary is unavailable
      download_url="https://orus.io/api/v4/projects/3711/packages/generic/${tool}/${version}/${tool}_${version}_${operating_system}_x86_64"
    fi
  fi

  echo "$download_url"
}
