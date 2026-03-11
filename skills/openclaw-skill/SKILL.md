---
name: security-audit
description: "Run OpenClaw security audit — check gateway, credentials, channels, tools, network, and system security"
user-invocable: true
disable-model-invocation: false
metadata: {"openclaw": {"emoji": "🔒", "os": ["darwin", "linux"], "requires": {"anyBins": ["python3", "python"]}, "install": [{"id": "clone", "kind": "download", "label": "Clone openclaw-security-audit", "bins": ["audit.sh"]}]}}
---

# OpenClaw Security Audit Skill

Run a comprehensive security audit on the current OpenClaw installation. Checks 6 security domains: gateway, credentials, channels, tools & sandbox, network, and system (macOS).

## When to Use

- User asks to "check security", "audit security", "run security check", or "is my openclaw secure?"
- User mentions concerns about API key leaks, exposed ports, or privacy
- User wants to verify their OpenClaw configuration is safe
- After changing OpenClaw config (gateway, channels, tools, etc.)

## When NOT to Use

- User is asking about general (non-OpenClaw) system security
- User wants to audit a different application
- User is just asking what OpenClaw is

## How to Run

The audit tool is located at `{baseDir}/../../`. Run checks individually or all at once.

### Quick Check (critical items only)

```bash
bash {baseDir}/../../checks/gateway.sh && bash {baseDir}/../../checks/credentials.sh
```

### Full Audit (all 6 modules)

```bash
for check in gateway credentials channels tools network system; do
  bash {baseDir}/../../checks/${check}.sh
done
```

### Individual Checks

Run a specific module when the user asks about a particular area:

| User asks about | Run |
|----------------|-----|
| Gateway, ports, binding, auth | `bash {baseDir}/../../checks/gateway.sh` |
| API keys, passwords, tokens, permissions | `bash {baseDir}/../../checks/credentials.sh` |
| WhatsApp, Telegram, DM policy, channels | `bash {baseDir}/../../checks/channels.sh` |
| Sandbox, tools, denyCommands | `bash {baseDir}/../../checks/tools.sh` |
| IP leak, exposed ports, firewall | `bash {baseDir}/../../checks/network.sh` |
| SIP, FileVault, TCC, iCloud | `bash {baseDir}/../../checks/system.sh` |

### Auto-Fix

When issues are found and the user wants to fix them:

```bash
bash {baseDir}/../../fixes/interactive-fix.sh
```

Or run specific fixes:
- `bash {baseDir}/../../fixes/gateway-fix.sh` — bind to localhost, generate strong token
- `bash {baseDir}/../../fixes/permission-fix.sh` — fix file/directory permissions
- `bash {baseDir}/../../fixes/channel-fix.sh` — fix DM policy, allowFrom, requireMention

### Generate Report

```bash
bash {baseDir}/../../audit.sh
```
Then select option 5 for HTML/JSON report.

## Output Format

Each check outputs lines in the format:
- `[PASS]` — check passed, no action needed
- `[WARN]` — potential issue, review recommended
- `[FAIL]` — security issue found, fix recommended
- `[SKIP]` — check skipped (component not installed/found)

## Important Notes

- This tool is **read-only by default**. Fix scripts require explicit user confirmation.
- The **IP leak check** (in network module) will ask before sending your IP to external services.
- All checks gracefully skip if OpenClaw is not installed.
