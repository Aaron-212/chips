use paint.nu [split-chip]

export def render [config: record]: nothing -> string {
    let prompt = $env.VIRTUAL_ENV_PROMPT? | default ""
    if $prompt == "" { return "" }

    (
        split-chip {
            text: "venv",
            fg_color: black,
            bg_color: cyan
        } {
            text: $prompt,
            fg_color: light_gray,
            bg_color: dark_gray
        }
        $config
    )
}
