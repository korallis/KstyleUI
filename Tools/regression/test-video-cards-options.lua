-- test-video-cards-options.lua: the video guide fits its steps, Tasks has useful rows and a preview, and Text previews its own font changes.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local mode = ...

local function Cards(screen)
	local R = Boot({ width = screen[1], height = screen[2], uiScale = 768 / 1080 }, nil, nil, true)
	R.K.Options.Write("Skins", "restedXP.boxes", false)
	R.rxp.targeting.activeTargetFrame:Hide()
	R.rxp.activeItemFrame:Hide()
	R.settle()
	local path = R.ns.RestedXP.Chrome.Path(R.rxp.RXPFrame)
	local guide = R.K.Skin.Parts(R.rxp.RXPFrame).backdrop
	local steps = R.rxp.RXPFrame.CurrentStepFrame
	local function Check()
		local scale = R.K.Widgets.ScaleFactor(steps)
		local glass = G.ScaledRect(guide, R.env.UIParent, R.K.Scale.Root())
		local content = G.ScaledRect(steps, R.env.UIParent, R.K.Scale.Root())
		assert(content.bottom - glass.bottom < 32 * scale, "issue 8: fit the guide to its steps, not the quest card's height")
		assert(glass.top - glass.bottom >= 28 * scale, "issue 8: retain a usable guide minimum")
		local gutter = R.ns.RestedXP.Chrome.Gutter(R.rxp.RXPFrame.BottomFrame)
		assert(not gutter:IsVisible(), "issue 8: a folded step list must hide its one-pixel gutter")
	end
	Check()
	R.rxp.fake.guide({ { index = 97, elements = { { text = "Talk to Carendin in the Magic Quarter" }, { text = "Turn in Halgar's Summons" }, { text = "Accept Creature of the Void" } } } })
	R.rxp.SetStep(1); R.settle(); Check()
	local tall = guide:GetHeight()
	R.rxp.fake.guide({ { index = 98, elements = { { text = "Leave the Magic Quarter" } } } })
	R.rxp.SetStep(1); R.settle(); Check()
	assert(guide:GetHeight() < tall, "issue 8: a shorter step shrinks the card again: " .. tall .. " to " .. guide:GetHeight() .. " steps " .. steps:GetHeight())
	R.K.Options.Write("Skins", "restedXP.fit", false); R.settle()
	assert(guide:GetHeight() > tall, "guide fit Off restores the shared story-card height")
	R.K.Options.Write("Skins", "restedXP.fit", true); R.settle(); Check()
	assert(path and #R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end

local function Options(screen)
	local env, K, ns = O.New({ width = screen[1], height = screen[2], setup = function(e) e._resolveRects = true end })
	local function Settle() env.RunTimers(); O.W.Settle(env); env.RunTimers() end
	K.Options.Open("Tasks"); Settle()
	local parts = ns.Window.Parts()
	if mode ~= "text" then
		assert(parts.preview:IsVisible() and parts.preview.current, "issue 11: Tasks uses the usual preview column")
		local tasks = 0
		for _, item in ipairs(ns.Window.State().items) do
			if item.kind == "task" then
				tasks = tasks + 1
				assert(type(item.help) == "string" and item.help ~= "", "issue 11: explain each task's destination")
			end
		end
		assert(tasks == 6, "issue 11: keep the six existing shortcuts")
	end
	K.Options.Open("General"); Settle()
	for i, item in ipairs(ns.Window.State().items) do
		if item.kind == "header" and item.label == K.L["Text"] then parts.content:ScrollToIndex(i, true, "TOP"); break end
	end
	Settle()
	local sample = parts.preview.current
	assert(sample and sample.body, "issue 12: Text shows typography, even with both boss lanes enabled")
	local shows, show = 0, ns.Preview.Show
	ns.Preview.Show = function(...) shows = shows + 1; return show(...) end
	for i, item in ipairs(ns.Window.State().items) do
		if item.kind == "header" and item.label == K.L["Settings window"] then parts.content:ScrollToIndex(i, true, "TOP"); break end
	end
	Settle()
	assert(shows == 0, "scrolling between sections with the same preview must not refit it")
	ns.Preview.Show = show
	K.Widgets.Size(ns.Window.Frame(), 1800, 1040); ns.Window.Frame():Restyle(); Settle()
	K.Options.Write("OptionsPresentation", "preview", false); Settle()
	local small = sample:GetScale()
	K.Options.Write("OptionsPresentation", "preview", true); Settle()
	assert(sample:GetScale() > small and small <= 1.25, "the typography sample obeys the larger-preview setting: " .. small .. " -> " .. sample:GetScale() .. " room " .. parts.preview.holder:GetWidth() .. " sample " .. sample:GetWidth())
	local face, size = sample.body:GetFont()
	K.Options.Write("Appearance", "fontScale", 1.2); Settle()
	assert(select(2, sample.body:GetFont()) > size, "issue 12: the Text size control changes the sample")
	K.Options.Write("Appearance", "font", K.Tokens.FontPath("InterSemiBold")); Settle()
	assert(sample.body:GetFont() ~= face, "issue 12: the Font control changes the sample")
	for i, item in ipairs(ns.Window.State().items) do
		if item.kind == "header" and item.label == K.L["Existing addons"] then parts.content:ScrollToIndex(i, true, "TOP"); break end
	end
	Settle()
	assert(parts.preview.current ~= sample, "issue 12: Existing addons retains its boss lane preview")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	if mode ~= "options" and mode ~= "text" then Cards(screen) end
	if mode ~= "cards" then Options(screen) end
end
print("video cards and Options ok")
