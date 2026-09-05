---@meta

---# ALIASES

---@alias MF_GoodBadNeutral integer  # 0 = Neutral, 1 = Good, 2 = Bad
---@alias MF_MoodleLevel integer     # 0 (neutral) to 4 (max intensity)

---Per-moodle data stored in `character:getModData().Moodles[name]`
---@class MF_MoodleModData
---@field Level MF_MoodleLevel
---@field GoodBadNeutral MF_GoodBadNeutral
---@field Value number

---# MF MODULE

---@class MF
---@field Moodles table<string, any> Moodles map (getPlayer only); reset on every new moodle creation for backward compatibility.
---@field MoodlesStorage table<integer, table<string, ISMoodle>> Moodles map keyed by playerNum, then by moodle name (splitscreen compatible).
---@field verbose boolean Enables debug printing.
---@field TooLargeValue number Sentinel large value used for unset thresholds.
---@field ModDataClean boolean Internal flag: whether player mod data has been cleaned once.
---@field scale number Global UI scale factor applied to all moodles.
__MF = {}

---Registers creation of a moodle named `moodleName` for every player, via `Events.OnCreatePlayer`.
---@param moodleName string
function MF.createMoodle(moodleName) end

---Retrieves a moodle instance for a given moodle name and (optionally) player number.
---@param moodleName string
---@param playerNum integer? Defaults to 0 if not provided.
---@return ISMoodle?
function MF.getMoodle(moodleName, playerNum) end

---Repositions and resizes all tracked moodles across all players after `MF.scale` changes.
function MF.adjustScale() end

---# ISMOODLE CLASS

---@class ISMoodle : ISUIElement
---@field name string Moodle identifier / texture & translation key base.
---@field char IsoPlayer Owning character.
---@field playerNum integer Owning player number (splitscreen support).
---@field disable boolean Whether the moodle is suspended (e.g. character death).
---
---@field chevronCount integer Number of chevrons drawn.
---@field chevronIsUp boolean Whether chevrons point up (true) or down (false).
---@field chevronUp Texture
---@field chevronUpBorder Texture
---@field chevronDown Texture
---@field chevronDownBorder Texture
---
---@field pic Texture Default moodle picture (used when no per-level override exists).
---@field title table<MF_GoodBadNeutral, table<MF_MoodleLevel, string|boolean>> Title text per (goodBadNeutral, level); `false` until lazily resolved.
---@field desc table<MF_GoodBadNeutral, table<MF_MoodleLevel, string|boolean>> Description text per (goodBadNeutral, level); `false` until lazily resolved.
---@field bkg table<MF_GoodBadNeutral, table<MF_MoodleLevel, Texture>> Background textures per (goodBadNeutral, level).
---@field pics table<MF_GoodBadNeutral, table<MF_MoodleLevel, Texture>> Picture override textures per (goodBadNeutral, level).
---
---@field threasholdBad4 number
---@field threasholdBad3 number
---@field threasholdBad2 number
---@field threasholdBad1 number
---@field threasholdGood1 number
---@field threasholdGood2 number
---@field threasholdGood3 number
---@field threasholdGood4 number
---
---@field MoodleOscilationLevel number Current wiggle intensity (0 = idle).
---@field OscilatorScalar number
---@field OscilatorDecelerator number
---@field OscilatorRate number
---@field OscilatorStep number
---@field OscilatorXOffset number Current computed X wiggle offset.
---
---@field borderColor table
---@field backgroundColor table
---@field addedToUIManager boolean? Whether the element is currently registered with the UIManager.
---@field onPlayerDeathFunc fun(player: IsoPlayer) Handler bound to `Events.OnPlayerDeath`.
__ISMoodle = {}

---# VALUE / STATE ACCESS

---Sets the moodle's underlying value, recomputes level/alignment, triggers wiggle on change,
---and adds/removes itself from the UIManager depending on neutrality.
---@param value number
function __ISMoodle:setValue(value) end

---Returns the moodle's current raw value (0.5 default / while disabled).
---@return number
function __ISMoodle:getValue() end

---Returns whether the moodle is currently Good, Bad, or Neutral.
---@return MF_GoodBadNeutral
function __ISMoodle:getGoodBadNeutral() end

