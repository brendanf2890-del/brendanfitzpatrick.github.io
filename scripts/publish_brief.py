#!/usr/bin/env python3
"""
publish_brief.py — Generate a daily nat gas brief HTML page and prepend an
entry to posts/index.html.

Usage:
    python3 scripts/publish_brief.py <path-to-data.json>

Output:
    posts/<date>-natgas-brief.html   (created / overwritten)
    posts/index.html                 (new entry prepended to brief-list)
"""

import json
import os
import sys
from datetime import date

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSTS_DIR = os.path.join(REPO_ROOT, "posts")
INDEX_PATH = os.path.join(POSTS_DIR, "index.html")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sentiment_class(s):
    return {"bear": "val-bear", "bull": "val-bull", "neutral": "val-neutral"}.get(s or "", "")


def dev_class(val):
    if val < 0:
        return "val-bear"
    if val > 0:
        return "val-bull"
    return "val-neutral"


def fmt_dev(val):
    if val > 0:
        return f"+{val}"
    if val < 0:
        return f"–{abs(val)}"
    return "0"


def td(content, css=""):
    if css:
        return f'<td class="{css}">{content}</td>'
    return f"<td>{content}</td>"


def td_attr(sentiment):
    cls = sentiment_class(sentiment)
    return f' class="{cls}"' if cls else ""


def weather_rows_html(regions):
    rows = []
    for r in regions:
        name = f"<strong>{r['name']}</strong>" if r.get("bold") else r["name"]
        dn, dy = r["dev_normal"], r["dev_lastyear"]
        rows.append(
            f"                <tr>{td(name)}{td(r['hdds'])}"
            f"{td(fmt_dev(dn), dev_class(dn))}"
            f"{td(fmt_dev(dy), dev_class(dy))}</tr>"
        )
    return "\n".join(rows)


def risk_flags_html(flags):
    parts = []
    for i, f in enumerate(flags, 1):
        parts.append(
            f"        <li>\n"
            f"            <span class=\"flag-num\">{i}</span>\n"
            f"            <div class=\"flag-body\"><strong>{f['title']}</strong>"
            f" {f['body_html']}</div>\n"
            f"        </li>"
        )
    return "\n".join(parts)


def actions_html(actions):
    return "\n".join(f"        <li>{a}</li>" for a in actions)


# ---------------------------------------------------------------------------
# HTML generation
# ---------------------------------------------------------------------------

