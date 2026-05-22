# Mentoring and ownership

How a new contributor learns the platform, and how an owner stays in
shape on it.

## The first week

| Day | Goal | Activity |
|-----|------|----------|
| 1 | Run it | `make bootstrap && make apply && make verify` end to end |
| 2 | See it work | Follow `docs/runbooks/provision-load-balancer.md` start to finish |
| 3 | Read the canvas | `docs/ARCHITECTURE.md`, then the seven module READMEs |
| 4 | Trace a request | Use Grafana's trace-to-logs to follow one request from edge to backend |
| 5 | Ship something tiny | Add a metric, a Grafana panel, a runbook clarification; merge it |

By the end of the week, the new contributor has touched every part of
the stack with their hands.

## How to teach code review

Stand your ground on complexity. The most common failure mode is a
reviewer who tires after the third round and approves the fourth pass
because they can't face the conversation again. That is exactly when
the bad change lands.

Three things to enforce in every review:

1. **Every changed line traces to the PR description**. No drive-by
   improvements; no "while I was here." If something else needs
   fixing, file an issue.
2. **No mocks for our own infrastructure**. Tests use real LocalStack
   (or moto in unit tests), not handwritten mocks of our services.
3. **No bare error catches**. Every `except` classifies its error
   (transient, permanent, ambiguous) and decides accordingly.

Three things to spot quickly:

- A new exported function with no caller in the same PR.
- A new TODO without a name attached.
- A new "Optional" parameter that exists to skip a code path entirely.

## Calibrating a new reviewer

Pair the first ten reviews with a senior reviewer. After each, compare
the comments you each left. The point is not who is right; the point
is to teach the new reviewer what to notice.

## Ownership signals

A team owns a module when:

- The module's README names the team as the contact.
- The team can answer "why is this module shaped this way?" without
  reading the code.
- The team gets paged for incidents that originate in the module.
- The team approves any cross-module PR that touches the module.

Without all four, ownership is nominal; the codebase will rot at the
boundary.

## Diplomacy

The reviewer-author conversation is the platform. Make it pleasant:

- Lead with the issue, not the verdict.
- Quote the line you mean. Vague feedback wastes a round trip.
- When you change your mind, say so explicitly.
- When you're tired, hand the review off.

When a disagreement persists for more than two rounds, escalate to an
ADR. Either the decision belongs in an ADR (because it will recur), or
neither side has actually pinned the trade-off; writing it down
clarifies which.

## What a great senior engineer does on this codebase

- Maintains a mental model of the dependency graph between modules
  and can answer "if I change X, what breaks?" without grepping.
- Reads the Grafana dashboards weekly without prompting.
- Has read every ADR and challenges the ones they disagree with by
  writing a superseding ADR rather than ignoring them.
- Mentors at least one junior engineer through their first
  end-to-end ownership rotation per quarter.

That is the bar to grow into. Hold yourself and the team to it.
