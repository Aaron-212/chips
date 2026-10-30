use paint.nu [chip]

export def render [config: record]: nothing -> string {
    let time = date now | format date "%H:%M:%S"
    chip $time light_gray dark_gray $config
}
