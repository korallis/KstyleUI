-- test-skins-quests.lua: the world map, quest log and objective tracker skins restyle Forever's map window, quest list and tracker without covering the map or touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local HOOKED = { GetProgressBar = true, AddModule = true, SetFontObject = true, SetText = true }

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

local function Pool(list)
	return {
		EnumerateActive = function()
			local i = 0
			return function()
				i = i + 1
				return list[i]
			end
		end,
	}
end

-- WorldMap(env, B) -> the stand-in WorldMapFrame and the QuestMapFrame attached to it.
local function WorldMap(env, B)
	local p = {}
	local map = B.frame("Frame", nil, "WorldMapFrame")
	map:Hide()
	map:SetFrameLevel(5)
	map.ScrollContainer = B.frame("ScrollFrame", map)
	local border = B.frame("Frame", map)
	map.BorderFrame = border
	border.NineSlice = B.frame("Frame", border)
	p.nine = B.texture(border.NineSlice)
	border.Bg = B.texture(border, "BACKGROUND")
	border.InsetBorderTop = B.texture(border, "BACKGROUND")
	border.TitleContainer = B.frame("Frame", border)
	border.TitleContainer.TitleText = B.text(border.TitleContainer)
	border.PortraitContainer = B.frame("Frame", border)
	B.texture(border.PortraitContainer)
	border.CloseButton = B.frame("Button", border)
	B.texture(border.CloseButton)
	border.MaximizeMinimizeFrame = B.frame("Frame", border)
	border.MaximizeMinimizeFrame.MaximizeButton = B.frame("Button", border.MaximizeMinimizeFrame)
	border.MaximizeMinimizeFrame.MinimizeButton = B.frame("Button", border.MaximizeMinimizeFrame)
	p.minimizeArt = B.texture(border.MaximizeMinimizeFrame.MinimizeButton)
	map.NavBar = B.frame("Frame", map)
	p.navArt = B.texture(map.NavBar)
	map.NavBar.overlay = B.frame("Frame", map.NavBar)
	p.navOverlay = B.texture(map.NavBar.overlay)
	map.NavBar.home = B.frame("Button", map.NavBar)
	p.homeArt = B.texture(map.NavBar.home)

	local log = B.frame("Frame", map, "QuestMapFrame")
	log:Hide()
	log.QuestsFrame = B.frame("Frame", log)
	local scroll = B.frame("ScrollFrame", log.QuestsFrame, "QuestScrollFrame")
	log.QuestsFrame.ScrollFrame = scroll
	scroll.Background, scroll.Edge = B.texture(scroll, "BACKGROUND"), B.texture(scroll)
	scroll.ScrollBar = B.frame("Frame", scroll)
	scroll.SearchBox = B.frame("EditBox", scroll)
	B.texture(scroll.SearchBox)
	scroll.BorderFrame = B.frame("Frame", scroll)
	p.logBorder = B.texture(scroll.BorderFrame)
	local header = B.frame("Button", scroll)
	header.ButtonText = B.text(header)
	local title = B.frame("Button", scroll)
	title.Text = B.text(title)
	p.lateTitle = B.frame("Button", scroll)
	p.lateTitle.Text = B.text(p.lateTitle)
	p.titles = { title }
	scroll.headerFramePool = Pool({ header })
	scroll.titleFramePool = Pool(p.titles)
	env.QuestLogQuests_Update = function() end
	local details = B.frame("Frame", log.QuestsFrame)
	log.QuestsFrame.DetailsFrame = details
	details.Bg = B.texture(details, "BACKGROUND")
	details.BackFrame = B.frame("Frame", details)
	details.BackFrame.BackButton = B.frame("Button", details.BackFrame)
	B.texture(details.BackFrame.BackButton)
	for _, key in ipairs({ "AbandonButton", "ShareButton", "TrackButton" }) do
		details[key] = B.frame("Button", details)
		B.texture(details[key])
	end
	details.ScrollFrame = B.frame("ScrollFrame", details)
	details.ScrollFrame.ScrollBar = B.frame("Frame", details.ScrollFrame)
	p.map, p.log, p.scroll, p.header, p.title, p.details = map, log, scroll, header, title, details
	return p
