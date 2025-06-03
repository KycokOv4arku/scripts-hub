# Python Utilities

Mini-CLI tools for data cleanup, exports, and random automation.

## 1. `tg_history_json2csv.py`

Parses a Telegram channel export (`result.json`) and writes a clean CSV.

- Keeps every top-level field → new columns auto-appear.
- `text` parts are flattened into **Markdown** (`text_md` column).
- Drops noisy `text_entities`.
- Pure std-lib, runs anywhere.

**Run**

1. update path variable at top of script
2. in CLI -> `python tg_history_json2csv.py`
