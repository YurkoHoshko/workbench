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

use lib/utils.nu *
use lib/config.nu *

# Initialize workbench for current git repository
export def "workbench init" [
    --layout: string       # Layout file to use
    --agent: string        # Agent to use (default: opencode)
    --layouts-dir: string  # Layouts directory
    --base-ref: string     # Base ref for worktrees (default: origin/main)
    --root: string         # Override workbench root
] {
    use commands/init.nu
    init --layout $layout --agent $agent --layouts-dir $layouts_dir --base-ref $base_ref --root $root
}

# Create a new workbench
export def "workbench create" [
    name: string           # Workbench name (e.g., ABC-123)
    --from: string         # Override base ref
    --layout: string       # Override layout
    --agent: string        # Override agent
    --no-attach            # Don't attach after creation
    --no-session           # Don't create zellij session
] {
    use commands/create.nu
    create $name --from $from --layout $layout --agent $agent --no-attach=$no_attach --no-session=$no_session
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
    name?: string          # Workbench name (optional, inferred from CWD)
] {
    use commands/attach.nu
    attach $name
}

# Remove a workbench
export def "workbench rm" [
    name: string           # Workbench name to remove
    --branch               # Also delete the branch
    --force                # Force removal
    --yes (-y)             # Skip confirmation
] {
    use commands/rm.nu
    rm $name --branch=$branch --force=$force --yes=$yes
}

# Generate workbench report
export def "workbench report" [
    --name: string         # Workbench name (optional, inferred from CWD)
    --format: string       # Output format: md or json (default: md)
    --output: string       # Output file path
] {
    use commands/report.nu
    report --name $name --format $format --output $output
}

# Start/attach dashboard session
export def "workbench dashboard" [
    --layout: string       # Override layout
] {
    use commands/dashboard.nu
    dashboard --layout $layout
}

# Check for and fix inconsistencies
export def "workbench doctor" [
    --fix                  # Apply safe fixes
    --json                 # Output as JSON
] {
    use commands/doctor.nu
    doctor --fix=$fix --json=$json
}

# Show dependency status
export def "workbench deps" [] {
    check-deps | table
}
