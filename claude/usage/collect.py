#!/usr/bin/env python3
"""Claude Code 利用量の集計とダッシュボード生成。

~/.claude/projects/**/*.jsonl を全スキャンして日別サマリを再構築し、
durable な ~/.claude/usage/daily-usage.jsonl にマージしたうえで、
自己完結の静的ページ ~/.claude/usage/dashboard.html を生成する。

標準ライブラリのみで動作する。SessionStart フックから起動される想定。
"""

from __future__ import annotations

import glob
import json
import os
from collections import defaultdict
from datetime import datetime

HOME = os.path.expanduser("~")
PROJECTS_GLOB = os.path.join(HOME, ".claude", "projects", "**", "*.jsonl")
OUT_DIR = os.path.join(HOME, ".claude", "usage")
DATA_PATH = os.path.join(OUT_DIR, "daily-usage.jsonl")
HTML_PATH = os.path.join(OUT_DIR, "dashboard.html")

TOKEN_KINDS = ("input", "output", "cache_creation", "cache_read")
USAGE_KEYS = {
    "input": "input_tokens",
    "output": "output_tokens",
    "cache_creation": "cache_creation_input_tokens",
    "cache_read": "cache_read_input_tokens",
}


def _empty_tokens() -> dict[str, int]:
    return {k: 0 for k in TOKEN_KINDS}


def _empty_day(date: str) -> dict:
    return {
        "date": date,
        "totals": _empty_tokens(),
        "by_model": {},
        "by_project": {},
        "by_hour": {str(h): 0 for h in range(24)},
        "messages": 0,
        "sessions": 0,
        "agents": {},
        "skills": {},
        "mcp": {},
    }


def _add_tokens(dst: dict[str, int], usage: dict) -> int:
    """usage からトークンを dst に加算し、加算した総量を返す。"""
    total = 0
    for kind, src_key in USAGE_KEYS.items():
        v = usage.get(src_key) or 0
        dst[kind] += v
        total += v
    return total


def _bump(d: dict, key: str) -> None:
    d[key] = d.get(key, 0) + 1


def scan_raw_logs() -> dict[str, dict]:
    """生ログを全スキャンして date -> サマリ record の dict を返す。"""
    days: dict[str, dict] = {}
    seen_token: set[str] = set()  # トークン/メッセージ数の重複計上を防ぐ
    seen_tool: set[str] = set()  # tool 起動回数の重複計上を防ぐ(別管理)
    session_sets: dict[str, set] = defaultdict(set)

    for path in glob.glob(PROJECTS_GLOB, recursive=True):
        try:
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if rec.get("type") != "assistant":
                        continue
                    msg = rec.get("message") or {}
                    usage = msg.get("usage")
                    if not isinstance(usage, dict):
                        continue

                    ts = rec.get("timestamp")
                    if not ts:
                        continue
                    try:
                        dt = datetime.fromisoformat(
                            ts.replace("Z", "+00:00")
                        ).astimezone()  # システムローカル(JST)へ
                    except ValueError:
                        continue
                    date = dt.strftime("%Y-%m-%d")
                    hour = str(dt.hour)

                    msg_id = msg.get("id")
                    day = days.get(date)
                    if day is None:
                        day = _empty_day(date)
                        days[date] = day

                    # --- トークン / メッセージ数 / セッション(id で重複除去) ---
                    if msg_id is None or msg_id not in seen_token:
                        if msg_id:
                            seen_token.add(msg_id)
                        _add_tokens(day["totals"], usage)
                        model = msg.get("model") or "unknown"
                        cwd = rec.get("cwd") or ""
                        project = os.path.basename(cwd.rstrip("/")) or "unknown"
                        total = _add_tokens(
                            day["by_model"].setdefault(model, _empty_tokens()), usage
                        )
                        _add_tokens(
                            day["by_project"].setdefault(project, _empty_tokens()), usage
                        )
                        day["by_hour"][hour] += total
                        day["messages"] += 1
                        sid = rec.get("sessionId")
                        if sid:
                            session_sets[date].add(sid)

                    # --- tool 起動回数(同一 id が tool 有無で二重記録されるため別 dedup) ---
                    content = msg.get("content")
                    if isinstance(content, list):
                        relevant = [
                            b for b in content
                            if isinstance(b, dict) and b.get("type") == "tool_use"
                            and _tool_bucket(b.get("name")) is not None
                        ]
                        if relevant and (msg_id is None or msg_id not in seen_tool):
                            if msg_id:
                                seen_tool.add(msg_id)
                            for b in relevant:
                                name = b.get("name")
                                inp = b.get("input") or {}
                                bucket = _tool_bucket(name)
                                if bucket == "agents":
                                    key = inp.get("subagent_type") or "unknown"
                                elif bucket == "skills":
                                    key = inp.get("skill") or "unknown"
                                else:  # mcp
                                    parts = name.split("__")
                                    key = parts[1] if len(parts) >= 2 and parts[1] else "unknown"
                                _bump(day[bucket], key)
        except OSError:
            continue

    for date, day in days.items():
        day["sessions"] = len(session_sets.get(date, ()))

    return days


