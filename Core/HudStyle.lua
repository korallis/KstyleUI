-- HudStyle.lua: the HUD style setting, Frames, Orbs or Medallions, saved per profile; it switches out of combat, waits for combat to end when chosen in lockdown, fires HudStyleChanged, and offers a reload when a module fails to switch.
local addonName, ns = ...

local HudStyle = {}
ns.HudStyle = HudStyle

local Store, Tokens, L = ns.Store, ns.Tokens, ns.L

local SECTION = "HudStyle"
local STYLES = { frames = true, orbs = true, medallions = true }

HudStyle.MEDALLIONS_READY = false
local medallionsOffered = HudStyle.MEDALLIONS_READY or KSTYLEUI_DEV_MEDALLIONS == true

HudStyle.defaults = { style = "frames" }

local applied, queued

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

function HudStyle.Valid(value)
	return not (issecretvalue and issecretvalue(value)) and STYLES[value] == true
end

function HudStyle.Offered(value)
	return HudStyle.Valid(value) and (value ~= "medallions" or medallionsOffered)
end

function HudStyle.Saved()
	if Store.IsLoaded() then
		local value = Store.Module(SECTION).style
		if HudStyle.Offered(value) then
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
		type = "pictures", key = "style", label = L["HUD style"],
		help = medallionsOffered and L["Orbs puts health and resource in orbs; Medallions adds round portraits. Changes out of combat."] or L["Orbs puts health and resource in orbs. Changes out of combat."],
		options = {
			{ value = "frames", label = L["Frames"], picture = (Tokens.Texture("hudStyleFrames")) },
			{ value = "orbs", label = L["Orbs"], picture = (Tokens.Texture("hudStyleOrbs")) },
		},
	},
}
if medallionsOffered then
	table.insert(HudStyle.schema[2].options, { value = "medallions", label = L["Medallions"], picture = (Tokens.Texture("hudStyleMedallions")) })
end

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
