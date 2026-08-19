# Contributing

1. Fork and branch from `main`.
2. Keep shell scripts LF-only (`.gitattributes` enforces `eol=lf`).
3. Run `bash test.sh` (syntax + help/version).
4. Prefer VPS-safe defaults; destructive options must be opt-in env flags.
5. Open a PR with a clear why.

Style: Bash 4+, `shellcheck` clean when possible, Google Shell Style Guide.