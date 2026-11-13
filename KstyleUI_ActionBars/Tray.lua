-- Tray.lua: the Frames tray, one quest card behind bar 1 and bar 2 while they stand stacked, bar 2 straight above bar 1, both shown and steady.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets

local Tray = {}
ns.Tray = Tray

local function Layouts()
	return K.Setup and K.Setup.Layouts or {}
end

local function Plain(v)
	return type(v) == "number" and not ns.IsSecret(v)
end

local function Edges(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (Plain(left) and Plain(right) and Plain(top) and Plain(bottom)) then
		return nil
	end
	return left, right, top, bottom
end

local function Stacked(lower, upper, gap)
	local l1, r1, t1, b1 = Edges(lower.holder)
	local l2, r2, _, b2 = Edges(upper.holder)
	if not (l1 and l2) then
		return false
	end
	local slack = K.Scale.Pixel(1)
	local rise = b2 - t1
	return math.abs(l1 - l2) <= slack and math.abs(r1 - r2) <= slack and rise >= -slack and rise <= 2 * gap + slack and b1 < b2
end

local function Card(main)
	local card = Tray.card
	if card then
		return card
	end
	card = CreateFrame("Frame", nil, main.holder)
	card:SetFrameLevel(main.holder:GetFrameLevel())
	card.chrome = Widgets.Chrome(card, { shape = "card" })
	card:Hide()
	Tray.card = card
	return card
end

function Tray.Wanted(main, second, steady)
	if ns.Config("tray") ~= true or K.HudStyle.Current() == "orbs" or not (main and second) or not steady then
		return false
	end
	if not (main:Shown() and second:Shown()) or main.holderHidden or second.holderHidden then
		return false
	end
	if main:Config().fade == true or second:Config().fade == true then
		return false
	end
	return Stacked(main, second, Layouts().TRAY_GAP or 0)
end

function Tray.Refresh(main, second, steady, force)
	local wanted = Tray.Wanted(main, second, steady)
	if not wanted then
		if Tray.card then
			Tray.card:Hide()
		end
		return false
	end
	local card = Card(main)
	if (force or card.pair ~= second) and Widgets.MayMove(card) then
		card.pair = second
		local pad = Widgets.Snap(card, Layouts().TRAY_PAD or 0)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", second.holder, "TOPLEFT", -pad, pad)
		card:SetPoint("BOTTOMRIGHT", main.holder, "BOTTOMRIGHT", pad, -pad)
		card.chrome:Restyle()
	end
	card:Show()
	return true
end
