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
    mini) width=800; height=600 ;;
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

os_name=$(uname -s)
os_version=$(uname -r)
case "$os_name" in
    Darwin)
        os_name=$(sw_vers -productName)
        os_version=$(sw_vers -productVersion)
        ;;
    Linux)
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            os_name=${NAME:-$os_name}
            os_version=${VERSION_ID:-$os_version}
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        if ! windows_info=$(powershell.exe -NoProfile -NonInteractive -Command \
            '$os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; $os.Caption; $os.Version'); then
            fail 'Cannot determine the Windows name and version using PowerShell.'
        fi
        windows_info=${windows_info//$'\r'/}
        os_name=${windows_info%%$'\n'*}
        os_version=${windows_info#*$'\n'}
        ;;
esac
[ -n "$os_name" ] && [ -n "$os_version" ] || fail 'Cannot determine the OS name and version.'

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
text=$(printf 'This image was printed with:\nanalogbits/Instax-Offline-Printer\nCode Version: %s\nApp: %s\nOS: %s\nOS Version: %s' "$code_version" "$app" "$os_name" "$os_version")

mkdir -p "$output_dir"
margin=20
magick -size "$((width - 2 * margin))x$((height - 2 * margin))" \
    -background white -fill black -font "$font" -gravity center \
    label:"$text" -bordercolor white -border "$margin" \
    -colorspace sRGB -strip -quality 95 "$output_file"
printf '%s\n' "$output_file"
