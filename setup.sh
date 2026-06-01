#!/usr/bin/env bash
# claude-setup.sh — Bootstrap Jimmy's Claude Code environment on a new machine
# Run with: bash claude-setup.sh
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${YELLOW}→${NC} $*"; }
warn() { echo -e "${RED}!${NC} $*"; }

echo ""
echo "=================================="
echo "  Claude Code Environment Setup"
echo "=================================="
echo ""

# ── 1. Node / npm check ────────────────────────────────────────────────────────
info "Checking Node.js..."
if ! command -v node &>/dev/null; then
  warn "Node.js not found. Installing via nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
else
  ok "Node.js $(node --version) found"
fi

# ── 2. Claude Code CLI ─────────────────────────────────────────────────────────
info "Checking Claude Code CLI..."
if ! command -v claude &>/dev/null; then
  info "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'installed')"
else
  ok "Claude Code already installed: $(claude --version 2>/dev/null)"
fi

# ── 3. Python deps (for obsidian-logger.py) ────────────────────────────────────
info "Checking Python + anthropic SDK..."
if command -v pip3 &>/dev/null; then
  pip3 install --quiet anthropic
  ok "anthropic SDK ready"
elif command -v pip &>/dev/null; then
  pip install --quiet anthropic
  ok "anthropic SDK ready"
else
  warn "pip not found — install Python 3 and run: pip install anthropic"
fi

# ── 4. Directory structure ─────────────────────────────────────────────────────
info "Creating ~/.claude directory structure..."
mkdir -p \
  ~/.claude/agents \
  ~/.claude/commands/sc \
  ~/.claude/plugins/marketplaces \
  ~/.claude/projects \
  ~/.claude/sessions \
  ~/Documents/Notes/Notes
ok "Directories created"

# ── 5. Superpowers marketplace (private repo — needs SSH key) ──────────────────
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/obra-superpowers-marketplace"
if [ -d "$MARKETPLACE_DIR/.git" ]; then
  info "Superpowers marketplace exists — pulling latest..."
  git -C "$MARKETPLACE_DIR" pull --quiet
  ok "Superpowers marketplace updated"
else
  info "Cloning superpowers marketplace from YOUR_GITHUB_USERNAME/claude-config..."
  if git clone git@github.com:YOUR_GITHUB_USERNAME/claude-config.git "$MARKETPLACE_DIR" 2>/dev/null; then
    ok "Superpowers marketplace cloned"
  else
    warn "Could not clone git@github.com:YOUR_GITHUB_USERNAME/claude-config.git"
    warn "Make sure your SSH key is set up on this machine, then re-run."
    warn "Skipping — plugins that depend on superpowers won't work until this is cloned."
    mkdir -p "$MARKETPLACE_DIR"
  fi
fi

# ── 6. CLAUDE.md (global instructions) ────────────────────────────────────────
info "Writing ~/.claude/CLAUDE.md..."
cat > ~/.claude/CLAUDE.md << 'CLAUDEMD'
# Problem Solving & Memory Policy

When you run into any error or unexpected behavior:

1. STOP — do not guess or try random fixes
2. Investigate the root cause first — read logs, trace the error, understand WHY it's failing
3. Form a hypothesis before making any changes
4. Fix only what is causing the issue — do not refactor unrelated code
5. Verify the fix worked before moving on
6. Document what the issue was and how you solved it using your memory tools

## Memory Rules
- After solving any problem, always save a memory of:
  - What the error/issue was
  - What caused it
  - What fixed it
- Before attempting to fix any issue, always search your memory first in case you've seen something similar before

## What NOT to do
- Never blindly retry the same command hoping it works
- Never make multiple changes at once when debugging
- Never mark something as fixed without verifying it
- Never skip the root cause investigation step
CLAUDEMD
ok "CLAUDE.md written"

