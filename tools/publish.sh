#!/usr/bin/env bash
# Build the place with Rojo and publish it to Roblox through Open Cloud
# (https://create.roblox.com/docs/cloud/guides/usage-place-publishing).
#
# Settings live outside the repo in ~/.config/stealakaiju/publish.env:
#   ROBLOX_API_KEY=...   Open Cloud key with universe-places:write on the game
#   UNIVERSE_ID=...      the experience (from the Creator Hub URL)
#   PLACE_ID=...         the start place (from the roblox.com/games/<id> URL)
#
# Usage: tools/publish.sh          publish a live version players get
#        tools/publish.sh --saved  save a version without making it live
set -euo pipefail
cd "$(dirname "$0")/.."

config="${STEALAKAIJU_PUBLISH_ENV:-$HOME/.config/stealakaiju/publish.env}"
if [ ! -f "$config" ]; then
	echo "Нет файла настроек: $config" >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$config"
for name in ROBLOX_API_KEY UNIVERSE_ID PLACE_ID; do
	value="${!name:-}"
	if [ -z "$value" ] || [[ "$value" == *"ВСТАВЬ"* ]]; then
		echo "В $config не заполнено: $name" >&2
		exit 1
	fi
done

version_type="Published"
if [ "${1:-}" = "--saved" ]; then
	version_type="Saved"
fi

place="$(mktemp --suffix=.rbxl)"
trap 'rm -f "$place"' EXIT
rojo_bin="$(command -v rojo || echo "$HOME/.local/bin/rojo")"
"$rojo_bin" build default.project.json -o "$place"

echo "Загружаю в Roblox ($version_type)..."
response="$(curl --silent --show-error --noproxy '*' --write-out '\n%{http_code}' \
	--request POST \
	"https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=$version_type" \
	--header "x-api-key: $ROBLOX_API_KEY" \
	--header "Content-Type: application/octet-stream" \
	--data-binary @"$place")"
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$status" = "200" ]; then
	version="$(printf '%s' "$body" | sed -n 's/.*"versionNumber":[[:space:]]*\([0-9]*\).*/\1/p')"
	echo "✓ Опубликовано: версия ${version:-?} (https://www.roblox.com/games/$PLACE_ID)"
	if [ "$version_type" = "Published" ]; then
		echo "  Новые серверы запустятся с этой версией; уже открытые доиграют на старой."
	fi
else
	echo "✗ Ошибка $status: $body" >&2
	case "$status" in
		401) echo "  Ключ не принят: проверь ROBLOX_API_KEY." >&2 ;;
		403) echo "  У ключа нет доступа: нужен universe-places:write для этой игры (и разрешённый IP)." >&2 ;;
		404) echo "  Не найдена игра или место: проверь UNIVERSE_ID и PLACE_ID." >&2 ;;
	esac
	exit 1
fi
