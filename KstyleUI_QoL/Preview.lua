-- Preview.lua: the QoL page's live preview, a miniature of the screen centre: the alert lines, the crosshair and the cursor ring where the screen puts them (the entering, leaving and group death samples, of which the screen shows one at a time, stack down from the flash line's spot and everything under that line moves down with them, and the ring sits beside the crosshair), painted by the same functions the screen uses and dimmed while their switch is off.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OFF = 0.35
local GAP = Tokens.Size("gapLarge")

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.lines = {}
	for i = 1, 5 do frame.lines[i] = Widgets.FontString(frame, "OVERLAY") end
	frame.cross = ns.BuildCrosshair(frame)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
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
		ns.PaintRing(self.ring, not ns.Get("cursorRing") and OFF or nil)
		local cw, ch = self.cross:GetSize()
		local rw, cx, cy = self.ring:GetWidth(), ns.Get("crosshairX"), ns.Get("crosshairY")
		items[6] = { self.cross, cx, cy, cw, ch }
		items[7] = { self.ring, cx + cw / 2 + 2 * GAP + rw / 2, cy, rw, rw }
		local _, flash = ns.NoticeSpot("flash", h)
		local step = flash - select(2, ns.NoticeSpot("talents", h))
		for i, item in ipairs(items) do
			item[3] = item[3] - (i <= 3 and i - 1 or item[3] < flash - h and 2 or 0) * step
		end
		local left, right, top, bottom = math.huge, -math.huge, -math.huge, math.huge
		for _, item in ipairs(items) do
			left, right = math.min(left, item[2] - item[4] / 2), math.max(right, item[2] + item[4] / 2)
			bottom, top = math.min(bottom, item[3] - item[5] / 2), math.max(top, item[3] + item[5] / 2)
		end
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
