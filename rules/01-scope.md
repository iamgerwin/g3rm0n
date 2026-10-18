# 1. Product scope

g3rm0n is a **read-only monitoring dashboard** for a Linux machine and for the AI
services its owner uses. That is the whole product.

## In scope

- Showing live system state: CPU, memory, disk, power and thermals, processes, network.
- Showing AI usage: subscription limits (**AI Tokens**) and prepaid API balances (**AI Credits**).
- Choosing what is shown (`g3rm0n setup`, the config file, command-line flags).
- Installing, updating and uninstalling g3rm0n itself for the current user.

## Out of scope — do not add

- Anything that **changes the machine**: cleaning caches, deleting files, killing
  processes, installing or removing packages, tuning settings, running `sudo`.
- Anything that **changes an account**: buying credits, rotating keys, refreshing
  OAuth tokens, signing in or out of another tool.
- Background services, daemons, cron jobs or telemetry of any kind.
- Support for other operating systems by faking Linux interfaces. A port must read
  that platform's real counters and gets its own discussion first.

If a feature request needs any of the above, the answer is no, or a separate tool.

## Guiding principles

- **Glanceable.** Every row answers one question at a glance. If a value needs a
  paragraph to explain, it doesn't belong on the dashboard.
- **Honest.** Show "not reported", "stale" or "offline" instead of a misleading zero.
- **Light.** One refresh must stay cheap: no heavy commands in the frame loop, and
  network calls never block a frame.
- **Few dependencies.** bash 5 and coreutils for the system panels; `curl` and `jq`
  only for the AI panels, which hide themselves when those are missing.
