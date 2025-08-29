#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
SYSD_DIR="$HOME/.config/systemd/user"
SSH_DIR="$HOME/.ssh"
CONF_D="$SSH_DIR/config.d"

echo ">> Creating dirs"
mkdir -p "$BIN_DIR" "$SYSD_DIR" "$CONF_D"

echo ">> Installing dtun"
install -m 0755 bin/dtun "$BIN_DIR/dtun"

echo ">> Installing systemd units"
install -m 0644 systemd/ssh-agent.service "$SYSD_DIR/ssh-agent.service"
install -m 0644 systemd/tunnel@.service "$SYSD_DIR/tunnel@.service"

echo ">> Ensuring ~/.ssh/config includes ~/.ssh/config.d/*"
touch "$SSH_DIR/config"
if ! grep -qE '^\s*Include\s+~/.ssh/config\.d/\*' "$SSH_DIR/config"; then
  {
    echo ""
    echo "Include ~/.ssh/config.d/*"
  } >> "$SSH_DIR/config"
  echo "   Added 'Include ~/.ssh/config.d/*' to ~/.ssh/config"
fi

echo ">> Enabling user ssh-agent"
systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.service

echo ">> Enabling linger so user services survive reboot"
loginctl enable-linger "$USER" >/dev/null 2>&1 || true

echo ">> Done. Ensure 'autossh' is installed (e.g. 'sudo apt install autossh' or 'sudo pacman -S autossh')."
echo "   Next: dtun init"
