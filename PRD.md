# PRD: `workbench` — Zellij + Git Worktree Workbench Manager (Minimal State)

## 0. Summary

`workbench` is a CLI that manages multiple concurrent feature workspaces for a git repo using:

* **Git worktrees**: one per feature / ticket
* **Zellij session per worktree**: UI + process lifecycle
* **Repo-level Zellij layout**: defines panes (server, agent, editor, etc.)

Core philosophy:

* **Git is the source of truth** (worktree list + branches)
* **Zellij indicates whether a workbench is alive**
* Minimal additional state:

  * global config
  * repo config
  * nothing per workbench beyond the worktree itself

---

## 1. Goals & Non-goals

### Goals

1. Zero branch-switching; parallel feature work using worktrees.
2. One command to create a workbench and drop into its Zellij session.
3. FZF-powered navigation across workbenches with attach/delete.
4. Session resurrection and consistency checks (`doctor`).
5. Dashboard + report for visibility, driven by git state.

### Non-goals (v0.1)

* Port management (assumed single active server convention handled by layout commands)
* Process supervision (Zellij owns processes)
* CI / PR integration
* Dependency caching automation

---

## 2. Folder Layout & Config

### 2.1 Worktree root

Default:

* `$WT_ROOT = ~/.workbench`

Structure:

```
~/.workbench/
  <repo-name>/
    .workbench/
      config.json
    main/                 # canonical base worktree
    <worktree-name>/      # feature worktree
    <worktree-name>/
```

### 2.2 Global config (main config)

Path:

* `~/.config/workbench/config.json`

Purpose:

* defaults for all repos
* location of WT_ROOT
* default agent + layouts dir + default layout

**Schema**

```json
{
  "workbench_root": "~/.workbench",
  "agent": "opencode",
  "layouts_dir": "~/.config/zellij/layouts",
  "layout": "default.kdl"
}
```

### 2.3 Repo config

Path:

* `~/.workbench/<repo-name>/.workbench/config.json`

Purpose:

* overrides global config for this repo
* defines layout and agent for this repo
* defines default base ref for main

**Schema**

```json
{
  "repo_root": "/abs/path/to/repo",
  "base_ref": "origin/main",
  "agent": "opencode",
  "layouts_dir": "~/.config/zellij/layouts",
  "layout": "phoenix.kdl",
  "dashboard_layout": "dashboard.kdl",
  "branch_prefix": "wb/"
}
```

Precedence:

* repo config overrides global config
* flags override both

---

## 3. Naming Conventions

### 3.1 Repo name

* `repo-name = basename(repo_root)` (user assumption: unique)

### 3.2 Workbench name

* `<worktree-name>` is a readable identifier (e.g., ticket ID): `ABC-123`
* used as folder name and session suffix

Validation:

* must be filesystem safe
* no slashes
* recommended charset: `[A-Za-z0-9._-]+`

### 3.3 Branch name

Default:

* branch = `<branch_prefix><worktree-name>`
* example: `wb/ABC-123`

---

## 4. Zellij Integration

### 4.1 Session naming

Session name:

* `<repo-name>/<worktree-name>`

Dashboard session:

* `<repo-name>/dashboard`

### 4.2 Environment passed to layout

When launching session, export env vars:

* `WORKBENCH_REPO=<repo-name>`
* `WORKBENCH_NAME=<worktree-name>`
* `WORKBENCH_PATH=<abs worktree path>`
* `WORKBENCH_BRANCH=<branch name>`
* `WORKBENCH_BASE_REF=<base ref>`
* `WORKBENCH_AGENT=<agent>`

Implementation note:

* easiest is launching a shell that exports these env vars then runs zellij.

---

## 5. Commands

### 5.1 `workbench init`

Initializes `~/.workbench/<repo-name>` and repo config. Creates canonical `main` worktree.

**Behavior**

1. Detect git repo root from CWD:

   * `git rev-parse --show-toplevel`
2. Determine `repo-name = basename(repo_root)`
3. Create:

   * `WT_ROOT/<repo-name>/.workbench/`
4. Prompt for layout selection:

   * list layouts from `layouts_dir`
   * accept `--layout`
5. Write repo config with:

   * repo_root
   * base_ref (default `origin/main`)
   * layout, layouts_dir, agent
6. Ensure canonical main worktree exists:

   * path: `WT_ROOT/<repo-name>/main`
   * if missing: `git worktree add <main_path> <base_ref>`
7. Run `mise trust` in `main` worktree (interactive)

**Flags**

* `--layout <layout>`
* `--agent <agent>`
* `--layouts-dir <dir>`
* `--base-ref <ref>`
* `--root <path>` override WT_ROOT

**Acceptance**

* idempotent
* main worktree exists after init

---

### 5.2 `workbench create <worktree-name>`

Creates a new workbench: worktree + branch + Zellij session + attach.

**Behavior**

