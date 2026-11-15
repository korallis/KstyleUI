-- medallions_tiles.lua: the shared check behind test-groupframes-medallions-tiles*.lua. Run(screens, file) builds one
-- environment per screen on a profile saved in Medallions and lays out a raid of 10 while healing, 25 while not,
-- 40 while healing and 10 on a tile too short for two lines. Every tile is held to the drawn scene: a 10 or 25-player
-- tile takes two lines and a short one takes one (the 40-player tile takes either, by a unit or two of snapping); the
-- fill spans the tile on all four sides (the bottom too on two lines, where the heal row sits inside the fill); the
-- name, the percent and the debuff block never meet; the name fits its lane; both texts sit at the text floor or over;
-- and no role square draws; a Dead or Offline tile hides its debuff block, which its status text may cover. The debuff block is checked by its clip frame, which clips the engine's icons (Auras.lua),
-- so no icon can draw outside it.
local G = dofile("Tools/regression/group_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = dofile("Tools/render/scene.lua")

local T = {}

local CASES = {
	{ count = 10, role = "HEALER" },
	{ count = 25, role = "DAMAGER" },
	{ count = 40, role = "HEALER" },
	{ count = 10, role = "DAMAGER", height = 24, oneLine = true },
}
local LONG = { "Thaldrenwick", "Brightblades", "Dreadwalkers", "Hammerfeldt", "Kragar", "Ilyra" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local EPS = 0.01
local function Saved()
	return {
		version = 2, profiles = { Default = { GroupFrames = { enabled = true }, HudStyle = { style = "medallions" } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}
end

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

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function apart(a, b)
	return a[1] + a[3] <= b[1] + EPS or b[1] + b[3] <= a[1] + EPS or a[2] + a[4] <= b[2] + EPS or b[2] + b[4] <= a[2] + EPS
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

function T.Run(screens, file)
	local previous = rawget(_G, "RENDER_SCREEN")
	local checked, stacked, single = 0, 0, 0
	for _, screen in ipairs(screens) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
		local env, K, ns = G.New({ setup = Common.ForceScreen, saved = Saved() })
		env.SetQuiet(true)
		local reach = K.Tokens.Size("gapSmall") + 1
		for _, case in ipairs(CASES) do
			local what = "raid of " .. case.count .. " (" .. case.role:lower() .. (case.oneLine and ", short tile" or "") .. ") at " .. screen[1] .. "x" .. screen[2]
			G.SetRoster(env, "raid", G.Members(case.count, function(i, m)
				m.name = LONG[(i - 1) % #LONG + 1]
				m.class = CLASSES[(i - 1) % #CLASSES + 1]
				m.health = ({ 100, 64, 23, 8 })[(i - 1) % 4 + 1]
				if i == 4 then
					m.dead = true
				elseif i == 5 then
					m.online = false
				end
			end), { name = "Valerin", class = "SHAMAN", role = case.role })
			if not K.Modules.IsRunning("GroupFrames") then
				assert(K.Modules.Enable("GroupFrames"))
			end
			if case.height then
				K.Options.Write("GroupFrames", "raid.height", case.height)
			end
			env.RunTimers()
			assert(K.HudStyle.Current() == "medallions", what .. ": the profile opens on Medallions")
			local floor = K.Scale.TextFloor()
			local function px(text)
				local _, size = text:GetFont()
				return size * K.Widgets.ScaleFactor(text:GetParent()) / K.Scale.Pixel(1)
			end
			local drawn = {}
			for _, item in ipairs(Scene.Build(env).items) do
				drawn[item.object] = item.rect
			end
			for _, f in ipairs(rows(ns)) do
				local who = what .. ", " .. tostring(f.rawName) .. " (" .. f.unit .. ")"
				local tile = f.parts.tile
				assert(tile and f.tileText, who .. ": the Medallions tile is laid out")
				if case.oneLine then
					assert(not tile.stacked, who .. ": one line on a short tile")
				elseif case.count < 40 then
					assert(tile.stacked, who .. ": two lines on a 10 or 25-player tile")
				end
				if tile.stacked then
					stacked = stacked + 1
				else
					single = single + 1
				end
				local frame = { Scene.Rect(env, f) }
				local bar = { Scene.Rect(env, f.health) }
				assert(bar[1] - frame[1] <= reach and frame[1] + frame[3] - (bar[1] + bar[3]) <= reach and bar[2] - frame[2] <= reach,
					who .. ": the fill " .. describe(bar) .. " spans the tile " .. describe(frame))
				if tile.stacked then
					assert(frame[2] + frame[4] - (bar[2] + bar[4]) <= reach, who .. ": the fill " .. describe(bar) .. " runs to the tile's bottom " .. describe(frame))
				end
				assert(not f.role:IsShown() and not drawn[f.role], who .. ": no role square")
				assert(px(f.name) >= floor - EPS, who .. ": the name is at the " .. floor .. " px floor or over, got " .. px(f.name))
				local shown = f.name:GetText() or ""
				local _, size = f.name:GetFont()
				local width = ns.Names.Width(f.name, shown, size)
				assert(width <= f.nameWidth + f.nameFit.slack + EPS, who .. ": " .. shown .. " is " .. width .. " units in a " .. f.nameWidth .. " unit lane")
				local name = drawn[f.name]
				assert(name, who .. ": the name draws")
				local percent = drawn[f.healthText]
				local percentOn = f.healthText:IsShown() and (f.status ~= nil or ns.Settings.current.raid.healthText ~= "NONE")
				if percentOn then
					assert(percent, who .. ": the percent draws")
					assert(px(f.healthText) >= floor - EPS, who .. ": the percent is at the floor or over")
					assert(apart(name, percent), who .. ": the name " .. describe(name) .. " clears the percent " .. describe(percent))
					assert(percent[1] + percent[3] <= bar[1] + bar[3] + EPS, who .. ": the percent ends inside the fill")
				end
				local clip = f.parts.block and { Scene.Rect(env, f.auraClip) }
				if clip then
					assert(clip[1], who .. ": the debuff block resolves")
					assert(apart(name, clip), who .. ": the name " .. describe(name) .. " clears the debuffs " .. describe(clip))
					if f.status then
						eq(f.auraClip:GetAlpha(), 0, who .. ": the debuffs give way to " .. f.status)
					elseif percentOn then
						assert(apart(percent, clip), who .. ": the percent " .. describe(percent) .. " clears the debuffs " .. describe(clip))
					end
					assert(clip[1] >= bar[1] - EPS and clip[1] + clip[3] <= bar[1] + bar[3] + EPS, who .. ": the debuffs sit on the fill")
				end
				checked = checked + 1
			end
			assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
		end
	end
	rawset(_G, "RENDER_SCREEN", previous)
	assert(stacked > 0 and single > 0, file .. ": both tile shapes were checked")
	print(string.format("ok - %s: %d tiles, %d on two lines and %d on one", file, checked, stacked, single))
end

return T
