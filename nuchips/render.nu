use config.nu
use chips

# Render the prompt body without changing the caller's environment.
export def main []: nothing -> string {
    # Capture command metadata before running Git.
    let status = {
        duration_ms: ($env.CMD_DURATION_MS? | default "0" | into int)
        exit_code: ($env.LAST_EXIT_CODE? | default 0)
    }
    let config = config current
    if not $config.debug { return (left $config $status) }

    let measured = timeit --output { left $config $status }
    let elapsed_ms = $measured.time / 1ms | math round --precision 2
    $"($measured.output)($elapsed_ms)ms "
}

# Render the right prompt without running external commands.
export def right []: nothing -> string {
    let status = {
        duration_ms: ($env.CMD_DURATION_MS? | default "0" | into int)
        exit_code: ($env.LAST_EXIT_CODE? | default 0)
    }
    let config = config current
    chips right $config $status
}

# Render the indicator using the previous command's exit status.
export def indicator [text?: string]: nothing -> string {
    let exit_code = $env.LAST_EXIT_CODE? | default 0
    let config = config current
    let text = $text | default $config.indicator
    if not $config.color { return $text }

    let color = if $exit_code == 0 { "green" } else { "red" }
    $"(ansi reset)(ansi $color)($text)(ansi reset)"
}

def left [config: record, status: record]: nothing -> string {
    let body = chips collect $config | str join " "
    let prefix = if $config.newline_before_prompt { "\n" } else { "" }
    if $config.multiline {
        let right = chips right $config $status
        let row = align-right $body $right
        $"($prefix)($row)\n"
    } else {
        $"($prefix)($body) "
    }
}

def align-right [left: string, right: string]: nothing -> string {
    if $right == "" { return $left }

    let columns = try { (term size).columns } catch { 0 }
    let left_width = $left | ansi strip | str stats | get unicode-width
    let right_width = $right | ansi strip | str stats | get unicode-width
    let gap = $columns - $left_width - $right_width
    if $gap < 1 { return $left }

    let padding = "" | fill --width $gap
    $"($left)($padding)($right)"
}
