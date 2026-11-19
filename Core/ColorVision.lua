-- ColorVision.lua: semantic alert palettes follow the game's colour-vision filter unless the player chooses one.
local _, K = ...
local Vision = {}
K.ColorVision = Vision
local Store, Tokens, L = K.Store, K.Tokens, K.L
local PALETTES = { redGreen = { "visionRGCalm", "visionRGDanger", "visionRGWarning" }, blueYellow = { "visionBYCalm", "visionBYDanger", "visionBYWarning" } }
Store.RegisterDefaults("ColorVision", { mode = "game" })
K.Options.Register("ColorVision", function() return {
	{ type = "header", label = L["Colour vision"] },
	{ type = "dropdown", key = "mode", label = L["Colour vision"], help = L["Changes alert colours; role and state shapes stay visible in every mode."], options = {
		{ value = "game", label = L["Follow the game"] }, { value = "standard", label = L["Standard"] },
		{ value = "redGreen", label = L["Red-green"] }, { value = "blueYellow", label = L["Blue-yellow"] },
	} },
} end)

function Vision.Mode()
	local value = Store.IsLoaded() and Store.Module("ColorVision").mode or "game"
	if value ~= "game" then return value end
	local api = C_CVar and C_CVar.GetCVar or GetCVar
	if type(api) == "function" then
		local filter = api("colorblindSimulator")
		if not (issecretvalue and issecretvalue(filter)) then
			filter = tonumber(filter)
			if filter == 1 or filter == 2 then return "redGreen" end
			if filter == 3 then return "blueYellow" end
		end
	end
	return "standard"
end

function Vision.Color(index, ...)
	local palette = PALETTES[Vision.Mode()]
	if palette then return Tokens.Color(palette[index] or palette[1]) end
	return ...
end

function Vision.DispelAssets()
	local out = {}
	for kind, letter in pairs({ Magic = "M", Curse = "C", Disease = "D", Poison = "P", Enrage = "E" }) do
		out[kind] = { asset = Tokens.Texture("dispel" .. letter) }
	end
	return out
end

local threat = K.Theme.ThreatColor
function K.Theme.ThreatColor(status)
	if type(status) ~= "number" or issecretvalue and issecretvalue(status) then return threat(status) end
	return Vision.Color(status == 3 and 2 or status == 2 and 3 or 1, threat(status))
end

local function Changed() K.Callbacks.Fire("ThemeChanged") end
K.Callbacks.Register("SettingChanged", "ColorVision", function(_, module) if module == "ColorVision" then Changed() end end)
K.Events.Register("ColorVision", "CVAR_UPDATE", function(_, name) if name == "colorblindSimulator" or name == "colorblindMode" then Changed() end end)
