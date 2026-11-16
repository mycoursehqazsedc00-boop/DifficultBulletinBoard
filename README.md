# DifficultBulletinBoard (DBB2)

A World of Warcraft 1.12 / Turtle WoW addon that scans world chat and organizes LFG, profession, and hardcore messages into a filterable bulletin board UI.

## Client Mods & Optional Addons Used

| Mod / Addon | Purpose in this addon | Required? |
|---|---|---|
| **[ClassicAPI](https://github.com/brues-code/ClassicAPI)** | Calls `C_PlayerCache.GetPlayerInfoByName` to display sender names in their class colors (`RAID_CLASS_COLORS`). Falls back to white text when absent. | Optional |
| **[WoWTranslate](https://github.com/sanjaygbhat/wow-translate)** (v2.2 fork) | Reuses `WoWTranslate_CacheGet` (user dictionary, ranked cache, shared dictionary), `WoWTranslate_GetItemName` (item-link localization), `WoWTranslate_ReplaceItemNames` (plain-text CN item names), and `WoWTranslate_CheckGlossaryExact` / `WoWTranslate_CheckGlossaryPartial`. Falls back to DBB2's built-in CN dictionaries when absent. | Optional |

No other client DLL mods (SuperWoW, Nampower, UnitXP SP3, VanillaHelpers, WeirdUtils) are called by this addon.

## Features

- **Group Logs** — tracks and filters all group-related messages in one consolidated view
- **Group Finder** — locate groups for specific dungeons and raids with recommended level ranges and lockout indicators
- **Profession Search** — quickly find players offering or seeking crafting services
- **Hardcore Messages** — stay updated on hardcore deaths and level-ups
- **Blacklist & Wildcard Filtering** — hide spam matching user-defined patterns
- **Expiration & Deduplication** — auto-expire old messages and replace stale entries from the same sender
- **Notifications** — chat and raid-warning alerts with sound for watched categories
- **CJK Translation & Font Support** — translates Chinese LFG messages into English with bundled CJK font support (`WarSansTT-Bliz-500.ttf`)
- **Minimap Button & Slash Commands** — `/dbb`

## What Was Added / Improved

### Freeze & Crash Fix (Opening / Refreshing the Board)
- **Coalesced `OnShow` / `SwitchTab` double-update:** Opening the board previously triggered both `panel._needsContentUpdate` (from `SwitchTab`) and `DBB2.gui._needsDeferredUpdate` (from `OnShow`), rebuilding all rows twice on open. Now coalesced into a single deferred update.
- **Cached `TruncateMessage` layout:** `TruncateMessage` previously ran a `SetText` + `GetStringWidth` binary search (~7–9 synchronous CJK font-layout calls per row) on every rebuild. Results are now cached per `(message, width, fontOffset)` (and skipped completely on unchanged rows), eliminating the ~5s freeze and preventing WoW 1.12.1 font-layout `ACCESS_VIOLATION` crashes.
- **Cached `CategorizeMessage` per message:** Categorization results are now cached on each message object and invalidated only when `DBB2._catConfigRev` changes (tag/filter edits). `CategorizeMessage` also evaluates `MatchFilterTags` once per category type (`groups`, `professions`) instead of once per category, and `api/wildcards.lua` caches compiled Lua patterns.
- **Idle-frame & layout overhead reduction:**
  - `Logs` scroll frame now uses a dirty flag (`_logsDirty`) instead of scanning 50 rows and calling `UpdateScrollState()` every frame.
  - Per-row hover handlers short-circuit `MouseIsOver(this)` before walking the frame hierarchy in `IsRowVisibleInScrollFrame`.
  - `UpdateCategories` only calls `row:SetParent(catFrame)` when the parent actually changed, and `row:SetData` only re-anchors timestamp/message frames when `timeDisplayMode` changes.

### WoWTranslate v2.2 Integration & CN Pipeline Optimization
- **Hyperlink-safe segmentation & item-link localization:** Extracts `|H...|h[...]|h` links before translation so dictionary rules never corrupt links, and localizes Chinese `|Hitem:...|h` names to English using `WoWTranslate_GetItemName` (client cache -> persistent store -> bundled 6,111-item table).
- **Multi-tier lookup:** Checks `WoWTranslate_CacheGet` (including `/wt fix` user dictionary entries), then `WoWTranslate_ReplaceItemNames`, DBB2's ordered LFG phrase rules, `WoWTranslate_CheckGlossaryPartial`, and finally DBB2's misc dictionary.
- **Lazy cache upgrade:** When opening or refreshing the board, CJK-origin messages check `WoWTranslate_CacheGet` once to pick up async DLL translations that completed after `CHAT_MSG_*` fired.
- **Faster `dict_cn_misc` lookup:** Replaced per-character table allocation + inner string concatenation with byte-offset slicing and a bounded session memo table.

### Class-Colored Sender Names & Diagnostics
- **Class-colored sender names:** Implemented `DBB2.api.GetSenderClassColor(sender)` using ClassicAPI's `C_PlayerCache.GetPlayerInfoByName` (cached per session, white fallback without ClassicAPI).
- **Built-in tracing & perf counters:** Added `/dbb trace`, `/dbb perf`, and `/dbb log` for runtime diagnostics.

## Usage

- `/dbb` — Toggle the bulletin board window
- `/dbb trace` — Toggle live debug tracing in chat
- `/dbb perf` — Print GUI rebuild, categorization cache, truncation cache, and WoWTranslate hit counters
- `/dbb log` — Print the last 20 trace log entries
- `/dbb help` — List available commands

## Credits & License

- Original addon: `akzkak`, `DeterminedPanda`, `Zae` (Capyed)
- Chinese dictionary rules ported from `TranslateCN` by `Gangasrotogati`
- License: Same as original addon.
