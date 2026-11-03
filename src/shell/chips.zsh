zmodload zsh/datetime
autoload -Uz add-zsh-hook

_chips_preexec() {
    _chips_started=$EPOCHREALTIME
}

_chips_render() {
    setopt localoptions extendedglob
    local output
    local -a match
    output=$(command chips "$@") || return
    # Escape prompt syntax and mark ANSI colors as zero-width for ZLE.
    output=${output//\%/%%}
    if [[ -o promptbang ]]; then
        output=${output//\!/!!}
    fi
    print -rn -- "${output//(#b)($'\e'\[[0-9\;]#m)/%{$match[1]%}}"
}

_chips_precmd() {
    local last_status=$?
    local -i duration=0
    if [[ -n ${_chips_started-} ]]; then
        duration=$(( (EPOCHREALTIME - _chips_started) * 1000 ))
        unset _chips_started
    fi
    local config=${CHIPS_CONFIG:-'{}'}
    local -a args=(
        --cwd "$PWD"
        --home "$HOME"
        --venv-prompt "${VIRTUAL_ENV_PROMPT-}"
        --status "$last_status"
        --duration "$duration"
        --columns "${COLUMNS:-0}"
        --config "$config"
    )
    _chips_prompt=$(_chips_render --part prompt "${args[@]}") || _chips_prompt='❯ '
    _chips_right_prompt=$(_chips_render --part right "${args[@]}") || _chips_right_prompt=''
}

add-zsh-hook preexec _chips_preexec
add-zsh-hook precmd _chips_precmd
setopt prompt_subst prompt_percent
# Parameter expansion keeps shell syntax in directory names from being executed.
PROMPT='${_chips_prompt}'
RPROMPT='${_chips_right_prompt}'
PROMPT2='... '
