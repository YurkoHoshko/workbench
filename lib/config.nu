# Configuration management for workbench CLI

use utils.nu [expand-path, get-global-config-path, get-repo-config-path]

# Default global config
export def default-global-config []: nothing -> record {
    {
        workbench_root: "~/.workbench"
        agent: "opencode"
        layout: "default.kdl"
    }
}

# Default repo config (partial, merged with global)
export def default-repo-config []: nothing -> record {
    {
        base_ref: "origin/main"
    }
}

# Load JSON config file, return empty record if not exists
export def load-json-config [path: string]: nothing -> record {
    let expanded = (expand-path $path)
    if ($expanded | path exists) {
        open $expanded
    } else {
        {}
    }
}

# Save config to JSON file (creates parent dirs)
export def save-json-config [path: string, config: record]: nothing -> nothing {
    let expanded = (expand-path $path)
    let parent = ($expanded | path dirname)
    mkdir $parent
    $config | to json -i 2 | save -f $expanded
}

# Load global config with defaults
export def load-global-config []: nothing -> record {
    let defaults = (default-global-config)
    let user_config = (load-json-config (get-global-config-path))
    $defaults | merge $user_config
}

# Load repo config (requires repo_name, merges with global)
export def load-repo-config [repo_name: string, wb_root?: string]: nothing -> record {
    let global = (load-global-config)
    let root = if $wb_root != null { $wb_root } else { expand-path $global.workbench_root }
    let repo_path = (get-repo-config-path $root $repo_name)
    let repo_config = (load-json-config $repo_path)
    let defaults = (default-repo-config)
    
    # Merge: defaults < global < repo
    $defaults | merge $global | merge $repo_config
}

# Check if repo is initialized
export def repo-initialized [repo_name: string, wb_root?: string]: nothing -> bool {
    let global = (load-global-config)
    let root = if $wb_root != null { $wb_root } else { expand-path $global.workbench_root }
    let config_path = (get-repo-config-path $root $repo_name)
    $config_path | path exists
}

# Save repo config
export def save-repo-config [repo_name: string, config: record, wb_root?: string]: nothing -> nothing {
    let global = (load-global-config)
    let root = if $wb_root != null { $wb_root } else { expand-path $global.workbench_root }
    let config_path = (get-repo-config-path $root $repo_name)
    save-json-config $config_path $config
}

# Merge config with flag overrides
export def apply-overrides [config: record, overrides: record]: nothing -> record {
    # Filter out null values from overrides
    let filtered = ($overrides | transpose k v | where {|r| $r.v != null})
    if ($filtered | is-empty) {
        $config
    } else {
        let valid_overrides = ($filtered | transpose -r -d)
        $config | merge $valid_overrides
    }
}

# List available layouts from the default zellij layouts directory
export def list-layouts []: nothing -> list<string> {
    let expanded = (expand-path "~/.config/zellij/layouts")
    if ($expanded | path exists) {
        ls $expanded | where name =~ '\.kdl$' | get name | each { path basename }
    } else {
        []
    }
}

# Resolve a layout path from name or explicit path
export def resolve-layout-path [layout: string]: nothing -> string {
    let layout_is_path = ($layout | str starts-with "~") or ($layout | str starts-with "/") or ($layout | str contains "/")
    let expanded_layouts_dir = (expand-path "~/.config/zellij/layouts")
    if $layout_is_path {
        expand-path $layout
    } else {
        [$expanded_layouts_dir, $layout] | path join
    }
}

# Resolve layout path only if it exists
export def layout-path-if-exists [layout: string]: nothing -> string {
    let resolved = (resolve-layout-path $layout)
    if ($resolved | path exists) {
        $resolved
    } else {
        null
    }
}
