# statusline

My custom [Claude Code](https://claude.com/claude-code) status line — a single
self-contained bash script.

```
 <cwd>    <branch>  (● 3)    71.5k (47%)    Opus 4.8 (xhigh)    5% (12:30pm)
```

## Segments

Left to right (each segment hides itself when its data is unavailable):

| Segment | Color | Source |
| --- | --- | --- |
|  repo name | cyan | git toplevel of `cwd` |
|  branch `(● N)` | green / dim | current branch + count of dirty files |
|  session tokens `(N%)` | yellow / dim | tokens from the transcript, as % of the autocompact limit (`AUTOCOMPACT_LIMIT`, default 150k) |
|  model `(effort)` | red / dim | `model.display_name` + `effort.level` from stdin |
|  5h usage `(reset time)` | magenta / dim | `rate_limits.five_hour.used_percentage` (rounded) + local time the 5-hour rolling limit window resets |

The 5-hour usage segment requires a Claude.ai **Pro/Max** subscription and only
appears after the first API response in a session.

## Dependencies

- **bash**, **jq**, **git**
- **`date`** — the reset-time formatting uses BSD `date -r <epoch>` (macOS). On
  Linux, change that line to `date -d "@$reset_epoch"`.
- A **Nerd Font** in your terminal for the glyphs (codicons + FontAwesome
  clock). Without one, the icons render as boxes — the rest still works.

## Install

```sh
git clone <this-repo> ~/statusline
```

Then add this block to `~/.claude/settings.json` (point `command` at wherever
you cloned the script):

```json
"statusLine": {
  "type": "command",
  "command": "bash /Users/<you>/statusline/statusline-command.sh",
  "refreshInterval": 5
}
```

`refreshInterval` is in seconds. The script is stateless — it just reprints
whatever the latest stdin JSON contains on each refresh.
