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
-- (no C_EditMode at all), noViewers (no CooldownViewer Edit Mode system). The fake records saves (a count), sent (what SaveLayouts got) and activated (the index).
local EditModeFake = {}

EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT, EditModeFake.VIEWER = 12, 23, 8, 20
EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR = 3, 4
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
local function Viewer(index, orientation, direction, y)
	local entry = System(F.VIEWER, 0, y, {
		{ setting = F.ORIENTATION, value = orientation },
		{ setting = 1, value = 1 },
		{ setting = F.ICON_DIRECTION, value = direction },
		{ setting = F.ICON_SIZE, value = 5 },
		{ setting = F.ICON_PADDING, value = 5 },
	}, index)
	if index == F.BUFF_BAR then
		entry.settings[#entry.settings + 1] = { setting = F.BAR_WIDTH, value = 100 }
	end
	entry.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = y }
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
			Viewer(1, F.HORIZONTAL, F.RIGHT, 230),
			Viewer(F.BUFF_ICON, F.HORIZONTAL, F.RIGHT, 370),
			Viewer(F.BUFF_BAR, F.VERTICAL, F.LEFT, 400),
		},
	}
end

function F.Install(env, state)
	env.Enum = env.Enum or {}
	env.Enum.EditModeSystem = { ObjectiveTracker = F.TRACKER, DamageMeter = F.METER, ChatFrame = F.CHAT }
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
-- out at 1.60.1: one row (or column) of every tracked item, hidden ones keeping their slot, at least two; each item
-- 40 by 40 (bars 220 by 30, their width times BarWidthScale%, stored as percent - 50) scaled by IconSize% (stored as
-- (percent - 50) / 10), pitched by IconPadding less 4 (bars 2); k is root units to UIParent units, and the anchor is
-- the entry's point on UIParent's bottom left.
function F.ViewerRect(entry, count, k, bars)
	local scale = (F.Setting(entry, F.ICON_SIZE) * 10 + 50) / 100
	local pad = F.Setting(entry, F.ICON_PADDING) - (bars and 2 or 4)
	local n = math.max(2, count)
	local w, h
	if bars then
		w, h = 220 * (F.Setting(entry, F.BAR_WIDTH) + 50) / 100 * scale, n * 30 * scale + (n - 1) * pad
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
