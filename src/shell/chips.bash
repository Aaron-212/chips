# shellcheck shell=bash

[[ $- == *i* && -z ${_chips_bash_loaded-} ]] || return 0
_chips_bash_loaded=1
_chips_started=0

_chips_bash_render() {
    local output color
    local sgr=$'\e''\[[0-9;]*m'
    output=$(command chips --part prompt "$@") || return

    if [[ -o emacs || -o vi ]]; then
        # Readline uses these markers for nonprinting bytes after PS1 expands.
        while [[ $output =~ $sgr ]]; do
            color=${BASH_REMATCH[0]}
            printf '%s\001%s\002' "${output%%"$color"*}" "$color"
            output=${output#*"$color"}
        done
    fi
    printf '%s' "$output"
}

_chips_bash_precmd() {
    local last_status=$? duration=0 now
    if ((_chips_started != 0)); then
        now=${EPOCHREALTIME/./}
        if ((now >= _chips_started)); then
            duration=$(((now - _chips_started) / 1000))
        fi
        _chips_started=0
    fi

    local config=${CHIPS_CONFIG:-'{}'}
    _chips_prompt=$(_chips_bash_render \
        --cwd "$PWD" \
        --home "${HOME-}" \
        --venv-prompt "${VIRTUAL_ENV_PROMPT-}" \
        --status "$last_status" \
        --duration "$duration" \
        --columns "${COLUMNS:-0}" \
        --config "$config") || _chips_prompt='❯ '

    # Pass the status through to the next hook when errexit is off.
    [[ $- == *e* ]] || return "$last_status"
}

if ((BASH_VERSINFO[0] >= 5)); then
    # PS0 runs before the command. The empty slice records the time without printing.
    # shellcheck disable=SC2016
    PS0=${PS0-}'${_chips_started:$((_chips_started = ${EPOCHREALTIME/./}, 0)):0}'
fi

if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
    PROMPT_COMMAND=('_chips_bash_precmd' "${PROMPT_COMMAND[@]}")
else
    # shellcheck disable=SC2178
    PROMPT_COMMAND=_chips_bash_precmd$'\n'${PROMPT_COMMAND-}
fi

shopt -s promptvars
# Expand the rendered text as data, including any shell syntax in directory names.
PS1='${_chips_prompt}'
PS2='... '
