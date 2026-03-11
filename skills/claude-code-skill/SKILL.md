---
name: security-audit
description: "Run OpenClaw security audit — check gateway, credentials, channels, tools, network, and system security"
user-invocable: true
disable-model-invocation: false
---

# OpenClaw Security Audit

Run a comprehensive security audit on the local OpenClaw installation.

## When to Use

- User asks to "check security", "audit my openclaw", "is my config secure?"
- User mentions concerns about API key leaks, exposed ports, or privacy
- After the user changes OpenClaw configuration

## When NOT to Use

- General system security questions unrelated to OpenClaw
- User is asking about a different application

## Setup

The audit tool must be cloned first. Check if it exists:

```bash
ls ~/openclaw-security-audit/audit.sh 2>/dev/null || echo "NOT_INSTALLED"
```

If not installed, clone it:

```bash
git clone https://github.com/sunt23310-ops/openclaw-security-audit.git ~/openclaw-security-audit
```

## Running Checks

Set the audit tool path:

```bash
AUDIT_DIR="$HOME/openclaw-security-audit"
```

### Quick Check (gateway + credentials)

```bash
bash "$AUDIT_DIR/checks/gateway.sh" && bash "$AUDIT_DIR/checks/credentials.sh"
```

### Full Audit

```bash
for check in gateway credentials channels tools network system; do
  bash "$AUDIT_DIR/checks/${check}.sh"
done
```

### Individual Checks

Match what the user is asking about:

| Topic | Command |
|-------|---------|
| Gateway, ports, auth | `bash "$AUDIT_DIR/checks/gateway.sh"` |
| API keys, file permissions | `bash "$AUDIT_DIR/checks/credentials.sh"` |
| WhatsApp, Telegram, DM policy | `bash "$AUDIT_DIR/checks/channels.sh"` |
| Sandbox, tool restrictions | `bash "$AUDIT_DIR/checks/tools.sh"` |
| IP leak, port exposure | `bash "$AUDIT_DIR/checks/network.sh"` |
| macOS SIP, FileVault, TCC | `bash "$AUDIT_DIR/checks/system.sh"` |

### Auto-Fix (requires user confirmation)

```bash
bash "$AUDIT_DIR/fixes/interactive-fix.sh"
```

## Output Interpretation

- `[PASS]` — secure, no action needed
- `[WARN]` — potential issue, recommend review
- `[FAIL]` — security issue, recommend fix
- `[SKIP]` — component not found, check skipped

After running checks, summarize the results clearly. If there are FAIL items, recommend running the appropriate fix script and explain what it will do before the user confirms.
