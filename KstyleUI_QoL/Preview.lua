-- Preview.lua: the QoL page's live preview, a miniature of the screen centre: the alert lines, the crosshair and the cursor ring where the screen puts them (the entering, leaving and group death samples, of which the screen shows one at a time, stack down from the flash line's spot and everything under that line moves down with them, and the ring sits beside the crosshair with its dot, a trail and the cast circle part filled), and the character stats with sample values at the left, painted by the same functions the screen uses and dimmed while their switch is off.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OFF = 0.35
local GAP = Tokens.Size("gapLarge")
local TRAIL, CAST_SECONDS, CAST_DONE = 3, 10, 6

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
	for i = 1, 5 do frame.lines[i] = Widgets.FontString(frame, "OVERLAY") end
	frame.cross = ns.BuildCrosshair(frame)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
	frame.dot = frame:CreateTexture(nil, "OVERLAY")
	frame.trail = {}
	for i = 1, TRAIL do frame.trail[i] = frame:CreateTexture(nil, "ARTWORK") end
	frame.cast = ns.BuildCast(frame)
	frame.stats = CreateFrame("Frame", nil, frame)
	frame.stats.lines = {}
	frame.Refresh = function(self)
		local combat, mode = ns.Get("combatAlert"), ns.Get("combatAlertOn")
		local samples = {
			{ ns.NoticeText("combatEnter"), combat and mode ~= "leave", "flash", ns.NoticeColor("combatEnter") },
			{ ns.NoticeText("combatLeave"), combat and mode ~= "enter", "flash", ns.NoticeColor("combatLeave") },
			{ L["A group member died"], ns.Get("deathAlert"), "flash", Tokens.Color("hostile") },
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
		ns.PaintCrosshair(self.cross)
		self.cross:SetAlpha(ns.Get("crosshair") ~= "none" and 1 or OFF)
		local ring, cast = ns.Get("cursorRing"), ns.Get("castRing")
		ns.PaintRing(self.ring, Dim(ring))
		ns.PaintDot(self.dot, Dim(ring and ns.Get("cursorDot")))
		ns.PaintCast(self.cast, Dim(cast))
		self.cast:SetReverse(true)
		self.cast:SetCooldown(GetTime() - CAST_DONE, CAST_SECONDS)
		if type(self.cast.Pause) == "function" then self.cast:Pause() end
		local cw, ch = self.cross:GetSize()
		local rw, sw, cx, cy = self.ring:GetWidth(), self.cast:GetWidth(), ns.Get("crosshairX"), ns.Get("crosshairY")
		local rx = cx + cw / 2 + 2 * GAP + sw / 2
		items[6] = { self.cross, cx, cy, cw, ch }
		items[7] = { self.ring, rx, cy, rw, rw }
		items[8] = { self.cast, rx, cy, sw, sw }
		items[9] = { self.dot, rx, cy, self.dot:GetWidth(), self.dot:GetHeight() }
		for i, dot in ipairs(self.trail) do
			ns.PaintDot(dot, (1 - i / (TRAIL + 1)) * (Dim(ring and ns.Get("cursorTrail")) or 1))
			items[#items + 1] = { dot, rx - sw / 2 - i * 2 * dot:GetWidth(), cy, dot:GetWidth(), dot:GetHeight() }
		end
		local _, flash = ns.NoticeSpot("flash", h)
		local step = flash - select(2, ns.NoticeSpot("talents", h))
		for i, item in ipairs(items) do
			item[3] = item[3] - (i <= 3 and i - 1 or item[3] < flash - h and 2 or 0) * step
		end
		local left, right, top, bottom = math.huge, -math.huge, -math.huge, math.huge
		local function bounds()
			for _, item in ipairs(items) do
				left, right = math.min(left, item[2] - item[4] / 2), math.max(right, item[2] + item[4] / 2)
				bottom, top = math.min(bottom, item[3] - item[5] / 2), math.max(top, item[3] + item[5] / 2)
			end
		end
		bounds()
		ns.StyleStats(self.stats, Sample)
		ns.FillStats(self.stats)
		self.stats:SetAlpha(ns.Get("stats") and 1 or OFF)
		local tw, th = self.stats:GetSize()
		items[#items + 1] = { self.stats, left - 2 * GAP - tw / 2, top - th / 2, tw, th }
		bounds()
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
