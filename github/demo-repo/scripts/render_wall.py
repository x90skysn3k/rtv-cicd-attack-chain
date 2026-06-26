#!/usr/bin/env python3
"""Render a static trophy wall from validated submissions."""

from __future__ import annotations

import argparse
import html
import json
from datetime import datetime, timezone
from pathlib import Path

try:
    from .validate_submissions import validate_all
except ImportError:
    from validate_submissions import validate_all


def load_submissions(root: Path) -> list[dict[str, str]]:
    submission_dir = root / "submissions"
    submissions: list[dict[str, str]] = []
    if not submission_dir.exists():
        return submissions

    for path in sorted(submission_dir.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        submissions.append({"handle": payload["handle"], "message": payload["message"]})
    return sorted(submissions, key=lambda item: item["handle"].casefold())


def render_cards(submissions: list[dict[str, str]]) -> str:
    if not submissions:
        return """
        <div class="empty-line">
          <span class="prompt-user">x90sky@rtv-lab</span><span class="prompt-marker"> ~ %</span><span class="muted"> no merged submissions yet</span>
        </div>""".rstrip()

    cards = []
    for submission in submissions:
        handle = html.escape(submission["handle"])
        message = html.escape(submission["message"])
        payload = html.escape(json.dumps(submission, ensure_ascii=False))
        cards.append(
            f"""
        <article class="submission-card">
          <div class="prompt-line"><span class="prompt-user">x90sky@rtv-lab</span><span class="prompt-marker"> ~ %</span><span>cat submissions/{handle}.json</span></div>
          <h2>@{handle}</h2>
          <pre>{payload}</pre>
          <p>{message}</p>
        </article>""".rstrip()
        )
    return "\n".join(cards)


def render_page(submissions: list[dict[str, str]]) -> str:
    count = len(submissions)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    noun = "merge" if count == 1 else "merges"
    cards = render_cards(submissions)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RTV Trophy Wall</title>
  <style>
    :root {{
      color-scheme: dark;
      --terminal-green: #00ff41;
      --terminal-amber: #ffb000;
      --terminal-red: #ff3333;
      --terminal-cyan: #00d4ff;
      --terminal-dim: #33ff41aa;
      --terminal-bg: #0a0a0a;
      --terminal-bg-light: #111111;
      --terminal-border: #1a1a1a;
      --terminal-comment: #666666;
      --white: #f8fafc;
    }}

    * {{ box-sizing: border-box; }}

    ::selection {{
      background: #00ff4133;
      color: var(--terminal-green);
    }}

    body {{
      margin: 0;
      min-height: 100vh;
      background: #000;
      color: var(--terminal-green);
      font: 16px/1.55 ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }}

    .scanlines {{ position: relative; }}

    .scanlines::after {{
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 10;
      background: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0, 0, 0, 0.08) 2px, rgba(0, 0, 0, 0.08) 4px);
    }}

    main {{
      width: min(68rem, calc(100vw - 2rem));
      margin: 0 auto;
      padding: 4rem 0 5rem;
    }}

    .terminal-shell {{
      border: 1px solid var(--terminal-border);
      border-radius: 0.75rem;
      background: rgba(6, 18, 31, 0.82);
      box-shadow: 0 0 40px rgba(82, 255, 122, 0.10);
      overflow: hidden;
    }}

    .terminal-bar {{
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.75rem 1rem;
      border-bottom: 1px solid var(--terminal-border);
      background: rgba(255, 255, 255, 0.03);
      color: var(--terminal-comment);
      font-size: 0.8rem;
    }}

    .dot {{ width: 0.75rem; height: 0.75rem; border-radius: 999px; }}
    .red {{ background: var(--terminal-red); }}
    .amber {{ background: var(--terminal-amber); }}
    .green {{ background: var(--terminal-green); }}

    .terminal-body {{ padding: clamp(1.25rem, 4vw, 3rem); }}

    .prompt-line {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.35rem;
      color: var(--white);
      margin-bottom: 0.85rem;
    }}

    .prompt-user {{ color: var(--terminal-green); }}
    .prompt-marker {{ color: var(--terminal-comment); }}
    .muted {{ color: var(--terminal-comment); }}

    h1 {{
      margin: 0.2rem 0 1rem;
      font-size: clamp(2.4rem, 9vw, 6.8rem);
      line-height: 0.9;
      text-transform: uppercase;
      text-shadow: 0 0 24px rgba(82, 255, 122, 0.32);
    }}

    .lede {{
      max-width: 62rem;
      color: var(--terminal-dim);
      font-size: clamp(1rem, 2vw, 1.25rem);
    }}

    .stats {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr));
      gap: 1rem;
      margin: 2rem 0;
    }}

    .stat {{
      border: 1px solid rgba(82, 255, 122, 0.32);
      background: rgba(0, 255, 65, 0.06);
      padding: 1rem;
    }}

    .stat b {{ display: block; color: var(--white); font-size: 2rem; }}

    .wall {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
      gap: 1rem;
      margin-top: 2rem;
    }}

    .submission-card {{
      border: 1px solid rgba(0, 212, 255, 0.28);
      background: linear-gradient(145deg, rgba(0, 212, 255, 0.08), rgba(0, 255, 65, 0.05));
      padding: 1rem;
      min-height: 12rem;
    }}

    .submission-card h2 {{
      margin: 0.2rem 0 0.75rem;
      color: var(--white);
      font-size: 1.4rem;
    }}

    .submission-card pre {{
      white-space: pre-wrap;
      word-break: break-word;
      color: var(--terminal-comment);
      font-size: 0.78rem;
      margin: 0 0 0.75rem;
    }}

    .submission-card p {{ margin: 0; color: var(--terminal-green); }}

    .empty-line {{
      border: 1px dashed rgba(255, 176, 0, 0.5);
      padding: 1.25rem;
      color: var(--terminal-amber);
    }}

    footer {{
      margin-top: 2rem;
      color: var(--terminal-comment);
      font-size: 0.9rem;
    }}
  </style>
</head>
<body class="scanlines">
  <main>
    <section class="terminal-shell" aria-label="RTV trophy wall">
      <div class="terminal-bar">
        <span class="dot red"></span><span class="dot amber"></span><span class="dot green"></span>
        <span>rtv trophy wall</span>
      </div>
      <div class="terminal-body">
        <div class="prompt-line"><span class="prompt-user">x90sky@rtv-lab</span><span class="prompt-marker"> ~ %</span><span>cat merged-prs.json</span></div>
        <h1>Pipeline owned</h1>
        <p class="lede">Every card below came from a pull request the attendee opened from a fork, merged with a GitHub token recovered through the CI to cloud chain, then rendered by the protected deploy workflow.</p>
        <section class="stats" aria-label="lab stats">
          <div class="stat"><b>{count}</b>{noun}</div>
          <div class="stat"><b>15m</b>STS lifetime</div>
          <div class="stat"><b>0</b>manual approvals</div>
        </section>
        <section class="wall" aria-label="merged attendee submissions">
{cards}
        </section>
        <footer>Generated {generated_at}. Treat CI as production authority.</footer>
      </div>
    </section>
  </main>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Render RTV trophy wall")
    parser.add_argument("root", nargs="?", default=".", help="demo repository root")
    parser.add_argument("--output", default="site/index.html", help="output HTML path")
    args = parser.parse_args()

    root = Path(args.root)
    errors = validate_all(root)
    if errors:
        for error in errors:
            print(error)
        return 1

    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_page(load_submissions(root)), encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
