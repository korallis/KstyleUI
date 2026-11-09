-- test-setup-collisions.lua: every preset (DPS, Tank, Healer) resolves to element rects at 16:9, 16:10 and 21:9 on the 1080-unit canvas with nothing off screen and nothing overlapping, each element at the full footprint it draws: a reserve never hides part of its element (the boss stack once reserved one card of five), and the boss column's footprint covers its cards and their aura room from the live unit frames.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup.Layouts

local HEIGHT = 1080
local ASPECTS = { { "16:9", 16 / 9 }, { "16:10", 16 / 10 }, { "21:9", 21 / 9 } }

-- Pairs that never show together or sit inside each other on purpose; everything else must stay apart.
local function apart(name, a, c)
	local pair = { [a] = true, [c] = true }
	if pair["groupframes.party"] and pair["groupframes.raid"] then
		return false
	end
	if Layouts.Dock(a) == c or Layouts.Dock(c) == a then
		return false
	end
	-- An element that covers a card covers what docks in it too: the tooltip anchor lies over the readout and its menus.
	local function covers(x, y)
		local host = Layouts.Covers(x)
		return host ~= nil and (host == y or Layouts.Dock(y) == host)
	end
	if covers(a, c) or covers(c, a) then
		return false
	end
	if pair["meters.threat"] and pair["meters.damage"] and Layouts.Shown(name, "meters.threat") == false then
		return false
	end
	return true
end

local function overlap(r, s)
	return r[1] < s[3] and s[1] < r[3] and r[2] < s[4] and s[2] < r[4]
end

-- A reserve is room kept around an element, never less than the element ------------------------------------------
for _, name in ipairs(Layouts.Names()) do
	for _, element in ipairs(Layouts.ELEMENTS) do
		local w, h = Layouts.Footprint(name, element.key)
		if not Layouts.Sizes(name)[element.key] then
			assert(w >= element.width and h >= element.height, string.format("%s: %s draws %d x %d but the layout plans only %d x %d", name, element.key, element.width, element.height, w, h))
		end
	end
end

-- Every preset at every aspect: on screen and apart --------------------------------------------------------------
local checked = 0
for _, name in ipairs(Layouts.Names()) do
	local layout = Layouts.Get(name)
	for _, aspect in ipairs(ASPECTS) do
		local width = HEIGHT * aspect[2]
		local label = name .. " at " .. aspect[1]
		local rects, keys = {}, {}
		for _, element in ipairs(Layouts.ELEMENTS) do
			local w, h = Layouts.Footprint(name, element.key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h }, layout[element.key], width, HEIGHT)
			assert(l >= -1e-6 and b >= -1e-6 and r <= width + 1e-6 and t <= HEIGHT + 1e-6,
				string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %d)", label, element.key, l, b, r, t, width, HEIGHT))
			rects[element.key] = { l, b, r, t }
			keys[#keys + 1] = element.key
		end
		for i = 1, #keys do
			for j = i + 1, #keys do
				local a, c = keys[i], keys[j]
				if apart(name, a, c) and overlap(rects[a], rects[c]) then
					local ra, rc = rects[a], rects[c]
					error(string.format("%s: %s (%.0f,%.0f-%.0f,%.0f) overlaps %s (%.0f,%.0f-%.0f,%.0f)", label, a, ra[1], ra[2], ra[3], ra[4], c, rc[1], rc[2], rc[3], rc[4]))
				end
			end
		end
		checked = checked + 1
	end
end

-- The live boss column: the unit frames build it at the element's size and its auras fit the footprint's spare width --
do
	local U = dofile("Tools/regression/unitframes_env.lua")
	local uenv, UK, ns = U.New()
	local s = ns.Settings.Snapshot("boss")
	local element = UK.Setup.Layouts.Element("unitframes.boss")
	local fw = UK.Setup.Layouts.Footprint("DPS", "unitframes.boss")
	local auraW = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing + 2
	assert(s.auraPosition == "LEFT" and fw - element.width >= auraW, "the boss auras hang left of the cards inside the footprint: " .. (fw - element.width) .. " < " .. auraW)
	local _, _, w, h = UK.Layout.Rect("unitframes.boss")
	assert(math.abs(w - element.width) < 1 and math.abs(h - element.height) < 1, "the boss holder is built at the element's size")
	assert(#uenv._errors == 0, tostring(uenv._errors[1]))
end

print("setup collisions ok: " .. #Layouts.Names() .. " presets x " .. #ASPECTS .. " aspects, " .. checked .. " screens, " .. #Layouts.ELEMENTS .. " elements each")
