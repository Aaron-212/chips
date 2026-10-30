use location.nu
use duration.nu
use exit.nu
use clock.nu
use venv.nu

# Collect the left prompt segments.
export def collect [config: record]: nothing -> list<string> {
    [
        (venv render $config)
    ]
    | append (location render $config)
    | where {|chip| $chip != "" }
}

export def right [config: record, status: record]: nothing -> string {
    [
        (duration render $config $status.duration_ms)
        (exit render $config $status.exit_code)
        (clock render $config)
    ] | where {|chip| $chip != "" } | str join " "
}
