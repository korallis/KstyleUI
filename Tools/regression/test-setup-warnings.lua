-- test-setup-warnings.lua: Apply puts Forever's raid and boss warnings (RaidWarningFrame, an Edit Mode system) in the upper band where Blizzard, DBM and BigWigs put warnings, above the fight and off the nameplates that draw over the characters (round 6, Opus #3): the highest free band near 15% under the top, between the rails, centred when the centre is free, clear of the story slot and every element the layout shows, at every layout, screen and scale.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local Install, Modern, Find, Named = EditModeFake.Install, EditModeFake.Modern, EditModeFake.Find, EditModeFake.Named
local RAID_WARNING, ACCOUNT = EditModeFake.RAID_WARNING, EditModeFake.ACCOUNT

-- RaidWarning.lua sets the frame's height to five 20-unit lines, in UIParent's units; the skin narrows it to the lane.
local HEIGHT = 100
-- The lane's top lies in the upper 35% of the screen, and at least the top margin under the screen's edge.
local UPPER, MARGIN = 0.35, 28

local SCREENS = {
	{ name = "default" },
	{ name = "the owner's Mac", width = 2383, height = 1540, uiScale = 768 / 1080 },
	{ name = "21:9", width = 3440, height = 1440, uiScale = 0.8 },
	{ name = "1080p", width = 1920, height = 1080, uiScale = 1 },
}

-- Boot(state, screen, width): width is RaidWarningFrame's width in UIParent's units, a function of the root factor k:
-- the skin's lane by default (the skin narrows the frame when the module starts, before Apply), nil for Blizzard's 800.
local function Boot(state, screen, width)
	local opts = { boot = false, setup = function(env)
		Install(env, state)
	end }
	for key, value in pairs(screen) do
		if key ~= "name" then
			opts[key] = value
		end
	end
	local env, K = W.New(opts)
	CoreEnv.Boot(env)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local frame = env.CreateFrame("Frame", "RaidWarningFrame", env.UIParent)
	env.RaidWarningFrame = frame
	frame:SetSize(width and width(k) or K.Setup.EditMode.WARNING_LANE * k, HEIGHT)
	return env, K
end

local function Overlap(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

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
		local half = K.Setup.EditMode.WARNING_LANE / 2
		local lane = { l = a.offsetX / k - half, r = a.offsetX / k + half, t = a.offsetY / k }
		lane.b = lane.t - HEIGHT / k
		assert(lane.t <= rh, where .. ": the warnings stay on the screen")
		local Layouts = K.Setup.Layouts
		local function Box(key)
			local w, h = Layouts.Footprint(name, key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h }, Layouts.Get(name)[key], rw, rh)
			return { l = l, b = b, r = r, t = t }
		end
		local sigil = Box("unitframes.target")
		assert(lane.b > sigil.t, where .. ": the warnings sit above the target, never on it")
		assert(lane.l > Box("chat.main").r and lane.r < Box("minimap.main").l, where .. ": the warnings stay between the rails")
		local centred = { l = rw / 2 - half, r = rw / 2 + half, b = lane.b, t = lane.t }
		local free = true
		for key in pairs(Layouts.Get(name)) do
			if Layouts.Shown(name, key) ~= false then
				local box = Box(key)
				if Overlap(centred, { l = box.l - 16, r = box.r + 16, b = box.b - 16, t = box.t + 16 }) then
					free = false
				end
			end
		end
		if free then
			assert(math.abs((lane.l + lane.r) / 2 - rw / 2) < 0.6, where .. ": the centre is free, so the warnings are centred")
		end
		local slot = Layouts.Slot(name)
		local sl, sb, sr, st = Layouts.Rect(slot, slot, rw, rh)
		assert(not Overlap(lane, { l = sl, b = sb, r = sr, t = st }), where .. ": the warnings clear the story slot")
		for key in pairs(Layouts.Get(name)) do
			if Layouts.Shown(name, key) ~= false then
				assert(not Overlap(lane, Box(key)), where .. ": the warnings clear " .. key)
			end
		end
		assert(lane.t >= rh * (1 - UPPER), where .. ": the warnings sit in the upper band, their top " .. math.floor(rh - lane.t) .. " units under the screen's top of " .. rh)
		assert(lane.t <= rh - MARGIN, where .. ": the warnings keep the top margin")
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
			local rw, rh = K.Layout.RootSize()
			local a = entry.anchorInfo
			local lane = { l = (a.offsetX - 400) / k, r = (a.offsetX + 400) / k, t = a.offsetY / k }
			lane.b = lane.t - HEIGHT / k
			local Layouts = K.Setup.Layouts
			for key in pairs(Layouts.Get(name)) do
				if Layouts.Shown(name, key) ~= false then
					local w, h = Layouts.Footprint(name, key)
					local l, b, r, t = Layouts.Rect({ width = w, height = h }, Layouts.Get(name)[key], rw, rh)
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
