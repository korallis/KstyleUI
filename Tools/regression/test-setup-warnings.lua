-- test-setup-warnings.lua: Apply puts Forever's raid and boss warnings (RaidWarningFrame, an Edit Mode system) in the upper band where Blizzard, DBM and BigWigs put warnings, above the fight and off the nameplates that draw over the characters (round 6, Opus #3): the highest free band near 15% under the top, between the rails, centred when the centre is free, clear of the story slot and every element the layout shows, at every layout, screen, scale and HUD style, with Orbs' top-centre target and its cast bar a cluster gap clear (KSTY-67 item 2), and a live style switch moves the warnings Apply placed.
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
-- In Orbs the target heads the screen, so the warnings hang under it, between the group cards on the left and the boss
-- column under the target's right end. Where those leave less than the lane and a tight 4-unit gap each side (Healer's
-- wider raid card on a 16:9 root about 1950 units wide or less), the warnings cross the group card's right end: the
-- target, its cast bar and the boss frames stay clear (KSTY-67 item 2, a decision recorded for the Captain).
local GROUPS, SIDE = { ["groupframes.party"] = true, ["groupframes.raid"] = true }, 4

local SCREENS = {
	{ name = "default" },
	{ name = "the owner's Mac", width = 2383, height = 1540, uiScale = 768 / 1080, size = "default" },
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
	frame:SetSize(width and width(k) or K.Setup.EditMode.WARNING_LANE * k, HEIGHT)
	if screen.arrangement then
		K.Options.Write("Layout", "arrangement", screen.arrangement)
	end
	return env, K
end

-- Cluster(K, name) -> the Orbs target as drawn at its own place and size, the bar-form target's cast, which stands at the
-- target cast bar's place under it whether or not that element is on, and the target of target, as root rects.
local function Cluster(K, name)
	local Layouts = K.Setup.Layouts
	local rw, rh = K.Layout.RootSize()
	local positions = Layouts.Positions(name, "orbs", K.Scale.Aspect(), K.Scale.Band())
	local out = {}
	for _, key in ipairs({ "unitframes.target", "unitframes.castbar.target", "unitframes.targettarget" }) do
		local place = positions[key]
		local w, h = Layouts.Footprint(name, key)
		local l, b, r, t = Layouts.Rect({ width = place.width or w, height = place.height or h }, place, rw, rh)
		out[key] = { l = l, b = b, r = r, t = t }
	end
	return out
end

-- Rects(K, name, style) -> the root rect of every element the style's layout places, and its story cards.
local function Rects(K, name, style)
	local Layouts = K.Setup.Layouts
	local rw, rh = K.Layout.RootSize()
	local positions = Layouts.Positions(name, style, K.Scale.Aspect(), K.Scale.Band())
	local boxes = {}
	for key, place in pairs(positions) do
		local w, h, offsetX = Layouts.Footprint(name, key)
		if w and Layouts.Shown(name, key) ~= false then
			local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, place, rw, rh)
			boxes[key] = { l = l, b = b, r = r, t = t }
		end
	end
	local story = Layouts.Story(name, rh, true, style)
	local gl, gb, gr, gt = Layouts.Rect(story.guide, story.guide, rw, rh)
	return boxes, { l = gl, b = gb, r = gr, t = gt }
end

