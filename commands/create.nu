# workbench create command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# Create a new workbench: worktree + branch + Zellij session
# Branch name is the primary identifier for everything
export def main [
    branch: string                  # Branch name (e.g., feature/ABC-123 or ABC-123)
    --from: string                  # Override base_ref
    --agent: string                 # Override agent
    --no-attach                     # Don't attach to session
    --no-session                    # Create worktree only, no zellij session
]: nothing -> nothing {
    assert-deps

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
    let folder = (folder-name $branch)
    let wt_path = (get-worktree-path $wb_root $repo_name $folder)
    let base_ref = $config.base_ref

    add-worktree $repo_root $wt_path $branch $base_ref
    print $"Created worktree at ($wt_path)"

    if $no_session {
        print $"Worktree created. To start session: workbench attach ($branch)"
        return
    }

    let sess_name = (session-name $branch)
    let layout_path = (layout-path-if-exists $config.layout)
    let env_vars = (build-workbench-env $repo_name $folder $wt_path $branch $base_ref $config.agent)

    if $no_attach {
        start $sess_name $wt_path $layout_path $env_vars
        print $"Session '($sess_name)' started. Attach with: workbench attach ($branch)"
    } else {
        let in_zellij = (in-zellij)
        let session_exists = (session-exists $sess_name)
        if not $session_exists {
            start $sess_name $wt_path $layout_path $env_vars
        }

        if $in_zellij {
            error make --unspanned {
                msg: "Cannot attach from inside zellij"
                help: "Use 'workbench shell' from outside zellij, or detach first (Ctrl+O d)"
            }
        }
        
        attach $sess_name
    }
}
