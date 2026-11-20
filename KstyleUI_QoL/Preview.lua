-- Preview.lua: the QoL page's live preview: the alert lines, the crosshair and the cursor ring, painted by the same functions the screen uses and dimmed while their switch is off.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OFF = 0.35
local GAP = 12

function ns.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.lines = {}
	for i = 1, 4 do frame.lines[i] = Widgets.FontString(frame, "OVERLAY") end
	frame.cross = ns.BuildCrosshair(frame)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
	frame.Refresh = function(self)
		local combat, talent, durability = ns.Get("combatAlert"), ns.Get("talentAlert"), ns.Get("durabilityAlert")
		local mode = ns.Get("combatAlertOn")
		local samples = {
			{ ns.NoticeText("combatEnter"), combat and mode ~= "leave", ns.NoticeColor("combatEnter") },
			{ ns.NoticeText("combatLeave"), combat and mode ~= "enter", ns.NoticeColor("combatLeave") },
			{ ns.NoticeText("talent"), talent, ns.NoticeColor("talent") },
			{ string.format(L["Low durability: %d%%"], ns.Get("durabilityPercent") - 1), durability, Tokens.Color("neutral") },
		}
		local width, height = 0, -GAP
		for i, sample in ipairs(samples) do
			local text = self.lines[i]
			ns.PaintNotice(text, sample[1], sample[3], sample[4], sample[5])
			text:SetAlpha(sample[2] and 1 or OFF)
			width, height = math.max(width, Widgets.TextWidth(text, 0)), height + Widgets.TextHeight(text, Widgets.LineHeight(text)) + GAP
		end
		ns.PaintCrosshair(self.cross)
		self.cross:SetAlpha(ns.Get("crosshair") ~= "none" and 1 or OFF)
		ns.PaintRing(self.ring, not ns.Get("cursorRing") and OFF or nil)
		local cw, ch = self.cross:GetSize()
		local rw = self.ring:GetWidth()
		Widgets.Size(self, width + 6 * GAP + cw + rw, math.max(height, ch, rw))
		local y = 0
		for _, text in ipairs(self.lines) do
			text:ClearAllPoints()
			Widgets.Point(text, "TOP", self, "TOPLEFT", GAP + width / 2, -y)
			y = y + Widgets.TextHeight(text, Widgets.LineHeight(text)) + GAP
		end
		self.cross:ClearAllPoints()
		Widgets.Point(self.cross, "LEFT", self, "LEFT", width + 3 * GAP, 0)
		self.ring:ClearAllPoints()
		Widgets.Point(self.ring, "LEFT", self.cross, "RIGHT", 2 * GAP, 0)
	end
	frame.Restyle = frame.Refresh
	Widgets.Track(frame)
	frame:Refresh()
	return frame
end
