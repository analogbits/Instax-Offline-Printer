#!/bin/zsh
# ========================================================
# Install instax-square CLI system-wide
# ========================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/instax-square"

if [ ! -f "$BIN" ]; then
    echo "Error: Binary not found at $BIN"
    exit 1
fi

echo "Installing instax-square to /usr/local/bin/..."
if sudo cp "$BIN" /usr/local/bin/instax-square 2>/dev/null; then
    sudo chmod +x /usr/local/bin/instax-square
    echo "✓ Successfully installed /usr/local/bin/instax-square"
    echo "You can now run 'instax-square --help' from anywhere in Terminal!"
else
    mkdir -p "$HOME/.local/bin"
    cp "$BIN" "$HOME/.local/bin/instax-square"
    chmod +x "$HOME/.local/bin/instax-square"
    echo "✓ Installed to $HOME/.local/bin/instax-square"
fi
