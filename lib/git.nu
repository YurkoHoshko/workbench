use utils.nu [normalize-base-ref]

# Delete a local branch
export def delete-branch [repo_root: string, branch: string, force: bool = false]: nothing -> nothing {
    let flag = if $force { "-D" } else { "-d" }
    let result = (do { git -C $repo_root branch $flag $branch } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to delete branch: ($result.stderr)"
        }
    }
}

# Get commits ahead/behind base
export def get-diff-stats [repo_root: string, branch: string, base_ref: string]: nothing -> record<ahead: int, behind: int> {
    let normalized = (normalize-base-ref $base_ref)
    let result = (do { git -C $repo_root rev-list --left-right --count $"($normalized)...($branch)" } | complete)
    if $result.exit_code != 0 {
        return { ahead: 0, behind: 0 }
    }
    
    let parts = ($result.stdout | str trim | split row "\t")
    {
        behind: ($parts | get 0 | into int)
        ahead: ($parts | get 1 | into int)
    }
}

# Get diffstat summary
export def get-diffstat [repo_root: string, base_ref: string]: nothing -> string {
    let normalized = (normalize-base-ref $base_ref)
    let result = (do { git -C $repo_root diff --stat $normalized } | complete)
    if $result.exit_code != 0 {
        return ""
    }
    $result.stdout | str trim
}

# Get list of changed files
export def get-changed-files [repo_root: string, base_ref: string]: nothing -> list<string> {
    let normalized = (normalize-base-ref $base_ref)
    let result = (do { git -C $repo_root diff --name-only $normalized } | complete)
    if $result.exit_code != 0 {
        return []
    }
    $result.stdout | lines | where $it != ""
}

# Check if branch exists
export def branch-exists [repo_root: string, branch: string]: nothing -> bool {
    let result = (do { git -C $repo_root rev-parse --verify $"refs/heads/($branch)" } | complete)
    $result.exit_code == 0
}

# Detect default remote branch (origin/main or origin/master)
export def detect-default-branch [repo_root: string]: nothing -> string {
    # Try symbolic-ref first
    let remote_head = (do { git -C $repo_root symbolic-ref refs/remotes/origin/HEAD } | complete)
    if $remote_head.exit_code == 0 {
        return ($remote_head.stdout | str trim | str replace "refs/remotes/" "")
    }
    
    # Fallback: check if origin/main exists
    let has_main = (do { git -C $repo_root rev-parse --verify origin/main } | complete)
    if $has_main.exit_code == 0 {
        return "origin/main"
    }
    
    # Fallback: origin/master
    "origin/master"
}