---Returns the moodle's current intensity level (0-4).
---@return MF_MoodleLevel
function __ISMoodle:getLevel() end

---# CONFIGURATION / OVERRIDES

---@param chevronCount integer
function __ISMoodle:setChevronCount(chevronCount) end

---@param isUp boolean
function __ISMoodle:setChevronIsUp(isUp) end

---Sets the bad/good thresholds. Passing `nil` for a given tier collapses it to the next
---outer tier value (or `MF.TooLargeValue` / `-MF.TooLargeValue` for the outermost tiers).
---@param bad4 number?
---@param bad3 number?
---@param bad2 number?
---@param bad1 number?
---@param good1 number?
---@param good2 number?
---@param good3 number?
---@param good4 number?
function __ISMoodle:setThresholds(bad4, bad3, bad2, bad1, good1, good2, good3, good4) end

---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@param text string
function __ISMoodle:setTitle(goodBadNeutral, moodleLevel, text) end

---Backward-compatible alias for `setDescription`.
---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@param text string
function __ISMoodle:setDescritpion(goodBadNeutral, moodleLevel, text) end

---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@param text string
function __ISMoodle:setDescription(goodBadNeutral, moodleLevel, text) end

---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@param texture Texture
function __ISMoodle:setBackground(goodBadNeutral, moodleLevel, texture) end

---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@param texture Texture
function __ISMoodle:setPicture(goodBadNeutral, moodleLevel, texture) end

---Triggers the wiggle animation if the moodle is currently non-neutral.
function __ISMoodle:doWiggle() end

---# TEXT RESOLUTION

---Lazily resolves (and caches) the title text for a given (goodBadNeutral, level) pair,
---falling back to `getText("Moodles_<name>_<Good|Bad>_lvl<level>")`.
---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@return string|boolean|nil
function __ISMoodle:getTitle(goodBadNeutral, moodleLevel) end

---Lazily resolves (and caches) the description text for a given (goodBadNeutral, level) pair,
---falling back to `getText("Moodles_<name>_<Good|Bad>_desc_lvl<level>")`.
---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@return string|boolean|nil
function __ISMoodle:getDescription(goodBadNeutral, moodleLevel) end

---# RENDERING / INTERNALS

---Advances the wiggle oscillator state (internal, called from `render`).
function __ISMoodle:updateOscilatorXOffset() end

---Renders the moodle (background, tooltip, picture, chevrons). Overrides `ISUIElement:render`.
function __ISMoodle:render() end

---Returns the picture texture to use for a given (goodBadNeutral, level) pair,
---falling back to `self.pic` if no override exists.
---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
---@return Texture
function __ISMoodle:getPicture(goodBadNeutral, moodleLevel) end

---Compensates a vanilla bug where mouse-over detection misses the top/bottom of the moodle icon.
---@return boolean
function __ISMoodle:isMouseOverMoodle() end

---Draws the tooltip (title + description) when the mouse is over the moodle.
---@param goodBadNeutral MF_GoodBadNeutral
---@param moodleLevel MF_MoodleLevel
function __ISMoodle:mouseOverMoodle(goodBadNeutral, moodleLevel) end

---Computes the screen X/Y position of the moodle, stacking below vanilla moodles,
---Aiteron-compatible moodles, and other modded moodles that precede it.
---@return number x
---@return number y
function __ISMoodle:getXYPosition() end

---# LIFECYCLE

---Constructs (or re-derives) a new `ISMoodle` UI element for a moodle name/character,
---initializing the character's mod data and registering death-cleanup handling.
---@param moodleName string
---@param character IsoPlayer
---@return ISMoodle
function __ISMoodle:new(moodleName, character) end

---Disables the moodle (used on character death); values are frozen and rendering skipped.
function __ISMoodle:suspend() end

---Re-enables a previously suspended moodle.
function __ISMoodle:activate() end

---Initializes (or copies from a previous cached instance) chevrons, textures, titles,
---descriptions, backgrounds and picture overrides, preserving user overrides across recreation.
function __ISMoodle:handleCacheOverride() end

---Creates child UI elements. Overrides `ISUIElement:createChildren`.
---When `MF.verbose` is true, adds a debug green panel child.
function __ISMoodle:createChildren() end
