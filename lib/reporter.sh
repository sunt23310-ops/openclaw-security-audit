#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Report Generator
# =============================================================================
# Generates HTML and JSON audit reports organized by MITRE ATLAS categories
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPORT_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HISTORY_DIR="$(get_project_root)/history"

# Collect results as structured data
declare -a REPORT_ENTRIES

add_report_entry() {
    local category="$1"    # MITRE ATLAS category
    local check_name="$2"
    local status="$3"      # pass|warn|fail|skip
    local detail="$4"
    REPORT_ENTRIES+=("${category}|${check_name}|${status}|${detail}")
}

# =============================================================================
# JSON Report
# =============================================================================

generate_json_report() {
    local output_file="${1:-$HISTORY_DIR/audit_${REPORT_TIMESTAMP}.json}"
    mkdir -p "$(dirname "$output_file")"

    python3 - "$output_file" "${REPORT_ENTRIES[@]}" <<'PYEOF'
import json, sys, datetime

output_file = sys.argv[1]
entries = sys.argv[2:]

results = []
for entry in entries:
    parts = entry.split('|', 3)
    if len(parts) == 4:
        results.append({
            "category": parts[0],
            "check": parts[1],
            "status": parts[2],
            "detail": parts[3]
        })

# Group by category
categories = {}
for r in results:
    cat = r["category"]
    if cat not in categories:
        categories[cat] = []
    categories[cat].append({
        "check": r["check"],
        "status": r["status"],
        "detail": r["detail"]
    })

stats = {
    "pass": sum(1 for r in results if r["status"] == "pass"),
    "warn": sum(1 for r in results if r["status"] == "warn"),
    "fail": sum(1 for r in results if r["status"] == "fail"),
    "skip": sum(1 for r in results if r["status"] == "skip"),
}

report = {
    "tool": "openclaw-security-audit",
    "version": "1.0.0",
    "timestamp": datetime.datetime.now().isoformat(),
    "summary": stats,
    "categories": categories
}

with open(output_file, 'w') as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(output_file)
PYEOF
}

# =============================================================================
# HTML Report
# =============================================================================

generate_html_report() {
    local output_file="${1:-$HISTORY_DIR/audit_${REPORT_TIMESTAMP}.html}"
    mkdir -p "$(dirname "$output_file")"

    python3 - "$output_file" "${REPORT_ENTRIES[@]}" <<'PYEOF'
import sys, datetime

output_file = sys.argv[1]
entries = sys.argv[2:]

results = []
for entry in entries:
    parts = entry.split('|', 3)
    if len(parts) == 4:
        results.append({
            "category": parts[0],
            "check": parts[1],
            "status": parts[2],
            "detail": parts[3]
        })

stats = {
    "pass": sum(1 for r in results if r["status"] == "pass"),
    "warn": sum(1 for r in results if r["status"] == "warn"),
    "fail": sum(1 for r in results if r["status"] == "fail"),
    "skip": sum(1 for r in results if r["status"] == "skip"),
}

status_colors = {
    "pass": "#22c55e",
    "warn": "#eab308",
    "fail": "#ef4444",
    "skip": "#3b82f6"
}

status_icons = {
    "pass": "&#10004;",
    "warn": "&#9888;",
    "fail": "&#10008;",
    "skip": "&#8594;"
}

# Group by category
categories = {}
cat_order = []
for r in results:
    cat = r["category"]
    if cat not in categories:
        categories[cat] = []
        cat_order.append(cat)
    categories[cat].append(r)

timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>OpenClaw Security Audit Report - {timestamp}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0f172a; color: #e2e8f0; padding: 2rem; }}
  .container {{ max-width: 900px; margin: 0 auto; }}
  h1 {{ color: #38bdf8; margin-bottom: 0.5rem; font-size: 1.8rem; }}
  .subtitle {{ color: #94a3b8; margin-bottom: 2rem; }}
  .summary {{ display: flex; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }}
  .stat {{ background: #1e293b; padding: 1rem 1.5rem; border-radius: 8px; text-align: center; flex: 1; min-width: 100px; }}
  .stat .num {{ font-size: 2rem; font-weight: bold; }}
  .stat .label {{ font-size: 0.85rem; color: #94a3b8; margin-top: 0.25rem; }}
  .category {{ background: #1e293b; border-radius: 8px; margin-bottom: 1rem; overflow: hidden; }}
  .category-header {{ padding: 1rem 1.5rem; font-weight: 600; font-size: 1.1rem;
                      background: #1e3a5f; border-left: 4px solid #38bdf8; }}
  .check {{ display: flex; align-items: center; padding: 0.75rem 1.5rem;
            border-bottom: 1px solid #334155; gap: 0.75rem; }}
  .check:last-child {{ border-bottom: none; }}
  .badge {{ display: inline-block; width: 24px; height: 24px; border-radius: 50%;
            text-align: center; line-height: 24px; font-size: 0.75rem; flex-shrink: 0; }}
  .check-name {{ font-weight: 500; min-width: 200px; }}
  .check-detail {{ color: #94a3b8; font-size: 0.9rem; }}
  footer {{ text-align: center; margin-top: 2rem; color: #475569; font-size: 0.85rem; }}
</style>
</head>
<body>
<div class="container">
<h1>OpenClaw Security Audit Report</h1>
<p class="subtitle">Generated: {timestamp}</p>
<div class="summary">
  <div class="stat"><div class="num" style="color:{status_colors['pass']}">{stats['pass']}</div><div class="label">Passed</div></div>
  <div class="stat"><div class="num" style="color:{status_colors['warn']}">{stats['warn']}</div><div class="label">Warnings</div></div>
  <div class="stat"><div class="num" style="color:{status_colors['fail']}">{stats['fail']}</div><div class="label">Failed</div></div>
  <div class="stat"><div class="num" style="color:{status_colors['skip']}">{stats['skip']}</div><div class="label">Skipped</div></div>
</div>
"""

for cat in cat_order:
    html += f'<div class="category"><div class="category-header">{cat}</div>\\n'
    for r in categories[cat]:
        color = status_colors[r["status"]]
        icon = status_icons[r["status"]]
        html += f'<div class="check">'
        html += f'<span class="badge" style="background:{color};color:#fff">{icon}</span>'
        html += f'<span class="check-name">{r["check"]}</span>'
        html += f'<span class="check-detail">{r["detail"]}</span>'
        html += f'</div>\\n'
    html += '</div>\\n'

html += """
<footer>
  <p>Generated by openclaw-security-audit v1.0.0</p>
</footer>
</div>
</body>
</html>"""

with open(output_file, 'w') as f:
    f.write(html)

print(output_file)
PYEOF
}
