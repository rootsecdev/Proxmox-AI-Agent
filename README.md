# Proxmox AI Agent VM Bootstrap

A Bash bootstrap script for deploying a dedicated AI-assisted development environment on **Ubuntu 24.04 LTS (AMD64)** running under **Proxmox VE**.

The environment integrates **Claude Code CLI**, **OpenAI Codex CLI**, and **Ollama Cloud** with isolated development toolchains. It is designed for cybersecurity research, exploit development, code review, and general software engineering.

## Features

- **Claude Code CLI** — AI-assisted software development and code review using Anthropic models.
- **OpenAI Codex CLI** — Terminal-based coding agent powered by OpenAI models.
- **Ollama** — Access to Ollama Cloud models without requiring local GPU inference.
- **Python** — Project-level dependency isolation using `uv` and application isolation using `pipx`.
- **Node.js** — Version management using `fnm`.
- **Go** — Go development toolchain.
- **Rust** — Rust toolchain managed through `rustup`.
- **Development Utilities** — Git, compilers, debuggers, and common Linux development tools.
- **Proxmox Integration** — QEMU Guest Agent for improved virtual machine management.

OpenCode is intentionally excluded.

## Architecture

The deployment uses a single Ubuntu virtual machine containing all three AI interfaces.

```text
Proxmox VE Host
│
├── Ubuntu 24.04 LTS VM (AMD64)
│   │
│   ├── AI Coding Agents
│   │   ├── Claude Code CLI
│   │   └── OpenAI Codex CLI
│   │
│   ├── Ollama
│   │   └── Ollama Cloud Models
│   │
│   ├── Development Toolchains
│   │   ├── Python / uv / pipx
│   │   ├── Node.js / fnm
│   │   ├── Go
│   │   └── Rust / rustup
│   │
│   └── Proxmox Integration
│       └── QEMU Guest Agent
│
└── External Cloud Services
    ├── Anthropic
    ├── OpenAI
    └── Ollama Cloud
```

Cloud inference eliminates the need for a dedicated GPU inside the virtual machine.

## System Requirements

### Recommended Proxmox VM Configuration

| Component | Recommendation |
|---|---|
| Hypervisor | Proxmox VE |
| Operating System | Ubuntu 24.04 LTS Server |
| Architecture | AMD64 / x86-64 |
| CPU | 8 vCPU |
| Memory | 24 GB RAM |
| Storage | 200 GB |
| CPU Type | `host` |
| Machine Type | `q35` |
| BIOS | OVMF (UEFI) |
| SCSI Controller | VirtIO SCSI Single |
| Network Adapter | VirtIO |
| QEMU Guest Agent | Enabled |

### Minimum Suggested Resources

| Component | Minimum |
|---|---|
| CPU | 4 vCPU |
| RAM | 8 GB |
| Storage | 60 GB |

These are suggested allocations, not hard requirements. Resource needs depend on repository size, concurrent agent sessions, compilation workloads, and development tools.

## Installation

### 1. Prepare Ubuntu

Install Ubuntu 24.04 LTS Server and update the operating system.

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

Use a regular user account with `sudo` privileges.

### 2. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
cd YOUR-REPOSITORY
```

Replace the placeholder URL with your GitHub repository URL.

### 3. Review the Bootstrap Script

The script installs development utilities and may invoke upstream software installers.

Review the script before execution:

```bash
less bootstrap-ai-agent-proxmox.sh
```

Review downloaded installer sources and their security implications before running them.

### 4. Execute the Bootstrap Script

```bash
chmod +x bootstrap-ai-agent-proxmox.sh
./bootstrap-ai-agent-proxmox.sh
```

Run the script as your normal Ubuntu user, not directly as root.

An internet connection is required to retrieve packages and upstream installers.

### 5. Reload Your Shell

```bash
exec bash -l
```

### 6. Verify Installation

Check the installed AI tools:

```bash
claude --version
codex --version
ollama --version
```

Verify development toolchains:

```bash
python3 --version
uv --version
pipx --version
node --version
npm --version
go version
rustc --version
cargo --version
```

Verify the Proxmox Guest Agent:

```bash
systemctl status qemu-guest-agent
```

Some commands may require a new login session before their executable paths become available.

## AI Service Authentication

Each AI service requires separate authentication.

### Claude Code

```bash
claude
```

Follow the interactive authentication instructions.

### OpenAI Codex

```bash
codex
```

Follow the interactive authentication instructions.

### Ollama Cloud

```bash
ollama signin
```

After authentication, use an Ollama Cloud model available to your account.

```bash
ollama run <cloud-model-name>
```

Replace the placeholder with an available cloud model identifier.

Cloud models require network access and may be subject to subscription, usage, or rate limits.

## Dependency Isolation

The bootstrap environment is designed to minimize conflicts between system packages, development frameworks, and cybersecurity research tools.

### Python

Python project dependencies should be managed using `uv`.

Example:

```bash
mkdir -p ~/projects/python-research
cd ~/projects/python-research

