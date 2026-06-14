# CLAUDE.md

## What this project is

This is the personal portfolio and blog website for Brendan Fitzpatrick, a
physical commodities operations professional. It's a static website hosted on
GitHub Pages at `brendanfitzpatrick.github.io` — the homepage is a one-page
résumé/portfolio, and the `posts/` section holds dated "Market Briefs"
(currently daily natural-gas write-ups).

## How to run and test it

- Run it: there's no build step. To preview locally, run `python3 -m http.server`
  in the project folder, then open `http://localhost:8000/` in a browser. You
  can also just double-click an `.html` file to open it.
- Run tests: none — this is a hand-written static site with no test suite.
- Build it: n/a. Editing the HTML and pushing is all it takes; GitHub Pages
  serves the files directly.

## Tech stack

- Plain HTML with inline CSS (a `<style>` block inside each page) and a little
  inline JavaScript. No framework, no dependencies installed in the repo.
- Chart.js is loaded from a CDN (only on the homepage) to draw the dashboard
  charts. That's the only external library.

## How I want you to work with me

- I'm light on coding. Explain what you're doing in plain English and skip unexplained jargon.
- Show me your plan before you make changes. Wait for my OK on anything bigger than a tiny edit.
- Keep changes small and focused. One thing at a time.
- After editing, open the page (or describe how to check it) and tell me whether it worked.
- If something is unclear, ask me one question instead of guessing.
- When you finish, give me a two-line summary: what changed, and how I can check it.

## Project conventions

- Match the style of the files that are already here. Each page is
  self-contained, with its own styles — when making a new page, copy the
  closest existing one and adjust it.
- Put new market briefs in the `posts/` folder, named like
  `YYYY-MM-DD-topic-brief.html`, and add a link to them at the top of
  `posts/index.html` (newest first).
- Use the site's navy-blue color scheme (`#003a70` is the main color) and
  root-relative links like `/` and `/posts/` — not `../` style links.
- The dashboard numbers on the homepage are sample/simulated data. Keep them
  labeled that way; don't present them as real figures.

## Guardrails (ask me first before doing any of these)

- Don't delete files or folders without showing me first.
- Don't touch settings, dependencies, or anything outside the task I gave you.
- Never put passwords, API keys, or other secrets in this file or in committed code.

## For long sessions and mobile review

- Commit your work in small steps with clear messages, so I can review it on a small screen.
- Keep each change easy to review on its own. Smaller diffs are easier to approve from a phone.
- If you pause a long task, end with a note: what's done and what's next.
</content>