end

local function ProgressHolder(B, parent)
	local holder = B.frame("Frame", parent)
	local bar = B.frame("StatusBar", holder)
	holder.Bar = bar
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.26, 0.42, 1)
	bar.BorderLeft, bar.BorderRight, bar.BorderMid = B.texture(bar), B.texture(bar), B.texture(bar)
	bar.Label = B.text(bar)
	return holder
end

-- Tracker(env, B) -> the stand-in ObjectiveTrackerFrame with one module, and the tracker font objects.
local function Tracker(env, B)
	local p = {}
	local tracker = B.frame("Frame", nil, "ObjectiveTrackerFrame")
	tracker.NineSlice = B.frame("Frame", tracker)
	p.nine = B.texture(tracker.NineSlice)
	tracker.Header = B.frame("Frame", tracker)
	tracker.Header.Background = B.texture(tracker.Header, "BACKGROUND")
	tracker.Header.Text = B.text(tracker.Header)
	local modules = {}
	local function Module()
		local module = B.frame("Frame", tracker)
		module.Header = B.frame("Frame", module)
		module.Header.Background = B.texture(module.Header, "BACKGROUND")
		module.Header.Text = B.text(module.Header)
		module.usedProgressBars = {}
		local spare = ProgressHolder(B, module)
		function module.GetProgressBar(self, key)
			self.usedProgressBars[key] = self.usedProgressBars[key] or spare
			return self.usedProgressBars[key]
		end
		return module
	end
	modules[1] = Module()
	p.extra = Module()
	function tracker.ForEachModule(self, fn)
		for _, module in ipairs(modules) do
			fn(module)
		end
	end
	function tracker.AddModule(self, module)
		modules[#modules + 1] = module
	end
	env.ObjectiveTrackerLineFont = B.text(env.UIParent)
	env.ObjectiveTrackerHeaderFont = B.text(env.UIParent)
	env.ObjectiveTrackerLineFont:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	env.ObjectiveTrackerHeaderFont:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
	p.tracker, p.modules = tracker, modules
	return p
end

do
	local B, snap, map, tracker
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			map = WorldMap(env, B)
			tracker = Tracker(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	for _, key in ipairs({ "worldMap", "questLog", "tracker" }) do
		assert(K.Options.Row("Skins", key .. ".enabled"), key .. " has a switch")
	end
	assert(K.Options.Row("Skins", "tracker.font") and K.Options.Row("Skins", "tracker.panel"), "the tracker's own settings")
	K.Modules.Enable("Skins")
	assert(S.Logged(env, "worldMap: waits for Blizzard_WorldMap to load"))
	assert(S.Logged(env, "tracker: waits for Blizzard_ObjectiveTracker to load"))

	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	assert(ns.Skins.IsApplied("tracker"), "the shown tracker is skinned once its addon has loaded")
	local t = tracker.tracker
	assert(Alpha(tracker.nine) == 0, "Blizzard's tracker backdrop goes")
	assert(K.Skin.IsSkinned(t, "Backdrop"), "a glass panel sits behind the tracker")
	assert(Alpha(t.Header.Background) == 0 and Alpha(t.Header.Text) == 0, "the header's art and text go under a KstyleUI caption")
	local module = tracker.modules[1]
	assert(Alpha(module.Header.Background) == 0, "module headers lose their art")
	local holder = module:GetProgressBar("q1")
	assert(Alpha(holder.Bar.BorderLeft) == 0 and Alpha(holder.Bar:GetStatusBarTexture()) == 1, "progress bars keep only their fill")
	assert(W.LastCall(holder.Bar, "SetStatusBarTexture")[1] == Style.BarTexture(), "the bar texture")
	t:AddModule(tracker.extra)
	assert(Alpha(tracker.extra.Header.Background) == 0, "a module added later is skinned too")
	local lineFont = env.ObjectiveTrackerLineFont
	local path, size = lineFont:GetFont()
	assert(path == Style.Font("body") and W.Near(size, 12), "the tracker lines use the skin font at Blizzard's size")
	assert(FontPath(env.ObjectiveTrackerHeaderFont) == Style.Font("heading"))
	lineFont:SetFontObject("ObjectiveTrackerFont16")
	path, size = lineFont:GetFont()
	assert(path == Style.Font("body") and W.Near(size, 16), "Edit Mode's text size keeps the skin font, got " .. tostring(size))
	collectgarbage("collect")
	K.Options.Write("Skins", "text.size", 1.25)
	assert(W.Near(select(2, lineFont:GetFont()), 20), "the text size setting scales the tracker font")
	K.Options.Write("Skins", "tracker.panel", false)
	assert(not K.Skin.Parts(t).backdrop:IsShown(), "the panel switch hides the glass panel")

	S.LoadAddOn(env, "Blizzard_WorldMap")
	S.Show(map.map)
	assert(ns.Skins.IsApplied("worldMap"), "the map is skinned on its first show")
	local m, border = map.map, map.map.BorderFrame
	assert(K.Skin.IsSkinned(m, "Backdrop"), "the glass panel sits on the map frame")
	assert(K.Skin.Parts(m).backdrop:GetFrameLevel() < m.ScrollContainer:GetFrameLevel(), "behind the map canvas")
	assert(not K.Skin.IsSkinned(border, "Backdrop"), "the border frame, which sits above the map, gets no fill")
	assert(Alpha(map.nine) == 0 and Alpha(border.Bg) == 0 and Alpha(border.InsetBorderTop) == 0, "the map's frame art goes")
	assert(K.Skin.IsSkinned(border.CloseButton, "CloseButton") and Alpha(map.minimizeArt) == 0)
	assert(FontPath(border.TitleContainer.TitleText) == Style.Font("heading"))
	assert(Alpha(map.navArt) == 0 and Alpha(map.navOverlay) == 0 and K.Skin.IsSkinned(m.NavBar, "Backdrop"), "the navigation bar sits on a tile")
	assert(K.Skin.Parts(m.NavBar).backdrop.chrome.fillName == "surface", "on the glass surface")
	assert(K.Skin.Parts(m).backdrop.chrome.shapeName == "window", "the map is window-grade glass, as every Blizzard window")
	assert(Alpha(map.homeArt) == 1, "the navigation buttons keep their art")

	S.Show(map.log)
	assert(ns.Skins.IsApplied("questLog"), "the quest log is skinned on its first show")
	local scroll = map.scroll
	assert(Alpha(scroll.Background) == 0 and Alpha(scroll.Edge) == 0 and Alpha(map.logBorder) == 0, "the quest list's art goes")
	assert(K.Skin.Parts(map.log).backdrop.chrome.fillName == "surface", "the quest log is a glass tile, as every list body")
	assert(K.Skin.IsSkinned(scroll.ScrollBar, "ScrollBar") and K.Skin.IsSkinned(scroll.SearchBox, "EditBox"))
	assert(FontPath(map.header.ButtonText) == Style.Font("body") and FontPath(map.title.Text) == Style.Font("body"), "headers and quest titles use the skin font")
	map.titles[#map.titles + 1] = map.lateTitle
	env.QuestLogQuests_Update()
	assert(FontPath(map.lateTitle.Text) == Style.Font("body"), "rows Blizzard shows later are styled after each update")
	local details = map.details
	assert(Alpha(details.Bg) == 1, "the details keep their parchment: Blizzard colours quest text dark for it")
	assert(K.Skin.IsSkinned(details.AbandonButton, "Button") and K.Skin.IsSkinned(details.BackFrame.BackButton, "Button"))
	assert(K.Skin.IsSkinned(details.ScrollFrame.ScrollBar, "ScrollBar"))

	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The tracker's font switch leaves Blizzard's tracker font alone ------------------------------------------

do
	local tracker
	local env, K = S.New({
		loaded = { Blizzard_ObjectiveTracker = true },
		before = function(env)
			tracker = Tracker(env, S.Blizzard(env))
		end,
	})
	K.Options.Write("Skins", "tracker.font", false)
	K.Modules.Enable("Skins")
	assert(FontPath(env.ObjectiveTrackerLineFont) == "Fonts\\FRIZQT__.TTF", "Blizzard's font stays")
	assert(tracker.tracker and #env._errors == 0, tostring(env._errors[1]))
end

print("skins quests ok")
