# dtun — Declarative Tunnels, User-space, No-fuss

`dtun` is a tiny CLI plus user-level systemd units that make SSH tunnels **dead simple** and reliable.  
It manages a persistent `ssh-agent`, reads your per-alias SSH config, loads the right key, and runs the tunnel with `autossh` so it survives hiccups and restarts.

---

## ✨ Features

- **One-liner tunnels by alias**: `dtun start <alias>`
- **Per-alias SSH config** in `~/.ssh/config.d/<alias>.conf` (clean and declarative)
- **Persistent user ssh-agent** with socket exported to systemd services
- **Key loading**: automatically `ssh-add`s the `IdentityFile` from the alias
- **Robust tunnels** via `autossh -N -T <alias>`
- **User services**: start/stop/enable/disable/status/logs (systemd — no root)
- **Cross-distro friendly**: Ubuntu/Debian/Arch examples included

> Current commands (MVP): `init`, `alias add|list|show|rm`, `key add`, `start|stop|enable|disable|status|logs`.

Roadmap includes `key gen`, `key copy`, `ssh`, `test`, multi-forward, ProxyJump, macOS support, and packaging.

---

## 🧱 Requirements

- Linux with **systemd user services** (most desktop/server distros)
- **OpenSSH client** (`ssh`, `ssh-agent`, `ssh-add`)
- **autossh**
- `bash` (the CLI is a bash script)

### Install autossh

Ubuntu/Debian:
```bash
sudo apt update && sudo apt install -y autossh
```

Arch/EndeavourOS:
```bash
sudo pacman -S autossh
```

---

## 📦 Install dtun

Assuming you have the repository cloned locally (recommended layout below), run the installer:

```bash
./install.sh
```

What the installer does:
- Installs the CLI to `~/.local/bin/dtun` (ensure this is on your `PATH`)
- Installs user systemd units to `~/.config/systemd/user/`
  - `ssh-agent.service` (persistent agent with `%t/ssh-agent.socket`)
  - `tunnel@.service` (runs `autossh -N -T <alias>`)
- Ensures your `~/.ssh/config` includes `~/.ssh/config.d/*`
- Enables and starts the user **ssh-agent** service
- Enables **linger** so your user services can survive logout/reboot

> If `~/.local/bin` is not on your PATH, add this to your shell profile:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

Repo layout (expected by `install.sh`):

dtun/
├─ bin/
│ └─ dtun
├─ systemd/
│ ├─ ssh-agent.service
│ └─ tunnel@.service


---

## ⚡ Quickstart (5 minutes)

1) **Initialize dtun (agent + linger + sanity)**
```bash
dtun init
```

2) **Create an alias** (example: local `3307` → remote `127.0.0.1:3306`)
```bash
dtun alias add \
  --alias mydev \
  --host 192.0.2.10 \
  --user devuser \
  --lport 3307 \
  --rport 3306 \
  --identity ~/.ssh/id_ed25519
```

This writes `~/.ssh/config.d/mydev.conf`:
```sshconfig
Host mydev
  HostName 192.0.2.10
  User devuser
  Port 22
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  PreferredAuthentications publickey
  StrictHostKeyChecking accept-new
  ServerAliveInterval 30
  ServerAliveCountMax 3
  ExitOnForwardFailure yes
  LocalForward 3307 127.0.0.1:3306
```

3) **Load your key into the agent** (prompts once per login if passphrase-protected)
```bash
dtun key add mydev
```

4) **Start the tunnel and verify**
```bash
dtun start mydev
dtun status mydev            # systemd status
ss -ltnp | grep ':3307 '     # expect a LISTEN on 127.0.0.1:3307
```

5) **Use it (example: MySQL over the tunnel)**
```bash
mysql -h 127.0.0.1 -P 3307 -u <DB_USER> -p -e 'SELECT 1;'
```

6) **Auto-start at login**
```bash
dtun enable mydev
```

Stop / logs when needed:
```bash
dtun stop mydev
dtun logs mydev
```

---

## 🧠 Concepts

- **Alias**: an OpenSSH `Host` stanza kept in `~/.ssh/config.d/<alias>.conf`.  
  It defines: `HostName`, `User`, `IdentityFile`, and at least one `LocalForward`.
