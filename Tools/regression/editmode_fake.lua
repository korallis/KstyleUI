-- editmode_fake.lua: Forever's Edit Mode API as Blizzard_EditMode and the generated docs describe it, for the setup
-- tests and the HUD render, written from EditModeManagerDocumentation.lua and Blizzard_EditMode/Shared at 1.60.1:
-- GetLayouts returns the saved layouts only, activeLayout counts the presets first, SaveLayouts takes the presets and
-- the saved layouts together, and the presets come from EditModePresetLayoutManager:GetCopyOfPresetLayouts().
--
--   local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
--   local state = { saved = {}, active = 1 }
--   EditModeFake.Install(env, state)    -- from an environment's setup hook
--   EditModeFake.Find(EditModeFake.Named(state, "KstyleUI DPS"), EditModeFake.TRACKER).anchorInfo
--
-- state: saved (the saved layouts), active (the active index), max (account layouts allowed, default 5), noEditMode
-- (no C_EditMode at all), noViewers (no CooldownViewer Edit Mode system). The Modern preset carries the essential
-- and utility viewers in their default positions with the preset's IconLimit (12 and 7) and IconPadding (2), as
-- Mainline/EditModePresetLayouts.lua:781 and :804 store them. The fake records saves (a count), sent (what SaveLayouts got) and activated (the index).
local EditModeFake = {}

EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT, EditModeFake.VIEWER = 12, 23, 8, 20
EditModeFake.RAID_WARNING = 24
EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR = 3, 4
EditModeFake.ESSENTIAL, EditModeFake.UTILITY, EditModeFake.ICON_LIMIT = 1, 2, 1
EditModeFake.ORIENTATION, EditModeFake.ICON_DIRECTION, EditModeFake.ICON_SIZE, EditModeFake.ICON_PADDING = 0, 2, 3, 4
EditModeFake.BAR_WIDTH = 11
EditModeFake.HORIZONTAL, EditModeFake.VERTICAL, EditModeFake.LEFT, EditModeFake.RIGHT = 0, 1, 0, 1
EditModeFake.HEIGHT, EditModeFake.FRAME_WIDTH, EditModeFake.FRAME_HEIGHT = 0, 3, 4
EditModeFake.PRESET, EditModeFake.ACCOUNT, EditModeFake.CHARACTER = 0, 1, 2

local F = EditModeFake

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Copy(v)
	end
	return out
end
F.Copy = Copy

local function System(system, x, y, settings, index)
	return {
		system = system,
		systemIndex = index,
		anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = x, offsetY = y },
		settings = settings or {},
		isInDefaultPosition = true,
	}
end

