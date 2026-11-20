-- History.lua: spell history, the spells the player cast last, as a strip of icons and as a card of bars styled like the damage meter.
local _, ns = ...

local K = KstyleUI
local L, Widgets = K.L, K.Widgets
local IsSecret = ns.Logic.IsSecret

local ICONS, BARS = "meters.historyIcons", "meters.historyBars"
local OWNER, MAX = "MetersHistory", 10
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }
local START = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "BOTTOM", DOWN = "TOP" }
local STEP = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local PLACES = { party = "hideDungeon", raid = "hideRaid", pvp = "hidePvP", arena = "hidePvP", none = "hideWorld" }
local REACH = { slide = 1, fly = 3 }

local History = { section = "history", casts = {}, icons = {}, fadeGen = 0 }
ns.History = History

local function Hidden()
	if ns.Get("history.toggle") and ns.windowsHidden then return true end
	if type(IsInInstance) ~= "function" then return false end
	local delves = C_DelvesUI
	local ok, delve = false, nil
	if type(delves) == "table" and type(delves.HasActiveDelve) == "function" then ok, delve = pcall(delves.HasActiveDelve) end
	if ok and not IsSecret(delve) and delve == true then return ns.Get("history.hideDelve") end
	local inside, kind = IsInInstance()
	if IsSecret(inside) or IsSecret(kind) then return false end
	local key = PLACES[inside and kind or "none"]
	return key ~= nil and ns.Get("history." .. key)
end

local function Icon(i)
	local icon = History.icons[i]
	if not icon then
		local frame = CreateFrame("Frame", nil, History.strip)
		local back = frame:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints(frame)
		back:SetColorTexture(K.Tokens.Color("black"))
		icon = { frame = frame, texture = frame:CreateTexture(nil, "ARTWORK") }
		History.icons[i] = icon
	end
	return icon
end

