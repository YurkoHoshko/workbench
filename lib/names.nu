# Naming helpers for workbench CLI
#
# Unified naming: branch name is the primary identifier
# - Session name: branch with "/" → "_" (zellij doesn't allow slashes)
# - Folder name: branch with "/" → "_" (filesystem-safe)

# Get repo name from repo root path
export def repo-name [repo_root: string]: nothing -> string {
    $repo_root | path basename
}

# Sanitize branch name for use in session/folder names (replace / with _)
export def sanitize-branch [branch: string]: nothing -> string {
    $branch | str replace --all "/" "_"
}

# Format session name for zellij from branch name
export def session-name [branch: string]: nothing -> string {
    sanitize-branch $branch
}

# Get folder name from branch (same as session name)
export def folder-name [branch: string]: nothing -> string {
    sanitize-branch $branch
}
