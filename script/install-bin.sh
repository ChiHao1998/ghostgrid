#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN=/usr/local/bin/ghostgrid

cat > "$BIN" <<EOF
#!/usr/bin/env bash
exec bash "$REPO_DIR/main.sh" "\$@"
EOF

chmod +x "$BIN"
echo "Installed: $BIN -> $REPO_DIR/main.sh"
echo "Run: ghostgrid"
