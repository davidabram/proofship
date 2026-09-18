# Proofship

## Bend 2 development

This repository provides Bend entirely through its Nix development shell. The
Bend source is intentionally pinned to commit
`0b7e2b11c1054f5d0f4eb955cadb47997ef1115d` for reproducible development.

```sh
nix develop
bend --version
bend guide
```

The shell also provides the native CPU/GPU build dependencies, including CUDA
12.9. Bend is not installed globally.