1. Resolve repo config:

   * by repo root (current git dir)
   * if not initialized: error suggesting `init`
2. Compute:

   * worktree path: `WT_ROOT/<repo-name>/<worktree-name>`
   * branch: `branch_prefix + worktree-name`
3. Create worktree:

   * `git worktree add -b <branch> <path> <base_ref>`
4. Run:

   * `mise trust` in new worktree
5. Start zellij session:

   * session: `<repo-name>/<worktree-name>`
   * cwd = worktree path
   * layout from config
6. Attach

**Flags**

* `--from <ref>` overrides base_ref
* `--layout <layout>` override layout
* `--agent <agent>` override agent
* `--no-attach`
* `--no-session` (worktree only)

**Acceptance**

* worktree appears in `git worktree list`
* session exists and is attachable

---

### 5.3 `workbench list`

Lists workbenches derived from git worktrees + zellij sessions.

**Behavior**

* Use `git -C <repo_root> worktree list --porcelain`
* Identify workbenches as worktrees under:

  * `WT_ROOT/<repo-name>/` excluding `.workbench/`
* Determine session status:

  * `zellij list-sessions`
* Render each:

  * worktree-name
  * branch
  * status icon: `●` if session exists else `○`

**Flags**

* `--interactive`
* `--json`

#### Interactive mode (`--interactive`)

Uses `fzf`:

* entry: `<icon> <worktree-name> <branch>`
* Enter: attach
* `ctrl-d`: delete selected (`workbench rm <name>`)
* Preview: `workbench report --name <name>`

**Acceptance**

* interactive attach/delete work reliably

---

### 5.4 `workbench attach [<worktree-name>]`

Attach to a workbench session; resurrect if needed.

**Behavior**

* If name missing:

  * infer from CWD if inside a worktree
  * else open interactive list
* Resolve worktree path:

  * `WT_ROOT/<repo-name>/<worktree-name>`
* If worktree folder missing: error
* If session exists: attach
* If session missing: start session then attach

**Acceptance**

* resurrect works even after killing session

---

### 5.5 `workbench dashboard`

Start/attach dashboard session for repo.

**Behavior**

* session name: `<repo-name>/dashboard`
* layout: `dashboard_layout` if configured else fallback to `dashboard.kdl` in layouts_dir
* dashboard layout displays multiple workbenches

  * can call `workbench list --json` or `workbench report` via `watch`

**Flags**

* `--layout <layout>` override

---

### 5.6 `workbench report [--name <worktree-name>]`

Generate report (markdown/json).

**Behavior**

* Resolve worktree (by name or CWD)
* Show:

  * repo-name / worktree-name
  * branch
  * base_ref
  * git stats:

    * commits ahead/behind base
    * diffstat summary
    * changed files list (truncate)
  * session status (active/inactive)
  * taskwarrior tasks (optional; see below)

**Flags**

* `--name <name>`
* `--format md|json`
* `--output <file>`

---

### 5.7 `workbench rm <worktree-name>`

Remove worktree; keep branch by default.

**Behavior**

* Resolve worktree path
* If session exists:

  * kill session (`zellij kill-session -s <session>`)
* Remove worktree:

  * `git worktree remove <path>` (or `--force`)
* Optional branch deletion:

  * if `--branch`: delete local branch
  * safety checks unless `--force`

**Flags**

* `--branch`
* `--force`
* `--yes`

**Acceptance**

* after rm, no worktree in `git worktree list`
* branch remains unless `--branch`

---

### 5.8 `workbench doctor`

Detect and fix inconsistencies.

**Detect**

* worktree exists in git but folder missing → suggest `git worktree prune`
* folder exists but not in git worktrees → warn (manual intervention)
* session exists but folder missing → orphan session

**Flags**

* `--fix` (safe fixes only)
* `--json`

---

## 6. Taskwarrior Integration (Optional but supported)

Since you said “yes but not sure”: keep it minimal and non-magical.

### Convention

* Taskwarrior project name:

  * `<repo-name>:<worktree-name>`
    Example:
* `backend:ABC-123`

### Display

* report/dashboard show:

  * `task project:backend:ABC-123 status:pending`

### Creation

`workbench create` prints a hint after attach:

* `task add project:<repo>:<name> "..."`

Optional flag later:

* `workbench create <name> --task "Bootstrap <name>"`

---

## 7. Dependency checks

On startup:

* require: `git`, `zellij`
* if missing: actionable error
* optional: `fzf`, `task`, `mise`

---

## 8. Acceptance Criteria / MVP Definition

MVP is complete when:

1. `init` sets up repo config + main worktree.
2. `create` spawns worktree + zellij session and attaches.
3. `list --interactive` lets you attach/delete.
4. `attach` resurrects sessions.
5. `rm` removes worktree safely.
6. `doctor` identifies broken state; `--fix` prunes safe cases.
7. `dashboard` starts a dashboard layout.
8. `report` outputs correct git diff summary vs base.

---

