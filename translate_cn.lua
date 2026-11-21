-- translate_cn.lua
-- Chinese (Simplified) -> English translation pipeline for DifficultBulletinBoard
--
-- Pipeline (applied in order):
--   1. WoWTranslate User Dict / Ranked Cache / Shared Dict (if WoWTranslate is loaded)
--   2. Hyperlink protection & item-link localization (via WoWTranslate_GetItemName if loaded)
--   3. Plain-text item names (WoWTranslate_ReplaceItemNames if loaded)
--   4. Phrase pass  - ordered rules from dict_cn_phrases
--   5. WoWTranslate Glossary partial pass (if loaded)
--   6. Misc pass    - byte-offset greedy longest-match from dict_cn_misc (if CJK remains)
--
-- Dependencies loaded before this file (per TOC order):
--   api/utils.lua           - DBB2.api.ContainsCJK
--   api/dict_cn_phrases.lua
--   api/dict_cn_misc.lua

local string_gsub   = string.gsub
local string_find   = string.find
local string_len    = string.len
local string_byte   = string.byte
local string_sub    = string.sub
local table_getn    = table.getn
local table_insert  = table.insert
local table_sort    = table.sort
local table_concat  = table.concat

-- Bounded session memoization for identical raw messages
local _translateMemo = {}
local _translateMemoCount = 0
local TRANSLATE_MEMO_MAX = 200

-- =====================================================
-- UTF-8 & HYPERLINK HELPERS
-- =====================================================

local function utf8_charlen(str, i)
  local b = string_byte(str, i)
  if not b       then return 1 end
  if b < 128    then return 1 end
  if b < 192    then return 1 end
  if b < 224    then return 2 end
  if b < 240    then return 3 end
  return 4
end

local function LocalizeItemHyperlink(fullLink)
  if type(WoWTranslate_GetItemName) ~= "function" then
    return fullLink
  end
  local _, _, colorCode, itemIdStr, restData = string_find(fullLink, "^|c(%x%x%x%x%x%x%x%x)|Hitem:(%d+):([^|]*)|h%[")
  local hasColor = true
  if not itemIdStr then
    hasColor = false
    _, _, itemIdStr, restData = string_find(fullLink, "^|Hitem:(%d+):([^|]*)|h%[")
  end
  if not itemIdStr then
    return fullLink
  end
  local itemId = tonumber(itemIdStr)
  if not itemId then
    return fullLink
  end
  local itemName = WoWTranslate_GetItemName(itemId)
  if not itemName or itemName == "" then
    return fullLink
  end
  if DBB2 and DBB2.perf then
    DBB2.perf.wtItemLinkHits = DBB2.perf.wtItemLinkHits + 1
  end
  if hasColor then
    return "|c" .. colorCode .. "|Hitem:" .. itemIdStr .. ":" .. restData .. "|h[" .. itemName .. "]|h|r"
  else
    return "|Hitem:" .. itemIdStr .. ":" .. restData .. "|h[" .. itemName .. "]|h"
  end
end

-- Splits text into { { type = "text"|"link", content = string }, ... }
local function SegmentLinks(text)
  local segments = {}
  local len = string_len(text)
  local pos = 1

  while pos <= len do
    local colorStart = string_find(text, "|c%x%x%x%x%x%x%x%x|H", pos)
    local plainStart = string_find(text, "|H", pos, true)
    local linkStart = nil

    if colorStart and (not plainStart or colorStart <= plainStart) then
      linkStart = colorStart
    elseif plainStart then
      linkStart = plainStart
    end

    if not linkStart then
      if pos <= len then
        table_insert(segments, { type = "text", content = string_sub(text, pos) })
      end
      break
    end

    local displayStart = string_find(text, "|h%[", linkStart)
    local displayEnd = displayStart and string_find(text, "%]|h", displayStart) or nil
    if not displayEnd then
      -- Not a well-formed hyperlink; emit up to linkStart + 1 as text and continue
      table_insert(segments, { type = "text", content = string_sub(text, pos, linkStart + 1) })
      pos = linkStart + 2
    else
      if linkStart > pos then
        table_insert(segments, { type = "text", content = string_sub(text, pos, linkStart - 1) })
      end
      local linkEnd = displayEnd + 2
      if string_sub(text, linkEnd + 1, linkEnd + 2) == "|r" then
        linkEnd = linkEnd + 2
      end
      local rawLink = string_sub(text, linkStart, linkEnd)
      table_insert(segments, { type = "link", content = LocalizeItemHyperlink(rawLink) })
      pos = linkEnd + 1
    end
  end

  return segments
