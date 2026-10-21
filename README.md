# Clive

**Usage meters and a token budget gate for Claude Code.** One file, no dependencies,
one config file.

```
cntx 48% · sesn 18% · wkly 92%
```

That line sits under your prompt box. Clive adds three things:

1. **`sesn` / `wkly`** — how much of your 5-hour and weekly usage limits you have spent
2. **`cntx`** — how full the context window is, out of 100%
3. **a budget gate** — before a big query is sent, Clive sizes it and asks you to confirm

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/cjguarino/clive/main/install.sh | sh
```

That clones Clive to `~/.clive`, links `~/.local/bin/clive`, and wires both features
into `~/.claude/settings.json` (backing it up first). **Restart Claude Code** and the
meters appear.

Prefer to look before it edits anything:

```sh
CLIVE_NO_WIRE=1 curl -fsSL https://raw.githubusercontent.com/cjguarino/clive/main/install.sh | sh
clive install                 # when you are ready
clive install --no-estimator  # or: meters only, no prompt gating
```

**Requires** Python 3.8+ (macOS and every Linux ship it) and Claude Code 2.x.
No pip install, no npm, no jq, no build step.

Undo everything: `clive uninstall`

---

## 1 & 2. The meters

```sh
clive demo        # preview against sample data -- no session needed
```

```
cntx 48% · sesn 18% · wkly 92%          style = percent  (default)
cntx ████░░░░ · sesn █░░░░░░░           style = bar
cntx ████░░░░ 48% · sesn █░░░░░░░ 18%   style = both
```

Meters turn yellow at 70% and red at 90% (`statusline.thresholds`).

**Pick what shows, and in what order:**

```sh
clive config --set statusline.segments='["context","session","week"]'
```

Note the split: **segment names** are fixed identifiers (`context`, `session`,
`week`, `model`, `dir`, `branch`, `effort`) — those select what to show. The
**labels** are the text on screen, and you rename those freely:

```sh
clive config --set statusline.labels.context=ctx
clive config --set statusline.labels.week=week
```

**How often does it update?** Every turn. Claude Code re-renders the status line on its
own events, and both numbers only change when an API response arrives — context % comes
from the last response's token usage, and the limit windows come from what the API
reports. While Claude is thinking, you are seeing the previous response's numbers.
There is no newer value to show, which is why `refresh_interval_seconds` is `0`.
Set it to `60` if you enable `show_resets`, so the `(2h10m)` countdown stays current.

**If `sesn` and `wkly` never appear:** they come from a Claude subscription. API-key
and Bedrock/Vertex sessions get no limit data, so Clive drops those segments rather
than show a fake `0%`. They also appear only after the session's first response.

---

## 3. The budget gate

Submit something big and the send is held:

```
Clive  this query ~28.7k tokens  (prompt 1.1k + @files 25.6k + reply ~2k)
       context 96.4k (48%) -> 123.1k (61%) after send
       @src/client.ts  25.6k
       over your 15k threshold -- press up-arrow then Enter to send it anyway
       raise it: clive config --set estimator.threshold_tokens=43000
