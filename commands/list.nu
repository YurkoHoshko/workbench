# workbench list - List all workbenches across all repos

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# List workbenches from all initialized repos under workbench_root
export def main [
    --interactive (-i)  # Open interactive fzf picker
    --json (-j)         # Output as JSON
]: nothing -> any {
    let global_config = (load-global-config)
    let wb_root = (expand-path $global_config.workbench_root)
    
    # Scan all repo directories under workbench_root
    let all_workbenches = (scan-all-repos $wb_root)
    
    # Get active sessions (gracefully handle missing zellij)
    let sessions = if (which zellij | is-not-empty) {
        list-sessions
    } else {
        []
    }
    
    # Build display table - session name derived from branch
    let display = ($all_workbenches | each {|wb|
        let sess_name = (session-name $wb.branch)
        let status = if ($sess_name in $sessions) { "●" } else { "○" }
        {
            status: $status
            branch: $wb.branch
            repo_name: $wb.repo_name
            folder: $wb.name
            path: $wb.path
            repo_root: $wb.repo_root
            session: $sess_name
            active: ($sess_name in $sessions)
        }
    })
    
    if $json {
        return ($display | to json)
    }
    
    if $interactive {
        interactive-list $display $wb_root
    } else {
        # Simple table output - show branch as primary identifier
        $display | select status branch repo_name | table
    }
}

# Scan all initialized repos under workbench_root and collect their workbenches
def scan-all-repos [wb_root: string]: nothing -> list {
    if not ($wb_root | path exists) {
        return []
    }
    
    # List directories under wb_root (each is a repo)
    let repo_dirs = (ls $wb_root | where type == dir | get name)
    
    mut all_workbenches = []
    
    for repo_dir in $repo_dirs {
        let repo_name = ($repo_dir | path basename)
        let config_path = (get-repo-config-path $wb_root $repo_name)
        
        # Only process initialized repos
        if ($config_path | path exists) {
            let repo_config = (load-repo-config $repo_name $wb_root)
            let repo_root = $repo_config.repo_root
            
            # Get workbenches for this repo
            let workbenches = (list-workbenches $repo_root $wb_root $repo_name)
            
            # Add repo context to each workbench
            let with_repo = ($workbenches | each {|wb|
                $wb | merge { repo_name: $repo_name, repo_root: $repo_root }
            })
            
            $all_workbenches = ($all_workbenches | append $with_repo)
        }
    }
    
    $all_workbenches
}

# Interactive fzf picker
def interactive-list [workbenches: list, wb_root: string]: nothing -> nothing {
    if (which fzf | is-empty) {
        error make --unspanned {
            msg: "fzf is required for interactive mode"
            help: "Install fzf: https://github.com/junegunn/fzf"
        }
    }
    
    # Format entries for fzf - branch is the primary identifier
    let entries = ($workbenches | each {|wb|
        $"($wb.status) ($wb.branch) [($wb.repo_name)]"
    } | str join "\n")
    
    if ($entries | str trim) == "" {
        print "No workbenches found"
        return
    }
    
    # Write entries to temp file for fzf
    let tmpfile = $"/tmp/workbench-list-($nu.pid).txt"
    $entries | save -f $tmpfile
    
    # Run fzf with proper tty access
    let selected = (^bash -c $"fzf --ansi --header 'Enter: attach | Esc: cancel' < '($tmpfile)'" | str trim)
    ^rm -f $tmpfile
    
    if $selected != "" {
        # Parse selected entry: "● branch [repo_name]"
        let parts = ($selected | split row " ")
        let branch = ($parts | get 1)
        
        # Find matching workbench
        let wb_info = ($workbenches | where { $in.branch == $branch } | first)
        let repo_name = $wb_info.repo_name
        let folder = $wb_info.folder
        
        print $"Attaching to ($branch)..."
        
        # Build env vars and attach
        let config = (load-repo-config $repo_name $wb_root)
        let wt_path = (get-worktree-path $wb_root $repo_name $folder)
        let env_vars = (build-workbench-env $repo_name $folder $wt_path $branch $config.base_ref $config.agent)
        let layout_path = (layout-path-if-exists $config.layout)

        let sess_name = (session-name $branch)
        if not (session-exists $sess_name) {
            start $sess_name $wt_path $layout_path $env_vars
        }

        if (in-zellij) {
            error make --unspanned {
                msg: "Cannot attach from inside zellij"
                help: "Use 'workbench shell' from outside zellij, or detach first (Ctrl+O d)"
            }
        }
        
        attach $sess_name
    }
}