# ── 7. settings.json ───────────────────────────────────────────────────────────
info "Writing ~/.claude/settings.json..."
# NOTE: Sensitive env vars (N8N_API_KEY, ANTHROPIC_API_KEY) are NOT written here.
# Add them manually or export them in your shell profile.
cat > ~/.claude/settings.json << 'SETTINGS'
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "8000",
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-haiku-4-5-20251001",
    "N8N_BASE_URL": "YOUR_N8N_BASE_URL"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/update-sub-agents.sh",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/obsidian-logger.py",
            "timeout": 60,
            "statusMessage": "Logging session to Obsidian..."
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true,
    "remember@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "pyright-lsp@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "serena@claude-plugins-official": true,
    "github@claude-plugins-official": true
  },
  "extraKnownMarketplaces": {
    "superpowers-marketplace": {
      "source": {
        "source": "directory",
        "path": "/home/jimmy/.claude/plugins/marketplaces/obra-superpowers-marketplace"
      }
    },
    "claude-plugins-official": {
      "source": {
        "source": "github",
        "repo": "anthropics/claude-plugins-official"
      }
    }
  }
}
SETTINGS
ok "settings.json written"

# ── 8. obsidian-logger.py ──────────────────────────────────────────────────────
info "Writing ~/.claude/obsidian-logger.py..."
cat > ~/.claude/obsidian-logger.py << 'PYEOF'
#!/usr/bin/env python3
"""
obsidian-logger.py — Claude Code Stop hook
Reads the session transcript, extracts notable ideas/project updates/learnings via Haiku,
and appends them to the Obsidian vault at ~/Documents/Notes/Notes/
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
import anthropic

VAULT = Path.home() / "Documents/Notes/Notes"
IDEAS_FILE = VAULT / "Ideas.md"
PROJECTS_LOG = VAULT / "Project Updates Log.md"
LEARNINGS_FILE = VAULT / "Learnings.md"
PROJECTS_DIR = Path.home() / ".claude/projects"


def find_transcript(session_id: str) -> Path | None:
    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        candidate = project_dir / f"{session_id}.jsonl"
        if candidate.exists():
            return candidate
    return None


def read_transcript(path: Path) -> str:
    messages = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("type") not in ("user", "assistant"):
                continue

            msg = entry.get("message", {})
            role = msg.get("role", entry.get("type", "?"))
            content = msg.get("content", "")

            if isinstance(content, list):
                text = " ".join(
                    part.get("text", "")
                    for part in content
                    if isinstance(part, dict) and part.get("type") == "text"
                )
            elif isinstance(content, str):
                text = content
            else:
                continue

            text = text.strip()
            if text:
                messages.append(f"{role.upper()}: {text[:600]}")

    return "\n\n".join(messages[:60])


def extract_items(transcript: str) -> dict:
    client = anthropic.Anthropic()

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[
            {
                "role": "user",
                "content": f"""Review this Claude Code conversation and extract anything worth logging to a personal knowledge base.

Log ONLY genuinely notable items in these categories:
- IDEAS: novel concepts, project angles, automation ideas the user discussed or came up with
- PROJECT_UPDATES: decisions made, status changes, next steps defined for specific named projects
- LEARNINGS: technical things learned, tools explored, patterns or insights discovered

Rules:
- If the conversation was routine coding help with nothing notable, return empty lists
- Be selective — only log things that would still be valuable to read in 3 months
- Keep descriptions concise (1-2 sentences max)

Return ONLY valid JSON, nothing else:
{{
  "ideas": [{{"topic": "short title", "content": "1-2 sentence description"}}],
  "project_updates": [{{"project": "project name", "update": "what was decided or learned"}}],
  "learnings": [{{"topic": "topic", "content": "what was learned"}}]
}}

