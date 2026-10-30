use paint.nu [chip]

export def render [config: record, exit_code: int]: nothing -> string {
    if $exit_code == 0 { return "" }
    chip $"exit:($exit_code)" light_gray red $config
}
