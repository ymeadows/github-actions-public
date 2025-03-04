#!/usr/bin/env bash

# XXX Borrowed from https://github.com/selfuryon/nix-update-action

set -euo pipefail

enterFlakeFolder() {
  if [[ -n "$PATH_TO_FLAKE_DIR" ]]; then
    cd "$PATH_TO_FLAKE_DIR"
  fi
}

sanitizeInputs() {
  # remove all whitespace
  PACKAGES="${PACKAGES// /}"
  BLACKLIST="${BLACKLIST// /}"
}

determinePackages() {
  # determine packages to update
  PACKAGES=$(nix flake show --json |
    jq -r '[.packages[] | keys[] | select(test("'$PACKAGES'")) | select(test("'$BLACKLIST'")|not) ] | sort | unique |  join(",")')
}

updatePackages() {
  for PACKAGE in ${PACKAGES//,/ }; do
    if [[ ",$BLACKLIST," == *",$PACKAGE,"* ]]; then
        echo "Package '$PACKAGE' is blacklisted, skipping."
        continue
    fi
    echo "Updating package '$PACKAGE'."
    nix-update --flake ${VERSION:+--version=$VERSION} "$PACKAGE"
  done
}

# enterFlakeFolder
sanitizeInputs
determinePackages
updatePackages
