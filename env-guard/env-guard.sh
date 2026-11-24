#!/bin/bash
# Block Claude from editing .env files
# Triggered by PreToolUse on Write|Edit|MultiEdit

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path', ti.get('path', '')))
except:
    print('')
" 2>/dev/null)

NAME=$(basename "$FILE")

case "$NAME" in
    .env.example|.env.sample) exit 0 ;;
    .env|.env.*)
        echo "Blocked: $NAME is off-limits. Tell the user which variable to change instead of editing it." >&2
        exit 2 ;;
esac

exit 0
