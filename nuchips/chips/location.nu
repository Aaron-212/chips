use paint.nu [chip split-chip]

export def render [config: record]: nothing -> list<string> {
    let repository = if $config.show_git { git-context } else { {} }
    if ($repository | is-empty) {
        return [
            (chip (directory) light_gray dark_gray $config)
        ]
    }

    [
        (
            split-chip {
                text: "git",
                fg_color: light_gray,
                bg_color: purple
            } {
                text: $repository.project,
                fg_color: light_gray,
                bg_color: dark_gray
            }
            $config
        )
        (
            split-chip {
                text: $repository.branch,
                fg_color: light_gray,
                bg_color: purple
            } {
                text: $repository.status,
                fg_color: light_gray,
                bg_color: blue
            }
            $config
        )
    ]
}

def directory []: nothing -> string {
    let relative = try {
        $env.PWD | path relative-to $nu.home-dir
    } catch { null }
    let display = if $relative == null {
        $env.PWD
    } else if $relative == "" {
        "~"
    } else {
        ["~" $relative] | path join
    }

    $display | single-line
}

# Read repository context together so the prompt never mixes unrelated Git results.
def git-context []: nothing -> record {
    try {
        let root = (^git rev-parse --show-toplevel | complete)
        if $root.exit_code != 0 { return {} }

        let root_path = $root.stdout | str trim
        let relative = $env.PWD | path relative-to $root_path

        {
            project: (
                [($root_path | path basename) $relative]
                | where {|part| $part != "" }
                | path join
                | single-line
            )
            branch: (branch-name)
            status: (working-tree-status)
        }
    } catch {
        {}
    }
}

def branch-name []: nothing -> string {
    let branch = (^git symbolic-ref --quiet --short HEAD | complete)
    if $branch.exit_code == 0 {
        return $":($branch.stdout | str trim)" | single-line
    }

    let head = (^git rev-parse --short HEAD | complete)
    if $head.exit_code != 0 { return "unknown" }
    $"@($head.stdout | str trim)" | single-line
}

def working-tree-status []: nothing -> string {
    let result = (^git --no-optional-locks status --porcelain=v1 --untracked-files=normal | complete)
    if $result.exit_code != 0 { return "-" }

    let changes = $result.stdout | lines | each {|line| $line | str substring 0..1 }
    if ($changes | is-empty) { return "✓" }

    let conflicts = [
        DD
        AU
        UD
        UA
        DU
        AA
        UU
    ]
    let tracked = $changes | where {|change| $change != "??" and $change not-in $conflicts }
    mut symbols = []
    if ($changes | any {|change| $change in $conflicts }) {
        $symbols = ($symbols | append "×")
    }
    if ($tracked | any {|change| ($change | str substring 0..0) != " " }) {
        $symbols = ($symbols | append "+")
    }
    if ($tracked | any {|change| ($change | str substring 1..1) != " " }) {
        $symbols = ($symbols | append "!")
    }
    if "??" in $changes {
        $symbols = ($symbols | append "?")
    }
    $symbols | str join ""
}

def single-line []: string -> string {
    $in | ansi strip | str replace --all "\n" " " | str replace --all "\r" " "
}
