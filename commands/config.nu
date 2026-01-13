# workbench config - Open/edit workbench configuration

use ../lib/utils.nu *
use ../lib/config.nu *

# Open configuration in editor
export def main [
    --global (-g)  # Edit global config instead of repo config
    --show (-s)    # Print config instead of opening in editor
]: nothing -> nothing {
    let editor = ($env.EDITOR? | default "nano")
    
    if $global {
        let config_path = (get-global-config-path)
        
        # Ensure config exists with defaults
        if not ($config_path | path exists) {
            let defaults = (default-global-config)
            save-json-config $config_path $defaults
            print $"Created default global config at ($config_path)"
        }
        
        if $show {
            open $config_path
            return
        }
        
        print $"Opening ($config_path)..."
        ^$editor $config_path
    } else {
        # Need to be in a git repo or workbench
        let global_config = (load-global-config)
        let wb_root = (expand-path $global_config.workbench_root)
        
        # Try to infer repo from CWD
        let repo_name = (infer-repo-name $wb_root)
        
        if $repo_name == "" {
            error make --unspanned {
                msg: "Cannot determine repository"
                help: "Run from within a git repo, workbench folder, or use --global"
            }
        }
        
        let config_path = (get-repo-config-path $wb_root $repo_name)
        
        if not ($config_path | path exists) {
            error make --unspanned {
                msg: $"Repository '($repo_name)' is not initialized"
                help: "Run 'workbench init' first or use --global for global config"
            }
        }
        
        if $show {
            open $config_path
            return
        }
        
        print $"Opening ($config_path)..."
        ^$editor $config_path
    }
}

# Try to infer repo name from CWD (workbench folder or git repo)
def infer-repo-name [wb_root: string]: nothing -> string {
    let cwd = (pwd)
    
    # Check if inside workbench folder
    if ($cwd | str starts-with $wb_root) {
        let relative = ($cwd | str replace $"($wb_root)/" "")
        let parts = ($relative | split row "/")
        if ($parts | length) >= 1 {
            return ($parts | get 0)
        }
    }
    
    # Check if inside a git repo
    let result = (do { git rev-parse --show-toplevel } | complete)
    if $result.exit_code == 0 {
        return ($result.stdout | str trim | path basename)
    }
    
    ""
}
