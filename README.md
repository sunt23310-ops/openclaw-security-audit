<div align="center">

# OpenClaw Security Audit

### Protect your OpenClaw, guard your privacy

[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=for-the-badge&logo=apple)](https://github.com/sunt23310-ops/openclaw-security-audit)
[![Version](https://img.shields.io/badge/version-1.0.0-green?style=for-the-badge)](https://github.com/sunt23310-ops/openclaw-security-audit)

**English** | [中文](./README.zh.md)

</div>

---

## What is this?

A comprehensive security audit tool for [OpenClaw](https://github.com/openclaw/openclaw) - the personal AI assistant platform. It checks your OpenClaw deployment for security misconfigurations, credential exposure, and privacy risks.

**This tool is read-only by default.** It only modifies your system when you explicitly run the fix commands and confirm each change.

## Quick Start

```bash
git clone https://github.com/sunt23310-ops/openclaw-security-audit.git
cd openclaw-security-audit
./audit.sh
```

## What It Checks

### 6 Security Modules

| Module | What It Checks |
|--------|---------------|
| **Gateway** | Port binding (0.0.0.0 vs localhost), auth mode, TLS, token strength, all OpenClaw ports (18789-18793, CDP 18800-18899) |
| **Credentials** | `~/.openclaw/` directory permissions, `.env` file permissions, plaintext API keys in config, shell history leaks, auth-profiles security |
| **Channels** | DM policy (open vs pairing), `allowFrom: ["*"]` wildcards, group policy, `requireMention` settings |
| **Tools & Sandbox** | Sandbox mode (off/non-main/all), `tools.deny` list, `denyCommands` blacklist, tool profiles, CDP port exposure |
| **Network** | All port exposure scan, outbound connections, firewall status, IP leak detection (local + Shodan) |
| **System (macOS)** | SIP, FileVault, TCC/Full Disk Access, camera/microphone, screen recording, iCloud sync exposure, Gatekeeper |

### Security Threat Model

Checks are organized around [OpenClaw's MITRE ATLAS threat model](https://trust.openclaw.ai):

- **Reconnaissance** - Port exposure, IP in scanning databases
- **Initial Access** - Open DM policies, weak tokens, allowFrom wildcards
- **Credential Exposure** - Plaintext keys, loose file permissions, history leaks
- **Execution** - Sandbox disabled, no command blacklist, full tool profiles
- **System Security** - SIP, FileVault, TCC permissions

## Usage

### Interactive Menu (Recommended)

```bash
./audit.sh
```

### Run Individual Checks

```bash
bash checks/gateway.sh        # Gateway security
bash checks/credentials.sh    # Credential security
bash checks/channels.sh       # Channel policies
bash checks/tools.sh          # Tools & sandbox
bash checks/network.sh        # Network exposure
bash checks/system.sh         # macOS system security
```

### Auto-Fix

```bash
bash fixes/interactive-fix.sh    # Guided fix menu
bash fixes/gateway-fix.sh        # Fix gateway binding & token
bash fixes/permission-fix.sh     # Fix file permissions
bash fixes/channel-fix.sh        # Fix channel policies
```

### Generate Reports

Reports are saved to `history/` in HTML or JSON format (organized by MITRE ATLAS categories).

## Available Fixes

All fixes require explicit confirmation before applying:

| Fix | What It Does |
|-----|-------------|
| Bind gateway to localhost | Sets `gateway.bind` to `127.0.0.1` |
| Generate strong token | Creates 64-char random token, sets auth mode to `token` |
| Fix file permissions | Sets `~/.openclaw/` to 700, `.env` to 600, auth-profiles to 600 |
| Fix DM policy | Changes `open` DM policies to `pairing` |
| Remove allowFrom wildcards | Removes `["*"]` entries from channel configs |
| Enable requireMention | Requires @mention for bot to respond in groups |

## Use as a Skill

### OpenClaw Skill

Copy the skill into your OpenClaw workspace to use `/security-audit` as a slash command:

```bash
cp -r skills/openclaw-skill ~/.openclaw/skills/security-audit
```

Then in any OpenClaw conversation, type `/security-audit` to run a security check.

### Claude Code Skill

Copy the skill into your Claude Code project or global skills:

```bash
# Project-level (current repo only)
mkdir -p .claude/skills/security-audit
cp skills/claude-code-skill/SKILL.md .claude/skills/security-audit/SKILL.md

# Or global (available in all projects)
mkdir -p ~/.claude/skills/security-audit
cp skills/claude-code-skill/SKILL.md ~/.claude/skills/security-audit/SKILL.md
```

Then type `/security-audit` in Claude Code to invoke.

## Privacy

- **No data is sent externally** unless you explicitly opt-in to IP leak detection
- IP leak detection uses [Shodan InternetDB](https://internetdb.shodan.io/) (public API, no auth required)
- You are always prompted before any external request is made

## Requirements

- macOS (for system-level checks; gateway/credential/channel checks work on Linux)
- Python 3 (for JSON5 config parsing)
- OpenClaw installed (gracefully skips checks if not found)

## Running Tests

```bash
bash tests/run-tests.sh
```

## License

MIT License - see [LICENSE](./LICENSE)
