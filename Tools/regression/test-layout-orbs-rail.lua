-- test-layout-orbs-rail.lua: the Orbs right rail (KSTY-60 item 8, the KSTY-44 mock-up A): the quest card and the RestedXP
-- guide's card stand in one column under the minimap, quests above the guide, with the readout and the damage card under
-- them, for every preset, layout class and arrangement, clear of every other element, while Frames keeps them side by side;
-- live, the guide hangs a rail gap under the quest card's own foot, and a live style switch lays the rail as a login does.
local W = dofile("Tools/regression/widget_env.lua")
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local RAIL = {
	["skins.quests"] = true, ["skins.guide"] = true, ["actionbars.bar4"] = true, ["actionbars.bar5"] = true, ["actionbars.bar6"] = true,
	["databars.micro"] = true, ["databars.bags"] = true, ["tooltips.anchor"] = true,
}
local DOCKED = { ["databars.micro"] = "databars.strip", ["databars.bags"] = "databars.strip" }
local SCREENS = {
	{ 1920, 1080 }, { 2560, 1600 }, { 3456, 2234 }, { 1280, 720 }, { 2560, 1080 }, { 3440, 1440 }, { 3840, 1080 }, { 5120, 1440 },
}

-- The tables: one column at each screen, preset and arrangement, at the shipped and whole-unit Interface sizes and the
-- largest size the layout allows there, the quests no taller than the mock-up's card and neither card under the story
-- floor; clear of everything at the shipped size (at larger sizes the Orbs centre already crowds the rails).
do
	local _, K = W.New()
	local Layouts = K.Setup.Layouts
	local gap = Layouts.STORY_GAP
	local cases = 0
	for _, screen in ipairs(SCREENS) do
		local width, height = screen[1], screen[2]
		for _, arrangement in ipairs({ "centred", "spread" }) do
			local physical = arrangement == "spread" and width or math.min(width, math.floor(height * 12 / 5 + 0.5))
			local class = K.Scale.AspectClass(physical, height)
			local largest = 1.5
			while largest > 0.6 and not Layouts.Fits("DPS", physical, height, largest) do
				largest = largest - 0.01
			end
			for _, user in ipairs({ K.Scale.DEFAULT_USER_SCALE, 1, largest }) do
				local rh = 1080 / user
				local rw = rh * physical / height
				local px = rh / height
				for _, name in ipairs(Layouts.Names()) do
					local what = string.format("%s %dx%d %s at %.3f", name, width, height, arrangement, user)
					local story = Layouts.Story(name, rh, true, "orbs")
					assert(story.stacked, what .. ": Orbs stacks the story cards")
					local q, g = story.quests, story.guide
					local ql, qb, qr, qt = Layouts.Rect(q, q, rw, rh)
					local gl, gb, gr, gt = Layouts.Rect(g, g, rw, rh)
					assert(math.abs(ql - gl) < 1e-6 and math.abs(qr - gr) < 1e-6, what .. ": the guide shares the quest card's column")
					assert(math.abs(qb - gt - gap) < 1e-6, what .. ": the guide stands a rail gap under the quest card")
					local mapPlace = Layouts.Place(name, "orbs", class, "minimap.main")
					local mw, mh = Layouts.Footprint(name, "minimap.main")
					local _, mb, mr = Layouts.Rect({ width = mw, height = mh }, mapPlace, rw, rh)
					assert(qt < mb and math.abs(qr - mr) <= 1 + px, what .. ": the column hangs under the minimap, on its right edge")
					assert(q.height <= 268 * 19 / 16 + 1e-6 and g.height >= q.height - 1e-6 and q.height >= Layouts.STORY_FLOOR, what .. ": the quest card keeps the mock-up's height at most, the guide at least as much, both over the story floor, got " .. q.height .. " and " .. g.height)
					local positions = Layouts.Positions(name, "orbs", class)
					local enabled = Layouts.Enabled(name)
					local rects = {}
					for _, element in ipairs(user == K.Scale.DEFAULT_USER_SCALE and Layouts.ELEMENTS or {}) do
						local key = element.key
						if enabled[key] ~= false or RAIL[key] then
							local w, h, offsetX = Layouts.Footprint(name, key)
							local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, positions[key], rw, rh)
							rects[#rects + 1] = { key = key, l = l, b = b, r = r, t = t }
						end
					end
					rects[#rects + 1] = { key = q.key, l = ql, b = qb, r = qr, t = qt }
					rects[#rects + 1] = { key = g.key, l = gl, b = gb, r = gr, t = gt }
					for i, a in ipairs(rects) do
						if RAIL[a.key] then
							assert(a.l >= -px and a.b >= -px and a.r <= rw + px and a.t <= rh + px, what .. ": " .. a.key .. " stays on the root")
							for j, b in ipairs(rects) do
								local docked = DOCKED[a.key] == b.key or DOCKED[b.key] == a.key
								if i ~= j and not docked then
									local across = math.min(a.r, b.r) - math.max(a.l, b.l)
									local up = math.min(a.t, b.t) - math.max(a.b, b.b)
									assert(across <= px or up <= px, string.format("%s: %s and %s cross by %.1f by %.1f units", what, a.key, b.key, across, up))
								end
							end
						end
					end
					local frames = Layouts.Story(name, rh, true)
					assert(not frames.stacked and frames.quests.x < frames.guide.x and frames.quests.y == frames.guide.y, what .. ": Frames keeps the cards side by side")
					cases = cases + 1
				end
			end
		end
	end
	assert(cases == #SCREENS * 2 * 3 * 3)
	for _, name in ipairs(Layouts.Names()) do
		for key in pairs({ ["skins.quests"] = true, ["skins.guide"] = true }) do
			assert(Layouts.Style("orbs", name, key), name .. ": Orbs places " .. key)
			assert(Layouts.Style("frames", name, key) == nil, name .. ": Frames has no style table for " .. key)
		end
	end
end

-- KSTY-60 item 28: under Orbs, Blizzard's tracked buff icons (the cooldowns.buffs slot Apply hands Edit Mode, its icons
-- right-aligned on the slot's right edge) end where the player's buff row ends, over the health orb, so the two read as
-- one group of the player's auras instead of a pair standing off the row.
do
	local _, K = W.New()
	local Layouts = K.Setup.Layouts
	local tw, bw = Layouts.Element("cooldowns.buffs").width, Layouts.Element("auras.buffs").width
	for _, name in ipairs(Layouts.Names()) do
		local tracked, buffs = Layouts.Style("orbs", name, "cooldowns.buffs"), Layouts.Style("orbs", name, "auras.buffs")
		assert(tracked.anchor == buffs.anchor and math.abs(tracked.x + tw / 2 - (buffs.x + bw / 2)) < 1e-6, name .. ": the tracked buffs end where the buff row ends, " .. (tracked.x + tw / 2) .. " against " .. (buffs.x + bw / 2))
		assert(tracked.y > buffs.y, name .. ": above it")
	end
end

-- Live: the cards follow the tables, the guide hangs a rail gap under the quest card's foot, and a switch equals a login.
local function Boot(screen, style)
	local rxp
	local saved = { version = 12, profiles = { Default = { Appearance = { uiScale = 16 / 19 }, Layout = { preset = "DPS" }, HudStyle = { style = style } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = S.New({
		width = screen[1], height = screen[2], saved = saved,
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(3))
			rxp = Fake.Install(e, {})
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.SetStep()
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns, rxp
end

local function Cards(K, ns, rxp)
	local root = K.Scale.Root()
	local card = Geometry.ScaledRect(ns.Quests.Card(), root._env.UIParent, root)
	local guide = Geometry.ScaledRect(K.Skin.Parts(rxp.RXPFrame).backdrop, root._env.UIParent, root)
	return card, guide
end

for _, screen in ipairs({ { 1920, 1080 }, { 3440, 1440 }, { 5120, 1440 } }) do
	local what = screen[1] .. "x" .. screen[2]
	local env, K, ns, rxp = Boot(screen, "orbs")
	local px = K.Scale.Pixel(1) + 0.01
	local gap = K.Setup.Layouts.STORY_GAP
	local card, guide = Cards(K, ns, rxp)
	assert(math.abs(card.left - guide.left) <= px and math.abs(card.right - guide.right) <= px, what .. ": one column, got " .. card.left .. " and " .. guide.left)
	assert(math.abs(card.bottom - guide.top - gap) <= 2 * px, what .. ": the guide hangs a rail gap under the quest card's foot, got " .. (card.bottom - guide.top))
	local story = K.Setup.Story("DPS", true)
	assert(story.stacked and card.top <= story.tracker.top + px and guide.bottom >= story.guide.bottom - px, what .. ": both cards stay in the column")
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))

	local liveEnv, liveK, liveNs, liveRxp = Boot(screen, "frames")
	local frameCard, frameGuide = Cards(liveK, liveNs, liveRxp)
	assert(frameCard.right < frameGuide.left, what .. ": Frames keeps the quests beside the guide")
	liveK.Options.Write("HudStyle", "style", "orbs")
	liveEnv.RunTimers()
	S.W.Settle(liveEnv)
	local liveCard, liveGuide = Cards(liveK, liveNs, liveRxp)
	for _, side in ipairs({ "left", "right", "top", "bottom" }) do
		assert(math.abs(liveCard[side] - card[side]) <= px, what .. ": a live switch puts the quest card's " .. side .. " where a login does")
		assert(math.abs(liveGuide[side] - guide[side]) <= px, what .. ": a live switch puts the guide's " .. side .. " where a login does, got " .. liveGuide[side] .. " for " .. guide[side])
	end
	liveK.Options.Write("HudStyle", "style", "frames")
	liveEnv.RunTimers()
	S.W.Settle(liveEnv)
	local backCard, backGuide = Cards(liveK, liveNs, liveRxp)
	assert(math.abs(backCard.left - frameCard.left) <= px and math.abs(backGuide.top - frameGuide.top) <= px, what .. ": back in Frames the cards stand side by side again")
	assert(#liveEnv._errors == 0 and liveK.ErrorCount() == 0, what .. ": " .. tostring(liveEnv._errors[1]))
end

print("ok layout orbs rail")
