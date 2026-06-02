# Claude Code Setup

Bootstrap script to replicate a full Claude Code environment on a new machine.

## What it installs

| | |
|--|--|
| Node.js | via nvm if missing |
| Claude Code CLI | `@anthropic-ai/claude-code` |
| Python `anthropic` SDK | for session logging hook |
| `~/.claude/CLAUDE.md` | global problem-solving instructions |
| `~/.claude/settings.json` | model, hooks, plugin list |
| `obsidian-logger.py` | Stop hook — logs sessions to Obsidian |
| `update-sub-agents.sh` | PostToolUse hook — keeps agent index in sync |
| `/log-idea` command | log ideas/learnings to Obsidian from any session |
| Obsidian AppImage | downloaded to `~/Applications/` |
| Superpowers marketplace | cloned from your private `claude-config` repo |
| `agents/` | 23 subagents — `@pe`, `@humanwriter`, `@architect`, `@researcher`, and more |

## Plugins installed on first Claude Code launch

- `superpowers` — skills, brainstorming, TDD, plans, prompt engineer (`@pe`)
- `remember` — persistent memory across sessions
- `feature-dev` — feature development workflow agents
- `code-review` — PR code review
- `pr-review-toolkit` — multi-angle PR review suite
- `commit-commands` — git commit/push/PR shortcuts
- `security-guidance` — security review skill
- `typescript-lsp` / `pyright-lsp` — language servers
- `context7` — live library docs fetching
- `serena` — code intelligence
- `github` — GitHub integration

## Usage

```bash
bash setup.sh
```

## Before running

Edit two placeholders in `setup.sh`:

1. `YOUR_GITHUB_USERNAME` — your GitHub username (for the superpowers marketplace clone)
2. `YOUR_N8N_BASE_URL` — your n8n instance URL (e.g. `https://n8n.yourdomain.dev`)

## After running — manual steps

1. Add your `ANTHROPIC_API_KEY` to `~/.claude/settings.json` or your shell profile:
   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...
   ```
2. Add your `N8N_API_KEY` to `~/.claude/settings.json`
3. Set up your SSH key if the marketplace clone failed, then re-run
4. Open Claude Code once — plugins auto-install on first launch
5. Point Obsidian at `~/Documents/Notes/` or update the `VAULT` path in `obsidian-logger.py`
