#!/bin/sh
printf '\033c\033]0;%s\a' archipelago
base_path="$(dirname "$(realpath "$0")")"
"$base_path/archipelago.x86_64" "$@"
