# Git worktree operations for workbench CLI

use utils.nu [normalize-base-ref]

# Parse git worktree list --porcelain output
export def list-worktrees [repo_root: string]: nothing -> table<path: string, head: string, branch: string> {
    let result = (do { git -C $repo_root worktree list --porcelain } | complete)
    if $result.exit_code != 0 {
        return []
    }
    
    let lines = ($result.stdout | lines)
    mut worktrees = []
    mut current = { path: "", head: "", branch: "" }
    
    for line in $lines {
        if ($line | str starts-with "worktree ") {
            if $current.path != "" {
                $worktrees = ($worktrees | append $current)
            }
            $current = { 
                path: ($line | str replace "worktree " ""), 
                head: "", 
                branch: "" 
            }
        } else if ($line | str starts-with "HEAD ") {
            $current = ($current | merge { head: ($line | str replace "HEAD " "") })
        } else if ($line | str starts-with "branch ") {
            $current = ($current | merge { branch: ($line | str replace "branch refs/heads/" "") })
        }
    }
    
    if $current.path != "" {
        $worktrees = ($worktrees | append $current)
    }
    
    $worktrees
}

# Get workbenches (worktrees under wb_root/repo_name, excluding .workbench)
export def list-workbenches [
    repo_root: string, 
    wb_root: string, 
    repo_name: string
]: nothing -> table<name: string, path: string, branch: string, head: string> {
    let wt_base = ([$wb_root, $repo_name] | path join)
    let worktrees = (list-worktrees $repo_root)
    
    $worktrees 
    | where path =~ $"^($wt_base)/"
    | each {|wt|
        let name = ($wt.path | str replace $"($wt_base)/" "")
        if ($name != ".workbench" and not ($name | str contains "/")) {
            { name: $name, path: $wt.path, branch: $wt.branch, head: $wt.head }
        } else {
            null
        }
    }
    | compact
}

# Add a new worktree - creates branch if it doesn't exist, uses existing if it does
export def add-worktree [
    repo_root: string,
    path: string,
    branch: string,
    base_ref: string
]: nothing -> nothing {
    let normalized = (normalize-base-ref $base_ref)
    
    # Check if branch already exists
    let branch_check = (do { git -C $repo_root rev-parse --verify $"refs/heads/($branch)" } | complete)
    
    let result = if $branch_check.exit_code == 0 {
        # Branch exists - use it directly
        do { git -C $repo_root worktree add $path $branch } | complete
    } else {
        # Branch doesn't exist - create it from base_ref
        do { git -C $repo_root worktree add -b $branch $path $normalized } | complete
    }
    
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to create worktree: ($result.stderr)"
        }
    }
}

# Remove a worktree
export def remove-worktree [repo_root: string, path: string, force: bool = false]: nothing -> nothing {
    let args = if $force { ["worktree", "remove", "--force", $path] } else { ["worktree", "remove", $path] }
    let result = (do { git -C $repo_root ...$args } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to remove worktree: ($result.stderr)"
        }
    }
}

# Prune worktrees
export def prune-worktrees [repo_root: string]: nothing -> nothing {
    let result = (do { git -C $repo_root worktree prune } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to prune worktrees: ($result.stderr)"
        }
    }
}
