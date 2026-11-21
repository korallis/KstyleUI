-- QuickFire.lua: three secure buttons that the Place, Undo and Clear world marker key bindings click, built once Quick fire is on: Place puts the next world marker in Blizzard's star-to-skull order at the pointer through the game's own /wm [@cursor] command, Undo takes away the last one it placed and Clear takes them all. Restricted snippets keep the next marker and the list of markers Place put down, so the keys work in combat and Undo touches only its own; out of combat, before each Place and again as combat ends, the next marker becomes the first one the game says is free and markers the game says are gone leave the list, while an unknown answer changes nothing. Attributes change only out of combat, through the combat queue; off clears the order, so every key does nothing.
local _, ns = ...

local K, L = ns.K, ns.L

local OWNER = "QoL.quickfire"
local SNIPPETS = {
	Place = [[
		local order = self:GetAttribute("order")
		if not order then return false end
		local n = self:GetAttribute("next") or 1
		self:SetAttribute("next", n % #order + 1)
		self:SetAttribute("placed", gsub(self:GetAttribute("placed") or "", n, "") .. n)
		self:SetAttribute("macrotext", self:GetAttribute("wm") .. " [@cursor] " .. strsub(order, n, n))
	]],
	Undo = [[
		local place = self:GetFrameRef("place")
		local order, placed = place:GetAttribute("order"), place:GetAttribute("placed") or ""
		if not order or placed == "" then return false end
		local n = tonumber(strsub(placed, -1))
		place:SetAttribute("placed", strsub(placed, 1, -2))
		place:SetAttribute("next", n)
		self:SetAttribute("macrotext", self:GetAttribute("wm") .. " " .. strsub(order, n, n))
	]],
	Clear = [[
		local place = self:GetFrameRef("place")
		if not place:GetAttribute("order") then return false end
		place:SetAttribute("placed", "")
		place:SetAttribute("next", 1)
	]],
}

_G["BINDING_NAME_CLICK KstyleUI_QuickFirePlace:LeftButton"] = L["Place world marker"]
_G["BINDING_NAME_CLICK KstyleUI_QuickFireUndo:LeftButton"] = L["Undo last world marker"]
_G["BINDING_NAME_CLICK KstyleUI_QuickFireClear:LeftButton"] = L["Clear world markers"]

local buttons

local function Order()
	local list = {}
	for i = 1, 8 do list[i] = ns.Number(type(WORLD_RAID_MARKER_ORDER) == "table" and WORLD_RAID_MARKER_ORDER[i]) or i end
	return table.concat(list)
end

local function Count()
	local place = buttons and buttons.Place
	local order = place and ns.Ask(InCombatLockdown) == false and place:GetAttribute("order")
	if not order then return end
	local placed = place:GetAttribute("placed") or ""
	for i = #order, 1, -1 do
		if ns.Ask(IsRaidMarkerActive, tonumber(order:sub(i, i))) == false then
			place:SetAttribute("next", i)
			placed = placed:gsub(i, "")
		end
	end
	place:SetAttribute("placed", placed)
end

local function Build()
	if type(SecureHandlerWrapScript) ~= "function" or type(SecureHandlerSetFrameRef) ~= "function" then
		ns.LogOnce("noQuickFire", "SecureHandlerWrapScript is missing; Quick fire stays off")
		return
	end
	buttons = {}
	for key in pairs(SNIPPETS) do
		local button = CreateFrame("Button", "KstyleUI_QuickFire" .. key, K.Scale.Root(), "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useOnKeyDown", false)
		button:Hide()
		buttons[key] = button
	end
	buttons.Place:SetAttribute("type", "macro")
	buttons.Undo:SetAttribute("type", "macro")
	buttons.Clear:SetAttribute("type", "worldmarker")
	buttons.Clear:SetAttribute("action", "clear")
	buttons.Place:SetScript("PreClick", Count)
	for key, button in pairs(buttons) do
		if key ~= "Place" then SecureHandlerSetFrameRef(button, "place", buttons.Place) end
		SecureHandlerWrapScript(button, "OnClick", button, SNIPPETS[key])
	end
end

local function Sync()
	local on = ns.running and ns.Get("quickFire")
	if on then K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Count) else K.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED") end
	if not (on or buttons) then return end
	K.Combat.Queue(function()
		on = ns.running and ns.Get("quickFire")
		if on and not buttons then Build() end
		if not buttons then return end
		buttons.Place:SetAttribute("wm", SLASH_WORLD_MARKER1)
		buttons.Undo:SetAttribute("wm", SLASH_CLEAR_WORLD_MARKER1)
		buttons.Place:SetAttribute("order", on and type(SLASH_WORLD_MARKER1) == "string" and type(SLASH_CLEAR_WORLD_MARKER1) == "string" and Order() or nil)
		Count()
	end)
end

ns.AddPart({
	name = "quickfire",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or key == "quickFire" then Sync() end
	end,
})
