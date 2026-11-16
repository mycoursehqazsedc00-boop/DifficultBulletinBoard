
## api/blacklist.lua
```lua
-- DBB2 Blacklist API
-- Handles player and keyword blocking for message filtering
--
-- Dependencies: env/defaults.lua, api/wildcards.lua
-- This file must be loaded BEFORE chat_filter.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs

-- [ InitBlacklist ]
-- Initializes blacklist config if not present
-- Uses DBB2.env.defaultBlacklistKeywords from env/defaults.lua
function DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist then
    DBB2_Config.blacklist = {
      enabled = true,
      hideFromChat = true,  -- Hide blacklisted messages from chat (enabled by default)
      players = {},
      keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    }
  end
  -- Ensure all fields exist
  if DBB2_Config.blacklist.enabled == nil then
    DBB2_Config.blacklist.enabled = false
  end
  if DBB2_Config.blacklist.hideFromChat == nil then
    DBB2_Config.blacklist.hideFromChat = true  -- Default to enabled
  end
  if not DBB2_Config.blacklist.players then
    DBB2_Config.blacklist.players = {}
  end
  if not DBB2_Config.blacklist.keywords then
    DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
  end
end

-- [ IsBlacklistEnabled ]
-- Returns whether blacklist filtering is enabled
function DBB2.api.IsBlacklistEnabled()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.enabled
end

-- [ SetBlacklistEnabled ]
-- Enables or disables blacklist filtering
function DBB2.api.SetBlacklistEnabled(enabled)
  DBB2.api.InitBlacklist()
  DBB2_Config.blacklist.enabled = enabled
end

-- [ IsBlacklistHideFromChatEnabled ]
-- Returns whether hiding blacklisted messages from chat is enabled
function DBB2.api.IsBlacklistHideFromChatEnabled()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.hideFromChat
end

-- [ SetBlacklistHideFromChat ]
-- Enables or disables hiding blacklisted messages from chat
function DBB2.api.SetBlacklistHideFromChat(enabled)
  DBB2.api.InitBlacklist()
  DBB2_Config.blacklist.hideFromChat = enabled
end

-- [ AddPlayerToBlacklist ]
-- Adds a player name to the blacklist
function DBB2.api.AddPlayerToBlacklist(playerName)
  DBB2.api.InitBlacklist()
  if not playerName or playerName == "" then return false end
  
  local lowerName = string_lower(playerName)
  -- Check if already exists
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.players, playerName)
  return true
end

-- [ RemovePlayerFromBlacklist ]
-- Removes a player name from the blacklist
function DBB2.api.RemovePlayerFromBlacklist(playerName)
  DBB2.api.InitBlacklist()
  local lowerName = string_lower(playerName or "")
  
  for i = table_getn(DBB2_Config.blacklist.players), 1, -1 do
    if string_lower(DBB2_Config.blacklist.players[i]) == lowerName then
      table_remove(DBB2_Config.blacklist.players, i)
      return true
    end
  end
  return false
end

-- [ IsPlayerBlacklisted ]
-- Checks if a player is blacklisted
function DBB2.api.IsPlayerBlacklisted(playerName)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false end
  
  local lowerName = string_lower(playerName or "")
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return true
    end
  end
  return false
end

-- [ GetBlacklistedPlayers ]
-- Returns the list of blacklisted players
function DBB2.api.GetBlacklistedPlayers()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.players
end

-- [ AddKeywordToBlacklist ]
-- Adds a keyword to the blacklist
function DBB2.api.AddKeywordToBlacklist(keyword)
  DBB2.api.InitBlacklist()
  if not keyword or keyword == "" then return false end
  
  local lowerKeyword = string_lower(keyword)
  -- Check if already exists
  for _, kw in ipairs(DBB2_Config.blacklist.keywords) do
    if string_lower(kw) == lowerKeyword then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.keywords, keyword)
  return true
end

-- [ RemoveKeywordFromBlacklist ]
-- Removes a keyword from the blacklist
function DBB2.api.RemoveKeywordFromBlacklist(keyword)
  DBB2.api.InitBlacklist()
  local lowerKeyword = string_lower(keyword or "")
  
  for i = table_getn(DBB2_Config.blacklist.keywords), 1, -1 do
    if string_lower(DBB2_Config.blacklist.keywords[i]) == lowerKeyword then
      table_remove(DBB2_Config.blacklist.keywords, i)
      return true
    end
  end
  return false
end

-- [ GetBlacklistedKeywords ]
-- Returns the list of blacklisted keywords
function DBB2.api.GetBlacklistedKeywords()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.keywords
end

-- [ IsKeywordWildcardPattern ]
-- Checks if a keyword contains wildcard special characters (meaning it's a pattern)
-- Plain keywords get word boundary treatment, wildcard patterns are used as-is
-- 'keyword'    [string]        the keyword to check
-- return:      [boolean]       true if keyword contains wildcard syntax
function DBB2.api.IsKeywordWildcardPattern(keyword)
  if not keyword then return false end
  -- Check for wildcard metacharacters: * ? [ ] { } \
  if string_find(keyword, "[%*%?%[%]%{%}\\]") then
    return true
  end
  return false
end

-- [ MatchKeywordWithBoundary ]
-- Matches a plain keyword with word boundary rules:
-- - Keyword must not be preceded by a letter/number
-- - Keyword must not be followed by a letter/number (but punctuation is OK)
-- This prevents "na" from matching "naxx" but allows "na!" or "na?"
-- 'text'       [string]        the text to search in (should be lowercase)
-- 'keyword'    [string]        the keyword to find (should be lowercase)
-- return:      [boolean]       true if keyword matches with proper boundaries
function DBB2.api.MatchKeywordWithBoundary(text, keyword)
  if not text or not keyword then return false end
  
  local keywordLen = string_len(keyword)
  local textLen = string_len(text)
  local startPos = 1
  
  while startPos <= textLen do
    -- Find the keyword in text (plain search)
    local foundStart, foundEnd = string_find(text, keyword, startPos, true)
    if not foundStart then
      return false
    end
    
    -- Check character before the match (must not be alphanumeric)
    local validStart = true
    if foundStart > 1 then
      local charBefore = string_sub(text, foundStart - 1, foundStart - 1)
      if string_find(charBefore, "[%w]") then
        validStart = false
      end
    end
    
    -- Check character after the match (must not be alphanumeric)
    local validEnd = true
    if foundEnd < textLen then
      local charAfter = string_sub(text, foundEnd + 1, foundEnd + 1)
      if string_find(charAfter, "[%w]") then
        validEnd = false
      end
    end
    
    if validStart and validEnd then
      return true
    end
    
    -- Continue searching from after this match
    startPos = foundStart + 1
  end
  
  return false
end

-- [ IsMessageBlacklistedByKeyword ]
-- Checks if a message contains any blacklisted keyword
-- Plain keywords: matched with word boundaries (won't match inside other words)
--   e.g., "na" matches "na", "na!", "na?" but NOT "naxx"
-- Wildcard keywords: matched using wildcard API (for pattern matching)
--   e.g., "na*" would match "naxx" if you want loose matching
-- Returns: matched (boolean), matchedKeywords (table of matched keyword strings)
function DBB2.api.IsMessageBlacklistedByKeyword(message)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false, {} end
  if not message then return false, {} end
  
  local matchedKeywords = {}
  local lowerMessage = string_lower(message)
  
  for _, keyword in ipairs(DBB2_Config.blacklist.keywords) do
    local matched = false
    
    if DBB2.api.IsKeywordWildcardPattern(keyword) then
      -- Wildcard pattern: use wildcards API for matching (case-insensitive)
      if DBB2.api.wildcards and DBB2.api.wildcards.Match then
        matched = DBB2.api.wildcards.Match(message, keyword, true)
      end
    else
      -- Plain keyword: use word boundary matching
      local lowerKeyword = string_lower(keyword)
      matched = DBB2.api.MatchKeywordWithBoundary(lowerMessage, lowerKeyword)
    end
    
    if matched then
      table_insert(matchedKeywords, keyword)
    end
  end
  
  return table_getn(matchedKeywords) > 0, matchedKeywords
end

-- [ IsMessageBlacklisted ]
-- Checks if a message should be filtered (player or keyword)
-- Returns: blocked (boolean), reason (string: "player" or "keyword"), details (string or table)
function DBB2.api.IsMessageBlacklisted(message, sender)
  if not DBB2.api.IsBlacklistEnabled() then return false, nil, nil end
  
  if DBB2.api.IsPlayerBlacklisted(sender) then
    return true, "player", sender
  end
  
  local keywordBlocked, matchedKeywords = DBB2.api.IsMessageBlacklistedByKeyword(message)
  if keywordBlocked then
    return true, "keyword", matchedKeywords
  end
  
  return false, nil, nil
end
```

## api/categories.lua
```lua
-- DBB2 Categories API
-- Core category management functions for message filtering
--
-- NOTE: Default category data and initialization is in modules/categories.lua
-- This file provides the API functions that operate on category data.
--
-- Includes:
-- - Category collapse state (UI)
-- - Category management (get, update, select)
-- - Tag parsing utilities
-- - Filter tags (AND-condition filtering for groups/professions)
-- - Level range filtering (dungeon/raid level appropriateness)
-- - Message matching and categorization
--
-- Related files:
-- - env/tag_exclusions.lua: Tag false positive exclusion rules (DBB2.env.IsTagExcluded)

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_concat = table.concat
local table_getn = table.getn
local ipairs = ipairs
local math_abs = math.abs

-- =====================================================
-- CATEGORY COLLAPSE STATE API
-- =====================================================
-- Functions for managing the collapsed/expanded state of categories in the UI.
-- Collapsed categories show only the header, hiding their messages.

-- [ IsCategoryCollapsed ]
-- Checks whether a category is currently collapsed in the UI.
-- Collapsed categories show only the header row, hiding their messages.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @return              [boolean] true if collapsed, false if expanded or not found
function DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  if not categoryType or not categoryName then return false end
  if not DBB2_Config.categoryCollapsed then return false end
  if not DBB2_Config.categoryCollapsed[categoryType] then return false end
  return DBB2_Config.categoryCollapsed[categoryType][categoryName] or false
end

-- [ SetCategoryCollapsed ]
-- Sets the collapsed/expanded state of a category in the UI.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @param collapsed     [boolean] true to collapse, false to expand
-- @return              [boolean] true if set successfully, false if invalid params
function DBB2.api.SetCategoryCollapsed(categoryType, categoryName, collapsed)
  if not categoryType or not categoryName then return false end
  if not DBB2_Config.categoryCollapsed then
    DBB2_Config.categoryCollapsed = {}
  end
  if not DBB2_Config.categoryCollapsed[categoryType] then
    DBB2_Config.categoryCollapsed[categoryType] = {}
  end
  DBB2_Config.categoryCollapsed[categoryType][categoryName] = collapsed
  return true
end

-- [ ToggleCategoryCollapsed ]
-- Toggles the collapsed/expanded state of a category.
-- If collapsed, expands it; if expanded, collapses it.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @return              [boolean] The new collapsed state (true = now collapsed)
function DBB2.api.ToggleCategoryCollapsed(categoryType, categoryName)
  local isCollapsed = DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  DBB2.api.SetCategoryCollapsed(categoryType, categoryName, not isCollapsed)
  return not isCollapsed
end

-- =====================================================
-- CATEGORY MANAGEMENT API
-- =====================================================
-- Functions for retrieving and modifying category definitions.
-- Categories contain tags used to match messages to dungeon/raid groups,
-- profession services, or hardcore-specific content.

-- [ GetCategories ]
-- Returns all categories for a given type from the saved config.
--
-- @param categoryType  [string] Category type: "groups", "professions", or "hardcore"
-- @return              [table]  Array of category objects, or empty table if not found
--                               Each category: { name, selected, tags, _tagsLower, _tagsLen }
function DBB2.api.GetCategories(categoryType)
  if not categoryType then return {} end
  if not DBB2_Config.categories then return {} end
  return DBB2_Config.categories[categoryType] or {}
end

-- [ GetCategoryByName ]
-- Finds and returns a specific category by its display name.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param name          [string]  The exact display name of the category
-- @return              [table]   The category object if found, or nil
-- @return              [number]  The index in the categories array, or nil
function DBB2.api.GetCategoryByName(categoryType, name)
  if not categoryType or not name then return nil end
  local cats = DBB2.api.GetCategories(categoryType)
  for i, cat in ipairs(cats) do
    if cat.name == name then
      return cat, i
    end
  end
  return nil
end


-- [ UpdateCategoryTags ]
-- Updates the search tags for a category.
-- Also pre-computes lowercase versions and lengths for faster matching.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category to update
-- @param newTags       [table]   Array of tag strings (e.g., {"mc", "molten core", "molten"})
-- @return              [boolean] true if updated successfully, false if category not found
function DBB2.api.UpdateCategoryTags(categoryType, categoryName, newTags)
  local cat = DBB2.api.GetCategoryByName(categoryType, categoryName)
  if cat then
    cat.tags = newTags or {}
    -- Pre-compute lowercase tags and their lengths for faster matching
    cat._tagsLower = {}
    cat._tagsLen = {}
    for i, tag in ipairs(cat.tags) do
      local lower = string_lower(tag)
      cat._tagsLower[i] = lower
      cat._tagsLen[i] = string_len(lower)
    end
    return true
  end
  return false
end

-- [ EnsureTagsPrecomputed ]
-- Ensures a category has pre-computed lowercase tags
-- Called internally before matching
local function EnsureTagsPrecomputed(category)
  -- Always recompute if _tagsLower doesn't exist
  if not category._tagsLower then
    category._tagsLower = {}
    category._tagsLen = {}
    for i, tag in ipairs(category.tags or {}) do
      local lower = string_lower(tag)
      category._tagsLower[i] = lower
      category._tagsLen[i] = string_len(lower)
    end
    return
  end
  
  -- Check if tags array length changed (recompute if so)
  local tagsCount = 0
  if category.tags then
    for _ in ipairs(category.tags) do
      tagsCount = tagsCount + 1
    end
  end
  
  local cachedCount = 0
  for _ in ipairs(category._tagsLower) do
    cachedCount = cachedCount + 1
  end
  
  if tagsCount ~= cachedCount then
    category._tagsLower = {}
    category._tagsLen = {}
    for i, tag in ipairs(category.tags or {}) do
      local lower = string_lower(tag)
      category._tagsLower[i] = lower
      category._tagsLen[i] = string_len(lower)
    end
  end
end

-- [ SetCategorySelected ]
-- Enables or disables a category for message matching.
-- Disabled categories will not match any messages (unless ignoreSelected is used).
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @param selected      [boolean] true to enable, false to disable
-- @return              [boolean] true if updated successfully, false if category not found
function DBB2.api.SetCategorySelected(categoryType, categoryName, selected)
  local cat = DBB2.api.GetCategoryByName(categoryType, categoryName)
  if cat then
    cat.selected = selected and true or false
    return true
  end
  return false
end

-- =====================================================
-- TAG PARSING UTILITIES
-- =====================================================
-- Functions for converting between tag string formats.

-- [ ParseTagsString ]
-- Converts a comma-separated string into an array of tags.
-- Trims whitespace and converts to lowercase.
--
-- Example: "MC, BWL, Ony" -> {"mc", "bwl", "ony"}
--
-- @param str     [string] Comma-separated tags string
-- @return        [table]  Array of lowercase tag strings
function DBB2.api.ParseTagsString(str)
  local tags = {}
  if not str or str == "" then return tags end
  
  for tag in string_gfind(str, "([^,]+)") do
    -- Trim whitespace
    tag = string_gsub(tag, "^%s*(.-)%s*$", "%1")
    tag = string_lower(tag)
    if tag ~= "" then
      table_insert(tags, tag)
    end
  end
  return tags
end

-- [ TagsToString ]
-- Converts an array of tags into a comma-separated string.
-- Uses table.concat for efficiency.
--
-- Example: {"mc", "bwl", "ony"} -> "mc, bwl, ony"
--
-- @param tags    [table]  Array of tag strings
-- @return        [string] Comma-separated string, or empty string if no tags
function DBB2.api.TagsToString(tags)
  if not tags then return "" end
  if table_getn(tags) == 0 then return "" end
  
  -- table.concat is more efficient than manual concatenation
  return table_concat(tags, ", ")
end


-- =====================================================
-- FILTER TAGS API
-- =====================================================
-- Filter tags are additional tags that must ALSO match (AND condition)
-- when enabled, allowing filtering for specific message types like LFG/LFM
-- for groups or LFW/WTB/WTS for professions.

-- [ GetFilterTags ]
-- Returns the filter tags configuration for a category type.
-- Filter tags are additional tags that must ALSO match (AND condition)
-- when enabled, allowing filtering for specific message types.
--
-- @param categoryType  [string] Category type: "groups" or "professions"
-- @return              [table]  Config table { enabled = boolean, tags = {string...} }, or nil if not found
function DBB2.api.GetFilterTags(categoryType)
  if not categoryType then return nil end
  if not DBB2_Config.filterTags then return nil end
  return DBB2_Config.filterTags[categoryType]
end

-- [ IsFilterTagsEnabled ]
-- Checks whether filter tags are currently enabled for a category type.
-- When enabled, messages must match both category tags AND filter tags.
--
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @return              [boolean] true if filter tags are enabled, false otherwise
function DBB2.api.IsFilterTagsEnabled(categoryType)
  local filter = DBB2.api.GetFilterTags(categoryType)
  if not filter then return false end
  return filter.enabled or false
end

-- [ SetFilterTagsEnabled ]
-- Enables or disables filter tags for a category type.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @param enabled       [boolean] true to enable filter tags, false to disable
-- @return              [boolean] true if set successfully, false if invalid params
function DBB2.api.SetFilterTagsEnabled(categoryType, enabled)
  if not categoryType then return false end
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags[categoryType] then
    DBB2_Config.filterTags[categoryType] = { enabled = false, tags = {} }
  end
  DBB2_Config.filterTags[categoryType].enabled = enabled and true or false
  return true
end

-- [ UpdateFilterTags ]
-- Updates the filter tags array for a category type.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string] Category type: "groups" or "professions"
-- @param newTags       [table]  Array of tag strings (e.g., {"lfg", "lfm", "lf1m"})
-- @return              [boolean] true if updated successfully, false if invalid params
function DBB2.api.UpdateFilterTags(categoryType, newTags)
  if not categoryType then return false end
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags[categoryType] then
    DBB2_Config.filterTags[categoryType] = { enabled = false, tags = {} }
  end
  DBB2_Config.filterTags[categoryType].tags = newTags or {}
  return true
end

-- [ MatchFilterTags ]
-- Checks if a message matches any of the filter tags for a category type.
-- Uses word boundary matching for plain tags and wildcard matching for patterns.
-- Returns true if filter is disabled (pass-through behavior).
--
-- Supports wildcard patterns: * (any chars), ? (one char), [abc], [a-z], {a,b,c}
-- Also matches tags followed by digits (e.g., "lf1m", "lf2m" for "lf" tag).
--
-- @param message       [string]  The message text to check
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @return              [boolean] true if matches any filter tag, or if filter is disabled
function DBB2.api.MatchFilterTags(message, categoryType)
  -- If filter is disabled, always return true (no filtering)
  if not DBB2.api.IsFilterTagsEnabled(categoryType) then
    return true
  end
  
  local filter = DBB2.api.GetFilterTags(categoryType)
  if not filter or not filter.tags then
    return true  -- No tags defined, pass through
  end
  
  -- Quick check: any tags at all?
  local hasAnyTags = false
  for _ in ipairs(filter.tags) do
    hasAnyTags = true
    break
  end
  if not hasAnyTags then
    return true  -- No tags, pass through
  end
  
  local lowerMsg = string_lower(message or "")
  if lowerMsg == "" then return false end
  
  local msgLen = string_len(lowerMsg)
  
  for _, tag in ipairs(filter.tags) do
    local lowerTag = string_lower(tag)
    local tagLen = string_len(lowerTag)
    
    -- Check if tag contains wildcard special characters
    local isWildcard = string_find(lowerTag, "[%*%?%[%]%{%}\\]")
    
    if isWildcard then
      -- Use wildcard matching
      if DBB2.api.MatchWildcard(lowerMsg, lowerTag) then
        return true
      end
    else
      -- Plain text matching with word boundaries
      local startPos = 1
      while true do
        local foundPos = string_find(lowerMsg, lowerTag, startPos, true)
        if not foundPos then
          break
        end
        
        -- Check word boundaries
        local charBefore = ""
        if foundPos > 1 then
          charBefore = string_sub(lowerMsg, foundPos - 1, foundPos - 1)
        end
        
        local afterPos = foundPos + tagLen
        local charAfter = ""
        if afterPos <= msgLen then
          charAfter = string_sub(lowerMsg, afterPos, afterPos)
        end
        
        local validBefore = (foundPos == 1) or not string_find(charBefore, "[%w]")
        local validAfter = (afterPos > msgLen) or not string_find(charAfter, "[%w]")
        
        -- Also allow digits after (like LF1M, LF2M)
        if not validAfter and string_find(charAfter, "%d") then
          local digitEndPos = afterPos
          while digitEndPos <= msgLen and string_find(string_sub(lowerMsg, digitEndPos, digitEndPos), "%d") do
            digitEndPos = digitEndPos + 1
          end
          -- Check for 'M' after digits (for patterns like LF1M, LF2M)
          if digitEndPos <= msgLen then
            local afterDigits = string_sub(lowerMsg, digitEndPos, digitEndPos)
            if string_lower(afterDigits) == "m" then
              digitEndPos = digitEndPos + 1
            end
          end
          -- Check boundary after digits/M
          if digitEndPos > msgLen or not string_find(string_sub(lowerMsg, digitEndPos, digitEndPos), "[%w]") then
            validAfter = true
          end
        end
        
        if validBefore and validAfter then
          return true
        end
        
        startPos = foundPos + 1
      end
    end
  end
  
  return false
end

-- =====================================================
-- LEVEL RANGE API
-- =====================================================
-- Functions for level-based category filtering.
-- Level ranges define the appropriate player level for dungeon/raid content.
-- Level ranges are populated by modules/categories.lua during initialization
-- and stored in DBB2.categoryLevelRanges lookup table.

-- [ GetCategoryLevelRange ]
-- Returns the level range for a category (used for level filtering).
-- Level ranges define the appropriate player level for dungeon/raid content.
--
-- @param categoryName  [string] The display name of the category
-- @return              [table]  Level range table { minLevel = number, maxLevel = number }, or nil if not found
function DBB2.api.GetCategoryLevelRange(categoryName)
  if DBB2.categoryLevelRanges and DBB2.categoryLevelRanges[categoryName] then
    return DBB2.categoryLevelRanges[categoryName]
  end
  return nil
end

-- [ GetCategoryLevelRangeText ]
-- Returns a compact display string for a category level range.
-- Used by the Groups tab to show subtle recommended level info.
--
-- @param categoryName  [string] The display name of the category
-- @return              [string] Compact range string (e.g. "[16-24]" or "[60]"), or nil if not found/hidden
function DBB2.api.GetCategoryLevelRangeText(categoryName)
  if not categoryName or categoryName == "Custom Category" then
    return nil
  end

  local levelRange = DBB2.api.GetCategoryLevelRange(categoryName)
  if not levelRange then
    return nil
  end

  if levelRange.minLevel == levelRange.maxLevel then
    return "[" .. levelRange.minLevel .. "]"
  end

  return "[" .. levelRange.minLevel .. "-" .. levelRange.maxLevel .. "]"
end

-- [ IsLevelAppropriate ]
-- Checks if a category is appropriate for the given player level.
-- Used to filter out content that is too high or too low level.
-- Categories without defined level ranges are considered appropriate for all levels.
--
-- @param categoryName  [string] The display name of the category
-- @param playerLevel   [number] Player's level (optional, defaults to UnitLevel("player"))
-- @return              [boolean] true if player level is within category's range, or if no range defined
function DBB2.api.IsLevelAppropriate(categoryName, playerLevel)
  playerLevel = playerLevel or UnitLevel("player")
  local levelRange = DBB2.api.GetCategoryLevelRange(categoryName)
  if levelRange then
    return playerLevel >= levelRange.minLevel and playerLevel <= levelRange.maxLevel
  end
  -- If no level range defined, assume it's appropriate for all levels
  return true
end

-- =====================================================
-- MESSAGE MATCHING API
-- =====================================================
-- Functions for matching messages to categories based on tags.

-- [ MatchMessageToCategory ]
-- Checks if a message matches any tag in a category.
-- Uses word boundary matching to avoid partial matches (e.g., "dm" won't match "admin").
--
-- Features:
-- - Supports wildcard patterns: * (any chars), ? (one char), [abc], [a-z], [!abc], {a,b,c}
-- - Matches tags followed by 1-2 digits or "x" + digits (e.g., "zg15", "ony12", "bmx2")
-- - Special handling for "aq" tag to distinguish Temple (40) from Ruins (20)
-- - Special handling for "kara" tag to distinguish Upper (40) from Lower (10)
-- - Applies tag exclusion rules to prevent false positives (e.g., "ST" for server time)
-- - If filter tags are enabled, message must match BOTH category tags AND filter tags
--
-- @param message        [string]  The message text to check
-- @param category       [table]   Category object with .selected, .tags, ._tagsLower, ._tagsLen
-- @param ignoreSelected [boolean] If true, skip the .selected check (for mode 2 filtering)
-- @param categoryType   [string]  Optional: "groups", "professions", or "hardcore" for filter tag checking
-- @param ignoreFilterTags [boolean] Optional: if true, skip the extra filter tag gate
-- @return               [boolean] true if message matches the category
function DBB2.api.MatchMessageToCategory(message, category, ignoreSelected, categoryType, ignoreFilterTags)
  if not category then
    return false
  end
  if not ignoreSelected and not category.selected then
    return false
  end
  if not category.tags then
    return false
  end
  
  -- Quick check: any tags at all?
  local hasAnyTags = false
  for _ in ipairs(category.tags) do
    hasAnyTags = true
    break
  end
  if not hasAnyTags then
    return false
  end
  
  local lowerMsg = string_lower(message or "")
  if lowerMsg == "" then return false end
  
  -- Check filter tags first (if enabled for this category type)
  -- This is an AND condition - message must match BOTH filter tags AND category tags
  if not ignoreFilterTags and categoryType and (categoryType == "groups" or categoryType == "professions") then
    if not DBB2.api.MatchFilterTags(message, categoryType) then
      return false
    end
  end
  
  -- Ensure pre-computed lowercase tags exist
  EnsureTagsPrecomputed(category)
  
  local msgLen = string_len(lowerMsg)
  local tagsLower = category._tagsLower
  local tagsLen = category._tagsLen
  
  -- Use ipairs instead of table.getn for Lua 5.0 compatibility
  for i, lowerTag in ipairs(tagsLower) do
    local tagLen = tagsLen[i]

    -- Check if tag contains wildcard special characters
    local isWildcard = string_find(lowerTag, "[%*%?%[%]%{%}\\]")

    if isWildcard then
      -- Use wildcard matching for patterns
      if DBB2.api.MatchWildcard(lowerMsg, lowerTag) then
        return true
      end
    else
      -- Plain text matching with word boundaries
      local startPos = 1

      while true do
        local foundPos = string_find(lowerMsg, lowerTag, startPos, true)
        if not foundPos then
          break
        end

        -- Check character before the match (must be start or non-alphanumeric)
        local charBefore = ""
        if foundPos > 1 then
          charBefore = string_sub(lowerMsg, foundPos - 1, foundPos - 1)
        end

        -- Check character after the match
        local afterPos = foundPos + tagLen
        local charAfter = ""
        if afterPos <= msgLen then
          charAfter = string_sub(lowerMsg, afterPos, afterPos)
        end

        -- Check if boundaries are word boundaries (not letters or numbers)
        local validBefore = (foundPos == 1) or not string_find(charBefore, "[%w]")

        -- For validAfter, we allow 1-2 trailing digits (raid group sizes like
        -- "zg15", "ony12") and also "x" + digits for run-count shorthand like "bmx2".
        -- Special case: "aq" tag should only use direct numeric suffixes to
        -- distinguish Temple (40) from Ruins (20).
        local validAfter = false
        if afterPos > msgLen then
          -- End of message - valid
          validAfter = true
        elseif not string_find(charAfter, "[%w]") then
          -- Non-alphanumeric after - valid word boundary
          validAfter = true
        elseif string_find(charAfter, "%d") then
          -- Digit after tag - check for raid group size pattern (1-2 digits)
          local digit1 = charAfter
          local digit2 = ""
          local charAfterDigits = ""
          local digitEndPos = afterPos + 1

          -- Check for second digit
          if digitEndPos <= msgLen then
            local nextChar = string_sub(lowerMsg, digitEndPos, digitEndPos)
            if string_find(nextChar, "%d") then
              digit2 = nextChar
              digitEndPos = digitEndPos + 1
            end
          end

          -- Check character after the digits
          if digitEndPos <= msgLen then
            charAfterDigits = string_sub(lowerMsg, digitEndPos, digitEndPos)
          end

          -- Valid if digits are followed by word boundary
          local digitsFollowedByBoundary = (digitEndPos > msgLen) or not string_find(charAfterDigits, "[%w]")

          if digitsFollowedByBoundary then
            -- Special handling for "aq" tag to distinguish Temple (40-man) from Ruins (20-man)
            -- "aq40" -> Temple of Ahn'Qiraj only
            -- "aq" + any other number (aq13, aq15, aq20, etc.) -> Ruins of Ahn'Qiraj
            if lowerTag == "aq" then
              local digitSuffix = digit1 .. digit2
              -- Check which category we're matching against by looking at category name
              local catNameLower = string_lower(category.name or "")
              if string_find(catNameLower, "temple") or string_find(catNameLower, "aq40") then
                -- Temple of Ahn'Qiraj - only match "aq40"
                if digitSuffix == "40" then
                  validAfter = true
                end
              elseif string_find(catNameLower, "ruins") or string_find(catNameLower, "aq20") then
                -- Ruins of Ahn'Qiraj - match any number except "40"
                if digitSuffix ~= "40" then
                  validAfter = true
                end
              end
            -- Special handling for "kara" tag to distinguish Upper (40-man) from Lower (10-man)
            -- "kara40" -> Upper Karazhan Halls only
            -- "kara" + any other number (kara10, kara15, etc.) -> Lower Karazhan Halls
            elseif lowerTag == "kara" then
              local digitSuffix = digit1 .. digit2
              local catNameLower = string_lower(category.name or "")
              if string_find(catNameLower, "upper") or string_find(catNameLower, "ukh") then
                -- Upper Karazhan Halls - only match "kara40"
                if digitSuffix == "40" then
                  validAfter = true
                end
              elseif string_find(catNameLower, "lower") or string_find(catNameLower, "lkh") then
                -- Lower Karazhan Halls - match any number except "40"
                if digitSuffix ~= "40" then
                  validAfter = true
                end
              end
            else
              -- For all other tags, allow any 1-2 digit suffix
              validAfter = true
            end
          end
        elseif charAfter == "x" then
          -- Support shorthand like "bmx2" or "mcx3" where the tag is followed by
          -- a run-count marker instead of a direct size suffix.
          local digitPos = afterPos + 1
          local digit1 = ""
          local digit2 = ""
          local charAfterDigits = ""
          
          if digitPos <= msgLen then
            digit1 = string_sub(lowerMsg, digitPos, digitPos)
          end
          
          if string_find(digit1, "%d") then
            digitPos = digitPos + 1
            
            if digitPos <= msgLen then
              local nextChar = string_sub(lowerMsg, digitPos, digitPos)
              if string_find(nextChar, "%d") then
                digit2 = nextChar
                digitPos = digitPos + 1
              end
            end
            
            if digitPos <= msgLen then
              charAfterDigits = string_sub(lowerMsg, digitPos, digitPos)
            end
            
            if digitPos > msgLen or not string_find(charAfterDigits, "[%w]") then
              validAfter = true
            end
          end
        end

        if validBefore and validAfter then
          -- Check tag exclusions for false positives (uses DBB2.env.IsTagExcluded)
          if not DBB2.env.IsTagExcluded(lowerTag, lowerMsg, foundPos, tagLen, category) then
            return true
          end
        end

        -- Continue searching from next position
        startPos = foundPos + 1
      end
    end  -- end else (plain text matching)
  end
  return false
end


-- [ CategorizeMessage ]
-- Determines which categories a message belongs to across all category types.
-- Checks groups, professions, and hardcore categories.
--
-- @param message          [string]  The message text to categorize
-- @param ignoreSelected   [boolean] If true, match against all categories regardless of enabled state
-- @param ignoreFilterTags [boolean] If true, skip group/profession filter tag checks
-- @return               [table]   Result table with structure:
--                                 {
--                                   groups = {string...},      -- Array of matched group category names
--                                   professions = {string...}, -- Array of matched profession category names
--                                   hardcore = {string...},    -- Array of matched hardcore category names
--                                   isHardcore = boolean       -- true if any hardcore category matched
--                                 }
function DBB2.api.CategorizeMessage(message, ignoreSelected, ignoreFilterTags)
  -- Create fresh result table each call (safer than pooling)
  local result = {
    groups = {},
    professions = {},
    hardcore = {},
    isHardcore = false
  }
  
  if not message then return result end
  if not DBB2_Config.categories then return result end
  
  -- Check groups (pass categoryType for filter tag checking)
  for _, cat in ipairs(DBB2_Config.categories.groups or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "groups", ignoreFilterTags) then
      table_insert(result.groups, cat.name)
    end
  end
  
  -- Check professions (pass categoryType for filter tag checking)
  for _, cat in ipairs(DBB2_Config.categories.professions or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "professions", ignoreFilterTags) then
      table_insert(result.professions, cat.name)
    end
  end
  
  -- Check hardcore (no filter tags for hardcore)
  for _, cat in ipairs(DBB2_Config.categories.hardcore or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "hardcore", ignoreFilterTags) then
      table_insert(result.hardcore, cat.name)
      result.isHardcore = true
    end
  end
  
  return result
end

-- [ GetCategorizedMessages ]
-- Returns all messages organized by category for a given type.
-- Only includes messages for selected (enabled) categories.
-- Applies duplicate filtering per category (same sender + message within spam window).
-- Hardcore messages are excluded from groups/professions tabs and vice versa.
--
-- @param categoryType  [string] Category type: "groups", "professions", or "hardcore"
-- @return              [table]  Table mapping category names to message arrays:
--                               { ["Molten Core"] = {msg1, msg2, ...}, ["BWL"] = {...}, ... }
--                               Each message has: sender, message, time, channel, etc.
function DBB2.api.GetCategorizedMessages(categoryType)
  local categorized = {}
  
  if not categoryType then return categorized end
  
  local categories = DBB2.api.GetCategories(categoryType)
  local spamSeconds = DBB2_Config.spamFilterSeconds or 150
  
  -- Initialize empty arrays for each selected category
  for _, cat in ipairs(categories) do
    if cat.selected then
      categorized[cat.name] = {}
    end
  end
  
  -- Guard against nil messages table
  if not DBB2.messages then return categorized end
  
  -- Helper to check if message is duplicate within a category's message list
  local function isDuplicateInCategory(catMessages, msg)
    if spamSeconds <= 0 then return false end
    
    local lowerMsg = string_lower(DBB2.api.StripHyperlinks(msg.message or ""))
    local lowerSender = string_lower(msg.sender or "")
    local msgTime = msg.time or 0
    
    for _, existing in ipairs(catMessages) do
      local timeDiff = math_abs(msgTime - (existing.time or 0))
      if timeDiff <= spamSeconds then
        local existingMsg = string_lower(DBB2.api.StripHyperlinks(existing.message or ""))
        local existingSender = string_lower(existing.sender or "")
        if existingSender == lowerSender and existingMsg == lowerMsg then
          return true
        end
      end
    end
    return false
  end
  
  -- Categorize each message
  for _, msg in ipairs(DBB2.messages) do
    local msgCategories = DBB2.api.CategorizeMessage(msg.message)
    
    if categoryType == "hardcore" then
      -- Only show hardcore messages in hardcore tab
      for _, catName in ipairs(msgCategories.hardcore) do
        if categorized[catName] then
          if not isDuplicateInCategory(categorized[catName], msg) then
            table_insert(categorized[catName], msg)
          end
        end
      end
    else
      -- Skip hardcore messages in other tabs
      if not msgCategories.isHardcore then
        local matchedCats = msgCategories[categoryType] or {}
        for _, catName in ipairs(matchedCats) do
          if categorized[catName] then
            if not isDuplicateInCategory(categorized[catName], msg) then
              table_insert(categorized[catName], msg)
            end
          end
        end
      end
    end
  end
  
  return categorized
end
```

## api/channels.lua
```lua
-- DBB2 Channel Management API
-- All channel-related functionality: whitelist, monitoring config, auto-join
-- Dependencies: env/defaults.lua, api/hardcore.lua (for IsHardcoreCharacter)

local string_lower = string.lower
local string_len = string.len
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs
local pairs = pairs

-- =====================
-- CHANNEL WHITELIST API
-- =====================

-- Returns the list of whitelisted channel names
function DBB2.api.GetWhitelistedChannels()
  if not DBB2_Config.whitelistedChannels then
    DBB2_Config.whitelistedChannels = {}
    for i, ch in ipairs(DBB2.env.defaultWhitelistedChannels) do
      DBB2_Config.whitelistedChannels[i] = ch
    end
  end
  return DBB2_Config.whitelistedChannels
end

-- Checks if a channel is in the whitelist (uses prefix matching for city suffixes)
function DBB2.api.IsChannelWhitelisted(channelName)
  if not channelName then return false end
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    local lowerWhitelist = string_lower(name)
    local whitelistLen = string_len(lowerWhitelist)
    if string_sub(lowerName, 1, whitelistLen) == lowerWhitelist then
      local nextChar = string_sub(lowerName, whitelistLen + 1, whitelistLen + 1)
      if nextChar == "" or nextChar == " " or nextChar == "-" then
        return true
      end
    end
  end
  return false
end

-- Adds a channel to the whitelist (returns true if added, false if exists)
function DBB2.api.AddWhitelistedChannel(channelName)
  if not channelName or channelName == "" then return false end
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    if string_lower(name) == lowerName then return false end
  end
  
  table_insert(DBB2_Config.whitelistedChannels, lowerName)
  return true
end

-- Removes a channel from the whitelist (returns true if removed, false if not found)
function DBB2.api.RemoveWhitelistedChannel(channelName)
  if not channelName then return false end
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for i = table_getn(whitelist), 1, -1 do
    if string_lower(whitelist[i]) == lowerName then
      table_remove(DBB2_Config.whitelistedChannels, i)
      return true
    end
  end
  return false
end

-- Resets the whitelist to defaults
function DBB2.api.ResetWhitelistedChannels()
  DBB2_Config.whitelistedChannels = {}
  for i, ch in ipairs(DBB2.env.defaultWhitelistedChannels) do
    DBB2_Config.whitelistedChannels[i] = ch
  end
end

-- Returns a list of channels the player has joined
function DBB2.api.GetJoinedChannels()
  local channels = {}
  local list = { GetChannelList() }
  for i = 1, table_getn(list), 2 do
    local id, name = list[i], list[i + 1]
    if id and name then
      table_insert(channels, { id = id, name = name })
    end
  end
  return channels
end

-- =====================
-- CHANNEL MONITORING CONFIG API
-- =====================

-- Initializes channel monitoring config if not present
function DBB2.api.InitChannelConfig()
  if not DBB2_Config.monitoredChannels then
    DBB2_Config.monitoredChannels = {}
    for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
    if DBB2_Config.monitoredChannels[channel] == nil then
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  if DBB2_Config.autoJoinChannels == nil then
    DBB2_Config.autoJoinChannels = true
  end
end

-- Resets channel monitoring to defaults based on character type
-- Returns true if hardcore defaults applied, false if normal
function DBB2.api.ResetChannelDefaults()
  local isHardcore = DBB2.api.IsHardcoreCharacter()
  
  DBB2_Config.monitoredChannels = {}
  for channel, _ in pairs(DBB2.env.defaultMonitoredChannels) do
    DBB2_Config.monitoredChannels[channel] = false
  end
  
  if isHardcore then
    DBB2_Config.monitoredChannels["Hardcore"] = true
    DBB2_Config.monitoredChannels["Guild"] = true
    DBB2_Config.hardcoreChannelsInitialized = true
  else
    for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  
  DBB2.api.ResetWhitelistedChannels()
  return isHardcore
end

-- Fetches all currently joined channels and adds them to config
-- Returns array of channel names (static order + separators + dynamic)
function DBB2.api.RefreshJoinedChannels()
  DBB2.api.InitChannelConfig()
  local joinedChannels = DBB2.api.GetJoinedChannels()
  
  local staticChannels = {}
  for _, name in ipairs(DBB2.env.staticChannelOrder) do
    if name ~= "-" then staticChannels[name] = true end
  end
  
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and DBB2_Config.monitoredChannels[name] == nil then
      DBB2_Config.monitoredChannels[name] = false
    end
  end
  
  local result = {}
  for _, name in ipairs(DBB2.env.staticChannelOrder) do
    table_insert(result, name)
  end
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and not staticChannels[name] then
      table_insert(result, name)
    end
  end
  return result
end

-- Returns whether a specific channel is enabled for monitoring
function DBB2.api.IsChannelMonitored(channelName)
  if not channelName then return false end
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels[channelName] or false
end

-- Enables or disables monitoring for a specific channel
function DBB2.api.SetChannelMonitored(channelName, enabled)
  if not channelName then return end
  DBB2.api.InitChannelConfig()
  DBB2_Config.monitoredChannels[channelName] = enabled
  if enabled then
    DBB2.api.AddWhitelistedChannel(channelName)
  else
    DBB2.api.RemoveWhitelistedChannel(channelName)
  end
end

-- Returns table of all monitored channel settings
function DBB2.api.GetMonitoredChannels()
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels
end

-- =====================
-- AUTO-JOIN CHANNELS
-- =====================

-- Automatically joins World and LookingForGroup channels if not already joined
function DBB2.api.AutoJoinRequiredChannels()
  if DBB2_Config.autoJoinChannels == false then return end
  
  local joinedChannels = DBB2.api.GetJoinedChannels()
  local joinedLookup = {}
  for _, ch in ipairs(joinedChannels) do
    if ch.name then joinedLookup[string_lower(ch.name)] = true end
  end
  
  for _, channelName in ipairs(DBB2.env.autoJoinChannels) do
    local lowerName = string_lower(channelName)
    if not joinedLookup[lowerName] then
      JoinChannelByName(channelName)
      local hr, hg, hb = DBB2:GetHighlightColor()
      local hexColor = string.format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
      DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: Auto-joined |cffffffff" .. channelName .. "|r channel.")
    end
  end
end
```

## api/chat_filter.lua
```lua
-- DBB2 Chat Filter API
-- Handles chat frame hook system to hide captured messages from normal chat
--
-- Dependencies: api/blacklist.lua (IsMessageBlacklisted, IsBlacklistHideFromChatEnabled)
--               api/categories_api.lua (GetCategories, MatchMessageToCategory)
-- This file must be loaded AFTER blacklist.lua and categories_api.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_gsub = string.gsub
local ipairs = ipairs
local pcall = pcall
local getglobal = getglobal

-- [ ExtractFormattedMessageContent ]
-- Strips the channel/sender wrappers from a rendered chat line so filtering uses
-- the same plain message body that AddMessage receives from chat events.
-- 'message'    [string]        the formatted message from the chat frame
-- return:      [string]        plain message content
-- return:      [string|nil]    extracted sender name, if present
local function ExtractFormattedMessageContent(message)
  if not message then return "", nil end
  
  local content = message
  
  -- Remove a single leading channel block such as "[5. World] ", "[5] ", or "[H] ".
  content = string_gsub(content, "^%[[^%]]+%]%s*", "", 1)
  
  -- Extract "[Sender]: message"
  local _, _, sender, body = string_find(content, "^%[([^%]]+)%]%s*:%s*(.*)$")
  if sender then
    return body or "", sender
  end
  
  -- Fallback for formats like "Sender: message"
  _, _, sender, body = string_find(content, "^([^:]+):%s*(.*)$")
  if sender then
    sender = string_gsub(sender, "^%s*(.-)%s*$", "%1")
    if not string_find(sender, "^%d+$") and sender ~= "H" and sender ~= "" then
      return body or "", sender
    end
  end
  
  return content, nil
end

-- [ IsEnabledChatSource ]
-- Checks whether the current chat event source is one DBB2 is actively watching.
-- This keeps hide-from-chat aligned with the Channels config tab for all enabled
-- source types, not just numbered chat channels.
-- 'message'    [string]        formatted chat line (used for fallback parsing)
-- return:      [boolean]       true if this line comes from an enabled source
local function IsEnabledChatSource(message)
  if event == "CHAT_MSG_CHANNEL" then
    local channelName = arg9
    return channelName and DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(channelName) or false
  end
  
  if event == "CHAT_MSG_GUILD" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Guild") or false
  end
  
  if event == "CHAT_MSG_SAY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Say") or false
  end
  
  if event == "CHAT_MSG_YELL" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Yell") or false
  end
  
  if event == "CHAT_MSG_PARTY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Party") or false
  end
  
  if event == "CHAT_MSG_WHISPER" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Whisper") or false
  end
  
  if event == "CHAT_MSG_HARDCORE" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Hardcore") or false
  end
  
  -- Fallback when the line is not being added during a live chat event.
  return DBB2.api.IsFilterableChannel(message)
end

-- =====================
-- CHAT FILTER DETECTION
-- =====================

-- [ IsSystemMessage ]
-- Detects if a message is a WoW system message that should never be filtered
-- System messages include: /who results, combat log, loot, experience, etc.
-- 'message'    [string]        the message text (may include color codes)
-- return:      [boolean]       true if this is a system message
function DBB2.api.IsSystemMessage(message)
  if not message then return false end
  
  -- /who results format: "[Name]: Level XX Race Class <Guild> - Zone"
  -- The key identifier is the format with Level + Race + Class pattern
  -- Example: "[Hexbear]: Level 60 Night Elf Druid <Phoenix Rising> - Ahn'Qiraj"
  
  -- Check for /who result pattern: "Level [number] [race] [class]"
  -- This pattern is unique to /who results and won't match normal chat
  if string_find(message, "Level %d+ %a+ %a+") then
    return true
  end
  
  -- Also check for the "X player(s) total" message that accompanies /who
  if string_find(message, "%d+ players? total") then
    return true
  end
  
  -- Check for common system message patterns that might accidentally match categories
  -- These are WoW system messages, not player chat
  
  -- Loot messages: "You receive loot: [Item]"
  if string_find(message, "^You receive") then
    return true
  end
  
  -- Experience messages: "You gain X experience"
  if string_find(message, "^You gain %d+ experience") then
    return true
  end
  
  -- Reputation messages: "Your reputation with X has increased"
  if string_find(message, "^Your reputation") then
    return true
  end
  
  -- Skill up messages: "Your skill in X has increased to Y"
  if string_find(message, "^Your skill in") then
    return true
  end
  
  -- Discovery messages: "Discovered: Zone"
  if string_find(message, "^Discovered:") then
    return true
  end
  
  -- Quest messages
  if string_find(message, "^Quest ") or string_find(message, " completed%.$") then
    return true
  end
  
  return false
end

-- [ IsFilterableChannel ]
-- Checks if a formatted chat message is from a channel that should be filtered
-- Filterable channels: addon-whitelisted chat channels such as World, General,
-- LookingForGroup, Trade, Hardcore, and custom channels the addon monitors.
-- Custom channel format: "[X] [PlayerName]: message" (X = channel number only)
-- Built-in channel format: "[X. ChannelName] [PlayerName]: message" (number + dot + name)
-- Trade can also be "[2. Trade - City]" format
-- Hardcore channel format: "[H] [PlayerName]: message"
-- Uses the channel whitelist so chat hiding matches what DBB2 actually captures
-- from CHAT_MSG_CHANNEL.
-- 'message'    [string]        the formatted message from chat frame
-- return:      [boolean]       true if from a filterable channel
function DBB2.api.IsFilterableChannel(message)
  if not message then return false end
  
  local lowerMsg = string_lower(message)
  
  -- Check for Hardcore channel: "[H] " prefix (Turtle WoW specific)
  if string_find(lowerMsg, "^%[h%]") then
    return true
  end
  
  -- Check built-in channel format: "[X. ChannelName]"
  local _, _, namedChannel = string_find(message, "^%[%d+%.%s*([^%]]+)%]")
  if namedChannel then
    if DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(namedChannel) then
      return true
    end
  end
  
  -- Check for custom channel format: "[5]" at the start (number only, no dot)
  -- This format is used by custom channels on private servers and also covers
  -- chat frames that render only the channel number.
  local _, _, channelNum = string_find(message, "^%[(%d+)%]")
  if channelNum then
    -- GetChannelName returns: id, name (we need the second return value)
    local _, channelName = GetChannelName(tonumber(channelNum))
    if channelName and DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(channelName) then
      return true
    end
  end
  
  return false
end

-- [ IsOwnMessage ]
-- Checks if a message was sent by the player themselves
-- 'sender'     [string]        the sender name extracted from the message
-- return:      [boolean]       true if the sender is the player
function DBB2.api.IsOwnMessage(sender)
  if not sender then return false end
  
  -- Get the player's name
  local playerName = UnitName("player")
  if not playerName then return false end
  
  -- Compare case-insensitively
  return string_lower(sender) == string_lower(playerName)
end

-- [ ShouldHideFromChat ]
-- Checks if a message should be hidden from normal chat
-- hideFromChat modes: 0 = disabled, 1 = enabled (selected only), 2 = enabled (all categories)
-- Mode 1: Hide messages matching selected categories only
-- Mode 2: Hide messages matching any category (even disabled ones)
-- Also hides blacklisted messages when blacklist.hideFromChat is enabled (independent of hideFromChat mode)
-- Also hides duplicates when hideFromChat is enabled
-- IMPORTANT: Never hides system messages (like /who results) even if they match category patterns
-- IMPORTANT: Only filters messages from sources enabled in the Channels tab
-- IMPORTANT: Never filters the player's own messages
-- IMPORTANT: Category hiding intentionally ignores optional filter tags so broad
-- group/profession tags like "dm" or "mc" can still be suppressed from chat.
function DBB2.api.ShouldHideFromChat(message, sender, matchMessage)
  local mode = DBB2_Config.hideFromChat or 0
  local hideBlacklisted = DBB2.api.IsBlacklistHideFromChatEnabled()
  local textToMatch = matchMessage or message or ""
  
  -- If both hideFromChat and hideBlacklisted are disabled, nothing to filter
  if (mode == 0 or mode == false) and not hideBlacklisted then
    return false
  end
  
  -- CRITICAL: Never filter the player's own messages
  -- This ensures the player always sees what they typed
  if DBB2.api.IsOwnMessage(sender) then
    return false
  end
  
  -- CRITICAL: Only filter messages from sources enabled in the Channels tab
  if not IsEnabledChatSource(message) then
    return false
  end
  
  -- CRITICAL: Never filter system messages, even if they match category patterns
  -- This protects /who results, loot messages, skill ups, etc.
  if DBB2.api.IsSystemMessage(message) then
    return false
  end
  
  -- Check blacklist (hide if blacklist.hideFromChat is enabled, independent of hideFromChat mode)
  if hideBlacklisted and DBB2.api.IsMessageBlacklisted then
    local blocked = DBB2.api.IsMessageBlacklisted(textToMatch, sender)
    if blocked then
      return true
    end
  end
  
  -- If hideFromChat mode is disabled, don't check categories or duplicates
  if mode == 0 or mode == false then
    return false
  end
  
  local ignoreSelected = (mode == 2)  -- Mode 2 ignores selected state
  local matchesCategory = false

  -- Hide-from-chat should be broader than the optional bulletin board filter tag
  -- gate. The GUI/storage path can still require LF/LFG/LFM style tags, but chat
  -- suppression should catch obvious run keywords on their own.
  if DBB2.api.CategorizeMessage then
    local categories = DBB2.api.CategorizeMessage(textToMatch, ignoreSelected, true)
    matchesCategory =
      (categories.groups and categories.groups[1] ~= nil) or
      (categories.professions and categories.professions[1] ~= nil) or
      (categories.hardcore and categories.hardcore[1] ~= nil)
  else
    local categoryTypes = {"groups", "professions", "hardcore"}
    for _, categoryType in ipairs(categoryTypes) do
      local categories = DBB2.api.GetCategories(categoryType)
      if categories then
        for _, cat in ipairs(categories) do
          if DBB2.api.MatchMessageToCategory(textToMatch, cat, ignoreSelected, categoryType, true) then
            matchesCategory = true
            break
          end
        end
      end
      if matchesCategory then break end
    end
  end
  
  -- If message matches a category, also hide duplicates
  -- This ensures duplicate messages are hidden even when the original was hidden
  if matchesCategory then
    return true
  end
  
  -- Also check for duplicates of messages that would match categories
  -- This catches the case where a duplicate comes in after the original was already stored
  -- Extract just the message content (after sender) for duplicate comparison
  if DBB2.api.IsDuplicateMessage then
    if DBB2.api.IsDuplicateMessage(textToMatch, sender) then
      return true
    end
  end
  
  return false
end

-- =====================
-- CHAT FRAME HOOKS
-- =====================

-- Track which chat frames we've hooked (by frame index)
-- Using a table since we can't add properties to functions in Lua 5.0
DBB2._hookedChatFrames = DBB2._hookedChatFrames or {}

-- [ SetupChatFilter ]
-- Hooks into chat frames to filter captured messages
-- Uses tracking table to prevent double-hooking on addon reload
function DBB2.api.SetupChatFilter()
  -- Store original AddMessage functions (only if not already stored)
  if not DBB2.originalAddMessage then
    DBB2.originalAddMessage = {}
  end
  
  -- Hook all chat frames
  for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = getglobal("ChatFrame" .. i)
    if chatFrame and chatFrame.AddMessage then
      if DBB2._hookedChatFrames[i] then
        -- Already hooked, skip
      else
        -- Store original function
        local originalFunc = chatFrame.AddMessage
        DBB2.originalAddMessage[i] = originalFunc
        
        -- Mark as hooked
        DBB2._hookedChatFrames[i] = true
        
        -- Create our hook function
        -- Use closure to capture the frame index
        local frameIndex = i
        chatFrame.AddMessage = function(self, msg, r, g, b, id)
          -- Safety check: ensure we have a valid original to call
          local origToCall = DBB2.originalAddMessage[frameIndex]
          if not origToCall then
            return
          end
          
          -- Check if this message should be filtered
          -- Filter runs if hideFromChat is enabled OR hideBlacklistedFromChat is enabled
          local hideFromChatEnabled = DBB2_Config and DBB2_Config.hideFromChat and DBB2_Config.hideFromChat ~= 0
          local hideBlacklistedEnabled = DBB2_Config and DBB2_Config.blacklist and DBB2_Config.blacklist.hideFromChat
          
          if msg and (hideFromChatEnabled or hideBlacklistedEnabled) then
            -- Normalize the formatted chat line into the same plain message body
            -- used by CHAT_MSG_* events before applying blacklist/category checks.
            local cleanMsg = msg
            -- Remove color codes |cXXXXXXXX and |r
            cleanMsg = string_gsub(cleanMsg, "|c%x%x%x%x%x%x%x%x", "")
            cleanMsg = string_gsub(cleanMsg, "|r", "")
            -- Remove hyperlinks |H[player:NAME]|h[NAME]|h -> NAME
            cleanMsg = string_gsub(cleanMsg, "|H[^|]*|h([^|]*)|h", "%1")
            
            local msgContent, extractedSender = ExtractFormattedMessageContent(cleanMsg)
            
            -- Try to extract sender name from message format
            -- World format: "[5] [Sender]: message" (number = channel)
            -- Hardcore format: "[H] [Sender]: message"
            -- Guild format: "[Sender]: message"
            local sender = nil
            
            sender = extractedSender
            
            -- Wrap in pcall to prevent errors from breaking chat
            local success, shouldHide = pcall(DBB2.api.ShouldHideFromChat, cleanMsg, sender, msgContent)
            if success and shouldHide then
              return  -- Don't show this message
            end
          end
          
          -- Call original function
          origToCall(self, msg, r, g, b, id)
        end
      end
    end
  end
end

-- [ RemoveChatFilter ]
-- Removes our chat hooks and restores original functions
-- Call this if you need to cleanly disable the filter
function DBB2.api.RemoveChatFilter()
  if not DBB2.originalAddMessage then return end
  
  for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = getglobal("ChatFrame" .. i)
    if chatFrame and DBB2.originalAddMessage[i] and DBB2._hookedChatFrames[i] then
      chatFrame.AddMessage = DBB2.originalAddMessage[i]
      DBB2._hookedChatFrames[i] = nil
    end
  end
  
  -- Clear stored references
  DBB2.originalAddMessage = nil
end
```

## api/config_schema.lua
```lua
-- DBB2 Config Schema API
-- Core schema rendering system and basic widget renderers
-- Complex list widgets are in api/config_widgets.lua
-- Constants are in env/constants.lua

-- Localize frequently used globals for performance
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

DBB2.api = DBB2.api or {}

-- Local references to env constants (for performance)
local SPACING = DBB2.env.SPACING
local DEFAULT_WIDTH = DBB2.env.DEFAULT_WIDTH
local FONT_SIZE = DBB2.env.FONT_SIZE
local FONT_SIZE_INPUT = DBB2.env.FONT_SIZE_INPUT
local FONT_SIZE_SMALL = DBB2.env.FONT_SIZE_SMALL
local FONT_SIZE_LARGE = DBB2.env.FONT_SIZE_LARGE
local SECTION_FONT_SIZE = DBB2.env.SECTION_FONT_SIZE

-- ============================================================================
-- [ CreateConfigInput ]
-- ============================================================================
-- Creates an input box (EditBox) specifically styled for config panels.
-- The input box has a minimal border style that matches slider boxes,
-- with highlight color on hover for visual feedback.
--
-- This function is GLOBAL so that config_widgets.lua can access it.
--
-- Parameters:
--   name (string|nil) - Optional frame name for the EditBox.
--   parent (Frame)    - The parent frame to attach the EditBox to.
--
-- Returns:
--   EditBox - A styled EditBox frame with:
--     - Border textures (borderTop, borderBottom, borderLeft, borderRight)
--     - Highlight color on hover
--     - Escape key clears focus
--     - Height set to SPACING.inputHeight
-- ============================================================================
function CreateConfigInput(name, parent)
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(DBB2:ScaleSize(SPACING.inputHeight))
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(3), DBB2:ScaleSize(3))
  f:SetJustifyH("LEFT")
  
  -- Set font directly with explicit bright white color
  f:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE_INPUT))
  f:SetTextColor(1, 1, 1, 1)
  
  -- Border textures only (no background) - matches slider box style
  f.borderTop = f:CreateTexture(nil, "BORDER")
  f.borderTop:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderTop:SetHeight(1)
  f.borderTop:SetPoint("TOPLEFT", -1, 1)
  f.borderTop:SetPoint("TOPRIGHT", 1, 1)
  
  f.borderBottom = f:CreateTexture(nil, "BORDER")
  f.borderBottom:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderBottom:SetHeight(1)
  f.borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
  f.borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
  
  f.borderLeft = f:CreateTexture(nil, "BORDER")
  f.borderLeft:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderLeft:SetWidth(1)
  f.borderLeft:SetPoint("TOPLEFT", -1, 1)
  f.borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
  
  f.borderRight = f:CreateTexture(nil, "BORDER")
  f.borderRight:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderRight:SetWidth(1)
  f.borderRight:SetPoint("TOPRIGHT", 1, 1)
  f.borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.borderTop:SetTexture(r, g, b, 1)
    this.borderBottom:SetTexture(r, g, b, 1)
    this.borderLeft:SetTexture(r, g, b, 1)
    this.borderRight:SetTexture(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.borderTop:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderBottom:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderLeft:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderRight:SetTexture(0.2, 0.2, 0.2, 1)
  end)
  
  return f
end

-- ============================================================================
-- [ RenderConfigSchema ]
-- ============================================================================
-- Renders a declarative config schema into a scrollable panel with widgets.
-- This is the main entry point for building configuration UI panels using
-- the schema-based approach. Each schema item defines a widget type and its
-- configuration, which is then rendered into the panel.
--
-- Parameters:
--   panel (Frame)  - The parent frame to render the config UI into.
--                    Will have scrollFrame and _widgets attached to it.
--   schema (table) - Array of widget definitions. Each item is a table with:
--                    - type (string): Widget type - "section", "description",
--                      "slider", "toggle", "colorpicker", "checkbox",
--                      "channelList", "categoryList", "keywordList",
--                      "keywordImportExport", or "editbox"
--                    - Additional fields depend on widget type (see below)
--   options (table, optional) - Reserved for future configuration options.
--
-- Schema Widget Types:
--   section:     { type="section", label="Section Title" }
--   description: { type="description", text="Help text", fontSize=8 }
--   slider:      { type="slider", key="configKey", label="Label",
--                  min=0, max=100, step=1, default=50, width=250,
--                  tooltip="Help", valueLabels={[0]="Off"}, onChange=fn }
--   toggle:      { type="toggle", key="configKey", label="Label",
--                  default=false, width=250, tooltip="Help", onChange=fn }
--   colorpicker: { type="colorpicker", key="configKey", label="Label",
--                  default={r=1,g=1,b=1,a=1}, width=250, tooltip="Help",
--                  onChange=fn }
--   checkbox:    { type="checkbox", key="configKey", label="Label",
--                  default=false, tooltip="Help", onChange=fn }
--   channelList: { type="channelList" }
--   categoryList:{ type="categoryList", categoryType="groups"|"professions",
--                  showFilterTags=true }
--   keywordList: { type="keywordList" }
--   keywordImportExport: { type="keywordImportExport" }
--   editbox:     { type="editbox", placeholder="Text...", onEnter=fn }
--
-- Returns:
--   table - A result table containing:
--     - scrollFrame (Frame): The scroll frame widget
--     - scrollChild (Frame): The scroll child containing all widgets
--     - widgets (table): Array of created widget references
--     - panel (Frame): Reference to the input panel
--
-- Usage Example:
--   local schema = {
--     { type = "section", label = "Display Settings" },
--     { type = "slider", key = "fontOffset", label = "Font Size",
--       min = -6, max = 6, step = 1, default = 0 },
--     { type = "toggle", key = "showCurrentTime", label = "Show Time",
--       default = false },
--   }
--   DBB2.api.RenderConfigSchema(myPanel, schema)
-- ============================================================================
function DBB2.api.RenderConfigSchema(panel, schema, options)
  options = options or {}
  local scrollPadding = DBB2:ScaleSize(5)
  
  -- Create scroll frame
  local scrollFrame = DBB2.schema.CreateStaticScrollFrame(nil, panel)
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  panel.scrollFrame = scrollFrame
  
  -- Scrollbar padding
  scrollFrame.slider:ClearAllPoints()
  scrollFrame.slider:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -scrollPadding)
  scrollFrame.slider:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, scrollPadding)
  
  -- Create scroll child
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(1)
  scrollChild:SetHeight(1)
  scrollFrame:SetScrollChild(scrollChild)
  scrollFrame.scrollChild = scrollChild
  
  -- Store schema and rendering state on panel for rebuilding
  panel._schema = schema
  panel._widgets = {}
  panel._xOffset = DBB2:ScaleSize(SPACING.padding)
  
  -- Function to render/rebuild all widgets
  local function RenderAllWidgets()
    local hr, hg, hb = DBB2:GetHighlightColor()
    local yOffset = -DBB2:ScaleSize(SPACING.padding)
    local xOffset = panel._xOffset
    local lastType = nil
    
    for i, item in ipairs(schema) do
      local widget = panel._widgets[i]
      local widgetHeight = 0
      
      -- Calculate spacing
      local spacing = SPACING.widget
      if lastType == "section" then
        if item.type == "description" then
          spacing = 2
        else
          spacing = SPACING.afterSection
        end
      elseif lastType == "description" then spacing = SPACING.description
      elseif item.type == "section" then spacing = SPACING.section
      end
      
      if lastType then
        yOffset = yOffset - DBB2:ScaleSize(spacing)
      end
      
      -- Create widget if not exists, otherwise just reposition
      if not widget then
        if item.type == "section" then
          widget = DBB2.schema.CreateLabel(scrollChild, item.label, SECTION_FONT_SIZE)
          widget:SetTextColor(hr, hg, hb, 1)
        elseif item.type == "description" then
          widget = DBB2.schema.CreateLabel(scrollChild, item.text, item.fontSize or FONT_SIZE_SMALL)
          widget:SetTextColor(0.5, 0.5, 0.5, 1)
        elseif item.type == "slider" then
          widget = RenderSlider(scrollChild, item, xOffset, yOffset)
        elseif item.type == "toggle" then
          widget = RenderToggle(scrollChild, item, xOffset, yOffset)
        elseif item.type == "colorpicker" then
          widget = RenderColorPicker(scrollChild, item, xOffset, yOffset)
        elseif item.type == "checkbox" then
          widget = RenderCheckbox(scrollChild, item, xOffset, yOffset)
        elseif item.type == "channelList" then
          widget = RenderChannelList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "categoryList" then
          widget = RenderCategoryList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "keywordList" then
          widget = RenderKeywordList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "keywordImportExport" then
          widget = RenderKeywordImportExport(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "editbox" then
          widget = RenderEditBox(scrollChild, item, xOffset, yOffset)
        end
        panel._widgets[i] = widget
      end
      
      -- Get widget height
      if item.type == "section" or item.type == "description" then
        if widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
        if item.type == "description" then
          local descriptionWidth = (scrollChild:GetWidth() or 0) - xOffset - DBB2:ScaleSize(SPACING.padding)
          if descriptionWidth < 1 then descriptionWidth = 1 end
          if widget.SetWidth then
            widget:SetWidth(descriptionWidth)
          end
          widgetHeight = math.max(DBB2:ScaleSize(12), math.ceil(widget:GetHeight() or 0))
        else
          widgetHeight = DBB2:ScaleSize(12)
        end
      elseif item.type == "slider" or item.type == "toggle" then
        widgetHeight = DBB2:ScaleSize(30)
        if widget and widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
      elseif item.type == "colorpicker" then
        widgetHeight = DBB2:ScaleSize(20)
        if widget and widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
      elseif item.type == "checkbox" then
        widgetHeight = DBB2:ScaleSize(16)
        if widget and widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
      elseif item.type == "channelList" or item.type == "categoryList" or item.type == "keywordList" or item.type == "keywordImportExport" then
        -- Dynamic widgets - rebuild and get height
        if widget and widget.rebuild then
          widget.rebuild()
        end
        if widget and widget.getHeight then
          widgetHeight = widget.getHeight()
        end
        -- Reposition container
        if widget and widget.container then
          widget.container:ClearAllPoints()
          widget.container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
          widget.container:SetPoint("RIGHT", scrollChild, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
        end
      elseif item.type == "editbox" then
        widgetHeight = DBB2:ScaleSize(20)
        if widget and widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
      end
      
      yOffset = yOffset - widgetHeight
      lastType = item.type
    end
    
    -- Set content height (includes bottom padding for extra scroll space)
    local contentHeight = -yOffset + DBB2:ScaleSize(SPACING.padding) + DBB2:ScaleSize(SPACING.bottomPadding)
    scrollChild:SetHeight(contentHeight)
    
    -- Update scroll state
    if scrollFrame.UpdateScrollState then
      scrollFrame.UpdateScrollState()
    end
  end
  
  -- Track scroll width for responsive updates
  local lastScrollWidth = 0
  local function UpdateScrollWidth()
    local scrollLeft = scrollFrame:GetLeft()
    local scrollRight = scrollFrame:GetRight()
    if not scrollLeft or not scrollRight then return false end
    
    local scrollWidth = scrollRight - scrollLeft
    if scrollWidth > 0 and scrollWidth ~= lastScrollWidth then
      lastScrollWidth = scrollWidth
      scrollChild:SetWidth(scrollWidth)
      return true
    end
    return false
  end
  
  scrollFrame:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    if UpdateScrollWidth() then
      RenderAllWidgets()
      this.UpdateScrollState()
    end
  end)
  
  -- Store rebuild function on panel
  panel.RebuildDynamicContent = RenderAllWidgets
  
  -- Initial render (widgets will be created but may need repositioning on show)
  RenderAllWidgets()
  
  -- Rebuild on show - this ensures proper dimensions after panel is visible
  local origOnShow = panel:GetScript("OnShow")
  panel:SetScript("OnShow", function()
    -- Ensure width is set
    local left = scrollFrame:GetLeft()
    local right = scrollFrame:GetRight()
    if left and right then
      scrollChild:SetWidth(right - left)
    end
    RenderAllWidgets()
    if scrollFrame.UpdateScrollState then
      scrollFrame.UpdateScrollState()
    end
    if origOnShow then origOnShow() end
  end)
  
  return { scrollFrame = scrollFrame, scrollChild = scrollChild, widgets = panel._widgets, panel = panel }
end


-- =====================
-- BASIC WIDGET RENDERERS
-- =====================
-- These functions render individual widget types for the config schema system.
-- They are called internally by RenderConfigSchema based on the widget type.

-- ============================================================================
-- [ RenderSlider ]
-- ============================================================================
-- Renders a slider widget for numeric configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the slider to.
--   item (table)   - Schema item with: key, label, min, max, step, default,
--                    width, tooltip, valueLabels, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The slider widget frame with OnValueChanged callback.
-- ============================================================================
function RenderSlider(parent, item, x, y)
  local currentValue = DBB2_Config[item.key]
  if currentValue == nil then currentValue = item.default or item.min or 0 end
  if currentValue == true then currentValue = 1 end
  if currentValue == false then currentValue = 0 end
  
  local labelText = item.label
  if item.valueLabels and item.valueLabels[currentValue] then
    labelText = item.label .. ": " .. item.valueLabels[currentValue]
  end
  
  local slider = DBB2.schema.CreateSlider(nil, parent, labelText, item.min, item.max, item.step or 1, FONT_SIZE)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  slider:SetValue(currentValue)
  
  if item.tooltip then
    slider.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    slider.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  slider.OnValueChanged = function(val)
    DBB2_Config[item.key] = val
    if item.valueLabels and item.valueLabels[val] then
      slider.label:SetText(item.label .. ": " .. item.valueLabels[val])
    end
    if item.onChange then item.onChange(val) end
  end
  
  return slider
end

-- ============================================================================
-- [ RenderToggle ]
-- ============================================================================
-- Renders a toggle widget (On/Off slider) for boolean configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the toggle to.
--   item (table)   - Schema item with: key, label, default, width, tooltip,
--                    onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The toggle widget frame with OnValueChanged callback.
-- ============================================================================
function RenderToggle(parent, item, x, y)
  local currentValue = DBB2_Config[item.key]
  if currentValue == nil then currentValue = item.default end
  local numValue = currentValue and 1 or 0
  
  local toggleNames = { [0] = "Off", [1] = "On" }
  local slider = DBB2.schema.CreateSlider(nil, parent, item.label .. ": " .. toggleNames[numValue], 0, 1, 1, FONT_SIZE)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  slider:SetValue(numValue)
  
  if item.tooltip then
    slider.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    slider.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  slider.OnValueChanged = function(val)
    DBB2_Config[item.key] = (val == 1)
    slider.label:SetText(item.label .. ": " .. toggleNames[val])
    if item.onChange then item.onChange(val == 1) end
  end
  
  return slider
end

-- ============================================================================
-- [ RenderColorPicker ]
-- ============================================================================
-- Renders a color picker widget for RGBA color configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the picker to.
--   item (table)   - Schema item with: key, label, default (table with r,g,b,a),
--                    width, tooltip, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The color picker widget frame with OnColorChanged callback.
-- ============================================================================
function RenderColorPicker(parent, item, x, y)
  local colorPicker = DBB2.schema.CreateColorPicker(nil, parent, item.label, FONT_SIZE)
  colorPicker:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  colorPicker:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  
  local color = DBB2_Config[item.key] or item.default or {r = 1, g = 1, b = 1, a = 1}
  colorPicker:SetColor(color.r, color.g, color.b, color.a)
  
  if item.tooltip then
    colorPicker.button:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    colorPicker.button:SetScript("OnLeave", function()
      this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  colorPicker.OnColorChanged = function(r, g, b, a)
    DBB2_Config[item.key] = {r = r, g = g, b = b, a = a}
    if item.onChange then item.onChange(r, g, b, a) end
  end
  
  return colorPicker
end

-- ============================================================================
-- [ RenderCheckbox ]
-- ============================================================================
-- Renders a checkbox widget for boolean configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the checkbox to.
--   item (table)   - Schema item with: key, label, default, tooltip, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The checkbox widget frame with OnChecked callback.
-- ============================================================================
function RenderCheckbox(parent, item, x, y)
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local checkbox = DBB2.schema.CreateCheckBox(nil, parent, item.label, FONT_SIZE)
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  checkbox:SetWidth(checkSize)
  checkbox:SetHeight(checkSize)
  
  local checked = DBB2_Config[item.key]
  if checked == nil then checked = item.default end
  checkbox:SetChecked(checked)
  
  if item.tooltip then
    checkbox:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    checkbox:SetScript("OnLeave", function()
      this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  checkbox.OnChecked = function(checked)
    DBB2_Config[item.key] = checked
    if item.onChange then item.onChange(checked) end
  end
  
  return checkbox
end

-- ============================================================================
-- [ RenderEditBox ]
-- ============================================================================
-- Renders an edit box widget for text input.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the editbox to.
--   item (table)   - Schema item with: placeholder, onEnter callback.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   EditBox - The edit box widget frame.
-- ============================================================================
function RenderEditBox(parent, item, x, y)
  local editbox = CreateConfigInput(nil, parent)
  editbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  editbox:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding + 20), 0)
  editbox:SetHeight(DBB2:ScaleSize(SPACING.inputHeight))
  
  if item.placeholder then
    editbox.placeholder = editbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editbox.placeholder:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE_INPUT))
    editbox.placeholder:SetPoint("LEFT", DBB2:ScaleSize(6), 0)
    editbox.placeholder:SetText(item.placeholder)
    editbox.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
    
    editbox:SetScript("OnEditFocusGained", function()
      if this.placeholder then this.placeholder:Hide() end
    end)
    editbox:SetScript("OnEditFocusLost", function()
      if this.placeholder and this:GetText() == "" then this.placeholder:Show() end
    end)
  end
  
  if item.onEnter then
    editbox:SetScript("OnEnterPressed", function()
      item.onEnter(this:GetText())
      this:ClearFocus()
    end)
  end
  
  return editbox
end
```

## api/config_widgets.lua
```lua
-- DBB2 Config Widgets
-- Complex list widgets for config panels
-- Depends on: env/constants.lua, env/tables.lua, api/config_schema.lua

-- Localize frequently used globals for performance
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

-- Local references to env constants (for performance)
local SPACING = DBB2.env.SPACING
local FONT_SIZE = DBB2.env.FONT_SIZE
local FONT_SIZE_INPUT = DBB2.env.FONT_SIZE_INPUT
local FONT_SIZE_SMALL = DBB2.env.FONT_SIZE_SMALL
local FONT_SIZE_LARGE = DBB2.env.FONT_SIZE_LARGE
local SECTION_FONT_SIZE = DBB2.env.SECTION_FONT_SIZE


-- ============================================================================
-- [ RenderChannelList ]
-- ============================================================================
-- Renders a dynamic list of channel checkboxes for monitoring configuration.
-- Displays all available channels with checkboxes to enable/disable monitoring.
-- Automatically detects hardcore characters and disables Hardcore channel
-- for non-hardcore characters.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores channelCheckboxes reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding all checkboxes
--     - rebuild (function): Function to rebuild the checkbox list
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderChannelList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local rowSpacing = DBB2:ScaleSize(5)
  local sectionGap = DBB2:ScaleSize(8)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)  -- Will be set by rebuild
  
  panel.channelCheckboxes = {}
  
  -- Use channel descriptions from env/tables.lua
  local channelDescriptions = DBB2.env.channelDescriptions
  
  local totalHeight = checkSize  -- Minimum height
  
  local function Rebuild()
    -- Hide existing checkboxes
    for _, check in ipairs(panel.channelCheckboxes) do
      check:Hide()
    end
    panel.channelCheckboxes = {}
    
    local isHardcoreChar = DBB2.api.DetectHardcoreCharacter()
    local channelList = DBB2.api.RefreshJoinedChannels()
    
    -- Ensure we have channels
    if not channelList then
      totalHeight = checkSize
      container:SetHeight(totalHeight)
      return
    end
    
    -- Count channels (Lua 5.0 compatible)
    local channelCount = 0
    for _ in ipairs(channelList) do
      channelCount = channelCount + 1
    end
    
    if channelCount == 0 then
      totalHeight = checkSize
      container:SetHeight(totalHeight)
      return
    end
    
    local currentY = 0
    totalHeight = 0
    
    for i, channelName in ipairs(channelList) do
      if channelName == "-" then
        -- Section separator
        currentY = currentY - sectionGap
        totalHeight = totalHeight + sectionGap
      else
        local check = DBB2.schema.CreateCheckBox(nil, container, channelName, FONT_SIZE)
        check:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
        check:SetWidth(checkSize)
        check:SetHeight(checkSize)
        check._channelName = channelName
        
        if channelName == "Hardcore" and not isHardcoreChar then
          check:SetChecked(false)
          check:Disable()
        else
          check:SetChecked(DBB2.api.IsChannelMonitored(channelName))
          check.OnChecked = function(checked)
            DBB2.api.SetChannelMonitored(check._channelName, checked)
          end
        end
        
        check:SetScript("OnEnter", function()
          local r, g, b = DBB2:GetHighlightColor()
          this.backdrop:SetBackdropBorderColor(r, g, b, 1)
          local desc = channelDescriptions[this._channelName] or "Monitor this channel."
          DBB2.api.ShowTooltip(this, "RIGHT", {{this._channelName, "highlight"}, desc})
        end)
        check:SetScript("OnLeave", function()
          this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
          DBB2.api.HideTooltip()
        end)
        
        table_insert(panel.channelCheckboxes, check)
        currentY = currentY - checkSize - rowSpacing
        totalHeight = totalHeight + checkSize + rowSpacing
      end
    end
    
    -- Ensure minimum height
    if totalHeight < checkSize then
      totalHeight = checkSize
    end
    
    container:SetHeight(totalHeight)
  end
  
  -- Initial build
  Rebuild()
  panel.RebuildChannelCheckboxes = Rebuild
  
  return {
    container = container,
    rebuild = Rebuild,
    getHeight = function() return totalHeight end
  }
end


-- ============================================================================
-- [ RenderCategoryList ]
-- ============================================================================
-- Renders a dynamic list of category rows with checkboxes and tag inputs.
-- Each row shows a category name, enabled checkbox, and editable tags field.
-- Optionally includes a filter tags row at the top for additional filtering.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores categoryRows, filterTagsInput).
--   item (table)   - Schema item with:
--                    - categoryType (string): "groups", "professions", etc.
--                    - showFilterTags (boolean): Whether to show filter row.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding all rows
--     - rebuild (function): Function to rebuild the category rows
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderCategoryList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local categoryType = item.categoryType
  local rowHeight = DBB2:ScaleSize(SPACING.rowHeight)
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local nameWidth = DBB2:ScaleSize(150)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)
  
  panel.categoryRows = {}
  local totalHeight = rowHeight  -- Minimum
  
  -- Filter tags row (for groups/professions)
  local filterRowHeight = 0
  local filterRow = nil
  local filterSectionHeight = 0
  local filterHeader = nil
  local filterSectionHelp = nil

  local customCategoryName = nil
  local customSectionTitle = nil
  local customSectionHelpText = nil
  local customToggleLabel = nil
  local customToggleTooltipTitle = nil
  local customToggleTooltipText = nil
  local customSectionHeight = 0
  local customHeader = nil
  local customHelp = nil
  local customToggle = nil
  local customInput = nil
  local customToggleNames = { [0] = "Off", [1] = "On" }
  local customHeaderHeight = DBB2:ScaleSize(12)
  local customHeaderGap = DBB2:ScaleSize(2)
  local customDescGap = DBB2:ScaleSize(SPACING.description)
  local customSliderHeight = DBB2:ScaleSize(30)
  local customInputGap = DBB2:ScaleSize(SPACING.widget)
  local customBottomGap = DBB2:ScaleSize(SPACING.section)

  if categoryType == "groups" or categoryType == "professions" or categoryType == "hardcore" then
    customCategoryName = "Custom Category"
    customSectionTitle = "Custom Category"
    customSectionHelpText = "Enable a custom category and enter the tags used to match it."
    customToggleLabel = "Enable Custom Category"
    customToggleTooltipTitle = "Custom Category"
    customToggleTooltipText = "Enable your own custom category."
  end

  if customCategoryName then
    customHeader = DBB2.schema.CreateLabel(container, customSectionTitle, SECTION_FONT_SIZE)
    customHeader:SetTextColor(hr, hg, hb, 1)

    customHelp = DBB2.schema.CreateLabel(container, customSectionHelpText, FONT_SIZE)
    customHelp:SetTextColor(0.5, 0.5, 0.5, 1)

    customToggle = DBB2.schema.CreateSlider(nil, container, customToggleLabel, 0, 1, 1, FONT_SIZE)
    customToggle:SetWidth(DBB2:ScaleSize(DBB2.env.DEFAULT_WIDTH))
    customToggle.value:SetText(customToggleNames[0])
    customToggle.label:SetText(customToggleLabel .. ": " .. customToggleNames[0])

    customToggle.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", {{customToggleTooltipTitle, "highlight"}, customToggleTooltipText, {"Tags entered below will be used to match it.", "gray"}})
    end)
    customToggle.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)

    customInput = CreateConfigInput(nil, container)
    customInput:SetHeight(inputHeight)
    customInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  end

  local categoryHeaderHeight = DBB2:ScaleSize(12)
  local categoryHeaderGap = DBB2:ScaleSize(2)
  local categorySectionGap = DBB2:ScaleSize(SPACING.description)

  local categoryHeader = DBB2.schema.CreateLabel(container, "Categories", SECTION_FONT_SIZE)
  categoryHeader:SetTextColor(hr, hg, hb, 1)
  categoryHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -filterRowHeight)

  local categoryHelp = DBB2.schema.CreateLabel(container, "Enable categories and edit the tags used to match messages.", FONT_SIZE)
  categoryHelp:SetTextColor(0.5, 0.5, 0.5, 1)
  categoryHelp:SetPoint("TOPLEFT", categoryHeader, "BOTTOMLEFT", 0, -categoryHeaderGap)
  categoryHelp:SetPoint("TOPRIGHT", container, "TOPRIGHT", -DBB2:ScaleSize(5), -filterRowHeight - categoryHeaderHeight - categoryHeaderGap)
  
  if item.showFilterTags then
    local filterHeaderHeight = DBB2:ScaleSize(12)
    local filterHeaderGap = DBB2:ScaleSize(2)
    local filterSectionHelpGap = DBB2:ScaleSize(SPACING.description)
    local toggleNames = { [0] = "Off", [1] = "On" }
    local filterSliderHeight = DBB2:ScaleSize(30)
    local helperHeight = DBB2:ScaleSize(12)
    local helperGap = DBB2:ScaleSize(2)
    local inputGap = DBB2:ScaleSize(SPACING.description)
    local rowBottomGap = DBB2:ScaleSize(SPACING.section)

    filterHeader = DBB2.schema.CreateLabel(container, "Filter Tags", SECTION_FONT_SIZE)
    filterHeader:SetTextColor(hr, hg, hb, 1)

    filterSectionHelp = DBB2.schema.CreateLabel(container, "Require messages to match one of these tags before categories are checked.", FONT_SIZE)
    filterSectionHelp:SetTextColor(0.5, 0.5, 0.5, 1)

    filterRow = CreateFrame("Frame", nil, container)
    filterRow:SetHeight(filterSliderHeight + helperGap + helperHeight + inputGap + inputHeight + rowBottomGap)
    filterRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -filterSectionHeight)
    filterRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    
    local filterEnabled = DBB2.api.IsFilterTagsEnabled(categoryType) and 1 or 0
    local filterToggle = DBB2.schema.CreateSlider(nil, filterRow, "Filter Tags", 0, 1, 1, FONT_SIZE)
    filterToggle:ClearAllPoints()
    filterToggle:SetPoint("TOPLEFT", filterRow, "TOPLEFT", 0, 0)
    filterToggle:SetWidth(DBB2:ScaleSize(DBB2.env.DEFAULT_WIDTH))
    filterToggle:SetValue(filterEnabled)
    filterToggle.value:SetText(toggleNames[filterEnabled])
    filterToggle.label:SetText("Filter Tags: " .. toggleNames[filterEnabled])
    filterToggle.OnValueChanged = function(val)
      DBB2.api.SetFilterTagsEnabled(categoryType, val == 1)
      filterToggle.value:SetText(toggleNames[val])
      filterToggle.label:SetText("Filter Tags: " .. toggleNames[val])
    end

    filterToggle.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", {{"Filter Tags", "highlight"}, "When enabled, messages must also match one of these tags.", {"Turn this off to match all tags.", "gray"}})
    end)
    filterToggle.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)

    local filterHelp = DBB2.schema.CreateLabel(filterRow, "When enabled, messages must also match one of these tags.", FONT_SIZE_SMALL)
    filterHelp:SetPoint("TOPLEFT", filterToggle, "BOTTOMLEFT", 0, -helperGap)
    filterHelp:SetPoint("TOPRIGHT", filterRow, "TOPRIGHT", -DBB2:ScaleSize(5), -filterSliderHeight - helperGap)
    filterHelp:SetTextColor(0.5, 0.5, 0.5, 1)
    filterRow.filterHelp = filterHelp
    
    local filterInput = CreateConfigInput(nil, filterRow)
    filterInput:SetPoint("TOPLEFT", filterHelp, "BOTTOMLEFT", 0, -inputGap)
    filterInput:SetPoint("RIGHT", filterRow, "RIGHT", -DBB2:ScaleSize(5), 0)
    filterInput:SetHeight(inputHeight)
    
    local filterConfig = DBB2.api.GetFilterTags(categoryType)
    if filterConfig and filterConfig.tags then
      filterInput:SetText(DBB2.api.TagsToString(filterConfig.tags))
    end
    
    filterInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    filterInput:SetScript("OnEnterPressed", function()
      DBB2.api.UpdateFilterTags(categoryType, DBB2.api.ParseTagsString(this:GetText()))
      this:ClearFocus()
    end)
    filterInput:SetScript("OnEditFocusLost", function()
      DBB2.api.UpdateFilterTags(categoryType, DBB2.api.ParseTagsString(this:GetText()))
    end)
    
    panel.filterTagsInput = filterInput
    panel.filterCategoryType = categoryType
    filterRowHeight = filterSectionHeight + filterSliderHeight + helperGap + helperHeight + inputGap + inputHeight + rowBottomGap
  end

  local function GetWrappedLabelHeight(label, width)
    local minHeight = DBB2:ScaleSize(12)
    if not label or not label.SetWidth then
      return minHeight
    end
    label:SetWidth(width)
    return math.max(minHeight, math.ceil(label:GetHeight() or 0))
  end

  local function CreateCategoryRow()
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(rowHeight)
    row.check = DBB2.schema.CreateCheckBox(nil, row)
    row.check:SetPoint("LEFT", 0, 0)
    row.check:SetWidth(checkSize)
    row.check:SetHeight(checkSize)
    row.nameLabel = DBB2.schema.CreateLabel(row, "", FONT_SIZE)
    row.nameLabel:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
    row.nameLabel:SetWidth(nameWidth)
    row.tagsInput = CreateConfigInput(nil, row)
    row.tagsInput:SetPoint("LEFT", row.nameLabel, "RIGHT", 5, 0)
    row.tagsInput:SetPoint("RIGHT", row, "RIGHT", -DBB2:ScaleSize(5), 0)
    row.tagsInput:SetHeight(inputHeight)
    row.tagsInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    return row
  end

  local function UpdateFilterLayout(contentWidth, helpWidth)
    local filterSectionHelpHeight
    local filterHelpHeight
    local filterHelpWidth
    local filterRowWidth
    local topSectionGap

    if not filterHeader or not filterSectionHelp then
      filterSectionHeight = 0
      filterRowHeight = 0
      return 0
    end

    topSectionGap = DBB2:ScaleSize(SPACING.section)
    filterSectionHelpHeight = GetWrappedLabelHeight(filterSectionHelp, helpWidth)
    filterSectionHeight = DBB2:ScaleSize(12) + DBB2:ScaleSize(2) + filterSectionHelpHeight + DBB2:ScaleSize(SPACING.description)

    filterHelpHeight = DBB2:ScaleSize(12)
    if filterRow then
      filterRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(topSectionGap + filterSectionHeight))
      filterRowWidth = filterRow:GetWidth() or contentWidth
      filterHelpWidth = filterRowWidth - DBB2:ScaleSize(5)
      if filterHelpWidth < 1 then filterHelpWidth = 1 end
      if filterRow.filterHelp and filterRow.filterHelp.SetWidth then
        filterRow.filterHelp:SetWidth(filterHelpWidth)
        filterHelpHeight = math.max(DBB2:ScaleSize(12), math.ceil(filterRow.filterHelp:GetHeight() or 0))
      end
      filterRow:SetHeight(DBB2:ScaleSize(30) + DBB2:ScaleSize(2) + filterHelpHeight + DBB2:ScaleSize(SPACING.description) + inputHeight + DBB2:ScaleSize(SPACING.section))
    end

    filterRowHeight = topSectionGap + filterSectionHeight + DBB2:ScaleSize(30) + DBB2:ScaleSize(2) + filterHelpHeight + DBB2:ScaleSize(SPACING.description) + inputHeight + DBB2:ScaleSize(SPACING.section)
    return filterRowHeight
  end

  local function UpdateCustomSection(customCategory, activeFilterRowHeight, helpWidth)
    local customHelpHeight
    local customValue

    customSectionHeight = 0
    if customHelp then
      customHelpHeight = GetWrappedLabelHeight(customHelp, helpWidth)
      customSectionHeight = customHeaderHeight + customHeaderGap + customHelpHeight + customDescGap + customSliderHeight + customInputGap + inputHeight + customBottomGap
    end

    if not (customHeader and customHelp and customToggle and customInput and customCategory) then
      if customHeader and customHelp and customToggle and customInput then
        customHeader:Hide()
        customHelp:Hide()
        customToggle:Hide()
        customInput:Hide()
      end
      return 0
    end

    customHeader:Show()
    customHelp:Show()
    customToggle:Show()
    customInput:Show()
    customHeader:ClearAllPoints()
    customHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -activeFilterRowHeight)
    customHelp:ClearAllPoints()
    customHelp:SetPoint("TOPLEFT", customHeader, "BOTTOMLEFT", 0, -customHeaderGap)
    customHelp:SetPoint("TOPRIGHT", container, "TOPRIGHT", -DBB2:ScaleSize(5), -activeFilterRowHeight - customHeaderHeight - customHeaderGap)
    customToggle:ClearAllPoints()
    customToggle:SetPoint("TOPLEFT", customHelp, "BOTTOMLEFT", 0, -customDescGap)
    customValue = customCategory.selected and 1 or 0
    customToggle:SetValue(customValue)
    customToggle.value:SetText(customToggleNames[customValue])
    customToggle.label:SetText(customToggleLabel .. ": " .. customToggleNames[customValue])
    customToggle.OnValueChanged = function(val)
      DBB2.api.SetCategorySelected(categoryType, customCategory.name, val == 1)
      customToggle.value:SetText(customToggleNames[val])
      customToggle.label:SetText(customToggleLabel .. ": " .. customToggleNames[val])
    end
    customInput:ClearAllPoints()
    customInput:SetPoint("TOPLEFT", customToggle, "BOTTOMLEFT", 0, -customInputGap)
    customInput:SetPoint("RIGHT", container, "RIGHT", -DBB2:ScaleSize(5), 0)
    customInput:SetText(DBB2.api.TagsToString(customCategory.tags))
    customInput:SetScript("OnEnterPressed", function()
      DBB2.api.UpdateCategoryTags(categoryType, customCategory.name, DBB2.api.ParseTagsString(this:GetText()))
      this:ClearFocus()
    end)
    customInput:SetScript("OnEditFocusLost", function()
      DBB2.api.UpdateCategoryTags(categoryType, customCategory.name, DBB2.api.ParseTagsString(this:GetText()))
    end)
    return customSectionHeight
  end

  local function UpdateCategoryHeader(activeFilterRowHeight, effectiveCustomHeight)
    categoryHeader:ClearAllPoints()
    categoryHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(activeFilterRowHeight + effectiveCustomHeight))
    categoryHelp:ClearAllPoints()
    categoryHelp:SetPoint("TOPLEFT", categoryHeader, "BOTTOMLEFT", 0, -categoryHeaderGap)
    categoryHelp:SetPoint("TOPRIGHT", container, "TOPRIGHT", -DBB2:ScaleSize(5), -(activeFilterRowHeight + effectiveCustomHeight + categoryHeaderHeight + categoryHeaderGap))
  end

  local function BuildRows()
    local contentWidth = container:GetWidth() or 0
    local helpWidth = contentWidth - DBB2:ScaleSize(5)
    if helpWidth < 1 then helpWidth = 1 end

    local categoryHelpHeight = GetWrappedLabelHeight(categoryHelp, helpWidth)
    local categorySectionHeight = categoryHeaderHeight + categoryHeaderGap + categoryHelpHeight + categorySectionGap
    local activeFilterRowHeight = UpdateFilterLayout(contentWidth, helpWidth)

    local categories = DBB2.api.GetCategories(categoryType)
    if not categories then
      totalHeight = activeFilterRowHeight + customSectionHeight + categorySectionHeight + rowHeight
      container:SetHeight(totalHeight)
      return
    end

    local visibleCategories = {}
    local customCategory = nil
    for _, cat in ipairs(categories) do
      if customCategoryName and cat.name == customCategoryName then
        customCategory = cat
      else
        table_insert(visibleCategories, cat)
      end
    end

    local effectiveCustomHeight = UpdateCustomSection(customCategory, activeFilterRowHeight, helpWidth)

    if filterHeader and filterSectionHelp then
      filterHeader:Show()
      filterSectionHelp:Show()
      filterHeader:ClearAllPoints()
      filterHeader:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -DBB2:ScaleSize(SPACING.section))
      filterSectionHelp:ClearAllPoints()
      filterSectionHelp:SetPoint("TOPLEFT", filterHeader, "BOTTOMLEFT", 0, -2)
      filterSectionHelp:SetPoint("TOPRIGHT", container, "TOPRIGHT", -DBB2:ScaleSize(5), -(DBB2:ScaleSize(SPACING.section) + DBB2:ScaleSize(12) + 2))
    end

    UpdateCategoryHeader(activeFilterRowHeight, effectiveCustomHeight)

    local currentY = -(activeFilterRowHeight + effectiveCustomHeight + categorySectionHeight)

    for i, cat in ipairs(visibleCategories) do
      local row = panel.categoryRows[i]
      if not row then
        row = CreateCategoryRow()
        panel.categoryRows[i] = row
      end
      
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
      row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      row:Show()
      
      row.categoryName = cat.name
      row.categoryType = categoryType
      row.nameLabel:SetText(cat.name)
      row.nameLabel:SetTextColor(1, 1, 1, 1)
      row.check:SetChecked(cat.selected)
      row.tagsInput:SetText(DBB2.api.TagsToString(cat.tags))
      
      row.check.OnChecked = function(checked)
        DBB2.api.SetCategorySelected(row.categoryType, row.categoryName, checked)
      end
      row.tagsInput:SetScript("OnEnterPressed", function()
        DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(this:GetText()))
        this:ClearFocus()
      end)
      row.tagsInput:SetScript("OnEditFocusLost", function()
        DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(this:GetText()))
      end)
      
      currentY = currentY - rowHeight
    end
    
    -- Hide extra rows
    local catCount = 0
    for _ in ipairs(visibleCategories) do catCount = catCount + 1 end
    local rowCount = 0
    for _ in ipairs(panel.categoryRows) do rowCount = rowCount + 1 end
    
    for i = catCount + 1, rowCount do
      if panel.categoryRows[i] then panel.categoryRows[i]:Hide() end
    end
    
    totalHeight = activeFilterRowHeight + effectiveCustomHeight + categorySectionHeight + (catCount * rowHeight)
    if totalHeight < rowHeight then totalHeight = rowHeight end
    container:SetHeight(totalHeight)
  end
  
  BuildRows()
  
  return {
    container = container,
    rebuild = BuildRows,
    getHeight = function() return totalHeight end
  }
end


-- ============================================================================
-- [ RenderKeywordImportExport ]
-- ============================================================================
-- Renders an input box for bulk import/export of blacklist keywords.
-- Keywords are displayed as a comma-separated string that can be edited.
-- On Enter press, the entire keyword list is replaced with the parsed input.
-- On focus lost, the input reverts to the current keyword list.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the widget to.
--   panel (Frame)  - The config panel (stores importExportBox reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding the input box
--     - rebuild (function): Function to update the input with current keywords
--     - getHeight (function): Returns the widget height
-- ============================================================================
function RenderKeywordImportExport(parent, panel, item, x, y)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(inputHeight)
  
  -- Helper function to convert keywords array to comma-separated string
  local function KeywordsToString()
    local keywords = DBB2.api.GetBlacklistedKeywords()
    if not keywords then return "" end
    return table.concat(keywords, ", ")
  end
  
  -- Helper function to parse comma-separated string to keywords
  local function StringToKeywords(str)
    local keywords = {}
    for kw in string_gfind(str, "([^,]+)") do
      kw = string_gsub(kw, "^%s*(.-)%s*$", "%1")
      if kw ~= "" then
        table_insert(keywords, kw)
      end
    end
    return keywords
  end
  
  -- Create the import/export input box
  local importExportBox = CreateConfigInput(nil, container)
  importExportBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  importExportBox:SetPoint("RIGHT", container, "RIGHT", -DBB2:ScaleSize(5), 0)  -- Match category tags spacing
  importExportBox:SetHeight(inputHeight)
  
  -- Store reference on panel for rebuilding
  panel.importExportBox = importExportBox
  
  -- Update box with current keywords
  local function UpdateImportExportBox()
    importExportBox:SetText(KeywordsToString())
  end
  
  -- Import on Enter press
  importExportBox:SetScript("OnEnterPressed", function()
    local str = this:GetText()
    local newKeywords = StringToKeywords(str)
    
    -- Clear existing keywords
    DBB2_Config.blacklist.keywords = {}
    
    -- Add new keywords in order
    for _, kw in ipairs(newKeywords) do
      DBB2.api.AddKeywordToBlacklist(kw)
    end
    
    this:ClearFocus()
    
    -- Rebuild keyword list if it exists
    if panel.RebuildDynamicContent then
      panel.RebuildDynamicContent()
    end
  end)
  
  -- Restore current keywords on focus lost (cancel edit)
  importExportBox:SetScript("OnEditFocusLost", function()
    UpdateImportExportBox()
  end)
  
  importExportBox:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  -- Initial population
  UpdateImportExportBox()
  
  return {
    container = container,
    rebuild = UpdateImportExportBox,
    getHeight = function() return inputHeight end
  }
end


-- ============================================================================
-- [ RenderKeywordList ]
-- ============================================================================
-- Renders a dynamic list of blacklist keywords with an input field for adding
-- new keywords and remove buttons for each existing keyword.
-- Each keyword row shows the keyword text, optional pattern description,
-- and a remove button.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores keywordRows reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding input and keyword rows
--     - rebuild (function): Function to rebuild the keyword list
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderKeywordList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local rowHeight = DBB2:ScaleSize(22)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  local spacing = DBB2:ScaleSize(5)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)
  
  panel.keywordRows = {}
  local totalHeight = inputHeight + spacing  -- Minimum (input row)
  
  -- Input row
  local inputRow = CreateFrame("Frame", nil, container)
  inputRow:SetHeight(inputHeight)
  inputRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  inputRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  
  local keywordInput = CreateConfigInput(nil, inputRow)
  keywordInput:SetPoint("TOPLEFT", inputRow, "TOPLEFT", 0, 0)
  keywordInput:SetPoint("RIGHT", inputRow, "RIGHT", -DBB2:ScaleSize(5), 0)  -- Match category tags spacing
  keywordInput:SetHeight(inputHeight)
  
  keywordInput.placeholder = keywordInput:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  keywordInput.placeholder:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE_INPUT))
  keywordInput.placeholder:SetPoint("LEFT", DBB2:ScaleSize(6), 0)
  keywordInput.placeholder:SetText("Enter keyword and press Enter...")
  keywordInput.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
  
  keywordInput:SetScript("OnEditFocusGained", function() this.placeholder:Hide() end)
  keywordInput:SetScript("OnEditFocusLost", function()
    if this:GetText() == "" then this.placeholder:Show() end
  end)
  
  -- Use pattern descriptions from env/tables.lua
  local patternDescriptions = DBB2.env.patternDescriptions
  
  local function CreateKeywordRow(index)
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(rowHeight)
    
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE))
    row.name:SetPoint("LEFT", DBB2:ScaleSize(5), 0)
    row.name:SetWidth(DBB2:ScaleSize(180))
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(1, 1, 1, 1)
    
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.desc:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE_SMALL))
    row.desc:SetJustifyH("RIGHT")
    row.desc:SetTextColor(0.5, 0.5, 0.5, 1)
    
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetWidth(DBB2:ScaleSize(16))
    row.removeBtn:SetHeight(DBB2:ScaleSize(16))
    row.removeBtn:SetPoint("RIGHT", -DBB2:ScaleSize(5), 0)
    
    row.desc:SetPoint("RIGHT", row.removeBtn, "LEFT", -DBB2:ScaleSize(8), 0)
    
    row.removeBtn.text = row.removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.removeBtn.text:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(FONT_SIZE_LARGE))
    row.removeBtn.text:SetPoint("CENTER", 0, 0)
    row.removeBtn.text:SetText("x")
    row.removeBtn.text:SetTextColor(1, 0.3, 0.3, 1)
    
    row.removeBtn:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.5, 0.5, 1) end)
    row.removeBtn:SetScript("OnLeave", function() this.text:SetTextColor(1, 0.3, 0.3, 1) end)
    
    return row
  end
  
  local function RebuildKeywords()
    -- Hide existing rows
    for _, row in ipairs(panel.keywordRows) do
      row:Hide()
    end
    
    local keywords = DBB2.api.GetBlacklistedKeywords()
    if not keywords then
      totalHeight = inputHeight + spacing
      container:SetHeight(totalHeight)
      return
    end
    
    local currentY = -(inputHeight + spacing)
    
    for i, keyword in ipairs(keywords) do
      local row = panel.keywordRows[i]
      if not row then
        row = CreateKeywordRow(i)
        panel.keywordRows[i] = row
      end
      
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
      row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      row:Show()
      
      row.value = keyword
      row.name:SetText(keyword)
      row.desc:SetText(patternDescriptions[keyword] or "")
      
      local keywordToRemove = keyword
      row.removeBtn:SetScript("OnClick", function()
        DBB2.api.RemoveKeywordFromBlacklist(keywordToRemove)
        RebuildKeywords()
        if panel.RebuildDynamicContent then panel.RebuildDynamicContent() end
      end)
      
      currentY = currentY - rowHeight
    end
    
    local kwCount = 0
    for _ in ipairs(keywords) do kwCount = kwCount + 1 end
    
    totalHeight = inputHeight + spacing + (kwCount * rowHeight)
    if totalHeight < inputHeight + spacing then
      totalHeight = inputHeight + spacing
    end
    container:SetHeight(totalHeight)
  end
  
  local function AddKeyword()
    local kw = keywordInput:GetText()
    if kw and kw ~= "" then
      DBB2.api.AddKeywordToBlacklist(kw)
      keywordInput:SetText("")
      keywordInput.placeholder:Show()
      RebuildKeywords()
      if panel.RebuildDynamicContent then panel.RebuildDynamicContent() end
    end
  end
  
  keywordInput:SetScript("OnEnterPressed", function()
    AddKeyword()
    this:ClearFocus()
  end)
  
  RebuildKeywords()
  
  return {
    container = container,
    rebuild = RebuildKeywords,
    getHeight = function() return totalHeight end
  }
end
```

## api/dict_cn_misc.lua
```lua
-- dict_cn_misc.lua
-- Chinese (Simplified) → English word/term substitution table
-- Ported from TranslateCN by Gangasrotogati
-- Format: dict_cn_misc["<CN term>"] = "<EN translation>"

dict_cn_misc = dict_cn_misc or {}

-- ============================================================================
-- Classes & Roles
-- ============================================================================
dict_cn_misc["术士"] = "Warlock"
dict_cn_misc["战士"] = "Warrior"
dict_cn_misc["猎人"] = "Hunter"
dict_cn_misc["法师"] = "Mage"
dict_cn_misc["牧师"] = "Priest"
dict_cn_misc["德鲁伊"] = "Druid"
dict_cn_misc["圣骑士"] = "Paladin"
dict_cn_misc["萨满祭司"] = "Shaman"
dict_cn_misc["盗贼"] = "Rogue"
dict_cn_misc["骑士"] = "Paladin"
dict_cn_misc["德"] = "Druid"
dict_cn_misc["萨满"] = "Shaman"
dict_cn_misc["牧"] = "Priest"
dict_cn_misc["法"] = "Mage"
dict_cn_misc["猎"] = "Hunter"
dict_cn_misc["战"] = "Warrior"
dict_cn_misc["贼"] = "Rogue"
dict_cn_misc["术"] = "Warlock"
dict_cn_misc["QS"] = "Paladin"
dict_cn_misc["XD"] = "Druid"
dict_cn_misc["FS"] = "Mage"
dict_cn_misc["DZ"] = "Rogue"
dict_cn_misc["ZS"] = "Warrior"
dict_cn_misc["dz"] = "Rogue"
dict_cn_misc["fs"] = "Mage"
dict_cn_misc["lr"] = "Hunter"
dict_cn_misc["qs"] = "Paladin"
dict_cn_misc["xd"] = "Druid"
dict_cn_misc["zs"] = "Warrior"
dict_cn_misc["DLY"] = "Druid"
dict_cn_misc["法爷"] = "Mage"
dict_cn_misc["潜行者"] = "Rogue"
dict_cn_misc["卫士"] = "Felguard"
dict_cn_misc["蓝胖子"] = "Voidwalker"
dict_cn_misc["小鬼"] = "Imp"
dict_cn_misc["地狱犬"] = "Felhunter"
dict_cn_misc["魅魔"] = "Succubus"

-- ============================================================================
-- Specializations (Specs)
-- ============================================================================
dict_cn_misc["奶骑"] = "holy paladin"
dict_cn_misc["鸟德"] = "boomkin druid"
dict_cn_misc["奶德"] = "resto druid"
dict_cn_misc["熊德"] = "Feral Druid (Bear)"
dict_cn_misc["猫德"] = "Feral Druid (Cat)"
dict_cn_misc["小德"] = "Druid"
dict_cn_misc["平衡德"] = "Balance Druid"
dict_cn_misc["冰法"] = "Frost Mage"
dict_cn_misc["火法"] = "Fire Mage"
dict_cn_misc["奥法"] = "Arcane Mage"
dict_cn_misc["暗牧"] = "Shadow Priest"
dict_cn_misc["奶牧"] = "Holy Priest"
dict_cn_misc["戒律牧"] = "Disc Priest"
dict_cn_misc["神圣牧"] = "Holy Priest"
dict_cn_misc["神牧"] = "Holy Priest"
dict_cn_misc["戒律"] = "Discipline"
dict_cn_misc["元素萨"] = "Elemental Shaman"
dict_cn_misc["增强萨"] = "Enhancement Shaman"
dict_cn_misc["奶萨"] = "Resto Shaman"
dict_cn_misc["HSS"] = "Resto Shaman"
dict_cn_misc["狂暴战"] = "Fury Warrior"
dict_cn_misc["武器战"] = "Arms Warrior"
dict_cn_misc["防战"] = "Prot Warrior"
dict_cn_misc["双修战"] = "Dual-spec Warrior"
dict_cn_misc["MS战"] = "Mortal Strike Warrior"
dict_cn_misc["WQZ"] = "Arms Warrior"
dict_cn_misc["wqz"] = "Arms Warrior"
dict_cn_misc["KBZ"] = "Fury Warrior"
dict_cn_misc["kbz"] = "Fury Warrior"
dict_cn_misc["FZ"] = "Prot Warrior"
dict_cn_misc["fz"] = "Prot Warrior"
dict_cn_misc["惩戒骑"] = "Ret Paladin"
dict_cn_misc["防骑"] = "Prot Paladin"
dict_cn_misc["CJQ"] = "Retribution Paladin"
dict_cn_misc["FQ"] = "Prot Paladin"
dict_cn_misc["fq"] = "Prot Paladin"
dict_cn_misc["FJ"] = "Prot Paladin"
dict_cn_misc["NQ"] = "Holy Paladin"
dict_cn_misc["nq"] = "Holy Paladin"
dict_cn_misc["刺杀贼"] = "Assassination Rogue"
dict_cn_misc["战斗贼"] = "Combat Rogue"
dict_cn_misc["敏锐贼"] = "Subtlety Rogue"
dict_cn_misc["匕首贼"] = "Dagger Rogue"
dict_cn_misc["兽王猎"] = "BM Hunter"
dict_cn_misc["射击猎"] = "Marksman Hunter"
dict_cn_misc["生存猎"] = "Survival Hunter"
dict_cn_misc["陷阱猎"] = "Trap Hunter"
dict_cn_misc["痛苦术"] = "Affliction Lock"
dict_cn_misc["毁灭术"] = "Destro Lock"
dict_cn_misc["恶魔术"] = "Demo Lock"
dict_cn_misc["YSS"] = "Elemental Shaman"
dict_cn_misc["ZQS"] = "Enhancement Shaman"
dict_cn_misc["枭兽"] = "Moonkin form"
dict_cn_misc["咕咕"] = "Moonkin"
dict_cn_misc["奶爸"] = "Healer (male)"

-- ============================================================================
-- Group Roles & Composition
-- ============================================================================
dict_cn_misc["坦克"] = "tank"

dict_cn_misc["MT"] = "main tank"
dict_cn_misc["主坦"] = "main tank"
dict_cn_misc["主T"] = "Main Tank"
dict_cn_misc["主坦克"] = "Main Tank"
dict_cn_misc["副坦"] = "off-tank"
dict_cn_misc["副T"] = "Off-Tank"
dict_cn_misc["副坦克"] = "Off Tank"
dict_cn_misc["OT"] = "OT (Off-tank)"
dict_cn_misc["肉盾"] = "Tank"
dict_cn_misc["坦克战士"] = "Tank Warrior"
dict_cn_misc["保险丝"] = "backup tank (threat safety)"
dict_cn_misc["治疗"] = "healer"
dict_cn_misc["奶妈"] = "healer"
dict_cn_misc["奶"] = "healer"
dict_cn_misc["主奶"] = "Main Healer"
dict_cn_misc["大奶"] = "Main Healer"
dict_cn_misc["副奶"] = "Secondary Healer"
dict_cn_misc["MN"] = "Main Healer"
dict_cn_misc["mn"] = "Main Healer"
dict_cn_misc["FN"] = "Off Healer"
dict_cn_misc["fn"] = "Off Healer"
dict_cn_misc["输出"] = "DPS"
dict_cn_misc["DPS"] = "DPS"
dict_cn_misc["dps"] = "DPS"
dict_cn_misc["DD"] = "DPS"
dict_cn_misc["远程"] = "ranged"
dict_cn_misc["近战"] = "melee"
dict_cn_misc["摔绊"] = "melee"
dict_cn_misc["法系"] = "caster DPS"
dict_cn_misc["物理"] = "melee DPS"
dict_cn_misc["CDPS"] = "caster DPS"
dict_cn_misc["MDPS"] = "Melee DPS"
dict_cn_misc["RDPS"] = "Ranged DPS"
dict_cn_misc["法系输出"] = "caster DPS"
dict_cn_misc["近战输出"] = "melee DPS"
dict_cn_misc["远程输出"] = "ranged DPS"
dict_cn_misc["DPS位"] = "DPS spot"
dict_cn_misc["T或者N"] = "tank or healer"

-- ============================================================================
-- LFG & Group Forming Terms
-- ============================================================================
dict_cn_misc["招募"] = "recruiting"
dict_cn_misc["组队"] = "group up"
dict_cn_misc["开团"] = "raid forming"
dict_cn_misc["缺人"] = "need more"
dict_cn_misc["满了"] = "full"
dict_cn_misc["来"] = "need"
dict_cn_misc["打"] = "run"
dict_cn_misc["收"] = "taking"
dict_cn_misc["需要"] = "need"
dict_cn_misc["满5"] = "full 5/5"
dict_cn_misc["缺1"] = "need 1 more"
dict_cn_misc["缺2"] = "need 2 more"
dict_cn_misc["缺3"] = "need 3 more"
dict_cn_misc["缺4"] = "need 4 more"
dict_cn_misc["4=1D"] = "LF1M DPS"
dict_cn_misc["4=1H"] = "LF1M Healer"
dict_cn_misc["4=1T"] = "LF1M Tank"
dict_cn_misc["1=4"] = "LF4M"
dict_cn_misc["2=3"] = "LF3M"
dict_cn_misc["3=2"] = "LF2M"
dict_cn_misc["4=1"] = "LF1M"
dict_cn_misc["寻找组队"] = "LFG channel"
dict_cn_misc["寻求组队"] = "LFG channel"
dict_cn_misc["QZ"] = "LFG"
dict_cn_misc["qz"] = "LFG"
dict_cn_misc["来个"] = "need a"
dict_cn_misc["需来个"] = "need a"
dict_cn_misc["需来"] = "need"
dict_cn_misc["寻找"] = "seeking"
dict_cn_misc["寻求"] = "looking for"
dict_cn_misc["征召"] = "recruiting"
dict_cn_misc["找人"] = "looking for people"
dict_cn_misc["找队"] = "looking for group"
dict_cn_misc["求带"] = "LFB"
dict_cn_misc["开组"] = "forming group"
dict_cn_misc["来满级"] = "max level only"
dict_cn_misc["投天赋"] = "apply with talent"
dict_cn_misc["天赋"] = "talent"
dict_cn_misc["投简历"] = "apply"
dict_cn_misc["报名"] = "sign up"
dict_cn_misc["加我"] = "add me"
dict_cn_misc["任务队"] = "quest group"
dict_cn_misc["有没有T"] = "any tanks?"
dict_cn_misc["有没有N"] = "any healers?"
dict_cn_misc["来人"] = "Need"
dict_cn_misc["求组"] = "LFG"
dict_cn_misc["求邀请"] = "Inv me"
dict_cn_misc["收人"] = "LFM"
dict_cn_misc["组满"] = "Group full"
dict_cn_misc["缺DPS"] = "need DPS"
dict_cn_misc["缺T"] = "need tank"
dict_cn_misc["缺奶"] = "need healer"
dict_cn_misc["跑团"] = "join pug raid"
dict_cn_misc["招人"] = "recruiting"
dict_cn_misc["进组来"] = "Inv pls"

-- ============================================================================
-- Turtle WoW Specific - Custom Dungeons, Zones & Modes (ADDITIONS)
-- ============================================================================
dict_cn_misc["风暴废墟"] = "Stormwrought Ruins"
dict_cn_misc["风暴罗特城"] = "Stormwrought Ruins"
dict_cn_misc["风暴城堡"] = "Stormwrought Ruins"
dict_cn_misc["翡翠圣地"] = "Emerald Sanctum"
dict_cn_misc["仇恨熔炉"] = "Hateforge Quarry"
dict_cn_misc["新月林地"] = "Crescent Grove"
dict_cn_misc["暴风城地窖"] = "Stormwind Vault"
dict_cn_misc["一命"] = "Hardcore Mode"
dict_cn_misc["HC"] = "Hardcore"
dict_cn_misc["hc"] = "Hardcore"
dict_cn_misc["单机模式"] = "Ironman Mode"
dict_cn_misc["流浪汉"] = "Vagrant's Mode"
dict_cn_misc["孤狼"] = "Lone Wolf"
dict_cn_misc["乌龟服"] = "turtle server"
dict_cn_misc["乌龟魔兽"] = "Turtle WoW"
dict_cn_misc["大乌龟"] = "Turtle WoW (server)"
dict_cn_misc["乌龟模式"] = "Turtle Mode"
dict_cn_misc["龟速模式"] = "Turtle Mode"
dict_cn_misc["龟服"] = "turtle server"
dict_cn_misc["龟龟"] = "turtle server"
dict_cn_misc["乌龟亚服"] = "Turtle WoW Asia server"
dict_cn_misc["乌龟欧服"] = "Turtle WoW EU server"
dict_cn_misc["一命模式"] = "Hardcore Mode"
dict_cn_misc["硬核模式"] = "Hardcore Mode"
dict_cn_misc["野猪模式"] = "Boar Mode"
dict_cn_misc["流浪汉模式"] = "Vagrant's Endeavor"
dict_cn_misc["流浪者模式"] = "Vagrant's Endeavor"
dict_cn_misc["地狱模式"] = "Inferno Mode"
dict_cn_misc["炼狱模式"] = "Inferno Mode"
dict_cn_misc["工匠模式"] = "Artisan Mode"
dict_cn_misc["乌龟币"] = "Turtle Coin"
dict_cn_misc["乌龟代币"] = "Turtle Coin"
dict_cn_misc["商城币"] = "Shop Token"
dict_cn_misc["幻化币"] = "Fashion Coin"
dict_cn_misc["时尚币"] = "Fashion Coin"
dict_cn_misc["龟壳"] = "Turtle-Shell addon manager"
dict_cn_misc["龟龟助手"] = "Turtle helper tool"
dict_cn_misc["乌龟服疑难解答"] = "Turtle WoW FAQ"
dict_cn_misc["外围"] = "outside / perimeter"

-- ============================================================================
-- Vanilla Dungeons & Raids (A-Z & Abbreviations)
-- ============================================================================
dict_cn_misc["NY"] = "RFC"
dict_cn_misc["ny"] = "Ragefire Chasm"
dict_cn_misc["RFC"] = "Ragefire Chasm"
dict_cn_misc["rfc"] = "Ragefire Chasm"
dict_cn_misc["怒焰"] = "RFC"
dict_cn_misc["怒焰裂谷"] = "RFC"
dict_cn_misc["哀嚎洞穴"] = "WC"
dict_cn_misc["哀嚎洞窟"] = "Wailing Caverns"
dict_cn_misc["哀嚎"] = "Wailing Caverns"
dict_cn_misc["死亡矿坑"] = "DM"
dict_cn_misc["死亡矿井"] = "Deadmines"
dict_cn_misc["死矿"] = "Deadmines"
dict_cn_misc["DM"] = "Deadmines"
dict_cn_misc["dm"] = "Deadmines"
dict_cn_misc["VC"] = "Deadmines"
dict_cn_misc["vc"] = "Deadmines"
dict_cn_misc["SK"] = "Deadmines"
dict_cn_misc["sk"] = "Deadmines"
dict_cn_misc["迪菲亚海盗"] = "Defias Pirate"
dict_cn_misc["铁甲湾"]     = "Ironclad Cove"
dict_cn_misc["YY"] = "SFK"
dict_cn_misc["yy"] = "Shadowfang Keep"
dict_cn_misc["影牙城堡"] = "SFK"
dict_cn_misc["影牙"] = "Shadowfang Keep"
dict_cn_misc["SFK"] = "Shadowfang Keep"
dict_cn_misc["sfk"] = "Shadowfang Keep"
dict_cn_misc["黑暗深渊"] = "BFD"
dict_cn_misc["BFD"] = "Blackfathom Deeps"
dict_cn_misc["bfd"] = "Blackfathom Deeps"
dict_cn_misc["HD"] = "Blackfathom Deeps"
dict_cn_misc["hd"] = "Blackfathom Deeps"
dict_cn_misc["暴风监狱"] = "STOCKADES"
dict_cn_misc["暴风城监狱"] = "Stormwind Stockade"
dict_cn_misc["监狱"] = "Stockades"
dict_cn_misc["STOCKS"] = "Stockades"
dict_cn_misc["大JY"] = "Stormwind Vault"
dict_cn_misc["大监狱"] = "Stormwind Vault"
dict_cn_misc["大监狱地下"] = "Stormwind Vault"
dict_cn_misc["暴风城宝库"] = "Stormwind Vault"
dict_cn_misc["暴风城地下室"] = "Stormwind Vault"
dict_cn_misc["剃刀沼泽"] = "RFK"
dict_cn_misc["TDZ"] = "Razorfen Kraul"
dict_cn_misc["TDZZ"] = "Razorfen Kraul"
dict_cn_misc["TD沼泽"] = "Razorfen Kraul"
dict_cn_misc["RFK"] = "Razorfen Kraul"
dict_cn_misc["rfk"] = "Razorfen Kraul"
dict_cn_misc["ZZ"] = "Razorfen Kraul"
dict_cn_misc["zz"] = "Razorfen Kraul "
dict_cn_misc["诺莫瑞根"] = "GNOMER "
dict_cn_misc["侏儒FB"] = "Gnomeregan "
dict_cn_misc["侏儒城"] = "Gnomeregan"
dict_cn_misc["矮子FB"] = "Gnomeregan"
dict_cn_misc["GNOMER"] = "Gnomeregan"
dict_cn_misc["gnomer"] = "Gnomeregan"
dict_cn_misc["剃刀高地"] = "RFD "
dict_cn_misc["TD高地"] = "Razorfen Downs"
dict_cn_misc["TDGD"] = "Razorfen Downs"
dict_cn_misc["RFD"] = "Razorfen Downs"
dict_cn_misc["rfd"] = "Razorfen Downs"
dict_cn_misc["GD"] = "Razorfen Downs"
dict_cn_misc["gd"] = "Razorfen Downs"
dict_cn_misc["血色修道院"] = "SM"
dict_cn_misc["血色"] = "SM"
dict_cn_misc["XS"] = "SM"
dict_cn_misc["xs"] = "Scarlet Monastery"
dict_cn_misc["教堂"] = "Cathedral"
dict_cn_misc["图书馆"] = "Library"
dict_cn_misc["墓地"] = "Graveyard"
dict_cn_misc["MD"] = "Graveyard"
dict_cn_misc["武器库"] = "Armory"
dict_cn_misc["XS图书馆"] = "Scarlet Monastery Library"
dict_cn_misc["XS墓地"] = "Scarlet Monastery Graveyard"
dict_cn_misc["XS教堂"] = "Scarlet Monastery Cathedral"
dict_cn_misc["XS武器库"] = "Scarlet Monastery Armory"
dict_cn_misc["奥达曼"] = "Uldaman"
dict_cn_misc["ODM"] = "Uldaman"
dict_cn_misc["adm"] = "Uldaman"
dict_cn_misc["ADM"] = "Uldaman"
dict_cn_misc["ULDA"] = "Uldaman"
dict_cn_misc["ulda"] = "Uldaman"
dict_cn_misc["祖尔法拉克"] = "ZF"
dict_cn_misc["祖法"] = "Zul'Farrak"
dict_cn_misc["ZUL"] = "ZF"
dict_cn_misc["ZF"] = "Zul'Farrak"
dict_cn_misc["zf"] = "Zul'Farrak"
dict_cn_misc["ZFLK"] = "Zul'Farrak"
dict_cn_misc["FLK"] = "Zul'Farrak"
dict_cn_misc["玛拉顿"] = "MARAUDON"
dict_cn_misc["MLTD"] = "MARA"
dict_cn_misc["MLD"] = "Maraudon"
dict_cn_misc["mld"] = "Maraudon"
dict_cn_misc["MARA"] = "Maraudon"
dict_cn_misc["mara"] = "Maraudon"
dict_cn_misc["塔哈克神庙"] = "ST "
dict_cn_misc["沉没的神庙"] = "Sunken Temple "
dict_cn_misc["神庙"] = "Sunken Temple "
dict_cn_misc["阿塔哈卡神庙"] = "Sunken Temple "
dict_cn_misc["TK"] = "Sunken Temple "
dict_cn_misc["tk"] = "Sunken Temple "
dict_cn_misc["黑石深渊"] = "BRD "
dict_cn_misc["BRD"] = "Blackrock Depths "
dict_cn_misc["brd"] = "Blackrock Depths "
dict_cn_misc["黑深"] = "Blackrock Depths "
dict_cn_misc["本通灵学院"] = "SCHOLO"
dict_cn_misc["通灵"] = "Scholomance"
dict_cn_misc["通灵学院"] = "Scholomance"
dict_cn_misc["SCHOLO"] = "Scholomance"
dict_cn_misc["scholo"] = "Scholomance"
dict_cn_misc["TLXY"] = "Scholomance"
dict_cn_misc["斯坦索姆"] = "STRAT"
dict_cn_misc["STSM"] = "STRAT"
dict_cn_misc["stsm"] = "Stratholme"
dict_cn_misc["STRAT"] = "Stratholme"
dict_cn_misc["strat"] = "Stratholme"
dict_cn_misc["斯坦"] = "Stratholme"
dict_cn_misc["亡灵区"] = "Stratholme (Undead)"
dict_cn_misc["STDK"] = "Stratholme (Undead side)"
dict_cn_misc["血色十字"] = "Stratholme (Live)"
dict_cn_misc["死人"] = "Strat UD side"
dict_cn_misc["活人"] = "Strat Live side"
dict_cn_misc["死面"] = "Stratholme Undead"
dict_cn_misc["活面"] = "Stratholme Live"
dict_cn_misc["牵马队"] = "Strat UD side"
dict_cn_misc["牵马"] = "Strat UD side"
dict_cn_misc["DK队"] = "Strat UD"
dict_cn_misc["死亡骑士"] = "Strat UD side"
dict_cn_misc["男爵"] = "Baron run"
dict_cn_misc["黑石塔下"] = "LBRS"
dict_cn_misc["黑下"] = "LBRS "
dict_cn_misc["下层"] = "LBRS"
dict_cn_misc["LBRS"] = "Lower Blackrock Spire"
dict_cn_misc["lbrs"] = "Lower Blackrock Spire"
dict_cn_misc["黑石塔下层"] = "Lower Blackrock Spire"
dict_cn_misc["北都"] = "LBRS"
dict_cn_misc["黑石塔上"] = "UBRS"
dict_cn_misc["黑上"] = "UBRS"
dict_cn_misc["上层"] = "UBRS"
dict_cn_misc["UBRS"] = "Upper Blackrock Spire"
dict_cn_misc["ubrs"] = "Upper Blackrock Spire"
dict_cn_misc["黑石塔上层"] = "Upper Blackrock Spire"
dict_cn_misc["南都"] = "UBRS"
dict_cn_misc["HS"] = "Upper Blackrock Spire"
dict_cn_misc["hs"] = "Upper Blackrock Spire"
dict_cn_misc["HX"] = "Lower Blackrock Spire"
dict_cn_misc["hx"] = "Lower Blackrock Spire"
dict_cn_misc["黑石塔"] = "Blackrock Spire"
dict_cn_misc["厄运之槌"] = "Dire Maul"
dict_cn_misc["厄运"] = "Dire Maul"
dict_cn_misc["厄运东"] = "Dire Maul East"
dict_cn_misc["厄运北"] = "Dire Maul North"
dict_cn_misc["厄运西"] = "Dire Maul West"
dict_cn_misc["DME"] = "Dire Maul East"
dict_cn_misc["DMN"] = "Dire Maul North"
dict_cn_misc["DMW"] = "Dire Maul West"
dict_cn_misc["DM贡品"] = "Dire Maul Tribute"
dict_cn_misc["DM北增益"] = "DM North Buffs"
dict_cn_misc["DM增益"] = "DM Buffs"
dict_cn_misc["熔火之心"] = "MC"
dict_cn_misc["火心"] = "Molten Core"
dict_cn_misc["熔核"] = "Molten Core"
dict_cn_misc["黑翼之巢"] = "BWL"
dict_cn_misc["黑翼"] = "Blackwing Lair"
dict_cn_misc["BWL"] = "BWL"
dict_cn_misc["bwl"] = "Blackwing Lair"
dict_cn_misc["祖尔格拉布"] = "ZG"
dict_cn_misc["祖格"] = "Zul'Gurub"
dict_cn_misc["ZG"] = "ZG"
dict_cn_misc["zg"] = "Zul'Gurub"
dict_cn_misc["ZUG"] = "Zul'Gurub"
dict_cn_misc["安其拉废墟"] = "Ruins of Ahn'Qiraj"
dict_cn_misc["废墟"] = "AQ20"
dict_cn_misc["AQ20"] = "AQ20"
dict_cn_misc["aq20"] = "Ruins of Ahn'Qiraj"
dict_cn_misc["FX"] = "Ruins of Ahn'Qiraj"
dict_cn_misc["fx"] = "Ruins of Ahn'Qiraj"
dict_cn_misc["安其拉圣地"] = "AQ40"
dict_cn_misc["安其拉神庙"] = "Temple of Ahn'Qiraj"
dict_cn_misc["安其拉神殿"] = "Temple of Ahn'Qiraj"
dict_cn_misc["神殿"] = "AQ40"
dict_cn_misc["安其拉"] = "Ahn'Qiraj"
dict_cn_misc["AQ40"] = "AQ40"
dict_cn_misc["aq40"] = "Temple of Ahn'Qiraj"
dict_cn_misc["AQL"] = "Temple of Ahn'Qiraj"
dict_cn_misc["TAQ"] = "Temple of Ahn'Qiraj"
dict_cn_misc["taq"] = "Temple of Ahn'Qiraj"
dict_cn_misc["纳克萨玛斯"] = "Naxx"
dict_cn_misc["纳克"] = "Naxxramas"
dict_cn_misc["老克家"] = "Naxxramas"
dict_cn_misc["Naxx"] = "Naxx"
dict_cn_misc["NAX"] = "Naxxramas"
dict_cn_misc["NAXX"] = "Naxxramas"
dict_cn_misc["nax"] = "Naxxramas"
dict_cn_misc["naxx"] = "Naxxramas"
dict_cn_misc["奥妮克希亚的巢穴"] = "Onyxia's Lair"
dict_cn_misc["巢穴"] = "Onyxia's Lair"
dict_cn_misc["ONY"] = "Onyxia"
dict_cn_misc["ony"] = "Onyxia"
dict_cn_misc["ZNSY"] = "ZA"
dict_cn_misc["ZAM"] = "ZA"
dict_cn_misc["ZM"] = "ZA"
dict_cn_misc["KLZ"] = "Karazhan"
dict_cn_misc["klz"] = "Karazhan"
dict_cn_misc["卡拉赞"] = "Karazhan"
dict_cn_misc["卡上"] = "Karazhan (upper)"
dict_cn_misc["卡下"] = "Karazhan (lower)"
dict_cn_misc["KLZ上"] = "Karazhan (upper)"
dict_cn_misc["KLZ下"] = "Karazhan (lower)"
dict_cn_misc["KLZ地穴"] = "Karazhan Crypts"
dict_cn_misc["KLZ墓穴"] = "Karazhan Crypts"
dict_cn_misc["卡拉赞上层"] = "Upper Karazhan"
dict_cn_misc["卡拉赞下层"] = "Lower Karazhan"
dict_cn_misc["卡拉赞下层大厅"] = "Lower Karazhan Halls"
dict_cn_misc["卡拉赞之塔"] = "Tower of Karazhan"
dict_cn_misc["卡拉赞之塔上层"] = "Tower of Karazhan (Upper)"
dict_cn_misc["卡拉赞地下墓穴"] = "Karazhan Crypt"
dict_cn_misc["卡拉赞地窖"] = "Karazhan Crypt"
dict_cn_misc["卡拉赞墓穴"] = "Karazhan Crypt"
dict_cn_misc["海加尔山"] = "Mount Hyjal"
dict_cn_misc["海山"] = "Mount Hyjal"
dict_cn_misc["海山螺丝厂"] = "Mount Hyjal (farm)"
dict_cn_misc["海山跑跑团"] = "Hyjal jog farm group"
dict_cn_misc["时光之穴"] = "Black Morass"
dict_cn_misc["黑色沼泽"] = "The Black Morass"
dict_cn_misc["SG"] = "Black Morass"
dict_cn_misc["sg"] = "Black Morass"
dict_cn_misc["地下城"] = "dungeon"
dict_cn_misc["副本"] = "dungeon"
dict_cn_misc["团队"] = "raid"
dict_cn_misc["FB"] = "Dungeon"
dict_cn_misc["fb"] = "Dungeon"

-- ============================================================================
-- Custom Strategic Combat Warnings (ADDITIONS)
-- ============================================================================
dict_cn_misc["清小怪"] = "Clear trash"
dict_cn_misc["小怪区"] = "Trash packs"
dict_cn_misc["发车"] = "Pulling / Starting"

-- ============================================================================
-- Combat Mechanics & Strategy
-- ============================================================================
dict_cn_misc["打断"] = "interrupt"
dict_cn_misc["灭"] = "wipe"
dict_cn_misc["灭了"] = "Wiped"
dict_cn_misc["灭团"] = "Wipe"
dict_cn_misc["团灭"] = "Wipe"


-- ============================================================================
-- Status & Buffs / Debuffs
-- ============================================================================
dict_cn_misc["满BUFF"] = "Full world buffs"
dict_cn_misc["上BUFF"] = "applying buff"
dict_cn_misc["世界BUFF"] = "World buffs"
dict_cn_misc["世界BUFF团"] = "World-buff raid"
dict_cn_misc["三大"] = "the three world buffs"
dict_cn_misc["儿童套餐"] = "basic raid buffs (Stam/MotW/Int)"

-- ============================================================================
-- Specific Class Spells & Items
-- ============================================================================
dict_cn_misc["灵魂石"] = "soulstone"
dict_cn_misc["战斗复活"] = "combat rez"
dict_cn_misc["战复"] = "Battle res"
dict_cn_misc["糖"] = "Healthstone"
dict_cn_misc["治疗石"] = "Healthstone"
dict_cn_misc["自由拾取"] = "Free for All (loot)"
dict_cn_misc["队长分配"] = "Master Looter"
dict_cn_misc["开门"] = "Mage Portal"
dict_cn_misc["要水"] = "need water"
dict_cn_misc["要面包"] = "need bread"
dict_cn_misc["YMB"] = "need bread"
dict_cn_misc["ymb"] = "need bread"

-- ============================================================================
-- Custom Social Player Slang Callouts (ADDITIONS)
-- ============================================================================
dict_cn_misc["老司机"] = "Veteran player"
dict_cn_misc["划水怪"] = "Slacker"
dict_cn_misc["伸手党"] = "Beggar"
dict_cn_misc["老板"] = "GDKP buyer"
dict_cn_misc["打工仔"] = "GDKP carry"
dict_cn_misc["工具人"] = "Buff/Utility bot"

-- ============================================================================
-- General Social, Chat & Slang Expressions
-- ============================================================================
dict_cn_misc["谢谢"] = "thanks"
dict_cn_misc["万分感谢"] = "Many thanks"
dict_cn_misc["非常感谢"] = "Thanks a lot"
dict_cn_misc["辛苦了"] = "Good job/Thanks for the effort"
dict_cn_misc["好的"] = "okay"
dict_cn_misc["好"] = "okay"
dict_cn_misc["可以"] = "okay"
dict_cn_misc["行"] = "sure"
dict_cn_misc["对"] = "correct"
dict_cn_misc["不"] = "no"
dict_cn_misc["不行"] = "no"
dict_cn_misc["是"] = "yes"
dict_cn_misc["当然"] = "of course"
dict_cn_misc["也许"] = "maybe"
dict_cn_misc["随便"] = "whatever"
dict_cn_misc["没有"] = "no / none"
dict_cn_misc["有"] = "yes / have"
dict_cn_misc["对不起"] = "Sorry"
dict_cn_misc["抱歉"] = "Sorry"
dict_cn_misc["我的错"] = "My bad"
dict_cn_misc["没事"] = "It's fine"
dict_cn_misc["没关系"] = "No problem"
dict_cn_misc["问题"] = "problem"
dict_cn_misc["没问题"] = "no problem"
dict_cn_misc["错了"] = "wrong"
dict_cn_misc["真的"] = "really"
dict_cn_misc["不客气"] = "You're welcome"
dict_cn_misc["祝你好运"] = "Good luck"
dict_cn_misc["加油"] = "good luck"
dict_cn_misc["大佬"] = "Big shot/Veteran"
dict_cn_misc["老兵"] = "veteran"
dict_cn_misc["老玩家"] = "veteran player"
dict_cn_misc["大神"] = "Pro player"
dict_cn_misc["大哥"] = "pro player"
dict_cn_misc["高玩"] = "skilled player"
dict_cn_misc["高手"] = "skilled player"
dict_cn_misc["欧皇"] = "lucky player"
dict_cn_misc["脸白"] = "good luck"
dict_cn_misc["非酋"] = "unlucky player"
dict_cn_misc["脸黑"] = "bad luck"
dict_cn_misc["菜"] = "Noob"
dict_cn_misc["菜鸟"] = "Noob"
dict_cn_misc["菜鸡"] = "noob"
dict_cn_misc["萌新"] = "Newbie"
dict_cn_misc["新手"] = "Newbie"
dict_cn_misc["童工"] = "boosted lowbie"
dict_cn_misc["划水"] = "AFK/coasting"
dict_cn_misc["摸鱼"] = "slacking"
dict_cn_misc["摆烂"] = "throw/sandbag"
dict_cn_misc["躺平"] = "give up"
dict_cn_misc["土豪"] = "whale"
dict_cn_misc["富哥"] = "rich player"
dict_cn_misc["穷"] = "broke"
dict_cn_misc["内卷"] = "tryhard"
dict_cn_misc["强力党"] = "min-maxer"
dict_cn_misc["数据党"] = "spreadsheet player"
dict_cn_misc["千金党"] = "AH scammer"
dict_cn_misc["拼音党"] = "pinyin abbreviator"
dict_cn_misc["排骨人"] = "raid leech"
dict_cn_misc["金农"] = "gold farmer"
dict_cn_misc["兄弟们"] = "Bros"
dict_cn_misc["朋友"] = "Friend"
dict_cn_misc["哈哈"] = "haha"
dict_cn_misc["哈哈哈"] = "lol"
dict_cn_misc["哈哈哈哈"] = "lmao"
dict_cn_misc["笑死"] = "lmao"
dict_cn_misc["233"] = "LOL"
dict_cn_misc["2333"] = "LOL"
dict_cn_misc["LOL"] = "LOL"
dict_cn_misc["lol"] = "LOL"
dict_cn_misc["666"] = "nice"
dict_cn_misc["6666"] = "Very nice!"
dict_cn_misc["666了"] = "Incredibly well played!"
dict_cn_misc["厉害"] = "impressive"
dict_cn_misc["太厉害了"] = "That's awesome!"
dict_cn_misc["牛"] = "nice"
dict_cn_misc["牛逼"] = "awesome"
dict_cn_misc["好玩"] = "fun"
dict_cn_misc["无聊"] = "boring"
dict_cn_misc["太难了"] = "too hard"
dict_cn_misc["简单"] = "easy"
dict_cn_misc["服了"] = "unbelievable"

-- ============================================================================
-- Status & Scheduling (Time, Logs, Channels)
-- ============================================================================
dict_cn_misc["在线"] = "online"
dict_cn_misc["离线"] = "offline"
dict_cn_misc["上线"] = "Online"
dict_cn_misc["下线"] = "Offline"
dict_cn_misc["忙"] = "busy"
dict_cn_misc["回来了"] = "back"
dict_cn_misc["我回来了"] = "I'm back"
dict_cn_misc["吃饭"] = "eating"
dict_cn_misc["睡觉"] = "sleeping"
dict_cn_misc["上厕所"] = "bathroom break"
dict_cn_misc["暂离"] = "AFK"
dict_cn_misc["AFK"] = "AFK"
dict_cn_misc["afk"] = "AFK"
dict_cn_misc["BRB"] = "BRB"
dict_cn_misc["brb"] = "BRB"
dict_cn_misc["马上回来"] = "BRB"
dict_cn_misc["我累了"] = "I'm tired"
dict_cn_misc["得走了"] = "GTG (gotta go)"
dict_cn_misc["晚上"] = "tonight"
dict_cn_misc["早上"] = "morning"
dict_cn_misc["下午"] = "afternoon"
dict_cn_misc["本周"] = "this week"
dict_cn_misc["几点"] = "what time?"
dict_cn_misc["什么时候"] = "When?"
dict_cn_misc["倒数"] = "Countdown"
dict_cn_misc["大退"] = "quit game"
dict_cn_misc["小退"] = "to char select screen"
dict_cn_misc["重登"] = "relog"
dict_cn_misc["等一下"] = "Wait a moment"
dict_cn_misc["等等"] = "Wait"
dict_cn_misc["算了"] = "Nevermind"
dict_cn_misc["几号开"] = "what time starting?"
dict_cn_misc["现在开"] = "starting now"
dict_cn_misc["马上开"] = "starting soon"
dict_cn_misc["开始"] = "Start"
dict_cn_misc["走吧"] = "Let's go"
dict_cn_misc["过来"] = "Come here"
dict_cn_misc["别动"] = "Don't move"
dict_cn_misc["别担心"] = "Don't worry"
dict_cn_misc["快点"] = "hurry up"
dict_cn_misc["快动"] = "Move!"
dict_cn_misc["稳"] = "steady"
dict_cn_misc["稳住"] = "hold steady"
dict_cn_misc["注意"] = "watch out"
dict_cn_misc["小心"] = "be careful"
dict_cn_misc["你好"] = "Hello"
dict_cn_misc["大家好"] = "Hello everyone"
dict_cn_misc["有人吗"] = "Anyone there?"
dict_cn_misc["在吗"] = "You there?"
dict_cn_misc["再见"] = "Goodbye"
dict_cn_misc["拜拜"] = "Bye"
dict_cn_misc["88"] = "Bye"
dict_cn_misc["886"] = "Bye bye"
dict_cn_misc["晚安"] = "GN (good night)"
dict_cn_misc["GG"] = "GG"
dict_cn_misc["gg"] = "GG"
dict_cn_misc["WTF"] = "WTF"
dict_cn_misc["wtf"] = "WTF"
dict_cn_misc["OK"] = "OK"
dict_cn_misc["私我"] = "PST"
dict_cn_misc["私聊"] = "whisper me"
dict_cn_misc["直接密"] = "Whisper me"
dict_cn_misc["密我"] = "whisper me"
dict_cn_misc["密一下"] = "whisper me"
dict_cn_misc["来密"] = "Whisper me"
dict_cn_misc["来的密"] = "whisper me to join"
dict_cn_misc["求密"] = "Whisper me"
dict_cn_misc["MM"] = "Whisper"
dict_cn_misc["MMM"] = "Whisper"
dict_cn_misc["MMMM"] = "Whisper"
dict_cn_misc["MMMMM"] = "Whisper"
dict_cn_misc["MMMMMM"] = "Whisper"
dict_cn_misc["MMMMMMM"] = "Whisper"
dict_cn_misc["MMMMMMMM"] = "Whisper"
dict_cn_misc["MMMMMMMMM"] = "Whisper"
dict_cn_misc["MMMMMMMMMM"] = "Whisper"
dict_cn_misc["密密"] = "Whisper"
dict_cn_misc["密密密"] = "Whisper"
dict_cn_misc["密密密密"] = "Whisper"
dict_cn_misc["密密密密密"] = "Whisper"
dict_cn_misc["密密密密密密"] = "Whisper"
dict_cn_misc["世界频道"] = "world channel"
dict_cn_misc["交易频道"] = "trade channel"
dict_cn_misc["公聊"] = "say channel"

-- ============================================================================
-- Items, Gear Types, Bags & Materials
-- ============================================================================
dict_cn_misc["装备"] = "gear"
dict_cn_misc["ZB"] = "Gear"
dict_cn_misc["zb"] = "Gear"
dict_cn_misc["毕业装"] = "BiS gear"
dict_cn_misc["BIS"] = "Best in Slot"
dict_cn_misc["套装"] = "set gear"
dict_cn_misc["散件"] = "open-roll piece"
dict_cn_misc["武器"] = "weapon"
dict_cn_misc["护甲"] = "armor"
dict_cn_misc["戒指"] = "ring"
dict_cn_misc["项链"] = "necklace"
dict_cn_misc["背包"] = "bag"
dict_cn_misc["材料"] = "materials"
dict_cn_misc["药水"] = "potion"
dict_cn_misc["绷带"] = "bandage"
dict_cn_misc["食物"] = "food"
dict_cn_misc["白装"] = "white gear"
dict_cn_misc["绿装"] = "green gear"
dict_cn_misc["蓝装"] = "blue gear"
dict_cn_misc["紫装"] = "epic gear"
dict_cn_misc["史诗"] = "epic"
dict_cn_misc["橙装"] = "legendary"
dict_cn_misc["传说"] = "Legendary"
dict_cn_misc["拾取后绑定"] = "Bind on Pickup (BOP)"
dict_cn_misc["拾绑"] = "BOP (Bind on Pickup)"
dict_cn_misc["装备后绑定"] = "Bind on Equip (BOE)"
dict_cn_misc["装绑"] = "BOE (Bind on Equip)"
dict_cn_misc["药水CD"] = "potion cooldown"
dict_cn_misc["磕药"] = "use potion"
dict_cn_misc["大红"] = "Major Healing Potion"
dict_cn_misc["大蓝"] = "Major Mana Potion"
dict_cn_misc["暗抗药"] = "Shadow Resist Potion"
dict_cn_misc["火抗药"] = "Fire Resist Potion"
dict_cn_misc["合剂"] = "Flask"
dict_cn_misc["精炼"] = "Elixir"
dict_cn_misc["泰坦合剂"] = "Flask of the Titans"
dict_cn_misc["巨人合剂"] = "Flask of Supreme Power"
dict_cn_misc["精灵合剂"] = "Flask of Distilled Wisdom"
dict_cn_misc["黑莲花"] = "Black Lotus"
dict_cn_misc["火焰之油"] = "Fire Oil"
dict_cn_misc["符文布"] = "Runecloth"

-- ============================================================================
-- Economics, Bidding, GDKP & Auction House
-- ============================================================================
dict_cn_misc["金"] = "gold"
dict_cn_misc["银"] = "silver"
dict_cn_misc["银币"] = "silver"
dict_cn_misc["铜"] = "copper"
dict_cn_misc["铜币"] = "copper"
dict_cn_misc["金币"] = "gold"
dict_cn_misc["价格"] = "Price"
dict_cn_misc["多少钱"] = "How much?"
dict_cn_misc["多少G"] = "how much gold?"
dict_cn_misc["多少金"] = "How much gold?"
dict_cn_misc["几G"] = "how much gold?"
dict_cn_misc["便宜"] = "Cheap"
dict_cn_misc["便宜点"] = "cheaper please"
dict_cn_misc["少点"] = "lower the price"
dict_cn_misc["贵"] = "Expensive"
dict_cn_misc["买"] = "Buying"
dict_cn_misc["求购"] = "WTB (Buying)"
dict_cn_misc["出售"] = "WTS (Selling)"
dict_cn_misc["卖"] = "WTS"
dict_cn_misc["卖了"] = "sold"
dict_cn_misc["成交"] = "Sold"
dict_cn_misc["收了"] = "bought"
dict_cn_misc["买金"] = "buying gold (illegal)"
dict_cn_misc["卖金"] = "selling gold (illegal)"
dict_cn_misc["拍卖行"] = "Auction House"
dict_cn_misc["挂AH"] = "list on AH"
dict_cn_misc["挂拍卖"] = "list on AH"
dict_cn_misc["保管费"] = "deposit fee"
dict_cn_misc["手续费"] = "AH fee"
dict_cn_misc["流标"] = "AH unsold"
dict_cn_misc["黑金"] = "scam price"
dict_cn_misc["竞价"] = "bid"
dict_cn_misc["拍卖"] = "auction"
dict_cn_misc["竞拍"] = "bid"
dict_cn_misc["底价"] = "minimum bid"
dict_cn_misc["一口价"] = "buyout price"
dict_cn_misc["起拍价"] = "Opening Bid"
dict_cn_misc["加价"] = "Bid increment"
dict_cn_misc["分钱"] = "split gold"
dict_cn_misc["分G"] = "GDKP split"
dict_cn_misc["保底"] = "guaranteed payout"
dict_cn_misc["G团"] = "gold-bid pug"
dict_cn_misc["金团"] = "GDKP"
dict_cn_misc["金币团"] = "GDKP"
dict_cn_misc["EPGP"] = "EPGP loot system"
dict_cn_misc["DKP团"] = "DKP raid"
dict_cn_misc["MS团"] = "Main-Spec raid"
dict_cn_misc["SR团"] = "SR run"
dict_cn_misc["主副天赋"] = "MS/OS"
dict_cn_misc["主天赋"] = "Main Spec"
dict_cn_misc["副天赋"] = "Off Spec"
dict_cn_misc["OS"] = "Off Spec"
dict_cn_misc["ROLL"] = "roll"
dict_cn_misc["贪婪"] = "greed"
dict_cn_misc["传递"] = "pass"
dict_cn_misc["需求"] = "Need (loot)"
dict_cn_misc["分了"] = "disenchant it"
dict_cn_misc["分解"] = "Disenchant"
dict_cn_misc["保留"] = "reserve"
dict_cn_misc["硬保留"] = "Hard Reserve"
dict_cn_misc["软保留"] = "Soft Reserve (SR)"
dict_cn_misc["许愿"] = "SR (soft reserve)"
dict_cn_misc["许愿团"] = "SR run (make-a-wish raid)"
dict_cn_misc["毛人"] = "ninja looter"
dict_cn_misc["毛团"] = "ninja raid"
dict_cn_misc["曝光毛人"] = "expose the ninja looter"

-- ============================================================================
-- Custom Attunements & Keys Slang (ADDITIONS)
-- ============================================================================
dict_cn_misc["开门任务"] = "Attunement quest"
dict_cn_misc["钥匙"] = "Key"
dict_cn_misc["黑手钥匙"] = "UBRS Key"
dict_cn_misc["月亮钥匙"] = "Maraudon Key"

-- ============================================================================
-- Quests, Levels, Progression & Factions
-- ============================================================================
dict_cn_misc["任务"] = "quest"
dict_cn_misc["主线"] = "main quest"
dict_cn_misc["支线"] = "side quest"
dict_cn_misc["日常"] = "daily quest"
dict_cn_misc["升级"] = "level up"
dict_cn_misc["等级"] = "level"
dict_cn_misc["满级"] = "max level"
dict_cn_misc["经验"] = "experience"
dict_cn_misc["声望"] = "reputation"
dict_cn_misc["荣誉"] = "honor"
dict_cn_misc["军衔"] = "Rank"
dict_cn_misc["新手"] = "Newbie"
dict_cn_misc["地图"] = "map"
dict_cn_misc["坐骑"] = "mount"
dict_cn_misc["宠物"] = "pet"
dict_cn_misc["技能书"] = "skill book"
dict_cn_misc["技能点"] = "talent points"
dict_cn_misc["首杀"] = "server first kill"
dict_cn_misc["打过"] = "Killed before"
dict_cn_misc["没打过"] = "Never killed"
dict_cn_misc["首领击杀"] = "boss kill"
dict_cn_misc["过了"] = "Killed/Cleared"
dict_cn_misc["联盟"] = "Alliance"
dict_cn_misc["部落"] = "Horde"
dict_cn_misc["BL"] = "Horde"
dict_cn_misc["阵营"] = "faction"
dict_cn_misc["开荒"] = "Progression"
dict_cn_misc["开荒团"] = "Progression raid"
dict_cn_misc["公会"] = "guild"
dict_cn_misc["工会"] = "guild"
dict_cn_misc["工会团"] = "Guild run"
dict_cn_misc["欢迎"] = "welcome"

-- ============================================================================
-- World Buffs, Specific Rare Items & Icons
-- ============================================================================
dict_cn_misc["风剑"] = "Thunderfury"
dict_cn_misc["小风剑"] = "Thunderfury"
dict_cn_misc["雷霆之怒"] = "Thunderfury"
dict_cn_misc["橙杖"] = "Atiesh"
dict_cn_misc["艾提什"] = "Atiesh"
dict_cn_misc["鸡腿杖"] = "Atiesh"
dict_cn_misc["橙锤"] = "Sulfuras"
dict_cn_misc["萨弗拉斯"] = "Sulfuras"
dict_cn_misc["灰烬使者"] = "Ashbringer"
dict_cn_misc["堕落的灰烬使者"] = "Corrupted Ashbringer"
dict_cn_misc["奎尔塞拉"] = "Quel'Serrar"
dict_cn_misc["屠龙刀"] = "Quel'Serrar"
dict_cn_misc["阿什坎迪"] = "Ashkandi"
dict_cn_misc["阿什坎迪兄弟会之剑"] = "Ashkandi, Greatsword of the Brotherhood"
dict_cn_misc["艾露恩之镰"] = "Scythe of Elune"
dict_cn_misc["克拉科拉之偶"] = "Idol of Cla'ckora"
dict_cn_misc["龙头"] = "Ony/Nef Head Buff"
dict_cn_misc["龙头BUFF"] = "Rallying Cry of the Dragonslayer"
dict_cn_misc["奈法头"] = "Nef Head Buff"
dict_cn_misc["奥妮头"] = "Ony Head Buff"
dict_cn_misc["哈卡头"] = "Heart of Hakkar Buff"
dict_cn_misc["赞达拉"] = "Spirit of Zandalar"
dict_cn_misc["祖格BUFF"] = "Spirit of Zandalar"
dict_cn_misc["ZG增益"] = "Spirit of Zandalar"
dict_cn_misc["鲜血BUFF"] = "Spirit of Zandalar"
dict_cn_misc["心火"] = "Spirit of Zandalar"
dict_cn_misc["酋长"] = "Warchief's Blessing"
dict_cn_misc["酋长BUFF"] = "Warchief's Blessing"
dict_cn_misc["松花"] = "Songflower"
dict_cn_misc["花"] = "Songflower"
dict_cn_misc["花BUFF"] = "Songflower Serenade"


-- ============================================================================
-- Grind Types & Run Metrics
-- ============================================================================
dict_cn_misc["刷"] = "grind"
dict_cn_misc["刷怪"] = "grind mobs"
dict_cn_misc["怪"] = "mob"
dict_cn_misc["精英"] = "elite"
dict_cn_misc["jy"] = "elite"
dict_cn_misc["JY"] = "elite"
dict_cn_misc["首领"] = "boss"
dict_cn_misc["boss"] = "boss"
dict_cn_misc["BOSS"] = "boss"
dict_cn_misc["小怪"] = "trash mob"
dict_cn_misc["巡逻怪"] = "patrol mob"
dict_cn_misc["稀有"] = "Rare"
dict_cn_misc["稀有怪"] = "rare elite"
dict_cn_misc["死了"] = "dead"
dict_cn_misc["跑路"] = "run away"
dict_cn_misc["跑尸"] = "Corpse run"
dict_cn_misc["单刷"] = "solo run"
dict_cn_misc["双刷"] = "duo run"
dict_cn_misc["带"] = "Carry"
dict_cn_misc["带飞"] = "carry run"
dict_cn_misc["全程带"] = "full carry"
dict_cn_misc["带刷"] = "Boost/Carry"
dict_cn_misc["带秒"] = "Fast carry"
dict_cn_misc["快餐"] = "boosted/carry"
dict_cn_misc["刷马鞭"] = "Stormwind Vault (whip farm)"
dict_cn_misc["搬砖团"] = "grind run"
dict_cn_misc["农团"] = "Farm run"
dict_cn_misc["速刷"] = "speed clear"
dict_cn_misc["速刷队"] = "speed clear team"
dict_cn_misc["速刷团"] = "speed-clear raid"
dict_cn_misc["速通"] = "speed run"
dict_cn_misc["效率队"] = "efficiency group"
dict_cn_misc["全通"] = "full clear"
dict_cn_misc["光速"] = "speed"
dict_cn_misc["强力队"] = "strong group"
dict_cn_misc["AA团"] = "free roll raid"
dict_cn_misc["自己有本"] = "have lockout"
dict_cn_misc["没本"] = "no lockout"
dict_cn_misc["没有本"] = "no lockout"
dict_cn_misc["重置"] = "reset"
dict_cn_misc["重开"] = "restart"
dict_cn_misc["野团"] = "PUG"


-- ============================================================================
-- Professions
-- ============================================================================
dict_cn_misc["剥皮"] = "Skinning"
dict_cn_misc["草药"] = "Herbalism"
dict_cn_misc["采矿"] = "Mining"
dict_cn_misc["锻造"] = "Blacksmithing"
dict_cn_misc["工程"] = "Engineering"
dict_cn_misc["制皮"] = "Leatherworking"
dict_cn_misc["裁缝"] = "Tailoring"
dict_cn_misc["炼金"] = "Alchemy"
dict_cn_misc["附魔"] = "Enchanting"
dict_cn_misc["珠宝"] = "Gem/Jewelcrafting"
dict_cn_misc["宝石"] = "Gem"
dict_cn_misc["宝石切割"] = "Gem cut"
dict_cn_misc["钻石"] = "Diamond (gem)"


-- ============================================================================
-- PvP & Battlegrounds
-- ============================================================================
dict_cn_misc["PVP"] = "PVP"
dict_cn_misc["pvp"] = "PvP"
dict_cn_misc["PVE"] = "PVE"
dict_cn_misc["pve"] = "PvE"
dict_cn_misc["战场"] = "battleground"
dict_cn_misc["BG"] = "Battleground"
dict_cn_misc["bg"] = "Battleground"
dict_cn_misc["排战场"] = "queue battleground"
dict_cn_misc["排队"] = "queue"
dict_cn_misc["打野"] = "open world PvP"
dict_cn_misc["开PVP"] = "PvP flag on"
dict_cn_misc["插旗"] = "PvP flag on"
dict_cn_misc["战争模式"] = "War Mode"
dict_cn_misc["拿旗"] = "Grab the flag"
dict_cn_misc["还旗"] = "Return the flag"
dict_cn_misc["旗帜"] = "Flag"
dict_cn_misc["旗手"] = "Flag carrier"
dict_cn_misc["斜坡"] = "Ramp"
dict_cn_misc["坡道"] = "Ramp (WSG)"
dict_cn_misc["隧道"] = "Tunnel (WSG)"
dict_cn_misc["阿拉希"] = "Arathi Basin"
dict_cn_misc["奥山"] = "Alterac Valley"
dict_cn_misc["WSG"] = "Warsong Gulch"
dict_cn_misc["wsg"] = "Warsong Gulch"
dict_cn_misc["战歌"] = "Warsong Gulch"
dict_cn_misc["铁匠铺"] = "Blacksmith (AB)"
dict_cn_misc["AB铁"] = "AB Blacksmith"
dict_cn_misc["农场"] = "Farm (AB)"
dict_cn_misc["马厩"] = "Stables (AB)"
dict_cn_misc["金矿"] = "Gold Mine (AB)"
dict_cn_misc["AB矿"] = "AB Mine"
dict_cn_misc["AB木"] = "AB Lumber Mill"
dict_cn_misc["锯木场"] = "Lumber Mill (AB)"

-- ============================================================================
-- World Zones & Major Cities
-- ============================================================================
dict_cn_misc["东部王国"] = "Eastern Kingdoms"
dict_cn_misc["卡利姆多"] = "Kalimdor"
dict_cn_misc["野外"] = "open world"
dict_cn_misc["暴风"] = "Stormwind"
dict_cn_misc["暴风城"] = "Stormwind"
dict_cn_misc["奥格"] = "Orgrimmar"
dict_cn_misc["奥格瑞玛"] = "Orgrimmar"
dict_cn_misc["幽暗城"] = "Undercity"
dict_cn_misc["铁炉堡"] = "Ironforge"
dict_cn_misc["铁炉"] = "Ironforge"
dict_cn_misc["雷霆崖"] = "Thunder Bluff"
dict_cn_misc["达纳苏斯"] = "Darnassus"
dict_cn_misc["达纳"] = "Darnassus"
dict_cn_misc["银月城"] = "Silvermoon City"
dict_cn_misc["吉尔尼斯城"] = "Gilneas City"
dict_cn_misc["吉尔尼斯"] = "Gilneas City"
dict_cn_misc["斯通纳德"] = "Stonard"
dict_cn_misc["闪金镇"] = "Goldshire"
dict_cn_misc["藏宝海湾"] = "Booty Bay"
dict_cn_misc["加基森"] = "Gadgetzan"
dict_cn_misc["JJS"] = "Gadgetzan"
dict_cn_misc["东瘟疫之地"] = "Eastern Plaguelands"
dict_cn_misc["EPL"] = "Eastern Plaguelands"
dict_cn_misc["epl"] = "Eastern Plaguelands"
dict_cn_misc["西瘟疫之地"] = "Western Plaguelands"
dict_cn_misc["WPL"] = "Western Plaguelands"
dict_cn_misc["wpl"] = "Western Plaguelands"
dict_cn_misc["希利苏斯"] = "Silithus"
dict_cn_misc["XLSS"] = "Silithus"
dict_cn_misc["冬泉谷"] = "Winterspring"
dict_cn_misc["荆棘谷"] = "Stranglethorn Vale"
dict_cn_misc["JJG"] = "Stranglethorn Vale"
dict_cn_misc["STV"] = "Stranglethorn Vale"
dict_cn_misc["stv"] = "Stranglethorn Vale"
dict_cn_misc["诅咒之地"] = "Blasted Lands"
dict_cn_misc["燃烧平原"] = "Burning Steppes"
dict_cn_misc["黑石山"] = "Blackrock Mountain"
dict_cn_misc["BRM"] = "Blackrock Mountain"
dict_cn_misc["brm"] = "Blackrock Mountain"
dict_cn_misc["灼热峡谷"] = "Searing Gorge"
dict_cn_misc["费伍德森林"] = "Felwood"
dict_cn_misc["月光林地"] = "Moonglade"
dict_cn_misc["奥丹姆"] = "Uldum"
dict_cn_misc["塔纳利斯"] = "Tanaris"
dict_cn_misc["吉利吉姆岛"] = "Gillijim's Isle"
dict_cn_misc["拉皮迪斯岛"] = "Lapidis Isle"
dict_cn_misc["贝勒岛"] = "Balor Isle"
dict_cn_misc["塔拉宾岛"] = "Tel'Abim"
dict_cn_misc["月语海岸"] = "Moonwhisper Coast"
dict_cn_misc["阴森河源"] = "Grim Reaches"
dict_cn_misc["风角峡谷"] = "Wind Horn Canyon"
dict_cn_misc["霜鬃洞穴"] = "Frostmane Hollow"
dict_cn_misc["阿拉萨拉斯"] = "Alah'Thalas"
dict_cn_misc["龙喉避难所"] = "Dragonmaw Reserve"
dict_cn_misc["龙吼要塞"] = "Dragonmaw Retreat"
dict_cn_misc["采石场"] = "Hateforge Quarry"
dict_cn_misc["燃烧平原采石场"] = "Hateforge Quarry"

-- ============================================================================
-- Bosses & Major Named NPCs
-- ============================================================================
dict_cn_misc["大螺丝"] = "Ragnaros"
dict_cn_misc["拉格纳罗斯"] = "Ragnaros"
dict_cn_misc["大螺丝拉格纳罗斯"] = "Ragnaros"
dict_cn_misc["炎魔"] = "Ragnaros"
dict_cn_misc["螺丝"] = "Ragnaros"
dict_cn_misc["大奈法"] = "Nefarian"
dict_cn_misc["奈法"] = "Nefarian"
dict_cn_misc["奈法利安"] = "Nefarian"
dict_cn_misc["奥妮"] = "Onyxia"
dict_cn_misc["奥妮克希亚"] = "Onyxia"
dict_cn_misc["黑龙"] = "Onyxia"
dict_cn_misc["黑龙MM"] = "Onyxia"
dict_cn_misc["黑龙mm"] = "Onyxia"
dict_cn_misc["黑龙妹"] = "Onyxia"
dict_cn_misc["黑龙姐"] = "Onyxia"
dict_cn_misc["克尔苏加德"] = "Kel'Thuzad"
dict_cn_misc["老克"] = "Kel'Thuzad"
dict_cn_misc["KT"] = "Kel'Thuzad"
dict_cn_misc["kt"] = "Kel'Thuzad"
dict_cn_misc["克苏恩"] = "C'Thun"
dict_cn_misc["小克"] = "C'Thun"
dict_cn_misc["眼球"] = "C'Thun"
dict_cn_misc["双子皇帝"] = "Twin Emperors"
dict_cn_misc["双子"] = "Twin Emperors"
dict_cn_misc["维克洛尔"] = "Emperor Vek'lor"
dict_cn_misc["剑皇"] = "Emperor Vek'lor"
dict_cn_misc["维克纳拉什"] = "Emperor Vek'nilash"
dict_cn_misc["魔皇"] = "Emperor Vek'nilash"
dict_cn_misc["哈卡"] = "Hakkar"
dict_cn_misc["血神"] = "Hakkar"
dict_cn_misc["哈卡之子"] = "Son of Hakkar"
dict_cn_misc["冰龙"] = "Sapphiron"
dict_cn_misc["萨菲隆"] = "Sapphiron"
dict_cn_misc["大管家"] = "Majordomo Executus"
dict_cn_misc["管理者埃克索图斯"] = "Majordomo Executus"
dict_cn_misc["拉佐格尔"] = "Razorgore"
dict_cn_misc["狂野的拉佐格尔"] = "Razorgore"
dict_cn_misc["勒什雷尔"] = "Broodlord Lashlayer"
dict_cn_misc["布鲁塔卢斯"] = "Broodlord Lashlayer"
dict_cn_misc["克洛玛古斯"] = "Chromaggus"
dict_cn_misc["佛拉斯"] = "Flamegor"
dict_cn_misc["弗莱格尔"] = "Flamegor"
dict_cn_misc["埃博诺克"] = "Ebonroc"
dict_cn_misc["费尔默"] = "Firemaw"
dict_cn_misc["迦顿男爵"] = "Baron Geddon"
dict_cn_misc["玛格曼达"] = "Magmadar"
dict_cn_misc["加尔"] = "Garr"
dict_cn_misc["基赫纳斯"] = "Gehennas"
dict_cn_misc["卢西弗隆"] = "Lucifron"
dict_cn_misc["奥爆男"] = "Shazzrah"
dict_cn_misc["沙斯拉尔"] = "Shazzrah"
dict_cn_misc["焚化者古雷曼格"] = "Golemagg the Incinerator"
dict_cn_misc["萨弗隆先驱者"] = "Sulfuron Harbinger"
dict_cn_misc["瓦拉斯塔兹"] = "Vaelastrasz"
dict_cn_misc["堕落的瓦拉斯塔兹"] = "Vaelastrasz"
dict_cn_misc["红龙"] = "Vaelastrasz"
dict_cn_misc["门神"] = "Drakonid Guardian (BWL)"
dict_cn_misc["三门神"] = "Death Talon Wyrmguards (BWL)"
dict_cn_misc["教官拉苏维奥斯"] = "Instructor Razuvious"
dict_cn_misc["教官"] = "Instructor Razuvious"
dict_cn_misc["帕奇维克"] = "Patchwerk"
dict_cn_misc["缝合怪"] = "Patchwerk"
dict_cn_misc["缝合者帕奇维克"] = "Patchwerk"
dict_cn_misc["缝补"] = "Patchwerk"
dict_cn_misc["哥特里克"] = "Gothik the Harvester"
dict_cn_misc["洛欧塞布"] = "Loatheb"
dict_cn_misc["格拉斯"] = "Gluth"
dict_cn_misc["格罗布鲁斯"] = "Grobbulus"
dict_cn_misc["塔迪乌斯"] = "Thaddius"
dict_cn_misc["塞奈昂"] = "Thaddius"
dict_cn_misc["瘟疫使者诺斯"] = "Noth the Plaguebringer"
dict_cn_misc["肮脏的希尔盖"] = "Heigan the Unclean"
dict_cn_misc["跳舞"] = "Heigan Dance"
dict_cn_misc["迈克斯纳"] = "Maexxna"
dict_cn_misc["蜘蛛"] = "Maexxna"
dict_cn_misc["阿努布雷坎"] = "Anub'Rekhan"
dict_cn_misc["黑女巫法琳娜"] = "Grand Widow Faerlina"
dict_cn_misc["4DK"] = "Four Horsemen"
dict_cn_misc["四DK"] = "Four Horsemen"
dict_cn_misc["四骑士"] = "Four Horsemen"
dict_cn_misc["天启四骑士"] = "Four Horsemen"
dict_cn_misc["大十字军战士莫格莱尼"] = "Highlord Mograine"
dict_cn_misc["瑞文戴尔男爵"] = "Baron Rivendare"
dict_cn_misc["巴尔扎尔"] = "Balnazzar"
dict_cn_misc["沙尔图拉"] = "Battleguard Sartura"
dict_cn_misc["维希度斯"] = "Viscidus"
dict_cn_misc["范克瑞斯"] = "Fankriss the Unyielding"
dict_cn_misc["哈霍兰公主"] = "Princess Huhuran"
dict_cn_misc["奥罗"] = "Ouro"
dict_cn_misc["预言者斯克拉姆"] = "The Prophet Skeram"
dict_cn_misc["绿龙"] = "Dragons of Nightmare"
dict_cn_misc["艾索雷葛斯"] = "Azuregos"
dict_cn_misc["蓝龙"] = "Azuregos"
dict_cn_misc["卡扎克"] = "Kazzak"
dict_cn_misc["桑德兰"] = "Prince Thunderaan"
dict_cn_misc["逐风者桑德兰"] = "Thunderaan the Windseeker"
dict_cn_misc["逐风者的禁锢之颅"] = "Bindings of the Windseeker"
dict_cn_misc["高阶祭司"] = "High Priest"
dict_cn_misc["虎神"] = "High Priest Thekal (ZG)"
dict_cn_misc["蛇神"] = "High Priest Venoxis (ZG)"
dict_cn_misc["蜘蛛神"] = "High Priestess Mar'li (ZG)"
dict_cn_misc["蝙蝠神"] = "High Priestess Jeklik (ZG)"
dict_cn_misc["豹神"] = "High Priestess Arlokk (ZG)"
dict_cn_misc["鹰神"] = "Arlokk (ZG)"
dict_cn_misc["金度"] = "Jin'do the Hexxer"
dict_cn_misc["祖姆拉什"] = "Jin'do the Hexxer"
dict_cn_misc["蝙蝠前锋"] = "Bat Rider (ZG)"
dict_cn_misc["狗男女"] = "Romulo and Julianne"
dict_cn_misc["奥兹塔里亚斯"] = "Ostarius"
dict_cn_misc["丹基塔斯"] = "Dun Kithas"
dict_cn_misc["克拉柯拉"] = "Cla'ckora"
dict_cn_misc["雷格尔领主"] = "Lord Rygel"
dict_cn_misc["蛙王"] = "Lord Rygel (Frog King)"
dict_cn_misc["乌尔杜姆石板"] = "Plates of Uldum"
dict_cn_misc["神秘的陌生人"] = "Mysterious Stranger"
dict_cn_misc["霍格"]         = "Hogger"
dict_cn_misc["迪菲亚监工"]   = "Defias Overseer"
dict_cn_misc["迪菲亚路霸"]   = "Defias Highwayman"
dict_cn_misc["阿鲁高之子"]   = "Son of Arugal"
dict_cn_misc["莫高雷潜行者"] = "Mulgore Prowler"

-- ============================================================================
-- Miscellanous System Expressions
-- ============================================================================
dict_cn_misc["或者"] = "or"
dict_cn_misc["大地的裂变"] = "Cataclysm"
dict_cn_misc["熊猫人之谜"] = "Mists of Pandaria"
dict_cn_misc["暗影国度"] = "Shadowlands"
dict_cn_misc["地心之战"] = "The War Within"
dict_cn_misc["巨龙时代"] = "Dragonflight"
dict_cn_misc["巫妖王之怒"] = "Wrath of the Lich King"
dict_cn_misc["德拉诺之王"] = "Warlords of Draenor"
dict_cn_misc["燃烧的远征"] = "The Burning Crusade"
dict_cn_misc["正式服"] = "retail / live server"
dict_cn_misc["怀旧服"] = "Classic / Vanilla server"
dict_cn_misc["时光服"] = "Season of Discovery"
dict_cn_misc["NGA"] = "NGA forum"
dict_cn_misc["艾泽拉斯国家地理"] = "NGA forum"
dict_cn_misc["我卡了"] = "I have lag"
dict_cn_misc["掉线"] = "DC (disconnected)"
dict_cn_misc["举报"] = "report"
dict_cn_misc["外挂"] = "cheat/hack"
dict_cn_misc["脚本"] = "bot script"
dict_cn_misc["插件"] = "addon"
dict_cn_misc["客服"] = "GM/support"
dict_cn_misc["城春草木深"] = "City Spring"
dict_cn_misc["明亮梦境碎片"] = "Bright Dream Shard"
dict_cn_misc["普通模式"] = "Normal Mode"
dict_cn_misc["艾萨拉"] = "Azshara"
dict_cn_misc["血色领地"] = "Scarlet Enclave"
dict_cn_misc["黑名单"] = "ignore list"
dict_cn_misc["拉黑"] = "add to ignore"
dict_cn_misc["人品"] = "luck"
dict_cn_misc["人民币玩家"] = "pay-to-win player"
dict_cn_misc["RMB党"] = "pay-to-win player"
dict_cn_misc["指挥"] = "raid leader"
dict_cn_misc["团长"] = "raid leader"
dict_cn_misc["RL"] = "raid leader"
```

## api/dict_cn_phrases.lua
```lua
-- dict_cn_phrases.lua
-- Chinese (Simplified) → English PHRASE rules (ordered, applied before misc)
-- Ported from TranslateCN by Gangasrotogati
-- Format: { cn = "<pattern>", en = "<replacement>" }
-- Patterns are Lua string patterns (% escapes special chars).

dict_cn_phrases = {
    -- ============================================================================
    -- CRITICAL: Dungeon & Custom Zone Phrasing (Must be evaluated first!)
    -- ============================================================================
    { cn = "诺莫瑞根任务队", en = "Gnomeregan quest group " },
    { cn = "监狱任务队",     en = "Stockades quest group " },
    { cn = "霜鬃谷任务队",   en = "Frostmane Hollow quest group " },
    { cn = "新月来人",       en = "Crescent Grove LFG" },
    { cn = "小树林来TND",      en = "Crescent Grove need Tank, Healer, DPS " },
    { cn = "小树林",           en = "Crescent Grove " },
    { cn = "翡翠圣地开团",   en = "Forming Emerald Sanctum" },
    { cn = "仇恨熔炉速刷",   en = "Hateforge Quarry speedrun" },
    { cn = "死矿任务(%d)=(%d)", en = "Deadmines quest LFM (Need %2 more) " },
    { cn = "死矿任务队",     en = "Deadmines quest group " },
    { cn = "剃刀高地来人", en = "Razorfen Downs LFM, " },
    { cn = "新月小树林任务队", en = "Crescent Grove quest group " },
    { cn = "诺莫瑞根任务队",   en = "Gnomeregan quest group " },
    { cn = "监狱任务队",       en = "Stockades quest group " },
    { cn = "霜鬃谷任务队",     en = "Frostmane Hollow quest group " },
    { cn = "死矿任务队",       en = "Deadmines quest group " },
    { cn = "祖尔",           en = "ZF " },
    { cn = "来[nN]和[dD]",   en = "need Healer and DPS " },
    { cn = "来[tT]和[nN]",   en = "need Tank and Healer " },
    { cn = "来[tT]和[dD]",   en = "need Tank and DPS " },
    { cn = "有锤子",         en = "ZF Hammer ready " },
    { cn = "龙吼任务队",       en = "Dragonmaw Retreat quest group " },
    { cn = "龙吼",             en = "Dragonmaw Retreat " },
    { cn = "黑上全通",       en = "UBRS full run " },
    { cn = "许愿%+1",        en = "SR+1 " }, -- Note the '%' to escape the magic '+' character
{ cn = "新月小树林", en = "Crescent Grove" },  -- already have it but no "CG" abbreviation guard
{ cn = "霜鬃", en = "Frostmane Hollow" },       -- FH not covered
{ cn = "仇恨采石场", en = "Hateforge Quarry" }, -- HQ not covered

    -- ============================================================================
    -- Open-World Elite Quests & Hinterlands Specifics
    -- ============================================================================
    { cn = "辛特兰",         en = "Hinterlands " },
    { cn = "辛特兰JY",         en = "Hinterlands Elite quests " },
    { cn = "JY任务",         en = "Elite quests " },
    { cn = "来的[mM]",       en = "PST to join " },
    { cn = "另收",           en = "Also buying " },

    -- ============================================================================
    -- LFG Question Formats & Spacing Fixes
    -- ============================================================================
    { cn = "有没有死矿队伍啊", en = "Any Deadmines group? " },
    { cn = "有没有死矿队伍",   en = "Any Deadmines group " },
    
    -- Universal question fallbacks (handles any dungeon variant)
    { cn = "有没有",           en = "Any " },
    { cn = "队伍啊",           en = "group? " },
    { cn = "队伍",             en = "group " },

    -- ============================================================================
    -- Standalone English / Number Guard Rules (Protects words from corruption)
    -- ============================================================================
    { cn = "%f[%a][eE][sS]%f[%A]", en = "Emerald Sanctum" }, -- Only matches standalone "es" / "ES"
    { cn = "%f[%a][tT]%f[%A]",     en = "Tank" },            -- Only matches standalone "t" / "T"
    { cn = "%f[%a][nN]%f[%A]",     en = "Healer" },          -- Only matches standalone "n" / "N"
    { cn = "%f[%a][gG]%f[%A]",     en = "Gold" },            -- Only matches standalone "g" / "G"
    { cn = "(%d+)[gG]%f[%W]",      en = "%1 Gold" },         -- Formats gold safely (e.g., 20g -> 20 Gold)
    { cn = "%f[%a][aA][hH]%f[%A]", en = "WC" },              -- Only swaps "AH" if it's a standalone group tag
    { cn = "%f[%w]6%f[%W]",        en = "nice" },            -- Matches standalone "6", leaves "60+" perfectly safe
    { cn = "%f[%a][nN][dD]%f[%A]", en = "Resto Druid" },     -- Only matches standalone "nd" / "ND"
    { cn = "%f[%a][sS][tT]%f[%A]", en = "Sunken Temple " },  -- Only matches standalone "st" / "ST"

    -- ============================================================================
    -- Air-Tight Standalone Guard Rules (Protects system text and English sentences)
    -- ============================================================================
    { cn = "%f[%a][sS][sS]%f[%A]", en = "Warlock" },
    { cn = "%f[%a][sS][mM]%f[%A]", en = "Shaman" },
    { cn = "%f[%a][aA][mM]%f[%A]", en = "Shadow Priest" },
    { cn = "%f[%a][nN][dD]%f[%A]", en = "Resto Druid" },
    { cn = "%f[%a][hH][cC]%f[%A]", en = "Hardcore" },
    { cn = "%f[%a][eE][yY]%f[%A]", en = "Dire Maul" },
    { cn = "%f[%a][iI][fF]%f[%A]", en = "Ironforge" },
    { cn = "%f[%a][mM][cC]%f[%A]", en = "Molten Core" },
    { cn = "%f[%a][aA][bB]%f[%A]", en = "Arathi Basin" },
    { cn = "%f[%a][aA][vV]%f[%A]", en = "Alterac Valley" },
    { cn = "%f[%a][sS][wW]%f[%A]", en = "Stormwind" },
    { cn = "%f[%a][uU][cC]%f[%A]", en = "Undercity" },
    { cn = "%f[%a][oO][rR][gG]%f[%A]", en = "Orgrimmar" },
    { cn = "%f[%a][tT][lL]%f[%A]", en = "Scholomance" },
    { cn = "%f[%a][yY][sS]%f[%A]", en = "need water" },
    { cn = "%f[%a][fF][sS]%f[%A]", en = "Mage" },
    { cn = "%f[%a][lL][rR]%f[%A]", en = "Hunter" },
    { cn = "%f[%a][mM][nN]%f[%A]", en = "Main Healer" },   -- standalone "mn"/"MN" only
    { cn = "%f[%a][fF][nN]%f[%A]", en = "Off Healer" },    -- standalone "fn"/"FN" only
    { cn = "%f[%a][dD][dD]%f[%A]", en = "DPS" },           -- standalone "dd"/"DD" only
    { cn = "%f[%a][oO][kK]%f[%A]", en = "OK" },            -- standalone "ok"/"OK" only

    -- ============================================================================
    -- Advanced LFG Role Combos & Verbs
    -- ============================================================================
    { cn = "来[nN]%s?=%s?(%d+)", en = "LF%1M Healer " },
    { cn = "来[tT]%s?=%s?(%d+)", en = "LF%1M Tank " },
    { cn = "来[dD][pP][sS]%s?=%s?(%d+)", en = "LF%1M DPS " },
    { cn = "来[mM][sS]%s?=%s?(%d+)", en = "LF%1M Healer " }, -- Catching shorthand 'MS' (Priest/Healer)
    { cn = "需来个DPS或者奶", en = "need DPS or healer" },
    { cn = "需来个T或者奶",   en = "need tank or healer" },
    { cn = "需来个T",         en = "need a tank" },
    { cn = "需来个N",         en = "need a healer" },
    { cn = "需来个奶",        en = "need a healer" },
    { cn = "需来个DPS",       en = "need a DPS" },
    { cn = "有没有T来",       en = "any tanks for" },
    { cn = "有没有N来",       en = "any healers for" },
    { cn = "来个T或者N",      en = "need tank or healer" },
    { cn = "T或者N",          en = "tank or healer" },
    { cn = "来T%s?N",         en = "need Tank or Healer " },
    { cn = "来个T%s?N",       en = "need Tank or Healer " },
    { cn = "来点DPS",         en = "need some DPS" },
    { cn = "来个能拉人的",    en = "need someone who can summon" },
    { cn = "有没有大佬带",    en = "any pros to carry me?" },
    { cn = "来(%d)个",        en = "need %1 more" },
    { cn = "来T来奶",        en = "need Tank and Healer " },
    { cn = "来奶",           en = "need healer " },
    { cn = "来[tT]%s?[nN]", en = "need Tank and Healer " },
    { cn = "来[nN]%s?[tT]", en = "need Healer and Tank " },
    { cn = "%f[%a][tT][nN]%f[%A]", en = "Tank/Healer" },
    { cn = "来[tT][dD][nN]",   en = "need Tank, DPS, Healer " },
    { cn = "来[tT][nN][dD]",   en = "need Tank, Healer, DPS " },
    { cn = "任务队",           en = "quest group " },
    { cn = "来[dD]%s+[nN]",   en = "need DPS and Healer " },
    { cn = "来[tT]%s+[nN]%s?=%s?(%d+)", en = "LF%1M (Tank + Healer) " },
    { cn = "来[nN]%s+[tT]%s?=%s?(%d+)", en = "LF%1M (Healer + Tank) " },
    { cn = "来[dD]%s+[nN]%s?=%s?(%d+)", en = "LF%1M (DPS + Healer) " },
    { cn = "3BB护驾",          en = "3 party spots open " },
 
    -- ============================================================================
    -- Base LFG Role Requests
    -- ============================================================================
    { cn = "需要T",        en = "need tank" },
    { cn = "需要N",        en = "need healer" },
    { cn = "需要DPS",      en = "need dps" },
    { cn = "来个N",        en = "need a healer" },
    { cn = "来个T",        en = "need a tank" },
    { cn = "来个DPS",      en = "need a DPS" },
    { cn = "来个奶",       en = "need a healer" },
    { cn = "来[nN]",         en = "need Healer " },
    { cn = "来[tT]",         en = "need Tank " },
    { cn = "来[dD][pP][sS]", en = "need DPS " },
    { cn = "强力T",       en = "strong Tank" },
    { cn = "强力N",       en = "strong Healer" },
    { cn = "强力奶",      en = "strong Healer" },
    { cn = "来的[mM]+",        en = "PST " },
    { cn = "全通",           en = "full run " },
{ cn = "拉人", en = "summoning" },
{ cn = "没有传送", en = "no warlock for summon" },{ cn = "缺奶", en = "need healer" },
{ cn = "缺T", en = "need tank" },
{ cn = "缺DPS", en = "need DPS" },
{ cn = "奶满了", en = "healers full" },
{ cn = "T满了", en = "tanks full" },
{ cn = "满员了", en = "group full" },
{ cn = "已满", en = "full" },
{ cn = "消费团", en = "GDKP run" },   -- already in phrases but missing from misc
{ cn = "点数团", en = "DKP run" },
{ cn = "SR", en = "Soft Reserve" },
{ cn = "软保", en = "Soft Reserve" },
{ cn = "硬保", en = "Hard Reserve" },
{ cn = "许愿", en = "Soft Reserve" }, -- you have SR+1 but not the base term


    -- ============================================================================
    -- High-Level & Inferno Progression Farming Callouts
    -- ============================================================================
    { cn = "黑下宝钻",       en = "LBRS Diamond farm " },
    { cn = "刷装备",         en = "gear farm " },
    { cn = "炼狱饰品",       en = "Inferno trinket " },
    { cn = "第一步",         en = "step 1 " },
    { cn = "打信",           en = "farming quest drop " },
    { cn = "已开工",         en = "run in progress " },
    { cn = "能拉",           en = "can summon " },
    { cn = "可以拉",         en = "can summon " },
    { cn = "55%+即可",       en = "lvl 55+ welcome " },
{ cn = "HC队", en = "HC group" },
{ cn = "HC专用", en = "HC only" },
{ cn = "非HC勿扰", en = "HC players only, please" },
{ cn = "HC新手", en = "HC newbie" },

    -- ============================================================================
    -- Homophone & Slang Dungeon Fixes (Fixes "Noob Market" typo)
    -- ============================================================================
    { cn = "新月小树林",       en = "Crescent Grove " },
    { cn = "菜市场",         en = "Hateforge Quarry " }, -- Catches the caishichang typo for 采石场
    { cn = "NY任务队",       en = "RFC quest group " },  -- Stops NY from squishing into text
    { cn = "外围也做",       en = "doing outer quests too " },
    { cn = "YY任务队",       en = "SFK quest group " },
    { cn = "强T带队",       en = "strong Tank leading group " },
    { cn = "各种",           en = "all roles " },
    { cn = "新月小树林任务队", en = "Crescent Grove quest group " },
    { cn = "血色外围任务来人", en = "SM outer quests LFM, " },
    { cn = "血色外围任务",     en = "SM outer quests " },
    { cn = "外围任务",         en = "outer quests " },
    { cn = "一起",             en = "together " },

    -- ============================================================================
    -- Punctuation Role Combos & Better Level Scaling
    -- ============================================================================
    { cn = "来[tT]%.[dD]",   en = "need Tank and DPS " }, -- Catches punctuated "T.D" styles cleanly
    { cn = "来(%d+)%+",      en = "need lvl %1+ " },      -- Converts "来52+" into "need lvl 52+" instead of "to 52+"

    -- ============================================================================
    -- Profession Material & Trade Phrasing (Fixes "Middle-Skinned People")
    -- ============================================================================
    { cn = "收中皮",         en = "WTB Medium Leather " },
    { cn = "一组",           en = "1 stack " },
    { cn = "人在幽暗",       en = "currently in Undercity " },
{ cn = "收材料", en = "WTB mats" },
{ cn = "卖装备", en = "WTS gear" },
{ cn = "收装备", en = "WTB gear" },
{ cn = "出售", en = "WTS" },
{ cn = "收购", en = "WTB" },
{ cn = "私聊", en = "PST" },
{ cn = "低价出", en = "selling cheap" },
{ cn = "高价收", en = "buying at good price" },
{ cn = "议价", en = "price negotiable" },

    -- ============================================================================
    -- Original Base Phrases & Movements
    -- ============================================================================
    { cn = "来的组我",     en = "group with me" },
    { cn = "一起刷",       en = "run together" },
    { cn = "组队",         en = "group up" },
    { cn = "新建公会",     en = "New guild" },
    { cn = "其他也欢迎",   en = "others welcome" },
    { cn = "G团",          en = "GDKP" },
    { cn = "消费团",       en = "GDKP run" },
    { cn = "晚7%-11",      en = "7 to 11 pm" },
    { cn = "晚7",          en = "7 pm" },
    { cn = "绝不加班",     en = "no overtime" },
    { cn = "我吃饱了",     en = "I'm full" },
    { cn = "或者",         en = "or" },
    { cn = "号",           en = "" },
{ cn = "晚8", en = "8 pm" },
{ cn = "晚9", en = "9 pm" },
{ cn = "晚10", en = "10 pm" },
{ cn = "下午", en = "afternoon" },
{ cn = "明天", en = "tomorrow" },
{ cn = "今晚", en = "tonight" },
{ cn = "周末", en = "this weekend" },

    -- ============================================================================
    -- Tactical & Combat Callouts
    -- ============================================================================
    { cn = "全力输出",     en = "full DPS" },
    { cn = "全灭",         en = "wipe" },
    { cn = "推倒",         en = "boss down" },
{ cn = "战士T", en = "Warrior tank" },
{ cn = "圣骑T", en = "Paladin tank" },
{ cn = "德鲁伊T", en = "Druid tank" },
{ cn = "牧师奶", en = "Priest healer" },
{ cn = "萨满奶", en = "Shaman healer" },
{ cn = "德鲁伊奶", en = "Druid healer" },


    -- ============================================================================
    -- General Social Status / Group Coordination
    -- ============================================================================
    { cn = "有没有人",     en = "anyone want to" },
    { cn = "带我",         en = "carry me" },
    { cn = "有位置吗",     en = "any spots open?" },
    { cn = "还缺人吗",     en = "still need people?" },
    { cn = "等人",         en = "waiting for people" },

    -- ============================================================================
    -- Loot Contexts & Trade
    -- ============================================================================
    { cn = "需要还是贪婪", en = "need or greed" },
    { cn = "可以需要",     en = "you can need it" },
    { cn = "别需要",       en = "don't need it" },
    { cn = "这是我的",     en = "that's mine" },
    { cn = "你先要",       en = "you take it" },
    { cn = "给我",         en = "give it to me" },
    { cn = "卖多少",       en = "how much?" },
    { cn = "多少金",       en = "how much gold?" },
    { cn = "可以便宜吗",   en = "can you go cheaper?" },
    { cn = "不卖",         en = "not for sale" },

    -- ============================================================================
    -- Social Reactions & Greetings
    -- ============================================================================
    { cn = "干得好",       en = "good job" },
    { cn = "打得好",       en = "well played" },
    { cn = "真厉害",       en = "impressive" },
    { cn = "新手",         en = "newbie" },
    { cn = "大佬",         en = "pro player" },
    { cn = "带我飞",       en = "carry me" },
    { cn = "没关系",       en = "it's fine" },
    { cn = "没事",         en = "no worries" },
    { cn = "我知道了",     en = "I understand" },
    { cn = "不知道",       en = "I don't know" },
    { cn = "你好",         en = "hello" },
    { cn = "再见",         en = "goodbye" },
    { cn = "晚安",         en = "good night" },
    { cn = "早上好",       en = "good morning" },

    -- ============================================================================
    -- Lockouts & Group Sizing Metrics
    -- ============================================================================
    { cn = "全程带",       en = "full carry" },
    { cn = "带飞",         en = "carry run" },
    { cn = "自己有本",     en = "have lockout" },
    { cn = "没有本",       en = "no lockout" },
    { cn = "没本",         en = "no lockout" },
    { cn = "满5",          en = "full 5/5" },
    { cn = "缺(%d)",       en = "need %1 more" },

    -- ============================================================================
    -- Hardcore Survival Warnings
    -- ============================================================================
    { cn = "HC模式注意安全", en = "HC mode, play safe" },
    { cn = "别引怪会害死人", en = "Don't ninja pull, you'll kill us" },
    { cn = "求稳不要求快",   en = "Safety first, don't rush" },
    { cn = "珠宝大师",       en = "Zhubao (Master Crafter) " },
    { cn = "珠宝商人",       en = "Zhubao (Merchant) " },
    { cn = "一个珠宝",       en = "one Zhubao " },
    { cn = "少了一个珠宝",   en = "one less Zhubao " },

    -- ============================================================================
    -- Economy & Strategic Warnings
    -- ============================================================================
    { cn = "免费代工",     en = "Free crafting (your mats)" },
    { cn = "自带材料",     en = "Bring your own mats" },
    { cn = "代工做极品",   en = "Crafting high tier gear" },
}
```

## api/gui_schema.lua
```lua
-- DBB2 GUI Schema
-- Unified UI component system with consistent layout constants
-- All panels (Logs, Groups, Professions, Hardcore) use the same patterns

-- Note: This file uses global string/math functions directly rather than localized versions
-- because the functions are called infrequently (UI setup, not per-frame)

-- =====================
-- CONSTANT DOMAINS
-- =====================
-- Static config panel constants (widget spacing, font sizes) are in env/constants.lua
-- as DBB2.env.SPACING and DBB2.env.FONT_SIZE - used by config_schema.lua and config_widgets.lua
--
-- This file (gui_schema.lua) contains dynamic layout constants computed with DBB2:ScaleSize()
-- as DBB2.schema.* - used by the main GUI (message rows, scroll frames, tabs)
--
-- The two domains are intentionally separate:
--   DBB2.env    -> Config panels (settings UI)
--   DBB2.schema -> Main GUI (message display, tabs, scrolling)

-- =====================
-- LAYOUT CONSTANTS
-- =====================
-- Single source of truth for all spacing and sizing values

DBB2.schema = DBB2.schema or {}

--- Initialize layout constants for the GUI schema system.
-- Must be called after config is loaded to ensure proper scaling.
-- Sets up all spacing, sizing, and layout constants used by UI components.
-- @return nil
function DBB2.schema.InitLayout()
  local S = DBB2.schema
  
  -- Scrollbar and padding
  S.SCROLLBAR_WIDTH = DBB2:ScaleSize(7)
  S.SCROLLBAR_PADDING = DBB2:ScaleSize(6)
  S.SCROLLBAR_SPACE = S.SCROLLBAR_WIDTH + S.SCROLLBAR_PADDING  -- Total space for scrollbar
  
  -- Row layout
  S.ROW_HEIGHT = DBB2:ScaleSize(16)
  S.ROW_LEFT_PADDING = 5
  S.ROW_RIGHT_PADDING = 0  -- Row extends to container edge (container handles scrollbar space)
  
  -- Character name column
  S.CHARNAME_WIDTH = DBB2:ScaleSize(80)
  S.CHARNAME_OFFSET = DBB2:ScaleSize(85)  -- Where message starts (after charname)
  
  -- Timestamp column (default: HH:MM:SS, left-aligned)
  S.TIMESTAMP_WIDTH = DBB2:ScaleSize(55)
  S.TIMESTAMP_RIGHT_OFFSET = 5
  
  -- Timestamp column (Relative mode: right-aligned, dynamic width)
  S.TIMESTAMP_WIDTH_RELATIVE = DBB2:ScaleSize(22)
  S.TIMESTAMP_WIDTH_RELATIVE_CALC = DBB2:ScaleSize(20)
  S.TIMESTAMP_RIGHT_OFFSET_RELATIVE = -3
  
  -- Timestamp column (Elapsed mode: left-aligned, fixed MM:SS)
  S.TIMESTAMP_WIDTH_ELAPSED = DBB2:ScaleSize(38)
  S.TIMESTAMP_RIGHT_OFFSET_ELAPSED = 6
  S.TIMESTAMP_ELAPSED_GAP = 5
  
  -- Filter bar
  S.FILTER_HEIGHT = DBB2:ScaleSize(22)
  S.FILTER_PADDING = DBB2:ScaleSize(5)
  
  -- Category header (for categorized panels)
  S.CATEGORY_HEADER_HEIGHT = DBB2:ScaleSize(22)
  S.CATEGORY_SPACING = DBB2:ScaleSize(5)
  
  -- GUI frame padding
  S.GUI_PADDING = DBB2:ScaleSize(7)
  S.CONTENT_PADDING = 2
  
  -- Calculate derived values
  S.TIME_COLUMN_WIDTH = S.TIMESTAMP_WIDTH + S.SCROLLBAR_SPACE
end

-- =====================
-- TIME FORMAT HELPERS
-- =====================

--- Get the timestamp right offset for the current time display mode.
-- @return (number) The right offset value
function DBB2.schema.GetTimestampOffset()
  local S = DBB2.schema
  if DBB2_Config.timeDisplayMode == 1 then
    return S.TIMESTAMP_RIGHT_OFFSET_RELATIVE
  elseif DBB2_Config.timeDisplayMode == 2 then
    return S.TIMESTAMP_RIGHT_OFFSET_ELAPSED
  else
    return S.TIMESTAMP_RIGHT_OFFSET
  end
end

--- Calculate the effective timestamp column width for available-width math.
-- For Relative mode, uses actual rendered text width; for others, uses fixed constants.
-- @param timeFont (FontString) The time font string to measure
-- @return (number) The effective timestamp width including gap
function DBB2.schema.GetTimestampWidth(timeFont)
  local S = DBB2.schema
  if DBB2_Config.timeDisplayMode == 1 then
    return (timeFont:GetStringWidth() or S.TIMESTAMP_WIDTH_RELATIVE_CALC) + DBB2:ScaleSize(11)
  elseif DBB2_Config.timeDisplayMode == 2 then
    return (timeFont:GetStringWidth() or S.TIMESTAMP_WIDTH_ELAPSED) + S.TIMESTAMP_ELAPSED_GAP
  else
    return S.TIMESTAMP_WIDTH
  end
end

--- Calculate the available width for message text in a row.
-- @param timeFont (FontString) The time font string to measure
-- @return (number) Available pixel width for the message, or 0 if not calculable
function DBB2.schema.CalcMessageWidth(timeFont)
  local S = DBB2.schema
  if not DBB2.gui then return 0 end
  local guiWidth = DBB2.gui:GetWidth()
  if not guiWidth or guiWidth <= 0 then return 0 end
  
  local scrollWidth = guiWidth - (S.GUI_PADDING * 2) - (S.CONTENT_PADDING * 2)
  local rowWidth = scrollWidth - S.ROW_LEFT_PADDING - S.SCROLLBAR_SPACE
  return rowWidth - S.CHARNAME_OFFSET - S.GetTimestampWidth(timeFont) - S.GetTimestampOffset()
end

--- Truncate message text to fit within available width, adding ellipsis.
-- Sets the font string text and messageBtn width. Returns true if truncated.
-- @param row (Frame) The message row frame
-- @param availableWidth (number) Available pixel width
-- Returns the byte length of the UTF-8 character starting at position i in str.
-- Handles 1-byte (ASCII), 2-byte, 3-byte (CJK), and 4-byte sequences.
local function UTF8CharLen(str, i)
  local b = string.byte(str, i)
  if not b then return 1 end
  if b < 128 then return 1
  elseif b < 192 then return 1  -- continuation byte (shouldn't start here)
  elseif b < 224 then return 2
  elseif b < 240 then return 3
  else return 4
  end
end

-- Advance pos forward by one complete UTF-8 character.
local function UTF8NextCharPos(str, pos)
  return pos + UTF8CharLen(str, pos)
end

function DBB2.schema.TruncateMessage(row, availableWidth)
  row.message:SetWidth(availableWidth)
  row.messageBtn:SetWidth(availableWidth)
  row.message:SetText(row._fullMessage)
  row._isTruncated = false

  local fullMsg = row._fullMessage
  local msgLen  = string.len(fullMsg)

  if row.message:GetStringWidth() > availableWidth and msgLen > 3 then
    -- Build a table of valid UTF-8 character boundary byte positions.
    -- This ensures binary search never splits a multi-byte CJK sequence.
    local boundaries = {}
    local pos = 1
    while pos <= msgLen do
      table.insert(boundaries, pos)
      pos = UTF8NextCharPos(fullMsg, pos)
    end

    -- Binary search over character boundaries (not raw bytes).
    local lo, hi = 1, table.getn(boundaries)
    -- Clamp lo to at least the 3rd character boundary if available.
    if lo < 3 and table.getn(boundaries) >= 3 then lo = 3 end

    while lo < hi do
      local mid = math.floor((lo + hi + 1) / 2)
      local byteEnd = boundaries[mid] - 1
      local candidate = string.sub(fullMsg, 1, byteEnd)
      candidate = string.gsub(candidate, "%s+$", "")
      row.message:SetText(candidate .. "\226\128\166")
      if row.message:GetStringWidth() <= availableWidth then
        lo = mid
      else
        hi = mid - 1
      end
    end

    local byteEnd  = boundaries[lo] - 1
    local truncated = string.sub(fullMsg, 1, byteEnd)
    truncated = string.gsub(truncated, "%s+$", "")
    row.message:SetText(truncated .. "\226\128\166")
    row._isTruncated = true
  end
end

-- =====================
-- SCROLL FRAME
-- =====================

--- Create a scrollable frame with a vertical scrollbar.
-- The scroll frame includes mouse wheel support and automatic thumb sizing.
-- @param name (string) Unique name for the scroll frame
-- @param parent (Frame) Parent frame to attach the scroll frame to
-- @return (ScrollFrame) The created scroll frame with the following methods:
--   - GetCalculatedScrollRange(): Returns the calculated scroll range
--   - UpdateScrollState(): Updates scrollbar visibility and thumb size
--   - Scroll(step): Scrolls by the specified amount
function DBB2.schema.CreateScrollFrame(name, parent)
  local S = DBB2.schema
  local f = CreateFrame("ScrollFrame", name, parent)

  -- Create slider
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetWidth(S.SCROLLBAR_WIDTH)
  f.slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
  f.slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
  
  -- Required for draggable slider in WoW 1.12.1
  f.slider:EnableMouse(1)
  f.slider:SetValueStep(1)
  f.slider:SetMinMaxValues(0, 0)
  f.slider:SetValue(0)
  
  -- Thumb texture
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetWidth(S.SCROLLBAR_WIDTH)
  f.slider.thumb:SetHeight(DBB2:ScaleSize(50))
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.slider.thumb:SetTexture(hr, hg, hb, 0.5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
  end)
  
  -- Calculate scroll range from scroll child
  f.GetCalculatedScrollRange = function()
    local frameHeight = f:GetHeight() or 0
    local calcRange = 0
    if f.scrollChild and frameHeight > 0 then
      local childHeight = f.scrollChild:GetHeight() or 0
      calcRange = math.max(0, childHeight - frameHeight)
    end
    return calcRange
  end

  f.UpdateScrollState = function()
    local frameHeight = f:GetHeight()
    if frameHeight and frameHeight > 0 then
      local scrollRange = f.GetCalculatedScrollRange()
      f.slider:SetMinMaxValues(0, scrollRange)
      f.slider:SetValue(f:GetVerticalScroll())

      if scrollRange <= 1 then
        f.slider:Hide()
      else
        local m = frameHeight + scrollRange
        local ratio = frameHeight / m
        local size = math.floor(frameHeight * ratio)
        f.slider.thumb:SetHeight(math.max(size, DBB2:ScaleSize(20)))
        f.slider:Show()
      end
    end
  end

  f.Scroll = function(self, step)
    step = step or 0
    local current = f:GetVerticalScroll()
    local max = f.GetCalculatedScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll(max)
    elseif new <= 0 then
      f:SetVerticalScroll(0)
    else
      f:SetVerticalScroll(new)
    end
    f.UpdateScrollState()
  end

  f:EnableMouseWheel(1)
  f:SetScript("OnMouseWheel", function()
    local scrollSpeed = DBB2_Config.scrollSpeed or 20
    f:Scroll(arg1 * scrollSpeed)
  end)
  
  f._needsScrollUpdate = false
  f:SetScript("OnUpdate", function()
    if this._needsScrollUpdate then
      this._needsScrollUpdate = false
      this.UpdateScrollState()
    end
  end)

  return f
end

-- =====================
-- SCROLL CHILD
-- =====================

--- Create a scroll child frame to hold scrollable content.
-- The scroll child is automatically attached to the parent scroll frame.
-- @param name (string) Unique name for the scroll child frame
-- @param parent (ScrollFrame) Parent scroll frame created by CreateScrollFrame
-- @return (Frame) The created scroll child frame
function DBB2.schema.CreateScrollChild(name, parent)
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(1)
  f:SetHeight(1)
  parent:SetScrollChild(f)
  parent.scrollChild = f
  return f
end

-- =====================
-- MESSAGE CONTAINER
-- =====================

--- Create a container frame for message rows.
-- Used by both Logs and categorized panels (Groups, Professions, Hardcore).
-- Handles scrollbar space consistently by adjusting container width.
-- @param name (string) Unique name for the container frame
-- @param parent (Frame) Parent frame to attach the container to
-- @param scrollFrame (ScrollFrame) Associated scroll frame for width calculations
-- @return (Frame) The created container frame with the following methods:
--   - UpdateWidth(): Updates container width based on scroll frame dimensions
function DBB2.schema.CreateMessageContainer(name, parent, scrollFrame)
  local S = DBB2.schema
  local f = CreateFrame("Frame", name, parent)
  
  -- Container width = scroll frame width - scrollbar space
  -- This is set dynamically in UpdateContainerWidth
  f.scrollFrame = scrollFrame
  
  f.UpdateWidth = function(self)
    local sfLeft = self.scrollFrame:GetLeft()
    local sfRight = self.scrollFrame:GetRight()
    if sfLeft and sfRight and sfRight > sfLeft then
      self:SetWidth(sfRight - sfLeft - S.SCROLLBAR_SPACE)
      return true
    end
    return false
  end
  
  return f
end

-- =====================
-- MESSAGE ROW
-- =====================

--- Create a message row for displaying chat messages.
-- Each row contains a clickable character name, message text, and timestamp.
-- Supports truncation with tooltip for long messages.
-- @param name (string) Unique name for the row frame
-- @param parent (Frame) Parent frame to attach the row to
-- @return (Frame) The created message row with the following methods:
--   - SetData(sender, message, timeStr, classColor): Sets the row data
-- @usage
--   local row = DBB2.schema.CreateMessageRow("MyRow", parent)
--   row:SetData("PlayerName", "Looking for group!", "12:34", "|cff00ff00")
function DBB2.schema.CreateMessageRow(name, parent)
  local S = DBB2.schema
  
  local row = CreateFrame("Frame", name, parent)
  row:SetHeight(S.ROW_HEIGHT)
  
  -- Character name button (clickable)
  row.charNameBtn = CreateFrame("Button", nil, row)
  row.charNameBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.charNameBtn:SetWidth(S.CHARNAME_WIDTH)
  row.charNameBtn:SetHeight(S.ROW_HEIGHT)
  row.charNameBtn:EnableMouse(true)
  row.charNameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.charNameBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  
  row.charName = row.charNameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.charName:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
  row.charName:SetPoint("LEFT", 0, 0)
  row.charName:SetWidth(S.CHARNAME_WIDTH)
  row.charName:SetJustifyH("LEFT")
  row.charName:SetTextColor(1, 1, 1, 1)
  
  row.charNameBtn.isHovered = false
  
  -- Character name click handlers
  row.charNameBtn:SetScript("OnClick", function()
    local sender = this:GetParent()._sender
    if not sender or sender == "" or sender == "Unknown" then return end
    
    if arg1 == "LeftButton" then
      if IsShiftKeyDown() then
        SendWho("n-\"" .. sender .. "\"")
      else
        ChatFrameEditBox:Show()
        ChatFrameEditBox:SetFocus()
        ChatFrameEditBox:SetText("/w " .. sender .. " ")
      end
    elseif arg1 == "RightButton" then
      ChatFrameEditBox:Show()
      ChatFrameEditBox:SetFocus()
      ChatFrameEditBox:SetText("/invite " .. sender)
    end
  end)
  
  -- Timestamp (using bundled monospace font for perfect alignment)
  row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.time:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\IBMPlexMono-SemiBold.ttf", DBB2:GetFontSize(10))
  row.time:SetPoint("RIGHT", row, "RIGHT", S.TIMESTAMP_RIGHT_OFFSET, 0)
  row.time:SetWidth(S.TIMESTAMP_WIDTH)
  row.time:SetJustifyH("LEFT")
  row.time:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Message button (for tooltip on truncated messages)
  -- Width is set explicitly in SetData based on calculated availableWidth
  row.messageBtn = CreateFrame("Button", nil, row)
  row.messageBtn:SetPoint("LEFT", row, "LEFT", S.CHARNAME_OFFSET, 0)
  row.messageBtn:SetWidth(100)  -- Default width, updated in SetData
  row.messageBtn:SetHeight(S.ROW_HEIGHT)
  row.messageBtn:EnableMouse(true)
  row.messageBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  row.messageBtn.isHovered = false
  
  row.message = row.messageBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.message:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
  row.message:SetPoint("LEFT", 0, 0)
  row.message:SetPoint("RIGHT", 0, 0)
  row.message:SetJustifyH("LEFT")
  row.message:SetTextColor(0.9, 0.9, 0.9, 1)
  
  -- SetData function
  row.SetData = function(self, sender, message, timeStr, classColor)
    self._sender = sender or "Unknown"
    self._classColor = classColor or "|cffffffff"
    self._fullMessage = message or ""
    self._isTruncated = false
    
    -- Set character name
    if self.charNameBtn and self.charNameBtn.isHovered then
      self.charName:SetText(self._sender)
      local hr, hg, hb = DBB2:GetHighlightColor()
      self.charName:SetTextColor(hr, hg, hb, 1)
    else
      self.charName:SetText(self._classColor .. self._sender .. "|r")
      self.charName:SetTextColor(1, 1, 1, 1)
    end
    
    self.time:SetText(timeStr or "")
    
    -- Position timestamp based on display mode
    self.time:ClearAllPoints()
    self.messageBtn:ClearAllPoints()
    self.messageBtn:SetPoint("LEFT", self, "LEFT", S.CHARNAME_OFFSET, 0)
    
    if DBB2_Config.timeDisplayMode == 1 then
      -- Relative: right-aligned, dynamic width
      self.time:SetJustifyH("RIGHT")
      self.time:SetPoint("RIGHT", self, "RIGHT", S.TIMESTAMP_RIGHT_OFFSET_RELATIVE, 0)
      self.time:SetWidth(S.TIMESTAMP_WIDTH_RELATIVE)
    elseif DBB2_Config.timeDisplayMode == 2 then
      -- Elapsed: left-aligned to avoid jumping on update
      self.time:SetJustifyH("LEFT")
      self.time:SetPoint("RIGHT", self, "RIGHT", S.TIMESTAMP_RIGHT_OFFSET_ELAPSED, 0)
      self.time:SetWidth(S.TIMESTAMP_WIDTH_ELAPSED)
    else
      -- Timestamp: left-aligned, fixed width
      self.time:SetJustifyH("LEFT")
      self.time:SetPoint("RIGHT", self, "RIGHT", S.TIMESTAMP_RIGHT_OFFSET, 0)
      self.time:SetWidth(S.TIMESTAMP_WIDTH)
    end
    
    -- Calculate available width and truncate message
    local availableWidth = S.CalcMessageWidth(self.time)
    
    if availableWidth > 20 then
      S.TruncateMessage(self, availableWidth)
      self._needsWidthRecalc = false
    else
      self.message:SetText(self._fullMessage)
      self._needsWidthRecalc = true
    end
  end
  
  -- Helper: Check if row is visible within scroll frame viewport
  local function IsRowVisibleInScrollFrame(rowFrame)
    -- Walk up to find the scroll frame
    local scrollFrame = nil
    local current = rowFrame:GetParent()
    while current do
      -- Check if parent is a scroll child (has a scroll frame parent)
      local grandparent = current:GetParent()
      if grandparent and grandparent.GetVerticalScroll then
        scrollFrame = grandparent
        break
      end
      current = grandparent
    end
    
    if not scrollFrame then return true end  -- No scroll frame found, assume visible
    
    -- Get scroll frame bounds
    local sfTop = scrollFrame:GetTop()
    local sfBottom = scrollFrame:GetBottom()
    if not sfTop or not sfBottom then return true end
    
    -- Get row bounds
    local rowTop = rowFrame:GetTop()
    local rowBottom = rowFrame:GetBottom()
    if not rowTop or not rowBottom then return false end
    
    -- Row must be fully within viewport (not just overlapping)
    -- This prevents tooltips when row is partially scrolled out of view
    if rowTop > sfTop or rowBottom < sfBottom then
      return false
    end
    
    return true
  end
  
  -- Hover handlers for character name
  row.charNameBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local parent = this:GetParent()
    
    -- Check if row is actually visible in scroll viewport
    local isVisibleInViewport = IsRowVisibleInScrollFrame(parent)
    local isOver = MouseIsOver(this) and isVisibleInViewport
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      local hr, hg, hb = DBB2:GetHighlightColor()
      parent.charName:SetText(parent._sender or "Unknown")
      parent.charName:SetTextColor(hr, hg, hb, 1)
      if DBB2.tooltip and DBB2.tooltip:IsShown() then
        DBB2.api.DismissMessageTooltip()
      end
    else
      this.isHovered = false
      local classColor = parent._classColor or "|cffffffff"
      parent.charName:SetText(classColor .. (parent._sender or "Unknown") .. "|r")
      parent.charName:SetTextColor(1, 1, 1, 1)
    end
  end)
  
  -- Hover handlers for message (tooltip)
  row.messageBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local parent = this:GetParent()
    
    -- Check if row is actually visible in scroll viewport
    local isVisibleInViewport = IsRowVisibleInScrollFrame(parent)
    local isOver = MouseIsOver(this) and isVisibleInViewport
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      if parent._isTruncated and parent._fullMessage and parent._fullMessage ~= "" then
        if DBB2.api.ShowMessageTooltip then
          DBB2.api.ShowMessageTooltip(this, parent._sender, parent._fullMessage)
        end
      end
    else
      this.isHovered = false
      if DBB2.tooltip and DBB2.tooltip:IsShown() and DBB2.tooltip.triggerFrame == this then
        if DBB2.api.ShouldDismissTooltip and DBB2.api.ShouldDismissTooltip() then
          DBB2.api.DismissMessageTooltip()
        end
      end
    end
  end)
  
  -- OnUpdate for deferred width recalculation
  row:SetScript("OnUpdate", function()
    if not this._needsWidthRecalc then return end
    if not this:IsVisible() then return end
    
    local availableWidth = S.CalcMessageWidth(this.time)
    
    if availableWidth > 20 then
      this._needsWidthRecalc = false
      S.TruncateMessage(this, availableWidth)
    end
  end)
  
  return row
end


-- =====================
-- FILTER INPUT
-- =====================

--- Create a filter input field for filtering messages.
-- Includes placeholder text and visual feedback on focus/hover.
-- @param name (string) Unique name for the edit box
-- @param parent (Frame) Parent frame to attach the input to
-- @return (EditBox) The created filter input with placeholder text support
function DBB2.schema.CreateFilterInput(name, parent)
  local S = DBB2.schema
  
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(S.FILTER_HEIGHT)
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
  f:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  
  DBB2:CreateBackdrop(f, nil, nil, nil, true)
  
  -- Hide full border, we'll add bottom-only
  if f.backdrop then
    f.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    f.backdrop:SetBackdropColor(0, 0, 0, 0)
  end
  
  -- Bottom border line
  f.bottomBorder = parent:CreateTexture(nil, "BORDER")
  f.bottomBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  f.bottomBorder:SetHeight(1)
  f.bottomBorder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  f.bottomBorder:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, -S.FILTER_HEIGHT)
  f.bottomBorder:SetVertexColor(0.25, 0.25, 0.25, 1)
  
  -- Placeholder text
  f.placeholder = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.placeholder:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
  f.placeholder:SetPoint("LEFT", 6, 0)
  f.placeholder:SetText("Filter messages... (e.g. bwl,zg,mc)")
  f.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnterPressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEditFocusGained", function()
    this.placeholder:Hide()
  end)
  
  f:SetScript("OnEditFocusLost", function()
    if this:GetText() == "" then
      this.placeholder:Show()
    end
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.bottomBorder:SetVertexColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.bottomBorder:SetVertexColor(0.25, 0.25, 0.25, 1)
  end)
  
  return f
end

-- =====================
-- CURRENT TIME DISPLAY
-- =====================

--- Create a font string for displaying the current time.
-- Used in the filter bar area to show real-time clock.
-- @param parent (Frame) Parent frame to attach the font string to
-- @return (FontString) The created time display font string
function DBB2.schema.CreateCurrentTimeDisplay(parent)
  local S = DBB2.schema
  
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\IBMPlexMono-SemiBold.ttf", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  f:SetTextColor(0.5, 0.5, 0.5, 1)
  f:SetText(date("%H:%M:%S"))
  f:SetWidth(S.TIMESTAMP_WIDTH)
  
  return f
end

-- =====================
-- BUTTON
-- =====================

--- Create a styled button with hover effects.
-- Includes backdrop, text label, and press animation.
-- @param name (string) Unique name for the button
-- @param parent (Frame) Parent frame to attach the button to
-- @param text (string|nil) Button label text (default: "Button")
-- @return (Button) The created button with text property
function DBB2.schema.CreateButton(name, parent, text)
  local f = CreateFrame("Button", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetWidth(DBB2:ScaleSize(100))
  
  DBB2:CreateBackdrop(f)
  
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(11))
  f.text:SetPoint("CENTER", 0, 0)
  f.text:SetText(text or "Button")
  f.text:SetTextColor(1, 1, 1, 1)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  f:SetScript("OnMouseDown", function()
    if not this:IsEnabled() then return end
    this.text:SetPoint("CENTER", 1, -1)
  end)
  
  f:SetScript("OnMouseUp", function()
    this.text:SetPoint("CENTER", 0, 0)
  end)
  
  return f
end

-- =====================
-- CHECKBOX
-- =====================

--- Create a checkbox with optional label.
-- Includes visual check indicator and hover effects.
-- @param name (string|nil) Unique name for the checkbox (optional)
-- @param parent (Frame) Parent frame to attach the checkbox to
-- @param label (string|nil) Text label displayed next to the checkbox
-- @param fontSize (number|nil) Font size for the label (default: 10)
-- @return (Frame) The created checkbox with the following methods:
--   - SetChecked(checked): Sets the checked state
--   - GetChecked(): Returns the current checked state (boolean)
--   - Enable(): Enables the checkbox
--   - Disable(): Disables the checkbox
--   - OnChecked: Callback function called when state changes
function DBB2.schema.CreateCheckBox(name, parent, label, fontSize)
  fontSize = fontSize or 10
  local checkSize = DBB2:ScaleSize(16)
  local hr, hg, hb = DBB2:GetHighlightColor()
  
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(checkSize)
  f:SetHeight(checkSize)
  
  f.button = CreateFrame("Button", name and (name .. "Btn") or nil, f)
  f.button:SetAllPoints(f)
  f.button:EnableMouse(true)
  DBB2:CreateBackdrop(f.button)
  
  f.backdrop = f.button.backdrop
  
  f.checkFrame = CreateFrame("Frame", nil, f.button)
  f.checkFrame:SetPoint("TOPLEFT", 3, -3)
  f.checkFrame:SetPoint("BOTTOMRIGHT", -3, 3)
  f.checkFrame:SetFrameLevel(f.button:GetFrameLevel() + 5)
  
  f.check = f.checkFrame:CreateTexture(nil, "OVERLAY")
  f.check:SetAllPoints()
  f.check:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  f.check:SetVertexColor(hr, hg, hb, 1)
  f.checkFrame:Hide()
  
  f.isChecked = false
  
  f.SetChecked = function(self, checked)
    self.isChecked = checked and true or false
    if self.isChecked then
      self.checkFrame:Show()
    else
      self.checkFrame:Hide()
    end
  end
  
  f.GetChecked = function(self)
    return self.isChecked
  end
  
  f.button:SetScript("OnClick", function()
    local container = this:GetParent()
    container.isChecked = not container.isChecked
    if container.isChecked then
      container.checkFrame:Show()
    else
      container.checkFrame:Hide()
    end
    if container.OnChecked then
      container.OnChecked(container.isChecked)
    end
  end)
  
  f.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  if label then
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(fontSize))
    f.label:SetPoint("LEFT", f, "RIGHT", DBB2:ScaleSize(8), 0)
    f.label:SetText(label)
    f.label:SetTextColor(1, 1, 1, 1)
  end
  
  f.Disable = function(self)
    self.isDisabled = true
    self.button:EnableMouse(false)
    self.check:SetVertexColor(0.5, 0.5, 0.5, 1)
    if self.backdrop then
      self.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    if self.label then
      self.label:SetTextColor(0.5, 0.5, 0.5, 1)
    end
  end
  
  f.Enable = function(self)
    self.isDisabled = false
    self.button:EnableMouse(true)
    local r, g, b = DBB2:GetHighlightColor()
    self.check:SetVertexColor(r, g, b, 1)
    if self.backdrop then
      self.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    if self.label then
      self.label:SetTextColor(1, 1, 1, 1)
    end
  end
  
  return f
end

-- =====================
-- EDIT BOX
-- =====================

--- Create a styled text input field.
-- Includes backdrop and hover effects.
-- @param name (string) Unique name for the edit box
-- @param parent (Frame) Parent frame to attach the edit box to
-- @return (EditBox) The created edit box with backdrop
function DBB2.schema.CreateEditBox(name, parent)
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
  f:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  
  DBB2:CreateBackdrop(f, nil, nil, nil, true)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  return f
end

-- =====================
-- DROPDOWN
-- =====================

--- Create a dropdown button for selection menus.
-- Displays selected text with a dropdown arrow indicator.
-- @param name (string) Unique name for the dropdown button
-- @param parent (Frame) Parent frame to attach the dropdown to
-- @return (Button) The created dropdown button with text and arrow properties
function DBB2.schema.CreateDropDown(name, parent)
  local f = CreateFrame("Button", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetWidth(DBB2:ScaleSize(150))
  
  DBB2:CreateBackdrop(f)
  
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(11))
  f.text:SetPoint("LEFT", 5, 0)
  f.text:SetPoint("RIGHT", -DBB2:ScaleSize(20), 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetText("Select...")
  f.text:SetTextColor(1, 1, 1, 1)
  
  f.arrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.arrow:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(11))
  f.arrow:SetPoint("RIGHT", -5, 0)
  f.arrow:SetText("v")
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.arrow:SetTextColor(hr, hg, hb, 1)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  return f
end

-- =====================
-- LABEL
-- =====================

--- Create a simple text label.
-- @param parent (Frame) Parent frame to attach the label to
-- @param text (string|nil) Label text content
-- @param size (number|nil) Font size (default: 11)
-- @return (FontString) The created label font string
function DBB2.schema.CreateLabel(parent, text, size)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(size or 11))
  f:SetText(text or "")
  f:SetTextColor(1, 1, 1, 1)
  f:SetJustifyH("LEFT")
  return f
end

-- =====================
-- SLIDER
-- =====================

--- Create a horizontal slider with label and value display.
-- Includes track background and draggable thumb.
-- @param name (string|nil) Unique name for the slider container
-- @param parent (Frame) Parent frame to attach the slider to
-- @param label (string|nil) Label text displayed above the slider
-- @param minVal (number) Minimum slider value
-- @param maxVal (number) Maximum slider value
-- @param step (number|nil) Value step increment (default: 1)
-- @param fontSize (number|nil) Font size for label and value (default: 10)
-- @return (Frame) The created slider container with the following methods:
--   - SetValue(val): Sets the slider value
--   - GetValue(): Returns the current slider value (number)
--   - OnValueChanged: Callback function called when value changes
function DBB2.schema.CreateSlider(name, parent, label, minVal, maxVal, step, fontSize)
  step = step or 1
  fontSize = fontSize or 10
  if step == 0 then step = 1 end
  
  local container = CreateFrame("Frame", name, parent)
  container:SetHeight(DBB2:ScaleSize(30))
  container:SetWidth(DBB2:ScaleSize(200))
  
  container.label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.label:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(fontSize))
  container.label:SetPoint("TOPLEFT", 0, 0)
  container.label:SetText(label or "Slider")
  container.label:SetTextColor(1, 1, 1, 1)
  
  container.value = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.value:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(fontSize))
  container.value:SetPoint("TOPRIGHT", 0, 0)
  container.value:SetText(minVal)
  local hr, hg, hb = DBB2:GetHighlightColor()
  container.value:SetTextColor(hr, hg, hb, 1)
  
  local sliderOffset = DBB2:ScaleSize(16)
  local sliderHeight = sliderOffset
  
  container.slider = CreateFrame("Slider", name and (name .. "Slider") or nil, container)
  container.slider:SetPoint("TOPLEFT", 0, -sliderOffset)
  container.slider:SetPoint("TOPRIGHT", 0, -sliderOffset)
  container.slider:SetHeight(sliderHeight)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetMinMaxValues(minVal, maxVal)
  container.slider:SetValueStep(step)
  container.slider:SetValue(minVal)
  container.slider:EnableMouse(true)
  
  -- Track background
  container.track = container:CreateTexture(nil, "BACKGROUND")
  container.track:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
  container.track:SetPoint("TOPLEFT", container.slider, "TOPLEFT", 0, -sliderHeight/2 + 2)
  container.track:SetPoint("BOTTOMRIGHT", container.slider, "BOTTOMRIGHT", 0, sliderHeight/2 - 2)
  
  -- Thumb
  container.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  local thumb = container.slider:GetThumbTexture()
  thumb:SetWidth(DBB2:ScaleSize(10))
  thumb:SetHeight(DBB2:ScaleSize(14))
  thumb:SetVertexColor(hr, hg, hb, 1)
  
  container.slider:SetScript("OnValueChanged", function()
    local val = math.floor(this:GetValue() + 0.5)
    container.value:SetText(val)
    if container.OnValueChanged then
      container.OnValueChanged(val)
    end
  end)
  
  container.SetValue = function(self, val)
    self.slider:SetValue(val)
  end
  
  container.GetValue = function(self)
    return math.floor(self.slider:GetValue() + 0.5)
  end
  
  return container
end

-- =====================
-- RESIZE GRIP
-- =====================

--- Create a resize grip for resizable frames.
-- Allows users to drag the corner to resize the parent frame.
-- Automatically saves position after resize via DBB2.api.SavePosition.
-- @param parent (Frame) Parent frame that will be resizable
-- @param minWidth (number|nil) Minimum allowed width (default: 300)
-- @param minHeight (number|nil) Minimum allowed height (default: 200)
-- @return (Frame) The created resize grip frame
function DBB2.schema.CreateResizeGrip(parent, minWidth, minHeight)
  local gripSize = DBB2:ScaleSize(13)
  local grip = CreateFrame("Frame", nil, parent)
  grip:SetWidth(gripSize)
  grip:SetHeight(gripSize)
  grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 2, -2)
  grip:SetFrameLevel(parent:GetFrameLevel() + 10)
  grip:EnableMouse(true)
  
  grip.minWidth = minWidth or 300
  grip.minHeight = minHeight or 200
  
  grip.texture = grip:CreateTexture(nil, "OVERLAY")
  grip.texture:SetAllPoints(grip)
  grip.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
  
  grip:SetScript("OnEnter", function()
    this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-highlight")
  end)
  
  grip:SetScript("OnLeave", function()
    if not this.isResizing then
      this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
    end
  end)
  
  grip:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
      this.isResizing = true
      this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-down")
      
      local cursorX, cursorY = GetCursorPosition()
      local scale = parent:GetEffectiveScale()
      this.startX = cursorX / scale
      this.startY = cursorY / scale
      this.startWidth = parent:GetWidth()
      this.startHeight = parent:GetHeight()
      
      this:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local scale = parent:GetEffectiveScale()
        cursorX = cursorX / scale
        cursorY = cursorY / scale
        
        local newWidth = this.startWidth + (cursorX - this.startX)
        local newHeight = this.startHeight - (cursorY - this.startY)
        
        newWidth = math.max(newWidth, this.minWidth)
        newHeight = math.max(newHeight, this.minHeight)
        
        parent:SetWidth(newWidth)
        parent:SetHeight(newHeight)
      end)
    end
  end)

  grip:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" and this.isResizing then
      this.isResizing = false
      this:SetScript("OnUpdate", nil)
      
      DBB2.api.SavePosition(parent)
      
      if MouseIsOver(this) then
        this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-highlight")
      else
        this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
      end
    end
  end)
  
  return grip
end

-- =====================
-- TAB SYSTEM
-- =====================

--- Create a tabbed interface with multiple panels.
-- Each tab has a button and associated content panel.
-- @param name (string) Base name for tab system components
-- @param parent (Frame) Parent frame to attach the tab system to
-- @param tabs (table) Array of tab names (e.g., {"Logs", "Groups", "Config"})
-- @param buttonWidth (number|nil) Width of tab buttons (default: 90)
-- @param buttonHeight (number|nil) Height of tab buttons (default: 20)
-- @return (table) Tab system object with the following properties:
--   - buttons: Table of tab buttons keyed by tab name
--   - panels: Table of content panels keyed by tab name
--   - content: The main content container frame
--   - activeTab: Currently active tab name
--   - SwitchTab(tabName): Switches to the specified tab
--   - onTabChanged: Callback function called when tab changes
function DBB2.schema.CreateTabSystem(name, parent, tabs, buttonWidth, buttonHeight)
  local S = DBB2.schema
  local tabSystem = {}
  tabSystem.buttons = {}
  tabSystem.panels = {}
  tabSystem.activeTab = nil
  tabSystem.onTabChanged = nil
  
  buttonWidth = DBB2:ScaleSize(buttonWidth or 90)
  buttonHeight = DBB2:ScaleSize(buttonHeight or 20)
  local buttonSpacing = DBB2:ScaleSize(5)
  
  -- Switch tab function
  tabSystem.SwitchTab = function(tabName)
    local hr, hg, hb = DBB2:GetHighlightColor()
    
    for tname, panel in pairs(tabSystem.panels) do
      panel:Hide()
    end
    
    for tname, btn in pairs(tabSystem.buttons) do
      btn.text:SetTextColor(0.7, 0.7, 0.7, 1)
      btn.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    
    if tabSystem.panels[tabName] then
      tabSystem.panels[tabName]:Show()
    end
    if tabSystem.buttons[tabName] then
      tabSystem.buttons[tabName].text:SetTextColor(hr, hg, hb, 1)
      tabSystem.buttons[tabName].backdrop:SetBackdropBorderColor(hr, hg, hb, 1)
    end
    
    tabSystem.activeTab = tabName
    
    if tabSystem.onTabChanged then
      tabSystem.onTabChanged(tabName)
    end
  end
  
  -- Content area
  tabSystem.content = CreateFrame("Frame", name .. "Content", parent)
  tabSystem.content:SetPoint("TOPLEFT", parent, "TOPLEFT", S.GUI_PADDING, -S.GUI_PADDING - buttonHeight - DBB2:ScaleSize(5))
  tabSystem.content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -S.GUI_PADDING, S.GUI_PADDING)
  DBB2:CreateBackdrop(tabSystem.content)
  
  if tabSystem.content.backdrop then
    local bgColor = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    tabSystem.content.backdrop:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)
  end

  -- Create tab buttons and panels
  for i, tabName in ipairs(tabs) do
    local btn = DBB2.schema.CreateButton(name .. "Tab" .. tabName, parent, tabName)
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", S.GUI_PADDING + (i-1) * (buttonWidth + buttonSpacing), -S.GUI_PADDING)
    
    btn.tabName = tabName
    btn:SetScript("OnClick", function()
      tabSystem.SwitchTab(this.tabName)
    end)
    
    btn:SetScript("OnEnter", function()
      if tabSystem.activeTab ~= this.tabName then
        local r, g, b = DBB2:GetHighlightColor()
        this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      end
    end)
    
    btn:SetScript("OnLeave", function()
      if tabSystem.activeTab ~= this.tabName then
        this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
      end
    end)
    
    tabSystem.buttons[tabName] = btn
    
    local panel = CreateFrame("Frame", name .. "Panel" .. tabName, tabSystem.content)
    panel:SetPoint("TOPLEFT", S.CONTENT_PADDING, -S.CONTENT_PADDING)
    panel:SetPoint("BOTTOMRIGHT", -S.CONTENT_PADDING, S.CONTENT_PADDING)
    panel:Hide()
    
    panel.scrollFrame = nil
    
    panel:SetScript("OnShow", function()
      this._updateScrollPending = true
      if this.scrollFrame then
        this.scrollFrame._needsScrollUpdate = true
      end
    end)
    
    panel:SetScript("OnUpdate", function()
      if this._updateScrollPending then
        this._updateScrollPending = nil
        if this.scrollFrame and this.scrollFrame.UpdateScrollState then
          this.scrollFrame.UpdateScrollState()
        end
      end
      if this._needsContentUpdate then
        this._needsContentUpdate = nil
        local updateType = this._contentUpdateType
        this._contentUpdateType = nil
        if updateType == "Logs" then
          if DBB2.gui and DBB2.gui.UpdateMessages then
            DBB2.gui:UpdateMessages()
          end
        elseif updateType == "Groups" or updateType == "Professions" or updateType == "Hardcore" then
          if this.UpdateCategories then
            this.UpdateCategories()
          end
        end
      end
    end)
    
    tabSystem.panels[tabName] = panel
  end
  
  return tabSystem
end


-- =====================
-- STATIC SCROLL FRAME
-- =====================

--- Create a static scroll frame for config panels.
-- Simpler than the dynamic scroll frame, optimized for static content.
-- @param name (string) Unique name for the scroll frame
-- @param parent (Frame) Parent frame to attach the scroll frame to
-- @return (ScrollFrame) The created scroll frame with the following methods:
--   - GetScrollRange(): Returns the calculated scroll range
--   - UpdateScrollState(): Updates scrollbar visibility and thumb size
--   - Scroll(step): Scrolls by the specified amount
function DBB2.schema.CreateStaticScrollFrame(name, parent)
  local S = DBB2.schema
  local f = CreateFrame("ScrollFrame", name, parent)

  -- Create slider
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetWidth(S.SCROLLBAR_WIDTH or DBB2:ScaleSize(7))
  f.slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
  f.slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
  
  f.slider:EnableMouse(1)
  f.slider:SetValueStep(1)
  f.slider:SetMinMaxValues(0, 0)
  f.slider:SetValue(0)
  
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetWidth(S.SCROLLBAR_WIDTH or DBB2:ScaleSize(7))
  f.slider.thumb:SetHeight(DBB2:ScaleSize(50))
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.slider.thumb:SetTexture(hr, hg, hb, 0.5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
  end)

  f.GetScrollRange = function()
    local frameHeight = f:GetHeight() or 0
    if f.scrollChild and frameHeight > 0 then
      local childHeight = f.scrollChild:GetHeight() or 0
      return math.max(0, childHeight - frameHeight)
    end
    return 0
  end

  f.UpdateScrollState = function()
    local frameHeight = f:GetHeight()
    if frameHeight and frameHeight > 0 then
      local scrollRange = f.GetScrollRange()
      f.slider:SetMinMaxValues(0, scrollRange)
      
      local currentScroll = f:GetVerticalScroll()
      if currentScroll > scrollRange then
        f:SetVerticalScroll(scrollRange)
        f.slider:SetValue(scrollRange)
      else
        f.slider:SetValue(currentScroll)
      end

      if scrollRange <= 1 then
        f.slider:Hide()
      else
        local m = frameHeight + scrollRange
        local ratio = frameHeight / m
        local size = math.floor(frameHeight * ratio)
        f.slider.thumb:SetHeight(math.max(size, DBB2:ScaleSize(20)))
        f.slider:Show()
      end
    end
  end

  f.Scroll = function(self, step)
    step = step or 0
    local current = f:GetVerticalScroll()
    local max = f.GetScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll(max)
    elseif new <= 0 then
      f:SetVerticalScroll(0)
    else
      f:SetVerticalScroll(new)
    end
    f.UpdateScrollState()
  end

  f:EnableMouseWheel(1)
  f:SetScript("OnMouseWheel", function()
    local scrollSpeed = DBB2_Config.scrollSpeed or 20
    f:Scroll(arg1 * scrollSpeed)
  end)

  return f
end

--- Create a scroll child for static scroll frames.
-- The scroll child is automatically attached to the parent scroll frame.
-- @param name (string) Unique name for the scroll child frame
-- @param parent (ScrollFrame) Parent scroll frame created by CreateStaticScrollFrame
-- @param height (number|nil) Initial height of the scroll child (default: 1)
-- @return (Frame) The created scroll child frame
function DBB2.schema.CreateStaticScrollChild(name, parent, height)
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(parent:GetWidth() or 1)
  f:SetHeight(height or 1)
  parent:SetScrollChild(f)
  parent.scrollChild = f
  
  if parent.UpdateScrollState then
    parent.UpdateScrollState()
  end
  
  return f
end


-- =====================
-- COLOR PICKER
-- =====================

--- Create a color picker button with preview.
-- Opens the WoW color picker dialog when clicked.
-- Supports opacity/alpha channel selection.
-- @param name (string|nil) Unique name for the color picker container
-- @param parent (Frame) Parent frame to attach the color picker to
-- @param label (string|nil) Label text displayed next to the color button
-- @param fontSize (number|nil) Font size for the label (default: 10)
-- @return (Frame) The created color picker with the following methods:
--   - SetColor(r, g, b, a): Sets the color (values 0-1)
--   - GetColor(): Returns r, g, b, a color values
--   - OnColorChanged: Callback function called when color changes
function DBB2.schema.CreateColorPicker(name, parent, label, fontSize)
  fontSize = fontSize or 10
  local container = CreateFrame("Frame", name, parent)
  container:SetHeight(DBB2:ScaleSize(20))
  container:SetWidth(DBB2:ScaleSize(200))
  
  container.label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.label:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(fontSize))
  container.label:SetPoint("LEFT", 0, 0)
  container.label:SetText(label or "Color")
  container.label:SetTextColor(1, 1, 1, 1)
  
  container.button = CreateFrame("Button", name and (name .. "Button") or nil, container)
  container.button:SetWidth(DBB2:ScaleSize(50))
  container.button:SetHeight(DBB2:ScaleSize(16))
  container.button:SetPoint("RIGHT", 0, 0)
  
  DBB2:CreateBackdrop(container.button)
  
  -- Create preview frame at higher level to ensure visibility above backdrop
  container.button.previewFrame = CreateFrame("Frame", nil, container.button)
  container.button.previewFrame:SetPoint("TOPLEFT", 3, -3)
  container.button.previewFrame:SetPoint("BOTTOMRIGHT", -3, 3)
  container.button.previewFrame:SetFrameLevel(container.button:GetFrameLevel() + 5)
  
  container.button.preview = container.button.previewFrame:CreateTexture(nil, "OVERLAY")
  container.button.preview:SetAllPoints()
  container.button.preview:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  container.button.preview:SetVertexColor(1, 1, 1, 1)
  
  container.r = 1
  container.g = 1
  container.b = 1
  container.a = 1
  
  container.SetColor = function(self, r, g, b, a)
    self.r = r or 1
    self.g = g or 1
    self.b = b or 1
    self.a = a or 1
    self.button.preview:SetVertexColor(self.r, self.g, self.b, self.a)
  end
  
  container.GetColor = function(self)
    return self.r, self.g, self.b, self.a
  end
  
  container.button:SetScript("OnClick", function()
    local picker = container
    local cr, cg, cb, ca = picker.r, picker.g, picker.b, picker.a
    
    ColorPickerFrame.func = function()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1 - OpacitySliderFrame:GetValue()
      
      picker.r = r
      picker.g = g
      picker.b = b
      picker.a = a
      picker.button.preview:SetVertexColor(r, g, b, a)
      
      if picker.OnColorChanged then
        picker.OnColorChanged(r, g, b, a)
      end
    end
    
    ColorPickerFrame.cancelFunc = function()
      picker.r = cr
      picker.g = cg
      picker.b = cb
      picker.a = ca
      picker.button.preview:SetVertexColor(cr, cg, cb, ca)
    end
    
    ColorPickerFrame.opacityFunc = ColorPickerFrame.func
    ColorPickerFrame.opacity = 1 - ca
    ColorPickerFrame.hasOpacity = 1
    ColorPickerFrame:SetColorRGB(cr, cg, cb)
    ColorPickerFrame:SetFrameStrata("DIALOG")
    ShowUIPanel(ColorPickerFrame)
  end)
  
  container.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  container.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end)
  
  return container
end
```

## api/hardcore.lua
```lua
-- DBB2 Hardcore Mode API
-- Turtle WoW hardcore mode detection and state tracking
--
-- Functions:
--   DBB2.api.IsHardcoreChatActive() - Check if hardcore chat detected this session
--   DBB2.api.SetHardcoreChatActive() - Mark hardcore chat as active
--   DBB2.api.DetectHardcoreCharacter() - Scan spellbook for hardcore spells
--   DBB2.api.IsHardcoreCharacter() - Return cached hardcore status

-- Localize frequently used globals for performance
local string_lower = string.lower

-- =====================
-- HARDCORE MODE API
-- =====================

-- Turtle WoW hardcore mode: automatically switches between World and Hardcore chat.
-- When CHAT_MSG_HARDCORE events are received, World channel is ignored.
-- This is tracked per-session (resets on login).

-- Session flag: set to true when we receive any CHAT_MSG_HARDCORE event
DBB2._hardcoreChatActive = false

-- [ IsHardcoreChatActive ]
-- Returns whether hardcore chat has been detected this session
-- return:      [boolean]       true if hardcore chat is active
function DBB2.api.IsHardcoreChatActive()
  return DBB2._hardcoreChatActive
end

-- [ SetHardcoreChatActive ]
-- Marks hardcore chat as active (called when CHAT_MSG_HARDCORE is received)
function DBB2.api.SetHardcoreChatActive()
  DBB2._hardcoreChatActive = true
end


-- =====================
-- HARDCORE CHARACTER DETECTION
-- =====================

-- [ DetectHardcoreCharacter ]
-- Detects if the current character is an active hardcore character by scanning spellbook
-- Only scans the first "General" tab for efficiency and accuracy.
-- Looks for spells with rank "Challenge" (e.g., "Hardcore (Challenge)", "Inferno (Challenge)")
-- A character is considered "active hardcore" if:
--   1. Has "Hardcore" spell with "Challenge" rank AND is below level 60 (normal hardcore), OR
--   2. Has "Inferno" spell with "Challenge" rank (level 60 hardcore who chose to stay hardcore)
-- return:      [boolean]       true if active hardcore character detected
function DBB2.api.DetectHardcoreCharacter()
  -- Check cached result first
  if DBB2_Config.isHardcoreCharacter ~= nil then
    return DBB2_Config.isHardcoreCharacter
  end
  
  local hasHardcoreSpell = false
  local hasInfernoSpell = false
  local playerLevel = UnitLevel("player") or 60
  
  -- Only scan the first "General" tab (tab 1) for challenge spells
  -- This is more efficient and avoids false matches from other spell tabs
  local numTabs = GetNumSpellTabs()
  if numTabs >= 1 then
    local tabName, _, offset, numSpells = GetSpellTabInfo(1)
    
    for i = 1, numSpells do
      local spellName, spellRank = GetSpellName(offset + i, "spell")
      if spellName and spellRank then
        -- Only match spells with "Challenge" rank for precise detection
        if spellRank == "Challenge" then
          local lowerName = string_lower(spellName)
          if lowerName == "hardcore" then
            hasHardcoreSpell = true
          elseif lowerName == "inferno" then
            hasInfernoSpell = true
          end
        end
      end
    end
  end
  
  -- Active hardcore: has Inferno spell, OR has Hardcore spell and below level 60
  local isActiveHardcore = hasInfernoSpell or (hasHardcoreSpell and playerLevel < 60)
  
  DBB2_Config.isHardcoreCharacter = isActiveHardcore
  return isActiveHardcore
end

-- [ IsHardcoreCharacter ]
-- Returns cached hardcore character status (use DetectHardcoreCharacter to force re-scan)
-- return:      [boolean]       true if hardcore character
function DBB2.api.IsHardcoreCharacter()
  if DBB2_Config.isHardcoreCharacter == nil then
    return DBB2.api.DetectHardcoreCharacter()
  end
  return DBB2_Config.isHardcoreCharacter
end
```

## api/lockouts.lua
```lua
-- DBB2 Lockouts API
-- Tracks raid lockouts and maps them to categories
-- Depends on: env/tables.lua (DBB2.env.instanceAliases)

-- Localize frequently used globals for performance
local string_lower = string.lower
local math_floor = math.floor
local math_mod = math.mod
local time = time
local pairs = pairs

-- Storage for lockout data
DBB2.lockouts = {}

-- [ InitLockouts ]
-- Initializes the lockout tracking system
-- NOTE: UPDATE_INSTANCE_INFO event is registered in DifficultBulletinBoard.lua
function DBB2.api.InitLockouts()
  -- Request initial data
  RequestRaidInfo()
end

-- [ RefreshLockouts ]
-- Requests fresh lockout data from the server
function DBB2.api.RefreshLockouts()
  RequestRaidInfo()
end

-- [ UpdateLockouts ]
-- Called when UPDATE_INSTANCE_INFO fires, parses lockout data
function DBB2.api.UpdateLockouts()
  -- Clear existing lockouts
  DBB2.lockouts = {}
  
  local numInstances = GetNumSavedInstances()
  
  for i = 1, numInstances do
    local instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i)
    
    if instanceName and instanceReset and instanceReset > 0 then
      -- Store raw lockout info
      local lowerName = string_lower(instanceName)
      DBB2.lockouts[lowerName] = {
        name = instanceName,
        id = instanceID,
        reset = instanceReset,
        resetTime = time() + instanceReset
      }
    end
  end
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() then
    local activeTab = DBB2.gui.tabs and DBB2.gui.tabs.activeTab
    if activeTab == "Groups" then
      local panel = DBB2.gui.tabs.panels["Groups"]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
    end
  end
end

-- [ GetCategoryLockout ]
-- Checks if a category corresponds to a locked instance
-- 'categoryName' [string]  the category name to check
-- return: [table|nil]      lockout info if locked, nil otherwise
function DBB2.api.GetCategoryLockout(categoryName)
  if not categoryName then return nil end
  
  local lowerCat = string_lower(categoryName)
  local instanceAliases = DBB2.env.instanceAliases  -- Reference env table
  
  for instanceKey, lockoutData in pairs(DBB2.lockouts) do
    -- Check aliases for non-standard instance names
    local aliasedCategory = instanceAliases[instanceKey]  -- Use env reference
    if aliasedCategory and aliasedCategory == categoryName then
      return lockoutData
    end
    
    -- Direct match
    if instanceKey == lowerCat then
      return lockoutData
    end
  end
  
  return nil
end

-- [ IsCategoryLocked ]
-- Simple boolean check if category is locked
-- 'categoryName' [string]  the category name to check
-- return: [boolean]        true if locked
function DBB2.api.IsCategoryLocked(categoryName)
  return DBB2.api.GetCategoryLockout(categoryName) ~= nil
end

-- [ FormatTimeRemaining ]
-- Formats seconds into a readable time string
-- 'seconds' [number]  seconds remaining
-- return: [string]    formatted string like "2d 5h" or "3h 20m"
function DBB2.api.FormatTimeRemaining(seconds)
  if not seconds or type(seconds) ~= "number" or seconds <= 0 then
    return "Expired"
  end
  
  local days = math_floor(seconds / 86400)
  local hours = math_floor(math_mod(seconds, 86400) / 3600)
  local minutes = math_floor(math_mod(seconds, 3600) / 60)
  
  if days > 0 then
    return days .. "d " .. hours .. "h"
  elseif hours > 0 then
    return hours .. "h " .. minutes .. "m"
  else
    return minutes .. "m"
  end
end

-- [ GetLockoutTimeRemaining ]
-- Gets formatted time remaining for a category lockout
-- 'categoryName' [string]  the category name to check
-- return: [string|nil]     formatted time or nil if not locked
function DBB2.api.GetLockoutTimeRemaining(categoryName)
  local lockout = DBB2.api.GetCategoryLockout(categoryName)
  if lockout then
    local remaining = lockout.resetTime - time()
    return DBB2.api.FormatTimeRemaining(remaining)
  end
  return nil
end
```

## api/messages.lua
```lua
-- DBB2 Message API
-- Handles message capturing, storage, and filtering logic
--
-- Dependencies: api/blacklist.lua (IsMessageBlacklisted)
--               api/notifications.lua (CheckAndNotify)
--               api/categories_api.lua (CategorizeMessage)
-- This file must be loaded AFTER blacklist.lua and notifications.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_gsub = string.gsub
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local time = time
local ipairs = ipairs

-- Constants
local MAX_MESSAGES = 100

-- =====================
-- MESSAGE API
-- =====================

-- [ RemoveExpiredMessages ]
-- Removes messages older than the configured expire time
-- Called periodically to clean up old messages
function DBB2.api.RemoveExpiredMessages()
  local expireMinutes = DBB2_Config.messageExpireMinutes or 15
  if expireMinutes <= 0 then
    return
  end
  
  local expireSeconds = expireMinutes * 60
  local currentTime = time()
  local removed = false
  
  -- Remove from oldest to newest (start from beginning)
  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    local age = currentTime - (msg.time or 0)
    
    if age > expireSeconds then
      table_remove(DBB2.messages, i)
      removed = true
    end
  end
  
  -- Update GUI if messages were removed and GUI is visible
  if removed and DBB2.gui and DBB2.gui:IsShown() then
    if DBB2.gui.UpdateMessages then
      DBB2.gui:UpdateMessages()
    end
    
    -- Update active categorized tab if showing
    if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
      local activeTab = DBB2.gui.tabs.activeTab
      if activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
        local panel = DBB2.gui.tabs.panels[activeTab]
        if panel and panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end
  end
end

-- [ StripHyperlinks ]
-- Removes WoW hyperlink formatting from a message for comparison purposes
-- Hyperlinks like |Hplayer:Name|h[Name]|h become just [Name]
-- 'message'    [string]        the message text
-- return:      [string]        message with hyperlinks stripped
function DBB2.api.StripHyperlinks(message)
  if not message then return "" end
  -- Remove color codes |cXXXXXXXX and |r
  local clean = string_gsub(message, "|c%x%x%x%x%x%x%x%x", "")
  clean = string_gsub(clean, "|r", "")
  -- Remove hyperlinks |H...|h...|h -> keep the visible text
  clean = string_gsub(clean, "|H[^|]*|h([^|]*)|h", "%1")
  return clean
end

-- [ IsDuplicateMessage ]
-- Checks if a message is a duplicate within the spam filter time window
-- 'message'    [string]        the message text
-- 'sender'     [string]        the sender name
-- return:      [boolean]       true if duplicate, false otherwise
function DBB2.api.IsDuplicateMessage(message, sender)
  if not message then return false end
  
  local spamSeconds = DBB2_Config.spamFilterSeconds or 150
  if spamSeconds <= 0 then
    return false  -- Spam filter disabled
  end
  
  local currentTime = time()
  -- Strip hyperlinks before comparison so [Guild] links with different internal IDs still match
  local lowerMsg = string_lower(DBB2.api.StripHyperlinks(message))
  local lowerSender = string_lower(sender or "")
  local msgCount = table_getn(DBB2.messages)
  
  -- Check existing messages for duplicates
  for i = msgCount, 1, -1 do
    local msg = DBB2.messages[i]
    local timeDiff = currentTime - (msg.time or 0)
    
    -- Only check messages within the spam filter window
    if timeDiff > spamSeconds then
      break  -- Messages are ordered by time, so we can stop here
    end
    
    -- Check if same sender and same message (strip hyperlinks for comparison)
    local storedMsg = string_lower(DBB2.api.StripHyperlinks(msg.message or ""))
    local storedSender = string_lower(msg.sender or "")
    
    if storedSender == lowerSender and storedMsg == lowerMsg then
      return true
    end
  end
  
  return false
end

-- [ RemovePreviousMessageFromSameSender ]
-- Removes any previous message from the same sender that matches the same categories
-- This ensures only the most recent message per sender per category is shown
-- Hardcore messages are excluded from this deduplication
-- 'sender'         [string]        the sender name
-- 'newCategories'  [table]         categories the new message matches (from CategorizeMessage)
-- 'ignoreFilterTags' [boolean]     if true, compare categories without the extra filter tag gate
-- return:          [boolean]       true if a message was removed
function DBB2.api.RemovePreviousMessageFromSameSender(sender, newCategories, ignoreFilterTags)
  if not sender or not newCategories then return false end
  
  -- Skip deduplication for hardcore messages
  if newCategories.isHardcore then return false end
  
  local lowerSender = string_lower(sender)
  local newGroups = newCategories.groups or {}
  local newProfessions = newCategories.professions or {}
  
  -- No categories to dedupe against
  if table_getn(newGroups) == 0 and table_getn(newProfessions) == 0 then
    return false
  end
  
  -- Build lookup tables for new message category names (they are strings)
  local newGroupsLookup = {}
  local newProfessionsLookup = {}
  for _, catName in ipairs(newGroups) do
    newGroupsLookup[catName] = true
  end
  for _, catName in ipairs(newProfessions) do
    newProfessionsLookup[catName] = true
  end
  
  -- Search for previous messages from same sender with overlapping categories
  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    if msg and string_lower(msg.sender or "") == lowerSender then
      -- Check if this old message matches any of the same categories
      local oldCategories = DBB2.api.CategorizeMessage(msg.message, true, ignoreFilterTags)
      if oldCategories and not oldCategories.isHardcore then
        local hasOverlap = false
        
        -- Check groups overlap (category names are strings)
        for _, catName in ipairs(oldCategories.groups or {}) do
          if newGroupsLookup[catName] then
            hasOverlap = true
            break
          end
        end
        
        -- Check professions overlap if no groups overlap found
        if not hasOverlap then
          for _, catName in ipairs(oldCategories.professions or {}) do
            if newProfessionsLookup[catName] then
              hasOverlap = true
              break
            end
          end
        end
        
        -- Remove the old message if categories overlap
        if hasOverlap then
          table_remove(DBB2.messages, i)
          return true
        end
      end
    end
  end
  
  return false
end

-- [ AddMessage ]
-- Adds a new message to the message store
-- Only stores messages that match at least one category (regardless of enabled state)
-- IMPORTANT: System messages (CHAT_MSG_SYSTEM) are ONLY stored if they match hardcore categories
-- This prevents /who results, loot messages, etc. from appearing in Groups/Professions tabs
-- For Groups and Professions: replaces previous message from same sender in same category
-- 'message'    [string]        the message text
-- 'sender'     [string]        the sender name
-- 'channel'    [string]        the channel name
-- 'type'       [string]        the message type (CHAT_MSG_GUILD, CHAT_MSG_CHANNEL, etc)
function DBB2.api.AddMessage(message, sender, channel, msgType)
  -- Guard against nil message
  if not message then return end
  
  -- Clean up expired messages first
  DBB2.api.RemoveExpiredMessages()

  -- Translate Chinese messages to English before categorisation.
  -- This ensures CJK messages pass the category filter (which uses English patterns).
  message = DBB2.api.TranslateCN(message)

  -- Categorize twice:
  -- 1) fullCategories respects filter tags and controls what is actually stored/shown
  -- 2) baseCategories ignores filter tags so a newer reworded message can still clear
  --    an older same-sender entry for the same run instead of leaving stale GUI data behind
  local fullCategories = DBB2.api.CategorizeMessage(message, true)
  local baseCategories = DBB2.api.CategorizeMessage(message, true, true)
  
  -- Check if message matches any category (ignoring enabled state)
  -- This ensures duplicate filter works for all category patterns
  local categories = fullCategories
  local matchesAnyCategory = (table_getn(categories.groups) > 0) or 
                              (table_getn(categories.professions) > 0) or 
                              (table_getn(categories.hardcore) > 0)
  local matchesBaseCategory = (table_getn(baseCategories.groups) > 0) or
                              (table_getn(baseCategories.professions) > 0) or
                              (table_getn(baseCategories.hardcore) > 0)
  
  if not matchesBaseCategory then
    return  -- Message doesn't match any category pattern, ignore it
  end
  
  -- CRITICAL: System messages (like /who results) should ONLY be stored if they match
  -- hardcore categories. This prevents zone names in /who results from polluting
  -- the Groups/Professions tabs (e.g., "Zul'Gurub" in a /who result)
  if msgType == "CHAT_MSG_SYSTEM" then
    local matchesHardcore = table_getn(categories.hardcore) > 0
    if not matchesHardcore then
      return  -- System message doesn't match hardcore, ignore it
    end
  end
  
  -- Check blacklist (only for messages that match categories)
  -- Uses DBB2.api.IsMessageBlacklisted from blacklist.lua
  if DBB2.api.IsMessageBlacklisted(message, sender) then
    return
  end
  
  if DBB2.api.IsDuplicateMessage(message, sender) then
    return
  end
  
  -- Clear stale messages from the same sender using base category overlap so an
  -- updated line can replace an older GUI entry even if it no longer passes the
  -- optional filter tag requirement.
  DBB2.api.RemovePreviousMessageFromSameSender(sender, baseCategories, true)
  
  -- If the message no longer passes the active filter tag gate, stop after clearing
  -- any stale older entry. We do not store/show the new line in the GUI.
  if not matchesAnyCategory then
    return
  end
  
  -- Remove previous message from same sender in same category (Groups/Professions only)
  -- This ensures only the most recent message per sender is shown
  -- Check for notifications before storing (only for selected categories)
  -- Uses DBB2.api.CheckAndNotify from notifications.lua
  -- Pass msgType so system messages only trigger hardcore notifications
  DBB2.api.CheckAndNotify(message, sender, msgType)

  -- Store message
  table_insert(DBB2.messages, {
    message = message,
    sender = sender or "Unknown",
    channel = channel or "",
    time = time(),
    type = msgType or ""
  })
  
  -- Keep only last MAX_MESSAGES messages
  if table_getn(DBB2.messages) > MAX_MESSAGES then
    table_remove(DBB2.messages, 1)
  end
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() then
    -- Update logs tab
    if DBB2.gui.UpdateMessages then
      DBB2.gui:UpdateMessages()
    end
    
    -- Update active categorized tab if showing
    if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
      local activeTab = DBB2.gui.tabs.activeTab
      if activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
        local panel = DBB2.gui.tabs.panels[activeTab]
        if panel and panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end
  end
end

-- [ GetMessages ]
-- Returns all stored messages
-- return:      [table]         array of message objects
function DBB2.api.GetMessages()
  return DBB2.messages
end

-- [ GetMessageCount ]
-- Returns the number of stored messages
-- return:      [number]        message count
function DBB2.api.GetMessageCount()
  return table_getn(DBB2.messages)
end

-- [ ClearMessages ]
-- Clears all stored messages
-- return:      [boolean]       true (always succeeds)
function DBB2.api.ClearMessages()
  DBB2.messages = {}
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() and DBB2.gui.UpdateMessages then
    DBB2.gui:UpdateMessages()
  end
  return true
end

-- [ FilterMessages ]
-- Returns filtered messages based on criteria
-- 'filterType' [string]        filter type: "guild", "channel", "all"
-- 'limit'      [number]        max number of messages to return (optional)
-- return:      [table]         filtered array of message objects
function DBB2.api.FilterMessages(filterType, limit)
  local filtered = {}
  local count = table_getn(DBB2.messages)
  
  -- Default to "all" if no filter type specified
  filterType = filterType or "all"
  
  for i = 1, count do
    local msg = DBB2.messages[i]
    
    if filterType == "all" then
      table_insert(filtered, msg)
    elseif filterType == "guild" and msg.type == "CHAT_MSG_GUILD" then
      table_insert(filtered, msg)
    elseif filterType == "channel" and msg.type == "CHAT_MSG_CHANNEL" then
      table_insert(filtered, msg)
    end
  end
  
  -- Apply limit if specified
  if limit and limit > 0 and table_getn(filtered) > limit then
    local start = table_getn(filtered) - limit + 1
    local limited = {}
    for i = start, table_getn(filtered) do
      table_insert(limited, filtered[i])
    end
    return limited
  end
  
  return filtered
end
```

## api/notifications.lua
```lua
-- DBB2 Notification API
-- Handles alert system for watched categories
--
-- Dependencies: api/categories_api.lua (GetCategories, MatchMessageToCategory)
-- This file must be loaded AFTER categories_api.lua

-- Localize frequently used globals for performance
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs
local GetTime = GetTime

-- =====================
-- NOTIFICATION STATE
-- =====================

-- Session-only notification state (not saved to config)
DBB2.notificationState = {}

-- [ InitNotificationState ]
-- Initializes notification state for all categories (session-only, all off by default)
function DBB2.api.InitNotificationState()
  DBB2.notificationState = {
    groups = {},
    professions = {},
    hardcore = {}
  }
end

-- [ IsNotificationEnabled ]
-- Returns whether notifications are enabled for a specific category
-- 'categoryType'   [string]        the category type (groups, professions, hardcore)
-- 'categoryName'   [string]        the category name
-- return:          [boolean]       true if notifications enabled for this category
function DBB2.api.IsNotificationEnabled(categoryType, categoryName)
  if not DBB2.notificationState[categoryType] then
    return false
  end
  return DBB2.notificationState[categoryType][categoryName] or false
end

-- [ SetNotificationEnabled ]
-- Enables or disables notifications for a specific category
-- 'categoryType'   [string]        the category type (groups, professions, hardcore)
-- 'categoryName'   [string]        the category name
-- 'enabled'        [boolean]       whether to enable notifications
-- return:          [boolean]       true if set successfully
function DBB2.api.SetNotificationEnabled(categoryType, categoryName, enabled)
  if not categoryType or not categoryName then return false end
  if not DBB2.notificationState[categoryType] then
    DBB2.notificationState[categoryType] = {}
  end
  DBB2.notificationState[categoryType][categoryName] = enabled
  return true
end

-- =====================
-- NOTIFICATION CONFIG
-- =====================

-- [ InitNotificationConfig ]
-- Initializes notification config settings
-- mode: 0 = off, 1 = chat only, 2 = raid warning only, 3 = both
function DBB2.api.InitNotificationConfig()
  if not DBB2_Config.notifications then
    DBB2_Config.notifications = {
      mode = 3  -- Default: both
    }
  end
  -- Migrate old config format (chat/raidWarn booleans) to new mode format
  if DBB2_Config.notifications.chat ~= nil or DBB2_Config.notifications.raidWarn ~= nil then
    local chat = DBB2_Config.notifications.chat
    local raid = DBB2_Config.notifications.raidWarn
    if chat and raid then
      DBB2_Config.notifications.mode = 3
    elseif chat then
      DBB2_Config.notifications.mode = 1
    elseif raid then
      DBB2_Config.notifications.mode = 2
    else
      DBB2_Config.notifications.mode = 0
    end
    -- Remove old fields
    DBB2_Config.notifications.chat = nil
    DBB2_Config.notifications.raidWarn = nil
  end
  -- Ensure mode is valid
  if not DBB2_Config.notifications.mode or DBB2_Config.notifications.mode < 0 or DBB2_Config.notifications.mode > 3 then
    DBB2_Config.notifications.mode = 3
  end
end

-- [ GetNotificationMode ]
-- Returns current notification mode (0-3)
-- return:      [number]        0 = off, 1 = chat, 2 = raid warning, 3 = both
function DBB2.api.GetNotificationMode()
  DBB2.api.InitNotificationConfig()
  return DBB2_Config.notifications.mode
end

-- [ SetNotificationMode ]
-- Sets notification mode (0 = off, 1 = chat, 2 = raid warning, 3 = both)
-- 'mode'       [number]        the notification mode (0-3)
function DBB2.api.SetNotificationMode(mode)
  DBB2.api.InitNotificationConfig()
  if mode >= 0 and mode <= 3 then
    DBB2_Config.notifications.mode = mode
  end
end

-- =====================
-- LEGACY COMPATIBILITY
-- =====================

-- [ GetNotificationSettings ]
-- Returns current notification settings (legacy compatibility)
-- Returns table with chat and raidWarn booleans based on mode
-- return:      [table]         {mode, chat, raidWarn}
function DBB2.api.GetNotificationSettings()
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  return {
    mode = mode,
    chat = (mode == 1 or mode == 3),
    raidWarn = (mode == 2 or mode == 3)
  }
end

-- [ SetNotificationChat ]
-- Enables or disables chat notifications (legacy compatibility)
-- 'enabled'    [boolean]       whether to enable chat notifications
function DBB2.api.SetNotificationChat(enabled)
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  if enabled then
    if mode == 0 or mode == 2 then
      DBB2_Config.notifications.mode = mode + 1
    end
  else
    if mode == 1 then
      DBB2_Config.notifications.mode = 0
    elseif mode == 3 then
      DBB2_Config.notifications.mode = 2
    end
  end
end

-- [ SetNotificationRaidWarn ]
-- Enables or disables raid warning notifications (legacy compatibility)
-- 'enabled'    [boolean]       whether to enable raid warning notifications
function DBB2.api.SetNotificationRaidWarn(enabled)
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  if enabled then
    if mode == 0 or mode == 1 then
      DBB2_Config.notifications.mode = mode + 2
    end
  else
    if mode == 2 then
      DBB2_Config.notifications.mode = 0
    elseif mode == 3 then
      DBB2_Config.notifications.mode = 1
    end
  end
end

-- =====================
-- NOTIFICATION QUEUE
-- =====================

-- On-screen notification queue system
DBB2.notificationQueue = {}
DBB2.notificationActive = false
DBB2.notificationTimer = 0

-- Constants for notification timing
local NOTIFICATION_DURATION = 3  -- seconds per notification (display time)
local NOTIFICATION_FADE_BUFFER = 5  -- extra time for fade out before next

-- [ ProcessNotificationQueue ]
-- Process the notification queue (local function)
local function ProcessNotificationQueue()
  if DBB2.notificationActive then return end
  if table_getn(DBB2.notificationQueue) == 0 then return end
  
  -- Get next notification from queue
  local notification = table_remove(DBB2.notificationQueue, 1)
  
  -- Show it
  UIErrorsFrame:AddMessage(notification.text, notification.r, notification.g, notification.b, 1.0, NOTIFICATION_DURATION)
  
  -- Play sound if enabled
  if notification.playSound then
    PlaySoundFile("Interface\\AddOns\\DifficultBulletinBoard\\sound\\duck.wav")
  end
  
  -- Mark as active and set timer (duration + fade buffer)
  DBB2.notificationActive = true
  DBB2.notificationTimer = GetTime() + NOTIFICATION_DURATION + NOTIFICATION_FADE_BUFFER
end

-- [ QueueScreenNotification ]
-- Queue an on-screen notification (local function)
-- 'text'       [string]        the notification text
-- 'r'          [number]        red color component (0-1)
-- 'g'          [number]        green color component (0-1)
-- 'b'          [number]        blue color component (0-1)
-- 'playSound'  [boolean]       whether to play notification sound
local function QueueScreenNotification(text, r, g, b, playSound)
  table_insert(DBB2.notificationQueue, {
    text = text,
    r = r,
    g = g,
    b = b,
    playSound = playSound
  })
  ProcessNotificationQueue()
end

-- =====================
-- NOTIFICATION FRAME
-- =====================

-- Create a frame to handle the queue timer
local notificationFrame = CreateFrame("Frame")
notificationFrame:SetScript("OnUpdate", function()
  if DBB2.notificationActive and GetTime() >= DBB2.notificationTimer then
    DBB2.notificationActive = false
    ProcessNotificationQueue()
  end
end)

-- =====================
-- QUEUE MANAGEMENT
-- =====================

-- [ ClearNotificationQueue ]
-- Clears all pending notifications from the queue
-- Called when joining a group (if clearNotificationsOnGroupJoin is enabled)
function DBB2.api.ClearNotificationQueue()
  DBB2.notificationQueue = {}
  DBB2.notificationActive = false
  DBB2.notificationTimer = 0
end

-- [ DisableAllNotifications ]
-- Disables notifications for all categories and clears the pending queue
-- Called when joining a group (if clearNotificationsOnGroupJoin is enabled)
function DBB2.api.DisableAllNotifications()
  -- Clear the notification state for all category types
  DBB2.notificationState = {
    groups = {},
    professions = {},
    hardcore = {}
  }
  
  -- Also clear any pending notifications in the queue
  DBB2.api.ClearNotificationQueue()
  
  -- Update GUI bell icons if visible
  if DBB2.gui and DBB2.gui:IsShown() and DBB2.gui.tabs then
    local panels = {"Groups", "Professions", "Hardcore"}
    for _, panelName in ipairs(panels) do
      local panel = DBB2.gui.tabs.panels[panelName]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
    end
  end
end

-- =====================
-- NOTIFICATION SENDING
-- =====================

-- [ SendNotification ]
-- Sends a notification for a matched category
-- 'categoryName'   [string]        the category name that matched
-- 'sender'         [string]        the message sender
-- 'message'        [string]        the message text
function DBB2.api.SendNotification(categoryName, sender, message)
  local settings = DBB2.api.GetNotificationSettings()
  
  -- Guard against nil values
  categoryName = categoryName or "Unknown"
  sender = sender or "Unknown"
  message = message or ""
  
  -- Get highlight color for notification text
  local hr, hg, hb = DBB2:GetHighlightColor()
  local hexColor = string_format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
  local notifyText = "|cff" .. hexColor .. "[DBB]|r " .. categoryName .. " - " .. sender .. ": " .. message
  
  if settings.chat then
    -- Use the original AddMessage function to bypass our chat filter hook
    -- This ensures notifications are always shown even when hideFromChat is enabled
    local origFunc = DBB2.originalAddMessage and DBB2.originalAddMessage[1]
    if origFunc then
      origFunc(DEFAULT_CHAT_FRAME, notifyText, 1, 1, 1, nil)
    else
      -- Fallback if hook not installed yet
      DEFAULT_CHAT_FRAME:AddMessage(notifyText)
    end
  end
  
  -- Check if sound should play (only with first notification, not queued ones)
  local soundEnabled = DBB2_Config.notificationSound or 1
  local playSound = (soundEnabled == 1)
  
  if settings.raidWarn then
    -- Queue on-screen notification
    local screenText = "[DBB] " .. categoryName .. " - " .. sender .. ": " .. message
    QueueScreenNotification(screenText, hr, hg, hb, playSound)
  elseif playSound then
    -- Play sound immediately if no raid warn (chat only mode)
    PlaySoundFile("Interface\\AddOns\\DifficultBulletinBoard\\sound\\duck.wav")
  end
end

-- [ CheckAndNotify ]
-- Checks if message matches any category with notifications enabled and sends notification
-- IMPORTANT: System messages (CHAT_MSG_SYSTEM) only trigger hardcore notifications,
-- never groups/professions. This prevents zone names in death messages from triggering dungeon alerts.
-- 'message'    [string]        the message text
-- 'sender'     [string]        the message sender
-- 'msgType'    [string]        optional message type (CHAT_MSG_SYSTEM, CHAT_MSG_CHANNEL, etc)
function DBB2.api.CheckAndNotify(message, sender, msgType)
  if not DBB2.notificationState then return end
  
  -- System messages should ONLY trigger hardcore notifications
  -- This prevents false positives like "Golbolar Quarry" in death messages
  -- triggering alerts for "Hateforge Quarry"
  local isSystemMessage = (msgType == "CHAT_MSG_SYSTEM")
  
  local categoryTypes = {"groups", "professions", "hardcore"}
  
  for _, categoryType in ipairs(categoryTypes) do
    -- Skip groups/professions for system messages
    if isSystemMessage and categoryType ~= "hardcore" then
      -- Do nothing, skip this category type
    else
      local categories = DBB2.api.GetCategories(categoryType)
      if categories then
        for _, cat in ipairs(categories) do
          if cat.selected and DBB2.api.IsNotificationEnabled(categoryType, cat.name) then
            if DBB2.api.MatchMessageToCategory(message, cat, nil, categoryType) then
              DBB2.api.SendNotification(cat.name, sender, message)
              return  -- Only notify once per message
            end
          end
        end
      end
    end
  end
end
```

## api/tooltip.lua
```lua
-- DBB2 Tooltip API
-- Centralized tooltip system for consistent styling across the addon

-- Localize frequently used globals for performance
local table_getn = table.getn
local ipairs = ipairs
local type = type
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

-- [ InitTooltip ]
-- Creates the shared tooltip frame
function DBB2.api.InitTooltip()
  if DBB2.tooltip then return DBB2.tooltip end
  
  local tooltip = CreateFrame("Frame", "DBB2Tooltip", UIParent)
  tooltip:SetFrameStrata("TOOLTIP")
  tooltip:SetFrameLevel(100)
  tooltip:Hide()
  
  -- Create backdrop matching main GUI (but use fixed color, not configurable)
  DBB2:CreateBackdrop(tooltip, nil, nil, 0.95, true)
  
  -- Lines storage
  tooltip.lines = {}
  tooltip.maxLines = 20
  
  -- Pre-create line font strings
  for i = 1, tooltip.maxLines do
    local line = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line:SetJustifyH("LEFT")
    line:Hide()
    tooltip.lines[i] = line
  end
  
  DBB2.tooltip = tooltip
  return tooltip
end

-- [ ShowTooltip ]
-- Shows a tooltip with multiple lines
-- owner:   [frame]   the frame to anchor to
-- anchor:  [string]  anchor position ("RIGHT", "LEFT", "TOP", "BOTTOM", "CURSOR")
-- lines:   [table]   array of lines, each can be:
--                    - string: white text
--                    - {text}: white text
--                    - {text, r, g, b}: colored text
--                    - {text, "highlight"}: uses highlight color
--                    - {text, "gray"}: uses gray color
function DBB2.api.ShowTooltip(owner, anchor, lines)
  -- Guard against nil parameters
  if not lines or table_getn(lines) == 0 then return end
  
  local tooltip = DBB2.api.InitTooltip()
  
  -- Hide all lines first
  for i = 1, tooltip.maxLines do
    tooltip.lines[i]:Hide()
  end
  
  local padding = DBB2:ScaleSize(8)
  local spacing = DBB2:ScaleSize(2)
  local fontSize = DBB2:GetFontSize(10)
  local maxLineWidth = DBB2:ScaleSize(260)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local lineCount = 0
  
  -- Process lines
  for i, lineData in ipairs(lines) do
    if i > tooltip.maxLines then break end
    lineCount = i
    
    local text, r, g, b
    
    if type(lineData) == "string" then
      text = lineData
      r, g, b = 1, 1, 1
    elseif type(lineData) == "table" then
      text = lineData[1]
      if lineData[2] == "highlight" then
        r, g, b = hr, hg, hb
      elseif lineData[2] == "gray" then
        r, g, b = 0.5, 0.5, 0.5
      elseif type(lineData[2]) == "number" then
        r, g, b = lineData[2], lineData[3] or 1, lineData[4] or 1
      else
        r, g, b = 1, 1, 1
      end
    else
      text = ""
      r, g, b = 1, 1, 1
    end
    
    local line = tooltip.lines[i]
    line:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", fontSize)
    line:SetWidth(0)
    line:SetText(text or "")
    line:SetTextColor(r, g, b, 1)
    line:ClearAllPoints()
    
    if i == 1 then
      line:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -padding)
    else
      line:SetPoint("TOPLEFT", tooltip.lines[i-1], "BOTTOMLEFT", 0, -spacing)
    end
    
    line:Show()
  end
  
  -- Force one invisible layout pass so first-hover sizing is correct.
  tooltip:SetWidth(1)
  tooltip:SetHeight(1)
  tooltip:SetAlpha(0)
  tooltip:Show()
  
  local maxWidth = 0
  local totalHeight = padding
  
  for i = 1, lineCount do
    local line = tooltip.lines[i]
    local stringWidth = line:GetStringWidth()
    local lineWidth = stringWidth

    -- Tighten wrapped lines so tooltips don't keep excess empty space on the right.
    if stringWidth > maxLineWidth then
      local low = DBB2:ScaleSize(80)
      local high = maxLineWidth
      local bestWidth = maxLineWidth

      line:SetWidth(maxLineWidth)
      local wrappedHeight = line:GetHeight()

      while low <= high do
        local mid = math_floor((low + high) / 2)
        line:SetWidth(mid)
        if line:GetHeight() <= wrappedHeight then
          bestWidth = mid
          high = mid - 1
        else
          low = mid + 1
        end
      end

      line:SetWidth(bestWidth)
      lineWidth = math_min(bestWidth, stringWidth)
    end

    if lineWidth > maxWidth then
      maxWidth = lineWidth
    end
    totalHeight = totalHeight + line:GetHeight() + spacing
  end
  
  totalHeight = totalHeight + padding - spacing
  
  tooltip:SetWidth(maxWidth + padding * 2)
  tooltip:SetHeight(totalHeight)
  DBB2:CreateBackdrop(tooltip, nil, nil, 0.95, true)
  
  -- Position based on anchor
  tooltip:ClearAllPoints()
  anchor = anchor or "CURSOR"
  
  if anchor == "CURSOR" then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
    
    -- Keep on screen
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local tipWidth = tooltip:GetWidth()
    local tipHeight = tooltip:GetHeight()
    
    if x + 15 + tipWidth > screenWidth then
      tooltip:ClearAllPoints()
      tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - 5, y + 10)
    end
    if y + 10 + tipHeight > screenHeight then
      tooltip:ClearAllPoints()
      tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 15, y - 5)
    end
  elseif anchor == "RIGHT" and owner then
    tooltip:SetPoint("LEFT", owner, "RIGHT", 5, 0)
  elseif anchor == "LEFT" and owner then
    tooltip:SetPoint("RIGHT", owner, "LEFT", -5, 0)
  elseif anchor == "TOP" and owner then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 5)
  elseif anchor == "BOTTOM" and owner then
    tooltip:SetPoint("TOP", owner, "BOTTOM", 0, -5)
  elseif owner then
    -- Default: top-right of owner
    tooltip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 5, 5)
  else
    -- Fallback to cursor position if no owner
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
  end
  
  tooltip:SetAlpha(1)
  tooltip:Show()
end

-- [ HideTooltip ]
-- Hides the tooltip
function DBB2.api.HideTooltip()
  if DBB2.tooltip then
    DBB2.tooltip:Hide()
  end
end

-- [ ShowMessageTooltip ]
-- Shows a tooltip for message display (sender + message)
-- owner:   [frame]   the frame that triggered the tooltip
-- sender:  [string]  sender name (shown in highlight color)
-- message: [string]  message text
function DBB2.api.ShowMessageTooltip(owner, sender, message)
  local tooltip = DBB2.api.InitTooltip()
  
  -- Hide all lines first
  for i = 1, tooltip.maxLines do
    tooltip.lines[i]:Hide()
  end
  
  local padding = DBB2:ScaleSize(8)
  local spacing = DBB2:ScaleSize(4)
  local fontSize = DBB2:GetFontSize(10)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local maxWidth = DBB2:ScaleSize(350)
  
  -- Guard against nil values
  sender = sender or "Unknown"
  message = message or ""
  
  -- Title (sender)
  local titleLine = tooltip.lines[1]
  titleLine:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", fontSize)
  titleLine:SetText(sender)
  titleLine:SetTextColor(hr, hg, hb, 1)
  titleLine:ClearAllPoints()
  titleLine:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -padding)
  titleLine:Show()
  
  -- Message
  local msgLine = tooltip.lines[2]
  msgLine:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", fontSize)
  msgLine:SetWidth(maxWidth)
  msgLine:SetText(message)
  msgLine:SetTextColor(0.9, 0.9, 0.9, 1)
  msgLine:ClearAllPoints()
  msgLine:SetPoint("TOPLEFT", titleLine, "BOTTOMLEFT", 0, -spacing)
  msgLine:Show()
  
  -- Force one invisible layout pass so first-hover sizing is correct.
  tooltip:SetWidth(1)
  tooltip:SetHeight(1)
  tooltip:SetAlpha(0)
  tooltip:Show()
  
  -- Tighten wrapped message width so the tooltip doesn't reserve excessive
  -- empty space on the right. We keep the smallest width that preserves the
  -- current wrapped height.
  local wrappedHeight = msgLine:GetHeight()
  local minWidth = math_max(DBB2:ScaleSize(120), titleLine:GetStringWidth())
  local low = minWidth
  local high = maxWidth
  local bestWidth = maxWidth
  
  while low <= high do
    local mid = math.floor((low + high) / 2)
    msgLine:SetWidth(mid)
    if msgLine:GetHeight() <= wrappedHeight then
      bestWidth = mid
      high = mid - 1
    else
      low = mid + 1
    end
  end
  
  msgLine:SetWidth(bestWidth)
  
  -- Calculate size
  local textWidth = math_min(msgLine:GetStringWidth(), bestWidth)
  local titleWidth = titleLine:GetStringWidth()
  local contentWidth = math_max(bestWidth, titleWidth, textWidth)
  local tooltipWidth = contentWidth + (padding * 2)
  local tooltipHeight = titleLine:GetHeight() + msgLine:GetHeight() + spacing + (padding * 2)
  
  tooltip:SetWidth(tooltipWidth)
  tooltip:SetHeight(tooltipHeight)
  DBB2:CreateBackdrop(tooltip, nil, nil, 0.95, true)
  
  -- Position near cursor
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  x, y = x / scale, y / scale
  
  tooltip:ClearAllPoints()
  tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
  
  -- Keep on screen
  local screenWidth = GetScreenWidth()
  local screenHeight = GetScreenHeight()
  
  if x + 15 + tooltipWidth > screenWidth then
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - 5, y + 10)
  end
  if y + 10 + tooltipHeight > screenHeight then
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 15, y - 5)
  end
  
  -- Store state for message tooltips (used by message rows)
  tooltip.activeData = {sender = sender, message = message}
  tooltip.triggerFrame = owner
  
  tooltip:SetAlpha(1)
  tooltip:Show()
end

-- [ ShouldDismissTooltip ]
-- Check if tooltip should be dismissed
-- Returns false if mouse is still over the trigger frame
function DBB2.api.ShouldDismissTooltip()
  local tooltip = DBB2.tooltip
  if not tooltip or not tooltip.activeData then return true end
  
  -- Keep visible if mouse is still over the trigger frame
  if tooltip.triggerFrame and MouseIsOver(tooltip.triggerFrame) then
    return false
  end
  
  -- Mouse is elsewhere, dismiss
  return true
end

-- [ DismissMessageTooltip ]
-- Dismisses message tooltip and clears state
function DBB2.api.DismissMessageTooltip()
  local tooltip = DBB2.tooltip
  if tooltip then
    tooltip.activeData = nil
    tooltip.triggerFrame = nil
    tooltip:Hide()
  end
end

-- [ GetTooltipActiveData ]
-- Returns the active message tooltip data (if any)
function DBB2.api.GetTooltipActiveData()
  if DBB2.tooltip then
    return DBB2.tooltip.activeData
  end
  return nil
end
```

## api/translate_cn.lua
```lua
-- translate_cn.lua
-- Chinese (Simplified) → English translation pipeline for DifficultBulletinBoard
--
-- Pipeline (applied in order):
--   1. Phrase pass  – ordered rules from dict_cn_phrases
--   2. Misc pass    – greedy longest-match from dict_cn_misc
--
-- Dependencies loaded before this file (per TOC order):
--   api/utils.lua           – DBB2.api.ContainsCJK
--   api/dict_cn_phrases.lua
--   api/dict_cn_misc.lua

local string_gsub   = string.gsub
local string_len    = string.len
local string_byte   = string.byte
local string_sub    = string.sub
local table_getn    = table.getn
local table_insert  = table.insert
local table_sort    = table.sort
local table_concat  = table.concat

-- =====================================================
-- INTERNAL HELPERS
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

local function utf8_chars(str)
  local chars = {}
  local i = 1
  local len = string_len(str)
  while i <= len do
    local clen = utf8_charlen(str, i)
    table_insert(chars, string_sub(str, i, i + clen - 1))
    i = i + clen
  end
  return chars
end

-- =====================================================
-- PHRASE PASS
-- =====================================================

local function apply_phrases(text)
  if not dict_cn_phrases then return text end
  local i = 1
  while i <= table_getn(dict_cn_phrases) do
    local rule = dict_cn_phrases[i]
    if rule.cn and rule.en then
      local replacement = rule.en
      -- Automatically append a trailing space if one doesn't exist
      if type(replacement) == "string" and string_sub(replacement, -1) ~= " " then
        replacement = replacement .. " "
      end
      text = string_gsub(text, rule.cn, replacement)
    end
    i = i + 1
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
-- MISC PASS  (greedy longest-match, left-to-right)
-- =====================================================

local _misc_by_first = nil

local function build_misc_index()
  if _misc_by_first then return end
  _misc_by_first = {}
  if not dict_cn_misc then return end
  for cn, en in pairs(dict_cn_misc) do
    local chars = utf8_chars(cn)
    local first = chars[1]
    if first then
      if not _misc_by_first[first] then
        _misc_by_first[first] = {}
      end
      local bucket = _misc_by_first[first]
      table_insert(bucket, { cn = cn, en = en, len = table_getn(chars) })
    end
  end
  for _, bucket in pairs(_misc_by_first) do
    table_sort(bucket, function(a, b) return a.len > b.len end)
  end
end

local function apply_misc(text)
  if not dict_cn_misc then return text end
  build_misc_index()

  local chars = utf8_chars(text)
  local total = table_getn(chars)
  local out   = {}
  local i     = 1

  while i <= total do
    local ch     = chars[i]
    local bucket = _misc_by_first[ch]
    local matched = false

    if bucket then
      local b = 1
      while b <= table_getn(bucket) do
        local entry = bucket[b]
        local klen  = entry.len
        if i + klen - 1 <= total then
          local slice = ""
          local j = 0
          while j < klen do
            slice = slice .. chars[i + j]
            j = j + 1
          end
          if slice == entry.cn then
            local translation = entry.en
            -- Automatically append a trailing space if one doesn't exist
            if string_sub(translation, -1) ~= " " then
              translation = translation .. " "
            end
            table_insert(out, translation)
            i = i + klen
            matched = true
            break
          end
        end
        b = b + 1
      end
    end

    if not matched then
      table_insert(out, ch)
      i = i + 1
    end
  end

  return table_concat(out)
end

-- =====================================================
-- PUBLIC API
-- =====================================================

function DBB2.api.TranslateCN(message)
  if not message or message == "" then
    return message
  end
  if not DBB2.api.ContainsCJK(message) then
    return message
  end
  local result = apply_phrases(message)
  result = apply_misc(result)

  -- =====================================================
  -- POST-TRANSLATION CLEANUP (Self-Healing Space Engine)
  -- =====================================================
  -- 1. Collapse duplicate multi-spaces created by back-to-back words into single spaces
  result = string_gsub(result, "%s+", " ")
  -- 2. Strip any trailing whitespaces off the absolute end of the sentence
  result = string_gsub(result, "%s+$", "")

  return result
end
```

## api/utils.lua
```lua
-- DBB2 Utilities API
-- General utility functions: frame position persistence, table utilities, time formatting

-- Localize frequently used globals for performance
local table_getn = table.getn
local pairs = pairs
local type = type
local time = time
local date = date
local math_floor = math.floor
local math_mod = math.mod
local string_format = string.format

-- =====================================================
-- FRAME POSITION UTILITIES
-- =====================================================
-- Functions for saving and loading frame positions to saved variables.

-- [ SavePosition ]
-- Saves the position and size of a frame to saved variables
-- @param frame  [Frame]   The frame to save position for
-- @return       [boolean] true if saved successfully, false if invalid frame
function DBB2.api.SavePosition(frame)
  if not frame then return false end
  local name = frame:GetName()
  if not name then return false end
  
  local anchor, _, _, xpos, ypos = frame:GetPoint()
  
  DBB2_Config.position = DBB2_Config.position or {}
  DBB2_Config.position[name] = {
    anchor = anchor or "CENTER",
    xpos = xpos or 0,
    ypos = ypos or 0,
    width = frame:GetWidth(),
    height = frame:GetHeight()
  }
  return true
end

-- [ LoadPosition ]
-- Loads the saved position and size of a frame
-- @param frame  [Frame]   The frame to load position for
-- @return       [boolean] true if loaded successfully, false if no saved position
function DBB2.api.LoadPosition(frame)
  if not frame then return false end
  local name = frame:GetName()
  if not name then return false end
  
  if DBB2_Config.position and DBB2_Config.position[name] then
    local pos = DBB2_Config.position[name]
    
    frame:ClearAllPoints()
    frame:SetPoint(pos.anchor or "CENTER", pos.xpos or 0, pos.ypos or 0)
    
    if pos.width and pos.width > 0 then
      frame:SetWidth(pos.width)
    end
    
    if pos.height and pos.height > 0 then
      frame:SetHeight(pos.height)
    end
    return true
  end
  return false
end

-- =====================================================
-- TABLE UTILITIES
-- =====================================================
-- General table manipulation functions.

-- [ DeepCopy ]
-- Creates a deep copy of a table (preserves array structure)
-- @param orig  [table]  The table to copy
-- @return      [any]    Deep copy of the input (or the input itself if not a table)
function DBB2.api.DeepCopy(orig)
  if type(orig) ~= "table" then return orig end
  
  local copy = {}
  -- First copy array part
  for i = 1, table_getn(orig) do
    if type(orig[i]) == "table" then
      copy[i] = DBB2.api.DeepCopy(orig[i])
    else
      copy[i] = orig[i]
    end
  end
  -- Then copy hash part
  for k, v in pairs(orig) do
    if type(k) ~= "number" or k < 1 or k > table_getn(orig) then
      if type(v) == "table" then
        copy[k] = DBB2.api.DeepCopy(v)
      else
        copy[k] = v
      end
    end
  end
  return copy
end

-- =====================================================
-- TIME FORMATTING UTILITIES
-- =====================================================
-- Functions for formatting timestamps in various display modes.

-- [ FormatRelativeTime ]
-- Formats a timestamp as relative time (e.g., "<1m", "2m", "15m", "1h")
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted relative time string
function DBB2.api.FormatRelativeTime(timestamp)
  if not timestamp then return "?" end
  
  local now = time()
  local diff = now - timestamp
  if diff < 0 then diff = 0 end
  
  if diff < 60 then
    return "<1m"
  elseif diff < 120 then
    return "2m"
  elseif diff < 3600 then
    local minutes = math_floor(diff / 60)
    return minutes .. "m"
  else
    local hours = math_floor(diff / 3600)
    local minutes = math_floor(math_mod(diff, 3600) / 60)
    if minutes > 0 then
      return hours .. "h" .. minutes .. "m"
    else
      return hours .. "h"
    end
  end
end

-- [ FormatRelativeTimeHMS ]
-- Formats a timestamp as MM:SS format, caps at 59:59 with overflow flag
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted MM:SS string
-- @return           [boolean] true if capped at 59:59 (over an hour old)
function DBB2.api.FormatRelativeTimeHMS(timestamp)
  if not timestamp then return "00:00", false end
  
  local now = time()
  local diff = now - timestamp
  if diff < 0 then diff = 0 end
  
  local hours = math_floor(diff / 3600)
  local minutes = math_floor(math_mod(diff, 3600) / 60)
  local seconds = math_floor(math_mod(diff, 60))
  
  -- Cap at 59:59 if over an hour
  if hours >= 1 then
    return "59:59", true
  end
  
  return string_format("%02d:%02d", minutes, seconds), false
end

-- [ FormatMessageTime ]
-- Returns time format based on config: 0=HH:MM:SS, 1=Relative, 2=Elapsed MM:SS
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted time string
-- @return           [boolean] Overflow flag (only for elapsed mode)
function DBB2.api.FormatMessageTime(timestamp)
  if DBB2_Config.timeDisplayMode == 1 then
    return DBB2.api.FormatRelativeTime(timestamp), false
  elseif DBB2_Config.timeDisplayMode == 2 then
    return DBB2.api.FormatRelativeTimeHMS(timestamp)
  else
    return date("%H:%M:%S", timestamp), false
  end
end

-- =====================================================
-- CJK / UNICODE UTILITIES
-- =====================================================
-- Helpers for detecting and handling Chinese/Japanese/Korean text.

-- [ ContainsCJK ]
-- Returns true if the string contains at least one CJK Unified Ideograph
-- (U+4E00–U+9FFF) encoded as UTF-8.
-- Used to decide whether a message needs the CJK font path.
-- @param str  [string]  UTF-8 encoded string to test
-- @return     [boolean]
function DBB2.api.ContainsCJK(str)
  if not str or str == "" then return false end
  local i = 1
  local len = string.len(str)
  while i <= len do
    local b1 = string.byte(str, i)
    -- 3-byte UTF-8 sequence: 224–239
    if b1 and b1 >= 224 and b1 < 240 then
      local b2 = string.byte(str, i + 1) or 0
      local b3 = string.byte(str, i + 2) or 0
      -- Decode the codepoint
      local cp = ((b1 - 224) * 4096)
               + ((b2 - 128) * 64)
               + (b3 - 128)
      -- CJK Unified Ideographs: U+4E00–U+9FFF
      -- CJK Extension A:        U+3400–U+4DBF
      -- CJK Compatibility:      U+F900–U+FAFF
      if (cp >= 19968 and cp <= 40959)
      or (cp >= 13312 and cp <= 19903)
      or (cp >= 63744 and cp <= 64255) then
        return true
      end
      i = i + 3
    elseif b1 and b1 >= 128 then
      -- 2-byte or 4-byte sequence — skip correctly
      if b1 < 224 then i = i + 2
      else i = i + 4
      end
    else
      i = i + 1
    end
  end
  return false
end
```

## api/wildcards.lua
```lua
-- DBB2 Wildcards API
-- Provides wildcard pattern matching for Lua 5.0 (WoW 1.12.1)
-- Simple, intuitive syntax familiar to users from file searching

--[[
================================================================================
                          DBB2 WILDCARDS USER GUIDE
================================================================================

This addon supports wildcard patterns for blacklist filtering.
All matching is CASE-INSENSITIVE by default.

--------------------------------------------------------------------------------
                              QUICK REFERENCE
--------------------------------------------------------------------------------

  PATTERN         MEANING                      EXAMPLE
  -------         -------                      -------
  *               Any characters (0 or more)   *day matches "Monday", "day"
  ?               Any single character         P?rt matches "Part", "Port"
  [abc]           Any of these characters      [aeiou] matches any vowel
  [a-z]           Character range              [0-9] matches any digit
  [!abc]          NOT these characters         [!0-9] matches non-digits
  {a,b,c}         Any of these words           {cat,dog} matches "cat" or "dog"
]]

-- Localize frequently used globals
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

-- Initialize wildcards API namespace
DBB2.api.wildcards = {}

-- [ ConvertWildcardToLua ]
-- Converts a wildcard pattern to a Lua pattern
-- Supports: * ? [abc] [a-z] [!abc] {a,b,c}
-- 'wildcard'   [string]        the wildcard pattern
-- return:      [string/table]  Lua pattern string, or table of patterns for alternation
local function ConvertWildcardToLua(wildcard)
  if not wildcard or wildcard == "" then return "" end
  
  local len = string_len(wildcard)
  local result = ""
  local i = 1
  local alternations = nil  -- Will hold {a,b,c} expansions if found
  
  while i <= len do
    local c = string_sub(wildcard, i, i)
    local nextChar = ""
    if i < len then nextChar = string_sub(wildcard, i+1, i+1) end
    
    if c == "\\" and nextChar ~= "" then
      -- Escaped character - treat next char as literal
      -- Escape it for Lua pattern if needed
      if string_find(nextChar, "[%(%)%.%%%+%-%*%?%[%]%^%$]") then
        result = result .. "%" .. nextChar
      else
        result = result .. nextChar
      end
      i = i + 2
      
    elseif c == "*" then
      -- * = zero or more of any character
      result = result .. ".*"
      i = i + 1
      
    elseif c == "?" then
      -- ? = exactly one character
      result = result .. "."
      i = i + 1
      
    elseif c == "[" then
      -- Character class: [abc], [a-z], [!abc]
      local classEnd = string_find(wildcard, "]", i + 1, true)
      if classEnd then
        local classContent = string_sub(wildcard, i + 1, classEnd - 1)
        
        -- Check for negation [!...]
        if string_sub(classContent, 1, 1) == "!" then
          -- Convert [!abc] to [^abc]
          result = result .. "[^" .. string_sub(classContent, 2) .. "]"
        else
          -- Pass through as-is (Lua supports [abc] and [a-z])
          result = result .. "[" .. classContent .. "]"
        end
        i = classEnd + 1
      else
        -- No closing bracket, treat [ as literal
        result = result .. "%["
        i = i + 1
      end
      
    elseif c == "{" then
      -- Alternation: {a,b,c}
      local braceEnd = string_find(wildcard, "}", i + 1, true)
      if braceEnd then
        local altContent = string_sub(wildcard, i + 1, braceEnd - 1)
        -- IMPORTANT: Use the original wildcard prefix, not the converted result
        -- 'result' contains Lua patterns (e.g., ".*"), but we need the original
        -- wildcard syntax (e.g., "*") for recursive conversion
        local beforeWildcard = string_sub(wildcard, 1, i - 1)
        local after = string_sub(wildcard, braceEnd + 1)
        
        -- Split by comma and create multiple patterns
        alternations = {}
        local altStart = 1
        local altLen = string_len(altContent)
        
        for j = 1, altLen do
          local ac = string_sub(altContent, j, j)
          if ac == "," then
            local alt = string_sub(altContent, altStart, j - 1)
            table_insert(alternations, alt)
            altStart = j + 1
          end
        end
        -- Don't forget the last alternative
        if altStart <= altLen then
          table_insert(alternations, string_sub(altContent, altStart))
        end
        
        -- Build full patterns for each alternative
        local fullPatterns = {}
        for _, alt in ipairs(alternations) do
          -- Recursively convert using original wildcard syntax (not Lua patterns)
          local altPattern = ConvertWildcardToLua(beforeWildcard .. alt .. after)
          if type(altPattern) == "table" then
            -- Nested alternation - flatten
            for _, p in ipairs(altPattern) do
              table_insert(fullPatterns, p)
            end
          else
            table_insert(fullPatterns, altPattern)
          end
        end
        return fullPatterns
      else
        -- No closing brace, treat { as literal
        result = result .. "%{"
        i = i + 1
      end
      
    elseif c == "}" then
      -- Unmatched }, treat as literal
      result = result .. "%}"
      i = i + 1
      
    elseif c == "]" then
      -- Unmatched ], treat as literal
      result = result .. "%]"
      i = i + 1
      
    else
      -- Regular character - escape if it's a Lua pattern special char
      if string_find(c, "[%(%)%.%%%+%-%^%$]") then
        result = result .. "%" .. c
      else
        result = result .. c
      end
      i = i + 1
    end
  end
  
  return result
end

-- [ IsWildcardPattern ]
-- Checks if a string contains wildcard special characters
-- 'pattern'    [string]        the pattern to check
-- return:      [boolean]       true if contains wildcard syntax
function DBB2.api.wildcards.IsWildcardPattern(pattern)
  if not pattern then return false end
  -- Check for wildcard metacharacters: * ? [ ] { }
  -- Also check for escape sequences which indicate intentional pattern usage
  if string_find(pattern, "[%*%?%[%]%{%}\\]") then
    return true
  end
  return false
end

-- [ Match ]
-- Tests if a wildcard pattern matches anywhere in the text
-- 'text'       [string]        the text to search in
-- 'wildcard'   [string]        the wildcard pattern
-- 'ignoreCase' [boolean]       if true (default), match case-insensitively
-- return:      [boolean]       true if pattern matches
function DBB2.api.wildcards.Match(text, wildcard, ignoreCase)
  if not text or not wildcard then return false end
  if wildcard == "" then return true end
  
  if ignoreCase == nil then ignoreCase = true end
  
  local searchText = text
  local searchWildcard = wildcard
  
  if ignoreCase then
    searchText = string_lower(text)
    searchWildcard = string_lower(wildcard)
  end
  
  local pattern = ConvertWildcardToLua(searchWildcard)
  
  if type(pattern) == "table" then
    -- Has alternations - try each pattern
    for _, p in ipairs(pattern) do
      local success, result = pcall(string_find, searchText, p)
      if success and result then
        return true
      end
    end
    return false
  else
    -- Single pattern
    local success, result = pcall(string_find, searchText, pattern)
    return success and result ~= nil
  end
end

-- [ Find ]
-- Finds the first match of a wildcard pattern in text
-- 'text'       [string]        the text to search in
-- 'wildcard'   [string]        the wildcard pattern
-- 'ignoreCase' [boolean]       if true (default), match case-insensitively
-- return:      [number, number, string] start, end, matched text (or nil if no match)
function DBB2.api.wildcards.Find(text, wildcard, ignoreCase)
  if not text or not wildcard then return nil end
  if wildcard == "" then return 1, 0, "" end
  
  if ignoreCase == nil then ignoreCase = true end
  
  local searchText = text
  local searchWildcard = wildcard
  
  if ignoreCase then
    searchText = string_lower(text)
    searchWildcard = string_lower(wildcard)
  end
  
  local pattern = ConvertWildcardToLua(searchWildcard)
  
  if type(pattern) == "table" then
    -- Has alternations - try each pattern
    for _, p in ipairs(pattern) do
      local success, s, e = pcall(string_find, searchText, p)
      if success and s then
        return s, e, string_sub(text, s, e)
      end
    end
    return nil
  else
    -- Single pattern
    local success, s, e = pcall(string_find, searchText, pattern)
    if success and s then
      return s, e, string_sub(text, s, e)
    end
    return nil
  end
end

-- [ IsValid ]
-- Checks if a wildcard pattern is valid (won't cause errors)
-- 'wildcard'   [string]        the pattern to validate
-- return:      [boolean, string] true if valid, or false with error message
function DBB2.api.wildcards.IsValid(wildcard)
  if not wildcard then return false, "Pattern is nil" end
  if wildcard == "" then return true, nil end
  
  local pattern = ConvertWildcardToLua(wildcard)
  
  if type(pattern) == "table" then
    -- Check each alternation
    for _, p in ipairs(pattern) do
      local success, result = pcall(string_find, "test", p)
      if not success then
        return false, result
      end
    end
    return true, nil
  else
    local success, result = pcall(string_find, "test", pattern)
    if not success then
      return false, result
    end
    return true, nil
  end
end

-- [ Escape ]
-- Escapes a string so it can be used as a literal in a wildcard pattern
-- 'str'        [string]        the string to escape
-- return:      [string]        escaped string safe for use in patterns
function DBB2.api.wildcards.Escape(str)
  if not str then return "" end
  -- Escape wildcard special characters: * ? [ ] { } \
  local escaped = str
  escaped = string_gsub(escaped, "\\", "\\\\")
  escaped = string_gsub(escaped, "%*", "\\*")
  escaped = string_gsub(escaped, "%?", "\\?")
  escaped = string_gsub(escaped, "%[", "\\[")
  escaped = string_gsub(escaped, "%]", "\\]")
  escaped = string_gsub(escaped, "%{", "\\{")
  escaped = string_gsub(escaped, "%}", "\\}")
  return escaped
end

-- [ GetLuaPattern ]
-- Returns the converted Lua pattern (for debugging)
-- 'wildcard'   [string]        the wildcard pattern
-- return:      [string/table]  Lua pattern(s)
function DBB2.api.wildcards.GetLuaPattern(wildcard)
  return ConvertWildcardToLua(wildcard)
end

-- =====================================================
-- CONVENIENCE WRAPPER (matches old regex API signature)
-- =====================================================

-- [ MatchWildcard ]
-- Convenience wrapper for wildcard matching (exposed at api level)
-- 'text'       [string]        the text to search in
-- 'pattern'    [string]        the wildcard pattern
-- return:      [boolean]       true if pattern matches anywhere in text
function DBB2.api.MatchWildcard(text, pattern)
  return DBB2.api.wildcards.Match(text, pattern, true)
end

```

## DifficultBulletinBoard.lua
```lua
-- Create main addon namespace
DBB2 = CreateFrame("Frame", nil, UIParent)
DBB2:RegisterEvent("ADDON_LOADED")
DBB2:RegisterEvent("PLAYER_ENTERING_WORLD")
DBB2:RegisterEvent("CHAT_MSG_CHANNEL")
DBB2:RegisterEvent("CHAT_MSG_GUILD")
DBB2:RegisterEvent("CHAT_MSG_SAY")
DBB2:RegisterEvent("CHAT_MSG_YELL")
DBB2:RegisterEvent("CHAT_MSG_PARTY")
DBB2:RegisterEvent("CHAT_MSG_WHISPER")
DBB2:RegisterEvent("CHAT_MSG_SYSTEM")
DBB2:RegisterEvent("UPDATE_INSTANCE_INFO")
DBB2:RegisterEvent("CHAT_MSG_HARDCORE")  -- Turtle WoW hardcore chat
DBB2:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")  -- Channel join/leave notifications
DBB2:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- Party join/leave for notification clearing
DBB2:RegisterEvent("RAID_ROSTER_UPDATE")  -- Raid join/leave for notification clearing

-- Initialize saved variables
DBB2_Config = {}

-- Initialize addon tables
DBB2.messages = {}
DBB2.modules = {}
DBB2.api = {}  -- Initialize API table
DBB2.pendingMessages = {}  -- Queue for messages to display after login

-- Store minimap button angle
if not DBB2_Config.minimapAngle then
  DBB2_Config.minimapAngle = 45
end

-- Backdrop definitions
DBB2.backdrop = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", 
  tile = false, 
  tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", 
  edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}

DBB2.backdrop_shadow = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 8,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

-- Helper function to create backdrop
-- useFixedBg: if true, uses the default dark charcoal instead of configurable color
function DBB2:CreateBackdrop(frame, inset, legacy, transp, useFixedBg)
  local border = 1
  
  -- Use configurable background color (with fallback to default dark charcoal)
  -- Unless useFixedBg is true, then always use the default
  local br, bg, bb, ba
  if useFixedBg then
    br, bg, bb, ba = 0.08, 0.08, 0.10, 0.85
  else
    local bgColor = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    br, bg, bb, ba = bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85
  end
  local er, eg, eb, ea = 0.25, 0.25, 0.25, 1  -- Border: subtle gray
  
  -- Override transparency if specified
  if transp and transp < ba then ba = transp end
  
  if not frame.backdrop then
    local b = CreateFrame("Frame", nil, frame)
    local level = frame:GetFrameLevel()
    if level < 1 then
      b:SetFrameLevel(level)
    else
      b:SetFrameLevel(level - 1)
    end
    frame.backdrop = b
  end
  
  frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -border, border)
  frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", border, -border)
  frame.backdrop:SetBackdrop(DBB2.backdrop)
  frame.backdrop:SetBackdropColor(br, bg, bb, ba)
  frame.backdrop:SetBackdropBorderColor(er, eg, eb, ea)
end

-- Helper function to create shadow
function DBB2:CreateBackdropShadow(frame)
  if frame.backdrop_shadow then return end
  
  local anchor = frame.backdrop or frame
  frame.backdrop_shadow = CreateFrame("Frame", nil, anchor)
  frame.backdrop_shadow:SetFrameStrata("BACKGROUND")
  frame.backdrop_shadow:SetFrameLevel(1)
  frame.backdrop_shadow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
  frame.backdrop_shadow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
  frame.backdrop_shadow:SetBackdrop(DBB2.backdrop_shadow)
  frame.backdrop_shadow:SetBackdropBorderColor(0, 0, 0, 0.8)
end

-- Helper function to queue a message for display after login
-- Used by modules that run during ADDON_LOADED when chat frame may not be ready
function DBB2:QueueMessage(msg)
  table.insert(DBB2.pendingMessages, msg)
end

-- Event handler
DBB2:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
    -- Initialize config with defaults if needed
    DBB2_Config = DBB2_Config or {}
    
    if not DBB2_Config.initialized then
      DBB2_Config.initialized = true
      DBB2_Config.version = "1.0.0"
      DBB2_Config.position = {}
      DBB2_Config.fontOffset = 0  -- Font size offset (-6 to +6)
      DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}  -- Default highlight color (#aaa7cc)
      DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}  -- Default background color (dark charcoal)
      DBB2_Config.spamFilterSeconds = 150  -- Duplicate message filter time
      DBB2_Config.messageExpireMinutes = 15  -- Auto-remove messages older than X minutes (0 = disabled)
      DBB2_Config.hideFromChat = 0  -- Hide captured messages from chat (0=off, 1=selected, 2=all)
      DBB2_Config.maxMessagesPerCategory = 5  -- Max messages shown per category (0 = unlimited)
      DBB2_Config.scrollSpeed = 55  -- Scroll speed (pixels per wheel tick)
      DBB2_Config.defaultTab = 0  -- Default tab (0=Logs, 1=Groups, 2=Professions, 3=Hardcore)
      DBB2_Config.showCurrentTime = true  -- Show current time above timestamps
      DBB2_Config.timeDisplayMode = 2  -- Time format (0=timestamp, 1=relative, 2=elapsed)
      DBB2_Config.showLevelFilteredGroups = false  -- Level filter for groups tab
      DBB2_Config.showGroupLevelRanges = true  -- Show recommended dungeon level ranges in Groups tab
      DBB2_Config.notificationSound = 1  -- Notification sound (0=off, 1=on)
      DBB2_Config.clearNotificationsOnGroupJoin = true  -- Clear notifications when joining group
      DBB2_Config.autoJoinChannels = true  -- Auto-join World and LFG channels
      DBB2_Config.minimapAngle = 45  -- Minimap button angle
      DBB2_Config.minimapFreeMode = false  -- Minimap button free positioning mode
      DBB2_Config.clampToScreen = true  -- Prevent dragging frames off-screen
      DBB2_Config.closeOnEscape = true  -- Allow the Escape key to close the main window
    end
    
    -- Ensure fontOffset exists for existing configs and is within safe bounds
    if DBB2_Config.fontOffset == nil or type(DBB2_Config.fontOffset) ~= "number" then
      DBB2_Config.fontOffset = 0
    end
    -- Clamp fontOffset to safe range (-6 to +6) to prevent crashes
    if DBB2_Config.fontOffset < -6 then
      DBB2_Config.fontOffset = -6
    elseif DBB2_Config.fontOffset > 6 then
      DBB2_Config.fontOffset = 6
    end
    
    -- Ensure highlightColor exists for existing configs
    if DBB2_Config.highlightColor == nil then
      DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}
    end
    
    -- Ensure backgroundColor exists for existing configs
    if DBB2_Config.backgroundColor == nil then
      DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    end
    
    -- Ensure spamFilterSeconds exists for existing configs
    if DBB2_Config.spamFilterSeconds == nil then
      DBB2_Config.spamFilterSeconds = 150
    end
    
    -- Ensure maxMessagesPerCategory exists for existing configs
    if DBB2_Config.maxMessagesPerCategory == nil then
      DBB2_Config.maxMessagesPerCategory = 5
    end
    
    -- Ensure messageExpireMinutes exists for existing configs
    if DBB2_Config.messageExpireMinutes == nil then
      DBB2_Config.messageExpireMinutes = 15
    end
    
    -- Ensure hideFromChat exists for existing configs (migrate boolean to number)
    if DBB2_Config.hideFromChat == nil then
      DBB2_Config.hideFromChat = 0
    elseif DBB2_Config.hideFromChat == true then
      DBB2_Config.hideFromChat = 1
    elseif DBB2_Config.hideFromChat == false then
      DBB2_Config.hideFromChat = 0
    end
    
    -- Ensure scrollSpeed exists for existing configs
    if DBB2_Config.scrollSpeed == nil then
      DBB2_Config.scrollSpeed = 55
    end
    
    -- Ensure showLevelFilteredGroups exists for existing configs (default off)
    if DBB2_Config.showLevelFilteredGroups == nil then
      DBB2_Config.showLevelFilteredGroups = false
    end

    -- Ensure showGroupLevelRanges exists for existing configs (default on)
    if DBB2_Config.showGroupLevelRanges == nil then
      DBB2_Config.showGroupLevelRanges = true
    end
    
    -- Ensure autoJoinChannels exists for existing configs (default on)
    if DBB2_Config.autoJoinChannels == nil then
      DBB2_Config.autoJoinChannels = true
    end
    
    -- Ensure defaultTab exists for existing configs (default 0 = Logs)
    if DBB2_Config.defaultTab == nil then
      DBB2_Config.defaultTab = 0
    end
    
    -- Ensure showCurrentTime exists for existing configs (default on)
    if DBB2_Config.showCurrentTime == nil then
      DBB2_Config.showCurrentTime = true
    end
    
    -- Ensure timeDisplayMode exists for existing configs (default elapsed)
    if DBB2_Config.timeDisplayMode == nil then
      DBB2_Config.timeDisplayMode = 2
    end
    
    -- Ensure notificationSound exists for existing configs (default on)
    if DBB2_Config.notificationSound == nil then
      DBB2_Config.notificationSound = 1
    end
    
    -- Ensure clearNotificationsOnGroupJoin exists for existing configs (default on)
    if DBB2_Config.clearNotificationsOnGroupJoin == nil then
      DBB2_Config.clearNotificationsOnGroupJoin = true
    end
    
    -- Ensure minimap button position fields exist for existing configs
    if DBB2_Config.minimapAngle == nil then
      DBB2_Config.minimapAngle = 45
    end
    if DBB2_Config.minimapFreeMode == nil then
      DBB2_Config.minimapFreeMode = false
    end
    -- minimapFreePos can be nil (means not in free mode)
    
    -- Ensure clampToScreen exists for existing configs (default on)
    if DBB2_Config.clampToScreen == nil then
      DBB2_Config.clampToScreen = true
    end

    -- Ensure closeOnEscape exists for existing configs (default on)
    if DBB2_Config.closeOnEscape == nil then
      DBB2_Config.closeOnEscape = true
    end
    
    -- Load modules (use ipairs to preserve load order from TOC file)
    for i, module in ipairs(DBB2.modules) do
      if module then
        module()
      end
    end
    
    -- Initialize notification state (session-only, all off by default)
    DBB2.api.InitNotificationState()
    
    -- Setup chat filter hook for hiding captured messages
    DBB2.api.SetupChatFilter()
    
    -- Initialize lockout tracking
    DBB2.api.InitLockouts()
    
    -- Initialize channel monitoring config
    DBB2.api.InitChannelConfig()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccDifficult|cffffffffBulletinBoard |cff555555v" .. (GetAddOnMetadata("DifficultBulletinBoard", "Version") or "?") .. "|r loaded. Click minimap button to open.")
  end
  
  if event == "PLAYER_ENTERING_WORLD" then
    -- Display any queued messages from module initialization
    if table.getn(DBB2.pendingMessages) > 0 then
      for _, msg in ipairs(DBB2.pendingMessages) do
        DEFAULT_CHAT_FRAME:AddMessage(msg)
      end
      DBB2.pendingMessages = {}
    end
    
    -- Clear hardcore detection cache to force fresh detection on each login/switch
    DBB2_Config.isHardcoreCharacter = nil
    local isHardcore = DBB2.api.DetectHardcoreCharacter()
    
    -- For hardcore characters, apply defaults ONLY if user hasn't customized channels yet
    -- Once user makes any change, their preferences are saved like normal characters
    if isHardcore and not DBB2_Config.hardcoreChannelsInitialized then
      DBB2_Config.hardcoreChannelsInitialized = true
      DBB2.api.SetChannelMonitored("World", false)
      DBB2.api.SetChannelMonitored("LookingForGroup", false)
      DBB2.api.SetChannelMonitored("General", false)
      DBB2.api.SetChannelMonitored("Trade", false)
      DBB2.api.SetChannelMonitored("Say", false)
      DBB2.api.SetChannelMonitored("Yell", false)
      DBB2.api.SetChannelMonitored("Whisper", false)
      DBB2.api.SetChannelMonitored("Party", false)
      DBB2.api.SetChannelMonitored("LocalDefense", false)
      DBB2.api.SetChannelMonitored("WorldDefense", false)
      DBB2.api.SetChannelMonitored("GuildRecruitment", false)
      DBB2.api.SetChannelMonitored("\228\184\150\231\149\140", false)
    end
    
    -- Rebuild channel config panel if it exists (updates states)
    if DBB2.gui and DBB2.gui.configTabs and DBB2.gui.configTabs.panels then
      local channelsPanel = DBB2.gui.configTabs.panels["Channels"]
      if channelsPanel and channelsPanel.RebuildChannelCheckboxes then
        channelsPanel.RebuildChannelCheckboxes()
      end
    end
    
    -- Auto-join required channels (World, LookingForGroup) if not already joined
    -- Use a small delay to ensure channel system is ready
    if not DBB2._autoJoinScheduled then
      DBB2._autoJoinScheduled = true
      -- Create a frame for the delayed call
      local delayFrame = CreateFrame("Frame")
      delayFrame.elapsed = 0
      delayFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 2 then  -- 2 second delay
          DBB2.api.AutoJoinRequiredChannels()
          this:SetScript("OnUpdate", nil)
          this:Hide()
        end
      end)
    end
  end
  
  if event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_GUILD" then
    -- Capture chat messages using API
    local message = arg1
    local sender = arg2
    local channel = arg9 or "Guild"
    
    -- For Guild messages, check if Guild channel is monitored
    if event == "CHAT_MSG_GUILD" then
      if not DBB2.api.IsChannelMonitored("Guild") then
        return  -- Guild channel not monitored, ignore
      end
    end
    
    -- For channel messages, only capture from whitelisted LFG-relevant channels
    -- This automatically filters out addon channels like TTRP, XTENSIONXTOOLTIP, etc.
    if event == "CHAT_MSG_CHANNEL" then
      if not DBB2.api.IsChannelWhitelisted(channel) then
        return  -- Not an LFG channel, ignore
      end
      
      -- Ignore World channel when hardcore is active
      local lowerChannel = string.lower(channel or "")
      if DBB2.api.IsHardcoreChatActive() and lowerChannel == "world" then
        return
      end
    end
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_WHISPER" then
    -- Capture Say, Yell, Party, Whisper messages
    local message = arg1
    local sender = arg2
    local channel
    
    if event == "CHAT_MSG_SAY" then
      channel = "Say"
    elseif event == "CHAT_MSG_YELL" then
      channel = "Yell"
    elseif event == "CHAT_MSG_WHISPER" then
      channel = "Whisper"
    else
      channel = "Party"
    end
    
    -- Check if this channel is monitored
    if not DBB2.api.IsChannelMonitored(channel) then
      return
    end
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "CHAT_MSG_HARDCORE" then
    -- Turtle WoW hardcore chat messages
    local message = arg1
    local sender = arg2
    
    -- Check if Hardcore channel is monitored
    if not DBB2.api.IsChannelMonitored("Hardcore") then
      return  -- Hardcore channel not monitored, ignore
    end
    
    -- Mark hardcore chat as active (enables auto-switch from World)
    if not DBB2.api.IsHardcoreChatActive() then
      DBB2.api.SetHardcoreChatActive()
    end
    
    DBB2.api.AddMessage(message, sender, "Hardcore", event)
  end
  
  if event == "CHAT_MSG_SYSTEM" then
    -- Capture system messages (hardcore deaths, level ups, etc.)
    local message = arg1
    -- System messages don't have a sender, use "System" as placeholder
    local sender = "System"
    local channel = "System"
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "UPDATE_INSTANCE_INFO" then
    DBB2.api.UpdateLockouts()
  end
  
  if event == "CHAT_MSG_CHANNEL_NOTICE" then
    -- Channel join/leave notification - refresh channel list if panel exists
    -- arg1 = notice type (e.g. "YOU_JOINED", "YOU_LEFT")
    -- arg9 = channel name
    if DBB2.gui and DBB2.gui.configTabs and DBB2.gui.configTabs.panels then
      local channelsPanel = DBB2.gui.configTabs.panels["Channels"]
      if channelsPanel and channelsPanel.RebuildChannelCheckboxes then
        channelsPanel.RebuildChannelCheckboxes()
      end
    end
  end
  
  if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
    -- Disable all category notifications when joining a group (if enabled)
    if DBB2_Config.clearNotificationsOnGroupJoin then
      -- Check if in a party or raid
      if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
        DBB2.api.DisableAllNotifications()
      end
    end
  end
end)

-- Register module function
function DBB2:RegisterModule(name, func)
  if DBB2.modules[name] then return end
  DBB2.modules[name] = func
  table.insert(DBB2.modules, func)
end

-- Cache tables for scaled values (populated on first call, constant per session)
DBB2._fontCache = {}
DBB2._scaledCache = {}

-- [ GetEffectiveFontOffset ]
-- Converts the UI font offset step into the actual font-size delta.
-- Each visible step is 0.5 font size to allow finer adjustments while
-- keeping the saved/configured slider values at whole numbers.
-- return:      [number]        actual font size delta
function DBB2:GetEffectiveFontOffset()
  local offset = DBB2_Config.fontOffset
  if type(offset) ~= "number" then offset = 0 end
  if offset < -6 then offset = -6 end
  if offset > 6 then offset = 6 end
  return offset * 0.5
end

-- Get font size with offset applied (cached)
-- 'baseSize'   [number]        the base font size
-- return:      [number]        font size with offset applied (minimum 6, maximum 24)
-- Note: WoW 1.12.1 has internal font size limits. Large fonts can cause crashes.
function DBB2:GetFontSize(baseSize)
  if self._fontCache[baseSize] then
    return self._fontCache[baseSize]
  end
  local size = baseSize + DBB2:GetEffectiveFontOffset()
  -- Clamp between 6 and 24 to prevent crashes in WoW 1.12.1
  -- Using conservative limits as vanilla WoW has strict font rendering constraints
  if size < 6 then size = 6 end
  if size > 24 then size = 24 end
  self._fontCache[baseSize] = size
  return size
end

-- [ GetScaleFactor ]
-- Returns a scale factor based on font offset for scaling UI element widths/heights
-- return:      [number]        scale factor (1.0 at offset 0, increases with positive offset)
function DBB2:GetScaleFactor()
  local effectiveOffset = DBB2:GetEffectiveFontOffset()
  -- Scale by ~10% per actual font size increase (UI step of +6 = 1.3x scale)
  return 1 + (effectiveOffset * 0.1)
end

-- [ ScaleSize ]
-- Scales a base size value according to font offset (cached)
-- 'baseSize'   [number]        the base size value
-- return:      [number]        scaled size (minimum 1 to prevent zero/negative dimensions)
function DBB2:ScaleSize(baseSize)
  if self._scaledCache[baseSize] then
    return self._scaledCache[baseSize]
  end
  local scaled = math.floor(baseSize * DBB2:GetScaleFactor() + 0.5)
  -- Ensure minimum size of 1 to prevent invalid frame dimensions
  if scaled < 1 then scaled = 1 end
  self._scaledCache[baseSize] = scaled
  return scaled
end

-- Get highlight color
-- return:      [r, g, b, a]    highlight color components
function DBB2:GetHighlightColor()
  local c = DBB2_Config.highlightColor or {r = 0.2, g = 1, b = 0.8, a = 1}
  return c.r, c.g, c.b, c.a
end

-- Slash command to toggle GUI
SLASH_DBB1 = "/dbb"
SlashCmdList["DBB"] = function(msg)
  if DBB2.gui then
    if DBB2.gui:IsShown() then
      DBB2.gui:Hide()
    else
      DBB2.gui:Show()
    end
  end
end

```

## DifficultBulletinBoard.toc
```toc
## Interface: 11200
## Title: |cffaaa7ccDifficult|cffffffffBulletinBoard
## Author: akzkak, DeterminedPanda - Capyed by Zae
## Notes: Group finder based on chat messages. CJK font support (place WarSansTT-Bliz-500.ttf in the font/ folder).
## Version: 2.51
## SavedVariablesPerCharacter: DBB2_Config

DifficultBulletinBoard.lua

env\defaults.lua
env\versions.lua
env\constants.lua
env\tables.lua
env\tag_exclusions.lua

api\utils.lua
api\hardcore.lua
api\channels.lua
api\wildcards.lua
api\categories.lua
api\blacklist.lua
api\chat_filter.lua
api\notifications.lua
api\lockouts.lua
api\messages.lua
api\tooltip.lua
api\gui_schema.lua
api\config_schema.lua
api\config_widgets.lua
api\dict_cn_phrases.lua
api\dict_cn_misc.lua
api\translate_cn.lua

modules\version_check.lua
modules\categories.lua
modules\gui.lua
modules\config.lua
modules\minimap.lua
```

## env/constants.lua
```lua
-- DBB2 UI Constants
-- Centralized spacing and font size values for consistent UI
-- These constants are used throughout the config system for layout consistency

-- =====================
-- CONSTANT DOMAINS
-- =====================
-- This file (env/constants.lua) contains static config panel constants:
--   DBB2.env.SPACING   -> Widget spacing, padding, row heights
--   DBB2.env.FONT_SIZE -> Font sizes for labels, inputs, descriptions
-- Used by: config_schema.lua, config_widgets.lua (settings UI)
--
-- Main GUI constants (message rows, scroll frames, tabs) are in api/gui_schema.lua
-- as DBB2.schema.* - computed dynamically with DBB2:ScaleSize()
--
-- The two domains are intentionally separate:
--   DBB2.env    -> Config panels (settings UI)
--   DBB2.schema -> Main GUI (message display, tabs, scrolling)

DBB2.env = DBB2.env or {}

-- Spacing constants (used everywhere for consistency)
DBB2.env.SPACING = {
  widget = 11,        -- Between widgets
  section = 19,       -- Before section headers
  afterSection = 8,   -- After section headers
  description = 5,    -- After descriptions
  padding = 10,       -- Panel edge padding
  rowHeight = 28,     -- Category/keyword row height
  checkSize = 14,     -- Checkbox size
  inputHeight = 18,   -- Input field height
  bottomPadding = 0,  -- Extra scroll space after last content
}

-- Font sizes
DBB2.env.FONT_SIZE = 9             -- For settings/labels under sections
DBB2.env.FONT_SIZE_INPUT = 10     -- For text inside input boxes
DBB2.env.FONT_SIZE_SMALL = 8      -- For descriptions and secondary text
DBB2.env.FONT_SIZE_LARGE = 11     -- For buttons and emphasis
DBB2.env.SECTION_FONT_SIZE = 10   -- For section headers

-- Default widget width
DBB2.env.DEFAULT_WIDTH = 250
```

## env/defaults.lua
```lua
-- DBB2 Environment Defaults
-- Central location for default configuration values
--
-- This file is loaded early in the TOC order so that API files
-- can reference these defaults via DBB2.env.* namespace.

-- Initialize the env namespace
DBB2.env = DBB2.env or {}

-- =====================
-- CHANNEL DEFAULTS
-- =====================

-- Default whitelisted channels (case-insensitive)
-- These are the standard channels where players look for groups
DBB2.env.defaultWhitelistedChannels = {
  "world",           -- Main LFG channel on most servers
  "lookingforgroup", -- Blizzard's LFG channel
  "lfg",             -- Common abbreviation
  "trade",           -- Sometimes used for LFG
  "general",         -- Zone general chat
  "hardcore",        -- Turtle WoW hardcore
  "\228\184\150\231\149\140", -- Chinese "World" channel (世界)
}

-- Default channel monitoring settings (which channels are enabled for monitoring)
DBB2.env.defaultMonitoredChannels = {
  -- Group 1: Local/Social
  Say = false,
  Yell = false,
  Guild = true,
  Whisper = false,
  Party = false,
  -- Group 2: Zone/Global channels
  General = true,
  Trade = true,
  LocalDefense = false,
  WorldDefense = false,
  LookingForGroup = true,
  GuildRecruitment = false,
  World = true,
  ["\228\184\150\231\149\140"] = true,  -- Chinese "World" channel (世界)
  -- Special
  Hardcore = true,  -- Will only work for hardcore characters
}

-- Static channel order for UI display (always shown regardless of joined status)
-- Use "-" as separator marker between groups
DBB2.env.staticChannelOrder = {
  "Say", "Yell", "Guild", "Whisper", "Party",
  "-",  -- separator
  "General", "Trade", "LocalDefense", "WorldDefense", "LookingForGroup", "GuildRecruitment", "World", "Hardcore",
  "-",  -- separator (dynamic channels follow)
}

-- Channels to auto-join if not already joined
DBB2.env.autoJoinChannels = {"World", "LookingForGroup", "\228\184\150\231\149\140"}

-- =====================
-- BLACKLIST DEFAULTS
-- =====================

-- Default blacklist keywords (used by InitBlacklist and reset functions)
-- These patterns are used to filter out common spam/recruitment messages
-- Supports wildcards: * matches any characters
DBB2.env.defaultBlacklistKeywords = {"recruit*", "recrut*", "<*>", "\\[???\\]", "\\[??\\]"}


-- =====================
-- CATEGORY DEFAULTS
-- =====================

-- Default filter tags for category types (must match in addition to category tags when enabled)
-- These are global filters that apply to all categories within a type
-- groups: LFG-style tags for dungeon/raid groups
-- professions: Trade-style tags for profession services
DBB2.env.defaultFilterTags = {
  groups = {
    enabled = false,
    tags = { "LF", "LFG", "LFM", "LF*M" }
  },
  professions = {
    enabled = false,
    tags = { "LF", "LFW", "WTB", "WTS" }
  },
  hardcore = {
    enabled = false,
    tags = {}
  }
}

-- Default group categories (dungeons/raids)
-- Level ranges: minLevel = minimum recommended level, maxLevel = maximum useful level (60 = endgame)
-- Each category has: name, selected (default state), tags (matching keywords), minLevel, maxLevel
DBB2.env.defaultGroups = {
  { name = "Custom Category",               selected = false, tags = {}, minLevel = 1, maxLevel = 60 },
  { name = "Upper Karazhan Halls",          selected = true, tags = { "kara40", "ukh"}, minLevel = 60, maxLevel = 60 },
  { name = "Naxxramas",                     selected = true, tags = { "naxxramas", "naxx" }, minLevel = 60, maxLevel = 60 },
  { name = "Temple of Ahn'Qiraj",           selected = true, tags = { "ahn'qiraj", "ahnqiraj", "aq40", "aq" }, minLevel = 60, maxLevel = 60 },
  { name = "Emerald Sanctum",               selected = true, tags = { "emerald", "sanctum", "es", "esnormal", "eshardcore" }, minLevel = 60, maxLevel = 60 },
  { name = "Blackwing Lair",                selected = true, tags = { "blackwing", "bwl" }, minLevel = 60, maxLevel = 60 },
  { name = "Lower Karazhan Halls",          selected = true, tags = { "karazhan", "kara", "kz", "kara10", "k10" }, minLevel = 60, maxLevel = 60 },
  { name = "Onyxia's Lair",                 selected = true, tags = { "onyxia", "ony", "onyx" }, minLevel = 60, maxLevel = 60 },
  { name = "Molten Core",                   selected = true, tags = { "molten", "mc" }, minLevel = 60, maxLevel = 60 },
  { name = "Ruins of Ahn'Qiraj",            selected = true, tags = { "ruins", "ahn'qiraj", "ahnqiraj", "aq20", "aq" }, minLevel = 60, maxLevel = 60 },
  { name = "Timbermaw Hold",                selected = true, tags = { "th", "tmh", "tm", "hold", "timber", "maw" }, minLevel = 60, maxLevel = 60 },
  { name = "Zul'Gurub",                     selected = true, tags = { "zul'gurub", "zulgurub", "zg" }, minLevel = 60, maxLevel = 60 },
  { name = "Stormwind Vault",               selected = true, tags = { "vault", "swvault", "swv" }, minLevel = 60, maxLevel = 60 },
  { name = "Caverns of Time: Black Morass", selected = true, tags = { "cot", "morass", "cavern", "cot:bm", "bm" }, minLevel = 60, maxLevel = 60 },
  { name = "Karazhan Crypt",                selected = true, tags = { "crypt", "crypts", "kara", "karazhan" }, minLevel = 60, maxLevel = 60 },
  { name = "Upper Blackrock Spire",         selected = true, tags = { "ubrs", "blackrock", "upper", "spire" }, minLevel = 60, maxLevel = 60 },
  { name = "Lower Blackrock Spire",         selected = true, tags = { "lbrs", "blackrock", "lower", "spire" }, minLevel = 55, maxLevel = 60 },
  { name = "Stratholme",                    selected = true, tags = { "strat", "strath", "stratholme" }, minLevel = 58, maxLevel = 60 },
  { name = "Scholomance",                   selected = true, tags = { "scholo", "scholomance" }, minLevel = 58, maxLevel = 60 },
  { name = "Dire Maul",                     selected = true, tags = { "dire", "maul", "dm", "dm:e", "dm:east", "dm:w", "dm:west", "dm:n", "dm:north", "dmw", "dmwest", "dmn", "dmnorth", "dme", "dmeast", "tribute", "dmt" }, minLevel = 57, maxLevel = 60 },
  { name = "Blackrock Depths",              selected = true, tags = { "brd", "blackrock", "depths", "emp", "lava" }, minLevel = 50, maxLevel = 60 },
  { name = "Hateforge Quarry",              selected = true, tags = { "hateforge", "quarry", "hq", "hfq" }, minLevel = 51, maxLevel = 60 },
  { name = "The Sunken Temple",             selected = true, tags = { "st", "sunken", "temple" }, minLevel = 49, maxLevel = 58 },
  { name = "Zul'Farrak",                    selected = true, tags = { "zf", "zul'farrak", "zulfarrak", "farrak" }, minLevel = 42, maxLevel = 51 },
  { name = "Maraudon",                      selected = true, tags = { "mara", "maraudon" }, minLevel = 43, maxLevel = 54 },
  { name = "Gilneas City",                  selected = true, tags = { "gilneas", "city" }, minLevel = 43, maxLevel = 52 },
  { name = "Stormwrought Ruins",            selected = true, tags = { "stormwrought", "ruins", "castle", "descent", "swc" }, minLevel = 32, maxLevel = 44 },
  { name = "Uldaman",                       selected = true, tags = { "uldaman", "ulda" }, minLevel = 41, maxLevel = 50 },
  { name = "Razorfen Downs",                selected = true, tags = { "razorfen", "downs", "rfd" }, minLevel = 35, maxLevel = 44 },
  { name = "Scarlet Monastery",             selected = true, tags = { "scarlet", "monastery", "sm", "armory", "cathedral", "cath", "library", "lib", "graveyard" }, minLevel = 30, maxLevel = 45 },
  { name = "Windhorn Canyon",               selected = true, tags = { "wc", "whc", "wind", "Windhorn", "canyon", "wh", "horn" }, minLevel = 26, maxLevel = 30 },
  { name = "The Crescent Grove",            selected = true, tags = { "crescent", "grove" }, minLevel = 28, maxLevel = 38 },
  { name = "Razorfen Kraul",                selected = true, tags = { "razorfen", "kraul", "rfk" }, minLevel = 29, maxLevel = 36 },
  { name = "Dragonmaw Retreat",             selected = true, tags = { "dragonmaw", "retreat", "dmr" }, minLevel = 26, maxLevel = 35 },
  { name = "Gnomeregan",                    selected = true, tags = { "gnomeregan", "gnomer" }, minLevel = 28, maxLevel = 37 },
  { name = "The Stockade",                  selected = true, tags = { "stockade", "stockades", "stock", "stocks" }, minLevel = 23, maxLevel = 32 },
  { name = "Blackfathom Deeps",             selected = true, tags = { "bfd", "blackfathom" }, minLevel = 22, maxLevel = 31 },
  { name = "Shadowfang Keep",               selected = true, tags = { "sfk", "shadowfang" }, minLevel = 20, maxLevel = 28 },
  { name = "The Deadmines",                 selected = true, tags = { "vc", "dm", "deadmine", "deadmines" }, minLevel = 16, maxLevel = 24 },
  { name = "Wailing Caverns",               selected = true, tags = { "wc", "wailing", "caverns" }, minLevel = 16, maxLevel = 25 },
  { name = "Frostmane Hollow",              selected = true, tags = { "Frostmane", "fh", "fmh", "frost", "hollow", "fm", "mane" }, minLevel = 13, maxLevel = 20 },
  { name = "Ragefire Chasm",                selected = true, tags = { "rfc", "ragefire", "chasm" }, minLevel = 13, maxLevel = 19 },
}

-- Default profession categories
-- Each category has: name, selected (default state), tags (matching keywords)
DBB2.env.defaultProfessions = {
  { name = "Custom Category",  selected = false, tags = {} },
  { name = "Alchemy",        selected = true, tags = { "alchemist", "alchemy", "alch" } },
  { name = "Blacksmithing",  selected = true, tags = { "blacksmithing", "blacksmith", "bs" } },
  { name = "Enchanting",     selected = true, tags = { "enchanting", "enchanter", "enchant", "ench" } },
  { name = "Engineering",    selected = true, tags = { "engineering", "engineer", "eng" } },
  { name = "Herbalism",      selected = true, tags = { "herbalism", "herbalist", "herb" } },
  { name = "Leatherworking", selected = true, tags = { "leatherworking", "leatherworker", "lw" } },
  { name = "Mining",         selected = true, tags = { "mining", "miner" } },
  { name = "Tailoring",      selected = true, tags = { "tailoring", "tailor" } },
  { name = "Jewelcrafting",  selected = true, tags = { "jewelcrafting", "Jewelcrafter", "jeweler", "jewel", "jc" } },
  { name = "Cooking",        selected = true, tags = { "cooking", "cook" } },
}

-- Default hardcore categories (Turtle WoW specific)
-- Deaths: Tracks player death announcements
-- Level Ups: Tracks level up announcements
DBB2.env.defaultHardcore = {
  { name = "Custom Category", selected = false, tags = {} },
  { name = "Deaths",    selected = true, tags = { "tragedy" } },
  { name = "Level Ups", selected = true, tags = { "reached", "inferno" } },
}
```

## env/tables.lua
```lua
-- DBB2 Static Lookup Tables
-- Descriptions and labels used by config widgets
-- These tables are referenced by config_widgets.lua for tooltips and labels

DBB2.env = DBB2.env or {}

-- Channel descriptions for tooltips
DBB2.env.channelDescriptions = {
  Say = "Local /say chat",
  Yell = "Local /yell chat",
  Guild = "Your guild chat",
  Whisper = "Private whispers",
  Party = "Your party chat",
  General = "Zone general chat",
  Trade = "Trade channel",
  LocalDefense = "Zone defense",
  WorldDefense = "World defense",
  LookingForGroup = "Official LFG channel",
  GuildRecruitment = "Guild recruitment",
  World = "Main LFG channel",
  Hardcore = "Hardcore channel"
}

-- Pattern descriptions for keyword blacklist
DBB2.env.patternDescriptions = {
  ["<*>"] = "<Guild Name>",
  ["\\[??\\]"] = "[pl], [it]",
  ["\\[???\\]"] = "[pol], [ita]",
  ["recruit*"] = "recruit, recruiting",
  ["recrut*"] = "recrut, recrute"
}

-- Instance name aliases for lockout matching
-- Maps WoW's GetSavedInstanceInfo names to addon category names
DBB2.env.instanceAliases = {
  ["ahn'qiraj temple"] = "Temple of Ahn'Qiraj",
  ["ahn'qiraj ruins"] = "Ruins of Ahn'Qiraj",
  ["karazhan halls"] = "Upper Karazhan Halls",
  ["black morass"] = "Caverns of Time: Black Morass",
}
```

## env/tag_exclusions.lua
```lua
-- DBB2 Tag Exclusions
-- Tag false positive exclusion rules for message matching
--
-- This file contains rules to prevent false positive tag matches.
-- For example, "ST" should not match "20:30 ST" (server time).

-- Initialize env namespace if needed
DBB2.env = DBB2.env or {}

-- Localize frequently used globals for performance
local string_find = string.find
local string_lower = string.lower
local string_sub = string.sub
local string_len = string.len
local ipairs = ipairs

-- =====================================================
-- TAG FALSE POSITIVE EXCLUSIONS
-- =====================================================
-- Some short tags can match unintended patterns in messages.
-- This table defines exclusion rules to prevent false positives.
--
-- Format: tagExclusions[tag] = { check functions that return true if match should be REJECTED }
-- Each function receives: (lowerMsg, foundPos, tagLen, category)
--   lowerMsg  = lowercase message string
--   foundPos  = position where tag was found
--   tagLen    = length of the tag
--   category  = category table currently being evaluated
--
-- Return true to REJECT the match (false positive), false to allow it.
-- =====================================================

DBB2.env.tagExclusions = {}

local function HasWholeWordInRange(lowerMsg, word, rangeStart, rangeEnd)
  local msgLen = string_len(lowerMsg)
  local wordLen = string_len(word)
  local searchPos = rangeStart

  if msgLen == 0 then return false end
  if rangeStart < 1 then rangeStart = 1 end
  if rangeEnd > msgLen then rangeEnd = msgLen end
  if rangeStart > rangeEnd then return false end

  searchPos = rangeStart

  while true do
    local foundWordPos = string_find(lowerMsg, word, searchPos, true)
    if not foundWordPos or foundWordPos > rangeEnd then
      return false
    end

    local wordEndPos = foundWordPos + wordLen - 1
    if wordEndPos <= rangeEnd then
      local charBefore = ""
      local charAfter = ""

      if foundWordPos > 1 then
        charBefore = string_sub(lowerMsg, foundWordPos - 1, foundWordPos - 1)
      end
      if wordEndPos < msgLen then
        charAfter = string_sub(lowerMsg, wordEndPos + 1, wordEndPos + 1)
      end

      if ((foundWordPos == 1) or not string_find(charBefore, "[%w]")) and
         ((wordEndPos == msgLen) or not string_find(charAfter, "[%w]")) then
        return true
      end
    end

    searchPos = foundWordPos + 1
  end
end

local dmDirectionalWords = { "east", "west", "north" }

local function HasDireMaulWingContext(lowerMsg, foundPos, tagLen)
  local rangeStart = foundPos - 6
  local rangeEnd = foundPos + tagLen + 8

  for _, word in ipairs(dmDirectionalWords) do
    if HasWholeWordInRange(lowerMsg, word, rangeStart, rangeEnd) then
      return true
    end
  end

  return false
end

-- [ ST exclusion ]
-- "ST" is a tag for Sunken Temple, but also commonly used for "Server Time"
-- Reject matches like "20:30 ST", "8:00 ST", "19:45ST"
-- Pattern: digit(s) + colon + digit(s) + optional space + ST
DBB2.env.tagExclusions["st"] = {
  function(lowerMsg, foundPos, tagLen)
    -- Check if preceded by time pattern: look for "HH:MM " or "H:MM " before ST
    -- We need at least 4-6 chars before: "8:00 " (5) or "20:30 " (6) or "8:00" (4) or "20:30" (5)
    if foundPos < 3 then return false end
    
    -- Check for optional space right before ST
    local checkPos = foundPos - 1
    local charBeforeST = string_sub(lowerMsg, checkPos, checkPos)
    if charBeforeST == " " then
      checkPos = checkPos - 1
    end

    -- Now check for minutes (2 digits)
    if checkPos < 2 then return false end
    local min2 = string_sub(lowerMsg, checkPos, checkPos)
    local min1 = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
    if not string_find(min1, "%d") or not string_find(min2, "%d") then
      return false
    end
    checkPos = checkPos - 2
    
    -- Check for colon
    if checkPos < 1 then return false end
    local colon = string_sub(lowerMsg, checkPos, checkPos)
    if colon ~= ":" then return false end
    checkPos = checkPos - 1
    
    -- Check for hour (1-2 digits)
    if checkPos < 1 then return false end
    local hour1 = string_sub(lowerMsg, checkPos, checkPos)
    if not string_find(hour1, "%d") then return false end
    
    -- Optional second hour digit
    if checkPos > 1 then
      local hour2 = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
      if string_find(hour2, "%d") then
        checkPos = checkPos - 1
      end
    end
    
    -- Verify word boundary before the time
    if checkPos > 1 then
      local charBeforeTime = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
      if string_find(charBeforeTime, "[%w]") then
        return false
      end
    end
    
    return true
  end
}

-- [ DM exclusion ]
-- "DM" is a tag for Dire Maul and Deadmines, but also commonly used for "Direct Message"
-- Reject matches like "DM me", "DM us" (direct message me/us)
-- Also reject "DM:" patterns (DM:E, DM:W, DM:N are Dire Maul wings, not generic DM)
DBB2.env.tagExclusions["dm"] = {
  function(lowerMsg, foundPos, tagLen, category)
    local msgLen = string_len(lowerMsg)
    local afterPos = foundPos + tagLen
    
    -- Check for colon after DM (indicates Dire Maul wing like DM:E, DM:W, DM:N)
    -- This prevents the generic "dm" tag from matching when a specific wing is mentioned
    if afterPos <= msgLen then
      local charAfter = string_sub(lowerMsg, afterPos, afterPos)
      if charAfter == ":" then
        return true  -- "DM:" - reject generic dm match, let specific dm:e/dm:w/dm:n tags handle it
      end
    end

    -- Reject generic "dm" for The Deadmines when a Dire Maul wing word
    -- appears nearby, e.g. "dm east", "east dm", "dm north".
    if category and category.name then
      local catNameLower = string_lower(category.name)
      if string_find(catNameLower, "deadmines", 1, true) and
         HasDireMaulWingContext(lowerMsg, foundPos, tagLen) then
        return true
      end
    end
    
    -- Check for space after DM (for "DM me" / "DM us" patterns)
    if afterPos > msgLen then return false end
    local charAfter = string_sub(lowerMsg, afterPos, afterPos)
    if charAfter ~= " " then return false end
    
    -- Check for "me" or "us" after the space
    local wordStart = afterPos + 1
    if wordStart > msgLen then return false end
    
    -- Check for "me"
    if wordStart + 1 <= msgLen then
      local nextWord = string_sub(lowerMsg, wordStart, wordStart + 1)
      if nextWord == "me" then
        -- Verify word boundary after "me"
        local afterMe = wordStart + 2
        if afterMe > msgLen or not string_find(string_sub(lowerMsg, afterMe, afterMe), "[%w]") then
          return true  -- "DM me" - reject as direct message
        end
      end
      if nextWord == "us" then
        -- Verify word boundary after "us"
        local afterUs = wordStart + 2
        if afterUs > msgLen or not string_find(string_sub(lowerMsg, afterUs, afterUs), "[%w]") then
          return true  -- "DM us" - reject as direct message
        end
      end
    end
    
    return false
  end
}

-- =====================================================
-- TAG EXCLUSION HELPER FUNCTION
-- =====================================================

-- [ IsTagExcluded ]
-- Helper function to check tag exclusions.
-- Returns true if the match should be REJECTED (is a false positive).
--
-- @param tag       [string] The lowercase tag being matched
-- @param lowerMsg  [string] The lowercase message string
-- @param foundPos  [number] Position where tag was found
-- @param tagLen    [number] Length of the tag
-- @param category  [table]  Category currently being evaluated (optional)
-- @return          [boolean] true if match should be rejected, false if valid
function DBB2.env.IsTagExcluded(tag, lowerMsg, foundPos, tagLen, category)
  -- Global exclusion: reject matches inside hyperlink brackets |h[...]|h
  -- This prevents item/spell/quest links like [Maul] from matching tags
  -- Only excludes REAL hyperlinks (with |h prefix), not manually typed [brackets]
  -- Search backwards for '[' and check if preceded by '|h'
  local bracketStart = nil
  for i = foundPos, 1, -1 do
    local char = string_sub(lowerMsg, i, i)
    if char == "[" then
      -- Check if this bracket is part of a hyperlink (preceded by |h)
      if i >= 3 then
        local prefix = string_sub(lowerMsg, i - 2, i - 1)
        if prefix == "|h" then
          bracketStart = i
        end
      end
      break
    elseif char == "]" then
      break
    end
  end
  
  if bracketStart then
    local matchEnd = foundPos + tagLen - 1
    local msgLen = string_len(lowerMsg)
    for i = matchEnd, msgLen do
      local char = string_sub(lowerMsg, i, i)
      if char == "]" then
        -- Check if followed by |h (closing hyperlink)
        if i + 2 <= msgLen then
          local suffix = string_sub(lowerMsg, i + 1, i + 2)
          if suffix == "|h" then
            return true  -- Match is inside |h[...]|h hyperlink - reject it
          end
        end
        break
      elseif char == "[" then
        break
      end
    end
  end
  
  -- Check tag-specific exclusions
  local exclusions = DBB2.env.tagExclusions[tag]
  if not exclusions then return false end
  
  for _, checkFunc in ipairs(exclusions) do
    if checkFunc(lowerMsg, foundPos, tagLen, category) then
      return true  -- Match should be rejected
    end
  end
  return false  -- Match is valid
end
```

## env/versions.lua
```lua
-- DBB2 Version Numbers
-- Centralized version numbers for auto-reset functionality
--
-- Each version number controls a specific set of defaults.
-- Increment ONLY the relevant version when you change those defaults.
-- This prevents unnecessary resets of unrelated user customizations.

DBB2.versions = {
  -- Groups category tags and filter tags (LF/LFG/LFM)
  -- Increment when: Adding/removing dungeon/raid categories, changing group tags
  GROUPS = 16,
  
  -- Professions category tags and filter tags (LFW/WTB/WTS)
  -- Increment when: Adding/removing profession categories, changing profession tags
  PROFESSIONS = 10,
  
  -- Hardcore category tags
  -- Increment when: Changing hardcore category tags (deaths, level ups)
  HARDCORE = 10,
  
  -- Blacklist keywords
  -- Increment when: Adding/removing default blacklist patterns
  BLACKLIST = 5,
  
  -- Monitored channels
  -- Increment when: Changing default channel selections
  -- CHANNELS = 1,
}
```

## modules/categories.lua
```lua
-- DBB2 Categories Module
-- Category initialization and auto-reset logic
--
-- NOTE: Default category data is in env/defaults.lua (DBB2.env.*)
-- NOTE: Category API functions are in api/categories.lua
-- This module provides initialization and the ResetCategoriesToDefaults function.
--
-- VERSION NUMBERS are in env/versions.lua:
--   DBB2.versions.CATEGORY  - for category/filter tag changes
--   DBB2.versions.BLACKLIST - for blacklist keyword changes

-- Localize frequently used globals for performance
local ipairs = ipairs
local pairs = pairs

DBB2:RegisterModule("categories", function()
  -- Level range lookup table (runtime only, not saved)
  -- Populated from DBB2.env.defaultGroups defined in env/defaults.lua
  -- Access via DBB2.api.GetCategoryLevelRange() or DBB2.api.IsLevelAppropriate()
  DBB2.categoryLevelRanges = {}
  for _, cat in ipairs(DBB2.env.defaultGroups) do
    if cat.minLevel and cat.maxLevel then
      DBB2.categoryLevelRanges[cat.name] = {
        minLevel = cat.minLevel,
        maxLevel = cat.maxLevel
      }
    end
  end
  
  -- Initialize saved categories config
  if not DBB2_Config.categories then
    DBB2_Config.categories = {}
  end
  
  -- Initialize filter tags config
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags.groups then
    DBB2_Config.filterTags.groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups)
  end
  if not DBB2_Config.filterTags.professions then
    DBB2_Config.filterTags.professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions)
  end
  if not DBB2_Config.filterTags.hardcore then
    DBB2_Config.filterTags.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.hardcore)
  end
  
  -- Helper to check if a table has any array elements (more reliable than table.getn in Lua 5.0)
  local function hasArrayElements(t)
    if not t then return false end
    -- Check if first element exists (all category arrays start at index 1)
    return t[1] ~= nil
  end
  
  -- Initialize categories from saved or defaults
  -- Use hasArrayElements instead of table.getn for more reliable detection
  if not DBB2_Config.categories.groups or not hasArrayElements(DBB2_Config.categories.groups) then
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
  end
  if not DBB2_Config.categories.professions or not hasArrayElements(DBB2_Config.categories.professions) then
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
  end
  if not DBB2_Config.categories.hardcore or not hasArrayElements(DBB2_Config.categories.hardcore) then
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
  end
  
  -- Ensure all categories have a tags field (fix for SavedVariables not preserving empty tables)
  -- Also clean up runtime-only fields that shouldn't be saved (_tagsLower, _tagsLen)
  local function ensureTagsField(categories)
    for _, cat in ipairs(categories) do
      if cat.tags == nil then
        cat.tags = {}
      end
      -- Clean up runtime-only precomputed fields (they'll be regenerated on demand)
      cat._tagsLower = nil
      cat._tagsLen = nil
    end
  end
  ensureTagsField(DBB2_Config.categories.groups)
  ensureTagsField(DBB2_Config.categories.professions)
  ensureTagsField(DBB2_Config.categories.hardcore)

  local function ensureCustomCategory(categories)
    for _, cat in ipairs(categories) do
      if cat.name == "Custom Category" then
        return
      end
    end
    table.insert(categories, 1, { name = "Custom Category", selected = false, tags = {} })
  end

  ensureCustomCategory(DBB2_Config.categories.groups)
  ensureCustomCategory(DBB2_Config.categories.professions)
  ensureCustomCategory(DBB2_Config.categories.hardcore)
  
  -- Initialize collapsed states if not present
  if not DBB2_Config.categoryCollapsed then
    DBB2_Config.categoryCollapsed = {}
  end
  
  -- =====================================================
  -- AUTO-RESET ON VERSION CHANGE
  -- =====================================================
  -- Check each version number separately to only reset what changed
  
  -- Groups version: reset groups categories and filter tags
  local savedGroupsVersion = DBB2_Config.groupsVersion or 0
  if savedGroupsVersion < DBB2.versions.GROUPS then
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
    DBB2_Config.filterTags.groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups)
    DBB2_Config.groupsVersion = DBB2.versions.GROUPS
    DBB2:QueueMessage("|cff33ffccDBB2:|r Groups tags updated to v" .. DBB2.versions.GROUPS .. " defaults.")
  end
  
  -- Professions version: reset professions categories and filter tags
  local savedProfessionsVersion = DBB2_Config.professionsVersion or 0
  if savedProfessionsVersion < DBB2.versions.PROFESSIONS then
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
    DBB2_Config.filterTags.professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions)
    DBB2_Config.professionsVersion = DBB2.versions.PROFESSIONS
    DBB2:QueueMessage("|cff33ffccDBB2:|r Professions tags updated to v" .. DBB2.versions.PROFESSIONS .. " defaults.")
  end
  
  -- Hardcore version: reset hardcore categories
  local savedHardcoreVersion = DBB2_Config.hardcoreVersion or 0
  if savedHardcoreVersion < DBB2.versions.HARDCORE then
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
    DBB2_Config.filterTags.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.hardcore)
    DBB2_Config.hardcoreVersion = DBB2.versions.HARDCORE
    DBB2:QueueMessage("|cff33ffccDBB2:|r Hardcore tags updated to v" .. DBB2.versions.HARDCORE .. " defaults.")
  end
  
  -- Blacklist version: reset blacklist keywords only (preserves enabled state and player list)
  local savedBlacklistVersion = DBB2_Config.blacklistVersion or 0
  if savedBlacklistVersion < DBB2.versions.BLACKLIST then
    -- Ensure blacklist structure exists before resetting keywords
    if not DBB2_Config.blacklist then
      DBB2_Config.blacklist = {
        enabled = true,
        hideFromChat = true,
        players = {},
        keywords = {}
      }
    end
    DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    DBB2_Config.blacklistVersion = DBB2.versions.BLACKLIST
    DBB2:QueueMessage("|cff33ffccDBB2:|r Blacklist keywords updated to v" .. DBB2.versions.BLACKLIST .. " defaults.")
  end
  
  -- [ ResetCategoriesToDefaults ]
  -- Resets all tag-related settings to default values (categories, filter tags, blacklist keywords)
  -- NOTE: This function lives in DBB2.modules (not DBB2.api) because it performs
  -- a full reset operation. Default data is now in env/defaults.lua (DBB2.env.*).
  function DBB2.modules.ResetCategoriesToDefaults()
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
    DBB2_Config.filterTags = {
      groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups),
      professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions),
      hardcore = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.hardcore)
    }
    -- Reset blacklist keywords (preserves enabled state and player list)
    if DBB2_Config.blacklist then
      DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    end
    -- Update version numbers to current
    DBB2_Config.groupsVersion = DBB2.versions.GROUPS
    DBB2_Config.professionsVersion = DBB2.versions.PROFESSIONS
    DBB2_Config.hardcoreVersion = DBB2.versions.HARDCORE
    DBB2_Config.blacklistVersion = DBB2.versions.BLACKLIST
  end
end)
```

## modules/config.lua
```lua
-- DBB2 Config Module
-- All config tabs use the same declarative schema system

DBB2:RegisterModule("config", function()
  if not DBB2.gui or not DBB2.gui.tabs or not DBB2.gui.tabs.panels or not DBB2.gui.tabs.panels["Config"] then
    DEFAULT_CHAT_FRAME:AddMessage("DBB2: ERROR - Config panel not ready")
    return
  end
  
  local configPanel = DBB2.gui.tabs.panels["Config"]
  
  -- Scroll update on show
  local originalConfigOnShow = configPanel:GetScript("OnShow")
  configPanel:SetScript("OnShow", function()
    if originalConfigOnShow then originalConfigOnShow() end
    if DBB2.gui.configTabs and DBB2.gui.configTabs.activeTab then
      local activePanel = DBB2.gui.configTabs.panels[DBB2.gui.configTabs.activeTab]
      if activePanel and activePanel.scrollFrame then
        activePanel.scrollFrame._needsScrollUpdate = true
      end
    end
  end)
  
  -- Position config panel
  configPanel:ClearAllPoints()
  configPanel:SetPoint("TOPLEFT", DBB2.gui.tabs.content, "TOPLEFT", 0, 0)
  configPanel:SetPoint("BOTTOMRIGHT", DBB2.gui.tabs.content, "BOTTOMRIGHT", 0, 0)
  
  -- Create tab system
  local configTabs = {"General", "Channels", "Groups", "Professions", "Hardcore", "Blacklist"}
  DBB2.gui.configTabs = DBB2.schema.CreateTabSystem("DBB2Config", configPanel, configTabs, 90, 14)
  
  -- Position tab buttons vertically on right side
  local buttonWidth = DBB2:ScaleSize(90)
  local buttonHeight = DBB2:ScaleSize(14)
  local buttonSpacing = DBB2:ScaleSize(3)
  local padding = DBB2:ScaleSize(5)
  local versionArtHeight = DBB2:ScaleSize(55)
  
  for i, tabName in ipairs(configTabs) do
    local btn = DBB2.gui.configTabs.buttons[tabName]
    btn:ClearAllPoints()
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetParent(DBB2.gui.configTabs.content)
    local extraSpacing = (tabName == "Blacklist") and buttonHeight or 0
    btn:SetPoint("TOPRIGHT", DBB2.gui.configTabs.content, "TOPRIGHT", -padding, -padding - versionArtHeight - ((i - 1) * (buttonHeight + buttonSpacing)) - extraSpacing)
  end
  
  DBB2.gui.configTabs.content:ClearAllPoints()
  DBB2.gui.configTabs.content:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 0, 0)
  DBB2.gui.configTabs.content:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 0, 0)
  
  if DBB2.gui.configTabs.content.backdrop then
    DBB2.gui.configTabs.content.backdrop:Hide()
  end
  
  -- Adjust tab panels
  local separatorPadding = DBB2:ScaleSize(7)
  for _, tabName in ipairs(configTabs) do
    local panel = DBB2.gui.configTabs.panels[tabName]
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", DBB2.gui.configTabs.content, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + 3 + separatorPadding), 0)
    panel._configTabName = tabName
  end
  
  -- Separator line
  local separatorLine = DBB2.gui.configTabs.content:CreateTexture(nil, "ARTWORK")
  separatorLine:SetWidth(1)
  separatorLine:SetPoint("TOP", DBB2.gui.configTabs.content, "TOPRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetPoint("BOTTOM", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Reset button
  local resetBtn = DBB2.schema.CreateButton("DBB2ResetBtn", DBB2.gui.configTabs.content, "Reset Defaults")
  resetBtn:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -padding, padding)
  resetBtn:SetWidth(buttonWidth)
  resetBtn:SetHeight(buttonHeight)
  resetBtn.text:SetTextColor(1, 0.3, 0.3, 1)
  resetBtn:SetScript("OnEnter", function() this.backdrop:SetBackdropBorderColor(1, 0.3, 0.3, 1) end)
  resetBtn:SetScript("OnLeave", function() this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
  resetBtn:SetScript("OnClick", function()
    DBB2_Config.fontOffset = 0
    DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}
    DBB2_Config.spamFilterSeconds = 150
    DBB2_Config.messageExpireMinutes = 15
    DBB2_Config.hideFromChat = 0
    DBB2_Config.maxMessagesPerCategory = 5
    DBB2_Config.scrollSpeed = 55
    DBB2_Config.defaultTab = 0
    DBB2_Config.notificationSound = 1
    DBB2_Config.showCurrentTime = true
    DBB2_Config.timeDisplayMode = 2
    DBB2_Config.showLevelFilteredGroups = false
    DBB2_Config.showGroupLevelRanges = true
    DBB2_Config.clearNotificationsOnGroupJoin = true
    DBB2_Config.autoJoinChannels = true
    DBB2_Config.clampToScreen = true
    DBB2_Config.closeOnEscape = true
    DBB2_Config.minimapAngle = 45
    DBB2_Config.minimapFreeMode = false
    DBB2_Config.minimapFreePos = nil
    DBB2_Config.notifications = { mode = 3 }
    DBB2_Config.blacklist = { enabled = true, hideFromChat = true, players = {}, keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords) }
    DBB2_Config.hardcoreChannelsInitialized = nil
    DBB2.api.ResetChannelDefaults()
    DBB2_Config.position = nil
    if DBB2.modules.ResetCategoriesToDefaults then DBB2.modules.ResetCategoriesToDefaults() end
    ReloadUI()
  end)
  
  -- Reload button
  local reloadBtn = DBB2.schema.CreateButton("DBB2ReloadBtn", DBB2.gui.configTabs.content, "Save & Reload")
  reloadBtn:SetPoint("BOTTOMRIGHT", resetBtn, "TOPRIGHT", 0, buttonSpacing)
  reloadBtn:SetWidth(buttonWidth)
  reloadBtn:SetHeight(buttonHeight)
  reloadBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
  reloadBtn:SetScript("OnClick", function()
    for _, panelName in ipairs({"Groups", "Professions", "Hardcore"}) do
      local panel = DBB2.gui.configTabs.panels[panelName]
      if panel and panel.categoryRows then
        for _, row in ipairs(panel.categoryRows) do
          if row and row.tagsInput and row.categoryType and row.categoryName then
            DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(row.tagsInput:GetText()))
          end
        end
      end
      if panel and panel.filterTagsInput and panel.filterCategoryType then
        DBB2.api.UpdateFilterTags(panel.filterCategoryType, DBB2.api.ParseTagsString(panel.filterTagsInput:GetText()))
      end
    end
    ReloadUI()
  end)
  
  -- Version art
  local hr, hg, hb = DBB2:GetHighlightColor()
  local versionFrame = CreateFrame("Frame", "DBB2VersionArt", DBB2.gui.configTabs.content)
  versionFrame:SetWidth(buttonWidth)
  versionFrame:SetHeight(DBB2:ScaleSize(36))
  versionFrame:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.buttons["General"], "TOPRIGHT", 0, DBB2:ScaleSize(14))
  
  versionFrame.difficult = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.difficult:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(11))
  versionFrame.difficult:SetPoint("TOPLEFT", 0, 0)
  versionFrame.difficult:SetText("Difficult")
  versionFrame.difficult:SetTextColor(hr, hg, hb, 1)
  
  versionFrame.name = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.name:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(11))
  versionFrame.name:SetPoint("TOPRIGHT", 0, -(DBB2:GetFontSize(11) + DBB2:ScaleSize(1)))
  versionFrame.name:SetText("BulletinBoard")
  versionFrame.name:SetTextColor(1, 1, 1, 1)
  
  versionFrame.version = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.version:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(9))
  versionFrame.version:SetPoint("TOPRIGHT", versionFrame.name, "BOTTOMRIGHT", 0, -2)
  versionFrame.version:SetText("v" .. (GetAddOnMetadata("DifficultBulletinBoard", "Version") or "?"))
  versionFrame.version:SetTextColor(0.5, 0.5, 0.5, 1)


  -- Initialize APIs
  DBB2.api.InitNotificationConfig()
  DBB2.api.InitChannelConfig()
  DBB2.api.InitBlacklist()
  DBB2_Config.notificationMode = DBB2.api.GetNotificationMode()

  -- =====================
  -- GENERAL TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["General"], {
    { type = "section", label = "Appearance" },
    { type = "description", text = "Customize how the window and text look.", fontSize = 9 },
    { type = "slider", key = "defaultTab", label = "Default Tab", min = 0, max = 3, step = 1,
      valueLabels = {[0] = "Logs", [1] = "Groups", [2] = "Professions", [3] = "Hardcore"},
      tooltip = {{"Default Tab", "highlight"}, "Choose which tab opens by default."} },
    { type = "slider", key = "fontOffset", label = "Font Size Offset", min = -6, max = 6, step = 1,
      tooltip = {{"Font Size Offset", "highlight"}, "Adjust text size.", {"Requires /reload", "gray"}},
      onChange = function(val)
        if DBB2.gui.resizeGrip then
          local s = 1 + ((val * 0.5) * 0.1)
          DBB2.gui.resizeGrip.minWidth = math.floor(410 * s + 0.5)
          DBB2.gui.resizeGrip.minHeight = math.floor(275 * s + 0.5)
        end
      end },
    { type = "colorpicker", key = "backgroundColor", label = "Background Color",
      default = {r = 0.08, g = 0.08, b = 0.10, a = 0.85},
      tooltip = {{"Background Color", "highlight"}, "Set the background color.", {"Requires /reload", "gray"}} },
    { type = "colorpicker", key = "highlightColor", label = "Highlight Color",
      default = {r = 0.2, g = 1, b = 0.8, a = 1},
      tooltip = {{"Highlight Color", "highlight"}, "Set the color used for highlights.", {"Requires /reload", "gray"}} },

    { type = "section", label = "Time & Display" },
    { type = "description", text = "Control how messages are shown and how much information is visible.", fontSize = 9 },
    { type = "toggle", key = "showCurrentTime", label = "Show Current Time",
      tooltip = {{"Show Current Time", "highlight"}, "Show the current time above message timestamps."},
      onChange = function(enabled)
        for _, p in ipairs({"Logs", "Groups", "Professions", "Hardcore"}) do
          local panel = DBB2.gui.tabs.panels[p]
          if panel and panel.currentTimeText then
            if enabled then panel.currentTimeText:Show() else panel.currentTimeText:Hide() end
          end
        end
      end },
    { type = "slider", key = "timeDisplayMode", label = "Time Format", min = 0, max = 2, step = 1,
      valueLabels = {[0] = "Timestamp", [1] = "Relative", [2] = "Elapsed"},
      tooltip = {{"Time Format", "highlight"}, "Choose how message time is shown.", "Timestamp: Shows the clock time.", "Relative: Shows how long ago the message appeared.", "Elapsed: Shows time since the message appeared."},
      onChange = function(val)
        -- Refresh all panels to update timestamp display
        if DBB2.gui and DBB2.gui:IsShown() then
          if DBB2.gui.UpdateMessages then DBB2.gui:UpdateMessages() end
          for _, p in ipairs({"Groups", "Professions", "Hardcore"}) do
            local panel = DBB2.gui.tabs.panels[p]
            if panel and panel.UpdateCategories then panel.UpdateCategories() end
          end
        end
      end },
    { type = "toggle", key = "showGroupLevelRanges", label = "Show Level Ranges", default = true,
      tooltip = {{"Show Level Ranges", "highlight"}, "Show level ranges in Groups tab next to dungeons."},
      onChange = function()
        local gp = DBB2.gui.tabs.panels["Groups"]
        if gp and gp.UpdateCategories and gp:IsVisible() then gp.UpdateCategories() end
      end },
    { type = "slider", key = "maxMessagesPerCategory", label = "Messages per Category", min = 0, max = 10, step = 1,
      tooltip = {{"Messages per Category", "highlight"}, "Limit how many messages are shown in each category.", {"0 = unlimited", "gray"}} },
    { type = "slider", key = "scrollSpeed", label = "Scroll Speed", min = 10, max = 100, step = 5,
      tooltip = {{"Scroll Speed", "highlight"}, "Adjust how fast lists scroll with the mouse wheel."} },
    
    { type = "section", label = "Notifications" },
    { type = "description", text = "Choose when notifications appear and how they get your attention.", fontSize = 9 },
    { type = "description", text = "Tip: Shift-click an active bell to turn off all active notifications.", fontSize = 9 },
    { type = "slider", key = "notificationMode", label = "Mode", min = 0, max = 3, step = 1,
      valueLabels = {[0] = "Off", [1] = "Chat", [2] = "Raid Warning", [3] = "Chat & Raid Warning"},
      tooltip = {{"Notification Mode", "highlight"}, "Choose how notifications are shown."},
      onChange = function(val)
        DBB2.api.SetNotificationMode(val)
        if DBB2.gui and DBB2.gui.tabs and DBB2.gui.tabs.panels then
          for _, p in ipairs({"Groups", "Professions", "Hardcore"}) do
            local panel = DBB2.gui.tabs.panels[p]
            if panel and panel.UpdateCategories and panel:IsVisible() then
              panel.UpdateCategories()
            end
          end
        end
      end },
    { type = "slider", key = "notificationSound", label = "Sound", min = 0, max = 1, step = 1,
      valueLabels = {[0] = "Off", [1] = "On"},
      tooltip = {{"Sound", "highlight"}, "Play a sound when a notification appears."} },
    { type = "toggle", key = "clearNotificationsOnGroupJoin", label = "Auto-Clear", default = true,
      tooltip = {{"Auto-Clear", "highlight"}, "Clear active notifications when you join a group."} },
    
    { type = "section", label = "Filtering & Cleanup" },
    { type = "description", text = "Reduce spam, control repeats, and manage how messages are handled.", fontSize = 9 },
    { type = "slider", key = "spamFilterSeconds", label = "Duplicate Filter (seconds)", min = 0, max = 300, step = 10,
      tooltip = {{"Duplicate Filter", "highlight"}, "Ignore repeated messages within the selected time.", {"0 = disabled", "gray"}} },
    { type = "slider", key = "messageExpireMinutes", label = "Auto-Remove (minutes)", min = 0, max = 30, step = 1,
      tooltip = {{"Auto-Remove", "highlight"}, "Automatically remove old messages after a set time.", {"0 = disabled", "gray"}} },
    { type = "slider", key = "hideFromChat", label = "Hide from Chat", min = 0, max = 2, step = 1,
      valueLabels = {[0] = "Disabled", [1] = "Selected", [2] = "All"},
      tooltip = {{"Hide from Chat", "highlight"}, "Hide captured messages from your chat window."} },
    { type = "toggle", key = "showLevelFilteredGroups", label = "Level Filter (Groups)",
      tooltip = {{"Level Filter", "highlight"}, "Only show categories within your level range."},
      onChange = function()
        local gp = DBB2.gui.tabs.panels["Groups"]
        if gp and gp.UpdateCategories and gp:IsVisible() then gp.UpdateCategories() end
      end },

    { type = "section", label = "Window" },
    { type = "description", text = "Control how the window behaves on your screen.", fontSize = 9 },
    { type = "toggle", key = "clampToScreen", label = "Clamp to Screen", default = true,
      tooltip = {{"Clamp to Screen", "highlight"}, "Keep the main window on screen."},
      onChange = function(enabled)
        if DBB2.gui then
          DBB2.gui:SetClampedToScreen(enabled)
        end
      end },
    { type = "toggle", key = "closeOnEscape", label = "Close with Escape", default = true,
      tooltip = {{"Close with Escape", "highlight"}, "Allow the Escape key to close the main window."},
      onChange = function(enabled)
        if DBB2.gui and DBB2.gui.SetCloseOnEscape then
          DBB2.gui.SetCloseOnEscape(enabled)
        end
      end },
  })

  -- =====================
  -- CHANNELS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Channels"], {
    { type = "section", label = "Channels" },
    { type = "description", text = "Choose which chat channels are monitored for messages.", fontSize = 9 },
    { type = "toggle", key = "autoJoinChannels", label = "Auto-join World & LookingForGroup", default = true,
      tooltip = {{"Auto-Join", "highlight"}, "Automatically join these channels when you log in."} },
    { type = "section", label = "Available Channels" },
    { type = "channelList" },
  })

  -- =====================
  -- GROUPS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Groups"], {
    { type = "section", label = "Group Categories" },
    { type = "description", text = "Wildcard support: * (any), ? (one char), [a-z], {a,b}", fontSize = 9 },
    { type = "categoryList", categoryType = "groups", showFilterTags = true },
  })

  -- =====================
  -- PROFESSIONS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Professions"], {
    { type = "section", label = "Profession Categories" },
    { type = "description", text = "Wildcard support: * (any), ? (one char), [a-z], {a,b}", fontSize = 9 },
    { type = "categoryList", categoryType = "professions", showFilterTags = true },
  })

  -- =====================
  -- HARDCORE TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Hardcore"], {
    { type = "section", label = "Hardcore Categories" },
    { type = "description", text = "Wildcard support: * (any), ? (one char), [a-z], {a,b}", fontSize = 9 },
    { type = "categoryList", categoryType = "hardcore", showFilterTags = true },
  })

  -- =====================
  -- BLACKLIST TAB
  -- =====================
  -- Set config keys from API for checkbox binding
  DBB2_Config.blacklistEnabled = DBB2.api.IsBlacklistEnabled()
  DBB2_Config.blacklistHideFromChat = DBB2.api.IsBlacklistHideFromChatEnabled()
  
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Blacklist"], {
    { type = "section", label = "Blacklist" },
    { type = "description", text = "Block messages containing keywords you do not want to see.", fontSize = 9 },
    { type = "toggle", key = "blacklistEnabled", label = "Enable Blacklist Filtering",
      tooltip = {{"Enable Blacklist Filtering", "highlight"}, "Turn blacklist filtering on or off."},
      onChange = function(checked) DBB2.api.SetBlacklistEnabled(checked) end },
    { type = "toggle", key = "blacklistHideFromChat", label = "Hide messages from Chat",
      tooltip = {{"Hide from Chat", "highlight"}, "Hide blacklisted messages from your chat window."},
      onChange = function(checked) DBB2.api.SetBlacklistHideFromChat(checked) end },
    { type = "section", label = "Import & Export" },
    { type = "description", text = "Copy your blacklist to export it, or paste one here and press Enter to import.", fontSize = 9 },
    { type = "keywordImportExport" },
    { type = "section", label = "Keywords" },
    { type = "description", text = "Wildcard support: * (any), ? (one char), [a-z], {a,b}", fontSize = 9 },
    { type = "keywordList" },
  })

  -- Set default tab
  DBB2.gui.configTabs.SwitchTab("General")
end)
```

## modules/gui.lua
```lua
-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_len = string.len
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local table_remove = table.remove
local ipairs = ipairs
local pairs = pairs
local date = date
local math_max = math.max

DBB2:RegisterModule("gui", function()
  -- Initialize schema layout constants
  DBB2.schema.InitLayout()
  local S = DBB2.schema
  
  -- Constants
  local MAX_ROWS = 50
  local DEFAULT_ROW_HEIGHT = 16
  
  -- Create main GUI frame
  DBB2.gui = CreateFrame("Frame", "DBB2ConfigGUI", UIParent)
  DBB2.gui:SetMovable(true)
  DBB2.gui:EnableMouse(true)
  DBB2.gui:RegisterForDrag("LeftButton")
  DBB2.gui:SetWidth(539)
  DBB2.gui:SetHeight(343)
  DBB2.gui:SetFrameStrata("DIALOG")
  DBB2.gui:SetClampedToScreen(DBB2_Config.clampToScreen ~= false)
  DBB2.gui:SetPoint("CENTER", 0, 0)
  DBB2.gui:Hide()
  
  -- Load saved position and size
  DBB2.api.LoadPosition(DBB2.gui)
  
  DBB2.gui:SetScript("OnDragStart", function()
    this:StartMoving()
  end)
  
  DBB2.gui:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    DBB2.api.SavePosition(this)
  end)
  
  -- Create backdrop
  DBB2:CreateBackdrop(DBB2.gui, nil, nil, 0.85)
  
  local function SetCloseOnEscape(enabled)
    local frameName = "DBB2ConfigGUI"
    local found = false
    local i
    
    for i = table_getn(UISpecialFrames), 1, -1 do
      if UISpecialFrames[i] == frameName then
        if enabled and not found then
          found = true
        else
          table_remove(UISpecialFrames, i)
        end
      end
    end
    
    if enabled and not found then
      table_insert(UISpecialFrames, frameName)
    end
  end
  
  DBB2.gui.SetCloseOnEscape = SetCloseOnEscape
  SetCloseOnEscape(DBB2_Config.closeOnEscape ~= false)
  
  -- Close button - in header area between borders
  local closeSize = DBB2:ScaleSize(14)
  local headerPadding = DBB2:ScaleSize(7)
  DBB2.gui.close = CreateFrame("Button", "DBB2Close", DBB2.gui)
  DBB2.gui.close:SetPoint("TOPRIGHT", -headerPadding, -headerPadding)
  DBB2.gui.close:SetHeight(closeSize)
  DBB2.gui.close:SetWidth(closeSize)
  DBB2:CreateBackdrop(DBB2.gui.close)
  
  DBB2.gui.close.texture = DBB2.gui.close:CreateTexture(nil, "OVERLAY")
  DBB2.gui.close.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\close")
  DBB2.gui.close.texture:SetPoint("CENTER", 0, 0)
  DBB2.gui.close.texture:SetWidth(DBB2:ScaleSize(16))
  DBB2.gui.close.texture:SetHeight(DBB2:ScaleSize(16))
  DBB2.gui.close.texture:SetVertexColor(1, 0.25, 0.25, 1)
  
  DBB2.gui.close:SetScript("OnEnter", function()
    this.backdrop:SetBackdropBorderColor(1, 0.25, 0.25, 1)
  end)
  
  DBB2.gui.close:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end)
  
  DBB2.gui.close:SetScript("OnClick", function()
    this:GetParent():Hide()
  end)
  
  -- Config button - in header area between borders
  DBB2.gui.configBtn = S.CreateButton("DBB2ConfigBtn", DBB2.gui, "Config")
  DBB2.gui.configBtn:SetPoint("RIGHT", DBB2.gui.close, "LEFT", -DBB2:ScaleSize(5), 0)
  DBB2.gui.configBtn:SetWidth(DBB2:ScaleSize(50))
  DBB2.gui.configBtn:SetHeight(closeSize)
  DBB2.gui.configBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)  -- Match inactive tab color
  DBB2.gui.configBtn:SetScript("OnClick", function()
    DBB2.gui.tabs.SwitchTab("Config")
  end)
  
  -- Override hover scripts to respect active state
  DBB2.gui.configBtn:SetScript("OnEnter", function()
    if DBB2.gui.tabs.activeTab ~= "Config" then
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    end
  end)
  DBB2.gui.configBtn:SetScript("OnLeave", function()
    if DBB2.gui.tabs.activeTab ~= "Config" then
      this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
  end)
  
  -- Create tab system using schema (horizontal tabs at top, height 14 to match close/refresh)
  local tabNames = {"Logs", "Groups", "Professions", "Hardcore", "Config"}
  DBB2.gui.tabs = S.CreateTabSystem("DBB2", DBB2.gui, tabNames, 70, 14)
  
  -- Hide the Config tab button (we use the separate Config button on the right)
  DBB2.gui.tabs.buttons["Config"]:Hide()
  
  -- Store original SwitchTab function
  local originalSwitchTab = DBB2.gui.tabs.SwitchTab
  
  -- Override SwitchTab to also handle Config button styling
  DBB2.gui.tabs.SwitchTab = function(tabName)
    -- Call original function
    originalSwitchTab(tabName)
    
    -- Update Config button styling
    local hr, hg, hb = DBB2:GetHighlightColor()
    if tabName == "Config" then
      DBB2.gui.configBtn.text:SetTextColor(hr, hg, hb, 1)
      DBB2.gui.configBtn.backdrop:SetBackdropBorderColor(hr, hg, hb, 1)
    else
      DBB2.gui.configBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
      DBB2.gui.configBtn.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
  end
  
  -- Tab change callback
  DBB2.gui.tabs.onTabChanged = function(tabName)
    -- Defer update to next frame to ensure panel dimensions are calculated
    -- This fixes the issue where messages don't fill width until resize
    local panel = DBB2.gui.tabs.panels[tabName]
    if panel then
      panel._needsContentUpdate = true
      panel._contentUpdateType = tabName
    end
  end
  
  -- =====================
  -- LOGS PANEL
  -- =====================
  local logsPanel = DBB2.gui.tabs.panels["Logs"]
  
  -- Filter input with placeholder (uses schema constants)
  DBB2.gui.filterInput = S.CreateFilterInput("DBB2FilterInput", logsPanel)
  DBB2.gui.filterInput:SetPoint("TOPLEFT", logsPanel, "TOPLEFT", 0, 0)
  DBB2.gui.filterInput:SetPoint("TOPRIGHT", logsPanel, "TOPRIGHT", -S.TIME_COLUMN_WIDTH, 0)
  
  -- Current time display - aligned with message timestamps
  DBB2.gui.currentTimeText = S.CreateCurrentTimeDisplay(logsPanel)
  -- Position to align with row timestamps
  DBB2.gui.currentTimeText:SetPoint("RIGHT", logsPanel, "TOPRIGHT", -S.SCROLLBAR_SPACE + S.TIMESTAMP_RIGHT_OFFSET, -(S.FILTER_HEIGHT / 2))
  
  -- Also store reference on logsPanel for config onChange handler compatibility
  logsPanel.currentTimeText = DBB2.gui.currentTimeText
  
  -- Hide by default (controlled by config)
  if not DBB2_Config.showCurrentTime then
    DBB2.gui.currentTimeText:Hide()
  end
  
  -- Global time update frame (updates all panels at once for smooth tab transitions)
  -- Also handles periodic refresh of relative timestamps
  -- Only create once, on the main GUI frame so it always runs
  if not DBB2.gui.globalTimeFrame then
    DBB2.gui.globalTimeFrame = CreateFrame("Frame", nil, DBB2.gui)
    DBB2.gui.globalTimeFrame.elapsed = 0
    DBB2.gui.globalTimeFrame.relativeTimeElapsed = 0
    DBB2.gui.globalTimeFrame:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      this.relativeTimeElapsed = this.relativeTimeElapsed + arg1
      
      -- Update current time display every second
      if this.elapsed >= 1 then
        this.elapsed = 0
        if DBB2_Config.showCurrentTime then
          local timeStr = date("%H:%M:%S")
          -- Update Logs panel
          if DBB2.gui.currentTimeText then
            DBB2.gui.currentTimeText:SetText(timeStr)
          end
          -- Update categorized panels (Groups, Professions, Hardcore)
          local panels = {"Groups", "Professions", "Hardcore"}
          for _, panelName in ipairs(panels) do
            local panel = DBB2.gui.tabs.panels[panelName]
            if panel and panel.currentTimeText then
              panel.currentTimeText:SetText(timeStr)
            end
          end
        end
        
        -- Update elapsed timestamps every second (mode 2)
        if DBB2_Config.timeDisplayMode == 2 and DBB2.gui:IsShown() then
          if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
            local activeTab = DBB2.gui.tabs.activeTab
            if activeTab == "Logs" then
              if DBB2.gui.UpdateTimestampsOnly then DBB2.gui:UpdateTimestampsOnly() end
            else
              local panel = DBB2.gui.tabs.panels[activeTab]
              if panel and panel.UpdateTimestampsOnly then panel.UpdateTimestampsOnly() end
            end
          end
        end
      end
      
      -- Update relative timestamps every 30 seconds (to keep them fresh)
      if this.relativeTimeElapsed >= 30 then
        this.relativeTimeElapsed = 0
        if DBB2_Config.timeDisplayMode == 1 and DBB2.gui:IsShown() then
          -- Refresh active panel to update relative times
          if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
            local activeTab = DBB2.gui.tabs.activeTab
            if activeTab == "Logs" then
              if DBB2.gui.UpdateMessages then DBB2.gui:UpdateMessages() end
            else
              local panel = DBB2.gui.tabs.panels[activeTab]
              if panel and panel.UpdateCategories then panel.UpdateCategories() end
            end
          end
        end
      end
    end)
  end
  
  -- Store current filter terms
  DBB2.gui.filterTerms = {}
  
  -- Throttle state for filter updates
  DBB2.gui.filterPending = false
  DBB2.gui.filterLastText = ""
  
  -- Parse filter input into terms (minimum 2 characters per term)
  local function ParseFilterTerms(text)
    local terms = {}
    if text and text ~= "" then
      -- Split by comma
      for term in string_gfind(text, "([^,]+)") do
        -- Trim whitespace and convert to lowercase
        term = string_gsub(term, "^%s*(.-)%s*$", "%1")
        term = string_lower(term)
        -- Only include terms with at least 2 characters
        if string_len(term) >= 2 then
          table_insert(terms, term)
        end
      end
    end
    return terms
  end
  
  -- Check if message matches any filter term
  local function MessageMatchesFilter(message, terms)
    if table_getn(terms) == 0 then
      return true  -- No filter = all match
    end
    local lowerMsg = string_lower(message or "")
    for _, term in ipairs(terms) do
      if string_find(lowerMsg, term, 1, true) then
        return true
      end
    end
    return false
  end
  
  -- Throttled filter update (runs on next frame to avoid stale GetText)
  local function ScheduleLogsFilterUpdate()
    DBB2.gui.filterPending = true
  end
  
  -- Process pending filter update (called from OnUpdate)
  DBB2.gui.filterInput:SetScript("OnUpdate", function()
    if not DBB2.gui.filterPending then return end
    DBB2.gui.filterPending = false
    
    local currentText = this:GetText() or ""
    -- Only update if text actually changed (avoids redundant updates)
    if currentText ~= DBB2.gui.filterLastText then
      DBB2.gui.filterLastText = currentText
      DBB2.gui.filterTerms = ParseFilterTerms(currentText)
      -- Reset scroll to top when filter changes
      if DBB2.gui.scroll then
        DBB2.gui.scroll:SetVerticalScroll(0)
      end
      DBB2.gui:UpdateMessages()
    end
  end)
  
  -- Update filter on text change (schedules update for next frame)
  DBB2.gui.filterInput:SetScript("OnTextChanged", function()
    ScheduleLogsFilterUpdate()
  end)
  
  DBB2.gui.filterInput:SetScript("OnEnterPressed", function()
    this:ClearFocus()
  end)
  
  -- Create scroll frame for messages (using schema)
  DBB2.gui.scroll = S.CreateScrollFrame("DBB2ScrollFrame", logsPanel)
  DBB2.gui.scroll:SetPoint("TOPLEFT", logsPanel, "TOPLEFT", 0, -(S.FILTER_HEIGHT + S.FILTER_PADDING))
  DBB2.gui.scroll:SetPoint("BOTTOMRIGHT", logsPanel, "BOTTOMRIGHT", 0, 0)
  logsPanel.scrollFrame = DBB2.gui.scroll  -- Register for OnShow update
  
  -- Create scroll child (using schema)
  DBB2.gui.scrollchild = S.CreateScrollChild("DBB2ScrollChild", DBB2.gui.scroll)
  
  -- Message row pool (using schema)
  DBB2.gui.messageRows = {}
  local ROW_HEIGHT = S.ROW_HEIGHT
  
  -- Pre-create message rows using schema
  for i = 1, MAX_ROWS do
    local row = S.CreateMessageRow("DBB2MsgRow" .. i, DBB2.gui.scrollchild)
    row:SetPoint("TOPLEFT", DBB2.gui.scrollchild, "TOPLEFT", S.ROW_LEFT_PADDING, -((i-1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", DBB2.gui.scrollchild, "RIGHT", -S.SCROLLBAR_SPACE, 0)
    row:Hide()
    DBB2.gui.messageRows[i] = row
  end
  
  -- Continuously update scroll child dimensions
  local lastChildHeight = 0
  local lastScrollWidth = 0
  DBB2.gui.scroll:SetScript("OnUpdate", function()
    -- Check for deferred scroll update
    if this._needsScrollUpdate then
      this._needsScrollUpdate = false
      this.UpdateScrollState()
    end
    
    -- Early exit if not visible
    if not this:IsVisible() then return end
    
    -- Use actual rendered width (right - left) instead of GetWidth()
    local scrollLeft = this:GetLeft()
    local scrollRight = this:GetRight()
    if not scrollLeft or not scrollRight then return end
    
    local scrollWidth = scrollRight - scrollLeft
    local scrollHeight = this:GetHeight()
    
    -- Early exit if dimensions not ready
    if scrollWidth <= 0 or not scrollHeight or scrollHeight <= 0 then return end
    
    -- Only update if width changed
    if scrollWidth ~= lastScrollWidth then
      lastScrollWidth = scrollWidth
      DBB2.gui.scrollchild:SetWidth(scrollWidth)
      -- Defer message refresh to coalesce with resize updates
      DBB2.gui._resizePending = true
    end
    
    -- Calculate content height based on visible rows
    local visibleRows = 0
    for i = 1, MAX_ROWS do
      if DBB2.gui.messageRows[i]:IsShown() then
        visibleRows = visibleRows + 1
      end
    end
    
    local contentHeight = visibleRows * S.ROW_HEIGHT
    local newChildHeight = contentHeight
    
    if newChildHeight ~= lastChildHeight then
      DBB2.gui.scrollchild:SetHeight(newChildHeight)
      DBB2.gui.scrollchild:SetWidth(scrollWidth)
      lastChildHeight = newChildHeight
    end
    
    this.UpdateScrollState()
  end)
  
  -- Function to update messages
  function DBB2.gui:UpdateMessages()
    local count = table_getn(DBB2.messages)
    local filterTerms = DBB2.gui.filterTerms or {}
    local hasFilter = table_getn(filterTerms) > 0
    
    -- Hide all rows first
    for i = 1, MAX_ROWS do
      DBB2.gui.messageRows[i]:Hide()
    end
    
    if count > 0 then
      local rowIndex = 1
      
      -- Display messages (newest first)
      -- Only show messages that match Groups or Professions tags (not Hardcore)
      for i = count, 1, -1 do
        local msg = DBB2.messages[i]
        if msg and rowIndex <= MAX_ROWS then
          -- Check message categories
          local categories = nil
          if DBB2.api.CategorizeMessage then
            categories = DBB2.api.CategorizeMessage(msg.message)
          end
          
          if categories and categories.isHardcore then
          else
            -- Check if message matches any Groups or Professions tag
            local matchesCategory = false
            if categories then
              matchesCategory = (table_getn(categories.groups) > 0) or (table_getn(categories.professions) > 0)
            end
            
            -- Only show messages that match at least one category
            if matchesCategory then
              local row = DBB2.gui.messageRows[rowIndex]
              local timeStr, isOverHour = DBB2.api.FormatMessageTime(msg.time)
              
              -- Check if message matches filter
              local matches = true
              if hasFilter then
                matches = false
                local lowerMsg = string_lower(msg.message or "")
                for _, term in ipairs(filterTerms) do
                  if string_find(lowerMsg, term, 1, true) then
                    matches = true
                    break
                  end
                end
              end
              
              -- Determine class color (placeholder - white for now)
              local classColor = "|cffffffff"
              
              row:SetData(msg.sender, msg.message, timeStr, classColor)
              row._msgTime = msg.time  -- Store for lightweight time updates
              
              -- Apply filter styling
              if hasFilter and not matches then
                -- Greyed out: subtle dimmed text (only message content, not time)
                row.message:SetTextColor(0.35, 0.35, 0.35, 1)
                row.charName:SetTextColor(0.35, 0.35, 0.35, 1)
                row._isFiltered = true  -- Track filter state for UpdateTimestampsOnly
              else
                -- Normal colors (no filter or matches)
                row.message:SetTextColor(0.9, 0.9, 0.9, 1)
                -- Only set charName color if not currently hovered
                if not row.charNameBtn or not row.charNameBtn.isHovered then
                  row.charName:SetTextColor(1, 1, 1, 1)
                end
                row._isFiltered = false  -- Track filter state for UpdateTimestampsOnly
              end
              
              -- Timestamp color is independent of filter state
              if isOverHour then
                row.time:SetTextColor(1, 0.3, 0.3, 1)
              else
                row.time:SetTextColor(0.5, 0.5, 0.5, 1)
              end
              
              row:Show()
              rowIndex = rowIndex + 1
            end
          end
        end
      end
    end
  end
  
  -- Lightweight function to update only timestamps (no row rebuilding)
  function DBB2.gui:UpdateTimestampsOnly()
    for i = 1, MAX_ROWS do
      local row = DBB2.gui.messageRows[i]
      if row:IsShown() and row._msgTime then
        local timeStr, isOverHour = DBB2.api.FormatMessageTime(row._msgTime)
        row.time:SetText(timeStr)
        if isOverHour then
          row.time:SetTextColor(1, 0.3, 0.3, 1)
        else
          row.time:SetTextColor(0.5, 0.5, 0.5, 1)
        end
      end
    end
  end
  
  -- =====================
  -- CATEGORIZED PANELS (Groups, Professions, Hardcore)
  -- =====================
  
  -- Create categorized panel for each type
  local function CreateCategorizedPanel(panelName, categoryType)
    local panel = DBB2.gui.tabs.panels[panelName]
    
    -- Shared row pool constants
    local MAX_POOL_ROWS = 100
    local ROW_HEIGHT = S.ROW_HEIGHT
    
    -- Filter input with placeholder (using schema)
    panel.filterInput = S.CreateFilterInput("DBB2" .. panelName .. "FilterInput", panel)
    panel.filterInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.filterInput:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -S.TIME_COLUMN_WIDTH, 0)
    
    -- Current time display - aligned with message timestamps (using schema)
    panel.currentTimeText = S.CreateCurrentTimeDisplay(panel)
    panel.currentTimeText:SetPoint("RIGHT", panel, "TOPRIGHT", -S.SCROLLBAR_SPACE + S.TIMESTAMP_RIGHT_OFFSET, -(S.FILTER_HEIGHT / 2))
    
    -- Hide by default (controlled by config)
    if not DBB2_Config.showCurrentTime then
      panel.currentTimeText:Hide()
    end
    
    -- Store filter terms
    panel.filterTerms = {}
    
    -- Throttle state for filter updates
    panel.filterPending = false
    panel.filterLastText = ""
    
    -- Parse filter input into terms (minimum 2 characters per term)
    local function ParseFilterTerms(text)
      local terms = {}
      if text and text ~= "" then
        for term in string_gfind(text, "([^,]+)") do
          term = string_gsub(term, "^%s*(.-)%s*$", "%1")
          term = string_lower(term)
          -- Only include terms with at least 2 characters
          if string_len(term) >= 2 then
            table_insert(terms, term)
          end
        end
      end
      return terms
    end
    
    -- Throttled filter update (runs on next frame to avoid stale GetText)
    local function ScheduleFilterUpdate()
      if panel.filterPending then return end
      panel.filterPending = true
    end
    
    -- Process pending filter update (called from OnUpdate)
    panel.filterInput:SetScript("OnUpdate", function()
      if not panel.filterPending then return end
      panel.filterPending = false
      
      local currentText = this:GetText() or ""
      -- Only update if text actually changed (avoids redundant updates)
      if currentText ~= panel.filterLastText then
        panel.filterLastText = currentText
        panel.filterTerms = ParseFilterTerms(currentText)
        -- Reset scroll to top when filter changes
        if panel.scroll then
          panel.scroll:SetVerticalScroll(0)
        end
        if panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end)
    
    -- Update filter on text change (schedules update for next frame)
    panel.filterInput:SetScript("OnTextChanged", function()
      ScheduleFilterUpdate()
    end)
    
    panel.filterInput:SetScript("OnEnterPressed", function()
      this:ClearFocus()
    end)
    
    -- Create scroll frame for categories (using schema)
    local scroll = S.CreateScrollFrame("DBB2" .. panelName .. "Scroll", panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(S.FILTER_HEIGHT + S.FILTER_PADDING))
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.scrollFrame = scroll  -- Register for OnShow update
    
    local scrollchild = S.CreateScrollChild("DBB2" .. panelName .. "ScrollChild", scroll)
    
    -- Store references
    panel.scroll = scroll
    panel.scrollchild = scrollchild
    panel.categoryType = categoryType
    panel.categoryFrames = {}
    
    -- Shared row pool (like Logs panel)
    panel.rowPool = {}
    panel.rowPoolIndex = 0
    
    -- Pre-create pooled rows (using schema)
    for i = 1, MAX_POOL_ROWS do
      local row = S.CreateMessageRow("DBB2" .. panelName .. "PoolRow" .. i, scrollchild)
      row:Hide()
      panel.rowPool[i] = row
    end
    
    -- Get next available row from pool
    local function GetPooledRow()
      panel.rowPoolIndex = panel.rowPoolIndex + 1
      if panel.rowPoolIndex <= MAX_POOL_ROWS then
        return panel.rowPool[panel.rowPoolIndex]
      end
      return nil
    end
    
    -- Reset pool at start of each update
    local function ResetRowPool()
      for i = 1, panel.rowPoolIndex do
        if panel.rowPool[i] then
          panel.rowPool[i]:Hide()
        end
      end
      panel.rowPoolIndex = 0
    end
    
    -- Helper function to check if category tags match any filter term
    local function CategoryMatchesFilter(cat, filterTerms)
      if not cat or not cat.tags then return false end
      for _, term in ipairs(filterTerms) do
        -- Check category tags (exact match only)
        for _, tag in ipairs(cat.tags) do
          if string_lower(tag) == term then
            return true
          end
        end
      end
      return false
    end
    
    -- Update function for this panel
    panel.UpdateCategories = function()
      -- Reset row pool
      ResetRowPool()
      
      -- Hide all existing category frames
      for _, frame in pairs(panel.categoryFrames) do
        frame:Hide()
      end
      
      local categorized = DBB2.api.GetCategorizedMessages(categoryType)
      local categories = DBB2.api.GetCategories(categoryType)
      local yOffset = 0
      local hr, hg, hb = DBB2:GetHighlightColor()
      local filterTerms = panel.filterTerms or {}
      local hasFilter = table_getn(filterTerms) > 0
      
      for _, cat in ipairs(categories) do
        if cat.selected then
          -- Level filter check for Groups tab only
          -- Skip categories outside player's level range when filter is enabled
          local passesLevelFilter = true
          if categoryType == "groups" and DBB2_Config.showLevelFilteredGroups then
            passesLevelFilter = DBB2.api.IsLevelAppropriate(cat.name)
          end
          
          if passesLevelFilter then
          local messages = categorized[cat.name] or {}
          local msgCount = table_getn(messages)
          local isCollapsed = DBB2.api.IsCategoryCollapsed(categoryType, cat.name)
          
          -- Check if this category is locked (only for Groups tab)
          -- Locked categories display with red [Saved] tag but function normally
          -- (can be expanded/collapsed, notifications work, etc.)
          local isLocked = false
          local lockoutInfo = nil
          if categoryType == "groups" and DBB2.api.IsCategoryLocked then
            isLocked = DBB2.api.IsCategoryLocked(cat.name)
            if isLocked then
              lockoutInfo = DBB2.api.GetCategoryLockout(cat.name)
            end
          end
          
          -- Check if category matches filter via tags/name
          local categoryMatchesTags = hasFilter and CategoryMatchesFilter(cat, filterTerms)
          
          -- Filter messages if filter is active
          local filteredMessages = {}
          if hasFilter then
            if categoryMatchesTags then
              -- Category matches by tag/name - show ALL its messages
              filteredMessages = messages
            else
              -- Category doesn't match by tag - filter messages by content
              for _, msg in ipairs(messages) do
                local lowerMsg = string_lower(msg.message or "")
                for _, term in ipairs(filterTerms) do
                  if string_find(lowerMsg, term, 1, true) then
                    table_insert(filteredMessages, msg)
                    break
                  end
                end
              end
            end
          else
            filteredMessages = messages
          end
          
          local filteredCount = table_getn(filteredMessages)
          
          if hasFilter and filteredCount == 0 and not categoryMatchesTags then
          else
            -- Always show enabled categories (even with 0 messages when no filter)
            -- Get or create category frame
            local catFrame = panel.categoryFrames[cat.name]
            if not catFrame then
              catFrame = CreateFrame("Frame", nil, scrollchild)
              -- No right offset - let rows handle their own offset like Logs panel
              catFrame:SetPoint("LEFT", scrollchild, "LEFT", 0, 0)
              catFrame:SetPoint("RIGHT", scrollchild, "RIGHT", 0, 0)
              panel.categoryFrames[cat.name] = catFrame
              
              -- Clickable header button (for collapse only)
              catFrame.headerBtn = CreateFrame("Button", nil, catFrame)
              catFrame.headerBtn:SetPoint("TOPLEFT", 0, 0)
              catFrame.headerBtn:SetPoint("TOPRIGHT", 0, 0)
              catFrame.headerBtn:SetHeight(S.CATEGORY_HEADER_HEIGHT)
              catFrame.headerBtn:EnableMouse(true)
              
              -- Collapse indicator
              catFrame.collapseIndicator = catFrame.headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
              catFrame.collapseIndicator:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(14))
              catFrame.collapseIndicator:SetPoint("LEFT", S.ROW_LEFT_PADDING, 0)
              catFrame.collapseIndicator:SetWidth(DBB2:ScaleSize(12))
              catFrame.collapseIndicator:SetText("+")
              
              -- Category header text
              catFrame.header = catFrame.headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
              catFrame.header:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(10))
              catFrame.header:SetPoint("LEFT", catFrame.collapseIndicator, "RIGHT", 3, 0)
              catFrame.header:SetTextColor(hr, hg, hb, 1)

              catFrame.levelRange = catFrame.headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
              catFrame.levelRange:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\WarSansTT-Bliz-500.ttf", DBB2:GetFontSize(9))
              catFrame.levelRange:SetTextColor(0.48, 0.48, 0.48, 1)
              catFrame.levelRange:Hide()
              
              -- Bell button for notifications (right after header text)
              local bellSize = DBB2:ScaleSize(14)
              catFrame.bellBtn = CreateFrame("Button", nil, catFrame)
              catFrame.bellBtn:SetPoint("LEFT", catFrame.header, "RIGHT", 3, 0)
              catFrame.bellBtn:SetWidth(bellSize)
              catFrame.bellBtn:SetHeight(bellSize)
              catFrame.bellBtn:SetFrameLevel(catFrame.headerBtn:GetFrameLevel() + 1)
              catFrame.bellBtn:EnableMouse(true)
              
              catFrame.UpdateHeaderLayout = function(showBell)
                catFrame.levelRange:ClearAllPoints()
                if showBell then
                  catFrame.levelRange:SetPoint("LEFT", catFrame.bellBtn, "RIGHT", 3, 0)
                else
                  catFrame.levelRange:SetPoint("LEFT", catFrame.header, "RIGHT", 3, 0)
                end
              end
              
              catFrame.UpdateHeaderLayout(false)
              
              catFrame.bellIcon = catFrame.bellBtn:CreateTexture(nil, "OVERLAY")
              catFrame.bellIcon:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\bell")
              catFrame.bellIcon:SetAllPoints()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
              catFrame.bellBtn:Hide()
              
              -- Store references for bell click handler
              catFrame.bellBtn.categoryName = cat.name
              catFrame.bellBtn.categoryType = categoryType
              catFrame.bellBtn.catFrame = catFrame
              
              catFrame.bellBtn:SetScript("OnClick", function()
                local isEnabled = DBB2.api.IsNotificationEnabled(this.categoryType, this.categoryName)
                if isEnabled and IsShiftKeyDown() then
                  DBB2.api.DisableAllNotifications()
                  return
                end
                DBB2.api.SetNotificationEnabled(this.categoryType, this.categoryName, not isEnabled)
                panel.UpdateCategories()
              end)
              
              catFrame.bellBtn:SetScript("OnEnter", function()
                -- Brighten the bell on hover
                this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
              end)
              
              catFrame.bellBtn:SetScript("OnLeave", function()
                -- Restore bell state based on notification status
                local notifyMode = DBB2.api.GetNotificationMode()
                local isEnabled = DBB2.api.IsNotificationEnabled(this.categoryType, this.categoryName)
                if notifyMode <= 0 then
                  this:Hide()
                elseif isEnabled then
                  this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
                  this:Show()
                else
                  this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.22)
                  this:Show()
                end
              end)
              
              -- Store references for click handler
              catFrame.categoryName = cat.name
              catFrame.categoryType = categoryType
              
              -- Click handler (collapse only)
              catFrame.headerBtn:SetScript("OnClick", function()
                DBB2.api.ToggleCategoryCollapsed(catFrame.categoryType, catFrame.categoryName)
                panel.UpdateCategories()
              end)
              
              -- Hover effect - brighten bell while hovering the header
              catFrame.headerBtn:SetScript("OnEnter", function()
                catFrame.header:SetTextColor(1, 1, 1, 1)
                catFrame.collapseIndicator:SetTextColor(1, 1, 1, 1)
                if catFrame.levelRange:IsShown() then
                  catFrame.levelRange:SetTextColor(0.7, 0.7, 0.7, 1)
                end
                local notifyMode = DBB2.api.GetNotificationMode()
                if notifyMode > 0 then
                  catFrame.bellBtn:Show()
                  catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.7)
                end

              end)
              
              catFrame.headerBtn:SetScript("OnLeave", function()
                -- Restore appropriate color based on current state (stored on frame)
                local hr, hg, hb = DBB2:GetHighlightColor()
                -- Check if collapsed (+ means collapsed)
                local isCollapsed = catFrame.collapseIndicator:GetText() == "+"
                
                -- Collapse indicator: always red when collapsed
                if isCollapsed then
                  catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.isLocked then
                  catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.currentMsgCount and catFrame.currentMsgCount > 0 then
                  catFrame.collapseIndicator:SetTextColor(hr, hg, hb, 1)
                else
                  catFrame.collapseIndicator:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                
                -- Header color based on locked/message state (not collapse state)
                if catFrame.isLocked then
                  catFrame.header:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.currentMsgCount and catFrame.currentMsgCount > 0 then
                  catFrame.header:SetTextColor(hr, hg, hb, 1)
                else
                  catFrame.header:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                if catFrame.levelRange:IsShown() then
                  catFrame.levelRange:SetTextColor(0.48, 0.48, 0.48, 1)
                end
                -- Restore the subtle bell unless notifications are globally off
                local notifyMode = DBB2.api.GetNotificationMode()
                local isEnabled = DBB2.api.IsNotificationEnabled(catFrame.categoryType, catFrame.categoryName)
                if notifyMode <= 0 then
                  catFrame.bellBtn:Hide()
                elseif isEnabled then
                  catFrame.bellBtn:Show()
                  catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
                else
                  catFrame.bellBtn:Show()
                  catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.22)
                end
                DBB2.api.HideTooltip()
              end)
            end
            
            -- Store lockout state on frame
            catFrame.isLocked = isLocked
            catFrame.lockoutInfo = lockoutInfo
            
            -- Update collapse indicator
            if isCollapsed then
              catFrame.collapseIndicator:SetText("+")
              catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)  -- Red when collapsed
            else
              catFrame.collapseIndicator:SetText("-")
            end
            
            -- Update header with count (show filtered count if filtering)
            local displayCount = filteredCount
            -- Store current message count on frame for OnLeave handler
            catFrame.currentMsgCount = displayCount
            
            -- Determine header text and color based on lockout and message count
            local headerText = cat.name
            local levelRangeText = nil
            if displayCount > 0 then
              headerText = cat.name .. " (" .. displayCount .. ")"
            end
            if categoryType == "groups" and DBB2_Config.showGroupLevelRanges then
              levelRangeText = DBB2.api.GetCategoryLevelRangeText(cat.name)
            end
            
            -- Add lockout indicator to header with reset time
            if isLocked and lockoutInfo then
              local remaining = lockoutInfo.resetTime - time()
              local timeStr = DBB2.api.FormatTimeRemaining(remaining)
              headerText = headerText .. " |cffff6666[Saved - " .. timeStr .. "]|r"
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(0.8, 0.3, 0.3, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
              end
            elseif displayCount > 0 then
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(hr, hg, hb, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(hr, hg, hb, 1)
              end
            else
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(0.5, 0.5, 0.5, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(0.5, 0.5, 0.5, 1)
              end
            end

            if levelRangeText then
              catFrame.levelRange:SetText(levelRangeText)
              catFrame.levelRange:Show()
            else
              catFrame.levelRange:SetText("")
              catFrame.levelRange:Hide()
            end
            
            -- Show/hide bell button based on notification state and mode
            local notifyMode = DBB2.api.GetNotificationMode()
            local notifyEnabled = DBB2.api.IsNotificationEnabled(categoryType, cat.name)
            local showBell = notifyMode > 0
            catFrame.UpdateHeaderLayout(showBell)
            
            if notifyMode > 0 and notifyEnabled then
              catFrame.bellBtn:Show()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
            elseif notifyMode > 0 then
              catFrame.bellBtn:Show()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.22)
            else
              catFrame.bellBtn:Hide()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.22)
            end
            -- Update bell button references (in case category was reused)
            catFrame.bellBtn.categoryName = cat.name
            catFrame.bellBtn.categoryType = categoryType
            
            -- Position category frame - use explicit width from scroll frame
            catFrame:ClearAllPoints()
            catFrame:SetPoint("TOPLEFT", scrollchild, "TOPLEFT", 0, -yOffset)
            -- Get scroll frame width and set catFrame width explicitly
            -- Subtract scrollbar space to avoid overlap
            local sfLeft = scroll:GetLeft()
            local sfRight = scroll:GetRight()
            if sfLeft and sfRight and sfRight > sfLeft then
              catFrame:SetWidth(sfRight - sfLeft - S.SCROLLBAR_SPACE)
            else
              -- Fallback to anchor-based
              catFrame:SetPoint("RIGHT", scrollchild, "RIGHT", -S.SCROLLBAR_SPACE, 0)
            end
            
            -- Create/update message rows using shared pool
            local headerHeight = S.CATEGORY_HEADER_HEIGHT
            local maxSetting = DBB2_Config.maxMessagesPerCategory or 5
            local maxMessages
            if maxSetting == 0 then
              maxMessages = filteredCount  -- Unlimited
            else
              maxMessages = math.min(filteredCount, maxSetting)
            end
            
            -- Only show messages if not collapsed
            local visibleMessages = 0
            if not isCollapsed then
              -- Show messages (newest first)
              for i = 1, maxMessages do
                local msgIndex = filteredCount - i + 1
                local msg = filteredMessages[msgIndex]
                
                if msg then
                  local row = GetPooledRow()
                  if not row then break end
                  
                  -- Reparent row to category frame
                  row:SetParent(catFrame)
                  row:ClearAllPoints()
                  row:SetPoint("TOPLEFT", catFrame, "TOPLEFT", S.ROW_LEFT_PADDING, -(headerHeight + (i-1) * ROW_HEIGHT))
                  row:SetPoint("RIGHT", catFrame, "RIGHT", 0, 0)
                  
                  local timeStr, isOverHour = DBB2.api.FormatMessageTime(msg.time)
                  row:SetData(msg.sender, msg.message, timeStr, "|cffffffff")
                  row._msgTime = msg.time  -- Store for lightweight time updates
                  row.message:SetTextColor(0.9, 0.9, 0.9, 1)
                  -- Only set charName color if not currently hovered
                  if not row.charNameBtn or not row.charNameBtn.isHovered then
                    row.charName:SetTextColor(1, 1, 1, 1)
                  end
                  -- Red if over 1 hour in elapsed mode
                  if isOverHour then
                    row.time:SetTextColor(1, 0.3, 0.3, 1)
                  else
                    row.time:SetTextColor(0.5, 0.5, 0.5, 1)
                  end
                  row:Show()
                  visibleMessages = visibleMessages + 1
                end
              end
            end
            
            -- Set category frame height
            local catHeight
            if isCollapsed or visibleMessages == 0 then
              catHeight = headerHeight + S.CATEGORY_SPACING  -- Just header height
            else
              catHeight = headerHeight + (visibleMessages * ROW_HEIGHT) + S.CATEGORY_SPACING
            end
            catFrame:SetHeight(catHeight)
            catFrame:Show()
            
            yOffset = yOffset + catHeight + S.CATEGORY_SPACING
          end
          end  -- if passesLevelFilter
        end
      end
      
      -- Update scroll child height (includes bottom padding for extra scroll space)
      local bottomPadding = S.GUI_PADDING * 3  -- Extra scroll space
      local scrollHeight = scroll:GetHeight()
      local newChildHeight = math_max(yOffset + bottomPadding, scrollHeight)
      scrollchild:SetHeight(newChildHeight)
      scrollchild:SetWidth(scroll:GetWidth() or 1)
      -- Defer UpdateScrollState to next frame so WoW can recalculate scroll range
      scroll._needsScrollUpdate = true
    end
    
    -- Lightweight function to update only timestamps (no row rebuilding)
    panel.UpdateTimestampsOnly = function()
      for i = 1, panel.rowPoolIndex do
        local row = panel.rowPool[i]
        if row and row:IsShown() and row._msgTime then
          local timeStr, isOverHour = DBB2.api.FormatMessageTime(row._msgTime)
          row.time:SetText(timeStr)
          -- Red if over 1 hour in elapsed mode
          if isOverHour then
            row.time:SetTextColor(1, 0.3, 0.3, 1)
          else
            row.time:SetTextColor(0.5, 0.5, 0.5, 1)
          end
        end
      end
    end
    
    -- Update scroll child width on size change
    -- Track last width to avoid redundant updates
    local lastCatScrollWidth = 0
    scroll:SetScript("OnUpdate", function()
      -- Check for deferred scroll update
      if this._needsScrollUpdate then
        this._needsScrollUpdate = false
        this.UpdateScrollState()
      end
      
      -- Early exit if not visible
      if not this:IsVisible() then return end
      
      local scrollLeft = this:GetLeft()
      local scrollRight = this:GetRight()
      if not scrollLeft or not scrollRight then return end
      
      local scrollWidth = scrollRight - scrollLeft
      
      -- Only update if width actually changed
      if scrollWidth > 0 and scrollWidth ~= lastCatScrollWidth then
        lastCatScrollWidth = scrollWidth
        scrollchild:SetWidth(scrollWidth)
        -- Defer category refresh to coalesce with resize updates
        DBB2.gui._resizePending = true
      end
    end)
  end
  
  -- Create the three categorized panels
  CreateCategorizedPanel("Groups", "groups")
  CreateCategorizedPanel("Professions", "professions")
  CreateCategorizedPanel("Hardcore", "hardcore")
  
  -- Config panel content is created by modules/config.lua
  
  -- =====================
  -- INITIALIZATION
  -- =====================
  
  -- Update messages when shown
  DBB2.gui:SetScript("OnShow", function()
    -- Refresh lockout data
    if DBB2.api.RefreshLockouts then
      DBB2.api.RefreshLockouts()
    end
    -- Switch to configured default tab
    local defaultTabNames = {"Logs", "Groups", "Professions", "Hardcore"}
    local tabIndex = (DBB2_Config.defaultTab or 0) + 1  -- Convert 0-based to 1-based
    local tabName = defaultTabNames[tabIndex] or "Logs"
    DBB2.gui.tabs.SwitchTab(tabName)
    -- Defer a second update to next frame to ensure proper dimensions are calculated
    -- This fixes the issue where messages don't fill width until resize
    this._needsDeferredUpdate = true
  end)
  
  -- Handle deferred update after OnShow AND deferred resize updates
  DBB2.gui:SetScript("OnUpdate", function()
    local needsUpdate = this._needsDeferredUpdate or DBB2.gui._resizePending
    if not needsUpdate then return end
    
    this._needsDeferredUpdate = nil
    DBB2.gui._resizePending = false
    
    local activeTab = DBB2.gui.tabs.activeTab
    if activeTab == "Logs" then
      DBB2.gui:UpdateMessages()
      if DBB2.gui.scroll and DBB2.gui.scroll.UpdateScrollState then
        DBB2.gui.scroll.UpdateScrollState()
      end
    elseif activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
      local panel = DBB2.gui.tabs.panels[activeTab]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
      if panel and panel.scroll and panel.scroll.UpdateScrollState then
        panel.scroll.UpdateScrollState()
      end
    end
  end)
  
  -- Add resize grip using schema
  local baseMinWidth = 410
  local baseMinHeight = 275
  -- Calculate scale factor directly to avoid cache issues
  local scaleFactor = DBB2:GetScaleFactor()
  local scaledMinWidth = math.floor(baseMinWidth * scaleFactor + 0.5)
  local scaledMinHeight = math.floor(baseMinHeight * scaleFactor + 0.5)
  DBB2.gui.resizeGrip = S.CreateResizeGrip(DBB2.gui, scaledMinWidth, scaledMinHeight)
  
  -- Enforce minimum size on loaded position (in case saved size is smaller than scaled minimum)
  local minW = DBB2.gui.resizeGrip.minWidth
  local minH = DBB2.gui.resizeGrip.minHeight
  if DBB2.gui:GetWidth() < minW then
    DBB2.gui:SetWidth(minW)
  end
  if DBB2.gui:GetHeight() < minH then
    DBB2.gui:SetHeight(minH)
  end
  
  -- Update messages when window is resized (throttled to avoid client crash)
  -- The 1.12 client can ACCESS_VIOLATION if we rebuild all rows on every pixel
  -- of a drag resize, so we defer the heavy update to the next frame instead.
  DBB2.gui._resizePending = false
  DBB2.gui:SetScript("OnSizeChanged", function()
    DBB2.gui._resizePending = true
  end)
  
  -- Set default tab based on config
  local defaultTabNames = {"Logs", "Groups", "Professions", "Hardcore"}
  local tabIndex = (DBB2_Config.defaultTab or 0) + 1  -- Convert 0-based to 1-based
  local tabName = defaultTabNames[tabIndex] or "Logs"
  DBB2.gui.tabs.SwitchTab(tabName)
end)
```

## modules/minimap.lua
```lua
-- Localize frequently used globals for performance
local math_rad = math.rad
local math_deg = math.deg
local math_cos = math.cos
local math_sin = math.sin
local math_atan2 = math.atan2

DBB2:RegisterModule("minimap", function()
  -- Create minimap button (standard circular minimap button)
  DBB2.minimapButton = CreateFrame("Button", "DBB2MinimapButton", Minimap)
  DBB2.minimapButton:SetFrameStrata("MEDIUM")
  DBB2.minimapButton:SetWidth(31)
  DBB2.minimapButton:SetHeight(31)
  DBB2.minimapButton:SetFrameLevel(8)
  DBB2.minimapButton:RegisterForDrag("LeftButton")
  DBB2.minimapButton:SetMovable(true)
  DBB2.minimapButton:SetClampedToScreen(true)
  DBB2.minimapButton:EnableMouse(true)
  DBB2.minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  
  -- Create overlay frame for circular mask
  DBB2.minimapButton.overlay = CreateFrame("Frame", nil, DBB2.minimapButton)
  DBB2.minimapButton.overlay:SetWidth(53)
  DBB2.minimapButton.overlay:SetHeight(53)
  DBB2.minimapButton.overlay:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay:SetFrameLevel(DBB2.minimapButton:GetFrameLevel() + 1)
  
  -- Create overlay texture (circular border)
  DBB2.minimapButton.overlay.texture = DBB2.minimapButton.overlay:CreateTexture(nil, "OVERLAY")
  DBB2.minimapButton.overlay.texture:SetWidth(53)
  DBB2.minimapButton.overlay.texture:SetHeight(53)
  DBB2.minimapButton.overlay.texture:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay.texture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  
  -- Create icon texture (circular)
  DBB2.minimapButton.icon = DBB2.minimapButton:CreateTexture(nil, "BACKGROUND")
  DBB2.minimapButton.icon:SetWidth(20)
  DBB2.minimapButton.icon:SetHeight(20)
  DBB2.minimapButton.icon:SetPoint("TOPLEFT", 7, -5)
  DBB2.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  DBB2.minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  
  -- Dragging functionality
  DBB2.minimapButton.angle = DBB2_Config.minimapAngle or 45
  DBB2.minimapButton.freePos = DBB2_Config.minimapFreePos or nil
  DBB2.minimapButton.freeMode = DBB2_Config.minimapFreeMode or false
  
  local function UpdatePosition()
    DBB2.minimapButton:ClearAllPoints()
    
    if DBB2.minimapButton.freeMode and DBB2.minimapButton.freePos then
      -- Free positioning mode - position relative to UIParent
      DBB2.minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", DBB2.minimapButton.freePos.x, DBB2.minimapButton.freePos.y)
    else
      -- Locked to minimap circle
      local angle = math_rad(DBB2.minimapButton.angle)
      local radius = 80
      local x = math_cos(angle) * radius
      local y = math_sin(angle) * radius
      DBB2.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
  end
  
  DBB2.minimapButton:SetScript("OnDragStart", function()
    this:LockHighlight()
    this.isDragging = true
    this.freeDragging = IsControlKeyDown()
  end)
  
  DBB2.minimapButton:SetScript("OnDragStop", function()
    this:UnlockHighlight()
    this.isDragging = false
    this.freeDragging = false
    DBB2_Config.minimapAngle = DBB2.minimapButton.angle
    DBB2_Config.minimapFreePos = DBB2.minimapButton.freePos
    DBB2_Config.minimapFreeMode = DBB2.minimapButton.freeMode
  end)
  
  DBB2.minimapButton:SetScript("OnUpdate", function()
    if this.isDragging then
      local mx, my = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      mx = mx / scale
      my = my / scale
      
      if this.freeDragging then
        -- Free drag mode - place anywhere
        DBB2.minimapButton.freeMode = true
        DBB2.minimapButton.freePos = { x = mx, y = my }
      else
        -- Locked drag mode - rotate around minimap
        DBB2.minimapButton.freeMode = false
        local px, py = Minimap:GetCenter()
        local angle = math_deg(math_atan2(my - py, mx - px))
        DBB2.minimapButton.angle = angle
      end
      UpdatePosition()
    end
  end)
  
  -- Click handler
  DBB2.minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
      if DBB2.gui:IsShown() then
        DBB2.gui:Hide()
      else
        DBB2.gui:Show()
      end
    elseif arg1 == "RightButton" and IsControlKeyDown() then
      -- Reset position to default (locked mode, 45 degrees)
      DBB2.minimapButton.angle = 45
      DBB2.minimapButton.freeMode = false
      DBB2.minimapButton.freePos = nil
      DBB2_Config.minimapAngle = 45
      DBB2_Config.minimapFreeMode = false
      DBB2_Config.minimapFreePos = nil
      UpdatePosition()
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaa7ccDBB2:|r Minimap button position reset.")
    end
  end)
  
  -- Tooltip
  DBB2.minimapButton:SetScript("OnEnter", function()
    DBB2.api.ShowTooltip(this, "LEFT", {
      {"|cffaaa7ccDifficult|cffffffffBulletinBoard", "highlight"},
      "Left-click to toggle window",
      "Drag to rotate around minimap",
      "Ctrl + Drag to move freely",
      "Ctrl + Right-click to reset position"
    })
  end)
  
  DBB2.minimapButton:SetScript("OnLeave", function()
    DBB2.api.HideTooltip()
  end)
  
  -- Initial position
  UpdatePosition()
end)
```

## modules/version_check.lua
```lua
-- DBB2 Version Check API
-- Notifies users when a newer version is available via addon channel communication
-- Uses the TOC ## Version field as the single source of truth

local ADDON_PREFIX = "DBB2Ver"
local MY_VERSION = GetAddOnMetadata("DifficultBulletinBoard", "Version") or "0.0"

-- Session flag to only show upgrade notification once per login
local notifiedThisSession = false

-- Parse version string to comparable number (e.g., "2.33" -> 2033)
local function ParseVersion(str)
  if not str then return 0 end
  local _, _, major, minor = string.find(str, "^(%d+)%.(%d+)")
  return (tonumber(major) or 0) * 1000 + (tonumber(minor) or 0)
end

-- Check if version A is newer than version B
local function IsNewerVersion(versionA, versionB)
  return ParseVersion(versionA) > ParseVersion(versionB)
end

-- Show upgrade notification to user
local function ShowUpgradeNotification(newVersion)
  if notifiedThisSession then return end
  notifiedThisSession = true
  
  local hr, hg, hb = DBB2:GetHighlightColor()
  local hexColor = string.format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
  DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: A new version |cff00ff00v" .. newVersion .. "|r is available!")
  DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: |cff88aaffhttps://github.com/DeterminedPanda/DifficultBulletinBoard|r")
end

-- Check if we should show notification (called 10s after login)
local function CheckForUpdateNotification()
  local newestSeen = DBB2_Config.newestVersionSeen
  if newestSeen and IsNewerVersion(newestSeen, MY_VERSION) then
    ShowUpgradeNotification(newestSeen)
  end
end

-- Broadcast our version to available channels
local function BroadcastVersion()
  -- RAID covers both raid and party (auto-downgrades to PARTY if not in raid)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "RAID")
  -- GUILD (silently ignored if not in a guild)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "GUILD")
  -- BATTLEGROUND (silently ignored if not in a battleground)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "BATTLEGROUND")
end

-- Handle incoming addon message
local function OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= ADDON_PREFIX then return end
  
  -- Ignore our own messages
  local playerName = UnitName("player")
  if sender == playerName then return end
  
  local theirVersion = message
  
  -- Check if they have a newer version than us
  if IsNewerVersion(theirVersion, MY_VERSION) then
    -- Save it for next login (don't notify mid-session)
    local currentNewest = DBB2_Config.newestVersionSeen
    if not currentNewest or IsNewerVersion(theirVersion, currentNewest) then
      DBB2_Config.newestVersionSeen = theirVersion
    end
  end
end

-- Initialize version check system
local function InitVersionCheck()
  -- Register for addon messages
  DBB2:RegisterEvent("CHAT_MSG_ADDON")
  
  -- Hook into the main event handler
  local originalOnEvent = DBB2:GetScript("OnEvent")
  DBB2:SetScript("OnEvent", function()
    -- Handle addon messages
    if event == "CHAT_MSG_ADDON" then
      OnAddonMessage(arg1, arg2, arg3, arg4)
      return
    end
    
    -- Call original handler
    if originalOnEvent then
      originalOnEvent()
    end
  end)
  
  -- Schedule version broadcast and update check 10 seconds after login
  local delayFrame = CreateFrame("Frame")
  delayFrame.elapsed = 0
  delayFrame.waiting = true
  delayFrame:SetScript("OnUpdate", function()
    if not this.waiting then return end
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 10 then
      CheckForUpdateNotification()
      BroadcastVersion()
      this.waiting = false
      this:Hide()
    end
  end)
end

-- Register module
DBB2:RegisterModule("version_check", InitVersionCheck)
```

## README.md
```md
RIP Turtle 2018-2026 🐢  Adding Chinese compatibility for Capybara Paradise 
<img width="678" height="346" alt="image" src="https://github.com/user-attachments/assets/9471dbc4-2db4-41f1-a828-453c94ab9fb9" />


# Difficult Bulletin Board - Addon for Turtle WoW

**Difficult Bulletin Board** is a World of Warcraft 1.12 addon inspired by the LFG Group Bulletin Board. It scans world chat and organizes messages into an easy-to-read UI, making it more convenient to find what you need.

## Features

- **Groups Logs**: Track and filter all group-related messages in one consolidated view.
- **Group Finder**: Easily locate groups for the content you want to do.
- **Profession Search**: Quickly find players offering or seeking crafting services.
- **Hardcore Messages**: Stay updated with hardcore-related events, such as deaths or level-ups.
- **Auto-detect Hardcore Chat**: Show only messages aimed at hardcore characters.
- **Blacklist Filter**: Hide all messages matching your blacklist.
- **Expiration Date**: Set an expiration date to automatically delete old messages—or turn automatic deletion off entirely.
- **Collapsible Topics**: Collapse topics to hide unwanted messages and keep your feed tidy.
- **Notification System**: Be notified if an entry gets added to a specific topic.
- **Lockouts Track**: Keep track of raids your are saved to.



![85ad664551023708](https://github.com/user-attachments/assets/b474d2c6-60a6-4116-b5c7-8e3df43d0f58)



## Installation

1. Download the addon by clicking the link below:
   - [Download Difficult Bulletin Board](https://github.com/thezephyrsong/DifficultBulletinBoard/archive/refs/heads/master.zip)

2. Unzip the `DifficultBulletinBoard-master.zip` archive.

3. Rename the directory inside the zip from `DifficultBulletinBoard-master` to `DifficultBulletinBoard`.

4. Move the `DifficultBulletinBoard` folder to your World of Warcraft AddOns directory:
   - Example path: `C:\World of Warcraft Turtle\Interface\AddOns`

5. If you have WoW open, make sure to restart the game for the addon to load properly.

6. To verify the installation, type `/dbb` in the game chat. If the installation was successful, the addon will open.


## Usage

### Accessing the Bulletin Board

You can open the bulletin board interface by left-clicking on the DifficultBulletinBoard Minimap icon or by typing ```/dbb``` into your chat window.
The interface will show an ordered list of messages from the world chat.

### Editing and Managing Entries

To manage topics, left-click on the config button to open the options window and select which topics to follow by selecting or unselecting the corresponding checkbox.

## Troubleshooting

### No Messages Show Up?
If no messages appear on your bulletin board and no errors are displayed, make sure you are in the **world chat** by typing `/join world` in-game.

### Tags List Issues?
If your tags list seems incorrect or disorganized, try pressing the **Reset Defaults** button in the options window.  
It’s also a good idea to reset the tags after updating the addon, as I may improve or adjust the tags list in future updates.

## Contact

Have feature suggestions or need further assistance? Feel free to [create an issue](https://github.com/thezephyrsong/DifficultBulletinBoard/issues) on this repository and I will help you as soon as possible.
```

