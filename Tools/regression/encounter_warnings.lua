-- encounter_warnings.lua: a stand-in for Forever's RaidWarningFrame, the frame that shows boss emotes, boss whispers
-- and raid warnings in the middle of the screen, built from Blizzard_RaidWarning at 1.60.1 (Gethe/wow-ui-source,
-- branch forever): RaidWarning.xml (800 by 100, TOP of UIParent at y -182, HIGH strata, hidden, an Edit Mode system)
-- and RaidWarning.lua (a pool of GameFontNormalHuge strings; AddMessage acquires one, sets its text, colour and the
-- 20-unit resting height, shows the frame and calls UpdateLayout, which stacks the strings from the frame's TOP;
-- OnUpdate releases a faded string and calls UpdateShownState and UpdateLayout).
--
--   local Warnings = dofile("Tools/regression/encounter_warnings.lua")
--   local frame = Warnings.Build(env, B)               -- B from skins_env S.Blizzard(env)
--   frame:AddMessage("Bloodtalon Matriarch begins to cast Terrifying Screech!", Warnings.BOSS, 6, Warnings.BOSS_EMOTE)
--   Warnings.Lines(frame, 2)                           -- the newest message wraps to two lines
--   Warnings.Secret(frame, env)                        -- the newest message's anchoring is secret: its height reads secret
--   Warnings.Fade(frame, 0.4)                          -- every message fades to 0.4 alpha
--   Warnings.Expire(frame)                             -- the oldest message hides and the pool releases it
--
-- The stand-in keeps the parts the skin reads: the frame's methods (hooked, never replaced by the skin), its
-- fontStringPool (Acquire, Release, EnumerateActive, GetNumActive) and the strings' resting height, which the game
-- reports through GetStringHeight unless the string's anchoring is secret.
local Warnings = {}

Warnings.WIDTH, Warnings.HEIGHT, Warnings.Y = 800, 100, -182
Warnings.MIN_TEXT_HEIGHT, Warnings.MAX_TOTAL_LINES, Warnings.MAX_SLOTS = 20, 5, 4
Warnings.RAID_WARNING, Warnings.BOSS_EMOTE = 1, 2
Warnings.BOSS = { r = 1, g = 0.82, b = 0 }
Warnings.WARNING = { r = 1, g = 0.28, b = 0 }

