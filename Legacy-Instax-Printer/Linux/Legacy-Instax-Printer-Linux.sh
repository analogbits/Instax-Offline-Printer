#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Python 3 is required. Install python3 and python3-tk using your package manager."
    exit 1
fi

python3 -c "import PIL" >/dev/null 2>&1 || python3 -m pip install --user pillow
exec python3 LegacyInstaxPrinterGUI.py "$@"
