# workbench doctor - detect and fix inconsistencies

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/worktrees.nu *
use ../lib/names.nu *
use ../lib/zellij.nu *

# Detect all issues for a repo
def detect-issues [repo_name: string, wb_root: string, repo_root: string]: nothing -> table<type: string, name: string, detail: string, fixable: bool> {
    mut issues = []
    
    let wt_base = ([$wb_root, $repo_name] | path join)
    
    # Get git worktrees
    let worktrees = (list-worktrees $repo_root)
    let wb_worktrees = ($worktrees | where path =~ $"^($wt_base)/" | each {|wt|
        let name = ($wt.path | str replace $"($wt_base)/" "")
        if ($name != ".workbench" and not ($name | str contains "/")) {
            { name: $name, path: $wt.path }
        } else {
            null
        }
    } | compact)
    
    # Get folders in wt_base
    let folders = if ($wt_base | path exists) {
        ls $wt_base 
        | where type == "dir" 
        | get name 
        | each { path basename }
        | where $it != ".workbench"
    } else {
        []
    }
    
    # Get zellij sessions for this repo (session format: repo_name_wb_name)
    let sessions = (list-sessions) | where $it =~ $"^($repo_name)_"
    
    # Check 1: Worktree in git but folder missing
    for wt in $wb_worktrees {
        if not ($wt.path | path exists) {
            $issues = ($issues | append {
                type: "missing_folder"
                name: $wt.name
                detail: $"Git worktree registered at ($wt.path) but folder missing"
                fixable: true
            })
        }
    }
    
    # Check 2: Folder exists but not in git worktrees
    let wt_names = ($wb_worktrees | get name)
    for folder in $folders {
        if not ($folder in $wt_names) {
            $issues = ($issues | append {
                type: "orphan_folder"
                name: $folder
                detail: $"Folder ($wt_base)/($folder) exists but not a git worktree"
                fixable: false
            })
        }
    }
    
    # Check 3: Session exists but folder missing
    for session in $sessions {
        let wb_name = ($session | str replace $"($repo_name)_" "")
        let expected_path = ([$wt_base, $wb_name] | path join)
        if not ($expected_path | path exists) {
            $issues = ($issues | append {
                type: "orphan_session"
                name: $wb_name
                detail: $"Session '($session)' exists but folder ($expected_path) missing"
                fixable: true
            })
        }
    }
    
    $issues
}

# Fix an issue
def fix-issue [issue: record, repo_name: string, wb_root: string, repo_root: string]: nothing -> record<success: bool, message: string> {
    match $issue.type {
        "missing_folder" => {
            prune-worktrees $repo_root
            { success: true, message: $"Pruned worktree ($issue.name)" }
        }
        "orphan_session" => {
            let session_name = (session-name $repo_name $issue.name)
            if (session-exists $session_name) {
                stop $session_name
            }
            { success: true, message: $"Killed orphan session ($session_name)" }
        }
        _ => {
            { success: false, message: $"Cannot auto-fix issue type: ($issue.type)" }
        }
    }
}

# Main doctor command
export def main [
    --fix       # Apply safe fixes automatically
    --json      # Output as JSON
]: nothing -> nothing {
    assert-deps
    
    let repo_root = (get-git-root)
    let repo_name = (repo-name $repo_root)
    let global_config = (load-global-config)
    let wb_root = (expand-path $global_config.workbench_root)
    
    if not (repo-initialized $repo_name $wb_root) {
        if $json {
            { error: "Repo not initialized", repo: $repo_name } | to json
            return
        }
        print $"(ansi red)Error:(ansi reset) Repo '($repo_name)' not initialized. Run `workbench init` first."
        return
    }
    
    let issues = (detect-issues $repo_name $wb_root $repo_root)
    
    if $json {
        if $fix {
            let results = ($issues | where fixable | each {|issue|
                let result = (fix-issue $issue $repo_name $wb_root $repo_root)
                $issue | merge $result
            })
            let unfixable = ($issues | where not fixable)
            { 
                fixed: $results, 
                unfixable: $unfixable,
                total_issues: ($issues | length),
                fixed_count: ($results | where success | length)
            } | to json -i 2
        } else {
            $issues | to json -i 2
        }
        return
    }
    
    if ($issues | is-empty) {
        print $"(ansi green)✓(ansi reset) No issues found for ($repo_name)"
        return
    }
    
    print $"Found ($issues | length) issue\(s) in ($repo_name):\n"
    
    for issue in $issues {
        let icon = match $issue.type {
            "missing_folder" => $"(ansi red)✗(ansi reset)"
            "orphan_folder" => $"(ansi yellow)⚠(ansi reset)"
            "orphan_session" => $"(ansi yellow)⚠(ansi reset)"
            _ => "?"
        }
        
        let fix_hint = if $issue.fixable { " (fixable)" } else { " (manual)" }
        print $"  ($icon) [($issue.type)] ($issue.name)($fix_hint)"
        print $"      ($issue.detail)"
        
        if $fix and $issue.fixable {
            let result = (fix-issue $issue $repo_name $wb_root $repo_root)
            if $result.success {
                print $"      (ansi green)→ Fixed:(ansi reset) ($result.message)"
            } else {
                print $"      (ansi red)→ Failed:(ansi reset) ($result.message)"
            }
        }
    }
    
    if not $fix {
        let fixable_count = ($issues | where fixable | length)
        if $fixable_count > 0 {
            print $"\nRun `workbench doctor --fix` to apply ($fixable_count) safe fix\(es)."
        }
    }
}
