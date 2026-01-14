# workbench create command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# Create a new workbench: worktree + branch + Zellij session
export def main [
    name: string                    # Workbench name (e.g., ABC-123)
    --from: string                  # Override base_ref
    --branch: string                # Explicit branch name
    --agent: string                 # Override agent
    --no-attach                     # Don't attach to session
    --no-session                    # Create worktree only, no zellij session
]: nothing -> nothing {
    assert-deps
    assert-valid-name $name

    let repo_root = (get-git-root)
    let repo_name = (repo-name $repo_root)

    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run `workbench init` first"
        }
    }

    let config = (load-repo-config $repo_name)
    let config = (apply-overrides $config {
        base_ref: $from
        agent: $agent
    })

    let wb_root = (expand-path $config.workbench_root)
    let wt_path = (get-worktree-path $wb_root $repo_name $name)
    let branch_name = if $branch != null { $branch } else { $name }
    let base_ref = $config.base_ref

    add-worktree $repo_root $wt_path $branch_name $base_ref
    print $"Created worktree at ($wt_path)"


    if $no_session {
        print $"Worktree created. To start session: workbench attach ($name)"
        return
    }

    let session_name = (session-name $repo_name $name)
    let layout_path = (layout-path-if-exists $config.layout)
    let env_vars = (build-workbench-env $repo_name $name $wt_path $branch_name $base_ref $config.agent)

    if $no_attach {
        start $session_name $wt_path $layout_path $env_vars
        print $"Session '($session_name)' started. Attach with: workbench attach ($name)"
    } else {
        let in_zellij = (in-zellij)
        let session_exists = (session-exists $session_name)
        if not $session_exists {
            start $session_name $wt_path $layout_path $env_vars
        }

        if $in_zellij {
            let plugin_path = ([(get-zellij-plugin-dir), "zellij-switch.wasm"] | path join)
            switch $session_name $wt_path $layout_path $plugin_path
        } else {
            attach $session_name
        }
    }
}
