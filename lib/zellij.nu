# Zellij session management for workbench CLI

# Conventional name for workbench-specific layout
const LOCAL_LAYOUT_NAME = "workbench.kdl"

# Resolve layout path: prefer local workbench.kdl if exists, otherwise use configured layout
export def resolve-layout-path [cwd: string, layout: string, layouts_dir: string]: nothing -> string {
    let local_layout = ([$cwd, $LOCAL_LAYOUT_NAME] | path join)
    if ($local_layout | path exists) {
        $local_layout
    } else {
        [$layouts_dir, $layout] | path join
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
    
    # Build environment export commands
    let env_exports = ($env_vars | transpose k v | each {|e| $"export ($e.k)='($e.v)'"} | str join "; ")
    
    # Create a wrapper script to set env and start zellij
    let cmd = $"($env_exports); cd '($cwd)'; zellij --session '($session_name)' --layout '($layout_path)'"
    
    # Run detached
    let result = (do { bash -c $"($cmd) &" } | complete)
    
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
    
    if $in_zellij {
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
        if not (session-exists $session_name) {
            let layout_path = (resolve-layout-path $cwd $layout $layouts_dir)
            
            # Set environment variables
            $env_vars | transpose k v | each {|e| 
                load-env { ($e.k): ($e.v) }
            }
            
            let layout_arg = if ($layout_path | path exists) {
                ["--layout" $layout_path]
            } else {
                []
            }
            
            cd $cwd
            run-external "zellij" "attach" "-c" ...$layout_arg $session_name
        } else {
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
