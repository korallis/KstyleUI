-- HudStyle.lua: the HUD style setting, Frames or Orbs, saved per profile; it switches out of combat, waits for combat to end when chosen in lockdown, fires HudStyleChanged, and offers a reload when a module fails to switch.
local addonName, ns = ...

local HudStyle = {}
ns.HudStyle = HudStyle

local Store, L = ns.Store, ns.L

local SECTION = "HudStyle"
local STYLES = { frames = true, orbs = true }

HudStyle.defaults = { style = "frames" }

local applied, queued

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

function HudStyle.Saved()
	if Store.IsLoaded() then
		local value = Store.Module(SECTION).style
		if not (issecretvalue and issecretvalue(value)) and STYLES[value] then
			return value
		end
	end
	return HudStyle.defaults.style
end

function HudStyle.Current()
	return applied or HudStyle.Saved()
end

local function Apply()
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
				Apply()
			end)
		end
		return
	end
	applied = style
	Log("HUD style " .. style)
	local errors = ns.ErrorCount()
	ns.Callbacks.Fire("HudStyleChanged", style)
	if ns.ErrorCount() > errors then
		ns.Widgets.ReloadPrompt(L["Your HUD style finishes changing when you reload."])
	end
end

HudStyle.schema = {
	{ type = "header", label = L["HUD"] },
	{
		type = "dropdown", key = "style", label = L["HUD style"],
		help = L["Orbs shows health and resource in two orbs beside the main action buttons. Changes out of combat."],
		options = { { value = "frames", label = L["Frames"] }, { value = "orbs", label = L["Orbs"] } },
	},
}

Store.RegisterDefaults(SECTION, HudStyle.defaults)
ns.Options.Register(SECTION, HudStyle.schema)

ns.Callbacks.Register("SettingChanged", SECTION, function(_, module)
	if module == SECTION then
		Apply()
	end
end)
ns.Callbacks.Register("ProfileChanged", SECTION, Apply)

ns.Events.Register(SECTION, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(SECTION, "ADDON_LOADED")
		Apply()
	end
end)
