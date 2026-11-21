-- RaidTools.lua: the raid tools, a Layout element: a star marker button that opens a glass panel of ready check, role check, a ten-second pull timer and the eight target markers with Clear, in a row or a column, opening down or up and right or left from the button, the other way on an axis where the chosen way would leave the screen. It shows by the Show raid tools rule (in a raid only for the leader or an assistant, the only players its buttons work for; an unknown raid answer hides it), starts collapsed when asked, opens on a ready check when asked, and the Toggle raid tools binding clicks it. The actions are the calls Blizzard's own raid manager makes, enabled as it enables them (ready check, role check and pull timer for the leader or an assistant in a group, the role check not in a finder group or a battleground, the markers for anyone the tools show to), repainted only when that or combat changes, and refused in combat, where the game restricts them; the frame is not secure, so it shows and hides in combat too.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY, NAME = "QoL.raidtools", "qol.raidtools", "KstyleUI_RaidTools"
local MARKS, COUNT, PULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 8, 10
local GROW = { downright = { "TOPLEFT", "BOTTOMLEFT", -1 }, downleft = { "TOPRIGHT", "BOTTOMRIGHT", -1 }, upright = { "BOTTOMLEFT", "TOPLEFT", 1 }, upleft = { "BOTTOMRIGHT", "TOPRIGHT", 1 } }
local EVENTS = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "READY_CHECK" }

_G["BINDING_NAME_CLICK KstyleUI_RaidTools:LeftButton"] = L["Toggle raid tools"]

local holder
local open = false

local function Do(api, ...)
	if ns.Ask(InCombatLockdown) == false and type(api) == "function" then api(...) end
end

local function Party(name)
	return type(C_PartyInfo) == "table" and C_PartyInfo[name] or nil
end

local ACTIONS = {
	{ L["Ready check"], function() Do(Party("DoReadyCheck")) end },
	{ L["Role check"], function() Do(InitiateRolePoll) end },
	{ L["Pull timer"], function() Do(Party("DoCountdown"), PULL) end },
}

local function Mark(i)
	Do(SetRaidTarget, "target", i ~= 0 and ns.Ask(GetRaidTargetIndex, "target") == i and 0 or i)
end

function ns.RaidToolsWanted()
	local mode = ns.running and ns.Get("raidTools") or "never"
	if mode == "never" then return false end
	local raid = ns.Ask(IsInRaid)
	if raid == true then return ns.Ask(UnitIsGroupLeader, "player") == true or ns.Ask(UnitIsGroupAssistant, "player") == true end
	return raid == false and mode == "group" and ns.Ask(IsInGroup) == true
end

function ns.ArrangeRaidTools(panel, buttons, layout)
	local gap, pad = Tokens.Size("gapSmall"), panel.chrome:Inset("gapMedium")
	local widest = 0
	for _, button in ipairs(buttons) do
		if not button.SetIcon then
			button.opts.width = nil
			button:Restyle()
			widest = math.max(widest, button:GetWidth())
		end
	end
	local size = buttons[1]:GetHeight()
	local x, y, w, h = 0, 0, 0, 0
	for _, button in ipairs(buttons) do
		if button.SetIcon then button.opts.size = size elseif layout == "column" then button.opts.width = widest end
		button:Restyle()
		button:ClearAllPoints()
		Widgets.Point(button, "TOPLEFT", panel.content, "TOPLEFT", x, -y)
		local bw, bh = button:GetWidth(), button:GetHeight()
		w, h = math.max(w, x + bw), math.max(h, y + bh)
		if layout == "row" then x = x + bw + gap else y = y + bh + gap end
	end
	Widgets.Size(panel, w + 2 * pad, h + 2 * pad)
end

function ns.AnchorRaidTools(panel, grow, anchor)
	local spot = GROW[grow]
	panel:ClearAllPoints()
	Widgets.Point(panel, spot[1], anchor, spot[2], 0, spot[3] * Tokens.Size("gapSmall"))
	return spot[1]
end

function ns.RaidToolsStar(parent, name, onClick)
	local star = Widgets.IconButton(parent, { name = name, crop = false, icon = MARKS, tooltip = L["Raid tools"], onClick = onClick })
	star.icon:SetSpriteSheetCell(1, 4, 4)
	return star
end

