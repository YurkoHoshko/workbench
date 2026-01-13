# workbench review - Create a review workbench for a branch

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/worktrees.nu *
use ../lib/zellij.nu *

# Create a review workbench for inspecting a branch
export def main [
    branch?: string           # Branch to review (default: current branch)
]: nothing -> nothing {
    assert-deps
    
    let repo_root = (get-git-root)
    let repo_name = (get-repo-name $repo_root)
    
    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run `workbench init` first"
        }
    }
    
    let config = (load-repo-config $repo_name)
    let wb_root = (expand-path $config.workbench_root)
    
    # Determine branch to review
    let review_branch = if $branch != null {
        $branch
    } else {
        # Get current branch
        let result = (do { git -C $repo_root branch --show-current } | complete)
        if $result.exit_code != 0 or ($result.stdout | str trim) == "" {
            error make --unspanned {
                msg: "Cannot determine current branch"
                help: "Provide a branch name: workbench review <branch>"
            }
        }
        $result.stdout | str trim
    }
    
    # Validate branch exists
    if not (branch-exists $repo_root $review_branch) {
        # Try with remote prefix
        let remote_branch = $"origin/($review_branch)"
        let result = (do { git -C $repo_root rev-parse --verify $remote_branch } | complete)
        if $result.exit_code != 0 {
            error make --unspanned {
                msg: $"Branch '($review_branch)' not found"
                help: "Check branch name or fetch from remote first"
            }
        }
    }
    
    # Create review workbench name: review/{branch-name}
    # Sanitize branch name for workbench name (replace / with -)
    let sanitized = ($review_branch | str replace --all "/" "-")
    let wb_name = $"review-($sanitized)"
    
    # Validate name
    assert-valid-name $wb_name
    
    let wt_path = (get-worktree-path $wb_root $repo_name $wb_name)
    
    # Check if already exists
    if ($wt_path | path exists) {
        print $"Review workbench already exists, attaching..."
        let env_vars = (build-workbench-env $repo_name $wb_name $wt_path $review_branch $config.base_ref $config.agent { WORKBENCH_REVIEW: "true" })
        let layout_path = (layout-path-if-exists "review.kdl" $config.layouts_dir)
        if not (session-exists $repo_name $wb_name) {
            start $repo_name $wb_name $wt_path $layout_path $env_vars
        }

        if (in-zellij) {
            let plugin_path = (install-switch-plugin (get-zellij-plugin-dir))
            switch $repo_name $wb_name $wt_path $layout_path $plugin_path
        } else {
            attach $repo_name $wb_name
        }
        return
    }
    
    # Create worktree for existing branch (no new branch)
    add-worktree-existing $repo_root $wt_path $review_branch
    print $"Created review worktree at ($wt_path)"
    
    let env_vars = (build-workbench-env $repo_name $wb_name $wt_path $review_branch $config.base_ref $config.agent { WORKBENCH_REVIEW: "true" })
    let layout_path = (layout-path-if-exists "review.kdl" $config.layouts_dir)
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
