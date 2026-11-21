-- RaidTools.lua: the raid tools, a Layout element: a star marker button that opens a glass panel of ready check, role check, a ten-second pull timer and the eight target markers with Clear, in a row or a column, opening down or up and right or left from the button. It shows by the Show raid tools rule (in a raid only for the leader or an assistant, the only players its buttons work for), starts collapsed when asked, opens on a ready check when asked, and the Toggle raid tools binding clicks it. The actions are the calls Blizzard's own raid manager makes and are refused in combat, where the game restricts them; the frame is not secure, so it shows and hides in combat too.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY, NAME = "QoL.raidtools", "qol.raidtools", "KstyleUI_RaidTools"
local MARKS, COUNT, PULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 8, 10
local GROW = { downright = { "TOPLEFT", "BOTTOMLEFT", -1 }, downleft = { "TOPRIGHT", "BOTTOMRIGHT", -1 }, upright = { "BOTTOMLEFT", "TOPLEFT", 1 }, upleft = { "BOTTOMRIGHT", "TOPRIGHT", 1 } }
local EVENTS = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "READY_CHECK" }

BINDING_HEADER_KSTYLEUI_QOL = L["KstyleUI quality of life"]
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
	if ns.Ask(IsInRaid) == true then return ns.Ask(UnitIsGroupLeader, "player") == true or ns.Ask(UnitIsGroupAssistant, "player") == true end
	return mode == "group" and ns.Ask(IsInGroup) == true
end

function ns.ArrangeRaidTools(panel, buttons, layout, grow, anchor)
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
	local spot = GROW[grow]
	if anchor then
		panel:ClearAllPoints()
		Widgets.Point(panel, spot[1], anchor, spot[2], 0, spot[3] * gap)
	end
	return spot[1]
end

function ns.RaidToolsStar(parent, name, onClick)
	local star = Widgets.IconButton(parent, { name = name, crop = false, tooltip = L["Raid tools"], onClick = onClick })
	star:SetIcon(MARKS)
	star.icon:SetSpriteSheetCell(1, 4, 4)
	return star
end

function ns.RaidToolButtons(parent)
	local buttons = {}
	for _, action in ipairs(ACTIONS) do buttons[#buttons + 1] = Widgets.Button(parent, { text = action[1], onClick = action[2] }) end
	for i = 1, COUNT do
		local button = Widgets.IconButton(parent, { crop = false, onClick = function() Mark(i) end })
		button:SetIcon(MARKS)
		button.icon:SetSpriteSheetCell(i, 4, 4)
		buttons[#buttons + 1] = button
	end
	buttons[#buttons + 1] = Widgets.Button(parent, { text = L["Clear"], onClick = function() Mark(0) end })
	return buttons
end

local function Paint(event)
	local free = event ~= "PLAYER_REGEN_DISABLED" and ns.Ask(InCombatLockdown) == false
	for _, button in ipairs(holder.buttons) do button:SetEnabled(free) end
	holder.panel:SetShown(open)
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
		ns.ArrangeRaidTools(self.panel, self.buttons, ns.Get("raidToolsLayout"), ns.Get("raidToolsGrow"), self)
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
	if on and not holder then Build() end
	if holder then
		holder:Restyle()
		Refresh()
	end
end

function ns.RaidToolsFrame() return holder end

ns.AddPart({
	name = "raidtools",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and key:find("^raidTools") then Sync() end
	end,
})
