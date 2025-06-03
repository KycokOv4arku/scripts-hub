"""
Parse Telegram channel export JSON → CSV  (markdown-friendly)

• Input
  - Hard-coded path: JSON_PATH (Telegram “Channel full export” → result.json)
  - No external libraries (pure std-lib)

• Output
  - Creates <result>.csv next to the JSON file
  - Columns:
      id | date | type | from | text_md | …all other top-level keys order-preserved
  - `text` array is flattened to Markdown in column `text_md`
  - `text_entities` is dropped (redundant once text is rendered)

• Rules
  - Unknown `text[*].type` → raw text kept, script won’t crash
  - CSV is written UTF-8 with header row
  - Fancy code blocks preserved: ```lang … ```
  - New/extra message fields automatically become new CSV columns

• Usage
  1. Adjust JSON_PATH if your file lives elsewhere.
  2. Run:  python tg_history_json2csv.py
  3. Check the ✅ print for the row count & path.

Limitations
  - Designed for “channel” exports; DMs/groups should still work but
    haven’t been tested.
  - Expects valid UTF-8 JSON produced by Telegram Desktop/CLI.

🤖Written with GPT o3
Prompt:
text: gimme a python parser to make out of json. csv, where text field
is a human readable md without lossing formating
other fields as u see json have, hardcode these <path> to json
files added: snippet of 5 post to give context of json structure.
"""

import csv
import json
import pathlib

# Provide the export path
JSON_PATH = pathlib.Path("path/to/file/result.json")
if not JSON_PATH.is_file():
    raise SystemExit(f"{JSON_PATH} not found – edit JSON_PATH in the script")
OUT_CSV = JSON_PATH.with_suffix(".csv")


def part_to_md(part):
    """Turn one Telegram text part into Markdown."""
    if isinstance(part, str):
        return part
    t = part.get("type")
    txt = part.get("text", "")
    if t == "plain":
        return txt
    if t == "bold":
        return f"**{txt}**"
    if t == "italic":
        return f"*{txt}*"
    if t == "code":
        return f"`{txt}`"
    if t == "pre":
        lang = part.get("language", "")
        fence = f"```{lang}\n" if lang else "```\n"
        return f"{fence}{txt}\n```"
    if t == "text_link":
        return f'[{txt}]({part.get("href","")})'
    # fallback – unrecognised part type
    return txt


# 2) Load JSON
with JSON_PATH.open(encoding="utf-8") as f:
    data = json.load(f)

# 3) Build rows & master field set
rows, fieldnames = [], set()
for msg in data.get("messages", []):
    row = {}
    for k, v in msg.items():
        if k == "text":  # markdown-ify
            row["text_md"] = (
                "".join(part_to_md(p) for p in v) if isinstance(v, list) else v
            )
        elif k != "text_entities":  # drop raw entity clutter
            row[k] = v
    fieldnames.update(row.keys())
    rows.append(row)

# Put some key columns first, keep the rest in natural order
front = ["id", "date", "type", "from", "text_md"]
field_order = front + [f for f in fieldnames if f not in front]

# 4) Write CSV
with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=field_order, extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)

print(f"✅  Wrote {len(rows)} rows → {OUT_CSV}")
