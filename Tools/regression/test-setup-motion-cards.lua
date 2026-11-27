-- test-setup-motion-cards.lua: with Motion on and client animations that never step from before the window opens, the HUD style and layout cards draw their title, note and edge with the accent painted on the pick, and Your addons draws its controls, with valid rects, on its first open as on a reopen.
local Suite = dofile("Tools/regression/suite_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Fake = dofile("Tools/regression/addons_fake.lua")

local env, K = Suite.New({ version = 42, profiles = { Default = {} }, characters = {}, account = { setupSeen = true } }, 2560, 1440, Fake.Install)
K.Motion.SetLevel("full")
env._stalled = true
assert(K.Setup.Open(true))
local panel = K.Setup.window
local accent = { K.Widgets.Rgba("accent") }

local function Settle()
	env.RunTimers(); W.Settle(env); env.RunTimers()
end

-- Drawn(region, what): shown at an effective opacity, its own alpha times every parent's, above 0.
local function Drawn(region, what)
	assert(region:IsVisible() and region:GetEffectiveAlpha() > 0, what .. " draws with no animation stepped; show the setup window and its pages without a fade they depend on")
end

local function Cards(cards, value, what)
	for key, card in pairs(cards) do
		local label = what .. ": the " .. key .. " card"
		for _, text in ipairs({ card.title, card.note }) do
			Drawn(text, label .. "'s title and note")
			assert((text:GetText() or "") ~= "", label .. " has its title and note")
		end
		local rim = card.chrome.rim
		assert(not rim.pending, label .. " builds its edge")
		for i = 1, 9 do
			if i ~= 5 then
				Drawn(rim[i], label .. "'s edge piece " .. i)
				local lit = W.SameColor(rim[i], accent[1], accent[2], accent[3], accent[4])
				assert(lit == (key == value), label .. (lit and " paints" or " does not paint") .. " its edge accent with " .. value .. " picked")
			end
		end
	end
end

local function Pick(cards, order, field, what)
	Cards(cards, K.Setup.Choice()[field], what .. " on arrival")
	for _, value in ipairs(order) do
		W.Click(cards[value])
		Cards(cards, value, what .. ", " .. value .. " just picked")
		Settle()
		Cards(cards, value, what .. ", " .. value .. " picked")
	end
end

Settle()
W.Click(panel.next)
Pick(panel.styleCards, { "frames", "medallions" }, "hudStyle", "HUD style step")
W.Click(panel.next)
Pick(panel.cards, { "DPS", "Tank", "Healer" }, "layout", "layout step")

-- Snapshot(frame): every shown region under frame with its effective alpha and rect.
local function Snapshot(frame, into)
	into = into or {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsVisible() then
			into[#into + 1] = table.concat({ tostring(region:GetEffectiveAlpha()), tostring(region:GetLeft()), tostring(region:GetBottom()), tostring(region:GetWidth()), tostring(region:GetHeight()) }, " ")
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsVisible() then Snapshot(child, into) end
	end
	return into
end

W.Click(panel.next)
W.Click(panel.next)
assert(K.Setup.Step() == 5, "the fifth step is Your addons")
local page = panel.addonsPage
local tracker = panel.addons.groups.Questie.items["Integrations.questTracker"].control
Drawn(tracker, "On Your addons' first open, Questie's quest tracker dropdown")
Drawn(tracker.text, "On Your addons' first open, Questie's quest tracker choice")
assert(tracker:GetWidth() > 0 and tracker:GetHeight() > 0, "Questie's quest tracker dropdown has a size on the first open")
-- The owner's in-game reading (2026-11-27): built while the page was hidden, these textures read IsRectValid false on
-- the first open and were not drawn, leaving each switch a half stub and the dropdown without its arrow and text.
assert(tracker.chevron:IsRectValid(), "On Your addons' first open, Questie's quest tracker arrow has a valid rect; lay the page out again when it shows")
for _, group in ipairs(panel.addons.active) do
	for _, item in ipairs(group.active) do
		local name, knob, track = item.row.module .. "." .. item.row.key, item.control.knob, item.control.trackBox
		Drawn(item.control, "On Your addons' first open, " .. name)
		if knob then
			Drawn(knob, "On Your addons' first open, the knob of " .. name)
			assert(knob:IsRectValid() and item.control.track[3]:IsRectValid(), "On Your addons' first open, the knob and right end of " .. name .. " have valid rects; lay the page out again when it shows")
			assert(knob:GetWidth() > 0 and knob:GetLeft() >= track:GetLeft() and knob:GetRight() <= track:GetRight()
				and knob:GetBottom() >= track:GetBottom() and knob:GetTop() <= track:GetTop(), "On Your addons' first open, the knob of " .. name .. " sits inside its track")
		end
	end
end
Settle()
local first = Snapshot(page)
W.Click(panel.back)
W.Click(panel.next)
Settle()
assert(table.concat(first, "|") == table.concat(Snapshot(page), "|"), "Your addons draws the same on its first open as on a reopen")
assert(#env._errors == 0, tostring(env._errors[1]))
print("setup motion cards ok")
