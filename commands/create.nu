# workbench create command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/zellij.nu *

# Create a new workbench: worktree + branch + Zellij session
export def main [
    name: string                    # Workbench name (e.g., ABC-123)
    --from: string                  # Override base_ref
    --branch: string                # Explicit branch name (overrides prefix + name)
    --layout: string                # Override layout
    --agent: string                 # Override agent
    --no-attach                     # Don't attach to session
    --no-session                    # Create worktree only, no zellij session
]: nothing -> nothing {
    assert-deps
    assert-valid-name $name

    let repo_root = (get-git-root)
    let repo_name = (get-repo-name $repo_root)

    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run `workbench init` first"
        }
    }

    let config = (load-repo-config $repo_name)
    let config = (apply-overrides $config {
        base_ref: $from
        layout: $layout
        agent: $agent
    })

    let wb_root = (expand-path $config.workbench_root)
    let wt_path = (get-worktree-path $wb_root $repo_name $name)
    let branch_name = if $branch != null { $branch } else { format-branch-name $config.branch_prefix $name }
    let base_ref = $config.base_ref

    add-worktree $repo_root $wt_path $branch_name $base_ref
    print $"Created worktree at ($wt_path)"

    if (which mise | is-not-empty) {
        let result = (do { mise trust $wt_path } | complete)
        if $result.exit_code == 0 {
            print "Ran mise trust"
        }
    }

    if $no_session {
        print $"Worktree created. To start session: workbench attach ($name)"
        return
    }

    let session_name = (format-session-name $repo_name $name)
    let layouts_dir = (expand-path $config.layouts_dir)
    let env_vars = {
        WORKBENCH_REPO: $repo_name
        WORKBENCH_NAME: $name
        WORKBENCH_PATH: $wt_path
        WORKBENCH_BRANCH: $branch_name
        WORKBENCH_BASE_REF: $base_ref
        WORKBENCH_AGENT: $config.agent
    }

    if $no_attach {
        start-session $session_name $wt_path $config.layout $layouts_dir $env_vars
        print $"Session '($session_name)' started. Attach with: workbench attach ($name)"
    } else {
        ensure-and-attach $session_name $wt_path $config.layout $layouts_dir $env_vars
    }
}
