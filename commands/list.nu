# workbench list - List workbenches with session status

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/zellij.nu *

# List workbenches derived from git worktrees + zellij sessions
export def main [
    --interactive (-i)  # Open interactive fzf picker
    --json (-j)         # Output as JSON
]: nothing -> any {
    assert-deps
    
    let repo_root = (get-git-root)
    let repo_name = (get-repo-name $repo_root)
    
    if not (repo-initialized $repo_name) {
        error make {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run `workbench init` first"
        }
    }
    
    let config = (load-repo-config $repo_name)
    let wb_root = (expand-path $config.workbench_root)
    
    # Get workbenches from git worktrees
    let workbenches = (list-workbenches $repo_root $wb_root $repo_name)
    
    # Get active sessions
    let sessions = (list-sessions)
    
    # Build display table
    let display = ($workbenches | each {|wb|
        let session_name = (format-session-name $repo_name $wb.name)
        let status = if ($session_name in $sessions) { "●" } else { "○" }
        {
            status: $status
            name: $wb.name
            branch: $wb.branch
            path: $wb.path
            session: $session_name
            active: ($session_name in $sessions)
        }
    })
    
    if $json {
        return ($display | to json)
    }
    
    if $interactive {
        interactive-list $display $repo_name $repo_root
    } else {
        # Simple table output
        $display | select status name branch | table
    }
}

# Interactive fzf picker
def interactive-list [workbenches: list, repo_name: string, repo_root: string]: nothing -> nothing {
    if (which fzf | is-empty) {
        error make {
            msg: "fzf is required for interactive mode"
            help: "Install fzf: https://github.com/junegunn/fzf"
        }
    }
    
    # Format entries for fzf
    let entries = ($workbenches | each {|wb|
        $"($wb.status) ($wb.name) ($wb.branch)"
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
        # Parse selected entry: "● name branch"
        let parts = ($selected | split row " ")
        let name = ($parts | get 1)
        print $"Attaching to ($name)..."
        
        # Build env vars and attach
        let config = (load-repo-config $repo_name)
        let wb_root = (expand-path $config.workbench_root)
        let wt_path = (get-worktree-path $wb_root $repo_name $name)
        let branch = (format-branch-name $config.branch_prefix $name)
        let session_name = (format-session-name $repo_name $name)
        
        let env_vars = {
            WORKBENCH_REPO: $repo_name
            WORKBENCH_NAME: $name
            WORKBENCH_PATH: $wt_path
            WORKBENCH_BRANCH: $branch
            WORKBENCH_BASE_REF: $config.base_ref
            WORKBENCH_AGENT: $config.agent
        }
        
        ensure-and-attach $session_name $wt_path $config.layout (expand-path $config.layouts_dir) $env_vars
    }
}
