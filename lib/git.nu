# Git worktree operations for workbench CLI

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

# Add a new worktree with a new branch
export def add-worktree [
    repo_root: string,
    path: string,
    branch: string,
    base_ref: string
]: nothing -> nothing {
    let result = (do { git -C $repo_root worktree add -b $branch $path $base_ref } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to create worktree: ($result.stderr)"
        }
    }
}

# Add worktree for existing branch
export def add-worktree-existing [
    repo_root: string,
    path: string,
    branch: string
]: nothing -> nothing {
    let result = (do { git -C $repo_root worktree add $path $branch } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to create worktree: ($result.stderr)"
        }
    }
}

# Add worktree in detached HEAD mode (for main worktree tracking a ref)
export def add-worktree-detached [
    repo_root: string,
    path: string,
    ref: string
]: nothing -> nothing {
    let result = (do { git -C $repo_root worktree add --detach $path $ref } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to create worktree: ($result.stderr)"
        }
    }
}

# Remove a worktree
export def remove-worktree [repo_root: string, path: string, force: bool = false]: nothing -> nothing {
    let args = if $force { ["worktree", "remove", "--force", $path] } else { ["worktree", "remove", $path] }
    let result = (do { git -C $repo_root ...$args } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to remove worktree: ($result.stderr)"
        }
    }
}

# Delete a local branch
export def delete-branch [repo_root: string, branch: string, force: bool = false]: nothing -> nothing {
    let flag = if $force { "-D" } else { "-d" }
    let result = (do { git -C $repo_root branch $flag $branch } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to delete branch: ($result.stderr)"
        }
    }
}

# Prune worktrees
export def prune-worktrees [repo_root: string]: nothing -> nothing {
    let result = (do { git -C $repo_root worktree prune } | complete)
    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to prune worktrees: ($result.stderr)"
        }
    }
}

# Get commits ahead/behind base
export def get-diff-stats [repo_root: string, branch: string, base_ref: string]: nothing -> record<ahead: int, behind: int> {
    let result = (do { git -C $repo_root rev-list --left-right --count $"($base_ref)...($branch)" } | complete)
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
    let result = (do { git -C $repo_root diff --stat $base_ref } | complete)
    if $result.exit_code != 0 {
        return ""
    }
    $result.stdout | str trim
}

# Get list of changed files
export def get-changed-files [repo_root: string, base_ref: string]: nothing -> list<string> {
    let result = (do { git -C $repo_root diff --name-only $base_ref } | complete)
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

# Fetch from remote
export def fetch [repo_root: string]: nothing -> nothing {
    do { git -C $repo_root fetch } | complete | ignore
}
