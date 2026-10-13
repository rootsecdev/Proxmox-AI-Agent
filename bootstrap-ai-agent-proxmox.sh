#!/usr/bin/env bash
# Ubuntu 24.04 amd64 AI agent VM bootstrap for Proxmox.
# Installs Claude Code, Codex CLI, Ollama (cloud use), isolated developer tooling.
# Review upstream installers before execution. Run as a normal sudo-capable user.
set -Eeuo pipefail
trap 'echo "ERROR: command failed at line $LINENO" >&2' ERR

if [[ $EUID -eq 0 ]]; then echo 'Run as a normal user, not root.' >&2; exit 1; fi
if [[ $(uname -m) != x86_64 ]]; then echo 'This script targets x86_64/amd64.' >&2; exit 1; fi
if [[ ! -r /etc/os-release ]]; then exit 1; fi
. /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 24.04 ]]; then
  echo 'Requires Ubuntu 24.04 LTS.' >&2; exit 1
fi

INSTALL_AGENTS=${INSTALL_AGENTS:-1}
INSTALL_RUST=${INSTALL_RUST:-1}
INSTALL_OLLAMA=${INSTALL_OLLAMA:-1}
NODE_MAJOR=${NODE_MAJOR:-22}

sudo -v
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl wget git git-lfs jq unzip zip tar xz-utils \
  build-essential pkg-config cmake ninja-build clang lldb gdb make \
  python3 python3-venv python3-dev pipx \
  golang-go direnv shellcheck ripgrep fd-find \
  openssh-client openssl libssl-dev libffi-dev \
  qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
mkdir -p "$HOME/.local/bin" "$HOME/projects" "$HOME/.config"

# ~/.local/bin for pipx, uv, Claude and other user-level executables.
PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
for rc in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$rc"
  grep -Fqx "$PROFILE_LINE" "$rc" || printf '\n%s\n' "$PROFILE_LINE" >> "$rc"
done
export PATH="$HOME/.local/bin:$PATH"

# uv installer (isolated Python environments per project).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# fnm manages Node.js separately from Ubuntu apt packages.
if ! command -v fnm >/dev/null 2>&1; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
FNM_BIN="$HOME/.local/share/fnm/fnm"
if ! command -v fnm >/dev/null 2>&1 && [[ -x "$FNM_BIN" ]]; then
  export PATH="$(dirname "$FNM_BIN"):$PATH"
fi
if ! command -v fnm >/dev/null 2>&1; then
  echo 'fnm not found after installation; check installer output.' >&2; exit 1
fi
# Configure fnm permanently for Bash
FNM_START="# BEGIN FNM CONFIG"
FNM_END="# END FNM CONFIG"

# Remove any previous unguarded initialization
sed -i '/^eval "$(fnm env --use-on-cd --shell bash)"$/d' "$HOME/.bashrc"

# Add the configuration only once
if ! grep -Fqx "$FNM_START" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'

# BEGIN FNM CONFIG
export PATH="$HOME/.local/share/fnm:$PATH"

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi
# END FNM CONFIG
EOF
fi
eval "$(fnm env --shell bash)"
fnm install "$NODE_MAJOR"
fnm default "$NODE_MAJOR"
fnm use "$NODE_MAJOR"

# Optional Rust toolchain, kept under ~/.rustup and ~/.cargo.
if [[ "$INSTALL_RUST" == 1 ]]; then
  if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
fi

if [[ "$INSTALL_AGENTS" == 1 ]]; then
  # Official native Claude Code installer (no npm global dependency).
  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  # Codex CLI via npm under fnm-managed Node.js (user-owned, no sudo).
  if ! command -v codex >/dev/null 2>&1; then
    npm install -g @openai/codex
  fi
fi

if [[ "$INSTALL_OLLAMA" == 1 ]]; then
  # Official Linux Ollama installer; installs a system service.
  if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  # Cloud-only: no `ollama pull`, no local model downloads.
  # Restrict Ollama's API listener to localhost.
  if systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q '^ollama.service'; then
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    printf '[Service]\nEnvironment="OLLAMA_HOST=127.0.0.1:11434"\n' | \
      sudo tee /etc/systemd/system/ollama.service.d/10-localhost.conf >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable --now ollama
    sudo systemctl restart ollama
  fi
fi

printf '\n=== Verification ===\n'
for tool in git python3 pipx uv fnm node npm go rustc claude codex ollama; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%-10s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%-10s %s\n' "$tool" 'not installed or not yet in PATH'
  fi
done
printf '\nDone. Start a fresh shell: exec bash -l\n'
printf 'Authenticate Claude, Codex and Ollama Cloud interactively as your normal user.\n'
printf 'Python projects: cd ~/projects/<name> && uv init && uv venv && uv add <package>\n'
printf 'Standalone Python tools: pipx install <package>\n'
