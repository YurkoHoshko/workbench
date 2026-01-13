# workbench dashboard command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/zellij.nu *

# Start/attach dashboard session for repo
export def main [
    --layout: string  # Override dashboard layout
]: nothing -> nothing {
    assert-deps

    let repo_root = (get-git-root)
    let repo_name = (get-repo-name $repo_root)

    if not (repo-initialized $repo_name) {
        error make --unspanned {
            msg: $"Repository '($repo_name)' not initialized"
            help: "Run 'workbench init' first"
        }
    }

    let config = (load-repo-config $repo_name)
    let layouts_dir = (expand-path $config.layouts_dir)

    # Determine layout: flag > dashboard_layout config > fallback to dashboard.kdl
    let dashboard_layout = if $layout != null {
        $layout
    } else if ("dashboard_layout" in $config) and ($config.dashboard_layout != null) {
        $config.dashboard_layout
    } else {
        "dashboard.kdl"
    }

    let session_name = (format-session-name $repo_name "dashboard")
    let wb_root = (expand-path $config.workbench_root)
    let cwd = [$wb_root, $repo_name] | path join

    let env_vars = {
        WORKBENCH_REPO: $repo_name
        WORKBENCH_NAME: "dashboard"
        WORKBENCH_PATH: $cwd
    }

    ensure-and-attach $session_name $cwd $dashboard_layout $layouts_dir $env_vars
}
