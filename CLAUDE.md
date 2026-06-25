# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this is

A personal portfolio website for **Brendan Fitzpatrick**, a physical
commodities operations professional. It is a **static GitHub Pages site**
served from `brendanfitzpatrick.github.io` — there is **no build step, no
package manager, no framework, and no server-side code**. The site is plain
hand-written HTML with inline `<style>` and `<script>` blocks. Editing a file
and pushing it to the default branch publishes it directly.

The site has two parts:
1. A single-page portfolio (`index.html`) covering focus areas, automation
   tools, an interactive ops-risk dashboard, the settlement pipeline, skills,
   and operational scope.
2. A "Market Briefs" blog section (`posts/`) of daily natural-gas market
   synthesis write-ups.

## Repository layout

```
.
├── index.html                          # Main portfolio page (self-contained: HTML + CSS + Chart.js)
├── README.md                           # One-line project description
├── CLAUDE.md                           # This file
└── posts/                              # "Market Briefs" blog section
    ├── index.html                      # Brief listing / index page
    └── 2026-04-18-natgas-brief.html    # An individual dated brief
```

There are no other directories, config files, or assets. Images, fonts, and
JS libraries are loaded from CDNs or the system font stack — nothing is
vendored locally.

## How it works

- **No build / no install.** There is nothing to compile or `npm install`.
  To preview, open the `.html` files directly in a browser, or serve the repo
  root with any static server (e.g. `python3 -m http.server`).
- **Deployment is git push.** GitHub Pages serves the repository root. Merging
  to the default branch (`main`) is the deploy. There is no `.github/workflows`
  CI — Pages builds automatically from the branch.
- **Charts** use Chart.js v4.4.1, loaded from cdnjs in `index.html`. Chart data
  is hardcoded inline in the `<script>` block at the bottom of the file; it is
  simulated/representative data, not a live feed.
- **Links are root-absolute** (e.g. `/posts/`, `/posts/2026-04-18-natgas-brief.html`).
  This works because the site is served from the domain root. Keep using
  root-absolute paths for internal links so they resolve both on the live site
  and across pages.

## Conventions to follow

These are derived from the existing files — match them when editing or adding pages.

**Styling**
- CSS lives in a single `<style>` block in the `<head>` of each page. There is
  **no shared/external stylesheet** — each HTML file is self-contained and
  duplicates the base styles it needs. When changing shared visual elements
  (header, tables, colors), update each page consistently.
- Brand color palette (reuse these exact values):
  - Primary navy: `#003a70`
  - Steel blue: `#4a7fb5` (and lighter `#7ba3cc`)
  - Status / value colors: green `#1a8a3f`, yellow/amber `#c78c00`, red `#c0392b`
  - Body text: `#2c3e50` / `#333`; muted: `#666` / `#999`
  - Light backgrounds: `#f7f9fb`, `#f0f2f5`, `#e0e4e8` (borders)
- Font stack: `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`.
- Layout containers are centered with `max-width` (1100px on the portfolio,
  900px on briefs) and `margin: 0 auto`.
- The reset `* { margin: 0; padding: 0; box-sizing: border-box; }` is at the top
  of every page.
- Responsive grids use `grid-template-columns: repeat(auto-fit, minmax(...))`.
  There is a `@media (max-width: 768px)` block for mobile tweaks.

**Structure**
- Section blocks in `index.html` are delimited by clearly labeled HTML comment
  banners (e.g. `<!-- ====== 3. OPS RISK DASHBOARD ====== -->`). Preserve this
  commenting style when adding sections.
- The sticky nav bar (`.nav-bar`) anchors to section `id`s. If you add/remove a
  portfolio section, update the nav links and the scroll-spy section list at the
  bottom of the script accordingly.

**JavaScript**
- Vanilla JS only, in a trailing `<script>` block. No modules, no bundler.
- Color constants are declared at the top of the script and reused across charts.

## Adding a new Market Brief

Briefs follow a fixed pattern. To add one:

1. Create `posts/YYYY-MM-DD-<slug>.html` (date-prefixed filename, e.g.
   `2026-04-18-natgas-brief.html`). The simplest approach is to **copy the most
   recent brief** and replace its content — this inherits the full brief stylesheet
   and structure (site header, `.brief-meta` label/date, section `<h2>`s, the
   `.table-wrap` tables, `.callout` boxes, `.risk-flags` list, `.actions-list`,
   and `.primers` footer).
2. Update the `<title>`, `.brief-date`, `.brief-title`, and body content.
3. Add a new `<li class="brief-item">` to the top of the list in
   `posts/index.html` linking to the new file, with its tag, date, title, and
   summary.
4. Keep the value-coloring convention in tables: `val-bear` (red, bearish),
   `val-bull` (green, bullish), `val-neutral` (amber).

## Git workflow

- Active development branch for the current task: `claude/claude-md-docs-1e7nnj`.
- Develop on the designated feature branch, commit with clear messages, and push
  with `git push -u origin <branch-name>`.
- **Do not open a pull request unless explicitly asked.**
- Do not push directly to `main` without explicit permission — merging to `main`
  publishes the live site.

## Content accuracy

The Market Briefs contain real market figures and the portfolio cites specific
experience and metrics. Treat factual content (storage numbers, production
figures, employment history, claimed metrics) as the owner's data — do not
invent or alter figures. When adding briefs, fill in real values; when unsure,
ask rather than fabricate.
