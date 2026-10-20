# statusline

My custom [Claude Code](https://claude.com/claude-code) status line — a single
self-contained bash script.

```
 <cwd>    <branch>  (● 3 ↑ 1)    71.5k (47%)    Opus 4.8 (xhigh)    5% (12:30pm)
```

## Segments

Left to right (each segment hides itself when its data is unavailable):

| Segment | Color | Source |
| --- | --- | --- |
|  repo name | cyan | git toplevel of `cwd` |
|  branch `(● N ↑ M)` | green / dim | current branch + count of dirty files + commits no remote has |
|  session tokens `(N%)` | yellow / dim | tokens in context from the transcript, as % of a 150k "happy context" budget (see below) |
|  model `(effort)` | red / dim | `model.display_name` + `effort.level` from stdin |
|  5h usage `(reset time)` | magenta / dim | `rate_limits.five_hour.used_percentage` (rounded) + local time the 5-hour rolling limit window resets |

The 5-hour usage segment requires a Claude.ai **Pro/Max** subscription and only
appears after the first API response in a session.

### Second line: `.now`

If the session's folder, or any folder above it, has a `.now` file, its first line is
shown in green on a second line. Use it to pin your current next step for a workspace,
e.g. `▶ NOW: open the PR`. Without a `.now` file the status line stays one line.

### Why the token percentage is out of 150k

The percentage is deliberately **not** a share of the model's full context window.
It is a share of 150k tokens, the rough point where context rot sets in and answer
quality starts to slide, well before the window is actually full. Treat it as a
"how much good context is left" gauge: past 100% it keeps counting up, and that is
your cue to `/compact` or `/clear`. Tune the budget with `AUTOCOMPACT_LIMIT` at the
top of the script.

## Dependencies

- **bash** (3.2+, so macOS's stock bash works), **jq**, **git**.
- **`date` / line-reverse** — the script auto-detects coreutils flavor: BSD
  (`date -r`, `tail -r`) on macOS, GNU (`date -d`, `tac`) on Linux / WSL / Git
  Bash. No per-platform edits needed.
- A **Nerd Font** selected in your terminal for the glyphs (codicons +
  FontAwesome clock). Without one, the icons render as boxes — everything else
  still works.

## Glyphs / troubleshooting

The icon bytes are stored as `\xHH` UTF-8 escapes rather than literal glyphs, so
the file stays pure ASCII and survives copy/paste, GitHub fetches, and Unicode
normalizers (which silently strip the Private Use Area codepoints otherwise).
Keep them escaped if you edit the file. If the glyphs look wrong:

- **Boxes / □ / "tofu":** the terminal isn't using a Nerd Font. Install one and
  select it in the terminal profile:
  - macOS — `brew install --cask font-jetbrains-mono-nerd-font`
  - Linux — drop the `.ttf` into `~/.local/share/fonts`, then `fc-cache -f`
  - Windows — install the `.ttf`, then set it in Windows Terminal / your terminal
- **Literal `\xEE…` shows instead of a glyph:** the script ran under `sh`/dash,
  not bash. Make sure the `statusLine.command` starts with `bash` (see Install).

## Install

```sh
git clone https://github.com/maxwellpothier/statusline.git ~/statusline
```

Or grab just the script:

```sh
mkdir -p ~/statusline
curl -fsSL https://raw.githubusercontent.com/maxwellpothier/statusline/main/statusline-command.sh \
  -o ~/statusline/statusline-command.sh
```

Clone or download the raw file. Do not copy the script out of a rendered web page
or chat transcript; use the URLs above so the bytes arrive exactly as committed.

Then add this block to `~/.claude/settings.json` (point `command` at wherever
you put the script):

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/statusline/statusline-command.sh",
  "refreshInterval": 5
}
```

`refreshInterval` is in seconds. The script is stateless — it just reprints
whatever the latest stdin JSON contains on each refresh.
