"""JSON5 parser for OpenClaw config files.

Handles comments (// and /* */), trailing commas, and unquoted keys.
Uses a state-machine approach that correctly handles strings containing
comment-like sequences (e.g., URLs with //).
"""

import json
import sys


def parse_json5(text):
    """Parse JSON5 text into a Python object."""
    result = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        # String literals - pass through unchanged
        if c in ('"', "'"):
            quote = c
            result.append('"')  # normalize to double quotes
            i += 1
            while i < n:
                sc = text[i]
                if sc == '\\' and i + 1 < n:
                    result.append(sc)
                    i += 1
                    result.append(text[i])
                elif sc == quote:
                    break
                else:
                    result.append(sc)
                i += 1
            result.append('"')
            i += 1
            continue
        # Line comment
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            i += 2
            while i < n and text[i] != '\n':
                i += 1
            continue
        # Block comment
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
            continue
        # Trailing comma before } or ]
        if c == ',':
            j = i + 1
            while j < n and text[j] in ' \t\r\n':
                j += 1
            if j < n and text[j] in ('}', ']'):
                i += 1
                continue
        # Unquoted keys: wrap in double quotes
        if c.isalpha() or c == '_' or c == '$':
            k = len(result) - 1
            while k >= 0 and result[k] in (' ', '\t', '\r', '\n'):
                k -= 1
            if k >= 0 and result[k] in ('{', ','):
                word = []
                while i < n and (text[i].isalnum() or text[i] in ('_', '$')):
                    word.append(text[i])
                    i += 1
                result.append('"')
                result.extend(word)
                result.append('"')
                continue
        result.append(c)
        i += 1
    return json.loads(''.join(result))


def load_config(path):
    """Load an OpenClaw config file, handling both JSON and JSON5."""
    with open(path, 'r') as f:
        raw = f.read()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return parse_json5(raw)


def get_value(cfg, key_path):
    """Get a nested value using dot notation."""
    keys = key_path.split('.')
    val = cfg
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            return None
    return val


if __name__ == '__main__':
    # CLI usage: python3 json5_parser.py <config_path> <key_path>
    if len(sys.argv) < 3:
        print("Usage: python3 json5_parser.py <config_path> <key_path>", file=sys.stderr)
        sys.exit(1)

    try:
        cfg = load_config(sys.argv[1])
        val = get_value(cfg, sys.argv[2])
        if val is not None:
            if isinstance(val, (dict, list)):
                print(json.dumps(val))
            else:
                print(val)
    except Exception:
        pass
