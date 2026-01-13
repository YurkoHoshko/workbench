# Zellij session management for workbench CLI

# zellij-switch plugin URL for switching sessions from inside zellij
const ZELLIJ_SWITCH_PLUGIN_URL = "https://github.com/mostafaqanbaryan/zellij-switch/releases/download/0.2.1/zellij-switch.wasm"

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

# Format session name for zellij (no slashes allowed)
export def session-name [repo_name: string, wb_name: string]: nothing -> string {
    $"($repo_name)_($wb_name)"
}

# List all zellij sessions
export def list-sessions []: nothing -> list<string> {
    let result = (do { zellij list-sessions -s } | complete)
    if $result.exit_code != 0 {
        return []
    }
    $result.stdout | lines | where $it != ""
}

# List workbench sessions for a repo, returning workbench names
export def list [repo_name: string]: nothing -> list<string> {
    let prefix = $"($repo_name)_"
    list-sessions
    | where $it =~ $"^($prefix)"
    | each { $in | str replace $"^($prefix)" "" }
}

# Check if a session exists
export def session-exists [repo_name: string, wb_name: string]: nothing -> bool {
    let session_name = (session-name $repo_name $wb_name)
    $session_name in (list-sessions)
}

# Start a new session (detached)
export def start [
    repo_name: string,
    wb_name: string,
    cwd: string,
    layout_path?: string,
    env_vars?: record
]: nothing -> string {
    let session = (session-name $repo_name $wb_name)
    if (session-exists $repo_name $wb_name) {
        return $wb_name
    }

    let cmd_args = (["--session" $session] | append (layout-args $layout_path))

    job spawn --tag $"zellij session ($session)" {
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
    $wb_name
}

# Attach to a session
export def attach [repo_name: string, wb_name: string]: nothing -> nothing {
    run-external "zellij" "attach" (session-name $repo_name $wb_name)
}

# Kill a session
export def stop [repo_name: string, wb_name: string]: nothing -> nothing {
    let session = (session-name $repo_name $wb_name)
    let result = (do { zellij kill-session $session } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: $"Failed to kill session: ($result.stderr)"
        }
    }
}

# Remove a session (alias for stop)
export def rm [repo_name: string, wb_name: string]: nothing -> nothing {
    stop $repo_name $wb_name
}

# Install zellij-switch plugin if missing
export def install-switch-plugin [plugins_dir: string]: nothing -> string {
    let plugin_path = ([$plugins_dir, "zellij-switch.wasm"] | path join)
    if not ($plugin_path | path exists) {
        mkdir $plugins_dir
        http get $ZELLIJ_SWITCH_PLUGIN_URL | save -f $plugin_path
    }
    $plugin_path
}

# Switch sessions using zellij-switch plugin
export def switch [
    repo_name: string,
    wb_name: string,
    cwd: string,
    layout_path?: string,
    plugin_path: string
]: nothing -> nothing {
    let session = (session-name $repo_name $wb_name)
    let layout_arg = if $layout_path != null { $"--layout ($layout_path)" } else { "" }
    let pipe_args = $"--session ($session) --cwd ($cwd) ($layout_arg)"
    ^zellij pipe --plugin $plugin_path -- $pipe_args
}
