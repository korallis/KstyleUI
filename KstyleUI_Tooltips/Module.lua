-- Module.lua: registers KstyleUI_Tooltips with the core: Enable, Disable, the settings page and its live preview.
local _, ns = ...

local K = KstyleUI
local Settings, Style, Anchor, Content, Preview = ns.Settings, ns.Style, ns.Anchor, ns.Content, ns.Preview

local MODULE = ns.MODULE

local function ApplyScale()
	if ns.active then
		Style.ApplyScale(Anchor.Scale())
	end
end

local function ApplyFonts()
	if ns.active then
		Style.ApplyFonts()
	end
end

local function ApplyAll()
	ApplyFonts()
	ApplyScale()
end

local function SkinAll()
	local count = 0
	for _, name in ipairs(Style.NAMES) do
		local tooltip = _G[name]
		if type(tooltip) == "table" then
			Style.Skin(tooltip, name)
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
	Anchor.Build()
	Anchor.Hook()
	Content.Register()
	ApplyAll()
	Watch()
	Settings.Log("restyled " .. count .. " tooltips")
end

function def.Disable()
	ns.active = false
	Style.RestoreFonts()
	Style.RestoreScale()
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
Settings.schema.preview = Preview.Build
K.Options.Register(MODULE, Settings.schema)
K.DevTest.AddCheck("tooltips", Check)
