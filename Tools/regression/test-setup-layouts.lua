-- test-setup-layouts.lua: the DPS, Tank and Healer layouts place every known element key on screen, apart, as the v3 mockups show.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises = CoreEnv.Raises

local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup and K.Setup.Layouts
assert(type(Layouts) == "table", "KstyleUI.Setup.Layouts is missing")

-- The element keys modules register with Layout, as docs/superpowers/plans/element-keys.md lists them.
local KEYS = {
	"unitframes.player", "unitframes.target", "unitframes.targettarget", "unitframes.focus", "unitframes.focustarget", "unitframes.pet",
	"unitframes.boss", "unitframes.castbar.player", "unitframes.castbar.target", "unitframes.resource", "groupframes.party", "groupframes.raid", "actionbars.bar1",
	"actionbars.bar2", "actionbars.bar3", "actionbars.bar4", "actionbars.bar5", "actionbars.bar6", "actionbars.pet",
	"actionbars.stance", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars",
	"auras.buffs", "auras.debuffs", "minimap.main", "chat.main", "databars.xp", "databars.rep", "databars.honor",
	"databars.strip", "databars.micro", "databars.bags", "meters.damage", "meters.threat", "meters.swing",
	"combattext.player",
	"tooltips.anchor",
}
local ANCHORS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
-- Party and raid frames never show together, so they may share space.
local EXCLUSIVE = { ["groupframes.party"] = "groupframes.raid", ["groupframes.raid"] = "groupframes.party" }
local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 3456, 2234 } }
local HEIGHT = 1080

local function set(list)
	local out = {}
	for _, v in ipairs(list) do
		out[v] = true
	end
	return out
end

-- The element list matches the plan's keys, and the doc lists the same keys ---------------------------

