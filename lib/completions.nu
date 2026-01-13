# Shell completions for workbench CLI

use utils.nu [get-git-root, get-repo-name, expand-path]
use config.nu [load-repo-config, repo-initialized]
use git.nu [list-workbenches]

# Get list of workbench names for current repo
def get-workbench-names []: nothing -> list<string> {
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
    $workbenches | get name
}

# Completion for workbench names
export def workbench-name [] {
    get-workbench-names | each {|name| { value: $name, description: "workbench" } }
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

# Completion for report formats
export def report-formats [] {
    [
        { value: "md", description: "Markdown" }
        { value: "json", description: "JSON" }
    ]
}
