# Attach to a workbench session; resurrect if needed

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *
use ../lib/mru.nu *

# Infer branch from CWD if inside a worktree
def infer-branch-from-cwd [wb_root: string, repo_name: string, workbenches: list]: nothing -> string {
    let wt_base = ([$wb_root, $repo_name] | path join)
    let cwd = (pwd)
    
    if ($cwd | str starts-with $wt_base) {
        let relative = ($cwd | str replace $"($wt_base)/" "")
        let parts = ($relative | split row "/")
        let folder = ($parts | first)
        if ($folder != ".workbench" and $folder != "") {
            # Find workbench by folder name and return its branch
            let wb = ($workbenches | where name == $folder | first)
            if ($wb | is-not-empty) {
                return $wb.branch
            }
        }
    }
    ""
}

# Attach to a workbench session
export def main [
    branch?: string  # Branch name (optional, inferred from CWD or interactive)
]: nothing -> nothing {
    assert-deps
    
    # Get repo context
    let git_root = (get-git-root)
    let repo_name = (repo-name $git_root)
    
    # Check if repo is initialized
    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run 'workbench init' first"
        }
    }
    
    # Load config
    let config = (load-repo-config $repo_name)
    let wb_root = (expand-path $config.workbench_root)
    
    # Get all workbenches for this repo
    let workbenches = (list-workbenches $git_root $wb_root $repo_name)
    
    # Resolve branch name
    let target_branch = if $branch != null {
        $branch
    } else {
        # Try to infer from CWD
        let inferred = (infer-branch-from-cwd $wb_root $repo_name $workbenches)
        if $inferred != "" {
            $inferred
        } else {
            # Open interactive list
            if ($workbenches | is-empty) {
                error make --unspanned {
                    msg: "No workbenches found"
                    help: "Create one with 'workbench create <branch>'"
                }
            }
            
            # Build fzf input - show branch as primary identifier
            let fzf_input = ($workbenches | each {|wb|
                let status = if (session-exists (session-name $wb.branch)) { "●" } else { "○" }
                $"($status) ($wb.branch)"
            } | str join "\n")
            
            # Run fzf
            if (which fzf | is-empty) {
                error make --unspanned {
                    msg: "fzf is required for interactive selection"
                    help: "Install fzf or provide branch: workbench attach <branch>"
                }
            }
            let result = (do { echo $fzf_input | fzf --ansi --prompt="Select workbench: " } | complete)
            if $result.exit_code != 0 {
                error make --unspanned { msg: "No workbench selected" }
            }
            
            # Parse selection (format: "● branch")
            let selected = ($result.stdout | str trim | split row " " | get 1)
            $selected
        }
    }
    
    # Find workbench info by branch
    let wb_info = ($workbenches | where branch == $target_branch | first)
    if ($wb_info | is-empty) {
        error make --unspanned {
            msg: $"No workbench found for branch: ($target_branch)"
            help: "Create one with 'workbench create ($target_branch)'"
        }
    }
    
    let folder = $wb_info.name
    let wt_path = $wb_info.path
    
    # Check if worktree folder exists
    if not ($wt_path | path exists) {
        error make --unspanned {
            msg: $"Worktree folder does not exist: ($wt_path)"
            help: "The worktree may have been removed. Check 'git worktree list'"
        }
    }
    
    # Build env vars for session resurrection
    let env_vars = (build-workbench-env $repo_name $folder $wt_path $target_branch $config.base_ref $config.agent)
    
    # Attach or resurrect
    let layout_path = (layout-path-if-exists $config.layout)
    let sess_name = (session-name $target_branch)
    let session_exists = (session-exists $sess_name)
    if not $session_exists {
        start $sess_name $wt_path $layout_path $env_vars
    }

    # Track MRU before attaching
    touch-mru $sess_name

    if (in-zellij) {
        error make --unspanned {
            msg: "Cannot attach from inside zellij"
            help: "Use 'workbench shell' from outside zellij, or detach first (Ctrl+O d)"
        }
    }
    
    attach $sess_name
}
