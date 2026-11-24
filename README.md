# chips

An experimental and opinionated prompt engine written in Zig.

Requires support for powerline symbols.

## Shell integration

With `chips` on your `PATH`, print the integration script with `chips _chips <shell>`.
Use `nu`, `zsh`, or `bash` for `<shell>`.

For Nushell, generate the script:

```nu
chips _chips nu | save --force ($nu.default-config-dir | path join chips.nu)
```

Then add this line to your `config.nu`:

```nu
source chips.nu
```

Regenerate `chips.nu` after upgrading chips.

The Nushell prompt refreshes when it returns after a command. To also refresh it
every second while you type or wait, add this to `config.nu`:

```nu
$env.CHIPS_BACKGROUND_REFRESH = true
```

For Zsh, add this line to your `.zshrc`:

```zsh
source <(chips _chips zsh)
```

For Bash, add this line to your `~/.bashrc` after any other prompt setup:

```bash
source <(chips _chips bash)
```

Bash shows the right-hand chips in multiline mode. Command durations require
Bash 5.0 or later.

Restart your shell to load the prompt.

Set `CHIPS_CONFIG` to override prompt options. Use a record in Nushell or a JSON
string in Zsh and Bash.
