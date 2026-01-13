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

# Validate workbench name (filesystem safe)
export def validate-name [name: string]: nothing -> bool {
    $name =~ '^[A-Za-z0-9._-]+$'
}

# Assert workbench name is valid
export def assert-valid-name [name: string]: nothing -> nothing {
    if not (validate-name $name) {
        error make --unspanned {
            msg: $"Invalid workbench name: '($name)'"
            help: "Name must match [A-Za-z0-9._-]+ (no slashes or special characters)"
        }
    }
}

# Expand ~ to home directory
export def expand-path [path: string]: nothing -> string {
    $path | str replace -r '^~' $env.HOME
}

# Get workbench root (default ~/.workbench)
export def get-workbench-root [override?: string]: nothing -> string {
    let root = if $override != null { $override } else { "~/.workbench" }
    expand-path $root
}

# Get global config path
export def get-global-config-path []: nothing -> string {
    expand-path "~/.config/workbench/config.json"
}

# Get repo config path
export def get-repo-config-path [wb_root: string, repo_name: string]: nothing -> string {
    [$wb_root, $repo_name, ".workbench", "config.json"] | path join
}

# Get worktree path for a workbench
export def get-worktree-path [wb_root: string, repo_name: string, name: string]: nothing -> string {
    [$wb_root, $repo_name, $name] | path join
}

# Format session name for zellij (no slashes allowed)
export def format-session-name [repo_name: string, wb_name: string]: nothing -> string {
    $"($repo_name)_($wb_name)"
}

# Format branch name with prefix
export def format-branch-name [prefix: string, wb_name: string]: nothing -> string {
    $"($prefix)($wb_name)"
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

# Get repo name from repo root path
export def get-repo-name [repo_root: string]: nothing -> string {
    $repo_root | path basename
}
