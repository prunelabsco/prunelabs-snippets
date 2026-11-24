# Claude Code Hook: Block Edits to .env Files

The follow-up hook I promised at the end of my Short *"Claude Code Hooks: The Feature Most Devs Skip"* ([YouTube](https://youtube.com/shorts/b6acJkc16jw) · [Instagram](https://www.instagram.com/reel/De4FRxUkn8v/)).

A rule in your prompt says "please don't touch .env". This hook makes it impossible: Claude's edit is cancelled before it happens.

## How it works

1. Claude is about to use `Write`, `Edit` or `MultiEdit` on a file.
2. Claude Code fires the `PreToolUse` event (before the tool runs) and pipes a JSON payload to the script on stdin.
3. The script reads `tool_input.file_path` and checks the file name:
   - `.env`, `.env.local`, `.env.production`, any `.env.*` → **blocked** (exit code `2`)
   - `.env.example` / `.env.sample` → allowed, these hold no secrets
   - anything else → allowed

On exit code `2`, Claude Code cancels the tool call and shows the script's message to Claude, so it tells you which variable to change instead of editing the file itself.

## Setup

### 1. Save the script

Save this as `~/.claude/hooks/env-guard.sh` (or grab [env-guard.sh](env-guard.sh) from this folder):

```bash
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
```

### 2. Register the hook

Add this to `~/.claude/settings.json` (all projects) or `.claude/settings.json` (one project). If you already have a `hooks` key (for example the [auto-format](../auto-format/) hook), add `PreToolUse` next to it:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/env-guard.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Restart Claude Code

Start a new session and ask Claude to add a variable to your `.env`. It should get blocked and tell you what to add yourself.

## Test it without Claude

Pipe a fake payload into the script and check the exit code:

```bash
echo '{"tool_input":{"file_path":"/app/.env"}}' | bash ~/.claude/hooks/env-guard.sh; echo "exit=$?"
# Blocked: .env is off-limits. ...
# exit=2

echo '{"tool_input":{"file_path":"/app/.env.example"}}' | bash ~/.claude/hooks/env-guard.sh; echo "exit=$?"
# exit=0
```

What I tested this way: `.env`, `.env.local`, `.env.production` blocked; `.env.example`, `.env.sample`, `config/app.php`, `environment.ts`, an empty path and invalid JSON all pass through.

## Notes

- It only guards Claude's `Write`, `Edit` and `MultiEdit` tools. A Bash command like `echo "KEY=x" >> .env` is not caught.
- It does not stop Claude from *reading* `.env`. To also keep secrets out of the conversation, add `Read` to the matcher (Claude then can't see your variable names either).
- Requires `python3` (used to parse the JSON payload).

Official docs on hooks: https://docs.claude.com/en/docs/claude-code/hooks
