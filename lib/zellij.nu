# Zellij session management for workbench CLI

use utils.nu [expand-path]

# Conventional name for workbench-specific layout
const LOCAL_LAYOUT_NAME = "workbench.kdl"

def debug-log [message: string]: nothing -> nothing {
    let enabled = ($env.WORKBENCH_DEBUG? | default "" | str length) > 0
    if $enabled {
        print $"[workbench][debug] ($message)"
    }
}

# Check if zellij supports --new-session-with-layout
def supports-new-session-with-layout []: nothing -> bool {
    let result = (do { zellij --help } | complete)
    if $result.exit_code != 0 {
        false
    } else {
        $result.stdout | str contains "--new-session-with-layout"
    }
}

# Resolve layout path: prefer local workbench.kdl if exists, otherwise use configured layout
export def resolve-layout-path [cwd: string, layout: string, layouts_dir: string]: nothing -> string {
    let local_layout = ([$cwd, $LOCAL_LAYOUT_NAME] | path join)
    if ($local_layout | path exists) {
        debug-log $"Using local layout: ($local_layout)"
        $local_layout
    } else {
        let layout_is_path = ($layout | str starts-with "~") or ($layout | str starts-with "/") or ($layout | str contains "/")
        let expanded_layouts_dir = (expand-path $layouts_dir)
        let resolved = if $layout_is_path {
            expand-path $layout
        } else {
            [$expanded_layouts_dir, $layout] | path join
        }
        debug-log $"Using configured layout: ($resolved)"
        $resolved
    }
}

# List all zellij sessions
export def list-sessions []: nothing -> list<string> {
    let result = (do { zellij list-sessions -s } | complete)
    if $result.exit_code != 0 {
        return []
    }
    $result.stdout | lines | where $it != ""
}

# Check if session exists
export def session-exists [session_name: string]: nothing -> bool {
    let sessions = (list-sessions)
    $session_name in $sessions
}

# Start a new session (detached)
export def start-session [
    session_name: string,
    cwd: string,
    layout: string,
    layouts_dir: string,
    env_vars: record
]: nothing -> nothing {
    let layout_path = (resolve-layout-path $cwd $layout $layouts_dir)
    let layout_exists = ($layout_path | path exists)
    debug-log $"Starting session '($session_name)' in ($cwd)"
    debug-log $"Resolved layout path: ($layout_path) exists=($layout_exists)"

    if not $layout_exists {
        debug-log "Layout file missing; starting without layout"
    }

    let layout_args = if $layout_exists {
        let supports_layout = (supports-new-session-with-layout)
        let layout_flag = if $supports_layout { "--new-session-with-layout" } else { "--layout" }
        if not $supports_layout {
            debug-log "zellij lacks --new-session-with-layout; using --layout"
        }
        [$layout_flag $layout_path]
    } else {
        []
    }
    let cmd_args = (["--session" $session_name] | append $layout_args)

    job spawn --tag $"zellij session ($session_name)" {
        with-env $env_vars {
            cd $cwd
            ^zellij ...$cmd_args
        }
    }

    # Give it a moment to start
    sleep 500ms
}

# Attach to a session
export def attach-session [session_name: string]: nothing -> nothing {
    run-external "zellij" "attach" $session_name
}

# Kill a session
export def kill-session [session_name: string]: nothing -> nothing {
    let result = (do { zellij kill-session $session_name } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to kill session: ($result.stderr)"
        }
    }
}

# zellij-switch plugin URL for switching sessions from inside zellij
const ZELLIJ_SWITCH_PLUGIN = "https://github.com/mostafaqanbaryan/zellij-switch/releases/download/0.2.1/zellij-switch.wasm"

# Start session if not exists, then attach
export def ensure-and-attach [
    session_name: string,
    cwd: string,
    layout: string,
    layouts_dir: string,
    env_vars: record
]: nothing -> nothing {
    # Check if we're inside a zellij session
    let in_zellij = ($env.ZELLIJ? | default "" | str length) > 0
    debug-log $"ensure-and-attach in_zellij=($in_zellij) session=($session_name)"
    
    if $in_zellij {
        let exists = (session-exists $session_name)
        debug-log $"Session exists: ($exists)"
        if not $exists {
            debug-log "Session missing; starting detached"
            start-session $session_name $cwd $layout $layouts_dir $env_vars
        }

        # Use zellij-switch plugin to switch sessions from inside zellij
        let layout_path = (resolve-layout-path $cwd $layout $layouts_dir)
        let layout_arg = if ($layout_path | path exists) {
            $"--layout ($layout_path)"
        } else {
            ""
        }
        let pipe_args = $"--session ($session_name) --cwd ($cwd) ($layout_arg)"

        # Use zellij pipe to invoke zellij-switch plugin
        ^zellij pipe --plugin $ZELLIJ_SWITCH_PLUGIN -- $pipe_args
    } else {
        let exists = (session-exists $session_name)
        debug-log $"Session exists: ($exists)"
        if not $exists {
            let layout_path = (resolve-layout-path $cwd $layout $layouts_dir)
            debug-log $"Resolved layout path: ($layout_path) exists=($layout_path | path exists)"
            
            # Set environment variables
            $env_vars | transpose k v | each {|e| 
                load-env { ($e.k): ($e.v) }
            }
            
            let layout_arg = if ($layout_path | path exists) {
                let supports_layout = (supports-new-session-with-layout)
                let layout_flag = if $supports_layout { "--new-session-with-layout" } else { "--layout" }
                if not $supports_layout {
                    debug-log "zellij lacks --new-session-with-layout; using --layout"
                }
                [$layout_flag $layout_path]
            } else {
                []
            }

            cd $cwd
            run-external "zellij" "--session" $session_name ...$layout_arg
        } else {
            debug-log "Attaching to existing session"
            attach-session $session_name
        }
    }
}

# Get session status for display
export def get-session-status [session_name: string]: nothing -> string {
    if (session-exists $session_name) { "●" } else { "○" }
}

# Kill session if exists (no error if not)
export def kill-session-if-exists [session_name: string]: nothing -> nothing {
    if (session-exists $session_name) {
        kill-session $session_name
    }
}
