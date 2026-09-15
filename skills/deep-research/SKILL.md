---
name: deep-research
description: Use when asked to research, investigate, evaluate, or compare a technology, library, architecture, or topic in depth — "deep research X", "should we adopt / migrate to X", "X vs Y for our stack", "current state of X" — and the answer needs several web sources synthesized into a cited report rather than one lookup.
---

# Deep Research

## Overview

Answer a research question the way a careful analyst would, as an orchestrator-worker run: the lead scopes the question and plans angles, cheap retrieval agents each cover one angle and hand back compressed, cited findings, a fresh verifier re-fetches the claims the answer rests on, and the lead synthesizes a report with a confidence label on every finding and writes it into the repo.

**Core principle:** Scale effort to the question, cite only pages someone in this run actually fetched, and say how sure you are — per finding, not in a footnote.

## When to Use

- "Deep research X", "investigate X", "what's the current state of X"
- "Should we adopt / migrate to / replace X with Y" for a stack, library, or architecture
- "Compare X vs Y (vs Z)" where the answer depends on more than one source
- Learning a topic well enough to make or explain a decision

**When NOT to use:** a fact one search settles and nobody asked for a write-up (a version number, a config flag), top-N lists, questions whose evidence sits behind logins or paywalls you can't reach, or literature reviews of academic papers (a different source discipline). Answer those inline.

## Defaults (always apply unless the user overrides)

- **Effort ladder** — classify the question and run the matching row of the table in step 2. Never fan out for a quick question; never run a comparison in one context.
- **Retrieval on a cheap model** — angle, gap, and verifier agents run on the cheapest capable model (Claude Code: `model: sonnet`). Planning, verification triage, and synthesis stay with the lead. Always name the model when dispatching; omitting it inherits the session model.
- **Fetched-or-nothing** — a URL appears in the report, and in every section of every agent's output, only if an agent in this run fetched it and quoted it. Search-result snippets are leads, not evidence.
- **Confidence per finding** — every key finding carries Established / Likely / Contested / Speculative (step 5) and single-source findings say so.
- **Verify before you conclude** — on standard and thorough, a fresh agent re-fetches the load-bearing claims (step 4), at most 12 claims per verifier. Quick has no verifier and no finding above Likely.
- **Agents return text, the lead writes files** — retrieval agents never write the report (Claude Code's Write tool refuses "report" files from subagents anyway).
- **Report to `docs/research/<YYYY-MM-DD>-<slug>.md`** in the current project, executive summary in chat. `AS_OF` is today's date.
- **No nested agents** — angle agents never spawn helpers. With no subagent tool at all, run the angles yourself one after another and say so in the report's Method.

## Workflow

### 1. Clarify — one round, only if needed

Four things must be known before dispatch: **goal** (decide vs learn), **depth** (quick / standard / thorough), **constraints** (stack and versions, time window, exclusions), **output path**. Infer before asking: "should we / which / replace" means *decide*, "what is / landscape / state of" means *learn*; depth is whatever the user said, else the row of the step 2 table the question's shape matches; the output path has a default, so it is never asked for. Ask once, with `AskUserQuestion` (or your harness's equivalent), only for what is still unknown and would change the run — typically the goal or the constraints of a *decide* question — then run to the end without further questions. If you cannot ask (autonomous run, subagent context), pick the sensible default, write the assumption into the report's Scope, and proceed.

### 2. Classify and plan

| Depth | Question shape | Agents | Per-agent budget |
|---|---|---|---|
| **quick** | a definition or overview the user wants written up, "what is X" | none — the lead searches itself, no verifier | 3–8 searches + fetches |
| **standard** | comparison, "should we", 2–4 options | 3 angle agents + 1 verifier | 8–15 tool calls |
| **thorough** | landscape, architecture survey, many options | 5 angle agents + 1 gap agent + 1 verifier | 10–20 tool calls |

Budget to expect: in testing, a standard run spent about 230k tokens across three Sonnet angle agents running 14–33 minutes in parallel, plus about 110k for the verifier. A single-agent pass on the same question cost 90k tokens and 17 minutes, and cited eight pages it never opened.

Derive the angles from the question so they don't overlap; these are the starting sets:

