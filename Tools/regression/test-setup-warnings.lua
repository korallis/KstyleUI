-- test-setup-warnings.lua: Apply puts Forever's raid and boss warnings (RaidWarningFrame, an Edit Mode system) in the upper band where Blizzard, DBM and BigWigs put warnings, above the fight and off the nameplates that draw over the characters (round 6, Opus #3): the highest free band near 15% under the top, between the rails, centred when the centre is free, clear of the story slot and every element the Medallions layout shows, at every layout, screen and scale.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local Install, Modern, Find, Named = EditModeFake.Install, EditModeFake.Modern, EditModeFake.Find, EditModeFake.Named
local RAID_WARNING, ACCOUNT = EditModeFake.RAID_WARNING, EditModeFake.ACCOUNT

-- RaidWarning.lua sets the frame's height to five 20-unit lines, in UIParent's units; the skin narrows it to the lane.
local HEIGHT = 100
-- The lane's top lies in the upper 35% of the screen, and at least the top margin under the screen's edge.
local UPPER, MARGIN = 0.35, 28
-- Your combat text is passing text like the warnings, so the warnings may cross it, as they cross the quest card
-- (Captain, KSTY-64): it holds the centre beside the cast since the Frames quest column runs to the cluster top.
local PASSING = { ["combattext.player"] = true }
local SCREENS = {
	{ name = "default" },
	{ name = "1920x1080 shipped", width = 1920, height = 1080, uiScale = 768 / 1080, size = "default" },
	{ name = "the owner's Mac", width = 2383, height = 1540, uiScale = 768 / 1080, size = "default" },
	{ name = "3456x2234", width = 3456, height = 2234, uiScale = 768 / 1080, size = "default" },
	{ name = "3024x1964", width = 3024, height = 1964, uiScale = 768 / 1080, size = "default" },
	{ name = "2560x1600", width = 2560, height = 1600, uiScale = 768 / 1080, size = "default" },
	{ name = "21:9", width = 3440, height = 1440, uiScale = 0.8 },
	{ name = "1080p", width = 1920, height = 1080, uiScale = 1 },
	{ name = "5120x1440", width = 5120, height = 1440, uiScale = 1 },
	{ name = "5120x1440 spread", width = 5120, height = 1440, uiScale = 1, arrangement = "spread" },
}

-- Boot(state, screen, width): width is RaidWarningFrame's width in UIParent's units, a function of the root factor k:
-- the skin's lane by default (the skin narrows the frame when the module starts, before Apply), nil for Blizzard's 800.
local function Boot(state, screen, width)
	local opts = { boot = false, setup = function(env)
		Install(env, state)
	end }
	for key, value in pairs(screen) do
		if key ~= "name" and key ~= "arrangement" then
			opts[key] = value
		end
	end
	local env, K = W.New(opts)
	CoreEnv.Boot(env)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local frame = env.CreateFrame("Frame", "RaidWarningFrame", env.UIParent)
	env.RaidWarningFrame = frame
	frame:SetSize(width and width(k) or K.Setup.EditMode.WarningLane() * k, HEIGHT)
	if screen.arrangement then
		K.Options.Write("Layout", "arrangement", screen.arrangement)
	end
	return env, K
end

-- Rects(K, name) -> the root rect of every element the Medallions layout places, as Edit Mode measures it, and its story cards.
-- The boss column counts the debuff row its cards hang to their left: the aura room the layouts reserve for it.
local function Rects(K, name)
	local Layouts = K.Setup.Layouts
	local rw, rh = K.Layout.RootSize()
	local positions = Layouts.Positions(name, "medallions", K.Scale.Aspect(), K.Scale.Band())
	local boxes = {}
	for key, place in pairs(positions) do
		local w, h, offsetX = Layouts.Footprint(name, key)
		local styled = Layouts.Style(name, key)
		if styled and styled.width then
			local boss = key == "unitframes.boss" and Layouts.Element(key)
			w, h, offsetX = styled.width + (boss and boss.reserve[1] - boss.width or 0), styled.height, nil
		end
		if w and Layouts.Shown(name, key) ~= false then
			local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, place, rw, rh)
			boxes[key] = { l = l, b = b, r = r, t = t }
		end
	end
	local story = Layouts.Story(name, rh, true, rw)
	local gl, gb, gr, gt = Layouts.Rect(story.guide, story.guide, rw, rh)
	return boxes, { l = gl, b = gb, r = gr, t = gt }
end

