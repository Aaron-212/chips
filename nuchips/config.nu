# Resolve partial options without changing the caller's environment.
export def resolve [options: record = {}]: nothing -> record {
    let defaults = {
        color: true
        debug: false
        chip_start: "\u{E0B6}"
        chip_end: "\u{E0B4}"
        show_git: true
        min_duration_ms: 1000
        human_readable_duration: true
        newline_before_prompt: true
        multiline: true
        indicator: "\u{276F} "
    }

    for option in ($options | transpose name value) {
        if $option.name not-in ($defaults | columns) {
            error make {msg: $"Unknown nuchips option: ($option.name)"}
        }

        let expected = $defaults | get $option.name | describe
        if ($option.value | describe) != $expected {
            error make {msg: $"nuchips option '($option.name)' must be ($expected)"}
        }
    }

    let config = $defaults | merge $options
    if $config.min_duration_ms < 0 {
        error make {msg: "nuchips option 'min_duration_ms' must be nonnegative"}
    }
    $config
}

# Also allow rendering before the prompt has been enabled.
export def current []: nothing -> record {
    resolve ($env.NUCHIPS_CONFIG? | default {})
}
