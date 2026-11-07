-- Module.lua: registers CombatText with the core, builds its frames on the first Enable, and turns UNIT_COMBAT into numbers.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Settings, Format, Pool, Display, Anchors, World, Preview = ns.Settings, ns.Format, ns.Pool, ns.Display, ns.Anchors, ns.World, ns.Preview

local MODULE = "CombatText"
local FIELD_KEY = "combattext.player"
local FIELD_MIN, FIELD_MAX = 60, 600
local FIELD_CAPACITY = 16
local FRAME_CAPACITY = 64
local WORLD_KEYS = { worldFont = true, worldFace = true }
local WATCHED_MODULES = { UnitFrames = true, GroupFrames = true, Nameplates = true }

local Module = {}
ns.Module = Module

local IsSecret = Format.IsSecret
local NAMEPLATES = Anchors.NAMEPLATES

local stats = {
	events = 0, shown = 0, secretAmount = 0, secretEvent = 0, secretFlag = 0, secretSchool = 0,
	secretUnit = 0, nameplate = 0,
}
Module.stats = stats

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function Refresh()
	Settings.Snapshot(Settings.Values(), Module.cfg)
	Anchors.Rebuild(Module.cfg)
end

local function Build()
	if Module.pool then
		return
	end
	local root = K.Scale.Root()
	local layer = CreateFrame("Frame", nil, root)
	layer:SetAllPoints(root)
	Module.layer = layer
	local footprint = K.Setup.Layouts.Element(FIELD_KEY)
	local field = CreateFrame("Frame", nil, root)
	field:SetSize(footprint.width, footprint.height)
	K.Widgets.Place(field, FIELD_KEY, K.Setup.Layouts.Default(FIELD_KEY), {
		label = footprint.label,
		module = MODULE,
		resizable = true,
		minWidth = FIELD_MIN, maxWidth = FIELD_MAX, minHeight = FIELD_MIN, maxHeight = FIELD_MAX,
	})
	Module.field = field
	Module.cfg = {}
	Module.pool = Pool.New(field, FIELD_CAPACITY)
	Module.framePool = Pool.New(layer, FRAME_CAPACITY)
	Module.fieldEmitter = Display.NewEmitter(field, "field", Module.pool)
	Anchors.Setup(Module.fieldEmitter, Module.framePool)
end

local function Shows(cfg, kind)
	if kind == "damage" then
		return cfg.damage
	elseif kind == "heal" then
		return cfg.heals
	elseif kind == "miss" then
		return cfg.misses
	end
	return cfg.neutral
end

local function Count(unit, event, flag, amount, school)
	stats.events = stats.events + 1
	if IsSecret(amount) then
		stats.secretAmount = stats.secretAmount + 1
	end
	if IsSecret(event) then
		stats.secretEvent = stats.secretEvent + 1
	end
	if IsSecret(flag) then
		stats.secretFlag = stats.secretFlag + 1
	end
	if IsSecret(school) then
		stats.secretSchool = stats.secretSchool + 1
	end
	if IsSecret(unit) then
		stats.secretUnit = stats.secretUnit + 1
	elseif NAMEPLATES[unit] then
		stats.nameplate = stats.nameplate + 1
	end
end

local function Show(emitter, cfg, kind, emphasis, amount, word, school)
	Display.Spawn(emitter, cfg, kind, emphasis, amount, word, school)
	stats.shown = stats.shown + 1
end

local function OnUnitCombat(_, unit, event, flag, amount, school)
	Count(unit, event, flag, amount, school)
	if IsSecret(unit) or type(unit) ~= "string" then
		return
	end
	local kind, emphasis, word = Format.Classify(event, flag, amount)
	local cfg = Module.cfg
	if not kind or not Shows(cfg, kind) then
		return
	end
	local list = Anchors.Lookup(unit)
	if list then
		for i = 1, #list do
			local emitter = list[i]
			if emitter and Anchors.Ready(emitter, unit) then
				Show(emitter, cfg, kind, emphasis, amount, word, school)
			end
		end
	elseif NAMEPLATES[unit] then
		local emitter = Anchors.Plate(unit, cfg)
		if emitter then
			Show(emitter, cfg, kind, emphasis, amount, word, school)
		end
	else
		Anchors.Missed(unit)
	end
end

local function OnRoster()
	Anchors.Schedule()
end

local function OnPlateRemoved(_, unit)
	if not IsSecret(unit) and type(unit) == "string" then
		Anchors.PlateRemoved(unit)
	end
end

local function OnSetting(_, module, key)
	if module ~= MODULE then
		return
	end
	Refresh()
	if WORLD_KEYS[key] then
		World.Apply(Module.cfg)
		K.Print(L["The game's own damage numbers change font at your next login."])
	end
end

local function OnProfile()
	Refresh()
	World.Apply(Module.cfg)
end

local function OnModule(_, name)
	if WATCHED_MODULES[name] then
		Anchors.Schedule()
	end
end

local function Check()
	if not K.Modules.IsRunning(MODULE) then
		return true, "switched off"
	end
	local unitFrames, groupFrames = Anchors.Counts()
	return true, string.format(
		"%d UNIT_COMBAT events (%d secret amount, %d secret event, %d secret flag, %d secret school, %d secret unit); %d from nameplate units; %d numbers shown; numbers attach to %d unit frames, %d group frames; DAMAGE_TEXT_FONT %s",
		stats.events, stats.secretAmount, stats.secretEvent, stats.secretFlag, stats.secretSchool, stats.secretUnit,
		stats.nameplate, stats.shown, unitFrames, groupFrames, tostring(World.Current()))
end

local function Enable()
	Build()
	Refresh()
	World.Apply(Module.cfg)
	Module.layer:Show()
	Module.field:Show()
	K.Events.Register(MODULE, "UNIT_COMBAT", OnUnitCombat)
	K.Events.Register(MODULE, "GROUP_ROSTER_UPDATE", OnRoster)
	K.Events.Register(MODULE, "NAME_PLATE_UNIT_REMOVED", OnPlateRemoved)
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, OnProfile)
	K.Callbacks.Register("ModuleChanged", MODULE, OnModule)
	if not Module.checked then
		Module.checked = true
		K.DevTest.AddCheck("combat text", Check)
	end
	if not Module.logged then
		Module.logged = true
		Log("numbers use " .. (AbbreviateNumbers and "AbbreviateNumbers" or "no AbbreviateNumbers") .. " and " .. (BreakUpLargeNumbers and "BreakUpLargeNumbers" or "no BreakUpLargeNumbers"))
	end
end

local function Disable()
	if Module.pool then
		Module.pool:ReleaseAll()
		Module.framePool:ReleaseAll()
		Module.layer:Hide()
		Module.field:Hide()
	end
	World.Restore()
end

Settings.schema.preview = Preview.Build
K.Modules.Register({ name = MODULE, defaults = Settings.defaults, Enable = Enable, Disable = Disable })
K.Options.Register(MODULE, Settings.schema)

World.Capture()
if K.Store.IsLoaded() and K.Modules.IsEnabled(MODULE) then
	World.Apply(Settings.Snapshot(Settings.Values()))
end
