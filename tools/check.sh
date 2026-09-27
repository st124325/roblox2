#!/usr/bin/env bash
# Compile every Luau file to catch syntax errors, then build the place with Rojo.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
while IFS= read -r file; do
	if ! out="$(luau-compile --binary "$file" 2>&1 >/dev/null)"; then
		echo "$out"
		status=1
	fi
done < <(find src -name '*.luau')
rojo build default.project.json -o StealAKaiju.rbxlx >/dev/null
[ $status -eq 0 ] && echo "OK: all files compile, StealAKaiju.rbxlx built"
exit $status