uv init
uv add requests
```

For standalone Python CLI tools, use `pipx`:

```bash
pipx install <package-name>
```

Avoid modifying the system Python environment using `sudo pip install`.

### Node.js

Node.js versions are managed using `fnm`.

Example:

```bash
fnm install --lts
fnm use --lts
```

Use project-local npm dependencies whenever possible.

### Rust

Rust toolchains and project dependencies are managed using `rustup` and Cargo.

```bash
rustup update
cargo --version
```

### Go

Use Go modules to isolate project dependencies:

```bash
mkdir -p ~/projects/go-research
cd ~/projects/go-research

go mod init example.com/go-research
```

## Recommended Development Workflow

For projects involving both Claude Code and Codex, Git worktrees can help prevent concurrent agents from modifying the same files.

Example:

```bash
git worktree add ../project-claude -b claude-dev
git worktree add ../project-codex -b codex-review
```

Each agent can work in its own checkout while sharing the same underlying Git repository.

Suggested workflow:

1. Develop or refactor code using Claude Code.
2. Review the implementation independently using Codex.
3. Run tests and static analysis.
4. Review proposed changes manually.
5. Merge validated changes into the primary branch.

## Security Considerations

AI coding agents can read files, execute commands, modify repositories, and interact with external services depending on their configuration and permissions.

Recommended security practices:

- Use a dedicated, non-root Linux account.
- Restrict agent access to sensitive files and credentials.
- Avoid storing API keys directly in shell scripts or Git repositories.
- Review agent-generated commands before executing potentially destructive operations.
- Use Git to track and review changes.
- Keep the Ubuntu VM updated.
- Restrict inbound network access using the Proxmox firewall.
- Keep Ollama's API bound to localhost unless remote access is explicitly required.
- Use separate, isolated environments for executing untrusted exploit code.
- Review client confidentiality requirements before sending source code or research artifacts to cloud AI providers.

**This VM is intended for AI-assisted development and code review, not as a security boundary for executing untrusted exploits.**

For offensive security testing, use an isolated lab VM or dedicated testing environment.

## Proxmox Recommendations

### QEMU Guest Agent

Enable the QEMU Guest Agent in the Proxmox VM options and confirm the service is running inside Ubuntu.

```bash
sudo systemctl enable --now qemu-guest-agent
```

### Snapshots and Backups

Recommended snapshot points:

- Clean Ubuntu installation
- Successful bootstrap installation
- AI agent authentication and configuration
- Before major development toolchain changes

Snapshots are useful for rollback, but scheduled VM backups should also be maintained.

### Performance Monitoring

Monitor VM resource consumption using:

```bash
free -h
top
df -h
```

Increase memory or CPU allocation only when observed workloads justify it.

Cloud model inference performance is primarily influenced by the remote service and network connectivity rather than local vCPU count.

## Troubleshooting

### Command Not Found After Installation

Reload the login shell:

```bash
exec bash -l
```

Confirm that the relevant user-level binary directory is included in `PATH`.

### Python Package Conflicts

Create a fresh project environment:

```bash
uv venv
```

Install dependencies through the project's package manager rather than the system Python installation.

### Node.js Version Problems

Check the active Node.js version:

```bash
fnm current
node --version
```

Install or activate an appropriate version through `fnm`.

### Ollama Cloud Connectivity

Check the installed Ollama version:

```bash
ollama --version
```

Confirm that authentication is configured and the VM can reach the required cloud endpoints.

### QEMU Guest Agent Not Running

```bash
sudo systemctl restart qemu-guest-agent
systemctl status qemu-guest-agent
```

Also confirm that the guest agent option is enabled in Proxmox.

## Project Structure

```text
proxmox-ai-agent-bootstrap/
├── README.md
├── bootstrap-ai-agent-proxmox.sh
└── LICENSE
```

## Maintenance

Keep system packages updated:

```bash
sudo apt update && sudo apt upgrade
```

Update language toolchains and AI agents using their respective supported update mechanisms.

Avoid blindly upgrading all development dependencies simultaneously. For reproducible projects, use dependency lockfiles and test updates before adoption.

## Disclaimer

This project is provided for educational, research, and authorized security development purposes.

Users are responsible for reviewing downloaded software, protecting credentials, complying with third-party service terms, and ensuring security testing is performed only against systems they are authorized to assess.

## License

Choose and add a license appropriate for your project, such as the MIT License. Until a license is added, no open-source reuse permission is granted by default.
