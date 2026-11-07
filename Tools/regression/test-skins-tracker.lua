-- test-skins-tracker.lua: the objective tracker skin keeps the skin font, with the interface's fallback, on every tracker text, and its glass panel follows the tracker's content.
local S = dofile("Tools/regression/skins_env.lua")
local Near = S.W.Near

local HOOKED = { GetProgressBar = true, GetTimerBar = true, AddModule = true, SetFontObject = true, UpdateHeaderPosition = true, SetCollapsed = true }
local BLIZZARD_FACE, FALLBACK_FACE = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"

local function FontPath(text)
	return (text:GetFont())
end

-- Unloadable(object) makes object refuse every KstyleUI face, as the game does with a font file it cannot load.
local function Unloadable(object)
	local set = object.SetFont
	object.SetFont = function(self, path, ...)
		if type(path) == "string" and path:find("KstyleUI", 1, true) then
			return false
		end
		set(self, path, ...)
		return true
	end
end

-- Holder(B, parent, labelOnBar) -> a stand-in progress bar (label on its Bar) or timer bar (label on the holder).
local function Holder(B, parent, labelOnBar)
	local holder = B.frame("Frame", parent)
	local bar = B.frame("StatusBar", holder)
	holder.Bar = bar
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar.BorderLeft, bar.BorderRight, bar.BorderMid = B.texture(bar), B.texture(bar), B.texture(bar)
	local owner = labelOnBar and bar or holder
	owner.Label = B.text(owner)
	return holder
end

-- Collapsible(B, header) gives a header Blizzard's minimise button, whose art SetCollapsed swaps.
local function Collapsible(B, header)
	header.MinimizeButton = B.frame("Button", header)
	header.MinimizeButton.Art = B.texture(header.MinimizeButton)
	function header.SetCollapsed() end
end

-- Chevron(env, K, button) -> the KstyleUI chevron drawn on a child frame of button.
local function Chevron(env, K, button)
	for _, frame in ipairs(env._frames) do
		if frame:GetParent() == button then
			for _, region in ipairs({ frame:GetRegions() }) do
				if region:GetTexture() == (K.Tokens.Texture("glyphChevron")) then
					return region
				end
			end
		end
	end
end

-- Tracker(env, B, unloadable) -> a stand-in ObjectiveTrackerFrame that lays out as Blizzard's container does:
-- each layout re-anchors NineSlice's bottom to the last module with content, hides the frame when nothing is
-- tracked, and ends with self:UpdateHeaderPosition(). p.layout is the Update captured before any hook, which a
-- dirty update runs, as DirtiableMixin does. Edit Mode, not the content, sizes the frame.
local function Tracker(env, B, unloadable)
	local p = { modules = {} }
	local tracker = B.frame("Frame", nil, "ObjectiveTrackerFrame")
	tracker.isCollapsed = false
	tracker.NineSlice = B.frame("Frame", tracker)
	tracker.Header = B.frame("Frame", tracker)
	tracker.Header.Background, tracker.Header.Text = B.texture(tracker.Header, "BACKGROUND"), B.text(tracker.Header)
	Collapsible(B, tracker.Header)
	for i, height in ipairs({ 120, 60 }) do
		local module = B.frame("Frame", tracker)
		module.contentsHeight = height
		module.Header = B.frame("Frame", module)
		module.Header.Background, module.Header.Text = B.texture(module.Header, "BACKGROUND"), B.text(module.Header)
		Collapsible(B, module.Header)
		module.usedProgressBars, module.usedTimerBars = {}, {}
		local progress, timer = Holder(B, module, true), Holder(B, module, false)
		function module.GetContentsHeight(self)
			return self.contentsHeight
		end
		function module.GetProgressBar(self, key)
			self.usedProgressBars[key] = progress
			return progress
		end
		function module.GetTimerBar(self, key)
			self.usedTimerBars[key] = timer
			return timer
		end
		p.modules[i] = module
	end
	function tracker.ForEachModule(self, fn)
		for _, module in ipairs(p.modules) do
			fn(module)
		end
	end
	function tracker.IsCollapsed(self)
		return self.isCollapsed
	end
	function tracker.UpdateHeaderPosition() end
	function tracker.Update(self)
		local last
		for _, module in ipairs(p.modules) do
			last = module:GetContentsHeight() > 0 and module or last
		end
		if last then
			self.NineSlice:SetPoint("BOTTOM", last, "BOTTOM", 0, -10)
		end
		self._shown = last ~= nil
		self:UpdateHeaderPosition()
	end
	function tracker.SetCollapsed(self, collapsed)
		self.isCollapsed = collapsed
		self:Update()
	end
	p.layout = tracker.Update
	p.layout(tracker)

	env.GameFontHighlight = B.text(env.UIParent)
	env.GameFontHighlight:SetFont(FALLBACK_FACE, 12, "")
	env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont = B.text(env.UIParent), B.text(env.UIParent)
	env.ObjectiveTrackerLineFont:SetFont(BLIZZARD_FACE, 12, "")
	env.ObjectiveTrackerHeaderFont:SetFont(BLIZZARD_FACE, 14, "")
	if unloadable then
		for _, object in ipairs({ env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont, tracker.Header.Text, p.modules[1].Header.Text }) do
			Unloadable(object)
		end
	end
	p.tracker = tracker
	return p
