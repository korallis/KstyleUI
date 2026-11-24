-- test-setup-motion-cards.lua: with Motion on and client animations that never step, the HUD style and layout cards keep their title, note and edge with the accent edge on the pick, and Your addons draws on its first open as on a reopen.
local Suite = dofile("Tools/regression/suite_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Fake = dofile("Tools/regression/addons_fake.lua")

local env, K = Suite.New({ version = 42, profiles = { Default = {} }, characters = {}, account = { setupSeen = true } }, 2560, 1440, function(e) Fake.Install(e) end)
K.Motion.SetLevel("full")
assert(K.Setup.Open(true))
W.Settle(env)
local panel = K.Setup.window
env._stalled = true
local accent = { K.Widgets.Rgba("accent") }

local function Settle()
	env.RunTimers(); W.Settle(env); env.RunTimers()
end

local function Cards(cards, value, what)
	for key, card in pairs(cards) do
		local label = what .. ": the " .. key .. " card"
		assert(card:IsVisible() and card:GetEffectiveAlpha() == 1, label .. " draws at full alpha with no animation stepped; show a setup page without a fade")
		for _, text in ipairs({ card.title, card.note }) do
			assert(text:IsVisible() and (text:GetText() or "") ~= "", label .. " shows its title and note")
		end
		assert(not card.chrome.rim.pending and card.chrome.rim[1]:IsVisible(), label .. " draws its edge")
		local edge = card.chrome.edge
		local lit = edge[1] == accent[1] and edge[2] == accent[2] and edge[3] == accent[3] and edge[4] == accent[4]
		assert(lit == (key == value), label .. (lit and " wears" or " lacks") .. " the accent edge with " .. value .. " picked")
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

W.Click(panel.next)
Pick(panel.styleCards, { "frames", "medallions" }, "hudStyle", "HUD style step")
W.Click(panel.next)
Pick(panel.cards, { "DPS", "Tank", "Healer" }, "layout", "layout step")

-- Drawn(frame): every shown region under frame with its effective alpha and rect.
local function Drawn(frame, into)
	into = into or {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsVisible() then
			into[#into + 1] = table.concat({ tostring(region:GetEffectiveAlpha()), tostring(region:GetLeft()), tostring(region:GetBottom()), tostring(region:GetWidth()), tostring(region:GetHeight()) }, " ")
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsVisible() then Drawn(child, into) end
	end
	return into
end

W.Click(panel.next)
W.Click(panel.next)
local page = panel.addonsPage
assert(K.Setup.Step() == 5 and page:IsVisible() and page:GetEffectiveAlpha() == 1, "Your addons draws at full alpha on its first open with no animation stepped")
for _, group in ipairs(panel.addons.active) do
	for _, item in ipairs(group.active) do
		assert(item.control:IsVisible(), "Your addons shows " .. item.row.module .. "." .. item.row.key .. " on its first open")
	end
end
Settle()
local first = Drawn(page)
W.Click(panel.back)
W.Click(panel.next)
Settle()
local again = Drawn(page)
assert(#first == #again, "Your addons draws " .. #first .. " regions on its first open and " .. #again .. " on a reopen")
for i = 1, #first do
	assert(first[i] == again[i], "Your addons region " .. i .. " draws the same on its first open as on a reopen: " .. first[i] .. " vs " .. again[i])
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("setup motion cards ok")
