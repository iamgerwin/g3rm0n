# g3rm0n

**A live terminal dashboard for your Linux or Mac and your AI usage.**

Type `g3rm0n` to see CPU, memory, disk, power, processes and network at a glance.
Next to them are your AI subscription limits (Claude, Codex, Z.ai) and prepaid API
balances (DeepSeek, OpenRouter). It's pure bash, has no daemon, and only ever reads.

[![ci](https://github.com/iamgerwin/g3rm0n/actions/workflows/ci.yml/badge.svg)](https://github.com/iamgerwin/g3rm0n/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/iamgerwin/g3rm0n)](https://github.com/iamgerwin/g3rm0n/releases)
[![license](https://img.shields.io/github/license/iamgerwin/g3rm0n)](LICENSE)

## Get started in 30 seconds

No account, no setup and no admin password. Copy one line, paste it, and you're done.

**On a Mac**

1. Open **Terminal**: press <kbd>⌘</kbd> <kbd>Space</kbd>, type `Terminal`, press <kbd>Return</kbd>.
2. Paste this line and press <kbd>Return</kbd>:

   ```bash
   brew install bash jq && curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
   ```

   No Homebrew yet? Get it first from [brew.sh](https://brew.sh). It's one line too.
3. Type `g3rm0n` and press <kbd>Return</kbd>.

**On Linux** (Ubuntu, Debian, Fedora, Arch, …)

1. Open a terminal (<kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>T</kbd> on Ubuntu).
2. Paste this line and press <kbd>Enter</kbd>:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
   ```
3. Type `g3rm0n` and press <kbd>Enter</kbd>.

That's all. Click any panel's title (or press its number) to fold it away, and press
<kbd>q</kbd> to quit. If you use Claude Code, Codex or Z.ai, your usage limits appear
by themselves. If `g3rm0n` isn't found, open a new terminal window and try again.

## What you'll see

<!-- sample:full -->
```
g3rm0n  ● 96 Healthy  workstation · Ubuntu 24.04.1 LTS · Oct 08 | 12:34PM UTC

▾ ◉ CPU ──────────────────────────────────── 1  ▾ ◫ Memory ───────────────────────────────── 2
Usage  ████░░░░░░░░░░░░   24%                   Used   ███████░░░░░░░░░   44% 13.8G/31.1G
Cores  ▂▁▃▁▅▂▁▁▂▇▁▂▁▁▃▁                         Swap   ░░░░░░░░░░░░░░░░    0% 0B/8.0G
Load   1.12 · 0.98 · 0.87 · 16 threads          Free   17.2G available
Model  AMD Ryzen 7 7840U w/ Radeon 780M         Cache  9.5G buffers & page cache

▾ ▤ Disk ─────────────────────────────────── 3  ▾ ◪ Power ────────────────────────────────── 4
/      ███████░░░   68% 312.4G/467.2G ext4      Batt   ████████░░   81% · discharging
I/O    read 1.1M/s · write 340.0K/s             GPU    ██░░░░░░░░   18%
                                                Temp   54°C CPU
                                                Uptime 3d 6h

▾ ≡ Processes ────────────────────────────── 5  ▾ ⇅ Network ──────────────────────────────── 6
Tasks  412 total · 2 running                    Down   ▁▁▂▄█▃▁▁▁▂▁▁▁▁▁▁ 2.3M/s
1      firefox          █░░░░  18.2%    1.8G    Up     ▃▃▃▅█▃▃▃▃▃▃▃▃▃▃▃ 96.0K/s
2      code             █░░░░   7.5%  812.4M    Link   wlp1s0 · 192.168.1.24
3      node             █░░░░   3.1%  240.7M    VPN    tailscale0 · 100.101.1.7

▾ ✦ AI Tokens · Claude ───────────────────── 7  ▾ ✦ AI Tokens · Codex ────────────────────── 7
5h     ████░░░░░░   42% · resets in 2h 14m      5h     █░░░░░░░░░   12% · resets in 3h 51m
Week   ██░░░░░░░░   17% · resets in 3d 4h       Week   █░░░░░░░░░    3% · resets in 5d 18h
Left   58% of 5h window · max 5x plan           Left   88% of 5h window · plus plan

▾ ✦ AI Tokens · Z.ai ─────────────────────── 7
5h     ██████░░░░   64% · resets in 58m
Tools  █░░░░░░░░░   10% · resets in 9d 23h
Left   36% of 5h window · lite plan

▾ ◆ AI Credits · DeepSeek ────────────────── 8  ▾ ◆ AI Credits · OpenRouter ──────────────── 8
Left   ¥110.00 · prepaid balance                Spent  ███████░░░   67% · $8.20 left of $25.00
Usage  not reported by this API                 Usage  $0.42 day · $3.10 wk · $12.50 mo
Split  topped up ¥100.00 · granted ¥10.00       Key    no spend cap

g3rm0n v0.1.7 · every 2s · 1-8 or click a title to fold · -/+ all · r refresh · q quit
```
<!-- /sample -->


## Features

- **Glanceable system panels.** CPU with a per-core activity strip, memory and swap,
  disk space and I/O rates, battery and GPU (NVIDIA or AMD), the hottest temperature
  sensor, the busiest processes, and network throughput with VPN detection.
- **A health score** in the header that flags CPU, memory, swap, heat or disk pressure,
  next to the date and time, in a header you can rearrange.
- **AI Tokens:** how much of each subscription's 5-hour and weekly window you've used,
  and when each one resets.
- **AI Credits:** how much prepaid balance is left and what you've spent per day, week and month.
- **Your choice of panels.** `g3rm0n setup` picks sections, providers and the refresh rate.
- **Fold what you don't need.** Click a panel's title, or press its section's digit,
  to fold it into a one-line summary. g3rm0n remembers your folds.
- **Safe with credentials.** Keys are referenced where they already live on your
  machine. They're never copied, stored or shown.
- **Smooth.** It redraws flicker-free on the alternate screen, AI calls run in the
  background, and it adapts to the window width (two columns or one).
- **Script-friendly.** `g3rm0n --once` prints one snapshot, and color is dropped
  automatically when output is piped.

## Platforms

g3rm0n has the same panels, keys, folding, setup and AI usage on every platform it
supports. Each platform reads the machine with its own stock tools, through a backend
that every release tests against the same suite.

| Platform | Backend | Reads the machine with |
|----------|---------|------------------------|
| Linux (Ubuntu 20.04+, Debian 11+, Fedora, Arch, …) | `linux` | `/proc`, `/sys`, `df`, `ps`, `ip` |
| macOS 12 Monterey or newer (Apple silicon and Intel) | `darwin` | `sysctl`, `vm_stat`, `iostat`, `netstat`, `ioreg`, `pmset`, `df`, `ps`, `route` |

Windows (PowerShell and Command Prompt) is planned for a later release.

Where macOS keeps a reading for root only, g3rm0n shows the closest reading any user
can get, instead of asking for `sudo`:

| Reading | Linux | macOS |
|---------|-------|-------|
| `Cores` row | activity of each core | core layout, e.g. `8 performance · 4 efficiency` |
| `Temp` row | the hottest CPU sensor (`coretemp`, `k10temp`, …), else the hottest sensor | the hottest CPU sensor on Apple silicon (IOKit, as iStat Menus reads it); `no sensors exposed` on Intel Macs |
| `GPU` row | NVIDIA or AMD usage, memory, temperature | Apple GPU usage |
| `Used` memory | total minus available | app memory + wired + compressed, as Activity Monitor counts it |
| Disk `~` row | your home partition, when it's separate | the data volume, where your files live (also what the folded Disk title and the health score watch) |
| Claude login | `~/.claude/.credentials.json` | the macOS Keychain, where Claude Code keeps it |

## Requirements

- **Linux:** bash 5 or newer, GNU coreutils and procps (`ps`), which come with every
  mainstream distribution.
- **macOS:** bash 5 from [Homebrew](https://brew.sh) (`brew install bash`); macOS itself
  ships bash 3.2. You don't need to change your login shell: g3rm0n finds bash 5 on its
  own, and zsh, fish and the others keep working as they are.
- **Optional:** `curl` and `jq` for the AI panels (on macOS: `brew install jq` if
  `jq` is missing); on Linux, `ip` (iproute2) for interface details and `nvidia-smi`
  for NVIDIA GPU stats.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
```

The same command works on Linux and macOS. It installs the latest release into
`~/.local/share/g3rm0n`, links `~/.local/bin/g3rm0n`, and adds bash, zsh and fish
completions. On fish, it also puts `~/.local/bin` on your `PATH`; for other shells
(zsh is the macOS default) it prints the exact line to add if `~/.local/bin` is
missing. No root is needed. Pipe the installer into `bash`, not `sh`.

Only what g3rm0n needs to run is installed: the program, its modules, the backend
for your operating system, the completions and the license (about 100 KB, against about 430 KB for the whole repository). Tests,
docs and development tools stay in the repository.

**On a Mac**, install bash 5 first, then run the command above:

```bash
brew install bash jq
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash
```

Other ways:

```bash
# a specific version
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash -s -- --version 0.1.7

# offline, from an unpacked release (or a clone), copying only the run-time files
./install.sh --from ~/Downloads/g3rm0n

# from a clone (links the checkout, handy for development)
git clone https://github.com/iamgerwin/g3rm0n && cd g3rm0n && ./install.sh
```

To update, run the install command again.

### Shells

g3rm0n is a bash 5 program, so it runs the same whichever shell you start it from:
bash, zsh, fish, dash, ksh, mksh, tcsh, nushell and others. Even `sh g3rm0n` hands
itself over to bash. Hints that tell you what to type, such as how to export an API
key, are written in the syntax of the shell you started it from.

| Shell | Completions | Exporting an API key |
|-------|-------------|----------------------|
| bash | installed automatically (needs the `bash-completion` package) | `export OPENROUTER_API_KEY=sk-or-...` |
| zsh | installed to `~/.local/share/zsh/site-functions`; add `fpath+=(~/.local/share/zsh/site-functions)` to `~/.zshrc` before `compinit` | `export OPENROUTER_API_KEY=sk-or-...` |
| fish | installed automatically | `set -gx OPENROUTER_API_KEY sk-or-...` |
| tcsh / csh | none | `setenv OPENROUTER_API_KEY sk-or-...` |
| nushell | none | `$env.OPENROUTER_API_KEY = "sk-or-..."` |

## Usage

```
g3rm0n                    live dashboard (digits or clicks fold panels, q quits)
g3rm0n --once             print one snapshot and exit
g3rm0n -i 5               refresh every 5 seconds
g3rm0n -s cpu,memory      show only some sections for this run
g3rm0n --no-ai            system panels only, no network calls at all
g3rm0n setup              choose what the dashboard shows
g3rm0n sensors            list the temperature sensors it can read, and which one Temp shows
g3rm0n version            print the version
g3rm0n help               all options
```

| Option | What it does |
|--------|--------------|
| `-1`, `--once` | Print one snapshot and exit. This is automatic when output isn't a terminal |
| `-i N`, `--interval N` | Seconds between refreshes (whole number, 1 or more). Overrides the config for this run |
| `-s LIST`, `--sections LIST` | Comma-separated sections for this run, e.g. `cpu,memory,ai-tokens` |
| `-f LIST`, `--fold LIST` | Start with these folded: section names (`memory,ai-tokens`), panel ids (`ai-codex`), `all` or `none` |
| `--no-mouse` | Don't capture the mouse, so the terminal's own text selection works as usual |
| `--no-ai` | Hide the AI panels and make no network calls |
| `--no-color` | Plain output without color (`NO_COLOR` works too) |

Sections: `cpu` `memory` `disk` `power` `processes` `network` `ai-tokens` `ai-credits`.

## Folding and keys

Every panel folds, like an accordion, into a single title line that keeps the number
you most need:

<!-- sample:folded -->
```
g3rm0n  ● 96 Healthy  workstation · Ubuntu 24.04.1 LTS · Oct 08 | 12:34PM UTC

▾ ◉ CPU ──────────────────────────────────── 1  ▸ ◫ Memory · 44% · 13.8G/31.1G ───────────── 2
Usage  ████░░░░░░░░░░░░   24%
Cores  ▂▁▃▁▅▂▁▁▂▇▁▂▁▁▃▁
Load   1.12 · 0.98 · 0.87 · 16 threads
Model  AMD Ryzen 7 7840U w/ Radeon 780M

▾ ▤ Disk ─────────────────────────────────── 3  ▸ ◪ Power · batt 81% · 54°C ──────────────── 4
/      ███████░░░   68% 312.4G/467.2G ext4
I/O    read 1.1M/s · write 340.0K/s

▸ ≡ Processes · 412 tasks · firefox 18% ──── 5  ▸ ⇅ Network · ↓ 2.3M/s · ↑ 96.0K/s ───────── 6

▾ ✦ AI Tokens · Claude ───────────────────── 7  ▾ ✦ AI Tokens · Codex ────────────────────── 7
5h     ████░░░░░░   42% · resets in 2h 14m      5h     █░░░░░░░░░   12% · resets in 3h 51m
Week   ██░░░░░░░░   17% · resets in 3d 4h       Week   █░░░░░░░░░    3% · resets in 5d 18h
Left   58% of 5h window · max 5x plan           Left   88% of 5h window · plus plan

▾ ✦ AI Tokens · Z.ai ─────────────────────── 7
5h     ██████░░░░   64% · resets in 58m
Tools  █░░░░░░░░░   10% · resets in 9d 23h
Left   36% of 5h window · lite plan

▸ ◆ AI Credits · DeepSeek · ¥110.00 left ─── 8  ▸ ◆ AI Credits · OpenRouter · $8.20 left ─── 8
```
<!-- /sample -->

`▾` marks an open panel and `▸` a folded one. The digit at the end of each title is
that section's shortcut.

| Key | What it does |
|-----|--------------|
| `1-8` | Fold or unfold a section: `1` CPU, `2` Memory, `3` Disk, `4` Power, `5` Processes, `6` Network, `7` AI Tokens, `8` AI Credits |
| `click` | Fold or unfold one panel. Click its title; this works per AI provider too |
| `- / +` | Fold everything / unfold everything |
| `r, space` | Refresh now |
| `q` | Quit (Ctrl-C works too) |

Folds are remembered between runs in `~/.local/state/g3rm0n/folded`. `--fold` sets
the starting folds for one run, and `--fold none` clears them. One-shot output
(`--once`, or when piped) ignores saved folds, so scripts always get the full
picture, unless you pass `--fold`.

**Mouse clicks** use the standard xterm mouse protocol (SGR, mode 1006), so they
work in the terminals people use on Linux, macOS and Windows: Windows Terminal (WSL
or SSH), iTerm2, Terminal.app, GNOME Terminal, Konsole, kitty, Alacritty, WezTerm,
VS Code's terminal and xterm. Inside **tmux**, turn on `set -g mouse on`. When
g3rm0n has the mouse, hold **Shift** (on macOS, **Option** in iTerm2 and Terminal.app)
while dragging to select text, or start it with `--no-mouse`, or set `mouse = off`.
Keyboard shortcuts work everywhere.

### The header

```
g3rm0n  ● 96 Healthy  workstation · Ubuntu 24.04.1 LTS · Oct 08 | 12:35PM UTC
```

The top line shows the health score, the machine, the OS, and the date and time in
your time zone (with its usual abbreviation, such as `PST` or `CET`). It's made of
parts you can rearrange or trim with `header` in the config, for example
`header = logo health time date`, or bring the kernel version back with
`header = logo health host os kernel date time`. In a narrow window, the OS, host and
date give way first; the health score and time always stay.

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
| ✦ AI Tokens | Claude | 5-hour and weekly limit, plan | Claude Code login: `~/.claude/.credentials.json` (or `$CLAUDE_CONFIG_DIR`); on macOS, the `Claude Code-credentials` Keychain item |
| ✦ AI Tokens | Codex | 5-hour and weekly limit, plan | Codex CLI login: `~/.codex/auth.json` (or `$CODEX_HOME`) |
| ✦ AI Tokens | Z.ai | 5-hour limit, plus the weekly limit or the monthly tool quota | `GLM_API_KEY`, `ZAI_API_KEY` or `Z_AI_API_KEY` |
| ◆ AI Credits | DeepSeek | Balance and topped-up/granted split | `DEEPSEEK_API_KEY` |
| ◆ AI Credits | OpenRouter | Credits left, spend per day/week/month, key cap | `OPENROUTER_API_KEY` |

A panel appears only when its credential exists. Sign in with that tool's own CLI, or
export the key in your shell profile (see [Shells](#shells) for the syntax). The key
must be **exported**: a plain `VAR=...` in bash or zsh, or `set -g` without `-x` in
fish, stays inside that shell and g3rm0n can't see it.

Claude and Codex usage comes from the same endpoints their official CLIs use for
their own usage screens. Those endpoints aren't publicly documented and may change.
If a provider changes its format, that one panel shows an error and the rest of the
dashboard keeps working.

## Privacy & security

- **Nothing is stored.** The config holds references such as `env:GLM_API_KEY`,
  `file:~/.codex/auth.json` or `keychain:Claude Code-credentials`, never key values.
- **The macOS Keychain is asked, not copied.** Finding Claude Code's login reads the
  item's name only. Its token is read when the Claude panel refreshes, sent only to
  Anthropic, and never written anywhere. macOS may ask once whether `security` may
  use it; choose **Always Allow** to avoid being asked at every refresh.
- **Keys go to their own provider only.** Each credential is read when it's needed and
  sent only to that provider's API, over HTTPS.
- **Keys don't show up in `ps`.** Auth headers are passed to curl on stdin, not as
  command-line arguments.
- **Only the numbers are cached.** `~/.cache/g3rm0n/ai` (mode 700) holds usage figures
  and status codes, never responses or tokens.
- **Calls are gentle.** Claude is asked at most every 5 minutes and the others every
  minute (set `<provider>.refresh` to change it). After a rate limit, g3rm0n follows
  the server's `Retry-After`, or waits 5, 10, 20 and up to 60 minutes. Only one
  g3rm0n at a time calls a provider, and every open window shares the result.
- **Only layout is remembered.** `~/.local/state/g3rm0n/folded` lists which panels
  are folded. Nothing else is written outside the cache. (On macOS, the cache also
  holds a short-lived CPU measurement while g3rm0n runs, removed when it exits.)
- **No telemetry**, no update checks, no background service.
- **`--no-ai`** guarantees zero network traffic.

## Configuration

`g3rm0n setup` writes `~/.config/g3rm0n/config`. It's plain `key = value` text that
you can edit by hand. g3rm0n parses it and never executes it, and `setup` keeps any
keys it doesn't manage (such as `mouse`) exactly as you wrote them.

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
| `<provider>.credentials` | Where that provider's credential lives: `file:<path>`, `env:<VARIABLE>` or (macOS) `keychain:<service>` |
| `mouse` | `on` (default) lets you click titles to fold; `off` leaves the mouse to the terminal |
| `header` | The header's parts, in order: any of `logo` `health` `host` `os` `kernel` `date` `time` (default `logo health host os date time`) |
| `<provider>.refresh` | Seconds between calls to that provider, e.g. `claude.refresh = 600` (default 300 for Claude, 60 for the others; never below 60) |

| Environment variable | Effect |
|----------------------|--------|
| `NO_COLOR` | Disables color |
| `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` | Move the config, cache and fold-state folders |
| `G3RM0N_INSTALL_DIR`, `G3RM0N_BIN_DIR` | Change where `install.sh` puts files |

## Troubleshooting

| You see | What to do |
|---------|------------|
| `Login expired · run claude to sign in again` | Open that CLI once so it refreshes its own login |
| macOS asks whether `security` may use "Claude Code-credentials" | That's g3rm0n reading Claude Code's login for the Claude panel. Choose **Always Allow**, or **Deny** to hide the panel |
| Only one column, or the bottom cut off, in a big window | Fixed in 0.1.5: g3rm0n now asks the terminal for its size instead of `tput`, whose macOS version always reported 80×24 |
| `Key rejected · check DEEPSEEK_API_KEY` | The key is wrong or revoked. Export a valid one |
| `12m ago · retry 4m` | The provider rate-limited g3rm0n. The numbers shown are the last good reading, and g3rm0n waits as long as the provider asks before trying again. To ask even less often, raise `claude.refresh` |
| `rate limited · retrying in 30m` | Rate limited before g3rm0n had any numbers. It waits by itself; nothing to do |
| `~0%` and `new window` | That window reset while g3rm0n was waiting, so it starts over. It's an estimate until the next reading |
| `Temp  no sensors exposed` | No readable sensor. Run `g3rm0n sensors` to see what the system returned |
| No AI panels at all | Install `curl` and `jq`, then run `g3rm0n setup --show` |
| A provider is missing | Run `g3rm0n setup --show` to see whether its credential was found |
| Key is set but shows *not found* | It isn't exported. Use `export` (bash/zsh), `set -gx` (fish) or `setenv` (tcsh) |
| `g3rm0n: command not found` | `~/.local/bin` isn't on your `PATH`; the installer printed the line to add for your shell |
| `g3rm0n needs bash 5 or newer` (macOS) | `brew install bash`. g3rm0n finds it in `/opt/homebrew/bin` or `/usr/local/bin` by itself |
| `Temp  no sensors exposed` on a Mac | Expected on Intel Macs and virtual machines. On Apple silicon, run `g3rm0n sensors`: its last line says what macOS returned |
| Boxes or misaligned bars | Use a UTF-8 locale and a font with box-drawing glyphs |
| Can't select text with the mouse | Hold Shift (Option on macOS) while dragging, or use `--no-mouse` / `mouse = off` |
| Clicking a title does nothing | Your terminal isn't sending mouse events (in tmux: `set -g mouse on`). Use the digit keys instead |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/iamgerwin/g3rm0n/main/install.sh | bash -s -- --uninstall
```

This keeps your config in `~/.config/g3rm0n` and your folds in
`~/.local/state/g3rm0n`; delete those folders too for a clean slate.

## Contributing

Contributions are welcome. Please read the rules in [`rules/`](rules/README.md) first.
They cover scope, code style, security, UI conventions, how to add a provider,
testing, releases and documentation. They apply equally to people and to coding
agents ([AGENTS.md](AGENTS.md)). [ARCHITECTURE.md](ARCHITECTURE.md) explains how the
code fits together. See also [CONTRIBUTING.md](CONTRIBUTING.md).

Docs are kept in step with the code by a deterministic drift check, `tests/docs.sh`.
It runs from a git pre-commit hook (`git config core.hooksPath .githooks`), from the
coding-agent stop hook and in CI. Every code change ships with a
[CHANGELOG](CHANGELOG.md) entry.

## License

[MIT](LICENSE) © John Gerwin De las Alas ([@iamgerwin](https://github.com/iamgerwin))
