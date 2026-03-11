# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-10

### Added

- **6 Security Check Modules**
  - `checks/gateway.sh` - Gateway port binding, auth mode, TLS, token strength, all OpenClaw ports
  - `checks/credentials.sh` - File permissions, plaintext API keys, shell history leaks, auth-profiles
  - `checks/channels.sh` - DM policy, allowFrom wildcards, group policy, requireMention
  - `checks/tools.sh` - Sandbox mode, tools.deny, denyCommands, tool profiles, CDP ports
  - `checks/network.sh` - Port exposure scan, outbound connections, firewall, IP leak detection
  - `checks/system.sh` - macOS SIP, FileVault, TCC/FDA, camera/mic, screen recording, iCloud sync

- **Shared Library** (`lib/`)
  - `common.sh` - Colors, logging, safe JSON5 config parsing, counters, utility functions
  - `reporter.sh` - HTML and JSON report generation organized by MITRE ATLAS categories

- **Auto-Fix Suite** (`fixes/`)
  - `interactive-fix.sh` - Guided fix menu
  - `gateway-fix.sh` - Bind to localhost, generate strong token
  - `permission-fix.sh` - Fix file/directory permissions (700/600)
  - `channel-fix.sh` - Fix DM policy, allowFrom wildcards, requireMention

- **Interactive TUI** (`audit.sh`)
  - ASCII art banner
  - 5 menu options: Quick Check, Full Audit, Network Check, Interactive Fix, Generate Report
  - Help system

- **Test Suite** (`tests/`)
  - BATS tests for gateway, credentials, network modules
  - Fallback basic validation when BATS is not installed
  - Syntax validation for all scripts

- **Documentation**
  - English README
  - Chinese README (README.zh.md)

### Security Design
- Config parsing uses parameter passing (no string interpolation injection)
- External IP queries require explicit user confirmation
- All fixes require interactive confirmation before applying
- Graceful skip when OpenClaw is not installed