- **Decision / comparison:** (1) official docs, maturity, roadmap of each option · (2) migration path and interop with the current stack · (3) operations: performance, reliability, failure modes, cost · (4) adoption: production reports, issue trackers, who runs it at scale · (5) contrarian: who stayed, who reverted, and why. Standard picks three by what is being decided: a migration takes (1) (2) (3); a greenfield choice takes (1) (3) (4). Contrarian evidence is dropped as an angle only because every brief already demands it.
- **Landscape / learning:** (1) definitions and overview · (2) state of the art and main options · (3) production experience reports · (4) trade-offs and failure modes · (5) critiques and contrarian views.
- **Codebase angle** — when the question names the current project or its stack ("our app", "we use X") and the working directory *is* that project, add one Explore-type agent that maps how X is used here (files, versions, config, tests) with Serena or grep, no web. Its findings feed a "Codebase impact" section.

The **gap agent** (thorough only) runs after the angle agents return: give it the gaps and contradictions the lead found and let it chase only those.

### 3. Dispatch — all agents in one message

Multiple Agent calls in one response run in parallel; one per response runs sequentially. Fill this brief per agent — `<angle>` from step 2, `<question>`, `<constraints>`:

```text
You are one retrieval agent in a parallel deep-research run. Cover ONE angle only: <angle>.
Question: <question>. Constraints: <constraints>. Other agents cover the other angles — stay in yours.

Search strategy: start wide, then narrow. Run 2–3 short queries in different terminology
(add `site:github.com`, `site:<official docs domain>` variants), skim results, then FETCH the
full page of the 3–6 most authoritative hits. Prefer primary sources: official docs, the
project's own repo, changelog, and issue tracker, first-party engineering blogs, benchmarks
that show methodology. Actively look for evidence against the obvious answer.

Blocked page (403/429/bot check/TLS error)? Retry once with
`curl -sL -A "<browser user-agent>" <url>` and strip the HTML. Still blocked? List it under
"Sources not reached" with what you tried and move on. The lead has a browser and will retry it.

Rules: a URL appears anywhere in your output — Findings, Contradictions, Dead ends — only if
you fetched it in this run. A search snippet is a lead, not evidence; "referenced via search"
and "search-assisted extraction" are citations of unfetched pages, so don't make them.
Quote the sentence that supports each claim. Record the publication date. Do not write any
file — return this text:

## Angle: <angle>
### Findings
- <claim> | "<supporting quote, ≤2 sentences>" | <URL fetched> | <publisher>, <date> | Tier <1|2|3>
### Contradictions
- <claim A> (<URL>) vs <claim B> (<URL>)
### Dead ends
- <what you searched for and found nothing on>
### Sources not reached
- <URL> — <403 / 429 / login / timeout> — <what you tried>
### Tool calls: <N> searches, <M> fetches
```

Filled in for angle (3) of a standard decision run, the prompt an agent actually receives:

```text
You are one retrieval agent in a parallel deep-research run. Cover ONE angle only: operations — performance, reliability, failure modes, and cost of Solid Queue compared with Sidekiq.
Question: Should a Rails 7.1 app on Sidekiq (Redis) migrate to Solid Queue? Constraints: Rails 7.1, PostgreSQL, Sidekiq OSS (no Pro/Enterprise), sources from 2024 onward preferred. Other agents cover official docs/maturity and migration path/adoption — stay in yours.
[search strategy, blocked-page, rules, and output-format blocks exactly as above]
```

Dispatch each on `model: sonnet` (or the cheapest capable model your harness offers).

When the agents return, read each finding's **quote**, not its claim — an agent's paraphrase can widen what the source says (in testing, "batch operations to retry failed jobs" came back as "job batches").

### 3b. Recover blocked sources — the lead, with a browser

Union the agents' "Sources not reached". For each one that would change a finding, and only if a browser MCP (Chrome DevTools, Playwright) is loaded in your session, open it there, read `document.body.innerText`, close the page (see "Fetching a blocked page"). Bot checks usually pass in a real browser; TLS errors and login walls never do, and a paywalled page counts as fetched only for the part you could read. Recovered text is a fetch in this run and may be cited; everything still unread stays in "Sources not reached".

### 4. Verify — a fresh agent re-fetches the load-bearing claims

Pick the claims the answer rests on: everything the recommendation depends on, every number (latency, throughput, price, dates), every "X does not support Y". Hand a **fresh** agent only those claims and their URLs — none of the angle agents' narrative, so it cannot confirm itself. **At most 12 claims per verifier**; beyond that, split the list across verifiers dispatched in the same message (one verifier given 20 claims ran for over two hours in testing).

```text
Verify each claim below against the cited URL only. Fetch the URL (retry once with curl and a browser user-agent if blocked); find the passage; return for each:
- <claim> — CONFIRMED (quote) | UNSUPPORTED (page fetched, passage absent or says something else: say what it says) | CONTRADICTED (quote) | UNREACHABLE (what failed)
Do not write any file. Return only the list.
Claims:
1. <claim> — <URL>
2. ...
```