local function Overlap(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

-- Both HUD styles. Frames stands the target low, so the warnings hang over it; Orbs heads the screen with the target and
-- its cast bar (KSTY-67 item 2), so the warnings hang a cluster gap under or beside them, still in the upper band.
for _, style in ipairs({ "frames", "orbs" }) do
	for _, screen in ipairs(SCREENS) do
		for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
			local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
			local env, K = Boot(state, screen)
			assert(K.Setup.Apply({ layout = name, modules = {}, hudStyle = style }))
			local where = name .. " in " .. style .. " on " .. screen.name
			local entry = Find(Named(state, "KstyleUI " .. name), RAID_WARNING)
			local a = entry.anchorInfo
			assert(a.point == "TOP" and a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", where .. ": the warnings hang from their top, measured from the screen's bottom left")
			assert(entry.isInDefaultPosition == false, where .. ": they leave Blizzard's default place")
			local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
			local rw, rh = K.Layout.RootSize()
			local half = K.Setup.EditMode.WARNING_LANE / 2
			local x = (a.offsetX - K.Scale.Origin() * k) / k
			local lane = { l = x - half, r = x + half, t = a.offsetY / k }
			lane.b = lane.t - HEIGHT / k
			assert(lane.t <= rh, where .. ": the warnings stay on the screen")
			local boxes, guide = Rects(K, name, style)
			local sigil = boxes["unitframes.target"]
			if style == "frames" then
				assert(lane.b > sigil.t, where .. ": the warnings sit above the target, never on it")
			else
				for key, box in pairs(Cluster(K, name)) do
					assert(not Overlap(lane, { l = box.l - 16, r = box.r + 16, b = box.b - 16, t = box.t + 16 }), where .. ": the warnings stand a cluster gap clear of " .. key .. " at the top")
				end
			end
			-- The left rail's widest card is the chat card (owner pass 1); the right rail's column is the guide card's.
			assert(lane.l > boxes["chat.main"].r and lane.r < guide.l, where .. ": the warnings stay between the rails")
			local centred = { l = rw / 2 - half, r = rw / 2 + half, b = lane.b, t = lane.t }
			local free = true
			for key, box in pairs(boxes) do
				if not PASSING[key] and Overlap(centred, { l = box.l - 16, r = box.r + 16, b = box.b - 16, t = box.t + 16 }) then
					free = false
				end
			end
			for _, box in pairs(style == "orbs" and Cluster(K, name) or {}) do
				if Overlap(centred, { l = box.l - 16, r = box.r + 16, b = box.b - 16, t = box.t + 16 }) then
					free = false
				end
			end
			if free then
				assert(math.abs((lane.l + lane.r) / 2 - rw / 2) < 0.6, where .. ": the centre is free, so the warnings are centred")
			end
			assert(not Overlap(lane, guide), where .. ": the warnings clear the guide's card")
			for key, box in pairs(boxes) do
				if GROUPS[key] and Overlap(lane, box) then
					local room = boxes["unitframes.boss"].l - box.r
					assert(style == "orbs" and room < 2 * half + 2 * SIDE, where .. ": the warnings cross " .. key .. " only in Orbs when the group card and the boss column leave less than the lane between them, got " .. room)
				elseif not PASSING[key] then
					assert(not Overlap(lane, box), where .. ": the warnings clear " .. key)
				end
			end
			assert(lane.t >= rh * (1 - UPPER), where .. ": the warnings sit in the upper band, their top " .. math.floor(rh - lane.t) .. " units under the screen's top of " .. rh)
			assert(lane.t <= rh - MARGIN, where .. ": the warnings keep the top margin")
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
end

-- A live HUD style switch moves the warnings Apply placed to the new style's lane, as a fresh Apply in that style puts
-- them, and back; warnings the player moved in Edit Mode stay where they are.
for _, screen in ipairs({ SCREENS[4], SCREENS[5] }) do
	local function Anchor(style)
		local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
		local _, K = Boot(state, screen)
		assert(K.Setup.Apply({ layout = "DPS", modules = {}, hudStyle = style }))
		local a = Find(Named(state, "KstyleUI DPS"), RAID_WARNING).anchorInfo
		return a.offsetX, a.offsetY
	end
	local fx, fy = Anchor("frames")
	local ox, oy = Anchor("orbs")
	assert(math.abs(fx - ox) + math.abs(fy - oy) > 1, screen.name .. ": the two styles give the warnings different lanes")
	local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
	local env, K = Boot(state, screen)
	assert(K.Setup.Apply({ layout = "DPS", modules = {}, hudStyle = "frames" }))
	local function Now()
		local a = Find(Named(state, "KstyleUI DPS"), RAID_WARNING).anchorInfo
		return a.offsetX, a.offsetY
	end
	K.Options.Write("HudStyle", "style", "orbs")
	local x, y = Now()
	assert(math.abs(x - ox) < 0.01 and math.abs(y - oy) < 0.01, screen.name .. ": a switch to Orbs moves the warnings to the Orbs lane, got " .. x .. ", " .. y .. " for " .. ox .. ", " .. oy)
	K.Options.Write("HudStyle", "style", "frames")
	x, y = Now()
	assert(math.abs(x - fx) < 0.01 and math.abs(y - fy) < 0.01, screen.name .. ": and back to the Frames lane")
	local entry = Find(Named(state, "KstyleUI DPS"), RAID_WARNING)
	entry.anchorInfo.offsetY = entry.anchorInfo.offsetY - 40
	K.Options.Write("HudStyle", "style", "orbs")
	x, y = Now()
	assert(math.abs(x - fx) < 0.01 and math.abs(y - (fy - 40)) < 0.01, screen.name .. ": warnings the player moved stay where they put them")
	assert(#env._errors == 0, tostring(env._errors[1]))
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
			local rw, rh = K.Layout.RootSize()
			local a = entry.anchorInfo
			local lane = { l = (a.offsetX - 400) / k, r = (a.offsetX + 400) / k, t = a.offsetY / k }
			lane.b = lane.t - HEIGHT / k
			local Layouts = K.Setup.Layouts
			for key in pairs(Layouts.Get(name)) do
				if not PASSING[key] and Layouts.Shown(name, key) ~= false then
					local w, h = Layouts.Footprint(name, key)
					local l, b, r, t = Layouts.Rect({ width = w, height = h }, Layouts.Get(name, rh)[key], rw, rh)
					assert(not Overlap(lane, { l = l, b = b, r = r, t = t }), where .. ": Blizzard's full width clears " .. key)
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

print("test-setup-warnings: ok")
