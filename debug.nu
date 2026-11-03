# Run `nu --config debug.nu` for an isolated session, or `source debug.nu`.
const chips_root = path self | path dirname

do {
    cd $chips_root
    mise exec -- zig build -Doptimize=ReleaseFast
    if $env.LAST_EXIT_CODE != 0 {
        error make {msg: "Could not build chips; the prompt was not installed."}
    }
}

const chips_binary = $chips_root | path join zig-out bin chips

# Set $env.CHIPS_CONFIG before sourcing, or change it while the prompt is active.
$env.CHIPS_CONFIG = ({debug: true} | merge ($env.CHIPS_CONFIG? | default {}))
let validation = do {
    ^$chips_binary --part indicator --config ($env.CHIPS_CONFIG | to json --raw)
} | complete
if $validation.exit_code != 0 {
    error make {
        msg: ($validation.stderr | str trim)
    }
}
$env.config.show_banner = false
$env.config.render_right_prompt_on_last_line = true

def chips-render [part: string, indicator?: string] {

    # Capture command metadata before running any external process.
    let status = $env.LAST_EXIT_CODE? | default 0
    let duration = $env.CMD_DURATION_MS? | default 0 | into int
    let columns = try { (term size).columns } catch { 0 }
    let options = {debug: true} | merge ($env.CHIPS_CONFIG? | default {}) | to json --raw
    let args = [
        --part
        $part
        --config
        $options
        --cwd
        $env.PWD
        --home
        ($env.HOME? | default $nu.home-dir)
        --venv-prompt
        ($env.VIRTUAL_ENV_PROMPT? | default "")
        --status
        ($status | into string)
        --duration
        ($duration | into string)
        --columns
        ($columns | into string)
    ]
    let color_args = if $env.config.use_ansi_coloring == false { [--no-color] } else { [] }
    let indicator_args = if $indicator == null { [] } else { [--indicator $indicator] }
    let result = do { ^$chips_binary ...$args ...$color_args ...$indicator_args } | complete
    if $result.exit_code == 0 {
        $result.stdout
    } else {
        match $part {
            left => $"($env.PWD) "
            indicator => ($indicator | default "❯ ")
            _ => ""
        }
    }
}

$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append {||
    if $env.CHIPS_PROMPT_JOB? != null {
        try { job kill $env.CHIPS_PROMPT_JOB }
    }
    $env.CHIPS_PROMPT_JOB = job spawn {
        loop {
            let left = chips-render left
            let right = chips-render right
            let indicator = chips-render indicator
            let vi_normal = chips-render indicator ": "
            (commandline set-prompt $left
                --right $right
                --indicator $indicator
                --vi-insert $indicator
                --vi-normal $vi_normal
                --multiline "... ")
            sleep 1sec
        }
    }
})
