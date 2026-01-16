# workbench

A nushell CLI that manages multiple concurrent feature workspaces using Git worktrees and Zellij sessions.

## Installation

Add to your nushell config:

```nu
use /path/to/workbench/mod.nu *
```

## Requirements

- **Required**: `git`, `zellij`
- **Optional**: `fzf` (interactive mode), `task` (taskwarrior)

Check dependencies:
```nu
workbench deps
```

## Quick Start

```nu
# Initialize workbench for current repo (run from git repo root)
workbench init

# Create a new workbench (branch name is the identifier)
workbench create feature/ABC-123

# List all workbenches
workbench list

# Interactive picker (requires fzf)
workbench list -i

# Attach to existing workbench by branch
workbench attach feature/ABC-123

# Interactive session picker loop (recommended)
workbench shell

# Remove workbench
workbench rm feature/ABC-123

# Check for issues
workbench doctor
workbench doctor --fix
```

## Commands

| Command | Description |
|---------|-------------|
| `workbench init` | Initialize workbench for current git repo |
| `workbench create <branch>` | Create new worktree + zellij session |
| `workbench list` | List all workbenches across all repos |
| `workbench attach [branch]` | Attach to session (resurrects if needed) |
| `workbench rm <branch>` | Remove workbench |
| `workbench shell` | Interactive session picker loop |
| `workbench doctor` | Detect and fix inconsistencies |
| `workbench config` | Open repo/global configuration |
| `workbench deps` | Show dependency status |

## Naming

**Branch name is the primary identifier** for everything:
- Session name: branch with `/` → `_` (e.g., `feature/ABC-123` → `feature_ABC-123`)
- Folder name: same transformation

This simplifies the mental model - you always refer to workbenches by their branch name.

## Shell Completions

Tab completions work automatically for:
- Branch names (existing workbenches for attach/rm)
- Layout files (from `~/.config/zellij/layouts/`)
- Agents (`opencode`, `amp`, `claude`, `aider`, `cursor`)

## Configuration

### Global config: `~/.config/workbench/config.json`

```json
{
  "workbench_root": "~/.workbench",
  "agent": "opencode",
  "layout": "default.kdl"
}
```

### Repo config: `~/.workbench/<repo>/.workbench/config.json`

```json
{
  "repo_root": "/abs/path/to/repo",
  "base_ref": "origin/main",
  "agent": "opencode",
  "layout": "phoenix.kdl"
}
```

## Folder Structure

```
~/.workbench/
  <repo-name>/
    .workbench/
      config.json
    main/                     # canonical base worktree
    feature_ABC-123/          # branch feature/ABC-123 → folder feature_ABC-123
```

## Zellij Integration

Sessions are named using the sanitized branch name (slashes → underscores). Environment variables passed to layouts:

- `WORKBENCH_REPO` - repository name
- `WORKBENCH_NAME` - folder name (sanitized branch)
- `WORKBENCH_PATH` - absolute worktree path
- `WORKBENCH_BRANCH` - original branch name
- `WORKBENCH_BASE_REF` - base ref
- `WORKBENCH_AGENT` - agent name

### Recommended workflow: `workbench shell`

The preferred way to work with multiple sessions:

```nu
workbench shell
```

This runs an interactive fzf picker in a loop:
1. Select a session with Enter → attaches to it
2. Detach from zellij (Ctrl+O d) → returns to picker
3. Press Esc → exits the shell

Sessions are sorted by **most recently used** first, so you can quickly switch between recent workbenches with just detach + Enter.

MRU state is stored in `~/.local/state/workbench/mru.txt`.

### Session switching plugin

`workbench init` installs the `zellij-switch` plugin to `~/.config/zellij/plugins/zellij-switch.wasm` for session switching from inside Zellij (alternative to the shell workflow).
