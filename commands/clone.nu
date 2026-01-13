# workbench clone - Clone a repo and initialize workbench

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/git.nu *
use ../lib/worktrees.nu *

# Clone a repository and initialize workbench for it
export def main [
    url: string              # Git repository URL to clone
    --name: string           # Override repo name (default: derived from URL)
    --layout: string         # Layout file to use
    --agent: string          # Agent to use
    --base-ref: string       # Base ref (default: origin/main or origin/master)
    --workbench: string      # Create initial workbench with this name
]: nothing -> nothing {
    assert-deps
    
    # Derive repo name from URL if not provided
    let repo_name = if $name != null {
        $name
    } else {
        # Extract repo name from URL (handles .git suffix)
        $url | path basename | str replace '.git' ''
    }
    
    assert-valid-name $repo_name
    
    let global_config = (load-global-config)
    let wb_root = (expand-path $global_config.workbench_root)
    
    let repo_dir = ([$wb_root, $repo_name] | path join)
    let clone_path = ([$repo_dir, "main"] | path join)
    
    # Check if already exists
    if ($clone_path | path exists) {
        error make --unspanned {
            msg: $"Workbench already exists at ($clone_path)"
            help: "Use `workbench attach` to connect to existing workbench"
        }
    }
    
    # Create workbench directory structure
    let workbench_dir = ([$repo_dir, ".workbench"] | path join)
    mkdir $workbench_dir
    
    print $"Cloning ($url) to ($clone_path)..."
    
    # Clone the repository
    let clone_result = (do { git clone $url $clone_path } | complete)
    if $clone_result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to clone repository: ($clone_result.stderr)"
        }
    }
    
    print "Repository cloned successfully"
    
    # Detect default branch
    let detected_base_ref = if $base_ref != null {
        $base_ref
    } else {
        detect-default-branch $clone_path
    }
    
    # Determine layout
    let layouts_dir = $global_config.layouts_dir
    let selected_layout = if $layout != null { $layout } else { $global_config.layout }
    
    # Save repo config
    let repo_config = {
        repo_root: $clone_path
        base_ref: $detected_base_ref
        layout: $selected_layout
        layouts_dir: $layouts_dir
        agent: (if $agent != null { $agent } else { $global_config.agent })
        branch_prefix: "wb/"
    }
    
    save-repo-config $repo_name $repo_config $wb_root
    print $"Saved repo config (base_ref: ($detected_base_ref))"
    
    
    print $"Workbench initialized for ($repo_name)"
    print $"Main worktree: ($clone_path)"
    
    # Create initial workbench if requested
    if $workbench != null {
        print $"Creating workbench '($workbench)'..."
        
        let wb_path = ([$repo_dir, $workbench] | path join)
        let branch = $"($repo_config.branch_prefix)($workbench)"
        
        add-worktree $clone_path $wb_path $branch $detected_base_ref
        
        
        print $"Created workbench: ($workbench)"
        print $"To attach: workbench attach ($workbench)"
    }
    
    print ""
    print "Next steps:"
    print $"  cd ($clone_path)"
    print "  workbench create <name>  # Create a feature workbench"
}
