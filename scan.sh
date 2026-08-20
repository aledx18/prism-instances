#!/bin/sh

set -eu

launcher=""
if command -v prismlauncher >/dev/null 2>&1; then
  launcher="prismlauncher"
elif command -v PrismLauncher >/dev/null 2>&1; then
  launcher="PrismLauncher"
fi

if [ -z "$launcher" ]; then
  printf '#available\t0\n'
  exit 0
fi

printf '#available\t1\n'

data_dir="${PRISM_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher}"
base="${PRISM_INSTANCES_DIR:-$data_dir/instances}"

icons_dir="$data_dir/icons"
launcher_config="$data_dir/prismlauncher.cfg"
if [ -f "$launcher_config" ]; then
  configured_icons_dir=$(awk -F= '$1 == "IconsDir" { print $2; exit }' "$launcher_config")
  case "$configured_icons_dir" in
    /*) icons_dir="$configured_icons_dir" ;;
    "") ;;
    *) icons_dir="$data_dir/$configured_icons_dir" ;;
  esac
fi

if command -v jq >/dev/null 2>&1 && [ -f "$data_dir/accounts.json" ]; then
  account_name=$(jq -r '[.accounts[] | select(.active == true) | .profile.name // empty][0] // empty' "$data_dir/accounts.json")
  [ -n "$account_name" ] && printf '#account\t%s\n' "$account_name"
fi

[ -d "$base" ] || exit 0

for dir in "$base"/*; do
  [ -d "$dir" ] || continue
  config="$dir/instance.cfg"
  [ -f "$config" ] || continue

  id=${dir##*/}
  name=$(awk -F= '$1 == "name" { print substr($0, index($0, "=") + 1); exit }' "$config")
  [ -n "$name" ] || name="$id"
  icon_key=$(awk -F= '$1 == "iconKey" { print substr($0, index($0, "=") + 1); exit }' "$config")
  icon_path=""
  if [ -n "$icon_key" ] && [ -f "$icons_dir/$icon_key.png" ]; then
    icon_path="$icons_dir/$icon_key.png"
  fi

  version=""
  loader=""
  pack="$dir/mmc-pack.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$pack" ]; then
    version=$(jq -r '[.components[] | select(.uid == "net.minecraft") | .version][0] // empty' "$pack")
    loader=$(jq -r '[.components[]
      | select(.uid != "net.minecraft" and .uid != "org.lwjgl3" and .dependencyOnly != true)
      | ((.cachedName // .uid) + " " + (.version // ""))]
      | join(", ")' "$pack")
  fi

  total_time=$(awk -F= '$1 == "totalTimePlayed" { print $2; exit }' "$config")
  last_launch=$(awk -F= '$1 == "lastLaunchTime" { print $2; exit }' "$config")
  instance_path="$dir/minecraft"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$name" "$version" "$loader" "${total_time:-0}" "$icon_path" "${last_launch:-0}" "$instance_path"
done
