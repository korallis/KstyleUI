-- HudStyle.lua: the HUD style setting, Medallions or Frames, saved per profile; it switches out of combat, waits for combat to end when chosen in lockdown, fires HudStyleChanged, and offers a reload when a module fails to switch.
local addonName, ns = ...

local HudStyle = {}
ns.HudStyle = HudStyle

local Store, Tokens, L = ns.Store, ns.Tokens, ns.L

local SECTION = "HudStyle"
local STYLES = { frames = true, medallions = true }
local FRAMES_LOOK = {
	GroupFrames = { ["party.portrait"] = false, ["raid.power"] = true, ["raid.textLayout"] = "ABOVE", ["raid.buffCount"] = 3 },
	DataBars = { ["xp.text"] = "levelRested", ["xp.fontSize"] = 12 },
	Nameplates = { ["name.size"] = 16, ["name.outline"] = "NONE", ["level.size"] = 13, ["level.outline"] = "NONE", ["debuffs.size"] = 29, ["debuffs.textSize"] = 13 },
}

HudStyle.defaults = { style = "medallions" }
HudStyle.FRAMES_LOOK = FRAMES_LOOK

local applied, queued

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

function HudStyle.Valid(value)
	return not (issecretvalue and issecretvalue(value)) and STYLES[value] == true
end

function HudStyle.Saved()
	if Store.IsLoaded() then
		local value = Store.Module(SECTION).style
		if HudStyle.Valid(value) then
			return value
		end
	end
	return HudStyle.defaults.style
end

function HudStyle.Current()
	return applied or HudStyle.Saved()
end

local function Look(style)
	local Options = ns.Options
	for module, values in pairs(FRAMES_LOOK) do
		if Store.Defaults(module) then
			for key, frames in pairs(values) do
				local value, default = Options.Read(module, key), Options.Default(module, key)
				if style == "frames" and value == default then
					Options.Write(module, key, frames)
				elseif style == "medallions" and value == frames then
					Options.Write(module, key, default)
				end
			end
		end
	end
end

local function Apply(chosen)
	local style = HudStyle.Saved()
	if applied == nil or style == applied then
		applied = style
		return
	end
	if InCombatLockdown() then
		if not queued then
			queued = true
			ns.Print(L["Your HUD style changes when combat ends."])
			ns.Combat.Queue(function()
				queued = false
				Apply(chosen)
			end)
		end
		return
	end
	if chosen then Look(style) end
	applied = style
	Log("HUD style " .. style)
	local errors = ns.ErrorCount()
	ns.Callbacks.Fire("HudStyleChanged", style)
	if ns.ErrorCount() > errors then
		ns.Widgets.ReloadPrompt(L["Your HUD style finishes changing when you reload."])
	end
end

function HudStyle.Schema()
	HudStyle.schema = {
		{ type = "header", label = L["HUD"] },
		{
			type = "pictures", key = "style", label = L["HUD style"],
			help = L["Medallions adds round portraits. Played on Frames before? Pick it here. Changes out of combat."],
			options = {
				{ value = "medallions", label = L["Medallions"], picture = (Tokens.Texture("hudStyleMedallions")) },
				{ value = "frames", label = L["Frames"], picture = (Tokens.Texture("hudStyleFrames")) },
			},
		},
	}
	return HudStyle.schema
end

Store.RegisterDefaults(SECTION, HudStyle.defaults)
ns.Options.Register(SECTION, HudStyle.Schema)

ns.Callbacks.Register("SettingChanged", SECTION, function(_, module, key)
	if module == SECTION then
		Apply(key == "style")
	end
end)
ns.Callbacks.Register("ProfileChanged", SECTION, function() Apply() end)

ns.Events.Register(SECTION, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(SECTION, "ADDON_LOADED")
		Apply()
	end
end)
