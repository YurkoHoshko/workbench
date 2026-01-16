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

# Check if branch exists
export def branch-exists [repo_root: string, branch: string]: nothing -> bool {
    let result = (do { git -C $repo_root rev-parse --verify $"refs/heads/($branch)" } | complete)
    $result.exit_code == 0
}

# Detect default remote branch (origin/main or origin/master)
export def detect-default-branch [repo_root: string]: nothing -> string {
    # Try symbolic-ref first (most reliable)
    let remote_head = (do { git -C $repo_root symbolic-ref refs/remotes/origin/HEAD } | complete)
    if $remote_head.exit_code == 0 {
        return ($remote_head.stdout | str trim | str replace "refs/remotes/" "")
    }
    
    # Fallback: check if origin/main exists
    let has_main = (do { git -C $repo_root rev-parse --verify origin/main } | complete)
    if $has_main.exit_code == 0 {
        return "origin/main"
    }
    
    # Fallback: check if origin/master exists
    let has_master = (do { git -C $repo_root rev-parse --verify origin/master } | complete)
    if $has_master.exit_code == 0 {
        return "origin/master"
    }
    
    # Last resort: try to find any remote branch
    let branches = (do { git -C $repo_root branch -r --format='%(refname:short)' } | complete)
    if $branches.exit_code == 0 {
        let first_branch = ($branches.stdout | lines | where { $in != "" and not ($in | str contains "HEAD") } | first)
        if $first_branch != null {
            return $first_branch
        }
    }
    
    # Give up - return main and let it fail with clear error
    "origin/main"
}
