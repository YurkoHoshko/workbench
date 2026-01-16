# Shell completions for workbench CLI

use utils.nu [expand-path]
use config.nu [load-repo-config, repo-initialized]
use worktrees.nu [list-workbenches]

# Get list of workbench branches for current repo
def get-workbench-branches []: nothing -> list<string> {
    let repo_root = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root.exit_code != 0 {
        return []
    }
    
    let root = ($repo_root.stdout | str trim)
    let repo_name = ($root | path basename)
    
    if not (repo-initialized $repo_name) {
        return []
    }
    
    let config = (load-repo-config $repo_name)
    let wb_root = (expand-path $config.workbench_root)
    
    let workbenches = (list-workbenches $root $wb_root $repo_name)
    $workbenches | get branch
}

# Completion for workbench branches
export def workbench-branch [] {
    get-workbench-branches | each {|branch| { value: $branch, description: "workbench" } }
}

# Completion for layout files
export def layout-files [] {
    let layouts_dir = "~/.config/zellij/layouts" | path expand
    if ($layouts_dir | path exists) {
        ls $layouts_dir 
        | where name =~ '\.kdl$' 
        | get name 
        | each {|f| { value: ($f | path basename), description: "layout" } }
    } else {
        []
    }
}

# Completion for agents
export def agents [] {
    ["opencode", "amp", "claude", "aider", "cursor"] | each {|a| { value: $a, description: "agent" } }
}

# Completion for branch names (local + remote)
export def branch-names [] {
    let result = (do { git branch -a --format='%(refname:short)' } | complete)
    if $result.exit_code != 0 {
        return []
    }
    
    $result.stdout 
    | lines 
    | where $it != "" 
    | each {|b| 
        # Clean up remote branch names (origin/branch -> branch for display)
        let clean = ($b | str replace "origin/" "")
        { value: $b, description: $clean }
    }
    | uniq-by value
}