- **ssh-agent**: user-level agent unit `ssh-agent.service` keeps your keys loaded and exposes a socket at `%t/ssh-agent.socket` for other user services.
- **tunnel@.service**: a systemd *template* unit. `tunnel@mydev.service` simply runs:
  ```bash
  autossh -M 0 -N -T mydev
  ```
  relying on the alias to define all the SSH details.

---

## 🔧 Commands (MVP)

### Bootstrap
```bash
dtun init
```
- Enables and starts `ssh-agent.service`
- Adds `Include ~/.ssh/config.d/*` to `~/.ssh/config` (if missing)
- Enables user lingering for persistence across reboots

### Manage aliases
```bash
dtun alias add --alias ALIAS --host HOST --user USER \
  --lport LPORT --rport RPORT \
  [--port 22] [--lhost 127.0.0.1] [--rhost 127.0.0.1] \
  [--identity PATH] [--strict accept-new]
dtun alias list
dtun alias show <ALIAS>
dtun alias rm <ALIAS>
```

### Keys
```bash
dtun key add <ALIAS>     # loads IdentityFile from alias into ssh-agent
```

### Tunnels
```bash
dtun start   <ALIAS>
dtun stop    <ALIAS>
dtun enable  <ALIAS>     # autostart at login
dtun disable <ALIAS>
dtun status  <ALIAS>
dtun logs    <ALIAS>
```

---

## 🧪 Verification Checklist

```bash
# 1) Agent up
systemctl --user status ssh-agent.service --no-pager
echo "$SSH_AUTH_SOCK"   # should be /run/user/<uid>/ssh-agent.socket

# 2) Alias resolves
ssh -G mydev | egrep '^(user|hostname|port|identityfile|localforward)'

# 3) Key loaded
dtun key add mydev
ssh-add -l

# 4) Tunnel listening
dtun start mydev
ss -ltnp | grep ':3307 '

# 5) Connectivity (DB example)
mysql -h 127.0.0.1 -P 3307 -u <DB_USER> -p -e 'SELECT 1;'
```

---

## 🧯 Troubleshooting

**Permission denied (publickey,password)** in `dtun logs <alias>`  
- Key not loaded or wrong IdentityFile/User in alias.  
- Check:
  ```bash
  ssh -G <alias> | egrep '^(user|hostname|identityfile|localforward)'
  dtun key add <alias>
  ssh-add -l
  ```

**Tunnel “started” but no port is listening**  
- SSH likely failing and autossh is restarting.  
- See logs: `dtun logs <alias>`  
- Verify `LocalForward` in alias and that the server allows login.

**Port already in use**  
- Change `--lport` or find the process:
  ```bash
  ss -ltnp | grep LISTEN
  ```

**Agent socket missing in services**  
- Ensure the unit contains:
  ```ini
  Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
  After=ssh-agent.service
  Wants=ssh-agent.service
  ```
- Reload: `systemctl --user daemon-reload` and restart agent.

**IdentityFile path shows `/home/user/~/.ssh/...`**  
- Use `~/.ssh/...` or an absolute path in your alias; current dtun expands `~` correctly.

**Enter passphrase on each reboot (headless)**  
- You’ll need a keyring/askpass solution or enter the passphrase once per login when you first run `dtun key add`/`dtun start` after reboot.

---

## 🔒 Security Notes

- `dtun` never stores secrets; it only reads `IdentityFile` paths and calls `ssh-add`.
- Prefer **key-based auth**; disable password logins on the server when possible.
- Host key policy defaults to `accept-new` — switch to `yes` if you want stricter checks.
- Consider separate keys per environment/host; set tight file permissions on `~/.ssh`.

---

## 🧹 Uninstall

```bash
./uninstall.sh
# This removes the CLI and user units. Your alias files in ~/.ssh/config.d remain.
```

---

## 🗺️ Roadmap (short)

- `key gen`, `key copy`, `ssh`, `test`
- Multiple `LocalForward` entries per alias
- ProxyJump support in `alias add`
- macOS (launchd) helper
- Packaging (Homebrew, .deb, AUR)
- Zsh/fish completions
- Import/export aliases (YAML/JSON)

---

## 🙌 Credits

Built to save time (and sanity) when working with remote dev DBs and internal services behind SSH.