def _tool_bucket(name):
    """tool 名を集計バケツ(agents / skills / mcp)に分類する。対象外なら None。"""
    if name == "Agent":
        return "agents"
    if name == "Skill":
        return "skills"
    if isinstance(name, str) and name.startswith("mcp__"):
        return "mcp"
    return None


def load_existing() -> dict[str, dict]:
    """既存 daily-usage.jsonl を date -> record の dict で読み込む。"""
    days: dict[str, dict] = {}
    if not os.path.exists(DATA_PATH):
        return days
    with open(DATA_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            date = rec.get("date")
            if date:
                days[date] = rec
    return days


def write_data(days: dict[str, dict]) -> list[dict]:
    """date 昇順で daily-usage.jsonl に書き出し、レコード配列を返す。"""
    records = [days[d] for d in sorted(days)]
    tmp = DATA_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True))
            f.write("\n")
    os.replace(tmp, DATA_PATH)
    return records


def write_html(records: list[dict]) -> None:
    data_json = json.dumps(records, ensure_ascii=False)
    html = HTML_TEMPLATE.replace("/*__DATA__*/", data_json)
    tmp = HTML_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(html)
    os.replace(tmp, HTML_PATH)


HTML_TEMPLATE = r"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Claude Code 利用量ダッシュボード</title>
<style>
  :root {
    --bg: #15171c; --panel: #1d2027; --border: #2c303a;
    --fg: #e6e8ec; --muted: #8a909c;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px; background: var(--bg); color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", "Hiragino Sans", sans-serif;
    line-height: 1.5;
  }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .sub { color: var(--muted); font-size: 13px; margin-bottom: 20px; }
  .cards { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 24px; }
  .card {
    background: var(--panel); border: 1px solid var(--border); border-radius: 10px;
    padding: 14px 16px; min-width: 120px;
  }
  .card .label { color: var(--muted); font-size: 12px; }
  .card .value { font-size: 22px; font-weight: 600; margin-top: 2px; }
  section {
    background: var(--panel); border: 1px solid var(--border); border-radius: 10px;
    padding: 16px 18px; margin-bottom: 20px;
  }
  section h2 { font-size: 15px; margin: 0 0 14px; }
  .legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 12px; color: var(--muted); margin-bottom: 10px; }
  .legend span { display: inline-flex; align-items: center; gap: 5px; }
  .legend i { width: 11px; height: 11px; border-radius: 2px; display: inline-block; }
  .scroll { overflow-x: auto; }
  .empty { color: var(--muted); font-size: 13px; }
  svg { display: block; }
  svg text { fill: var(--muted); font-size: 11px; }
  .bar-label { fill: var(--fg); }

  html { scroll-behavior: smooth; }
  .main { margin-left: 220px; }
  section { scroll-margin-top: 16px; }
  .toc {
    position: fixed; top: 24px; left: 24px; width: 184px;
    max-height: calc(100vh - 48px); overflow-y: auto;
    background: var(--panel); border: 1px solid var(--border);
    border-radius: 10px; padding: 12px; font-size: 13px; z-index: 10;
  }
  .toc h3 { font-size: 11px; color: var(--muted); margin: 0 0 8px; letter-spacing: .06em; text-transform: uppercase; }
  .toc a {
    display: block; color: var(--muted); text-decoration: none;
    padding: 5px 8px; border-radius: 6px; border-left: 2px solid transparent;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .toc a:hover { background: #2c303a; color: var(--fg); }
  .toc a.active { background: #2c303a; color: var(--fg); border-left-color: #6ea8fe; }
  @media (max-width: 920px) {
    .toc { display: none; }
    .main { margin-left: 0; }
  }
</style>
</head>
<body>
<nav class="toc" id="toc">
  <h3>メニュー</h3>
  <a href="#sec-daily">日別トークン</a>
  <a href="#sec-cache">日別キャッシュ読込</a>
  <a href="#sec-messages">日別メッセージ数</a>
  <a href="#sec-sessions">日別セッション数</a>
  <a href="#sec-project">プロジェクト別</a>
  <a href="#sec-model">モデル別</a>
  <a href="#sec-hour">時間帯別</a>
  <a href="#sec-agent">サブエージェント</a>
  <a href="#sec-skill">スキル</a>
  <a href="#sec-mcp">MCP ツール</a>
</nav>
<div class="main">
<h1>Claude Code 利用量ダッシュボード</h1>
<div class="sub" id="sub"></div>
<div class="cards" id="cards"></div>

<section id="sec-daily">
  <h2>日別トークン推移(入力・出力・キャッシュ作成)</h2>
  <div class="legend" id="legend-daily"></div>
  <div class="scroll" id="chart-daily"></div>
</section>

<section id="sec-cache">
  <h2>日別キャッシュ読込</h2>
  <div class="legend" id="legend-cache"></div>
  <div class="scroll" id="chart-cache"></div>
</section>

<section id="sec-messages">
  <h2>日別メッセージ数(応答)</h2>
  <div class="scroll" id="chart-messages"></div>
</section>

<section id="sec-sessions">
  <h2>日別セッション数</h2>
  <div class="scroll" id="chart-sessions"></div>
</section>

<section id="sec-project">
  <h2>プロジェクト別(総トークン)</h2>
  <div id="chart-project"></div>
</section>

<section id="sec-model">
  <h2>モデル別(総トークン)</h2>
  <div id="chart-model"></div>
</section>

<section id="sec-hour">
  <h2>時間帯別(全期間・総トークン)</h2>
  <div class="scroll" id="chart-hour"></div>
</section>

<section id="sec-agent">
  <h2>サブエージェント起動回数(全期間)</h2>
  <div id="chart-agent"></div>
</section>

<section id="sec-skill">
  <h2>スキル起動回数(全期間)</h2>
  <div id="chart-skill"></div>
</section>

<section id="sec-mcp">
  <h2>MCP ツール利用回数(サーバ別・全期間)</h2>
  <div id="chart-mcp"></div>
</section>
</div>

<script>
const DATA = /*__DATA__*/;
const KINDS = ["input", "output", "cache_creation", "cache_read"];
const KIND_LABEL = { input: "入力", output: "出力", cache_creation: "キャッシュ作成", cache_read: "キャッシュ読込" };
const COLORS = {
  input: "#6ea8fe", output: "#7ee0b8", cache_creation: "#f0b86e", cache_read: "#c89bf0",
  messages: "#7ee0b8", sessions: "#6ea8fe", agent: "#f0b86e", skill: "#c89bf0", mcp: "#e98ea0"
};
const WD = ["日", "月", "火", "水", "木", "金", "土"];
const SVGNS = "http://www.w3.org/2000/svg";

function fmt(n) {
  if (n >= 1e9) return (n / 1e9).toFixed(2) + "B";
  if (n >= 1e6) return (n / 1e6).toFixed(2) + "M";
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "k";
  return String(n);
}
function el(name, attrs, text) {
  const e = document.createElementNS(SVGNS, name);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (text != null) e.textContent = text;
  return e;
}
function recTotal(tok) { return KINDS.reduce((s, k) => s + (tok[k] || 0), 0); }
function sum(arr) { return arr.reduce((s, v) => s + v, 0); }

// --- サマリ ---
function renderSummary() {
  const sub = document.getElementById("sub");
  const cards = document.getElementById("cards");
  if (!DATA.length) {
    sub.textContent = "データがありません。Claude Code を使うと記録が蓄積されます。";
    return;
  }
  const first = DATA[0].date, last = DATA[DATA.length - 1].date;
  const grand = { input: 0, output: 0, cache_creation: 0, cache_read: 0 };
  for (const d of DATA) for (const k of KINDS) grand[k] += d.totals[k] || 0;
  const total = recTotal(grand);
  const msgs = sum(DATA.map(d => d.messages || 0));
  const sess = sum(DATA.map(d => d.sessions || 0));
  sub.textContent = `${first} 〜 ${last} / ${DATA.length} 日分`;

  const items = [
    { label: "総トークン", value: fmt(total) },
    { label: "入力", value: fmt(grand.input) },
    { label: "出力", value: fmt(grand.output) },
    { label: "キャッシュ作成", value: fmt(grand.cache_creation) },
    { label: "キャッシュ読込", value: fmt(grand.cache_read) },
    { label: "メッセージ数", value: msgs.toLocaleString() },
    { label: "セッション数", value: sess.toLocaleString() },
  ];
  for (const it of items) {
    const c = document.createElement("div");
    c.className = "card";
    c.innerHTML = `<div class="label">${it.label}</div><div class="value">${it.value}</div>`;
    cards.appendChild(c);
  }
}

// --- 日別グラフ共通: X 軸(日付 + 曜日)を描く ---
function drawDailyAxis(svg, padL, plotTop, plotH, barW, gap) {
  DATA.forEach((d, i) => {
    const cx = padL + i * (barW + gap) + barW / 2;
    const ly = plotTop + plotH + 14;
    const wd = WD[new Date(d.date + "T00:00:00").getDay()];
    const t = el("text", {
      x: cx, y: ly, "text-anchor": "end", transform: `rotate(-60 ${cx} ${ly})`
    }, `${d.date.slice(5)} (${wd})`);
    if (wd === "日" || wd === "土") t.setAttribute("fill", "#e98ea0");
    svg.appendChild(t);
  });
}
function drawYGrid(svg, padL, padR, plotTop, plotH, w, max) {
  const ticks = 4;
  for (let i = 0; i <= ticks; i++) {
    const y = plotTop + plotH - plotH * i / ticks;
    svg.appendChild(el("line", { x1: padL, y1: y, x2: w - padR, y2: y, stroke: "#2c303a" }));
    svg.appendChild(el("text", { x: padL - 6, y: y + 3, "text-anchor": "end" }, fmt(max * i / ticks)));
  }
}

// --- 日別積み上げ棒(対象 kinds を指定) ---
function buildLegend(hostId, kinds) {
  const legend = document.getElementById(hostId);
  for (const k of kinds) {
    const s = document.createElement("span");
    s.innerHTML = `<i style="background:${COLORS[k]}"></i>${KIND_LABEL[k]}`;
    legend.appendChild(s);
  }
}
function renderDailyChart(hostId, kinds) {
  const host = document.getElementById(hostId);
  if (!DATA.length) { host.innerHTML = '<div class="empty">データなし</div>'; return; }
  const dayTotal = d => kinds.reduce((s, k) => s + (d.totals[k] || 0), 0);
  const barW = 22, gap = 8, padL = 64, padR = 16, padT = 10, padB = 64;
  const h = 250, plotH = h - padT - padB;
  const w = padL + padR + DATA.length * (barW + gap);
  const max = Math.max(1, ...DATA.map(dayTotal));
  const svg = el("svg", { width: w, height: h, viewBox: `0 0 ${w} ${h}` });
  drawYGrid(svg, padL, padR, padT, plotH, w, max);
  DATA.forEach((d, i) => {
    const x = padL + i * (barW + gap);
    let y = padT + plotH;
    for (const k of kinds) {
      const v = d.totals[k] || 0;
      if (v <= 0) continue;
      const segH = plotH * v / max;
      y -= segH;
      const r = el("rect", { x, y, width: barW, height: segH, fill: COLORS[k] });
      r.appendChild(el("title", {}, `${d.date} ${KIND_LABEL[k]}: ${v.toLocaleString()}`));
      svg.appendChild(r);
    }
  });
  drawDailyAxis(svg, padL, padT, plotH, barW, gap);
  host.appendChild(svg);
}

// --- 日別単一系列棒(messages / sessions など scalar) ---
function renderDailySeries(hostId, key, color, unit) {
  const host = document.getElementById(hostId);
  if (!DATA.length) { host.innerHTML = '<div class="empty">データなし</div>'; return; }
  const barW = 22, gap = 8, padL = 56, padR = 16, padT = 10, padB = 64;
  const h = 220, plotH = h - padT - padB;
  const w = padL + padR + DATA.length * (barW + gap);
  const max = Math.max(1, ...DATA.map(d => d[key] || 0));
  const svg = el("svg", { width: w, height: h, viewBox: `0 0 ${w} ${h}` });
  drawYGrid(svg, padL, padR, padT, plotH, w, max);
  DATA.forEach((d, i) => {
    const v = d[key] || 0;
    const x = padL + i * (barW + gap);
    const bh = plotH * v / max;
    const y = padT + plotH - bh;
    const r = el("rect", { x, y, width: barW, height: bh, rx: 2, fill: color });
    r.appendChild(el("title", {}, `${d.date}: ${v.toLocaleString()}${unit || ""}`));
    svg.appendChild(r);
  });
  drawDailyAxis(svg, padL, padT, plotH, barW, gap);
  host.appendChild(svg);
}

// --- 横棒(汎用) ---
function renderHBars(hostId, rowsIn) {
  let rows = rowsIn;
  const host = document.getElementById(hostId);
  rows = rows.filter(r => r.value > 0);
  if (!rows.length) { host.innerHTML = '<div class="empty">データなし</div>'; return; }
  rows.sort((a, b) => b.value - a.value);
  const max = Math.max(1, ...rows.map(r => r.value));
  const rowH = 26, gap = 6, padL = 4, padR = 70, labelW = 150;
  const w = 760;
  const barAreaW = w - labelW - padR;
  const h = rows.length * (rowH + gap);
  const svg = el("svg", { width: "100%", height: h, viewBox: `0 0 ${w} ${h}` });
  rows.forEach((r, i) => {
    const y = i * (rowH + gap);
    svg.appendChild(el("text", { x: padL, y: y + rowH / 2 + 4, class: "bar-label" }, r.label));
    const bw = Math.max(1, barAreaW * r.value / max);
    const rect = el("rect", { x: labelW, y, width: bw, height: rowH, rx: 3, fill: r.color || "#6ea8fe" });
    rect.appendChild(el("title", {}, `${r.label}: ${r.value.toLocaleString()}`));
    svg.appendChild(rect);
    svg.appendChild(el("text", { x: labelW + bw + 6, y: y + rowH / 2 + 4 }, fmt(r.value)));
  });
  host.appendChild(svg);
}

function tokenHBars(hostId, field, color, stripPrefix) {
  const agg = {};
  for (const d of DATA) for (const k in d[field]) {
    agg[k] = (agg[k] || 0) + recTotal(d[field][k]);
  }
  const palette = ["#7ee0b8", "#6ea8fe", "#f0b86e", "#c89bf0", "#e98ea0"];
  const rows = Object.entries(agg).map(([label, value], i) => ({
    label: stripPrefix ? label.replace(/^claude-/, "") : label,
    value, color: color || palette[i % palette.length]
  }));
  renderHBars(hostId, rows);
}

function countHBars(hostId, field, color) {
  const agg = {};
  for (const d of DATA) { const m = d[field] || {}; for (const k in m) agg[k] = (agg[k] || 0) + m[k]; }
  renderHBars(hostId, Object.entries(agg).map(([label, value]) => ({ label, value, color })));
}

// --- 時間帯ヒストグラム ---
function renderHour() {
  const host = document.getElementById("chart-hour");
  if (!DATA.length) { host.innerHTML = '<div class="empty">データなし</div>'; return; }
  const hours = new Array(24).fill(0);
  for (const d of DATA) for (let hh = 0; hh < 24; hh++) hours[hh] += (d.by_hour[hh] || 0);
  const max = Math.max(1, ...hours);
  const barW = 22, gap = 8, padL = 56, padR = 12, padT = 10, padB = 28;
  const h = 200, plotH = h - padT - padB;
  const w = padL + padR + 24 * (barW + gap);
  const svg = el("svg", { width: w, height: h, viewBox: `0 0 ${w} ${h}` });
  drawYGrid(svg, padL, padR, padT, plotH, w, max);
  hours.forEach((v, hh) => {
    const x = padL + hh * (barW + gap);
    const bh = plotH * v / max;
    const y = padT + plotH - bh;
    const r = el("rect", { x, y, width: barW, height: bh, rx: 2, fill: "#6ea8fe" });
    r.appendChild(el("title", {}, `${hh}時台: ${v.toLocaleString()}`));
    svg.appendChild(r);
    if (hh % 2 === 0) svg.appendChild(el("text", { x: x + barW / 2, y: h - 10, "text-anchor": "middle" }, hh));
  });
  host.appendChild(svg);
}

renderSummary();
buildLegend("legend-daily", ["input", "output", "cache_creation"]);
renderDailyChart("chart-daily", ["input", "output", "cache_creation"]);
buildLegend("legend-cache", ["cache_read"]);
renderDailyChart("chart-cache", ["cache_read"]);
renderDailySeries("chart-messages", "messages", COLORS.messages, " 件");
renderDailySeries("chart-sessions", "sessions", COLORS.sessions, " 件");
tokenHBars("chart-project", "by_project", "#6ea8fe", false);
tokenHBars("chart-model", "by_model", null, true);
renderHour();
countHBars("chart-agent", "agents", COLORS.agent);
countHBars("chart-skill", "skills", COLORS.skill);
countHBars("chart-mcp", "mcp", COLORS.mcp);

// --- サイドメニュー: スクロール位置に応じてアクティブ表示 ---
(function () {
  const links = [...document.querySelectorAll(".toc a")];
  const byId = {};
  for (const a of links) byId[a.getAttribute("href").slice(1)] = a;
  const obs = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (e.isIntersecting) {
        links.forEach(a => a.classList.remove("active"));
        if (byId[e.target.id]) byId[e.target.id].classList.add("active");
      }
    }
  }, { rootMargin: "-15% 0px -75% 0px" });
  document.querySelectorAll("section[id]").forEach(s => obs.observe(s));
})();
</script>
</body>
</html>
"""


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    fresh = scan_raw_logs()
    days = load_existing()
    days.update(fresh)  # 生ログにある日は新値で上書き、無い古い日は保持
    records = write_data(days)
    write_html(records)


if __name__ == "__main__":
    main()
