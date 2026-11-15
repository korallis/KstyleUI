-- test-groupframes-medallions-tiles.lua: the Medallions raid tile on the 16:9 CREW screens (1280x720 to 3840x2160; test-groupframes-medallions-tiles-wide.lua has the rest) for 10, 25 and 40 players, healing or not: one class-coloured fill across the tile, the name never overlapping the percent or the debuff pips and shortened rather than run past its lane, every name and percent at the 11 px text floor or over, and no role square.
local G = dofile("Tools/regression/group_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = dofile("Tools/render/scene.lua")

local SCREENS = { { 1280, 720 }, { 1920, 1080, true }, { 2560, 1440 }, { 3840, 2160 } }
local CASES = { { 10, "HEALER" }, { 25, "DAMAGER" }, { 40, "HEALER" } }
local LONG = { "Thaldrenwick", "Brightblades", "Dreadwalkers", "Hammerfeldt", "Kragar", "Ilyra" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local EPS = 0.01
local SAVED = {
	version = 2, profiles = { Default = { GroupFrames = { enabled = true }, HudStyle = { style = "medallions" } } },
	characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
}

local function rows(ns)
	local out = {}
	for _, header in ipairs(ns.Headers.raid) do
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

local function apart(a, b)
	return a[1] + a[3] <= b[1] + EPS or b[1] + b[3] <= a[1] + EPS or a[2] + a[4] <= b[2] + EPS or b[2] + b[4] <= a[2] + EPS
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

local previous = rawget(_G, "RENDER_SCREEN")
local checked = 0
for _, screen in ipairs(SCREENS) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
	local env, K, ns = G.New({ setup = Common.ForceScreen, saved = SAVED })
	env.SetQuiet(true)
	for _, case in ipairs(CASES) do
		local count, role = case[1], case[2]
		local what = "raid of " .. count .. " (" .. role:lower() .. ") at " .. screen[1] .. "x" .. screen[2]
		G.SetRoster(env, "raid", G.Members(count, function(i, m)
			m.name = LONG[(i - 1) % #LONG + 1]
			m.class = CLASSES[(i - 1) % #CLASSES + 1]
			m.health = ({ 100, 64, 23, 8 })[(i - 1) % 4 + 1]
			m.dead = i == 4 or nil
			m.online = i ~= 5 and nil or false
		end), { name = "Valerin", class = "SHAMAN", role = role })
		if not K.Modules.IsRunning("GroupFrames") then
			assert(K.Modules.Enable("GroupFrames"))
		end
		env.RunTimers()
		assert(K.HudStyle.Current() == "medallions", what .. ": the profile opens on Medallions")
		local floor = K.Scale.TextFloor()
		local function px(text)
			local _, size = text:GetFont()
			return size * K.Widgets.ScaleFactor(text:GetParent()) / K.Scale.Pixel(1)
		end
		local drawn = {}
		if screen[3] and count == 10 then
			for _, item in ipairs(Scene.Build(env).items) do
				drawn[item.object] = item.rect
			end
		end
		for _, f in ipairs(rows(ns)) do
			local who = what .. ", " .. tostring(f.rawName) .. " (" .. f.unit .. ")"
			assert(f.parts.tile and f.tileText, who .. ": the Medallions tile is laid out")
			local frame = { Scene.Rect(env, f) }
			local bar = { Scene.Rect(env, f.health) }
			local reach = K.Tokens.Size("gapSmall") + 1
			assert(bar[1] - frame[1] <= reach and frame[1] + frame[3] - (bar[1] + bar[3]) <= reach,
				who .. ": the fill " .. describe(bar) .. " spans the tile " .. describe(frame))
			assert(not f.role:IsShown(), who .. ": no role square")
			assert(px(f.name) >= floor - EPS, who .. ": the name is at the " .. floor .. " px floor or over, got " .. px(f.name))
			local shown = f.name:GetText() or ""
			local _, size = f.name:GetFont()
			local width = ns.Names.Width(f.name, shown, size)
			assert(width <= f.nameWidth + f.nameFit.slack + EPS, who .. ": " .. shown .. " is " .. width .. " units in a " .. f.nameWidth .. " unit lane")
			local text = f.tileText
			local top = text.stacked and 0 or 1
			local name = drawn[f.name] or { text.left, top, width, 1 }
			if f.healthText:IsShown() and (f.healthText:GetText() or "") ~= "" then
				assert(px(f.healthText) >= floor - EPS, who .. ": the percent is at the floor or over")
				local _, textSize = f.healthText:GetFont()
				local textWidth = ns.Names.Width(f.healthText, f.healthText:GetText(), textSize)
				assert(textWidth <= text.reserve + EPS, who .. ": the percent fits its " .. text.reserve .. " unit lane, got " .. textWidth)
				local percent = drawn[f.healthText] or { text.textRight - textWidth, text.stacked and 2 or 1, textWidth, 1 }
				assert(apart(name, percent), who .. ": the name " .. describe(name) .. " clears the percent " .. describe(percent))
			end
			if f.auraClip and f.auraClip:IsShown() and f.parts.block then
				local block = f.parts.block
				local pips = drawn[f.auraClip] or { block.left, text.stacked and 0 or 1, block.width, 1 }
				assert(apart(name, pips), who .. ": the name " .. describe(name) .. " clears the debuff pips " .. describe(pips))
			end
			checked = checked + 1
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
	end
end
rawset(_G, "RENDER_SCREEN", previous)
print("ok - test-groupframes-medallions-tiles: " .. checked .. " tiles")
