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
-- (no C_EditMode at all). The fake records saves (a count), sent (what SaveLayouts got) and activated (the index).
local EditModeFake = {}

EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT = 12, 23, 8
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

local function System(system, x, y, settings)
	return {
		system = system,
		anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = x, offsetY = y },
		settings = settings or {},
		isInDefaultPosition = true,
	}
end

-- Modern() -> the Modern preset's systems this fake models, at Forever's preset places.
function F.Modern()
	return {
		layoutName = "Modern", layoutType = F.PRESET, layoutIndex = 0,
		systems = {
			System(F.TRACKER, -110, -275, { { setting = F.HEIGHT, value = 40 }, { setting = 1, value = 0 } }),
			System(F.METER, 0, 0, { { setting = 0, value = 0 }, { setting = F.FRAME_WIDTH, value = 200 }, { setting = F.FRAME_HEIGHT, value = 20 } }),
			System(F.CHAT, 35, 85),
		},
	}
end

function F.Install(env, state)
	env.Enum = env.Enum or {}
	env.Enum.EditModeSystem = { ObjectiveTracker = F.TRACKER, DamageMeter = F.METER, ChatFrame = F.CHAT }
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

function F.Find(layout, system)
	for _, entry in ipairs(layout.systems) do
		if entry.system == system then
			return entry
		end
	end
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