end

-- Edge(frame, side, blizzard) -> the Blizzard object and point that frame's TOP or BOTTOM edge hangs from,
-- following anchors through KstyleUI's own frames. blizzard is keyed by Blizzard objects, as B.snapshot() is.
local function Edge(frame, side, blizzard)
	for i = 1, frame:GetNumPoints() do
		local point, relative, relativePoint = frame:GetPoint(i)
		if point:find(side, 1, true) then
			if blizzard[relative] then
				return relative, relativePoint
			end
			return Edge(relative, side, blizzard)
		end
	end
end

-- The glass panel hugs the tracker's content through every Blizzard layout -------------------------------

do
	local B, snap, p
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			p = Tracker(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	assert(ns.Skins.IsApplied("tracker"), "the shown tracker is skinned once its addon has loaded")
	local tracker = p.tracker
	local panel = K.Skin.Parts(tracker).backdrop
	assert(panel and panel:IsShown(), "a glass panel sits behind the tracker")
	local function Bottom()
		return Edge(panel, "BOTTOM", snap)
	end
	local top, topPoint = Edge(panel, "TOP", snap)
	assert(top == tracker and topPoint:find("TOP", 1, true), "the panel starts at the tracker's top")
	local bottom, bottomPoint = Bottom()
	assert(bottom == tracker.NineSlice and bottomPoint == "BOTTOM", "with quests tracked, the panel ends where Blizzard's content ends, not at the tracker's Edit Mode height: " .. tostring(bottomPoint))

	for _, header in ipairs({ tracker.Header, p.modules[1].Header }) do
		local chevron = Chevron(env, K, header.MinimizeButton)
		assert(header.MinimizeButton.Art:GetAlpha() == 0 and chevron, "Blizzard's red and yellow collapse buttons become KstyleUI chevrons")
		header:SetCollapsed(true)
		assert(S.W.LastCall(chevron, "SetTexCoord")[3] == 0, "collapsed, the chevron points down to open")
		header:SetCollapsed(false)
		assert(S.W.LastCall(chevron, "SetTexCoord")[3] == 1, "open, it points up to collapse")
	end
	tracker:SetCollapsed(true)
	assert(Bottom() == tracker.Header, "collapsed, the panel wraps the header only")
	tracker:SetCollapsed(false)
	assert(Bottom() == tracker.NineSlice, "expanded again, the panel follows the content")
	for _, module in ipairs(p.modules) do
		module.contentsHeight = 0
	end
	p.layout(tracker)
	assert(Bottom() == tracker.Header, "with nothing tracked, a dirty layout shrinks the panel to the header")
	p.modules[2].contentsHeight = 40
	p.layout(tracker)
	assert(Bottom() == tracker.NineSlice, "a quest tracked again grows the panel back with the next layout")

	local module = p.modules[1]
	local timer = module:GetTimerBar("t1")
	assert(FontPath(timer.Label) == Style.Font("caption"), "timer bar labels take the skin font")
	assert(timer.Bar.BorderLeft:GetAlpha() == 0, "timer bars lose their border art")
	assert(timer.Bar:GetStatusBarTexture():GetAlpha() == 1, "timer bars keep their fill")
	assert(FontPath(module:GetProgressBar("q1").Bar.Label) == Style.Font("caption"), "progress bar labels take the skin font")
	K.Options.Write("Skins", "tracker.panel", false)
	assert(not panel:IsShown(), "the panel switch still hides the panel")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A face the game cannot load: tracker text falls back like the rest of the interface ------------------

do
	local B, snap, p
	local env, K, ns = S.New({
		loaded = { Blizzard_ObjectiveTracker = true },
		before = function(env)
			B = S.Blizzard(env)
			p = Tracker(env, B, true)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	assert(Style.Font("body"):find("KstyleUI", 1, true), "the test needs the default face to be KstyleUI's")
	K.Modules.Enable("Skins")
	assert(ns.Skins.IsApplied("tracker"))
	local lineFont, headerFont = env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont
	local path, size = lineFont:GetFont()
	assert(path == FALLBACK_FACE, "quest lines and titles use GameFontHighlight's face, as the rest of the interface does, got " .. tostring(path))
	assert(Near(size, 12), "at Blizzard's tracker size, got " .. tostring(size))
	assert(FontPath(headerFont) == FALLBACK_FACE and Near(select(2, headerFont:GetFont()), 14))
	assert(FontPath(p.tracker.Header.Text) == FALLBACK_FACE, "the tracker's header falls back the same way")
	assert(FontPath(p.modules[1].Header.Text) == FALLBACK_FACE, "module headers fall back the same way")
	assert(S.Logged(env, "GameFontHighlight"), "the fallback is logged")

	lineFont:SetFontObject("ObjectiveTrackerFont16")
	path, size = lineFont:GetFont()
	assert(path == FALLBACK_FACE and Near(size, 16), "Edit Mode's text size keeps the fallback face at the new size, got " .. tostring(path) .. " " .. tostring(size))
	K.Options.Write("Skins", "text.size", 1.25)
	assert(FontPath(lineFont) == FALLBACK_FACE and Near(select(2, lineFont:GetFont()), 20), "the text size setting still scales it")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins tracker ok")
