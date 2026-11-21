-- Preview.lua: the QoL page's live preview, a miniature of the screen centre: the alert lines, the crosshair (in its out-of-range colour while that is on), the cursor ring, a movement alert counting down and the target distance where the screen puts them (the entering, leaving, group death and potion samples, of which the screen shows one at a time, stack down from the flash line's spot and everything under that line moves down with them, and the ring sits beside the crosshair with its dot and a trail, the cast circle part filled around the ring, or at the screen centre when it is off the pointer), and the character stats with sample values at the left, painted by the same functions the screen uses and dimmed while their switch is off.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OFF = 0.35
local GAP = Tokens.Size("gapLarge")
local TRAIL, CAST_SECONDS, CAST_DONE, FLASH = 3, 10, 6, 4
local MOVE_TOP, RANGE_X, MOVE_LEFT = -40, -90, 2.4

local function Sample(stat)
	local n = #stat[1]
	return stat[7] and 10 + n * 0.75 or 100 * n, 120 + 15 * n
end

local function Dim(on)
	return not on and OFF or nil
end

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.lines = {}
	for i = 1, 6 do frame.lines[i] = Widgets.FontString(frame, "OVERLAY") end
	frame.cross = ns.BuildCrosshair(frame)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
	frame.dot = frame:CreateTexture(nil, "OVERLAY")
	frame.trail = {}
	for i = 1, TRAIL do frame.trail[i] = frame:CreateTexture(nil, "ARTWORK") end
	frame.cast = ns.BuildCast(frame)
	frame.move = ns.BuildMoveSlot(frame)
	frame.range = CreateFrame("Frame", nil, frame)
	frame.range.text = Widgets.FontString(frame.range, "OVERLAY")
	frame.stats = CreateFrame("Frame", nil, frame)
	frame.stats.lines = {}
	frame.Refresh = function(self)
		local combat, mode = ns.Get("combatAlert"), ns.Get("combatAlertOn")
		local samples = {
			{ ns.NoticeText("combatEnter"), combat and mode ~= "leave", "flash", ns.NoticeColor("combatEnter") },
			{ ns.NoticeText("combatLeave"), combat and mode ~= "enter", "flash", ns.NoticeColor("combatLeave") },
			{ L["A group member died"], ns.Get("deathAlert"), "flash", Tokens.Color("hostile") },
			{ L["Potion ready"], ns.Get("potionAlert"), "flash", Tokens.Color("friendly") },
			{ ns.NoticeText("talent"), ns.Get("talentAlert"), "talents", ns.NoticeColor("talent") },
			{ string.format(L["Low durability: %d%%"], ns.Get("durabilityPercent") - 1), ns.Get("durabilityAlert"), "durability", Tokens.Color("neutral") },
		}
		local items, h = {}, 0
		for i, sample in ipairs(samples) do
			local text = self.lines[i]
			ns.PaintNotice(text, sample[1], sample[4], sample[5], sample[6])
			text:SetAlpha(sample[2] and 1 or OFF)
			h = Widgets.TextHeight(text, Widgets.LineHeight(text))
			local point, y = ns.NoticeSpot(sample[3], h)
			items[i] = { text, 0, point == "TOP" and y - h / 2 or y + h / 2, Widgets.TextWidth(text, 1), h }
		end
		ns.PaintCrosshair(self.cross, ns.Get("crosshairRange"))
		self.cross:SetAlpha(ns.Get("crosshair") ~= "none" and 1 or OFF)
		local ring, cast = ns.Get("cursorRing"), ns.Get("castRing")
		ns.PaintRing(self.ring, Dim(ring))
		ns.PaintDot(self.dot, Dim(ring and ns.Get("cursorDot")))
		ns.PaintCast(self.cast, Dim(cast))
		self.cast:SetReverse(true)
		if type(GetTime) == "function" then self.cast:SetCooldown(GetTime() - CAST_DONE, CAST_SECONDS) end
		if type(self.cast.Pause) == "function" then self.cast:Pause() end
		local cw, ch = self.cross:GetSize()
		local rw, sw, cx, cy = self.ring:GetWidth(), self.cast:GetWidth(), ns.Get("crosshairX"), ns.Get("crosshairY")
		local rx = cx + cw / 2 + 2 * GAP + sw / 2
		items[7] = { self.cross, cx, cy, cw, ch }
		items[8] = { self.ring, rx, cy, rw, rw }
		local attach = ns.Get("castAttach")
		items[9] = { self.cast, attach and rx or 0, attach and cy or 0, sw, sw }
		items[10] = { self.dot, rx, cy, self.dot:GetWidth(), self.dot:GetHeight() }
		for i, dot in ipairs(self.trail) do
			ns.PaintDot(dot, (1 - i / (TRAIL + 1)) * (Dim(ring and ns.Get("cursorTrail")) or 1))
			items[#items + 1] = { dot, rx - sw / 2 - i * 2 * dot:GetWidth(), cy, dot:GetWidth(), dot:GetHeight() }
		end
		local move, range = self.move, self.range
		local mh, time = move:Paint(), Widgets.Duration.Format(MOVE_LEFT, ns.Get("moveDecimal") and "decimal" or "short")
		local id = ns.MoveSample()
		local label, icon = ns.MoveFormat(ns.MoveName(id)):gsub("{}", time), C_Spell and ns.Ask(C_Spell.GetSpellTexture, id)
		if move.mode == "icon" then
			move.icon:SetIcon(icon)
			if type(GetTime) == "function" then move.icon:SetCooldown(GetTime() - CAST_DONE, CAST_DONE + MOVE_LEFT) end
			if type(move.icon.cooldown.Pause) == "function" then move.icon.cooldown:Pause() end
		elseif move.mode == "bar" then
			move.bar.label:SetText(label)
			move.bar.art:SetTexture(icon)
			move.bar:SetBarRange(0, CAST_DONE + MOVE_LEFT)
			move.bar:SetBarValue(MOVE_LEFT)
		else
			move.text:SetText(label)
		end
		move:SetAlpha(ns.Get("moveAlert") and 1 or OFF)
		local below = math.min(MOVE_TOP, math.min(cy - ch / 2, cy - rw / 2, (attach and cy or 0) - sw / 2) - GAP)
		items[#items + 1] = { move, 0, below - mh / 2, move:GetWidth(), mh }
		ns.PaintRange(range.text, range)
		range.text:SetText(ns.RangeText(30, 35))
		range:SetAlpha(ns.Get("rangeText") and 1 or OFF)
		items[#items + 1] = { range, math.min(RANGE_X, cx - cw / 2 - GAP - range:GetWidth() / 2), 0, range:GetWidth(), range:GetHeight() }
		local _, flash = ns.NoticeSpot("flash", h)
		local step = flash - select(2, ns.NoticeSpot("talents", h))
		for i, item in ipairs(items) do
			item[3] = item[3] - (i <= FLASH and i - 1 or item[3] < flash - h and FLASH - 1 or 0) * step
		end
		local left, right, top, bottom = math.huge, -math.huge, -math.huge, math.huge
		for _, item in ipairs(items) do
			left, right = math.min(left, item[2] - item[4] / 2), math.max(right, item[2] + item[4] / 2)
			bottom, top = math.min(bottom, item[3] - item[5] / 2), math.max(top, item[3] + item[5] / 2)
		end
		ns.StyleStats(self.stats, Sample)
		ns.FillStats(self.stats)
		self.stats:SetAlpha(ns.Get("stats") and 1 or OFF)
		local tw, th = self.stats:GetSize()
		items[#items + 1] = { self.stats, left - 2 * GAP - tw / 2, top - th / 2, tw, th }
		left, bottom = left - 2 * GAP - tw, math.min(bottom, top - th)
		Widgets.Size(self, right - left + 2 * GAP, top - bottom)
		for _, item in ipairs(items) do
			item[1]:ClearAllPoints()
			Widgets.Point(item[1], "CENTER", self, "CENTER", item[2] - (left + right) / 2, item[3] - (top + bottom) / 2)
		end
	end
	frame.Restyle = frame.Refresh
	Widgets.Track(frame)
	frame:Refresh()
	return frame
end
