# Attach to a workbench session; resurrect if needed

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/zellij.nu *

# Infer workbench name from CWD if inside a worktree
def infer-workbench-from-cwd [wb_root: string, repo_name: string]: nothing -> string {
    let wt_base = ([$wb_root, $repo_name] | path join)
    let cwd = (pwd)
    
    if ($cwd | str starts-with $wt_base) {
        let relative = ($cwd | str replace $"($wt_base)/" "")
        let parts = ($relative | split row "/")
        let name = ($parts | first)
        if ($name != ".workbench" and $name != "") {
            return $name
        }
    }
    ""
}

# Attach to a workbench session
export def main [
    name?: string  # Workbench name (optional, inferred from CWD or interactive)
]: nothing -> nothing {
    assert-deps
    
    # Get repo context
    let git_root = (get-git-root)
    let repo_name = (get-repo-name $git_root)
    
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
    
    # Resolve workbench name
    let wb_name = if $name != null {
        $name
    } else {
        # Try to infer from CWD
        let inferred = (infer-workbench-from-cwd $wb_root $repo_name)
        if $inferred != "" {
            $inferred
        } else {
            # Open interactive list
            let workbenches = (list-workbenches $git_root $wb_root $repo_name)
            if ($workbenches | is-empty) {
                error make --unspanned {
                    msg: "No workbenches found"
                    help: "Create one with 'workbench create <name>'"
                }
            }
            
            # Build fzf input
            let fzf_input = ($workbenches | each {|wb|
                let status = (get-session-status (format-session-name $repo_name $wb.name))
                $"($status) ($wb.name) ($wb.branch)"
            } | str join "\n")
            
            # Run fzf
            if (which fzf | is-empty) {
                error make --unspanned {
                    msg: "fzf is required for interactive selection"
                    help: "Install fzf or provide workbench name: workbench attach <name>"
                }
            }
            let result = (do { echo $fzf_input | fzf --ansi --prompt="Select workbench: " } | complete)
            if $result.exit_code != 0 {
                error make --unspanned { msg: "No workbench selected" }
            }
            
            # Parse selection (format: "● name branch")
            let selected = ($result.stdout | str trim | split row " " | get 1)
            $selected
        }
    }
    
    assert-valid-name $wb_name
    
    # Resolve worktree path
    let wt_path = (get-worktree-path $wb_root $repo_name $wb_name)
    
    # Check if worktree folder exists
    if not ($wt_path | path exists) {
        error make --unspanned {
            msg: $"Worktree folder does not exist: ($wt_path)"
            help: "The worktree may have been removed. Check 'git worktree list'"
        }
    }
    
    # Get session name
    let session_name = (format-session-name $repo_name $wb_name)
    
    # Get branch name for this worktree
    let workbenches = (list-workbenches $git_root $wb_root $repo_name)
    let wb_info = ($workbenches | where name == $wb_name | first)
    let branch = if ($wb_info | is-not-empty) { $wb_info.branch } else { "" }
    
    # Build env vars for session resurrection
    let env_vars = {
        WORKBENCH_REPO: $repo_name
        WORKBENCH_NAME: $wb_name
        WORKBENCH_PATH: $wt_path
        WORKBENCH_BRANCH: $branch
        WORKBENCH_BASE_REF: $config.base_ref
        WORKBENCH_AGENT: $config.agent
    }
    
    # Attach or resurrect
    let layouts_dir = (expand-path $config.layouts_dir)
    ensure-and-attach $session_name $wt_path $config.layout $layouts_dir $env_vars
}
