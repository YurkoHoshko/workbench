# workbench report command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/zellij.nu *

# Generate workbench report (markdown/json)
export def main [
    --name: string       # Worktree name (infer from CWD if not provided)
    --format: string = "md"  # Output format: md|json
    --output: string     # Output file path (stdout if not provided)
] {
    assert-deps
    
    # Resolve worktree
    let resolved = (resolve-worktree $name)
    let repo_name = $resolved.repo_name
    let wb_name = $resolved.wb_name
    let wt_path = $resolved.wt_path
    let config = $resolved.config
    
    # Get branch info
    let workbenches = (list-workbenches $config.repo_root (expand-path $config.workbench_root) $repo_name)
    let wb_info = ($workbenches | where name == $wb_name | first)
    let branch = $wb_info.branch
    let base_ref = $config.base_ref
    
    # Git stats
    let diff_stats = (get-diff-stats $wt_path $branch $base_ref)
    let diffstat = (get-diffstat $wt_path $base_ref)
    let changed_files = (get-changed-files $wt_path $base_ref)
    
    # Session status
    let session_name = (format-session-name $repo_name $wb_name)
    let session_active = (session-exists $session_name)
    
    # Taskwarrior tasks (optional)
    let tasks = (get-taskwarrior-tasks $repo_name $wb_name)
    
    # Build report data
    let report = {
        repo_name: $repo_name
        worktree_name: $wb_name
        branch: $branch
        base_ref: $base_ref
        git: {
            ahead: $diff_stats.ahead
            behind: $diff_stats.behind
            diffstat: $diffstat
            changed_files: $changed_files
            changed_files_count: ($changed_files | length)
        }
        session: {
            name: $session_name
            active: $session_active
        }
        tasks: $tasks
    }
    
    # Format output
    let formatted = if $format == "json" {
        $report | to json -i 2
    } else {
        format-markdown $report
    }
    
    # Output
    if $output != null {
        $formatted | save -f $output
        print $"Report saved to ($output)"
    } else {
        $formatted
    }
}

# Resolve worktree by name or CWD
def resolve-worktree [name?: string]: nothing -> record<repo_name: string, wb_name: string, wt_path: string, config: record> {
    if $name != null {
        # Resolve by name - need to find which repo this belongs to
        let git_root = (get-git-root)
        let repo_name = (get-repo-name $git_root)
        let config = (load-repo-config $repo_name)
        let wb_root = (expand-path $config.workbench_root)
        let wt_path = (get-worktree-path $wb_root $repo_name $name)
        
        if not ($wt_path | path exists) {
            error make --unspanned {
                msg: $"Worktree '($name)' not found"
                help: "Use 'workbench list' to see available workbenches"
            }
        }
        
        { repo_name: $repo_name, wb_name: $name, wt_path: $wt_path, config: $config }
    } else {
        # Infer from CWD
        let cwd = (pwd)
        let git_root = (get-git-root)
        let repo_name = (get-repo-name $git_root)
        let config = (load-repo-config $repo_name)
        let wb_root = (expand-path $config.workbench_root)
        let wt_base = ([$wb_root, $repo_name] | path join)
        
        # Check if CWD is under a workbench
        if ($cwd | str starts-with $wt_base) {
            let relative = ($cwd | str replace $"($wt_base)/" "")
            let wb_name = ($relative | split row "/" | first)
            let wt_path = ([$wt_base, $wb_name] | path join)
            { repo_name: $repo_name, wb_name: $wb_name, wt_path: $wt_path, config: $config }
        } else {
            error make --unspanned {
                msg: "Could not determine workbench from current directory"
                help: "Use --name to specify the workbench, or run from within a workbench directory"
            }
        }
    }
}

# Get taskwarrior tasks for project (optional)
def get-taskwarrior-tasks [repo_name: string, wb_name: string]: nothing -> list<record<id: int, description: string, status: string>> {
    let deps = (check-deps)
    let has_task = ($deps | where name == "task" | first | get found)
    
    if not $has_task {
        return []
    }
    
    let project = $"($repo_name):($wb_name)"
    let result = (do { task project:($project) status:pending export } | complete)
    
    if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) {
        return []
    }
    
    try {
        $result.stdout | from json | each {|t|
            {
                id: ($t.id? | default 0)
                description: ($t.description? | default "")
                status: ($t.status? | default "pending")
            }
        }
    } catch {
        []
    }
}

# Format report as markdown
def format-markdown [report: record]: nothing -> string {
    let status_icon = if $report.session.active { "●" } else { "○" }
    let files_display = if ($report.git.changed_files_count > 10) {
        let shown = ($report.git.changed_files | take 10 | each { $"  - ($in)" } | str join "\n")
        $"($shown)\n  ... and ($report.git.changed_files_count - 10) more"
    } else if ($report.git.changed_files_count > 0) {
        $report.git.changed_files | each { $"  - ($in)" } | str join "\n"
    } else {
        "  (no changes)"
    }
    
    let tasks_display = if ($report.tasks | is-empty) {
        "  (none)"
    } else {
        $report.tasks | each {|t| $"  - [($t.id)] ($t.description)"} | str join "\n"
    }
    
    $"# ($report.repo_name) / ($report.worktree_name)

**Branch:** `($report.branch)`
**Base:** `($report.base_ref)`
**Session:** ($status_icon) \(($report.session.name)\)

## Git Stats

- Commits ahead: ($report.git.ahead)
- Commits behind: ($report.git.behind)

### Changed Files \(($report.git.changed_files_count)\)

($files_display)

### Diffstat

```
($report.git.diffstat)
```

## Tasks

($tasks_display)
"
}