local known = set(KEYS)
local seen = {}
for _, element in ipairs(Layouts.ELEMENTS) do
	assert(known[element.key], "Layouts.ELEMENTS has a key the plan does not list: " .. tostring(element.key))
	assert(not seen[element.key], "a key is listed twice: " .. element.key)
	seen[element.key] = true
	assert(type(element.module) == "string" and K.Features.modules[element.module] ~= nil, element.key .. " names a module in Features")
	assert(element.key:sub(1, #element.module):lower() == element.module:lower(), element.key .. " starts with its module's name")
	assert(type(element.label) == "string" and element.label ~= "", element.key .. " has a label")
	assert(type(element.width) == "number" and element.width > 0 and type(element.height) == "number" and element.height > 0, element.key .. " has a footprint")
	assert(Layouts.Element(element.key) == element, "Element finds " .. element.key)
end
for _, key in ipairs(KEYS) do
	assert(seen[key], "Layouts.ELEMENTS lacks " .. key)
end
assert(Layouts.Element("nameplates") == nil, "nameplates sit on the plates and have no element key")

local doc = assert(io.open("docs/superpowers/plans/element-keys.md", "rb")):read("*a")
local documented = {}
for key in doc:gmatch("\n| `([%w%.]+)` |") do
	documented[#documented + 1] = key
end
assert(#documented == #KEYS, "element-keys.md lists " .. #documented .. " keys, the plan has " .. #KEYS)
for i, key in ipairs(documented) do
	assert(key == KEYS[i], "element-keys.md row " .. i .. " is " .. key .. ", expected " .. KEYS[i])
	local element = Layouts.Element(key)
	local row = doc:match("\n| `" .. key:gsub("%.", "%%.") .. "` |[^\n]*")
	assert(row:find(element.width .. " x " .. element.height, 1, true), "element-keys.md gives " .. key .. "'s footprint as " .. element.width .. " x " .. element.height)
end

-- Rect: an anchor and offsets on a root of a given width ------------------------------------------------

local function same(a, b)
	return math.abs(a - b) < 1e-6
end
do
	local probe = { key = "probe", width = 100, height = 50 }
	local l, b, r, t = Layouts.Rect(probe, { anchor = "CENTER", x = 0, y = 0 }, 1920, 1080)
	assert(same(l, 910) and same(b, 515) and same(r, 1010) and same(t, 565), "CENTER centres the footprint")
	l, b, r, t = Layouts.Rect(probe, { anchor = "TOPRIGHT", x = -16, y = -16 }, 1920, 1080)
	assert(same(l, 1804) and same(b, 1014) and same(r, 1904) and same(t, 1064), "TOPRIGHT offsets from the top right corner")
	l, b = Layouts.Rect(probe, { anchor = "BOTTOMLEFT", x = 16, y = 16 }, 1920, 1080)
	assert(same(l, 16) and same(b, 16))
	l, b, r, t = Layouts.Rect(probe, { anchor = "LEFT", x = 10, y = 20 }, 1920, 1080)
	assert(same(l, 10) and same(b, 535) and same(r, 110) and same(t, 585), "LEFT centres vertically")
	l, b = Layouts.Rect(probe, { anchor = "BOTTOM", x = -100, y = 5 }, 1000, 1080)
	assert(same(l, 350) and same(b, 5), "BOTTOM centres horizontally")
end

-- Every layout: complete, valid, on screen and apart on every reference screen ---------------------------

local names = Layouts.Names()
assert(#names == 3 and names[1] == "DPS" and names[2] == "Tank" and names[3] == "Healer", "three layouts: DPS, Tank and Healer")

local function overlap(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

for _, name in ipairs(names) do
	local layout = Layouts.Get(name)
	assert(type(layout) == "table", name .. " has positions")
	assert(type(Layouts.Label(name)) == "string" and type(Layouts.Note(name)) == "string", name .. " has a label and a note")
	for key, position in pairs(layout) do
		assert(known[key], name .. " places " .. tostring(key) .. ", which is not a known element key")
		assert(ANCHORS[position.anchor], name .. " " .. key .. ": anchor " .. tostring(position.anchor) .. " is not one of the nine")
		for _, axis in ipairs({ "x", "y" }) do
			local v = position[axis]
			assert(type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge, name .. " " .. key .. ": " .. axis .. " must be a finite number")
		end
		for field in pairs(position) do
			assert(field == "anchor" or field == "x" or field == "y", name .. " " .. key .. " has an extra field " .. tostring(field))
		end
	end
	for _, key in ipairs(KEYS) do
		assert(layout[key], name .. " has no position for " .. key)
	end
	for _, screen in ipairs(SCREENS) do
		local width = HEIGHT * screen[1] / screen[2]
		local label = name .. " at " .. screen[1] .. "x" .. screen[2]
		local rects = {}
		for _, key in ipairs(KEYS) do
			local l, b, r, t = Layouts.Rect(Layouts.Element(key), layout[key], width, HEIGHT)
			assert(l >= 0 and b >= 0 and r <= width + 1e-6 and t <= HEIGHT, string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %d)", label, key, l, b, r, t, width, HEIGHT))
			rects[key] = { l, b, r, t }
		end
		for i = 1, #KEYS do
			for j = i + 1, #KEYS do
				local a, c = KEYS[i], KEYS[j]
				if EXCLUSIVE[a] ~= c and overlap(rects[a], rects[c]) then
					error(label .. ": " .. a .. " overlaps " .. c)
				end
				local ra, rc = rects[a], rects[c]
				if (a:find("^unitframes%.") or c:find("^unitframes%.")) and overlap({ ra[1] - 2, ra[2] - 2, ra[3] + 2, ra[4] + 2 }, rc) then
					error(label .. ": " .. a .. " comes within 2 units of " .. c)
				end
			end
		end
	end
end

-- The HUD follows the v3 mockups ---------------------------------------------------------------------

for _, name in ipairs(names) do
	local layout = Layouts.Get(name)
	local width = HEIGHT * 3456 / 2234
	local function rect(key)
		local l, b, r, t = Layouts.Rect(Layouts.Element(key), layout[key], width, HEIGHT)
		return { left = l, bottom = b, right = r, top = t, x = (l + r) / 2, y = (b + t) / 2 }
	end
	local player, target, essential = rect("unitframes.player"), rect("unitframes.target"), rect("cooldowns.essential")
	local utility, cast, bar1, bar2 = rect("cooldowns.utility"), rect("unitframes.castbar.player"), rect("actionbars.bar1"), rect("actionbars.bar2")
	local mid = width / 2
	local function centred(r)
		return math.abs(r.x - mid) < 1
	end
	assert(centred(essential) and centred(utility) and centred(cast) and centred(bar1) and centred(bar2), name .. ": the HUD band is centred")
	assert(bar2.top <= bar1.bottom and bar1.top <= utility.bottom and utility.top <= essential.bottom and essential.top <= cast.bottom, name .. ": two bar rows, then utility, essential and the cast bar above")
	assert(bar2.bottom < 100, name .. ": the action bars sit low")
	assert(player.right < essential.left and target.left > essential.right, name .. ": player and target sit either side of the Cooldown Manager")
	assert(player.bottom == target.bottom and player.top < cast.bottom, name .. ": player and target on one line, below the cast bar")
	assert(math.abs((mid - player.x) - (target.x - mid)) < 1, name .. ": player and target mirror each other")
	assert(player.bottom <= essential.bottom and player.top >= essential.top, name .. ": the frames flank the essential row, as in the composition mockup")
	assert(utility.bottom < player.bottom and utility.top > player.bottom - 60, name .. ": the utility row hangs just below the frames")
	assert(essential.left - player.right >= 24 and essential.left - player.right <= 40, name .. ": the mockup's 32-unit gap between a frame and the essential row")
	assert(cast.bottom - player.top >= 4 and cast.bottom - player.top <= 12, name .. ": the cast bar sits a few units above the frames")
	local xp, swing = rect("databars.xp"), rect("meters.swing")
	assert(centred(xp) and xp.bottom > bar1.top + 10 and xp.top < utility.bottom - 10, name .. ": the experience bar runs between action bar 1 and the utility row, with room for its caption")
	assert(xp.left > player.right - 1 and xp.right < target.left + 1, name .. ": the experience bar stays between the frames' inner edges")
	assert(swing.bottom >= cast.top, name .. ": the swing timer sits above the cast bar")
	local resource, pet, targetCast, tot = rect("unitframes.resource"), rect("unitframes.pet"), rect("unitframes.castbar.target"), rect("unitframes.targettarget")
	for _, under in ipairs({ { pet, player, "the pet frame" }, { targetCast, target, "the target cast bar" }, { tot, target, "the target of target" } }) do
		local small, frame = under[1], under[2]
		assert(small.top <= frame.bottom and small.left >= frame.left and small.right <= frame.right, name .. ": " .. under[3] .. " sits under its frame")
	end
	assert(resource.bottom >= player.top and resource.left >= player.left and resource.right <= player.right, name .. ": the class resource sits on top of the player frame")
	assert(math.abs((mid - pet.x) - (tot.x - mid)) < 1 and pet.bottom == tot.bottom, name .. ": the pet frame and the target of target mirror each other")
	local bars, buffs = rect("cooldowns.bars"), rect("cooldowns.buffs")
	assert(bars.top <= player.bottom and bars.top >= player.bottom - 4 and math.abs(bars.right - player.right) <= 4, name .. ": the tracked buff bars hang under the player frame, right-aligned, as in the mockup")
	assert(buffs.top <= target.bottom and buffs.left >= target.left and buffs.right <= target.right, name .. ": the tracked buff icons hang under the target frame")
	assert(bar1.bottom - bar2.top >= 6 and bar1.bottom - bar2.top <= 12, name .. ": the two bar rows keep the mockup's 10-unit gap")
	local minimap, auraBuffs = rect("minimap.main"), rect("auras.buffs")
	assert(minimap.top > HEIGHT - 40 and minimap.right > width - 40, name .. ": the minimap sits top right")
	assert(auraBuffs.top <= minimap.bottom and auraBuffs.right > width - 40, name .. ": the buffs sit under the minimap")
	local chat, strip = rect("chat.main"), rect("databars.strip")
	assert(chat.left < 40 and chat.bottom < 40, name .. ": chat sits bottom left")
	assert(strip.right > width - 40 and strip.bottom < 40, name .. ": the data strip sits bottom right")
	assert(rect("meters.damage").x > mid and rect("meters.threat").x > mid, name .. ": the meters sit right")
end
do
	local function x(name, key)
		local l, _, r = Layouts.Rect(Layouts.Element(key), Layouts.Get(name)[key], 1920, HEIGHT)
		return (l + r) / 2
	end
	assert(x("DPS", "groupframes.party") < 300 and x("Tank", "groupframes.party") < 300, "DPS and Tank keep party frames at the left edge")
	assert(x("Healer", "groupframes.party") > 300 and math.abs(x("Healer", "groupframes.raid") - 960) < 1, "Healer brings group frames to the centre")
	assert(x("Tank", "meters.threat") < x("DPS", "meters.threat"), "Tank brings the threat meter in beside the target frame")
end

-- Player and target take the kit sheet's proportions (docs/design/mockups/05_kit_hunter.jpg), about 3.3 times as wide as
-- tall, at the 80 to 95 units the v3 HUD mockups show. The compact frames stay compact.
for _, key in ipairs({ "unitframes.player", "unitframes.target" }) do
	local e = Layouts.Element(key)
	assert(e.height >= 88 and e.height <= 100, key .. " is close to the kit sheet's 100 units at the 1080 reference, as large as the Mac's screen allows beside the chat, got " .. e.height)
	assert(math.abs(e.width / e.height - 469 / 141) < 0.02, key .. " has the kit sheet's 469 by 141 proportions, got " .. e.width .. " x " .. e.height)
end

for _, key in ipairs({ "unitframes.targettarget", "unitframes.focustarget", "unitframes.pet" }) do
	assert(Layouts.Element(key).height < 36, key .. " stays a compact frame")
end

-- Footprints follow the owner's design file (kit-spec/SPEC.md) ------------------------------------------

do
	local function footprint(key)
		local element = Layouts.Element(key)
		return element.width .. "x" .. element.height
	end
	assert(footprint("minimap.main") == "168x166", "the minimap is 168 by 166: a 142 map, a 24 strip and a 22 footer, got " .. footprint("minimap.main"))
	assert(footprint("chat.main") == "320x130", "the chat panel is 320 by 130, got " .. footprint("chat.main"))
	assert(footprint("meters.damage") == "208x130", "the damage meter is 208 by 130 for five rows, got " .. footprint("meters.damage"))
	assert(footprint("meters.threat") == "208x104", "the threat meter is 208 by 104 for four rows, got " .. footprint("meters.threat"))
	assert(footprint("databars.strip") == "360x36", "the data strip is 360 wide, got " .. footprint("databars.strip"))
	assert(footprint("databars.xp") == "440x4", "the experience bar is 440 by 4, got " .. footprint("databars.xp"))
	local layout = Layouts.Get("DPS")
	local minimap = layout["minimap.main"]
	assert(minimap.anchor == "TOPRIGHT" and minimap.x == -16 and minimap.y == -16, "the minimap stays 16 in from the top right corner")
end

-- The HUD band takes the composition mockup's sizes (docs/design/mockups/v3/leveling_warrior.jpg, measured at the 1080
-- reference from the owner's 2574 by 1456 render, 1.348 px per unit): 38-unit buttons at a 41 pitch, 56-unit essential
-- icons at a 64 pitch, 52-unit utility icons, a 340 by 36 cast bar, a 440-wide experience line and 24-unit buff bars.
local FOOTPRINTS = {
	["actionbars.bar1"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar2"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar3"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar4"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar5"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar6"] = { 38, 12 * 38 + 11 * 3 },
	["cooldowns.essential"] = { 6 * 56 + 5 * 8, 56 },
	["cooldowns.utility"] = { 4 * 52 + 3 * 10, 52 },
	["cooldowns.bars"] = { 172, 3 * 24 + 2 * 3 },
	["unitframes.castbar.player"] = { 340, 36 },
	["databars.xp"] = { 440, 4 },
}
for key, size in pairs(FOOTPRINTS) do
	local e = Layouts.Element(key)
	assert(e.width == size[1] and e.height == size[2], key .. " is " .. size[1] .. " x " .. size[2] .. " as the mockup measures, got " .. e.width .. " x " .. e.height)
end

-- Get returns copies; Default gives the DPS position for a module's Register call ------------------------

do
	local layout = Layouts.Get("DPS")
	layout["unitframes.player"].x = 12345
	assert(Layouts.Get("DPS")["unitframes.player"].x ~= 12345, "Get returns a copy")
	assert(Layouts.Get("Raid") == nil, "an unknown layout gives nil")
	local default = Layouts.Default("unitframes.player")
	local dps = Layouts.Get("DPS")["unitframes.player"]
	assert(default.anchor == dps.anchor and default.x == dps.x and default.y == dps.y, "Default is the DPS position")
	default.x = 1
	assert(Layouts.Default("unitframes.player").x == dps.x, "Default returns a copy")
	Raises(function() Layouts.Default("unitframes.plyer") end, "unknown element key unitframes.plyer", "a typo in a module's key")
end

print("setup layouts ok: " .. #KEYS .. " keys, " .. #names .. " layouts, " .. #SCREENS .. " screens")
