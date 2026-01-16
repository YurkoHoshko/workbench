# MRU (Most Recently Used) tracking for workbench sessions

const MRU_FILE = "~/.local/state/workbench/mru.txt"

# Touch MRU entry for a session (moves it to top)
export def touch-mru [session_name: string]: nothing -> nothing {
    let mru_path = ($MRU_FILE | path expand)
    let mru_dir = ($mru_path | path dirname)
    
    if not ($mru_dir | path exists) {
        mkdir $mru_dir
    }
    
    # Read existing entries, remove this session, add it to top
    let existing = if ($mru_path | path exists) {
        open $mru_path | lines | where { $in != $session_name and $in != "" }
    } else {
        []
    }
    
    [$session_name] | append $existing | str join "\n" | save -f $mru_path
}

# Get MRU-sorted session names
export def get-mru-order []: nothing -> list<string> {
    let mru_path = ($MRU_FILE | path expand)
    if ($mru_path | path exists) {
        open $mru_path | lines | where { $in != "" }
    } else {
        []
    }
}

# Sort workbenches by MRU (recently used first, then by name)
export def sort-by-mru [workbenches: list]: nothing -> list {
    let mru = (get-mru-order)
    
    # Build priority map
    let with_priority = ($workbenches | each {|wb|
        let idx = ($mru | enumerate | where { $in.item == $wb.session } | get -o 0.index)
        let priority = if $idx != null { $idx } else { 99999 }
        $wb | merge { mru_priority: $priority }
    })
    
    $with_priority | sort-by mru_priority | reject mru_priority
}
