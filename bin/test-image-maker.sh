#!/bin/bash
set -euo pipefail

if ! command -v magick >/dev/null 2>&1; then
    printf '%s\n' 'Error: ImageMagick (magick) is required. Install ImageMagick and add magick to PATH before running this script (macOS: brew install imagemagick).' >&2
    exit 1
fi

usage() {
    printf '%s\n' \
        'Usage: test-image-maker.sh --app win|mac|linux|lrcplugin|dtplugin [--format wide|square|mini]' \
        '  --format  Instax format (default: square).' \
        '  --app     Application used to print the image (required).' \
        '  --help    Show this help.'
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

format=square
app=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --format|--app)
            [ "$#" -ge 2 ] || fail "Missing value for $1."
            case "$1" in
                --format) format=$2 ;;
                --app) app=$2 ;;
            esac
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *) fail "Unknown argument: $1. Use --help for usage." ;;
    esac
done

case "$format" in
    wide) width=1260; height=840 ;;
    square) width=800; height=800 ;;
    mini) width=600; height=800 ;;
    *) fail "Invalid format: $format. Choose wide, square, or mini." ;;
esac

case "$app" in
    win|mac|linux|lrcplugin|dtplugin) ;;
    '') fail '--app is required. Choose win, mac, linux, lrcplugin, or dtplugin.' ;;
    *) fail "Invalid app: $app. Choose win, mac, linux, lrcplugin, or dtplugin." ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if ! code_version=$(git -C "$repo_root" describe --tags --abbrev=0); then
    fail 'Cannot determine the code version. Git and a tag reachable from HEAD are required.'
fi

# Some macOS ImageMagick installations do not register the system fonts.
if [ -f /System/Library/Fonts/Helvetica.ttc ]; then
    font=/System/Library/Fonts/Helvetica.ttc
else
    fonts=$(magick -list font)
    font=$(printf '%s\n' "$fonts" | awk '
        /Font: / && $2 ~ /^(Arial|Helvetica|DejaVu-Sans|Liberation-Sans|Noto-Sans|NotoSans|FreeSans)$/ {
            print $2
            exit
        }
    ')
    [ -n "$font" ] || fail 'Install a sans-serif font (such as DejaVu Sans or Arial) that ImageMagick can find with magick -list font.'
fi

output_dir="$repo_root/tmp/test-images"
file_version=${code_version//\//-}
output_file="$output_dir/test-image-$format-$app-$file_version.jpg"
text=$(printf 'This image was printed with:\nanalogbits/Instax-Offline-Printer\nCode Version: %s\nApp: %s' "$code_version" "$app")

mkdir -p "$output_dir"
magick -size "$((width - 80))x$((height - 80))" \
    -background white -fill black -font "$font" -gravity center \
    label:"$text" -bordercolor white -border 40 \
    -colorspace sRGB -strip -quality 95 "$output_file"
printf '%s\n' "$output_file"
