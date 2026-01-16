# Utility functions for workbench CLI

# Check required dependencies, return list of missing ones
export def check-deps []: nothing -> table<name: string, required: bool, found: bool> {
    let deps = [
        { name: "git", required: true }
        { name: "zellij", required: true }
        { name: "fzf", required: false }
        { name: "task", required: false }
    ]
    
    $deps | each {|dep|
        let found = (which $dep.name | is-not-empty)
        { name: $dep.name, required: $dep.required, found: $found }
    }
}

# Assert required deps exist, error if missing
export def assert-deps []: nothing -> nothing {
    let missing = (check-deps | where {|r| $r.required and (not $r.found)} | get name)
    if ($missing | is-not-empty) {
        error make --unspanned {
            msg: $"Missing required dependencies: ($missing | str join ', ')"
            help: "Please install the missing tools and try again"
        }
    }
}

# Expand ~ to home directory
export def expand-path [path: string]: nothing -> string {
    $path | str replace -r '^~' $env.HOME
}

# Get global config path
export def get-global-config-path []: nothing -> string {
    expand-path "~/.config/workbench/config.json"
}

# Get repo config path
export def get-repo-config-path [wb_root: string, repo_name: string]: nothing -> string {
    [$wb_root, $repo_name, ".workbench", "config.json"] | path join
}

# Get worktree path for a workbench (name should already be sanitized/folder-safe)
export def get-worktree-path [wb_root: string, repo_name: string, folder: string]: nothing -> string {
    [$wb_root, $repo_name, $folder] | path join
}

# Normalize base refs like origin/main to avoid ambiguity
export def normalize-base-ref [base_ref: string]: nothing -> string {
    if ($base_ref | str starts-with "refs/") {
        $base_ref
    } else if ($base_ref | str starts-with "origin/") {
        $"refs/remotes/($base_ref)"
    } else {
        $base_ref
    }
}

# Build environment variables for workbench sessions
export def build-workbench-env [
    repo_name: string,
    wb_name: string,
    wt_path: string,
    branch: string,
    base_ref: string,
    agent: string,
    extra?: record
]: nothing -> record {
    let env_vars = {
        WORKBENCH_REPO: $repo_name
        WORKBENCH_NAME: $wb_name
        WORKBENCH_PATH: $wt_path
        WORKBENCH_BRANCH: $branch
        WORKBENCH_BASE_REF: $base_ref
        WORKBENCH_AGENT: $agent
    }
    if $extra != null {
        $env_vars | merge $extra
    } else {
        $env_vars
    }
}

# Check if running inside zellij
export def in-zellij []: nothing -> bool {
    ($env.ZELLIJ? | default "" | str length) > 0
}

# Get current git repo root from CWD
export def get-git-root []: nothing -> string {
    let result = (do { git rev-parse --show-toplevel } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: "Not in a git repository"
            help: "Run this command from within a git repository"
        }
    }
    $result.stdout | str trim
}
