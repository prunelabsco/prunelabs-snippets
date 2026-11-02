# Claude Code Hook: Auto-format After Every Edit

The hook from my Short *"Claude Code Hooks: The Feature Most Devs Skip"* ([YouTube](https://youtube.com/shorts/b6acJkc16jw) · [Instagram](https://www.instagram.com/reel/De4FRxUkn8v/)).

Telling Claude "always run the linter" doesn't stick. A hook does. This one runs **Laravel Pint** (PHP) or **Prettier** (JS/TS) on a file right after Claude edits it, so formatting just happens.

A prompt is a suggestion. A hook is a rule.

## How it works

1. Claude uses the `Write` or `Edit` tool on a file.
2. Claude Code fires the `PostToolUse` event and pipes a JSON payload to the script on stdin.
3. The script reads `tool_input.file_path` from that JSON and formats the file:
   - `.php` → walks up to the Laravel project root (where `artisan` and `vendor/bin/pint` live) and runs Pint on that one file
   - `.ts` / `.tsx` / `.js` / `.jsx` → runs Prettier (uses your project's Prettier config)
   - anything else → does nothing

It always exits `0`, so a formatter error never blocks Claude.

## Setup

### 1. Save the script

Save this as `~/.claude/hooks/auto-format.sh`:

```bash
#!/bin/bash
# Auto-format file after Claude edits it
# Triggered by PostToolUse on Write|Edit

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    f = ti.get('file_path', ti.get('path', ''))
    print(f)
except:
    print('')
" 2>/dev/null)

[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

if [[ "$FILE" == *.php ]]; then
    # Walk up from file dir to find artisan (Laravel project root)
    DIR=$(dirname "$FILE")
    while [[ "$DIR" != "/" && "$DIR" != "." ]]; do
        if [[ -f "$DIR/artisan" && -f "$DIR/vendor/bin/pint" ]]; then
            "$DIR/vendor/bin/pint" "$FILE" --quiet 2>/dev/null || true
            break
        fi
        DIR=$(dirname "$DIR")
    done
elif [[ "$FILE" =~ \.(tsx|ts|jsx|js)$ ]]; then
    # Prettier — picks up config automatically from nearest package.json
    prettier --write "$FILE" --log-level silent 2>/dev/null || \
    npx --yes prettier --write "$FILE" --log-level silent 2>/dev/null || true
fi

exit 0
```

### 2. Register the hook

Add this to `~/.claude/settings.json` (all projects) or `.claude/settings.json` (one project). If you already have a `hooks` key, merge it in:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/auto-format.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Restart Claude Code

Start a new session, ask Claude to edit a PHP file in a Laravel project, then check `git diff`. The formatting is already done.

## Requirements

- `python3` (used to parse the JSON payload)
- Laravel projects: Pint installed (`composer require laravel/pint --dev`, it ships with new Laravel apps)
- JS/TS projects: Prettier, either installed or available through `npx`

## Notes

- It only fires on Claude's `Write` and `Edit` tools. If Claude changes a file through a Bash command (`sed`, `echo >`), the hook won't run.
- Pint runs on the edited file only, not the whole project, so it stays fast.
- Not using Laravel? Swap the Pint line for your formatter (Black, gofmt, rustfmt, etc.). The structure stays the same.

Official docs on hooks: https://docs.claude.com/en/docs/claude-code/hooks