local function Overlap(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

-- The Medallions target stands low in the cluster, so the warnings hang over it.
for _, screen in ipairs(SCREENS) do
	for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
		local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
		local env, K = Boot(state, screen)
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local where = name .. " on " .. screen.name
		local entry = Find(Named(state, "KstyleUI " .. name), RAID_WARNING)
		local a = entry.anchorInfo
		assert(a.point == "TOP" and a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", where .. ": the warnings hang from their top, measured from the screen's bottom left")
		assert(entry.isInDefaultPosition == false, where .. ": they leave Blizzard's default place")
		local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
		local rw, rh = K.Layout.RootSize()
		local half = env.RaidWarningFrame:GetWidth() / k / 2
		local x = (a.offsetX - K.Scale.Origin() * k) / k
		local lane = { l = x - half, r = x + half, t = a.offsetY / k }
		lane.b = lane.t - HEIGHT / k
		assert(lane.t <= rh, where .. ": the warnings stay on the screen")
		local boxes, guide = Rects(K, name)
		assert(lane.b > boxes["unitframes.target"].t, where .. ": the warnings sit above the target, never on it")
		-- The left rail's widest card is the chat card (owner pass 1); the right rail starts at the minimap.
		assert(lane.l > boxes["chat.main"].r and lane.r < boxes["minimap.main"].l, where .. ": the warnings stay between the rails")
		local centred = { l = rw / 2 - half, r = rw / 2 + half, b = lane.b, t = lane.t }
		local free = true
		for key, box in pairs(boxes) do
			if not PASSING[key] and Overlap(centred, { l = box.l - 16, r = box.r + 16, b = box.b - 16, t = box.t + 16 }) then
				free = false
			end
		end
		if free then
			assert(math.abs((lane.l + lane.r) / 2 - rw / 2) < 0.6, where .. ": the centre is free, so the warnings are centred")
		end
		assert(not Overlap(lane, guide), where .. ": the warnings clear the guide's card")
		for key, box in pairs(boxes) do
			if not PASSING[key] then
				assert(not Overlap(lane, box), where .. ": the warnings clear " .. key)
			end
		end
		assert(lane.t >= rh * (1 - UPPER), where .. ": the warnings sit in the upper band, their top " .. math.floor(rh - lane.t) .. " units under the screen's top of " .. rh)
		assert(lane.t <= rh - MARGIN, where .. ": the warnings keep the top margin")
		assert(screen.name ~= "1920x1080 shipped" or lane.t >= rh * 0.85 - 0.5, where .. ": at 16:9 and the shipped size the warnings stand at the top of the band, beside the raid frames, " .. math.floor(rh - lane.t) .. " units under the screen's top")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- With the skin off the frame keeps Blizzard's 800 units: Apply reserves that width, so it either finds a band that
-- clears everything at 800 or leaves the warnings where the copied layout had them.
for _, screen in ipairs(SCREENS) do
	for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
		local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
		local env, K = Boot(state, screen, function()
			return 800
		end)
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local where = name .. " on " .. screen.name .. ", unskinned"
		local entry = Find(Named(state, "KstyleUI " .. name), RAID_WARNING)
		if not entry.isInDefaultPosition then
			local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
			local a = entry.anchorInfo
			local lane = { l = (a.offsetX - 400) / k, r = (a.offsetX + 400) / k, t = a.offsetY / k }
			lane.b = lane.t - HEIGHT / k
			for key, box in pairs((Rects(K, name))) do
				if not PASSING[key] then
					assert(not Overlap(lane, box), where .. ": Blizzard's full width clears " .. key)
				end
			end
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- A client whose Edit Mode has no RaidWarning system gets nothing written for it.
do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, { name = "no system" })
	env.Enum.EditModeSystem.RaidWarning = nil
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(Find(Named(state, "KstyleUI DPS"), RAID_WARNING).isInDefaultPosition == true, "without the enum the warnings keep the copied place")
end

-- The lane resolves only the three cards it measures in each preset, not every element (review of 875a06f7: 405).
do
	local _, K = Boot({ saved = {}, active = 1 }, SCREENS[4])
	local place, count = K.Setup.Layouts.Place, 0
	K.Setup.Layouts.Place = function(...)
		count = count + 1
		return place(...)
	end
	assert(K.Setup.EditMode.WarningLane() == 443 and count <= 9, "the 3:2 lane takes " .. count .. " element lookups")
	K.Setup.Layouts.Place = place
end

print("test-setup-warnings: ok")
