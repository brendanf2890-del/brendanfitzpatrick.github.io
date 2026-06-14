# CLAUDE.md

Guidance for AI assistants (and humans) working in this repository.

## What this is

A personal portfolio and blog website for **Brendan Fitzpatrick**, a physical
commodities operations professional. It is a **static site hosted on GitHub
Pages** at `brendanfitzpatrick.github.io`.

There is **no build step, no framework, no dependencies, and no test suite**.
Every page is a self-contained, hand-written HTML file with inline `<style>`
and inline `<script>` blocks. Edit the HTML, commit, push — GitHub Pages
serves it directly.

## Repository layout

```
.
├── index.html                          # Single-page portfolio (the homepage)
├── README.md                           # One-line project description
└── posts/                              # "Market Briefs" blog section
    ├── index.html                      # Brief listing / index page
    └── 2026-04-18-natgas-brief.html    # An individual dated brief
```

- **`index.html`** — The homepage. A long single-page layout with a sticky nav
  and these sections (anchored by `id`): `#focus` (Areas of Focus), `#tools`
  (Risk Automation & Analytics), `#dashboard` (Ops Risk Dashboard with
  Chart.js charts + tables), `#pipeline` (Settlement Pipeline), `#skills`
  (Technical Skills), `#scope` (Operational Scope). Charts are rendered by an
  inline `<script>` at the bottom using **Chart.js loaded from a CDN**
  (`cdnjs.cloudflare.com`). All chart data is hardcoded/simulated.
- **`posts/index.html`** — Lists the daily market briefs. Each brief is a
  `<li class="brief-item">` linking to its page. **Add new briefs here** so
  they appear in the index.
- **`posts/YYYY-MM-DD-<topic>-brief.html`** — An individual brief. The existing
  one is a daily natural-gas brief with sections: EIA Storage, EIA-914
  Production, NOAA Weather, VP Risk Flags, and Next Actions.

## Conventions

Follow the patterns already in the files — consistency matters more than any
external "best practice" here.

- **Self-contained pages.** Each HTML file carries its own `<style>` block.
  There is no shared CSS file; styles are duplicated/adapted per page. When
  creating a page, copy the closest existing file and adjust.
- **Links are root-relative.** Use `/`, `/posts/`, `/posts/<file>.html`
  (matching the GitHub Pages root). Don't use relative `../` paths.
- **Brand color palette** (used consistently across all pages):
  - Navy (primary): `#003a70`
  - Steel blue: `#4a7fb5`, light steel: `#7ba3cc`
  - Status: green `#1a8a3f` (`.status-green`), yellow `#c78c00`
    (`.status-yellow`), red `#c0392b` (`.status-red`)
  - Body text: `#2c3e50`; muted: `#666`/`#999`; borders: `#e0e4e8`
- **Typography:** system font stack
  (`-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`), `line-height: 1.6`.
- **Layout:** centered containers with `max-width` (1100px on the homepage,
  900px in posts) and `margin: 0 auto`. Cards use 4px border-radius, subtle
  hover lift (`transform: translateY(-1px)` + box-shadow).
- **Responsive:** grids use `repeat(auto-fit, minmax(...))`; there is a
  `@media (max-width: 768px)` block on the homepage.
- **Comments:** sections are delimited with banner comments like
  `<!-- ===== 1. EIA STORAGE ===== -->`.
- **Content is real/personal** (contact email, LinkedIn, résumé-style claims).
  The Ops Risk Dashboard numbers and counterparties are explicitly **simulated
  sample data** — keep that framing; don't present them as real.

## Common tasks

### Add a new market brief
1. Copy `posts/2026-04-18-natgas-brief.html` to
   `posts/<YYYY-MM-DD>-<topic>-brief.html`.
2. Update the `<title>`, `.brief-date`, `.brief-title`, `.brief-subtitle`, and
   the section content.
3. Add a new `<li class="brief-item">` entry at the **top** of the list in
   `posts/index.html` (newest first), pointing to the new file with a tag,
   date, title, and summary.

### Edit the homepage
- Edit `index.html` directly. If you add a new section, give it an `id` and add
  a matching `<a href="#id">` to the `.nav-bar nav`. The active-nav-on-scroll
  logic in the bottom `<script>` picks up any `<section>` automatically.

### Add/modify a chart
- Charts live in the inline `<script>` at the bottom of `index.html` using
  `new Chart(document.getElementById('...'), {...})`. Add a matching
  `<canvas id="...">` inside a `.chart-wrapper` in the `#dashboard` section.
  Reuse the predefined color constants (`navy`, `steel`, `green`, etc.).

## Verifying changes

There is no build or CI for the site. To check work:
- Open the HTML file in a browser, or serve locally, e.g.
  `python3 -m http.server` then visit `http://localhost:8000/`.
- Verify internal links resolve, the page renders, and (for the homepage)
  charts draw without console errors (requires internet for the Chart.js CDN).

## Git workflow

- Default branch: `main`. GitHub Pages serves from it.
- Make changes on a feature branch and push; open a PR only when explicitly
  requested.
- Keep commits focused with clear, descriptive messages.
</content>
</invoke>
