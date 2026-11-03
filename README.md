# chips

An experimental and opinionated prompt engine written in Zig.

## Shell integration

With `chips` on your `PATH`, print the integration script with `chips _chips nu` or `chips _chips zsh`.

For Nushell, generate the script:

```nu
chips _chips nu | save --force ($nu.default-config-dir | path join chips.nu)
```

Then add this line to your `config.nu`:

```nu
source chips.nu
```

Regenerate `chips.nu` after upgrading chips.

For Zsh, add this line to your `.zshrc`:

```zsh
source <(chips _chips zsh)
```

Restart your shell to load the prompt. Only Nushell and Zsh are supported.

Set `CHIPS_CONFIG` to override prompt options: use a record in Nushell or a JSON string in Zsh.
