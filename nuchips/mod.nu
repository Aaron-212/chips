use config.nu
export use render.nu

# Enable nuchips in the current Nushell session.
export def --env main [options: record = {}] {
    $env.NUCHIPS_CONFIG = (config resolve $options)

    $env.PROMPT_COMMAND = {|| render }
    $env.PROMPT_COMMAND_RIGHT = {||
        if (config current).multiline { "" } else { render right }
    }
    $env.config.render_right_prompt_on_last_line = true
    $env.PROMPT_INDICATOR = {|| render indicator }
    $env.PROMPT_INDICATOR_VI_INSERT = {|| render indicator }
    $env.PROMPT_INDICATOR_VI_NORMAL = {|| render indicator ": " }
    $env.PROMPT_MULTILINE_INDICATOR = "... "
}
