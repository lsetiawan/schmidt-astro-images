#!/usr/bin/env bash
# Render each image's environment.yml from pixi.toml.
#
# The images are layered (pangeo -> base -> florence-symposium) and each
# Dockerfile runs `mamba env update` with its own environment.yml, so the
# florence-symposium file only lists what it adds on top of base.
#
# Usage: scripts/render-environments.sh   (or: pixi run render-envs)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
platform="linux-64"
header="# Generated from pixi.toml by scripts/render-environments.sh -- do not edit by hand."

export_env() {
  pixi workspace export conda-environment \
    --manifest-path "$root/pixi.toml" -e "$1" -p "$platform"
}

render() {
  local out="$1"
  { echo "$header"; cat; } > "$out"
  echo "Wrote ${out#"$root"/}"
}

base_yml="$(export_env base)"
printf '%s\n' "$base_yml" | sed '/^name:/d' | render "$root/base/environment.yml"

# Drop dependency lines already provided by the base image. The bare `- pip`
# that pixi adds ahead of the `pip:` section is kept.
export_env florence-symposium \
  | sed '/^name:/d' \
  | awk 'NR == FNR { if (/^dependencies:/) d = 1; else if (d && /^- / && $0 != "- pip:") seen[$0] = 1; next }
         /^dependencies:/ { d = 1 }
         !(d && ($0 in seen)) { print }' <(printf '%s\n' "$base_yml") - \
  | render "$root/florence-symposium/environment.yml"
