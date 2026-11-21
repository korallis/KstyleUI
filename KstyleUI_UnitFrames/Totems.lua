-- Totems.lua: the player's totems in a row beside the player frame, each with its time left, from the game's totem slots.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Settings = ns.Settings

local Totems = {}
ns.Totems = Totems

local OWNER = Settings.MODULE .. ":totems"
local GAP = 4
local SLOTS = 4
local SIDES = { ABOVE = { "BOTTOMLEFT", "TOPLEFT", 0, 1 }, BELOW = { "TOPLEFT", "BOTTOMLEFT", 0, -1 }, LEFT = { "RIGHT", "LEFT", -1, 0 }, RIGHT = { "LEFT", "RIGHT", 1, 0 } }
local issecretvalue = issecretvalue or function() return false end
local live, listening

function Totems.Row(parent)
	local row = CreateFrame("Frame", nil, parent)
	row.buttons = {}
	local n = GetNumTotemSlots and GetNumTotemSlots()
	for i = 1, (not issecretvalue(n) and type(n) == "number" and n > 0) and n or SLOTS do
		local button = Widgets.IconButton(row, { size = Settings.Value("player", "totemSize") })
		button:EnableMouse(false)
		row.buttons[i] = button
	end
	return row
end

function Totems.Place(row, holder)
	local side = SIDES[Settings.Value("player", "totemPosition")] or SIDES.ABOVE
	local size, gap, count = Settings.Value("player", "totemSize"), Widgets.Snap(holder, GAP), #row.buttons
	size = Widgets.Snap(holder, size)
	row:ClearAllPoints()
	row:SetPoint(side[1], holder, side[2], side[3] * gap, side[4] * gap)
	row:SetSize(count * size + (count - 1) * gap, size)
	for i, button in ipairs(row.buttons) do
		button.opts.size = size
		button:Restyle()
		button:ClearAllPoints()
		local slot = side[3] < 0 and count - i or i - 1
		button:SetPoint("TOPLEFT", row, "TOPLEFT", slot * (size + gap), 0)
	end
end

local function Slot(button, i)
	local have, _, start, duration, icon = GetTotemInfo(i)
	if issecretvalue(have) then
		button:SetAlphaFromBoolean(have, 1, 0)
		button:Show()
	else
		button:SetAlpha(1)
		button:SetShown(have == true)
		if have ~= true then return end
	end
	button:SetIcon(icon)
	local ok, object = false, nil
	if GetTotemDuration then ok, object = pcall(GetTotemDuration, i) end
	if ok and object then
		button:SetCooldownFromDuration(object)
	else
		button:SetCooldown(start, duration)
	end
end

local function Update()
	for i, button in ipairs(live.buttons) do
		Slot(button, i)
	end
end

function Totems.Apply(uf)
	local on = ns.Frames.IsRunning() and uf.active and Settings.Value("player", "totems") and GetTotemInfo ~= nil
	if listening ~= (on and true or false) then
		listening = on and true or false
		if on then
			K.Events.Register(OWNER, "PLAYER_TOTEM_UPDATE", Update)
			K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Update)
		else
			K.Events.UnregisterAll(OWNER)
		end
	end
	if not on then
		if live then live:Hide() end
		return
	end
	live = live or Totems.Row(uf.holder)
	Totems.Place(live, uf.holder)
	live:Show()
	Update()
end
