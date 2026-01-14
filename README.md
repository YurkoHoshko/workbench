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

# Create a new workbench for a feature
workbench create ABC-123

# List all workbenches
workbench list

# Interactive picker (requires fzf)
workbench list -i

# Attach to existing workbench
workbench attach ABC-123

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
| `workbench list` | List all workbenches across all repos |
| `workbench attach [name]` | Attach to session (resurrects if needed) |
| `workbench rm <name>` | Remove workbench |
| `workbench doctor` | Detect and fix inconsistencies |
| `workbench review [branch]` | Create review workbench for a branch |
| `workbench config` | Open repo/global configuration |
| `workbench deps` | Show dependency status |

`workbench list` works globally from any directory and shows workbenches from all initialized repos:
```
● myrepo/feature-1    wb/feature-1
○ myrepo/feature-2    wb/feature-2
● otherrepo/fix-123   wb/fix-123
```

## Shell Completions

Tab completions work automatically for:
- Workbench names (dynamic, based on current repo)
- Layout files (from `~/.config/zellij/layouts/`)
- Agents (`opencode`, `amp`, `claude`, `aider`, `cursor`)

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

Sessions are named `<repo-name>_<worktree-name>` (underscore separator). Environment variables passed to layouts:

- `WORKBENCH_REPO` - repository name
- `WORKBENCH_NAME` - workbench name
- `WORKBENCH_PATH` - absolute worktree path
- `WORKBENCH_BRANCH` - branch name
- `WORKBENCH_BASE_REF` - base ref
- `WORKBENCH_AGENT` - agent name

### Session switching plugin

When attaching from inside Zellij, `workbench` uses the `zellij-switch` plugin and installs it to `~/.config/zellij/plugins/zellij-switch.wasm` if it is missing.
