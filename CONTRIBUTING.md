# Contributing to `regnant`

Thank you for your interest. This project reproduces, as faithfully as possible, the platform Vasilios Syrakis described in his 2026 YouTube videos. Contributions that improve faithfulness, fix bugs, or strengthen the security/observability baseline are welcome.

## Ground rules

- The Excalidraw canvas is the source of truth. Changes that diverge from it must come with an ADR.
- Infrastructure code is held to a state-of-the-art bar. Python services are minimal by design; do not grow them beyond what is needed to exercise the architecture.
- Every commit follows Conventional Commits. The `commitlint` pre-commit hook enforces this.
- Every PR runs the full CI matrix: lint, test, build, sign, sbom, trivy, codeql.

## Development setup

Prerequisites: Docker 24+, Docker Compose v2.30+, OpenTofu 1.10+ (or Terraform 1.13+), Python 3.13, Rust 1.83+, Go 1.23+, `pre-commit`.

```bash
git clone git@github.com:gufranco/regnant.git
cd regnant
pre-commit install --install-hooks
make bootstrap
make apply
make verify
```

Read `docs/runbooks/bootstrap.md` for the full walkthrough.

## Workflow

1. Branch from `main` using `feature/<slug>`, `fix/<slug>`, `chore/<slug>`, or `docs/<slug>`.
2. Make changes; run `pre-commit run --all-files` before committing.
3. Write or update tests; coverage gate is 95% across changed and related files.
4. Update ADRs and runbooks if the change affects an architectural decision or operational procedure.
5. Open a PR. CI must be green and all reviewer comments resolved before merge.

## Code review expectations

- Comments use the symptom-first format. Lead with the observable problem, not the proposed fix.
- Reviewers stand their ground on complexity (see `docs/MENTORING-AND-OWNERSHIP.md`).
- Mocking internal infrastructure is a blocking issue. Tests use real LocalStack and real upstream services.
- Static test data is a blocking issue. Use `faker` or equivalent.

## Adding a new module

1. Run `make scaffold module <name>` to create the directory skeleton.
2. Read at least two existing modules before designing yours.
3. Match the deep-modules principle: small interface, large implementation.
4. Document inputs, outputs, and the canvas region it implements.
5. Add a Terratest under `tests/terratest/`.

## Reporting bugs

Open a GitHub issue with: the exact reproduction steps, the verbatim error message, environment details (OS, Docker version, host arch), and the relevant container logs.

## License

By contributing you agree your contributions are licensed under the Apache License 2.0 (see `LICENSE`).
