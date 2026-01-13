# workbench status - Show current workbench status

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/zellij.nu *

# Infer workbench context from CWD
def get-workbench-context []: nothing -> record {
    let global_config = (load-global-config)
    let wb_root = (expand-path $global_config.workbench_root)
    let cwd = (pwd)
    
    # Check if we're inside a workbench folder
    if not ($cwd | str starts-with $wb_root) {
        return { found: false }
    }
    
    let relative = ($cwd | str replace $"($wb_root)/" "")
    let parts = ($relative | split row "/")
    
    if ($parts | length) < 2 {
        return { found: false }
    }
    
    let repo_name = ($parts | get 0)
    let wb_name = ($parts | get 1)
    
    if $wb_name == ".workbench" {
        return { found: false }
    }
    
    let config_path = (get-repo-config-path $wb_root $repo_name)
    if not ($config_path | path exists) {
        return { found: false }
    }
    
    let config = (load-repo-config $repo_name $wb_root)
    let wt_path = (get-worktree-path $wb_root $repo_name $wb_name)
    
    {
        found: true
        repo_name: $repo_name
        wb_name: $wb_name
        wt_path: $wt_path
        config: $config
        wb_root: $wb_root
    }
}

# Get git status summary
def get-git-status [wt_path: string]: nothing -> record {
    let status = (do { git -C $wt_path status --porcelain } | complete)
    if $status.exit_code != 0 {
        return { staged: 0, modified: 0, untracked: 0 }
    }
    
    let lines = ($status.stdout | lines | where $it != "")
    let staged = ($lines | where { $in | str starts-with "A " or $in | str starts-with "M " or $in | str starts-with "D " or $in | str starts-with "R " } | length)
    let modified = ($lines | where { $in | str substring 1..2 == "M" or $in | str substring 1..2 == "D" } | length)
    let untracked = ($lines | where { $in | str starts-with "??" } | length)
    
    { staged: $staged, modified: $modified, untracked: $untracked }
}

# Get current branch
def get-current-branch [wt_path: string]: nothing -> string {
    let result = (do { git -C $wt_path branch --show-current } | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim
    } else {
        "detached"
    }
}

# Get last commit info
def get-last-commit [wt_path: string]: nothing -> record {
    let result = (do { git -C $wt_path log -1 --format="%h|%s|%ar" } | complete)
    if $result.exit_code != 0 {
        return { hash: "", message: "", ago: "" }
    }
    
    let parts = ($result.stdout | str trim | split row "|")
    {
        hash: ($parts | get 0)
        message: ($parts | get 1? | default "")
        ago: ($parts | get 2? | default "")
    }
}

# Show workbench status
export def main [
    --json (-j)  # Output as JSON
]: nothing -> nothing {
    let ctx = (get-workbench-context)
    
    if not $ctx.found {
        error make --unspanned {
            msg: "Not inside a workbench"
            help: "Run this command from within a workbench folder"
        }
    }
    
    let repo_name = $ctx.repo_name
    let wb_name = $ctx.wb_name
    let wt_path = $ctx.wt_path
    let config = $ctx.config
    
    let branch = (get-current-branch $wt_path)
    let diff_stats = (get-diff-stats $wt_path $branch $config.base_ref)
    let git_status = (get-git-status $wt_path)
    let last_commit = (get-last-commit $wt_path)
    let session_name = (format-session-name $repo_name $wb_name)
    let session_active = if (which zellij | is-not-empty) {
        session-exists $session_name
    } else {
        false
    }
    
    let status = {
        repo: $repo_name
        workbench: $wb_name
        path: $wt_path
        branch: $branch
        base_ref: $config.base_ref
        ahead: $diff_stats.ahead
        behind: $diff_stats.behind
        staged: $git_status.staged
        modified: $git_status.modified
        untracked: $git_status.untracked
        last_commit: $last_commit
        session: $session_name
        session_active: $session_active
    }
    
    if $json {
        $status | to json -i 2
        return
    }
    
    # Pretty output
    let session_icon = if $session_active { "●" } else { "○" }
    
    print $"(ansi cyan)($repo_name)(ansi reset)/(ansi green)($wb_name)(ansi reset)"
    print $"  Branch: (ansi yellow)($branch)(ansi reset)"
    print $"  Base:   ($config.base_ref)"
    
    if $diff_stats.ahead > 0 or $diff_stats.behind > 0 {
        let ahead_str = if $diff_stats.ahead > 0 { $"(ansi green)↑($diff_stats.ahead)(ansi reset)" } else { "" }
        let behind_str = if $diff_stats.behind > 0 { $"(ansi red)↓($diff_stats.behind)(ansi reset)" } else { "" }
        print $"  Diff:   ($ahead_str) ($behind_str)"
    }
    
    if $git_status.staged > 0 or $git_status.modified > 0 or $git_status.untracked > 0 {
        mut parts = []
        if $git_status.staged > 0 { $parts = ($parts | append $"(ansi green)+($git_status.staged) staged(ansi reset)") }
        if $git_status.modified > 0 { $parts = ($parts | append $"(ansi yellow)~($git_status.modified) modified(ansi reset)") }
        if $git_status.untracked > 0 { $parts = ($parts | append $"(ansi red)?($git_status.untracked) untracked(ansi reset)") }
        print $"  Files:  ($parts | str join ', ')"
    } else {
        print $"  Files:  (ansi grey)clean(ansi reset)"
    }
    
    if $last_commit.hash != "" {
        print $"  Commit: (ansi grey)($last_commit.hash)(ansi reset) ($last_commit.message) (ansi grey)\(($last_commit.ago)\)(ansi reset)"
    }
    
    print $"  Session: ($session_icon) ($session_name)"
}