local function Pool(frame)
	local active, inactive = {}, {}
	local pool = {}
	function pool.Acquire()
		local s = table.remove(inactive)
		local isNew = s == nil
		if isNew then
			s = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
		end
		active[#active + 1] = s
		return s, isNew
	end
	function pool.Release(_, s)
		for i, v in ipairs(active) do
			if v == s then
				table.remove(active, i)
				s:Hide()
				s:SetText("")
				s:ClearAllPoints()
				s._state.StringHeight = nil
				inactive[#inactive + 1] = s
				return
			end
		end
	end
	function pool.ReleaseAll(self)
		while #active > 0 do
			self:Release(active[1])
		end
	end
	function pool.EnumerateActive()
		local i = 0
		return function()
			i = i + 1
			return active[i]
		end
	end
	function pool.GetNumActive()
		return #active
	end
	pool._active = active
	return pool
end

-- Build(env, B) -> the stand-in RaidWarningFrame, hidden, made with the skins builder B so the tests can check that
-- the skin writes no field onto it.
function Warnings.Build(env, B)
	local frame = B.frame("Frame", env.UIParent, "RaidWarningFrame")
	frame:SetSize(Warnings.WIDTH, Warnings.MIN_TEXT_HEIGHT * Warnings.MAX_TOTAL_LINES)
	frame:SetPoint("TOP", env.UIParent, "TOP", 0, Warnings.Y)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	frame.fontStringPool = Pool(frame)
	frame.messageCounter = 0
	frame.maxMessageSlots = Warnings.MAX_SLOTS
	frame.maxTextHeight = 30
	function frame.GetSortedMessages(self)
		local sorted = {}
		for s in self.fontStringPool:EnumerateActive() do
			sorted[#sorted + 1] = s
		end
		table.sort(sorted, function(a, b)
			if a._warningType ~= b._warningType then
				return a._warningType < b._warningType
			end
			return a._warningOrder < b._warningOrder
		end)
		return sorted
	end
	function frame.UpdateShownState(self)
		self:SetShown(self.isInEditMode == true or self.fontStringPool:GetNumActive() > 0)
	end
	function frame.UpdateLayout(self)
		for i, s in ipairs(self:GetSortedMessages()) do
			s:ClearAllPoints()
			if i == 1 then
				s:SetPoint("TOP", self, "TOP")
			else
				s:SetPoint("TOP", self:GetSortedMessages()[i - 1], "BOTTOM")
			end
		end
	end
	function frame.AddMessage(self, text, color, _, messageType)
		local pool = self.fontStringPool
		if pool:GetNumActive() >= self.maxMessageSlots then
			pool:Release(self:GetSortedMessages()[1])
		end
		local s, isNew = pool:Acquire()
		if isNew then
			s:SetWidth(self:GetWidth())
			s:SetJustifyH("CENTER")
		end
		s:SetText(text)
		s:SetTextColor(color.r, color.g, color.b, 1)
		s:SetTextHeight(Warnings.MIN_TEXT_HEIGHT)
		s._state.StringHeight = { n = 1, Warnings.MIN_TEXT_HEIGHT }
		s._warningType = messageType or Warnings.RAID_WARNING
		self.messageCounter = self.messageCounter + 1
		s._warningOrder = self.messageCounter
		s:SetAlpha(1)
		s:Show()
		self:Show()
		self:UpdateLayout()
	end
	function frame.ClearMessages(self)
		self.fontStringPool:ReleaseAll()
		self:UpdateShownState()
		self:UpdateLayout()
	end
	frame:SetScript("OnUpdate", function(self)
		local released = false
		for _, s in ipairs(self:GetSortedMessages()) do
			if not s:IsShown() then
				self.fontStringPool:Release(s)
				released = true
			end
		end
		if self.fontStringPool:GetNumActive() == 0 then
			self:UpdateShownState()
		end
		if released then
			self:UpdateLayout()
		end
	end)
	return frame
end

local function Newest(frame)
	local newest
	for s in frame.fontStringPool:EnumerateActive() do
		if not newest or s._warningOrder > newest._warningOrder then
			newest = s
		end
	end
	return newest
end

-- Lines(frame, n): the newest message wraps to n lines at the resting height.
function Warnings.Lines(frame, n)
	Newest(frame)._state.StringHeight = { n = 1, n * Warnings.MIN_TEXT_HEIGHT }
end

-- Secret(frame): the newest message's text is secret, so its anchoring is secret and its height reads secret.
function Warnings.Secret(frame, env)
	Newest(frame)._state.StringHeight = { n = 1, env.Secret(Warnings.MIN_TEXT_HEIGHT) }
end

-- Fade(frame, alpha): every message fades to alpha, as FadingFrame_OnUpdate fades it, and the frame's OnUpdate runs.
function Warnings.Fade(frame, alpha)
	for _, s in ipairs(frame:GetSortedMessages()) do
		s:SetAlpha(alpha)
	end
	frame:GetScript("OnUpdate")(frame, 0.016)
end

-- Expire(frame): the oldest message has faded out and hidden; the frame's OnUpdate releases it.
function Warnings.Expire(frame)
	local oldest = frame:GetSortedMessages()[1]
	if oldest then
		oldest:Hide()
	end
	frame:GetScript("OnUpdate")(frame, 0.016)
end

-- Strings(frame) -> the active strings, oldest first.
function Warnings.Strings(frame)
	return frame:GetSortedMessages()
end

return Warnings
