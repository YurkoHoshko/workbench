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
        if $debug { print "[DEBUG] Loading config and scanning..." }
        let global_config = (load-global-config)
        let wb_root = (expand-path $global_config.workbench_root)
        let all_workbenches = (scan-all-repos $wb_root $debug)
        
        if $debug { print $"[DEBUG] Found ($all_workbenches | length) workbenches" }
        
        let sessions = if (which zellij | is-not-empty) { list-sessions } else { [] }
        
        # Build display list
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
        
        let sorted = (sort-by-mru $display)
        
        if ($sorted | is-empty) {
            print "No workbenches found. Press Enter to refresh or Ctrl+C to exit."
            let _ = (input)
            continue
        }
        
        # Format for fzf: status branch [repo] path
        # Use --with-nth to show only first 3 fields, {4} available for preview
        let entries = ($sorted | each {|wb|
            $"($wb.status) ($wb.branch) [($wb.repo_name)] ($wb.path)"
        })
        
        if $debug { print $"[DEBUG] Launching fzf with ($entries | length) entries" }
        
        # Preview: git log + status for the worktree path (field 4)
        # Wrapped in sh -c to ensure posix shell regardless of user's $SHELL
        let preview_cmd = "sh -c 'path={4}; if [ -d \"$path\" ]; then echo \"📁 $path\"; echo; cd \"$path\"; git log --oneline -5 2>/dev/null; echo; git status -s 2>/dev/null | head -15; fi'"
        
        # Run fzf with --expect to capture keybindings
        let fzf_output = try {
            $entries | to text | ^fzf --ansi --no-sort --layout=default --with-nth=1,2,3 --expect=ctrl-s,ctrl-d,ctrl-n --header "Enter: attach │ Ctrl+S: toggle │ Ctrl+D: delete │ Ctrl+N: new │ Esc: exit" --preview $preview_cmd --preview-window=right:50%
        } catch {
            ""
        }
        
        if $fzf_output == "" {
            print "Exiting workbench shell"
            $running = false
            continue
        }
        
        # Parse fzf output: first line is key, second is selection
        let lines = ($fzf_output | lines)
        let key_pressed = ($lines | get 0 | str trim)
        let selected_line = if ($lines | length) > 1 { $lines | get 1 | str trim } else { "" }
        
        if $debug { print $"[DEBUG] Key: '($key_pressed)', Selection: '($selected_line)'" }
        
        if $selected_line == "" {
            continue
        }
        
        # Parse: "● branch [repo_name] path" - get highlighted item's info
        let parts = ($selected_line | split row " ")
        let branch = ($parts | get 1)
        let wb_info = ($sorted | where { $in.branch == $branch } | first)
        
        if ($wb_info | is-empty) {
            print $"Could not find workbench for branch: ($branch)"
            continue
        }
        
        let repo_name = $wb_info.repo_name
        let folder = $wb_info.folder
        let sess_name = (session-name $branch)
        
        # Handle ctrl-n - create new workbench in the highlighted item's repo
        if $key_pressed == "ctrl-n" {
            print $"New workbench in ($repo_name) - enter branch name: "
            let new_branch = (input | str trim)
            if $new_branch != "" {
                let config = (load-repo-config $repo_name $wb_root)
                let new_folder = (folder-name $new_branch)
                let wt_path = (get-worktree-path $wb_root $repo_name $new_folder)
                
                print $"Creating workbench: ($new_branch)"
                add-worktree $config.repo_root $wt_path $new_branch $config.base_ref
                
                let new_sess_name = (session-name $new_branch)
                let env_vars = (build-workbench-env $repo_name $new_folder $wt_path $new_branch $config.base_ref $config.agent)
                let layout_path = (layout-path-if-exists $config.layout)
                start $new_sess_name $wt_path $layout_path $env_vars
                
                touch-mru $new_sess_name
                print $"Attaching to ($new_branch)..."
                attach $new_sess_name
                print ""
            }
            continue
        }
        
        # Handle action based on key
        match $key_pressed {
            "ctrl-s" => {
                # Toggle session on/off
                if (session-exists $sess_name) {
                    print $"Stopping session: ($sess_name)"
                    stop $sess_name
                } else {
                    print $"Starting session: ($sess_name)"
                    let config = (load-repo-config $repo_name $wb_root)
                    let wt_path = (get-worktree-path $wb_root $repo_name $folder)
                    let env_vars = (build-workbench-env $repo_name $folder $wt_path $branch $config.base_ref $config.agent)
                    let layout_path = (layout-path-if-exists $config.layout)
                    start $sess_name $wt_path $layout_path $env_vars
                }
                sleep 300ms  # Brief pause to see the message
            }

            "ctrl-d" => {
                # Delete workbench (session + worktree)
                print $"Delete workbench ($branch)? [y/N] "
                let confirm = (input | str trim | str downcase)
                if $confirm == "y" {
                    if (session-exists $sess_name) {
                        print $"Killing session: ($sess_name)"
                        stop $sess_name
                    }
                    let config = (load-repo-config $repo_name $wb_root)
                    let wt_path = (get-worktree-path $wb_root $repo_name $folder)
                    print $"Removing worktree: ($wt_path)"
                    remove-worktree $config.repo_root $wt_path false
                    print $"Deleted workbench: ($branch)"
                    sleep 500ms
                }
            }
            _ => {
                # Enter or empty = attach
                let config = (load-repo-config $repo_name $wb_root)
                let wt_path = (get-worktree-path $wb_root $repo_name $folder)
                let env_vars = (build-workbench-env $repo_name $folder $wt_path $branch $config.base_ref $config.agent)
                let layout_path = (layout-path-if-exists $config.layout)
                
                if not (session-exists $sess_name) {
                    start $sess_name $wt_path $layout_path $env_vars
                }
                
                touch-mru $sess_name
                print $"Attaching to ($branch)..."
                attach $sess_name
                print ""
            }
        }
    }
}

# Scan all initialized repos
def scan-all-repos [wb_root: string, debug: bool = false]: nothing -> list {
    if not ($wb_root | path exists) {
        return []
    }
    
    let repo_dirs = (ls $wb_root | where type == dir | get name)
    
    mut all_workbenches = []
    
    for repo_dir in $repo_dirs {
        let repo_name = ($repo_dir | path basename)
        let config_path = (get-repo-config-path $wb_root $repo_name)
        
        if ($config_path | path exists) {
            let repo_config = (load-repo-config $repo_name $wb_root)
            let repo_root = $repo_config.repo_root
            let workbenches = (list-workbenches $repo_root $wb_root $repo_name)
            
            let with_repo = ($workbenches | each {|wb|
                $wb | merge { repo_name: $repo_name, repo_root: $repo_root }
            })
            
            $all_workbenches = ($all_workbenches | append $with_repo)
        }
    }
    
    $all_workbenches
}