def generate_brief(d):
    dt = date.fromisoformat(d["date"])
    display_date = dt.strftime("%A, %B %-d, %Y")
    iso_date = d["date"]

    s = d["storage"]
    p = d["production"]
    w = d["weather"]

    wc_attr  = td_attr(s.get("weekly_change_sentiment", ""))
    v5_attr  = td_attr(s.get("vs_5yr_avg_sentiment", ""))
    ytd_attr = td_attr(p.get("ytd_growth_sentiment", ""))

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Nat Gas Brief — {iso_date} | Brendan Fitzpatrick</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            line-height: 1.6;
            color: #2c3e50;
            background-color: #ffffff;
        }}

        html {{ scroll-behavior: smooth; }}

        .site-header {{
            padding: 24px 24px 16px;
            max-width: 900px;
            margin: 0 auto;
            border-bottom: 2px solid #003a70;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .site-header a {{
            color: #003a70;
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            border-bottom: 1px solid #003a70;
        }}

        .site-header .brand {{
            font-size: 16px;
            font-weight: 700;
            color: #003a70;
            border: none;
        }}

        .brief-wrap {{
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 24px 80px;
        }}

        .brief-meta {{
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }}

        .brief-label {{
            background: #003a70;
            color: white;
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 1px;
            text-transform: uppercase;
            padding: 3px 8px;
            border-radius: 3px;
        }}

        .brief-date {{
            font-size: 13px;
            color: #888;
        }}

        .brief-title {{
            font-size: 26px;
            font-weight: 700;
            color: #003a70;
            margin-bottom: 6px;
            letter-spacing: -0.3px;
        }}

        .brief-subtitle {{
            font-size: 14px;
            color: #4a7fb5;
            margin-bottom: 32px;
        }}

        h2 {{
            font-size: 17px;
            color: #003a70;
            font-weight: 700;
            margin-top: 40px;
            margin-bottom: 14px;
            padding-bottom: 8px;
            border-bottom: 1px solid #e0e4e8;
        }}

        h3 {{
            font-size: 14px;
            color: #003a70;
            font-weight: 600;
            margin-top: 24px;
            margin-bottom: 10px;
        }}

        p {{
            font-size: 14px;
            color: #333;
            margin-bottom: 14px;
        }}

        .callout {{
            background: #f7f9fb;
            border-left: 3px solid #003a70;
            padding: 14px 18px;
            border-radius: 0 4px 4px 0;
            margin-bottom: 16px;
        }}

        .callout p {{
            margin-bottom: 0;
            font-size: 13px;
            color: #2c3e50;
        }}

        .callout strong {{ color: #003a70; }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            margin-bottom: 20px;
        }}

        th {{
            background: #003a70;
            color: white;
            padding: 9px 14px;
            text-align: left;
            font-weight: 600;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        td {{
            padding: 9px 14px;
            border-bottom: 1px solid #f0f0f0;
            color: #333;
        }}

        tr:hover {{ background: #f7f9fb; }}

        td.val-bear {{ color: #c0392b; font-weight: 700; }}
        td.val-bull {{ color: #1a8a3f; font-weight: 700; }}
        td.val-neutral {{ color: #c78c00; font-weight: 700; }}

        .table-wrap {{
            background: white;
            border: 1px solid #e0e4e8;
            border-radius: 4px;
            overflow: hidden;
            margin-bottom: 24px;
        }}

        .table-label {{
            font-size: 11px;
            color: #003a70;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            padding: 12px 14px 8px;
            border-bottom: 1px solid #e0e4e8;
            background: #f7f9fb;
        }}

        .risk-flags {{
            list-style: none;
            padding: 0;
            margin-bottom: 24px;
        }}

        .risk-flags li {{
            display: flex;
            gap: 12px;
            padding: 14px 16px;
            border: 1px solid #e0e4e8;
            border-radius: 4px;
            margin-bottom: 10px;
            background: white;
        }}

        .risk-flags li:hover {{ background: #f7f9fb; }}

        .flag-num {{
            flex-shrink: 0;
            width: 22px;
            height: 22px;
            background: #c0392b;
            color: white;
            font-size: 11px;
            font-weight: 700;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-top: 1px;
        }}

        .flag-body {{
            font-size: 13px;
            color: #333;
            line-height: 1.6;
        }}

        .flag-body strong {{ color: #003a70; }}

        .actions-list {{
            counter-reset: action-counter;
            list-style: none;
            padding: 0;
            margin-bottom: 24px;
        }}

        .actions-list li {{
            counter-increment: action-counter;
            display: flex;
            gap: 12px;
            padding: 12px 16px;
            border-left: 3px solid #4a7fb5;
            background: #f7f9fb;
            margin-bottom: 8px;
            border-radius: 0 4px 4px 0;
            font-size: 13px;
            color: #333;
        }}

        .actions-list li::before {{
            content: counter(action-counter);
            flex-shrink: 0;
            width: 20px;
            height: 20px;
            background: #4a7fb5;
            color: white;
            font-size: 11px;
            font-weight: 700;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-top: 1px;
        }}

        .primers {{
            background: #f7f9fb;
            border: 1px solid #e0e4e8;
            border-radius: 4px;
            padding: 14px 18px;
            font-size: 12px;
            color: #666;
            margin-top: 32px;
        }}

        .primers strong {{ color: #003a70; }}

        .back-link {{
            display: inline-flex;
            align-items: center;
            gap: 6px;
            color: #4a7fb5;
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 28px;
        }}

        .back-link:hover {{ color: #003a70; }}
    </style>
</head>
<body>

<div class="site-header">
    <span class="brand">Brendan Fitzpatrick</span>
    <a href="/posts/">← All Briefs</a>
</div>

<div class="brief-wrap">

    <a href="/posts/" class="back-link">← Market Briefs</a>

    <div class="brief-meta">
        <span class="brief-label">Daily Brief</span>
        <span class="brief-date">{display_date}</span>
    </div>
    <h1 class="brief-title">Natural Gas — Daily Start-of-Day Brief</h1>
    <p class="brief-subtitle">EIA Storage · EIA-914 Production · NOAA Weather · VP Risk Flags</p>

    <!-- ===== 1. EIA STORAGE ===== -->
    <h2>1 · EIA Storage — Week Ending {s['week_ending']} (Released {s['release_date']})</h2>

    <div class="table-wrap">
        <div class="table-label">Working Gas in Storage</div>
        <table>
            <thead>
                <tr><th>Metric</th><th>Value</th></tr>
            </thead>
            <tbody>
                <tr><td>Working gas</td><td>{s['working_gas_bcf']} Bcf</td></tr>
                <tr><td>Weekly change</td><td{wc_attr}>{s['weekly_change']}</td></tr>
                <tr><td>vs. 5-yr average</td><td{v5_attr}>{s['vs_5yr_avg']}</td></tr>
                <tr><td>vs. year-ago</td><td>{s['vs_year_ago']}</td></tr>
                <tr><td>5-yr avg</td><td>{s['five_yr_avg_bcf']} Bcf</td></tr>
                <tr><td>NYMEX prompt close</td><td>{s['nymex_close']}</td></tr>
            </tbody>
        </table>
    </div>

    <div class="callout">
        <p>{s['callout_html']}</p>
    </div>

    <p>{s['narrative_html']}</p>

    <!-- ===== 2. EIA-914 PRODUCTION ===== -->
    <h2>2 · EIA-914 Production</h2>

    <div class="table-wrap">
        <div class="table-label">Dry Gas Output</div>
        <table>
            <thead>
                <tr><th>Metric</th><th>Value</th><th>Source</th></tr>
            </thead>
            <tbody>
                <tr><td>Dry gas (real-time estimate)</td><td><strong>{p['realtime_estimate']}</strong></td><td>Weekly storage supplement</td></tr>
                <tr><td>Dry gas ({p['monthly_actuals_period']} actuals, EIA-914)</td><td>{p['monthly_actuals']}</td><td>EIA Natural Gas Monthly</td></tr>
                <tr><td>YTD growth vs. prior year</td><td{ytd_attr}>{p['ytd_growth']}</td><td>AGA/S&amp;P Global</td></tr>
                <tr><td>Northeast (Appalachian)</td><td>{p['northeast_output']}</td><td>Slight shoulder-season pullback</td></tr>
            </tbody>
        </table>
    </div>

    <p>{p['record_note_html']}</p>

    <h3>Regional Color</h3>
    <p>{p['regional_html']}</p>
    <p>{p['waha_html']}</p>

    <!-- ===== 3. NOAA WEATHER ===== -->
    <h2>3 · NOAA Weather — CPC HDD, Week Ending {w['week_ending']}</h2>

    <div class="table-wrap">
        <div class="table-label">Heating Degree Days by Region</div>
        <table>
            <thead>
                <tr><th>Region</th><th>HDDs This Week</th><th>Dev from Normal</th><th>Dev from Last Yr</th></tr>
            </thead>
            <tbody>
{weather_rows_html(w['regions'])}
            </tbody>
        </table>
    </div>

    <p>{w['season_html']}</p>

    <div class="callout">
        <p>{w['forward_html']}</p>
    </div>

    <!-- ===== RISK FLAGS ===== -->
    <h2>VP Risk Flags</h2>

    <ul class="risk-flags">
{risk_flags_html(d['risk_flags'])}
    </ul>

    <!-- ===== NEXT ACTIONS ===== -->
    <h2>Next Actions — 24–72 hrs</h2>

    <ol class="actions-list">
{actions_html(d['actions'])}
    </ol>

    <!-- ===== PRIMERS ===== -->
    <div class="primers">
        <strong>Primers exercised:</strong> {d['primers']} &nbsp;|&nbsp;
        <strong>Sim to deepen:</strong> {d['sim']}
    </div>

</div>

</body>
</html>"""


# ---------------------------------------------------------------------------
# Index update
# ---------------------------------------------------------------------------

def index_entry(d):
    dt = date.fromisoformat(d["date"])
    display_date = dt.strftime("%B %-d, %Y")
    iso_date = d["date"]
    return (
        f'        <li class="brief-item">\n'
        f'            <a href="/posts/{iso_date}-natgas-brief.html">\n'
        f'                <div class="brief-item-meta">\n'
        f'                    <span class="brief-tag">Natural Gas</span>\n'
        f'                    <span class="brief-item-date">{display_date}</span>\n'
        f'                </div>\n'
        f'                <div class="brief-item-title">Daily Nat Gas Brief — {iso_date}</div>\n'
        f'                <div class="brief-item-summary">{d["index_summary"]}</div>\n'
        f'            </a>\n'
        f'        </li>'
    )


def update_index(d):
    with open(INDEX_PATH, "r", encoding="utf-8") as f:
        html = f.read()

    anchor = '<ul class="brief-list">'
    if anchor not in html:
        sys.exit(f'ERROR: anchor "{anchor}" not found in {INDEX_PATH}')

    iso_date = d["date"]
    if f"/posts/{iso_date}-natgas-brief.html" in html:
        print(f"SKIP:     {iso_date} already in {INDEX_PATH} — index not modified")
        return

    entry = index_entry(d)
    updated = html.replace(anchor, anchor + "\n" + entry, 1)

    with open(INDEX_PATH, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Updated:  {INDEX_PATH}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 scripts/publish_brief.py <path-to-data.json>")

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)

    iso_date = d["date"]
    brief_path = os.path.join(POSTS_DIR, f"{iso_date}-natgas-brief.html")

    html = generate_brief(d)
    with open(brief_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Written:  {brief_path}")

    update_index(d)


if __name__ == "__main__":
    main()