-- Viewer(index, orientation, direction) -> a Cooldown Manager viewer as the Modern preset stores it: 100% icons
-- (IconSize 5), padding 5, at the bottom of the screen; the bars keep the preset's BarWidthScale of 100, which Edit
-- Mode reads as 150% (ConvertValueDefault: the stored value plus the slider's 50 minimum).
local function Viewer(index, orientation, direction, y, limit, padding)
	local entry = System(F.VIEWER, 0, y, {
		{ setting = F.ORIENTATION, value = orientation },
		{ setting = F.ICON_LIMIT, value = limit or 1 },
		{ setting = F.ICON_DIRECTION, value = direction },
		{ setting = F.ICON_SIZE, value = 5 },
		{ setting = F.ICON_PADDING, value = padding or 5 },
	}, index)
	if index == F.BUFF_BAR then
		entry.settings[#entry.settings + 1] = { setting = F.BAR_WIDTH, value = 100 }
	end
	entry.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = y }
	return entry
end

-- Warning() -> RaidWarningFrame's system as the preset stores it (Mainline/EditModePresetLayouts.lua:1002): no
-- settings, its TOP 182 units under the screen's top.
local function Warning()
	local entry = System(F.RAID_WARNING, 0, -182)
	entry.anchorInfo = { point = "TOP", relativeTo = "UIParent", relativePoint = "TOP", offsetX = 0, offsetY = -182 }
	return entry
end

-- Modern() -> the Modern preset's systems this fake models, at Forever's preset places.
function F.Modern()
	return {
		layoutName = "Modern", layoutType = F.PRESET, layoutIndex = 0,
		systems = {
			System(F.TRACKER, -110, -275, { { setting = F.HEIGHT, value = 40 }, { setting = 1, value = 0 } }),
			System(F.METER, 0, 0, { { setting = 0, value = 0 }, { setting = F.FRAME_WIDTH, value = 200 }, { setting = F.FRAME_HEIGHT, value = 20 } }),
			System(F.CHAT, 35, 85),
			Viewer(F.ESSENTIAL, F.HORIZONTAL, F.RIGHT, 230, 12, 2),
			Viewer(F.UTILITY, F.HORIZONTAL, F.RIGHT, 240, 7, 2),
			Viewer(F.BUFF_ICON, F.HORIZONTAL, F.RIGHT, 370),
			Viewer(F.BUFF_BAR, F.VERTICAL, F.LEFT, 400),
			Warning(),
		},
	}
end

function F.Install(env, state)
	env.Enum = env.Enum or {}
	env.Enum.EditModeSystem = { ObjectiveTracker = F.TRACKER, DamageMeter = F.METER, ChatFrame = F.CHAT, RaidWarning = F.RAID_WARNING }
	if not state.noViewers then
		env.Enum.EditModeSystem.CooldownViewer = F.VIEWER
	end
	env.Enum.EditModeCooldownViewerSystemIndices = { Essential = 1, Utility = 2, BuffIcon = F.BUFF_ICON, BuffBar = F.BUFF_BAR }
	env.Enum.EditModeCooldownViewerSetting = { Orientation = F.ORIENTATION, IconLimit = 1, IconDirection = F.ICON_DIRECTION, IconSize = F.ICON_SIZE, IconPadding = F.ICON_PADDING, BarWidthScale = F.BAR_WIDTH }
	env.Enum.CooldownViewerOrientation = { Horizontal = F.HORIZONTAL, Vertical = F.VERTICAL }
	env.Enum.CooldownViewerIconDirection = { Left = F.LEFT, Right = F.RIGHT }
	env.Enum.EditModeLayoutType = { Preset = F.PRESET, Account = F.ACCOUNT, Character = F.CHARACTER }
	env.Enum.EditModeObjectiveTrackerSetting = { Height = F.HEIGHT, Opacity = 1, TextSize = 2 }
	env.Enum.EditModeDamageMeterSetting = { FrameWidth = F.FRAME_WIDTH, FrameHeight = F.FRAME_HEIGHT }
	env.Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = state.max or 5 } }
	env.EditModePresetLayoutManager = {
		GetCopyOfPresetLayouts = function()
			return { F.Modern(), Copy(F.Modern()) }
		end,
	}
	if state.noEditMode then
		env.C_EditMode = nil
		return
	end
	env.C_EditMode = {
		GetLayouts = function()
			return { layouts = Copy(state.saved), activeLayout = state.active }
		end,
		SaveLayouts = function(info)
			assert(not env.InCombatLockdown(), "SaveLayouts runs out of combat")
			state.saves = (state.saves or 0) + 1
			state.sent = info
			local saved = {}
			for _, layout in ipairs(info.layouts) do
				if layout.layoutType ~= F.PRESET then
					saved[#saved + 1] = Copy(layout)
				end
			end
			state.saved = saved
		end,
		SetActiveLayout = function(index)
			state.activated = index
			state.active = index
		end,
		IsValidLayoutName = function(name)
			return type(name) == "string" and name ~= "" and not name:find("Bad", 1, true)
		end,
	}
end

function F.Find(layout, system, index)
	for _, entry in ipairs(layout.systems) do
		if entry.system == system and (index == nil or entry.systemIndex == index) then
			return entry
		end
	end
end

-- ViewerRect(entry, count, k, bars) -> left, bottom, right, top in KstyleUI root units: the box Blizzard's buff icon
-- (or bar) viewer fills with count items under this Edit Mode entry, as CooldownViewerMixin:RefreshLayout lays it
-- out at 1.60.1: one row of every tracked item (one column when its Orientation is Vertical; bars always stack in
-- one column), hidden ones keeping their slot, at least two; each item
-- 40 by 40 (bars 220 by 30, their width times BarWidthScale%, stored as percent - 50) scaled by IconSize% (stored as
-- (percent - 50) / 10), pitched by IconPadding less 4 (bars 2), scaled by IconSize like the items (the grid offsets sit in each scaled item's space); k is root units to UIParent units, and the anchor is
-- the entry's point on UIParent's bottom left.
function F.ViewerRect(entry, count, k, bars)
	local scale = (F.Setting(entry, F.ICON_SIZE) * 10 + 50) / 100
	local pad = (F.Setting(entry, F.ICON_PADDING) - (bars and 2 or 4)) * scale
	local n = math.max(2, count)
	local w, h
	if bars then
		w, h = 220 * (F.Setting(entry, F.BAR_WIDTH) + 50) / 100 * scale, n * 30 * scale + (n - 1) * pad
	elseif F.Setting(entry, F.ORIENTATION) == F.VERTICAL then
		w, h = 40 * scale, n * 40 * scale + (n - 1) * pad
	else
		w, h = n * 40 * scale + (n - 1) * pad, 40 * scale
	end
	local a = entry.anchorInfo
	assert(a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", "viewer anchors are measured from the screen's bottom left")
	local x, y = a.offsetX, a.offsetY
	local left = a.point:find("RIGHT") and x - w or x
	local bottom = a.point:find("TOP") and y - h or y
	return left / k, bottom / k, (left + w) / k, (bottom + h) / k
end

-- RowRect(entry, count, k, size) -> left, bottom, right, top in root units: the box Blizzard's essential (size 50) or
-- utility (size 30) viewer fills with count items under this entry, as RefreshLayout lays a cooldown row out at 1.60.1
-- (Blizzard_CooldownViewer/CooldownViewer.lua:2033, CooldownViewer.xml:20 and :89): at least two items, IconLimit per
-- line (GetStride), lines stacking down from the top, each item size by size and pitched by IconPadding less 4
-- (GetAdditionalPaddingOffset), both scaled by IconSize%: the grid sets each item's offsets in the item's own scaled
-- units (Blizzard_SharedXML/GridLayoutUtil.lua:285, no respectChildScale); the viewer hangs from the entry's point on
-- UIParent's bottom left, a BOTTOM or TOP point at the box's middle.
function F.RowRect(entry, count, k, size)
	local scale = (F.Setting(entry, F.ICON_SIZE) * 10 + 50) / 100
	local pad = F.Setting(entry, F.ICON_PADDING) - 4
	local n = math.max(2, count)
	local stride = F.Setting(entry, F.ICON_LIMIT)
	local across, lines = math.min(n, stride), math.ceil(n / stride)
	local w, h = (across * size + (across - 1) * pad) * scale, (lines * size + (lines - 1) * pad) * scale
	local a = entry.anchorInfo
	assert(a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", "row anchors are measured from the screen's bottom left")
	local left = a.point:find("RIGHT") and a.offsetX - w or a.point:find("LEFT") and a.offsetX or a.offsetX - w / 2
	local bottom = a.point:find("TOP") and a.offsetY - h or a.offsetY
	return left / k, bottom / k, (left + w) / k, (bottom + h) / k
end

function F.Setting(entry, setting)
	for _, info in ipairs(entry.settings) do
		if info.setting == setting then
			return info.value
		end
	end
end

function F.Named(state, name)
	for i, layout in ipairs(state.saved or {}) do
		if layout.layoutName == name then
			return layout, i
		end
	end
end

return EditModeFake
