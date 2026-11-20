-- Visibility.lua: the visibility macro editor and per-character secure visibility gates.
local _, ns = ...

local K, L = KstyleUI, KstyleUI.L

ns.VISIBILITY_CONDITIONS = {
	{ "combat", "combat", L["In combat"] },
	{ "idle", "nocombat", L["Out of combat"] },
	{ "target", "@target,exists", L["Has target"] },
	{ "mounted", "mounted", L["Mounted"] },
	{ "group", "group", L["In group or raid"] },
	{ "shift", "mod:shift", L["Shift key"] },
	{ "ctrl", "mod:ctrl", L["Control key"] },
	{ "alt", "mod:alt", L["Alt key"] },
}

function ns.VisibilityDefaults()
	local out = { mode = "show" }
	for _, condition in ipairs(ns.VISIBILITY_CONDITIONS) do out[condition[1]] = false end
	return out
end

function ns.VisibilityMacro(builder)
	local groups = {}
	for _, condition in ipairs(ns.VISIBILITY_CONDITIONS) do
		if builder[condition[1]] then groups[#groups + 1] = "[" .. condition[2] .. "]" end
	end
	if #groups == 0 then return "" end
	return table.concat(groups) .. " " .. builder.mode .. "; " .. (builder.mode == "hide" and "show" or "hide")
end

function ns.ParseVisibility(macro)
	local builder = ns.VisibilityDefaults()
	if not macro or not macro:match("%S") then return builder end
	local groups, mode, fallback = macro:match("^%s*(%[.-%])%s+(%a+)%s*;%s*(%a+)%s*$")
	if not groups or (mode ~= "show" and mode ~= "hide") or fallback ~= (mode == "show" and "hide" or "show") then return nil end
	local known = {}
	for _, condition in ipairs(ns.VISIBILITY_CONDITIONS) do known[condition[2]] = condition[1] end
	local rest = groups:gsub("%[([^%]]+)%]", function(condition)
		local key = known[condition]
		if not key then return "?" end
		builder[key] = true
		return ""
	end)
	if rest:match("%S") then return nil end
	builder.mode = mode
	return builder
end

function ns.SyncVisibility(key)
	local cfg = ns.Config(key)
	cfg.visibilityBuilder = ns.ParseVisibility(cfg.visibility) or ns.VisibilityDefaults()
end

function ns.SyncVisibilities()
	for _, def in ipairs(ns.BARS) do ns.SyncVisibility(def.key) end
	ns.SyncVisibility("consumables")
end

local writing = false
function ns.VisibilityChanged(_, module, key)
	if module ~= "ActionBars" then return end
	local bar, field = key:match("^(%w+)%.(.+)$")
	if not bar then return end
	if field == "visibility" and not writing then
		ns.SyncVisibility(bar)
	elseif field:match("^visibilityBuilder%.") then
		writing = true
		K.Options.Write(module, bar .. ".visibility", ns.VisibilityMacro(ns.Config(bar).visibilityBuilder))
		writing = false
	end
end

BINDING_HEADER_KSTYLEUI_ACTIONBARS = "KstyleUI"
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar1:LeftButton"] = L["Toggle Action Bar 1"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar2:LeftButton"] = L["Toggle Action Bar 2"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar3:LeftButton"] = L["Toggle Action Bar 3"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar4:LeftButton"] = L["Toggle Action Bar 4"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar5:LeftButton"] = L["Toggle Action Bar 5"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_bar6:LeftButton"] = L["Toggle Action Bar 6"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_pet:LeftButton"] = L["Toggle pet bar"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_stance:LeftButton"] = L["Toggle stance bar"]
_G["BINDING_NAME_CLICK KstyleUI_Toggle_consumables:LeftButton"] = L["Toggle consumables bar"]

local TOGGLE = [[
	local gate = self:GetFrameRef("gate")
	local hidden = not gate:GetAttribute("toggle-hidden")
	gate:SetAttribute("toggle-hidden", hidden)
	if hidden then gate:Hide() else gate:Show() end
]]

function ns.VisibilityGate(holder, key)
	if type(SecureHandlerSetFrameRef) ~= "function" then
		ns.LogOnce("noToggle", "SecureHandlerSetFrameRef is missing; action bar visibility keys are unavailable")
		return holder
	end
	local gate = CreateFrame("Frame", nil, holder, "SecureHandlerBaseTemplate")
	gate:SetAllPoints(holder)
	local account, character = K.Store.Account(), K.Store.CharacterKey()
	account.actionBarToggles = account.actionBarToggles or {}
	local saved = {}
	if character then
		account.actionBarToggles[character] = account.actionBarToggles[character] or {}
		saved = account.actionBarToggles[character]
	end
	gate:SetAttribute("toggle-hidden", saved[key] == true)
	gate:SetShown(saved[key] ~= true)
	gate:HookScript("OnAttributeChanged", function(_, name, value)
		if name == "toggle-hidden" then saved[key] = value == true or nil end
	end)
	local toggle = CreateFrame("Button", "KstyleUI_Toggle_" .. key, K.Scale.Root(), "SecureHandlerClickTemplate")
	toggle:RegisterForClicks("AnyUp")
	SecureHandlerSetFrameRef(toggle, "gate", gate)
	toggle:SetAttribute("_onclick", TOGGLE)
	return gate
end

