-- test-groupframes-grid.lua: KSTY-67 items 3, 4 and 21 on the screens Lee judges by (1920x1080 at the 15/16 the game picks there, 3440x1440 and 5120x1440 at the automatic size): party and raid rows, their bars and the raid card on whole physical pixels; the party's percents and the raid's names and percents at the 11 px text floor or over; and class-coloured names lifted to a luminance of 0.62 so the dark class colours read on the card.
local G = dofile("Tools/regression/group_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = dofile("Tools/render/scene.lua")

local SCREENS = { { 1920, 1080, 15 / 16 }, { 3440, 1440, "auto" }, { 5120, 1440, "auto" } }
local CASES = { { "party", 4 }, { "raid", 10 }, { "raid", 20 }, { "raid", 40 } }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local NAME_LUMINANCE = 0.62
local TOLERANCE = 0.01

local function whole(v)
	return math.abs(v - math.floor(v + 0.5)) <= TOLERANCE
end

local function rows(ns, kind)
	local out = {}
	for _, header in ipairs(kind == "party" and { ns.Headers.party } or ns.Headers.raid) do
		local i = 1
		while header._attributes["child" .. i] do
			local button = header._attributes["child" .. i]
			if button._shown and button._attributes.unit then
				out[#out + 1] = ns.Button.Content(button)
			end
			i = i + 1
		end
	end
	return out
end

local previous = rawget(_G, "RENDER_SCREEN")
for _, screen in ipairs(SCREENS) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = screen[3] })
	local perUnit = screen[2] / 1080
	for _, case in ipairs(CASES) do
		local kind, count = case[1], case[2]
		local what = kind .. (kind == "raid" and (" of " .. count) or "") .. " at " .. screen[1] .. "x" .. screen[2]
		local env, K, ns = G.New({ setup = Common.ForceScreen })
		env.SetQuiet(true)
		G.SetRoster(env, kind, G.Members(count, function(i, m)
			m.class = CLASSES[(i - 1) % #CLASSES + 1]
			m.health = 64
		end))
		assert(K.Modules.Enable("GroupFrames"))
		env.RunTimers()
		local floor = K.Scale.TextFloor()
		local function px(text)
			local _, size = text:GetFont()
			return size * K.Widgets.ScaleFactor(text:GetParent()) / K.Scale.Pixel(1)
		end
		local function onGrid(region, label)
			local x, y, w, h = Scene.Rect(env, region)
			assert(x, what .. ": " .. label .. " resolves")
			for side, v in pairs({ left = x, top = y, right = x + w, bottom = y + h }) do
				assert(whole(v * perUnit), string.format("%s: %s's %s edge is on a whole pixel, got %.3f", what, label, side, v * perUnit))
			end
		end
		local shown = rows(ns, kind)
		assert(#shown >= count, what .. ": every member has a row, got " .. #shown)
		for _, f in ipairs(shown) do
			local label = f.unit
			onGrid(f, label)
			onGrid(f.health, label .. "'s bar")
			if f.showPower then
				onGrid(f.power, label .. "'s power line")
			end
			if f.healthText:IsShown() then
				assert(px(f.healthText) >= floor - TOLERANCE, string.format("%s: %s's percent is %.2f px, under the %d px floor", what, label, px(f.healthText), floor))
			end
			if kind == "raid" then
				assert(px(f.name) >= floor - TOLERANCE, string.format("%s: %s's name is %.2f px, under the %d px floor", what, label, px(f.name), floor))
			end
			local _, class = env.UnitClass(f.unit)
			local r, g, b = f.name:GetTextColor()
			local cr, cg, cb = K.Theme.ClassColorForWidget(class)
			local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
			assert(luminance >= NAME_LUMINANCE - 1e-6, string.format("%s: %s's %s name reads on the card, luminance %.3f", what, label, class, luminance))
			assert(r >= cr - 1e-6 and g >= cg - 1e-6 and b >= cb - 1e-6, what .. ": " .. class .. " only moves towards white")
		end
		if kind == "raid" then
			onGrid(ns.Headers.cards.raid.frame, "the raid card")
		end
		assert(#env._errors == 0, what .. ": " .. tostring(env._errors[1]))
		collectgarbage()
	end
end
rawset(_G, "RENDER_SCREEN", previous)

print("groupframes grid ok")
