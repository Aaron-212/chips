use paint.nu [chip]

export def render [config: record, duration_ms: int]: nothing -> string {
    if $duration_ms < $config.min_duration_ms { return "" }

    let text = if $config.human_readable_duration {
        $duration_ms | into duration --unit ms | into string
    } else {
        let seconds = $duration_ms / 1000 | math round --precision 1
        $"($seconds)s"
    }
    chip $text light_gray dark_gray $config
}
