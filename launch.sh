#!/bin/sh

set -eu

instance_id="${1:-}"
[ -n "$instance_id" ] || exit 2

if command -v prismlauncher >/dev/null 2>&1; then
  launcher="prismlauncher"
elif command -v PrismLauncher >/dev/null 2>&1; then
  launcher="PrismLauncher"
else
  exit 127
fi

exec "$launcher" --launch "$instance_id"
