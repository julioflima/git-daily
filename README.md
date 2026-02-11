<p align="center">
  <h1 align="center">🪖 git daily</h1>
  <p align="center">
    <strong>Your AI-powered standup report, straight from your Git history.</strong>
  </p>
  <p align="center">
    Never write a daily standup update by hand again.
  </p>
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> •
  <a href="#how-it-works">How it works</a> •
  <a href="#usage">Usage</a> •
  <a href="#time-travel">Time Travel</a> •
  <a href="#context">Context</a> •
  <a href="#requirements">Requirements</a>
</p>

---

```
$ git daily

💻 Fetching commits from 2026-02-10T18:00:00 to 2026-02-11T14:32:10:
💻 Commits found:
- a1b2c3d fix: resolve hydration mismatch on locale switch
- d4e5f6a feat: add translation memory sidebar panel
- 7g8h9ij chore: bump next to 15.1.2

All quiet on the western front 💣🪖:

• Fixed a hydration issue triggered by locale switching
• Added a translation memory sidebar panel
```

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/julioflima/git-daily/main/install.sh | bash
```

The installer handles everything:

- ✔ Checks dependencies (`git`, `curl`, `jq`)
- ✔ Installs to `~/.git-daily`
- ✔ Creates the global `git daily` alias
- ✔ Validates and saves your `OPENAI_API_KEY`

Then just run it inside **any** repo:

```bash
git daily
```

Works globally — every repo, every branch.

<details>
<summary>Manual install</summary>

```bash
git clone https://github.com/julioflima/git-daily.git ~/.git-daily
export OPENAI_API_KEY="sk-..."
git config --global alias.daily '!bash ~/.git-daily/daily.sh'
```

</details>

That's it. One command, instant standup.

## How it works

```
  git log ──→ fetch commits ──→ OpenAI GPT ──→ bullet-point summary
     │            │                  │                  │
     │      (author + date)    (summarize)        (your daily)
     ▼            ▼                  ▼                  ▼
  your repo   filtered logs     AI prompt          terminal output
```

1. **Fetches** your recent commits from `git log` within a time range
2. **Sends** them to OpenAI with a focused prompt that merges related work
3. **Returns** 2–5 concise bullet points — not one per commit, a real summary ready for Slack/standup

## Usage

```bash
# Default — commits since yesterday 6 PM until now
git daily

# Yesterday's full day (00:00 → 24:00)
git daily 'day^1'

# Two days ago (full 24h window)
git daily 'day^2'

# Last Friday (5 days ago)
git daily 'day^5'

# Add context to guide the summary
git daily 'day^1' "focus on layout changes"

# Debug mode — just print the date range, no API call
git daily --print-range
git daily 'day^3' --print-range
```

## Time Travel

The `day^N` syntax lets you look back at any specific day — always a clean **24-hour window**:

| Command | Range |
|---------|-------|
| `git daily` | Yesterday 18:00 → now |
| `git daily 'day^1'` | Yesterday 00:00 → today 00:00 |
| `git daily 'day^2'` | 2 days ago 00:00 → yesterday 00:00 |
| `git daily 'day^3'` | 3 days ago 00:00 → 2 days ago 00:00 |

> **Tip:** Use `--print-range` with any command to preview the time window without hitting the API.

## Context

Pass a quoted string to guide what the AI emphasizes:

```bash
# Highlight frontend work
git daily "focus on layout and CSS changes"

# Emphasize bug fixes
git daily 'day^1' "highlight bug fixes only"

# Prepare for a specific audience
git daily "explain for a non-technical PM"
```

The context is appended to the prompt — your commits stay the same, but the summary shifts focus.

## Requirements

| Tool | Purpose |
|------|---------|
| `bash` | Shell (macOS/Linux) |
| `git` | Commit history |
| `curl` | API requests |
| `jq` | JSON parsing |
| `OPENAI_API_KEY` | OpenAI API access |

Works on **macOS** (BSD date) and **Linux** (GNU date) out of the box.

## Configuration

Edit the top of `daily.sh` to customize:

```bash
AUTHOR_NAME="Julio Lima"    # Your git author name
MODEL="gpt-4o-mini"         # OpenAI model (fast + cheap)
```

## Why?

Because standups should take **zero effort** for the person reporting. Your commits already tell the story — let AI write the summary.

---

<p align="center">
  <sub>All quiet on the western front 💣🪖</sub>
</p>
