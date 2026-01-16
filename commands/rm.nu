# workbench rm - Remove a workbench (worktree + optional branch)

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# Remove a workbench: kill session, remove worktree, optionally delete branch
export def main [
    branch: string         # Branch name to remove
    --delete-branch        # Also delete the local branch
    --force                # Force removal (skip safety checks)
    --yes (-y)             # Skip confirmation prompt
]: nothing -> nothing {
    assert-deps

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
    
    # Find workbench by branch
    let workbenches = (list-workbenches $repo_root $wb_root $repo_name)
    let wb_info = ($workbenches | where branch == $branch | first)
    
    if ($wb_info | is-empty) {
        error make --unspanned {
            msg: $"Workbench for branch '($branch)' not found"
        }
    }
    
    let folder = $wb_info.name
    let wt_path = $wb_info.path
    let sess_name = (session-name $branch)

    if not $yes {
        let confirm = (input $"Remove workbench '($branch)'? \(y/N\) ")
        if ($confirm | str downcase) != "y" {
            print "Aborted."
            return
        }
    }

    # Kill session if exists
    if (session-exists $sess_name) {
        print $"Killing session: ($sess_name)"
        stop $sess_name
    }

    # Remove worktree
    print $"Removing worktree: ($wt_path)"
    remove-worktree $repo_root $wt_path $force

    # Optionally delete branch
    if $delete_branch {
        if (branch-exists $repo_root $branch) {
            print $"Deleting branch: ($branch)"
            delete-branch $repo_root $branch $force
        } else {
            print $"Branch '($branch)' not found, skipping"
        }
    }

    print $"Workbench '($branch)' removed."
}
