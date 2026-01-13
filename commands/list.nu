# workbench list - List all workbenches across all repos

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
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
    
    # Build display table
    let display = ($all_workbenches | each {|wb|
        let session_name = (session-name $wb.repo_name $wb.name)
        let status = if ($session_name in $sessions) { "●" } else { "○" }
        {
            status: $status
            display_name: $"($wb.repo_name)/($wb.name)"
            repo_name: $wb.repo_name
            name: $wb.name
            branch: $wb.branch
            path: $wb.path
            repo_root: $wb.repo_root
            session: $session_name
            active: ($session_name in $sessions)
        }
    })
    
    if $json {
        return ($display | to json)
    }
    
    if $interactive {
        interactive-list $display $wb_root
    } else {
        # Simple table output
        $display | select status display_name branch | table
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
    
    # Format entries for fzf
    let entries = ($workbenches | each {|wb|
        $"($wb.status) ($wb.display_name) ($wb.branch)"
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
    rm -f $tmpfile
    
    if $selected != "" {
        # Parse selected entry: "● repo/name branch"
        let parts = ($selected | split row " ")
        let display_name = ($parts | get 1)
        let name_parts = ($display_name | split row "/")
        let repo_name = ($name_parts | get 0)
        let wb_name = ($name_parts | get 1)
        
        print $"Attaching to ($display_name)..."
        
        # Build env vars and attach
        let config = (load-repo-config $repo_name $wb_root)
        let wt_path = (get-worktree-path $wb_root $repo_name $wb_name)
        let wb_info = ($workbenches | where { $in.repo_name == $repo_name and $in.name == $wb_name } | first)
        let branch = $wb_info.branch
        let env_vars = (build-workbench-env $repo_name $wb_name $wt_path $branch $config.base_ref $config.agent)
        let layout_path = (layout-path-if-exists $config.layout $config.layouts_dir)

        if not (session-exists $repo_name $wb_name) {
            start $repo_name $wb_name $wt_path $layout_path $env_vars
        }

        if (in-zellij) {
            let plugin_path = (install-switch-plugin (get-zellij-plugin-dir))
            switch $repo_name $wb_name $wt_path $layout_path $plugin_path
        } else {
            attach $repo_name $wb_name
        }
    }
}
