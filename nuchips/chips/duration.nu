use paint.nu [chip]

export def render [config: record, duration_ms: int]: nothing -> string {
    if $duration_ms < $config.min_duration_ms { return "" }

    let seconds = $duration_ms / 1000 | math round --precision 1
    chip $"($seconds)s" light_gray dark_gray $config
}