local function Render()
	local casts, strip = History.casts, History.strip
	if strip then
		local shown = History.iconsOn and not History.hidden and not History.faded
		strip:SetShown(shown)
		for i = 1, MAX do
			local icon = History.icons[i]
			local cast = casts[i]
			if i <= History.count and (IsSecret(cast) or cast ~= nil) then
				icon = icon or Icon(i)
				icon.texture:SetTexture(ns.SpellCall("GetSpellTexture", cast))
				icon.frame:Show()
			elseif icon then
				icon.frame:Hide()
			end
		end
	end
	local list = History.list
	if list then
		list.panel:SetShown(History.barsOn and not History.hidden)
		local n = math.min(#casts, ns.Get("history.barCount"), list.capacity or 0)
		local _, class = UnitClass("player")
		for i = 1, n do
			list:SetRow(i, ns.SpellCall("GetSpellName", casts[i]) or "", class, "friendly", 1, 1, "", "")
			list:SetRowIcon(i, ns.SpellCall("GetSpellTexture", casts[i]))
		end
		list:Finish(n, n == 0 and L["No spells yet"] or nil)
	end
end

local function FadeLater()
	History.fadeGen = History.fadeGen + 1
	local gen, delay = History.fadeGen, ns.Get("history.fade")
	if delay > 0 and InCombatLockdown() ~= true then
		C_Timer.After(delay, function()
			if gen == History.fadeGen and InCombatLockdown() ~= true then
				History.faded = true
				Render()
			end
		end)
	end
end

local function OnCast(_, _, _, spellID)
	if not IsSecret(spellID) and spellID == nil then return end
	table.insert(History.casts, 1, spellID)
	History.casts[MAX + 1] = nil
	History.faded = false
	if History.animate and History.iconsOn then
		History.group:Stop()
		History.group:Play(true)
	end
	Render()
	FadeLater()
end

function History:OnEvent(event)
	if event == "PLAYER_REGEN_DISABLED" then
		self.fadeGen = self.fadeGen + 1
	elseif event == "PLAYER_REGEN_ENABLED" then
		FadeLater()
	else
		self.hidden = Hidden()
		Render()
	end
end

local function BuildStrip()
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(160, 28)
	local strip = CreateFrame("Frame", nil, holder)
	strip:SetAllPoints(holder)
	local group = strip:CreateAnimationGroup()
	History.move, History.alpha = group:CreateAnimation("Translation"), group:CreateAnimation("Alpha")
	History.holder, History.strip, History.group = holder, strip, group
	K.Layout.Register(holder, ICONS, { anchor = "TOPRIGHT", x = -280, y = -190 }, { label = L["Spell history icons"], module = ns.MODULE })
end

local function StyleStrip()
	local grow, size, gap = ns.Get("history.grow"), ns.Get("history.size"), ns.Get("history.gap")
	local count, step, pitch = ns.Get("history.count"), STEP[grow], size + gap
	local long = count * pitch - gap
	History.holder:SetSize(step[1] ~= 0 and long or size, step[1] ~= 0 and size or long)
	local crop = ns.Get("damage.iconZoom")
	local edge = K.Scale.Pixel(1) / Widgets.ScaleFactor(History.holder)
	for i = 1, count do
		local icon = Icon(i)
		icon.frame:ClearAllPoints()
		icon.frame:SetSize(size, size)
		icon.frame:SetPoint(START[grow], History.strip, START[grow], step[1] * (i - 1) * pitch, step[2] * (i - 1) * pitch)
		icon.texture:ClearAllPoints()
		icon.texture:SetPoint("TOPLEFT", icon.frame, "TOPLEFT", edge, -edge)
		icon.texture:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", -edge, edge)
		icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	local anim = ns.Get("history.anim")
	local reach = (REACH[anim] or 0) * pitch
	History.move:SetOffset(-step[1] * reach, -step[2] * reach)
	History.move:SetDuration(anim == "fly" and 0.3 or 0.15)
	History.alpha:SetFromAlpha(1)
	History.alpha:SetToAlpha(anim == "fly" and 0 or 1)
	History.alpha:SetDuration(0.3)
	History.animate = anim ~= "none"
	History.count = count
end

local function BuildList()
	local width, height = ns.Footprint("meters.damage")
	History.list = ns.BarList.New(K.Scale.Root(), "history", {
		key = BARS, width = width or 248, height = height or 158, block = true,
		columns = function() return { value = false, percent = false } end,
		icons = function() return true end,
	})
	History.list:SetTitle(L["Spell history"])
	K.Layout.Register(History.list.holder, BARS, { anchor = "TOP", x = -160, y = -180 }, {
		label = L["Spell history bars"], module = ns.MODULE, resizable = true, minWidth = 120, maxWidth = 600, minHeight = 40, maxHeight = 800,
	})
end

function History:Start()
	self:Apply()
end

function History:Apply()
	if not ns.IsRunning() then return end
	self.iconsOn, self.barsOn = ns.Get("history.icons"), ns.Get("history.bars")
	ns.SetLive(ICONS, self.iconsOn)
	ns.SetLive(BARS, self.barsOn)
	if not self.iconsOn and not self.barsOn then
		self:Stop()
		return
	end
	if self.iconsOn and not self.holder then BuildStrip() end
	if self.barsOn and not self.list then BuildList() end
	self.count = self.count or 0
	if self.holder then
		self.holder:SetShown(self.iconsOn)
		if self.iconsOn then StyleStrip() end
	end
	if self.list then
		self.list.holder:SetShown(self.barsOn)
		self.list:Restyle()
	end
	for _, event in ipairs(EVENTS) do ns.Watch(self, event) end
	K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_SUCCEEDED", OnCast, "player")
	self.hidden, self.faded = Hidden(), nil
	Render()
	FadeLater()
end

function History:Stop()
	ns.UnwatchAll(self)
	K.Events.Unregister(OWNER, "UNIT_SPELLCAST_SUCCEEDED")
	self.fadeGen = self.fadeGen + 1
	if self.holder then self.holder:Hide() end
	if self.list then self.list.holder:Hide() end
end
