-- Module.lua: registers KstyleUI_Tooltips with the core: Enable, Disable, the settings page, its live preview and the Detailed tooltips CVar.
local _, ns = ...

local K = KstyleUI
local Settings, Style, Anchor, Content, Health, Units = ns.Settings, ns.Style, ns.Anchor, ns.Content, ns.Health, ns.Units

local MODULE = ns.MODULE
local UBER, DETAILED, SHARED = "UberTooltips", "TooltipsDetailed", "*"

local Detailed

local function OnVariables()
	K.Events.Unregister(DETAILED, "VARIABLES_LOADED")
	Detailed()
end

Detailed = function()
	local CVars, account = K.CVars, K.Store.Account()
	local all = account.tooltipsDetailed
	local shared = type(all) == "table" and type(all[SHARED]) == "table" and all[SHARED] or nil
	local want, memory = ns.active and Settings.Get("detailed") or "game", shared and shared[UBER]
	if want == "game" and type(memory) ~= "table" then
		return
	end
	if not CVars.Loaded() then
		K.Events.Register(DETAILED, "VARIABLES_LOADED", OnVariables)
		return
	end
	local current = CVars.Get(UBER)
	if not current then
		Settings.LogOnce("detailed", "UberTooltips cannot be read; Detailed tooltips keeps the game's setting")
		return
	end
	if want == "game" then
		if current ~= memory.written or type(memory.original) ~= "string"
			or CVars.Set(UBER, memory.original) and CVars.Get(UBER) == memory.original then
			shared[UBER] = nil
		end
		return
	end
	memory = type(memory) == "table" and memory or {}
	if current ~= memory.written then
		memory.original = current
	end
	local value = want == "on" and "1" or "0"
	if current == value or CVars.Set(UBER, value) then
		memory.written = value
		account.tooltipsDetailed = { [SHARED] = { [UBER] = memory } }
	end
end

local function ApplyScale()
	if ns.active then
		Anchor.Resize()
		Style.ApplyScale(Anchor.Scale())
		Style.ApplyFonts()
		Units.Restyle()
	end
end

local function ApplyFonts()
	if ns.active then
		Style.ApplyFonts()
	end
end

local function ApplyAll()
	ApplyScale()
	if ns.active then
		Health.Restyle()
		Anchor.Watch()
		Detailed()
		Content.Watch()
	end
end

local function SkinAll()
	local count = 0
	for _, name in ipairs(Style.NAMES) do
		local tooltip = _G[name]
		if type(tooltip) == "table" then
			Style.Skin(tooltip, name)
			if type(tooltip.ItemTooltip) == "table" then
				Style.ItemBorder(tooltip.ItemTooltip)
			end
			count = count + 1
		else
			Settings.LogOnce("missing:" .. name, name .. " is missing on this client; it keeps Blizzard's look")
		end
	end
	return count
end

local function Watch()
	local Callbacks = K.Callbacks
	Callbacks.Register("ScaleChanged", MODULE, ApplyScale)
	Callbacks.Register("ThemeChanged", MODULE, ApplyFonts)
	Callbacks.Register("ProfileChanged", MODULE, ApplyAll)
	Callbacks.Register("LayoutChanged", MODULE, function(_, key)
		if key == Anchor.KEY then
			ApplyScale()
		end
	end)
	Callbacks.Register("SettingChanged", MODULE, function(_, module)
		if module == MODULE then
			ApplyAll()
		end
	end)
end

local def = {
	name = MODULE,
	defaults = Settings.defaults,
	reskin = true,
}

function def.Enable()
	ns.active = true
	local count = SkinAll()
	if type(GameTooltip) == "table" then
		Health.Build(GameTooltip)
	end
	Anchor.Build()
	Anchor.Hook()
	Content.Register()
	ApplyAll()
	Watch()
	Settings.Log("restyled " .. count .. " tooltips")
end

function def.Disable()
	ns.active = false
	Health.Hide()
	Style.RestoreFonts()
	Style.RestoreScale()
	Units.Restyle()
	Detailed()
end

local function Check()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off: Blizzard tooltips"
	end
	local problems = {}
	if not Style.Glass(GameTooltip) then
		problems[#problems + 1] = "GameTooltip has no glass"
	end
	if not Anchor.IsHooked() then
		problems[#problems + 1] = "the default anchor is not hooked"
	end
	if not Content.IsRegistered() then
		problems[#problems + 1] = "no tooltip post-calls"
	end
	if #problems > 0 then
		return false, table.concat(problems, "; ")
	end
	return true, #Style.Tooltips() .. " tooltips restyled, position " .. Settings.Get("anchor") .. ", scale " .. string.format("%.2f", GameTooltip:GetScale())
end

K.Modules.Register(def)
K.Options.Register(MODULE, Settings.Schema)
K.DevTest.AddCheck("tooltips", Check)
