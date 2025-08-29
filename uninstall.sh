#!/usr/bin/env bash
set -euo pipefail

BIN="$HOME/.local/bin/dtun"
SYSD="$HOME/.config/systemd/user"

systemctl --user disable --now 'tunnel@*.service' 2>/dev/null || true
systemctl --user disable --now ssh-agent.service 2>/dev/null || true

rm -f "$BIN"
rm -f "$SYSD/ssh-agent.service" "$SYSD/tunnel@.service"

systemctl --user daemon-reload || true

echo "Uninstalled dtun and its units. Alias files remain under ~/.ssh/config.d/ (remove manually if desired)."
