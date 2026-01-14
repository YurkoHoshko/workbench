# Naming helpers for workbench CLI

# Get repo name from repo root path
export def repo-name [repo_root: string]: nothing -> string {
    $repo_root | path basename
}

# Format session name for zellij (no slashes allowed)
export def session-name [repo_name: string, wb_name: string]: nothing -> string {
    $"($repo_name)_($wb_name)"
}

# Format branch name with prefix
export def branch-name [prefix: string, wb_name: string]: nothing -> string {
    $"($prefix)($wb_name)"
}