TRANSCRIPT:
{transcript[:3500]}""",
            }
        ],
    )

    output = message.content[0].text.strip()
    start = output.find("{")
    end = output.rfind("}") + 1
    if start < 0 or end <= start:
        return {}

    try:
        return json.loads(output[start:end])
    except json.JSONDecodeError:
        return {}


def append_to(file: Path, header: str, entry_lines: list) -> None:
    needs_header = not file.exists() or file.stat().st_size == 0
    with open(file, "a") as f:
        if needs_header:
            f.write(header)
        f.write("\n".join(entry_lines) + "\n")


def main():
    try:
        hook_input = json.loads(sys.stdin.read())
        session_id = hook_input.get("session_id", "")
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if not session_id:
        sys.exit(0)

    transcript_path = find_transcript(session_id)
    if not transcript_path:
        sys.exit(0)

    transcript = read_transcript(transcript_path)
    if len(transcript) < 150:
        sys.exit(0)

    items = extract_items(transcript)
    if not items:
        sys.exit(0)

    date = datetime.now().strftime("%Y-%m-%d")
    logged = []

    ideas = items.get("ideas", [])
    if ideas:
        lines = []
        for idea in ideas:
            lines += ["\n---", f"**{date}**", f"**Topic:** {idea['topic']}", idea["content"], ""]
        append_to(IDEAS_FILE, "# Ideas\n\n", lines)
        logged.append(f"{len(ideas)} idea(s)")

    updates = items.get("project_updates", [])
    if updates:
        lines = ["\n---", f"**{date}**"]
        for u in updates:
            lines.append(f"- **{u['project']}:** {u['update']}")
        lines.append("")
        append_to(
            PROJECTS_LOG,
            "# Project Updates Log\n\nAuto-logged from Claude Code sessions.\n",
            lines,
        )
        logged.append(f"{len(updates)} project update(s)")

    learnings = items.get("learnings", [])
    if learnings:
        lines = ["\n---", f"**{date}**"]
        for lrn in learnings:
            lines.append(f"- **{lrn['topic']}:** {lrn['content']}")
        lines.append("")
        append_to(
            LEARNINGS_FILE,
            "# Learnings\n\nAuto-logged from Claude Code sessions.\n",
            lines,
        )
        logged.append(f"{len(learnings)} learning(s)")

    if logged:
        print(json.dumps({"systemMessage": f"Obsidian logged: {', '.join(logged)}"}))


if __name__ == "__main__":
    main()
PYEOF
chmod +x ~/.claude/obsidian-logger.py
ok "obsidian-logger.py written"

# ── 9. update-sub-agents.sh ────────────────────────────────────────────────────
info "Writing ~/.claude/update-sub-agents.sh..."
cat > ~/.claude/update-sub-agents.sh << 'SHEOF'
#!/bin/bash
# Regenerates ~/Documents/Notes/Notes/Sub Agents.md from ~/.claude/agents/

AGENTS_DIR="$HOME/.claude/agents"
OUTPUT="$HOME/Documents/Notes/Notes/Sub Agents.md"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [[ "$FILE_PATH" != "$AGENTS_DIR"* ]]; then
  exit 0
fi

{
cat <<'HEADER'
# Sub Agents

All Claude Code sub-agents. Invoke with `@agent-name` in Claude Code.

Agent files live in `~/.claude/agents/`

---
HEADER

declare -A names descs

while IFS= read -r file; do
  name=$(grep -m1 "^name:" "$file" | sed 's/name: *//' | xargs)
  desc=$(grep -m1 "^description:" "$file" | sed 's/description: *//' | cut -c1-100 | xargs)
  [ -z "$name" ] && continue
  names["$name"]="$name"
  descs["$name"]="$desc"
done < <(find "$AGENTS_DIR" -name "*.md" | sort)

row() { echo "| \`@$1\` | ${descs[$1]:-} |"; }
header() { echo -e "\n## $1\n\n| Agent | Description |\n|-------|-------------|"; }

header "Orchestrators"
for n in pe biz-dev; do [ "${names[$n]+x}" ] && row "$n"; done

header "Writers & Content"
for n in humanwriter; do [ "${names[$n]+x}" ] && row "$n"; done

header "Engineering"
for n in architect python-expert performance-engineer security-engineer code-quality; do
  [ "${names[$n]+x}" ] && row "$n"
done

header "Research & Analysis"
for n in researcher root-cause-analyst requirements-analyst repo-index; do
  [ "${names[$n]+x}" ] && row "$n"
done

header "Documentation & Learning"
for n in technical-writer learning-guide; do [ "${names[$n]+x}" ] && row "$n"; done

header "Workflow & PM"
for n in pm-agent; do [ "${names[$n]+x}" ] && row "$n"; done

echo -e "\n## PE Pipeline (sub-agents of \`@pe\`)\n\n| Agent | Role |\n|-------|------|"
for n in pe-analyst pe-researcher pe-architect pe-checker; do
  [ "${names[$n]+x}" ] && echo "| \`@$n\` | ${descs[$n]:-} |"
done

echo -e "\n## Biz-Dev Pipeline (sub-agents of \`@biz-dev\`)\n\n| Agent | Role |\n|-------|------|"
for n in biz-dev-trend-researcher biz-dev-prospect-finder biz-dev-pitch-builder; do
  [ "${names[$n]+x}" ] && echo "| \`@$n\` | ${descs[$n]:-} |"
done

header "Business"
for n in business-panel-experts; do [ "${names[$n]+x}" ] && row "$n"; done

known="pe biz-dev humanwriter architect python-expert performance-engineer security-engineer code-quality researcher root-cause-analyst requirements-analyst repo-index technical-writer learning-guide pm-agent pe-analyst pe-researcher pe-architect pe-checker biz-dev-trend-researcher biz-dev-prospect-finder biz-dev-pitch-builder business-panel-experts"
others=()
for n in "${!names[@]}"; do
  [[ " $known " != *" $n "* ]] && others+=("$n")
done
if [ ${#others[@]} -gt 0 ]; then
  header "Other"
  for n in $(echo "${others[@]}" | tr ' ' '\n' | sort); do
    row "$n"
  done
fi

} > "$OUTPUT"
SHEOF
chmod +x ~/.claude/update-sub-agents.sh
ok "update-sub-agents.sh written"

# ── 10. Custom commands ────────────────────────────────────────────────────────
info "Writing ~/.claude/commands/log-idea.md..."
cat > ~/.claude/commands/log-idea.md << 'CMDEOF'
Log an idea or topic from this conversation to Obsidian.

The vault is at ~/Documents/Notes/Notes/

1. Look at the current conversation context for the idea or topic the user wants to log. If the user provided a description after the command, use that. Otherwise, summarize what we just discussed.

2. Determine the right file:
   - A project idea or feature → append to ~/Documents/Notes/Notes/Ideas.md
   - A topic or thing learned → append to ~/Documents/Notes/Notes/Learning Log.md
   - If unsure, default to Ideas.md

3. Append an entry in this format (do not overwrite existing content):

---
**[Today's date]**
**Topic:** <one-line summary>
<2-4 sentences capturing the idea, what it is, why it's interesting or useful>

4. If the destination file doesn't exist yet, create it with a simple heading first:
   - Ideas.md: `# Ideas`
   - Learning Log.md: `# Learning Log`

5. Tell the user what was logged and to which file.
CMDEOF
ok "log-idea.md written"

# ── 11. Obsidian AppImage ──────────────────────────────────────────────────────
info "Checking for Obsidian..."
OBSIDIAN_VERSION="1.8.10"
OBSIDIAN_APPIMAGE="$HOME/Applications/Obsidian-${OBSIDIAN_VERSION}.AppImage"
mkdir -p ~/Applications

if ls ~/Applications/Obsidian*.AppImage &>/dev/null || ls ~/Downloads/Obsidian*.AppImage &>/dev/null; then
  ok "Obsidian AppImage already present — skipping download"
else
  info "Downloading Obsidian ${OBSIDIAN_VERSION} AppImage..."
  curl -L --progress-bar \
    "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" \
    -o "$OBSIDIAN_APPIMAGE"
  chmod +x "$OBSIDIAN_APPIMAGE"
  ok "Obsidian downloaded to ~/Applications/"
fi

# ── 12. Final checklist ────────────────────────────────────────────────────────
echo ""
echo "=================================="
echo "  Setup Complete"
echo "=================================="
echo ""
ok "CLAUDE.md — global instructions"
ok "settings.json — model, hooks, plugins list"
ok "obsidian-logger.py — session → Obsidian logging"
ok "update-sub-agents.sh — agent index hook"
ok "commands/log-idea.md — /log-idea command"
ok "Obsidian — AppImage present"
echo ""
echo -e "${YELLOW}Manual steps still required:${NC}"
echo ""
echo "  1. Add your ANTHROPIC_API_KEY to ~/.claude/settings.json (env section)"
echo "     or export it in ~/.bashrc / ~/.zshrc:"
echo "     export ANTHROPIC_API_KEY=sk-ant-..."
echo ""
echo "  2. Add your N8N_API_KEY to ~/.claude/settings.json (env section)"
echo ""
echo "  3. If SSH key isn't set up yet, clone the superpowers marketplace manually:"
echo "     git clone git@github.com:YOUR_GITHUB_USERNAME/claude-config.git \\"
echo "       ~/.claude/plugins/marketplaces/obra-superpowers-marketplace"
echo ""
echo "  4. Open Claude Code (VS Code extension or 'claude' CLI) — it will"
echo "     auto-install all listed plugins on first launch."
echo ""
echo "  5. Move/copy your Obsidian vault to ~/Documents/Notes/"
echo "     (or update the VAULT path in obsidian-logger.py)"
echo ""
