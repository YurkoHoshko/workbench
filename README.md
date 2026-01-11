# workbench

A nushell CLI that manages multiple concurrent feature workspaces using Git worktrees and Zellij sessions.

## Installation

Add to your nushell config:

```nu
use /path/to/workbench/mod.nu *
```

## Requirements

- **Required**: `git`, `zellij`
- **Optional**: `fzf` (interactive mode), `mise` (runtime management), `task` (taskwarrior)

Check dependencies:
```nu
workbench deps
```

## Quick Start

```nu
# Initialize workbench for current repo (run from git repo root)
workbench init

# Create a new workbench for a feature
workbench create ABC-123

# List all workbenches
workbench list

# Interactive picker (requires fzf)
workbench list -i

# Attach to existing workbench
workbench attach ABC-123

# View workbench report
workbench report --name ABC-123

# Open dashboard
workbench dashboard

# Remove workbench
workbench rm ABC-123

# Check for issues
workbench doctor
workbench doctor --fix
```

## Commands

| Command | Description |
|---------|-------------|
| `workbench init` | Initialize workbench for current git repo |
| `workbench create <name>` | Create new worktree + zellij session |
| `workbench list` | List workbenches with session status |
| `workbench attach [name]` | Attach to session (resurrects if needed) |
| `workbench rm <name>` | Remove workbench |
| `workbench report` | Generate workbench report |
| `workbench dashboard` | Start/attach dashboard session |
| `workbench doctor` | Detect and fix inconsistencies |
| `workbench deps` | Show dependency status |

## Configuration

### Global config: `~/.config/workbench/config.json`

```json
{
  "workbench_root": "~/.workbench",
  "agent": "opencode",
  "layouts_dir": "~/.config/zellij/layouts",
  "layout": "default.kdl"
}
```

### Repo config: `~/.workbench/<repo>/.workbench/config.json`

```json
{
  "repo_root": "/abs/path/to/repo",
  "base_ref": "origin/main",
  "agent": "opencode",
  "layout": "phoenix.kdl",
  "dashboard_layout": "dashboard.kdl",
  "branch_prefix": "wb/"
}
```

## Folder Structure

```
~/.workbench/
  <repo-name>/
    .workbench/
      config.json
    main/                 # canonical base worktree
    <worktree-name>/      # feature worktrees
```

## Zellij Integration

Sessions are named `<repo-name>/<worktree-name>`. Environment variables passed to layouts:

- `WORKBENCH_REPO` - repository name
- `WORKBENCH_NAME` - workbench name
- `WORKBENCH_PATH` - absolute worktree path
- `WORKBENCH_BRANCH` - branch name
- `WORKBENCH_BASE_REF` - base ref
- `WORKBENCH_AGENT` - agent name
