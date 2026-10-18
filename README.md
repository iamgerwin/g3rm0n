# g3rm0n

**A live terminal dashboard for your Linux machine and your AI usage.**

Type `g3rm0n` to see CPU, memory, disk, power, processes and network at a glance.
Next to them are your AI subscription limits (Claude, Codex, Z.ai) and prepaid API
balances (DeepSeek, OpenRouter). It's pure bash, has no daemon, and only ever reads.

[![ci](https://github.com/iamgerwin/g3rm0n/actions/workflows/ci.yml/badge.svg)](https://github.com/iamgerwin/g3rm0n/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/iamgerwin/g3rm0n)](https://github.com/iamgerwin/g3rm0n/releases)
[![license](https://img.shields.io/github/license/iamgerwin/g3rm0n)](LICENSE)

```
g3rm0n  ● 96 Healthy  workstation · Ubuntu 24.04.1 LTS · 6.8.0-45-generic

◉ CPU ────────────────────────────────────────  ◫ Memory ─────────────────────────────────────
Usage  ████░░░░░░░░░░░░   24%                   Used   ███████░░░░░░░░░   44% 13.9G/31.2G
Cores  ▂▁▃▁▅▂▁▁▂▇▁▂▁▁▃▁                         Swap   ░░░░░░░░░░░░░░░░    0% 0B/8.0G
Load   1.12 · 0.98 · 0.87 · 16 threads          Free   17.3G available
Model  AMD Ryzen 7 7840U w/ Radeon 780M         Cache  9.6G buffers & page cache

▤ Disk ───────────────────────────────────────  ◪ Power ──────────────────────────────────────
/      ███████░░░   68% 312.4G/467.3G ext4      Batt   ████████░░   81% · discharging
I/O    read 1.2M/s · write 340.0K/s             GPU    ██░░░░░░░░   18%
                                                Temp   54°C hottest sensor
                                                Uptime 3d 6h

≡ Processes ──────────────────────────────────  ⇅ Network ────────────────────────────────────
Tasks  412 total · 2 running                    Down   ▁▁▂▅█▃▁▁▁▂▁▁▁▁▁▁ 2.4M/s
1      firefox          █░░░░  18.2%    1.9G    Up     ▁▁▁▂▃▁▁▁▁▁▁▁▁▁▁▁ 96.0K/s
2      code             █░░░░   7.5%  812.4M    Link   wlp1s0 · 192.168.1.24
3      node             █░░░░   3.1%  240.8M    VPN    tailscale0 · 100.101.1.7

✦ AI Tokens · Claude ─────────────────────────  ✦ AI Tokens · Codex ──────────────────────────
5h     ████░░░░░░   42% · resets in 2h 14m      5h     █░░░░░░░░░   12% · resets in 3h 51m
Week   ██░░░░░░░░   17% · resets in 3d 4h       Week   █░░░░░░░░░    3% · resets in 5d 18h
Left   58% of 5h window · max 5x plan           Left   88% of 5h window · plus plan

✦ AI Tokens · Z.ai ───────────────────────────
5h     ██████░░░░   64% · resets in 58m
Tools  █░░░░░░░░░   10% · resets in 9d 23h
Left   36% of 5h window · lite plan

◆ AI Credits · DeepSeek ──────────────────────  ◆ AI Credits · OpenRouter ────────────────────
Left   ¥110.00 · prepaid balance                Spent  ███████░░░   67% · $8.20 left of $25.00
Usage  not reported by this API                 Usage  $0.42 day · $3.10 wk · $12.50 mo
Split  topped up ¥100.00 · granted ¥10.00       Key    no spend cap
```

## Features

- **Glanceable system panels.** CPU with a per-core activity strip, memory and swap,
  disk space and I/O rates, battery and GPU (NVIDIA or AMD), the hottest temperature
  sensor, the busiest processes, and network throughput with VPN detection.
- **A health score** in the header that flags CPU, memory, swap, heat or disk pressure.
- **AI Tokens:** how much of each subscription's 5-hour and weekly window you've used,
  and when each one resets.
- **AI Credits:** how much prepaid balance is left and what you've spent per day, week and month.
- **Your choice of panels.** `g3rm0n setup` picks sections, providers and the refresh rate.
- **Safe with credentials.** Keys are referenced where they already live on your
  machine. They're never copied, stored or shown.
- **Smooth.** It redraws flicker-free on the alternate screen, AI calls run in the
  background, and it adapts to the window width (two columns or one).
- **Script-friendly.** `g3rm0n --once` prints one snapshot, and color is dropped
  automatically when output is piped.

## Requirements

- Linux with bash 5 or newer (Ubuntu 20.04+, Debian 11+, Fedora, Arch, …)
- GNU coreutils and procps (`ps`), which come with every mainstream distribution
- **Optional:** `curl` and `jq` for the AI panels, `ip` (iproute2) for interface
  details, and `nvidia-smi` for NVIDIA GPU stats

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
```

This installs the latest release into `~/.local/share/g3rm0n`, links `~/.local/bin/g3rm0n`,
and adds bash and fish completions. On fish, it also puts `~/.local/bin` on your `PATH`.
No root is needed.

Other ways:

```bash
# a specific version
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash -s -- --version 0.1.0

# from a clone (links the checkout, handy for development)
git clone https://github.com/iamgerwin/g3rm0n && cd g3rm0n && ./install.sh
```

To update, run the install command again.

## Usage

```
g3rm0n                    live dashboard (q quits, any key refreshes)
g3rm0n --once             print one snapshot and exit
g3rm0n -i 5               refresh every 5 seconds
g3rm0n -s cpu,memory      show only some sections for this run
g3rm0n --no-ai            system panels only, no network calls at all
g3rm0n setup              choose what the dashboard shows
g3rm0n help               all options
```

Sections: `cpu` `memory` `disk` `power` `processes` `network` `ai-tokens` `ai-credits`.

## Setup

```bash
g3rm0n setup
```

Setup walks you through three steps. Use arrow keys (or `j`/`k`) to move, space to
toggle, `a` to select all or none, and enter to save:

1. **Sections:** which panels to show.
2. **AI providers:** setup marks each one as *found* or *not found* on this machine
   and pre-selects the ones it found.
3. **Refresh interval** in seconds.

| Command | What it does |
|---------|--------------|
| `g3rm0n setup --defaults` | Writes a config with every section and every detected provider, without prompting |
| `g3rm0n setup --show` | Prints the current config and what was detected |
| `g3rm0n setup --reset` | Deletes the config (back to built-in defaults) |

Without a config, g3rm0n shows every section and every provider it can find.

## AI providers

| Panel | Provider | Shows | Credential g3rm0n references |
|-------|----------|-------|------------------------------|
| ✦ AI Tokens | Claude | 5-hour and weekly limit, plan | Claude Code login: `~/.claude/.credentials.json` (or `$CLAUDE_CONFIG_DIR`) |
| ✦ AI Tokens | Codex | 5-hour and weekly limit, plan | Codex CLI login: `~/.codex/auth.json` (or `$CODEX_HOME`) |
| ✦ AI Tokens | Z.ai | 5-hour limit, plus the weekly limit or the monthly tool quota | `GLM_API_KEY`, `ZAI_API_KEY` or `Z_AI_API_KEY` |
| ◆ AI Credits | DeepSeek | Balance and topped-up/granted split | `DEEPSEEK_API_KEY` |
| ◆ AI Credits | OpenRouter | Credits left, spend per day/week/month, key cap | `OPENROUTER_API_KEY` |

A panel appears only when its credential exists. Sign in with that tool's own CLI, or
export the key in your shell profile, for example in fish:

```fish
set -gx OPENROUTER_API_KEY sk-or-...
```

Claude and Codex usage comes from the same endpoints their official CLIs use for
their own usage screens. Those endpoints aren't publicly documented and may change.
If a provider changes its format, that one panel shows an error and the rest of the
dashboard keeps working.

## Privacy & security

- **Nothing is stored.** The config holds references such as `env:GLM_API_KEY` or
  `file:~/.codex/auth.json`, never key values.
- **Keys go to their own provider only.** Each credential is read when it's needed and
  sent only to that provider's API, over HTTPS.
- **Keys don't show up in `ps`.** Auth headers are passed to curl on stdin, not as
  command-line arguments.
- **Only the numbers are cached.** `~/.cache/g3rm0n/ai` (mode 700) holds usage figures
  and status codes, never responses or tokens.
- **Calls are gentle.** Each provider is called at most once a minute, with a longer
  back-off after a rate limit.
- **No telemetry**, no update checks, no background service.
- **`--no-ai`** guarantees zero network traffic.

## Configuration

`g3rm0n setup` writes `~/.config/g3rm0n/config`. It's plain `key = value` text that
you can edit by hand. g3rm0n parses it and never executes it.

```ini
sections = cpu memory disk power processes network ai-tokens ai-credits
interval = 2
providers = claude codex zai openrouter
claude.credentials = file:~/.claude/.credentials.json
codex.credentials = file:~/.codex/auth.json
zai.credentials = env:GLM_API_KEY
openrouter.credentials = env:OPENROUTER_API_KEY
```

| Key | Meaning |
|-----|---------|
| `sections` | Panels to show (space-separated) |
| `interval` | Seconds between refreshes (whole number, 1 or more) |
| `providers` | AI providers to show: `auto` (every one detected), a list, or `none` |
| `<provider>.credentials` | Where that provider's credential lives: `file:<path>` or `env:<VARIABLE>` |

| Environment variable | Effect |
|----------------------|--------|
| `NO_COLOR` | Disables color |
| `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` | Move the config and cache folders |
| `G3RM0N_INSTALL_DIR`, `G3RM0N_BIN_DIR` | Change where `install.sh` puts files |

## Troubleshooting

| You see | What to do |
|---------|------------|
| `Login expired · run claude to sign in again` | Open that CLI once so it refreshes its own login |
| `Key rejected · check DEEPSEEK_API_KEY` | The key is wrong or revoked. Export a valid one |
| `rate limited · retrying in 5m` | The provider is throttling. g3rm0n backs off by itself |
| `stale 7m` | The last refresh failed; the numbers shown are from the last success |
| No AI panels at all | Install `curl` and `jq`, then run `g3rm0n setup --show` |
| A provider is missing | Run `g3rm0n setup --show` to see whether its credential was found |
| Boxes or misaligned bars | Use a UTF-8 locale and a font with box-drawing glyphs |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash -s -- --uninstall
```

This keeps your config in `~/.config/g3rm0n`; delete that folder too for a clean slate.

## Contributing

Contributions are welcome. Please read the rules in [`rules/`](rules/README.md) first.
They cover scope, code style, security, UI conventions, how to add a provider,
testing and releases. They apply equally to people and to coding agents. See also
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © John Gerwin De las Alas ([@iamgerwin](https://github.com/iamgerwin))
