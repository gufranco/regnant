# Long-term maintenance

A platform like this lives for years. The hard parts are not the
initial build but the cumulative effect of small decisions made over
hundreds of weeks. This document is the playbook for keeping the
codebase healthy across that timescale.

## What kills a platform slowly

- **Complexity creep**: every PR adds an exception. Reviewers tire,
  let one through, the next is easier. The frog boils.
- **Edge cases that became the norm**: a customer's special parameter
  silently turns into a hard-coded path, then a fork.
- **Untouched dependencies**: a library that compiles becomes a library
  no-one understands; an upgrade six years later requires rewriting
  every caller.
- **Knowledge concentrated in one person**: one engineer holds the
  end-to-end mental model, the rest cargo-cult.

## The cadence

| Cadence | Activity |
|---------|----------|
| Per PR | Self-review against the 70-category checklist; reviewer stands their ground on complexity |
| Weekly | Renovate batches; review and merge |
| Monthly | Read each Grafana dashboard; flag drifting baselines; rotate leaf certs |
| Quarterly | Read every ADR; supersede the ones that no longer apply; write any decision that has accumulated since |
| Six-monthly | Read each module's README cold; confirm it still describes the code |
| Annually | Rotate the root CA; recompute the per-region capacity math; review the disaster-recovery runbook end-to-end |

## Complexity budget

Reviewers reject any PR that:

- Adds an `if` for a single caller's special case in code shared by
  many.
- Introduces a new abstraction without retiring an old one.
- Reaches across module boundaries to read internal state.
- Adds a TODO without a concrete future action.

When the budget is exceeded, the PR is split: the surgical fix lands
now, the refactor lands as a separate change.

## Deep modules vs shallow modules

Module API surface should grow slower than implementation. A new
function in a module's public interface needs at least one of:

- A new user demand that cannot be served by composing existing ones.
- A measured cost to call paths that the new function eliminates.

If neither holds, the change is a private helper, not an export.

## Maintaining the source of truth

The OSB OpenAPI spec, the Sovereign templates, and the Envoy XDS
contract are the canonical schemas. When they change, regenerate every
SDK and every test fixture before merging.

## Dependency policy

- **Pin everything, lock files committed**. Re-running CI must
  reproduce the bytes.
- **Read the changelog**. Renovate's PR description is the start; the
  upstream changelog is the source.
- **Reject ranges**. `~> 5.80` is acceptable; `~> 5` is not.

## When the platform feels stuck

Two signals predict an upcoming wedge:

1. **Code churn on the same files**. If a directory has had ten
   independent PRs in a month, the abstraction is wrong; refactor or
   split.
2. **Bug reports without root causes**. If two consecutive incidents
   close with "added retry / added timeout / added monitor" instead
   of a structural fix, the architecture is masking a real defect.

When you see either signal, stop adding features. Spend a sprint on
the structural fix.

## Onboarding a new owner

The handoff covers four things, in order:

1. The canvas: read `docs/ARCHITECTURE.md` and the source-material
   research, then walk the new owner through the diagrams.
2. The runbooks: every operational task they will do is in
   `docs/runbooks/`. Have them execute each once.
3. The ADRs: read every `accepted` ADR; supersede the ones the new
   owner disagrees with after they have skin in the game.
4. The on-call rotation: pair them on the first three incidents.

Onboarding is done when the new owner closes an incident without
asking you a single question.

## What success looks like in year three

- Boot time to a green platform is still under ten minutes.
- The Grafana SLO dashboard is in the green for the trailing 90 days.
- The complexity budget has been enforced; the codebase fits in your
  head.
- A new contributor opens their first PR within a week of clone.