function ns.RaidToolButtons(parent)
	local buttons = {}
	for _, action in ipairs(ACTIONS) do buttons[#buttons + 1] = Widgets.Button(parent, { text = action[1], onClick = action[2] }) end
	for i = 1, COUNT do
		local button = Widgets.IconButton(parent, { crop = false, icon = MARKS, onClick = function() Mark(i) end })
		button.icon:SetSpriteSheetCell(i, 4, 4)
		buttons[#buttons + 1] = button
	end
	buttons[#buttons + 1] = Widgets.Button(parent, { text = L["Clear"], onClick = function() Mark(0) end })
	return buttons
end

local function Paint(event)
	local free = event ~= "PLAYER_REGEN_DISABLED" and ns.Ask(InCombatLockdown) == false
	local lead = free and ns.Ask(IsInGroup) == true and (ns.Ask(UnitIsGroupLeader, "player") == true or ns.Ask(UnitIsGroupAssistant, "player") == true)
	local poll = lead and ns.Ask(HasLFGRestrictions) == false and ns.Ask(UnitInBattleground, "player") == nil
	local state = (free and 1 or 0) + (lead and 2 or 0) + (poll and 4 or 0)
	if state ~= holder.state then
		holder.state = state
		for i, button in ipairs(holder.buttons) do
			if i == 2 then button:SetEnabled(poll) elseif i <= 3 then button:SetEnabled(lead) else button:SetEnabled(free) end
		end
	end
	holder.panel:SetShown(open)
end

local function Aim()
	local grow, root, panel, gap = ns.Get("raidToolsGrow"), K.Scale.Root(), holder.panel, Tokens.Size("gapSmall")
	local k, left, bottom, right, top = holder:GetEffectiveScale() / root:GetEffectiveScale(), holder:GetLeft(), holder:GetBottom(), holder:GetRight(), holder:GetTop()
	if left and bottom and right and top then
		local w, h = panel:GetWidth(), panel:GetHeight()
		if grow:find("^down") and (bottom - gap - h) * k < root:GetBottom() then grow = "up" .. grow:sub(5)
		elseif grow:find("^up") and (top + gap + h) * k > root:GetTop() then grow = "down" .. grow:sub(3) end
		if grow:find("left$") and (right - w) * k < root:GetLeft() then grow = grow:sub(1, -5) .. "right"
		elseif grow:find("right$") and (left + w) * k > root:GetRight() then grow = grow:sub(1, -6) .. "left" end
	end
	ns.AnchorRaidTools(panel, grow, holder)
end

local function Moved(_, key)
	if key == KEY and holder then Aim() end
end

function ns.ToggleRaidTools()
	if not (holder and holder:IsShown()) then return end
	open = not open
	Paint()
end

local function Build()
	holder = ns.RaidToolsStar(K.Scale.Root(), NAME, ns.ToggleRaidTools)
	holder.panel = Widgets.Panel(holder, {})
	holder.buttons = ns.RaidToolButtons(holder.panel.content)
	local restyle = holder.Restyle
	holder.Restyle = function(self)
		restyle(self)
		ns.ArrangeRaidTools(self.panel, self.buttons, ns.Get("raidToolsLayout"))
		Aim()
	end
	holder:Hide()
	Widgets.Place(holder, KEY, { anchor = "TOPLEFT", x = 16, y = -320 }, { label = L["Raid tools"], module = ns.MODULE, scalable = true })
end

local function Refresh(event)
	if not holder then return end
	local want = ns.RaidToolsWanted()
	if want and not holder:IsShown() then open = not ns.Get("raidToolsCollapsed") end
	if event == "READY_CHECK" and ns.Get("raidToolsReady") then open = true end
	holder:SetShown(want)
	if K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, want) end
	Paint(event)
end

local function Sync()
	local on = ns.running and ns.Get("raidTools") ~= "never"
	for _, event in ipairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, Refresh) else K.Events.Unregister(OWNER, event) end
	end
	if on then K.Callbacks.Register("LayoutChanged", OWNER, Moved) else K.Callbacks.Unregister("LayoutChanged", OWNER) end
	if on and not holder then Build() end
	if holder then
		holder:Restyle()
		Refresh()
	end
end

ns.AddPart({
	name = "raidtools",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and key:find("^raidTools") then Sync() end
	end,
})