end

-- Reconstructs a WoWTranslate cached string (which uses http://ph.wt/N placeholders)
-- with the localized hyperlinks from segments.
local function ReconstructWithLinks(segments, translatedText)
  local linkContents = {}
  local linkCount = 0
  for _, seg in ipairs(segments) do
    if seg.type == "link" then
      linkCount = linkCount + 1
      linkContents[linkCount] = seg.content
    end
  end
  if linkCount == 0 then
    return translatedText
  end
  local work = translatedText
  for i = 1, linkCount do
    local ph1 = "http://ph.wt/" .. i
    local ph2 = "https://ph.wt/" .. i
    local ph3 = "http://ph .wt/" .. i
    local ph4 = "http: //ph.wt/" .. i
    local s, e = string_find(work, ph1, 1, true)
    if not s then s, e = string_find(work, ph2, 1, true) end
    if not s then s, e = string_find(work, ph3, 1, true) end
    if not s then s, e = string_find(work, ph4, 1, true) end
    if s then
      work = string_sub(work, 1, s - 1) .. linkContents[i] .. string_sub(work, e + 1)
    else
      work = work .. " " .. linkContents[i]
    end
  end
  return work
end

-- =====================================================
-- PHRASE PASS
-- =====================================================

local function apply_phrases(text)
  if not dict_cn_phrases then return text end
  local count = table_getn(dict_cn_phrases)
  for i = 1, count do
    local rule = dict_cn_phrases[i]
    if rule.cn and rule.en then
      local replacement = rule.en
      if type(replacement) == "string" and string_sub(replacement, -1) ~= " " then
        replacement = replacement .. " "
      end
      text = string_gsub(text, rule.cn, replacement)
    end
  end
  -- Group composition: X=Y means "X have joined, need Y more", total = X+Y
  -- e.g. "3=2" -> "need 2 more (3/5)"
  text = string_gsub(text, "(%d+)=(%d+)", function(a, b)
    local have = tonumber(a) or 0
    local need = tonumber(b) or 0
    return "need " .. need .. " more (" .. have .. "/" .. (have + need) .. ") "
  end)
  return text
end

-- =====================================================
-- MISC PASS (byte-offset greedy longest-match, zero inner concat)
-- =====================================================

local _misc_by_first = nil

local function build_misc_index()
  if _misc_by_first then return end
  _misc_by_first = {}
  if not dict_cn_misc then return end
  for cn, en in pairs(dict_cn_misc) do
    local byteLen = string_len(cn)
    if byteLen > 0 then
      local clen = utf8_charlen(cn, 1)
      local first = string_sub(cn, 1, clen)
      if not _misc_by_first[first] then
        _misc_by_first[first] = {}
      end
      local trans = en
      if type(trans) == "string" and string_sub(trans, -1) ~= " " then
        trans = trans .. " "
      end
      table_insert(_misc_by_first[first], { cn = cn, en = trans, byteLen = byteLen })
    end
  end
  for _, bucket in pairs(_misc_by_first) do
    table_sort(bucket, function(a, b)
      if a.byteLen ~= b.byteLen then
        return a.byteLen > b.byteLen
      end
      return a.cn < b.cn
    end)
  end
end

local function apply_misc(text)
  if not dict_cn_misc then return text end
  build_misc_index()

  local len = string_len(text)
  local out = {}
  local pos = 1

  while pos <= len do
    local clen = utf8_charlen(text, pos)
    local ch = string_sub(text, pos, pos + clen - 1)
    local bucket = _misc_by_first[ch]
    local matched = false

    if bucket then
      local bCount = table_getn(bucket)
      for b = 1, bCount do
        local entry = bucket[b]
        local klen = entry.byteLen
        if pos + klen - 1 <= len then
          if string_sub(text, pos, pos + klen - 1) == entry.cn then
            table_insert(out, entry.en)
            pos = pos + klen
            matched = true
            break
          end
        end
      end
    end

    if not matched then
      table_insert(out, ch)
      pos = pos + clen
    end
  end

  return table_concat(out)
end

-- Translates a single plain-text (non-hyperlink) segment
local function TranslateTextSegment(seg)
  if not seg or seg == "" then return seg end
  if not DBB2.api.ContainsCJK(seg) then
    return seg
  end

  -- 1. WoWTranslate exact glossary match
  if type(WoWTranslate_CheckGlossaryExact) == "function" then
    local exact = WoWTranslate_CheckGlossaryExact(seg)
    if exact then
      if DBB2 and DBB2.perf then
        DBB2.perf.wtGlossaryHits = DBB2.perf.wtGlossaryHits + 1
      end
      return exact
    end
  end

  local result = seg

  -- 2. WoWTranslate plain-text Chinese item names (5,233 items >= 4 CJK chars)
  if type(WoWTranslate_ReplaceItemNames) == "function" then
    local replaced = WoWTranslate_ReplaceItemNames(result)
    if replaced then
      result = replaced
    end
  end

  -- 3. DBB2 ordered LFG phrase rules (handles X=Y, role combos, level patterns)
  result = apply_phrases(result)

  -- 4. WoWTranslate partial glossary (850+ terms + 58 Turtle WoW shorthands)
  if DBB2.api.ContainsCJK(result) and type(WoWTranslate_CheckGlossaryPartial) == "function" then
    local partial = WoWTranslate_CheckGlossaryPartial(result, false)
    if partial then
      result = partial
      if DBB2 and DBB2.perf then
        DBB2.perf.wtGlossaryHits = DBB2.perf.wtGlossaryHits + 1
      end
    end
  end

  -- 5. DBB2 misc dictionary fallback for any remaining CJK
  if DBB2.api.ContainsCJK(result) then
    result = apply_misc(result)
  end

  return result
end

-- =====================================================
-- PUBLIC API
-- =====================================================

function DBB2.api.TranslateCN(message)
  if not message or message == "" then
    return message
  end

  local memo = _translateMemo[message]
  if memo ~= nil then
    return memo
  end

  -- Fast path: if no CJK and no item link to localize, return as-is
  local hasCJK = DBB2.api.ContainsCJK(message)
  local hasItemLink = string_find(message, "|Hitem:", 1, true) ~= nil
  if not hasCJK and not hasItemLink then
    return message
  end

  local segments = SegmentLinks(message)

  -- Tier 1: Check WoWTranslate User Dictionary / Ranked Cache / Shared Dictionary
  if hasCJK and type(WoWTranslate_CacheGet) == "function" then
    local cached, found = WoWTranslate_CacheGet(message)
    if found and cached and cached ~= "" then
      local out = ReconstructWithLinks(segments, cached)
      out = string_gsub(out, "%s+", " ")
      out = string_gsub(out, "%s+$", "")
      if DBB2 and DBB2.perf then
        DBB2.perf.wtCacheHits = DBB2.perf.wtCacheHits + 1
      end
      if DBB2 and DBB2.Trace then
        DBB2:Trace("TRANSLATE", "wt_cache hit: " .. string_sub(out, 1, 60))
      end
      if _translateMemoCount >= TRANSLATE_MEMO_MAX then
        _translateMemo = {}
        _translateMemoCount = 0
      end
      _translateMemo[message] = out
      _translateMemoCount = _translateMemoCount + 1
      return out
    end
  end

  -- Translate only text segments; hyperlinks stay protected and item links are localized
  local outParts = {}
  for _, seg in ipairs(segments) do
    if seg.type == "link" then
      table_insert(outParts, seg.content)
    else
      table_insert(outParts, TranslateTextSegment(seg.content))
    end
  end
  local result = table_concat(outParts)

  -- Post-translation cleanup
  result = string_gsub(result, "%s+", " ")
  result = string_gsub(result, "%s+$", "")

  if _translateMemoCount >= TRANSLATE_MEMO_MAX then
    _translateMemo = {}
    _translateMemoCount = 0
  end
  _translateMemo[message] = result
  _translateMemoCount = _translateMemoCount + 1

  return result
end

-- [ UpgradeMessageTranslation ]
-- Lazily upgrades a CJK-origin stored message if WoWTranslate has since cached
-- an async DLL translation (or user added a /wt fix entry).
-- Returns true if the message was upgraded.
function DBB2.api.UpgradeMessageTranslation(msgObj)
  if not msgObj or not msgObj._hasCJKOrigin or msgObj._wtUpgraded then
    return false
  end
  if type(WoWTranslate_CacheGet) ~= "function" then
    return false
  end
  local raw = msgObj._rawMessage
  if not raw or raw == "" then
    return false
  end
  local cached, found = WoWTranslate_CacheGet(raw)
  if not found or not cached or cached == "" then
    return false
  end
  local segments = SegmentLinks(raw)
  local upgraded = ReconstructWithLinks(segments, cached)
  upgraded = string_gsub(upgraded, "%s+", " ")
  upgraded = string_gsub(upgraded, "%s+$", "")
  if upgraded ~= "" and upgraded ~= msgObj.message then
    msgObj.message = upgraded
    msgObj._catCache = nil
    msgObj._cleanLower = nil
    msgObj._wtUpgraded = true
    if DBB2 and DBB2.perf then
      DBB2.perf.wtAsyncUpgrades = DBB2.perf.wtAsyncUpgrades + 1
    end
    if DBB2 and DBB2.Trace then
      DBB2:Trace("TRANSLATE", "lazy wt_cache upgrade: " .. string_sub(upgraded, 1, 60))
    end
    return true
  end
  msgObj._wtUpgraded = true
  return false
end

-- [ RequestAsyncTranslation ]
-- If a CJK-origin message still has untranslated CJK characters after local passes,
-- optionally queues an async WoWTranslate_API.Translate request (only when the DLL
-- queue has spare capacity) and updates the stored message + visible UI on completion.
function DBB2.api.RequestAsyncTranslation(msgObj)
  if not msgObj or not msgObj._hasCJKOrigin or msgObj._wtRequested then
    return false
  end
  if type(WoWTranslate_API) ~= "table" or type(WoWTranslate_API.IsAvailable) ~= "function" then
    return false
  end
  if not WoWTranslate_API.IsAvailable() then
    return false
  end
  if type(WoWTranslate_API.GetPendingCount) == "function" and WoWTranslate_API.GetPendingCount() >= 3 then
    return false
  end
  local raw = msgObj._rawMessage
  if not raw or raw == "" then
    return false
  end
  if not DBB2.api.ContainsCJK(msgObj.message) then
    return false
  end

  local segments = SegmentLinks(raw)
  local parts = {}
  local linkIndex = 0
  for _, seg in ipairs(segments) do
    if seg.type == "link" then
      linkIndex = linkIndex + 1
      table_insert(parts, " http://ph.wt/" .. linkIndex .. " ")
    else
      local clean = string_gsub(seg.content, "|c%x%x%x%x%x%x%x%x", "")
      clean = string_gsub(clean, "|r", "")
      table_insert(parts, clean)
    end
  end
  local plainText = table_concat(parts)
  if plainText == "" then return false end

  msgObj._wtRequested = true
  return WoWTranslate_API.Translate(plainText, function(translation, err)
    if not translation or translation == "" then return end
    if type(WoWTranslate_CacheSave) == "function" then
      WoWTranslate_CacheSave(raw, translation)
    end
    local reconstructed = ReconstructWithLinks(segments, translation)
    reconstructed = string_gsub(reconstructed, "%s+", " ")
    reconstructed = string_gsub(reconstructed, "%s+$", "")
    if reconstructed ~= "" and reconstructed ~= msgObj.message then
      msgObj.message = reconstructed
      msgObj._catCache = nil
      msgObj._cleanLower = nil
      msgObj._wtUpgraded = true
      if DBB2 and DBB2.perf then
        DBB2.perf.wtAsyncUpgrades = DBB2.perf.wtAsyncUpgrades + 1
      end
      if DBB2 and DBB2.Trace then
        DBB2:Trace("TRANSLATE", "async DLL upgrade: " .. string_sub(reconstructed, 1, 60))
      end
      if DBB2.gui and DBB2.gui:IsShown() then
        if DBB2.gui.UpdateMessages then DBB2.gui:UpdateMessages() end
        if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
          local activeTab = DBB2.gui.tabs.activeTab
          if activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
            local panel = DBB2.gui.tabs.panels[activeTab]
            if panel and panel.UpdateCategories then panel.UpdateCategories() end
          end
        end
      end
    end
  end, "zh")
end
