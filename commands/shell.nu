# workbench shell - Interactive session picker loop
# Detach from any session returns you here to pick the next one

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *
use ../lib/mru.nu *

# Interactive session picker shell - runs in a loop
export def main [
    --debug (-d)  # Enable debug logging
]: nothing -> nothing {
    assert-deps
    
    if (which fzf | is-empty) {
        error make --unspanned {
            msg: "fzf is required for workbench shell"
            help: "Install fzf: https://github.com/junegunn/fzf"
        }
    }
    
    if (in-zellij) {
        error make --unspanned {
            msg: "workbench shell should not be run inside zellij"
            help: "Detach first (Ctrl+O d) or run from a regular terminal"
        }
    }
    
    if $debug { print "[DEBUG] Starting workbench shell loop" }
    
    mut running = true
    while $running {
        if $debug { print "[DEBUG] Loading global config..." }
        let global_config = (load-global-config)
        let wb_root = (expand-path $global_config.workbench_root)
        
        if $debug { print $"[DEBUG] Workbench root: ($wb_root)" }
        
        if $debug { print "[DEBUG] Scanning repos..." }
        let all_workbenches = (scan-all-repos $wb_root $debug)
        
        if $debug { print $"[DEBUG] Found ($all_workbenches | length) workbenches" }
        
        if $debug { print "[DEBUG] Getting zellij sessions..." }
        let sessions = if (which zellij | is-not-empty) {
            list-sessions
        } else {
            []
        }
        if $debug { print $"[DEBUG] Active sessions: ($sessions)" }
        
        # Build display list - branch is the primary identifier
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
        
        # Sort by MRU
        let sorted = (sort-by-mru $display)
        
        if ($sorted | is-empty) {
            print "No workbenches found. Press Enter to refresh or Ctrl+C to exit."
            let _ = (input)
            continue
        }
        
        # Format for fzf - show branch as primary, repo in brackets
        let entries = ($sorted | each {|wb|
            $"($wb.status) ($wb.branch) [($wb.repo_name)]"
        })
        
        if $debug { print $"[DEBUG] FZF entries: ($entries)" }
        if $debug { print "[DEBUG] Launching fzf..." }
        
        # Run fzf directly - let it have full terminal access
        let selected_line = try {
            $entries | to text | ^fzf --ansi --header "workbench shell │ Enter: attach │ Esc: exit" --no-sort --layout=reverse | str trim
        } catch {
            # fzf returns non-zero on Esc/Ctrl+C
            ""
        }
        
        if $debug { print $"[DEBUG] FZF selected: '($selected_line)'" }
        
        if $selected_line == "" {
            print "Exiting workbench shell"
            $running = false
            continue
        }
        
        # Parse: "● branch [repo_name]"
        let parts = ($selected_line | split row " ")
        let branch = ($parts | get 1)
        
        if $debug { print $"[DEBUG] Selected branch: ($branch)" }
        
        # Find matching workbench
        let wb_info = ($sorted | where { $in.branch == $branch } | first)
        let repo_name = $wb_info.repo_name
        let folder = $wb_info.folder
        
        # Load config and attach
        let config = (load-repo-config $repo_name $wb_root)
        let wt_path = (get-worktree-path $wb_root $repo_name $folder)
        let env_vars = (build-workbench-env $repo_name $folder $wt_path $branch $config.base_ref $config.agent)
        let layout_path = (layout-path-if-exists $config.layout)
        let sess_name = (session-name $branch)
        
        if $debug { print $"[DEBUG] Session name: ($sess_name), path: ($wt_path)" }
        
        # Start session if not running
        if not (session-exists $sess_name) {
            if $debug { print "[DEBUG] Starting new session..." }
            start $sess_name $wt_path $layout_path $env_vars
        }
        
        # Track MRU before attaching
        touch-mru $sess_name
        
        # Attach - this blocks until detach
        print $"Attaching to ($branch)..."
        attach $sess_name
        
        # After detach, loop continues and shows picker again
        print ""
    }
}

# Scan all initialized repos
def scan-all-repos [wb_root: string, debug: bool = false]: nothing -> list {
    if not ($wb_root | path exists) {
        if $debug { print $"[DEBUG] Workbench root doesn't exist: ($wb_root)" }
        return []
    }
    
    let repo_dirs = (ls $wb_root | where type == dir | get name)
    if $debug { print $"[DEBUG] Repo dirs: ($repo_dirs)" }
    
    mut all_workbenches = []
    
    for repo_dir in $repo_dirs {
        let repo_name = ($repo_dir | path basename)
        let config_path = (get-repo-config-path $wb_root $repo_name)
        
        if $debug { print $"[DEBUG] Checking repo ($repo_name), config: ($config_path)" }
        
        if ($config_path | path exists) {
            let repo_config = (load-repo-config $repo_name $wb_root)
            let repo_root = $repo_config.repo_root
            
            if $debug { print $"[DEBUG] Repo root: ($repo_root)" }
            
            let workbenches = (list-workbenches $repo_root $wb_root $repo_name)
            if $debug { print $"[DEBUG] Workbenches in ($repo_name): ($workbenches | length)" }
            
            let with_repo = ($workbenches | each {|wb|
                $wb | merge { repo_name: $repo_name, repo_root: $repo_root }
            })
            
            $all_workbenches = ($all_workbenches | append $with_repo)
        }
    }
    
    $all_workbenches
}
