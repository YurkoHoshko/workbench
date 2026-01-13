# workbench init command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/worktrees.nu *

# Initialize workbench for current git repository
export def main [
    --layout: string        # Layout file to use
    --agent: string         # Agent to use (e.g., opencode)
    --layouts-dir: string   # Directory containing layout files
    --base-ref: string      # Base ref for main worktree (default: origin/main)
]: nothing -> nothing {
    assert-deps

    let repo_root = (get-git-root)
    let repo_name = (get-repo-name $repo_root)

    let global_config = (load-global-config)
    let wb_root = (expand-path $global_config.workbench_root)

    let repo_dir = ([$wb_root, $repo_name] | path join)
    let workbench_dir = ([$repo_dir, ".workbench"] | path join)
    mkdir $workbench_dir

    let layouts_dir_resolved = if $layouts_dir != null { $layouts_dir } else { $global_config.layouts_dir }

    let selected_layout = if $layout != null {
        $layout
    } else {
        let layouts = (list-layouts $layouts_dir_resolved)
        if ($layouts | is-empty) {
            print $"No layouts found in ($layouts_dir_resolved), using default"
            $global_config.layout
        } else {
            print "Available layouts:"
            $layouts | enumerate | each {|it| print $"  ($it.index + 1). ($it.item)" }
            let choice = (input "Select layout (number or name): " | str trim)
            if ($choice | str length) == 0 {
                $global_config.layout
            } else if ($choice =~ '^\d+$') {
                let idx = (($choice | into int) - 1)
                if $idx >= 0 and $idx < ($layouts | length) {
                    $layouts | get $idx
                } else {
                    print "Invalid selection, using default"
                    $global_config.layout
                }
            } else if ($choice in $layouts) {
                $choice
            } else {
                print "Layout not found, using default"
                $global_config.layout
            }
        }
    }

    # Auto-detect default branch if not specified
    let detected_base_ref = if $base_ref != null {
        $base_ref
    } else {
        detect-default-branch $repo_root
    }

    let repo_config = {
        repo_root: $repo_root
        base_ref: $detected_base_ref
        layout: $selected_layout
        layouts_dir: $layouts_dir_resolved
        agent: (if $agent != null { $agent } else { $global_config.agent })
    }
    
    print $"Using base ref: ($detected_base_ref)"

    save-repo-config $repo_name $repo_config $wb_root
    print $"Saved repo config to ($workbench_dir)/config.json"

    let main_path = ([$repo_dir, "main"] | path join)
    if not ($main_path | path exists) {
        print $"Creating main worktree at ($main_path)..."
        # Use detached mode to avoid conflicts with checked-out branches
        add-worktree-detached $repo_root $main_path $repo_config.base_ref
        print "Main worktree created"
    } else {
        print "Main worktree already exists"
    }


    print $"Workbench initialized for ($repo_name)"
}