```

**To approve: press ↑ then Enter.** Clive remembers it just gated that exact prompt
and lets the resubmit through. Edit the prompt instead and it is re-estimated.

Under the threshold, Clive is silent. The gate never runs on headless sessions
(`claude -p`, CI), because nobody is there to approve.

```sh
clive config --set estimator.threshold_tokens=30000   # gate less often
clive config --set estimator.always_show=true         # show every estimate
clive off estimator                                   # meters only
```

**The estimate is a heuristic, deliberately.** It is `characters / 4`, plus the real
byte size of any `@file` you mentioned, plus an assumed reply. It does not call the
token-counting API — that would mean a network round trip and credentials on every
keystroke-submit. Expect it to be within ~10-20%, and tune `chars_per_token` down
toward `3.5` if you mostly paste dense code.

---

## Configuration

Everything lives in `~/.clive/config.json`. Install creates it **empty** — every
setting is at its default until you override it. Partial configs are the intended
shape: anything you leave out follows the default (so improvements reach you on
upgrade), and a malformed file falls back entirely rather than breaking your editor.

`config.example.json` in this repo is the full annotated reference, not a file you
need to copy.

```sh
clive config                      # the merged config, as actually used
clive config --set a.b=value      # typed: 25000 and true become number/bool
clive config --get estimator.threshold_tokens
clive config --edit               # $EDITOR
clive config --defaults           # every key and its default
clive config --reset
```

### `statusline`

| key | default | what it does |
|---|---|---|
| `enabled` | `true` | master switch for the meters |
| `segments` | `["context","session","week","model"]` | which meters, in render order. Also available: `dir`, `branch`, `effort` |
| `style` | `"percent"` | `percent` · `bar` · `both` |
| `labels` | `cntx` / `sesn` / `wkly` | rename any meter |
| `separator` | `" · "` | between segments |
| `colors` | `true` | ANSI color at the thresholds |
| `thresholds.warn` / `.alert` | `70` / `90` | yellow / red |
| `bar_width` | `8` | characters wide |
| `bar_chars` | `"█░"` | filled, empty |
| `show_resets` | `false` | append `(2h10m)` until the window resets |
| `show_context_tokens` | `false` | append `(96.4k)` to the context meter |
| `hide_below` | `0` | hide any meter under this percentage |
| `refresh_interval_seconds` | `0` | `0` = event-driven only. See "How often" above |

### `estimator`

| key | default | what it does |
|---|---|---|
| `enabled` | `true` | master switch for the gate |
| `threshold_tokens` | `15000` | hold the send at or above this |
| `threshold_on` | `"query"` | `query` = what you are adding · `request` = the whole next request, context included |
| `chars_per_token` | `4.0` | lower it for dense code |
| `assumed_output_tokens` | `2000` | the reply cannot be known; this is the assumption |
| `include_file_mentions` | `true` | size `@path` mentions from their real bytes |
| `max_file_bytes` | `2000000` | per-file cap when sizing mentions |
| `confirm_window_seconds` | `300` | how long an approval stays good |
| `always_show` | `false` | note the estimate even when under threshold |
| `skip_slash_commands` | `true` | the hook sees `/cmd` before it expands, so the estimate would be of the typed text |
| `skip_unattended` | `true` | never gate `claude -p` / CI runs |
| `bypass_prefix` | `""` | e.g. `">>"` to send a prompt unchecked. Avoid `!` — that is Claude Code's bash prefix |
| `context_window_tokens` | `200000` | only used for the `->  61%` display |
| `show_cost` | `false` | add a USD figure at API list price. Off because on a subscription you pay in limit percentage, not dollars |
| `pricing` | Opus 5 / Sonnet 5 / Haiku 4.5 | `$/million` used when `show_cost` is on |

---

## Commands

```
clive install [--scope user|project|local] [--no-statusline] [--no-estimator]
clive uninstall [--scope ...] [--purge]
clive status      what is on, and where it is wired
clive doctor      diagnose a setup that is not working
clive demo        preview the status line
clive config      see above
clive on|off meters|estimator|all
```

`--scope project` writes `.claude/settings.json` in the current repo instead of your
home config — useful for making the gate stricter on one codebase.

Upgrade: `git -C ~/.clive pull` (or re-run the curl line).

---

## How it works

No magic, and nothing is patched into Claude Code. Clive is two commands it already
knows how to call, declared in `settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "~/.clive/bin/clive statusline" },
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "~/.clive/bin/clive estimate" } ] }
    ]
  }
}
```

**`clive statusline`** gets Claude Code's status-line JSON on stdin and prints one
line to stdout, which is rendered under your prompt box. It reads
`context_window.used_percentage`, `rate_limits.five_hour.used_percentage`, and
`rate_limits.seven_day.used_percentage`. Any error prints nothing — a status line
should never be the reason your editor shows a problem.

**`clive estimate`** is a `UserPromptSubmit` hook, which runs before the prompt is
sent. Exit 0 lets it through; exit 2 blocks the send and shows stderr **to you only**,
never to Claude. The approval is a SHA-256 of your prompt in
`~/.clive/state/pending.json`, consumed on use and expired by
`confirm_window_seconds`. Every failure path exits 0 — a bug in Clive must not stop
you from talking to Claude.

Context size in the hook comes from the transcript: Clive tail-reads the JSONL and
takes the last non-sidechain assistant message's `usage` (`input + cache_read +
cache_creation`), which is what is actually in the window.

### Why the status line, and not next to the spinner

There is no hook or setting that renders text beside the thinking indicator — the
status line is the only live surface Claude Code exposes. It stays visible while
Claude works, so it is the right home for a meter, but it does sit below the prompt
box rather than beside the spinner.

---

## Troubleshooting

```sh
clive doctor
```

**Nothing appears after installing.** Restart Claude Code; `statusLine` is read at
startup. Then `clive status` to confirm which settings file it landed in — a
`.claude/settings.json` in your project overrides your home config.

**Only `cntx` appears.** Expected without a Claude subscription, or before the first
response of a session. See the note above.

**The gate will not let a prompt through.** `clive off estimator`, or raise
`estimator.threshold_tokens`. It is config, never a hard block.

**Debug either runtime by hand** — both are plain commands:

```sh
echo '{"context_window":{"used_percentage":42}}' | clive statusline
echo '{"prompt":"hello","cwd":"."}' | clive estimate; echo "exit=$?"
CLIVE_DEBUG=1 clive statusline < /dev/null   # print errors instead of staying silent
```

**Test against a throwaway config** without touching your real setup:

```sh
CLIVE_HOME=/tmp/clive-test clive demo
```

---

## License

MIT
