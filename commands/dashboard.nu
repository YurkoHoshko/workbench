# workbench dashboard command

use ../lib/utils.nu *
use ../lib/config.nu *
use ../lib/zellij.nu *

# Start/attach dashboard session for repo
export def main []: nothing -> nothing {
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

    # Determine layout: dashboard_layout config > fallback to dashboard.kdl
    let dashboard_layout = if ("dashboard_layout" in $config) and ($config.dashboard_layout != null) {
        $config.dashboard_layout
    } else {
        "dashboard.kdl"
    }

    let wb_root = (expand-path $config.workbench_root)
    let cwd = [$wb_root, $repo_name] | path join

    let env_vars = (build-workbench-env $repo_name "dashboard" $cwd "" $config.base_ref $config.agent)
    let layout_path = (layout-path-if-exists $dashboard_layout $config.layouts_dir)

    if not (session-exists $repo_name "dashboard") {
        start $repo_name "dashboard" $cwd $layout_path $env_vars
    }

    if (in-zellij) {
        let plugin_path = (install-switch-plugin (get-zellij-plugin-dir))
        switch $repo_name "dashboard" $cwd $layout_path $plugin_path
    } else {
        attach $repo_name "dashboard"
    }
}
