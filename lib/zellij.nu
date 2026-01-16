# Zellij session management for workbench CLI

def supports-new-session-with-layout []: nothing -> bool {
    let result = (do { zellij --help } | complete)
    if $result.exit_code != 0 {
        false
    } else {
        $result.stdout | str contains "--new-session-with-layout"
    }
}

def layout-args [layout_path?: string]: nothing -> list<string> {
    if $layout_path == null {
        []
    } else {
        let supports_layout = (supports-new-session-with-layout)
        let layout_flag = if $supports_layout { "--new-session-with-layout" } else { "--layout" }
        [$layout_flag $layout_path]
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

# Check if a session exists
export def session-exists [session_name: string]: nothing -> bool {
    $session_name in (list-sessions)
}

# Start a new session (detached)
export def start [
    session_name: string,
    cwd: string,
    layout_path?: string,
    env_vars?: record
]: nothing -> string {
    if (session-exists $session_name) {
        return $session_name
    }

    let cmd_args = (["--session" $session_name] | append (layout-args $layout_path))

    job spawn --tag $"zellij session ($session_name)" {
        if $env_vars != null {
            with-env $env_vars {
                cd $cwd
                ^zellij ...$cmd_args
            }
        } else {
            cd $cwd
            ^zellij ...$cmd_args
        }
    }

    # Give it a moment to start
    sleep 500ms
    $session_name
}

# Attach to a session
export def attach [session_name: string]: nothing -> nothing {
    ^zellij attach $session_name
}

# Kill a session
export def stop [session_name: string]: nothing -> nothing {
    let result = (do { zellij kill-session $session_name } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to kill session: ($result.stderr)"
        }
    }
}
