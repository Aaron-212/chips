export def chip [
    text: string
    fg_color: string
    bg_color: string
    config: record
]: nothing -> string {
    if not $config.color { return $text }

    let start = paint $config.chip_start {fg: $bg_color}
    let content = paint $text {fg: $fg_color, bg: $bg_color}
    let end = paint $config.chip_end {fg: $bg_color}
    $"($start)($content)($end)"
}

# Join two backgrounds inside one pair of rounded caps.
export def split-chip [left: record, right: record, config: record]: nothing -> string {
    if not $config.color { return $"($left.text)  ($right.text)" }

    let start = paint $config.chip_start {fg: $left.bg_color}
    let first = paint $"($left.text) " {fg: $left.fg_color, bg: $left.bg_color}
    let second = paint $" ($right.text)" {fg: $right.fg_color, bg: $right.bg_color}
    let end = paint $config.chip_end {fg: $right.bg_color}
    $"($start)($first)($second)($end)"
}

# Isolate each style from the surrounding terminal state.
def paint [text: string, style: record]: nothing -> string {
    $"(ansi reset)(ansi --escape $style)($text)(ansi reset)"
}
