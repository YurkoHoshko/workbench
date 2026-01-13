# workbench - Zellij + Git Worktree Workbench Manager
#
# Usage:
#   use /path/to/workbench/mod.nu *
#   workbench init
#   workbench create ABC-123
#   workbench list --interactive
#   workbench attach ABC-123
#   workbench rm ABC-123
#   workbench report
#   workbench dashboard
#   workbench doctor
#   workbench clone <url>

use lib/utils.nu *
use lib/config.nu *
use lib/completions.nu *

# Initialize workbench for current git repository
export def "workbench init" [
    --layout: string@layout-files  # Layout file to use
    --agent: string@agents         # Agent to use (default: opencode)
    --layouts-dir: string                      # Layouts directory
    --base-ref: string                         # Base ref for worktrees (default: origin/main)
] {
    use commands/init.nu
    init --layout $layout --agent $agent --layouts-dir $layouts_dir --base-ref $base_ref
}

# Create a new workbench
export def "workbench create" [
    name: string                               # Workbench name (e.g., ABC-123)
    --from: string                             # Override base ref
    --branch: string                           # Explicit branch name
    --agent: string@agents         # Override agent
    --no-attach                                # Don't attach after creation
    --no-session                               # Don't create zellij session
] {
    use commands/create.nu
    create $name --from $from --branch $branch --agent $agent --no-attach=$no_attach --no-session=$no_session
}

# List workbenches
export def "workbench list" [
    --interactive (-i)     # Open interactive fzf picker
    --json (-j)            # Output as JSON
] {
    use commands/list.nu
    list --interactive=$interactive --json=$json
}

# Attach to a workbench session
export def "workbench attach" [
    name?: string@workbench-name  # Workbench name (optional, inferred from CWD)
] {
    use commands/attach.nu
    attach $name
}

# Remove a workbench
export def "workbench rm" [
    name: string@workbench-name  # Workbench name to remove
    --branch                                 # Also delete the branch
    --force                                  # Force removal
    --yes (-y)                               # Skip confirmation
] {
    use commands/rm.nu
    rm $name --branch=$branch --force=$force --yes=$yes
}

# Generate workbench report
export def "workbench report" [
    --name: string@workbench-name   # Workbench name (optional, inferred from CWD)
    --format: string@report-formats # Output format: md or json (default: md)
    --output: string                            # Output file path
] {
    use commands/report.nu
    report --name $name --format $format --output $output
}

# Start/attach dashboard session
export def "workbench dashboard" [
] {
    use commands/dashboard.nu
    dashboard
}

# Check for and fix inconsistencies
export def "workbench doctor" [
    --fix                  # Apply safe fixes
    --json                 # Output as JSON
] {
    use commands/doctor.nu
    doctor --fix=$fix --json=$json
}

# Clone a repository and initialize workbench
export def "workbench clone" [
    url: string                                # Git repository URL
    --name: string                             # Override repo name
    --layout: string@layout-files  # Layout file to use
    --agent: string@agents         # Agent to use
    --base-ref: string                         # Base ref (default: auto-detect)
    --workbench: string                        # Create initial workbench with this name
] {
    use commands/clone.nu
    clone $url --name $name --layout $layout --agent $agent --base-ref $base_ref --workbench $workbench
}

# Show current workbench status
export def "workbench status" [
    --json (-j)  # Output as JSON
] {
    use commands/status.nu
    status --json=$json
}

# Create a review workbench for a branch
export def "workbench review" [
    branch?: string@branch-names  # Branch to review (default: current)
] {
    use commands/review.nu
    review $branch
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
