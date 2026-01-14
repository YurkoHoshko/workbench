# workbench rm - Remove a workbench (worktree + optional branch)

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# Remove a workbench: kill session, remove worktree, optionally delete branch
export def main [
    name: string           # Workbench name to remove
    --branch               # Also delete the local branch
    --force                # Force removal (skip safety checks)
    --yes (-y)             # Skip confirmation prompt
]: nothing -> nothing {
    assert-deps
    assert-valid-name $name

    let repo_root = (get-git-root)
    let repo_name = (repo-name $repo_root)

    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' is not initialized"
            help: "Run 'workbench init' first"
        }
    }

    let config = (load-repo-config $repo_name)
    let wb_root = (expand-path $config.workbench_root)
    let wt_path = (get-worktree-path $wb_root $repo_name $name)
    let session_name = (session-name $repo_name $name)

    if not ($wt_path | path exists) {
        error make --unspanned {
            msg: $"Workbench '($name)' not found at ($wt_path)"
        }
    }

    if not $yes {
        let confirm = (input $"Remove workbench '($name)'? \(y/N\) ")
        if ($confirm | str downcase) != "y" {
            print "Aborted."
            return
        }
    }

    # Kill session if exists
    if (session-exists $session_name) {
        print $"Killing session: ($session_name)"
        stop $session_name
    }

    # Remove worktree
    print $"Removing worktree: ($wt_path)"
    remove-worktree $repo_root $wt_path $force

    # Optionally delete branch
    if $branch {
        let branch_name = (branch-name $config.branch_prefix $name)
        if (branch-exists $repo_root $branch_name) {
            print $"Deleting branch: ($branch_name)"
            delete-branch $repo_root $branch_name $force
        } else {
            print $"Branch '($branch_name)' not found, skipping"
        }
    }

    print $"Workbench '($name)' removed."
}
