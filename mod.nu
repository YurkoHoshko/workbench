# workbench - Zellij + Git Worktree Workbench Manager
#
# Usage:
#   use /path/to/workbench/mod.nu *
#   workbench              # interactive shell (default)
#   workbench init
#   workbench create feature/ABC-123
#   workbench list
#   workbench attach feature/ABC-123
#   workbench rm feature/ABC-123
#   workbench doctor

use lib/utils.nu *
use lib/config.nu *
use lib/completions.nu *

# Interactive workbench shell (default command)
export def workbench [
    --debug (-d)  # Enable debug logging
] {
    use commands/shell.nu
    shell --debug=$debug
}

# Initialize workbench for current git repository
export def "workbench init" [
    --layout: string@layout-files  # Layout file to use
    --agent: string@agents         # Agent to use (default: opencode)
    --base-ref: string@branch-names            # Base ref for worktrees (default: origin/main)
] {
    use commands/init.nu
    init --layout $layout --agent $agent --base-ref $base_ref
}

# Create a new workbench (branch name is the primary identifier)
export def "workbench create" [
    branch: string@branch-names                # Branch name (e.g., feature/ABC-123)
    --from: string@branch-names                # Override base ref
    --agent: string@agents                     # Override agent
    --no-attach                                # Don't attach after creation
    --no-session                               # Don't create zellij session
] {
    use commands/create.nu
    create $branch --from $from --agent $agent --no-attach=$no_attach --no-session=$no_session
}

# List workbenches
export def "workbench list" [
    --interactive (-i)     # Open interactive fzf picker
    --json (-j)            # Output as JSON
] {
    use commands/list.nu
    list --interactive=$interactive --json=$json
}

# Attach to a workbench session (by branch name)
export def "workbench attach" [
    branch?: string@workbench-branch  # Branch name (optional, inferred from CWD)
] {
    use commands/attach.nu
    attach $branch
}

# Remove a workbench (by branch name)
export def "workbench rm" [
    branch: string@workbench-branch  # Branch name to remove
    --delete-branch                  # Also delete the local branch
    --force                          # Force removal
    --yes (-y)                       # Skip confirmation
] {
    use commands/rm.nu
    rm $branch --delete-branch=$delete_branch --force=$force --yes=$yes
}

# Check for and fix inconsistencies
export def "workbench doctor" [
    --fix                  # Apply safe fixes
    --json                 # Output as JSON
] {
    use commands/doctor.nu
    doctor --fix=$fix --json=$json
}

# Open/edit workbench configuration
export def "workbench config" [
    --global (-g)  # Edit global config
    --show (-s)    # Print config instead of opening
] {
    use commands/config.nu
    config --global=$global --show=$show
}

# Show dependency status
export def "workbench deps" [] {
    check-deps | table
}

# Interactive session picker shell
# Run this as your terminal "home base" - detach returns you here
export def "workbench shell" [
    --debug (-d)  # Enable debug logging
] {
    use commands/shell.nu
    shell --debug=$debug
}