Apply the verdicts: CONFIRMED keeps its label; UNSUPPORTED drops to Speculative with the reason, or is cut if the report doesn't need it; CONTRADICTED becomes Contested with both sides shown; UNREACHABLE gets one browser attempt by the lead (step 3b), then stays only if another fetched source supports it, otherwise it is cut and the URL goes to "Sources not reached".

### 5. Synthesize — the lead writes, by theme

**Source tiers** — tag every source:

| Tier | What counts |
|---|---|
| **1 Primary** | official docs, specs and RFCs, the project's own repo, changelog, and issue tracker, peer-reviewed papers, first-party benchmarks with methodology |
| **2 Reputable secondary** | publications with editorial standards, a team's write-up of its own production use or migration, maintainers of competing projects, reference sites with citations |
| **3 Community / unverified** | personal blogs, forum and Q&A answers, tutorials, newsletters, marketing pages, SEO listicles, AI-generated pages, anything undated or unattributed |

**Confidence labels** — assign one per key finding. *Independent* means different publishers, not one re-posting another.

| Label | Rule |
|---|---|
| **Established** | 2+ independent Tier 1–2 sources agree and the verifier confirmed |
| **Likely** | one Tier 1–2 source, or 2+ Tier 3 sources agree, nothing contradicts |
| **Contested** | Tier 1–2 sources disagree — show both sides |
| **Speculative** | a single Tier 3 source, or a claim the verifier could not confirm |

Fill `report-template.md` (bundled here); delete sections that have nothing in them. A quick run keeps Scope, Executive summary, Key findings, Sources, Sources not reached, and Method, and labels findings without a verifier verdict as at most Likely. Organize by theme, never by agent or by source. Use a comparison table when options are compared. Give a recommendation only when the goal was *decide*, and state the conditions it depends on. Every exact number keeps its source and date next to it. Findings with one source say "(single source)".

### 6. Persist and report

Write the report to the output path (default `docs/research/<YYYY-MM-DD>-<slug>.md`, create the directory). In chat, post: answer status (answered / partially / not answerable), the recommendation if any, three to five key findings with their labels, the file path, and the count of sources not reached. Don't paste the whole report.

## Fetching a blocked page

Agents and verifiers use the curl step; the browser step is the lead's (step 3b).

```bash
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"
curl -sL -A "$UA" -H "Accept: text/html" "$URL" | python3 -c '
import sys, re, html
t = sys.stdin.read()
t = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", t, flags=re.S | re.I)
t = html.unescape(re.sub(r"<[^>]+>", " ", t))
print(re.sub(r"\s+", " ", t)[:15000])'
```

Still blocked, and the lead has a browser MCP loaded (in Claude Code these tools are deferred — load them with ToolSearch first):

- **Chrome DevTools MCP:** `new_page(url)` → `evaluate_script(pageId, () => document.body.innerText.slice(0, 15000))` → `close_page`. Take the text inline — the MCP can't write files outside its workspace roots.
- **Playwright MCP:** `browser_navigate(url)` → `browser_evaluate(() => document.body.innerText.slice(0, 15000))` → `browser_close`.

Neither available or still blocked → "Sources not reached", with what was tried.

## Common mistakes

- Citing a URL because "the search snippet was substantive enough", or slipping one into Contradictions as "referenced via search" → fetch it or drop it. Snippets are leads; the report cites only fetched pages.
- Reporting exact latency, throughput, or price figures whose origin nobody opened → the verifier fetches the origin; unconfirmed numbers are Speculative or cut.
- Reading an agent's claim instead of its quote → the paraphrase can be broader than the source. Build findings from the quotes.
- One verifier with 20 claims → hours of serial fetching. Cap at 12 and split across parallel verifiers.
- Sending agents to a browser MCP → they may not see the tools, and parallel agents collide on one browser. The lead recovers blocked pages after the agents return.
- One blanket "note on source quality" at the end → label every key finding; readers weigh claims one at a time.
- Running a comparison in a single context → one long serial pass, context full of raw pages. Use the ladder and let agents compress.
- Asking retrieval agents to write the report file → they return text; the lead writes.
- Overlapping angles → duplicate findings and wasted calls. Keep angles disjoint and name the others in each brief.
- Counting a re-post as a second source → independence means a different publisher with its own evidence.
- Giving the verifier the angle agents' narrative → it confirms the narrative. Claims and URLs only.
- Skipping the clarify round when *decide* vs *learn* is unclear → a recommendation nobody asked for, or a survey when a decision was needed.
- Omitting "Sources not reached" and "Dead ends" → readers can't tell what was checked from what was missed.
