-- test-setup-layouts.lua: the Lumen DPS, Tank and Healer layouts place every known element key on screen, apart, on two rails around a clear centre, as the Lumen Rails mockup shows.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises = CoreEnv.Raises

local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup and K.Setup.Layouts
local LIFT, TRAY_PAD, TRAY_BOTTOM = Layouts.TRAY_LIFT, Layouts.TRAY_PAD, Layouts.TRAY_BOTTOM
local TRAY_TILE, TRAY_GAP = 38 * 19 / 16, 3 * 19 / 16
local TRAY_ROW = 12 * TRAY_TILE + 11 * TRAY_GAP
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
	"qol.lootfeed",
	"tooltips.anchor",
}
local ANCHORS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
-- Party and raid frames never show together, so they may share space.
local EXCLUSIVE = { ["groupframes.party"] = "groupframes.raid", ["groupframes.raid"] = "groupframes.party" }
local PICTURE_GAPS = {
	["unitframes.player/unitframes.target"] = 2,
}
-- 16:9 at three sizes, a MacBook, the owner's 2383 x 1540, 16:10, 21:9 and the two 32:9 panels (5120 x 1440, the
-- owner's, and 3840 x 1080): at the Interface size KstyleUI ships (16 / 19) the root is Layouts.HEIGHT (1282.5) units
-- tall on each.
local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 3456, 2234 }, { 2383, 1540 }, { 2560, 1600 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 1080 } }
local HEIGHT = Layouts.HEIGHT

local function same(a, b)
	return math.abs(a - b) < 1e-6
end

-- LEE-20: the owner's picture wins over the earlier Lumen sigil and spare-bar stack.
local REFERENCE = {
	["unitframes.player"] = { 491, 77.5, 0, 138 + LIFT, 586.5, -47.75 },
	["unitframes.target"] = { 491, 102.5, 0, 217.5 + LIFT, 737.4, 123.2 },
	["unitframes.castbar.player"] = { 347, 30, 0, 385.5 + LIFT },
	["unitframes.resource"] = { 120, 14, 0, 421 + LIFT },
	["cooldowns.essential"] = { 243.2, 36.7, 0, 335.3 + LIFT },
	["cooldowns.buffs"] = { 182.6, 41.6, -442.8, 155.9 + LIFT },
	["actionbars.bar1"] = { TRAY_ROW, TRAY_TILE, 0, TRAY_BOTTOM + TRAY_PAD },
	["actionbars.bar2"] = { TRAY_ROW, TRAY_TILE, 0, TRAY_BOTTOM + TRAY_PAD + TRAY_TILE + TRAY_GAP },
	["databars.xp"] = { 491, 5, 0, TRAY_BOTTOM - 9 * 19 / 16 - 5 },
}
for _, name in ipairs(Layouts.Names()) do
	for key, want in pairs(REFERENCE) do
		local element, position = Layouts.Element(key), Layouts.Get(name)[key]
		local label = "LEE-20 " .. name .. " " .. key
		assert(same(element.width, want[1]) and same(element.height, want[2]), label .. " matches the picture's frame dimensions")
		assert(position.anchor == "BOTTOM" and same(position.x, want[3]) and same(position.y, want[4]), label .. " matches the picture's bar-column position")
		local w, h, offsetX = Layouts.Footprint(name, key)
		assert(same(w, want[5] or want[1]) and same(h, want[2]) and same(offsetX or 0, want[6] or 0), label .. " reserves the external portrait and auras without recentering the bars")
	end
end

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
	probe.offsetX = -47.75
	l, b, r, t = Layouts.Rect(probe, { anchor = "BOTTOM", x = 0, y = 138 }, 1000, 1080)
	assert(same(l, 402.25) and same(r, 502.25) and same(b, 138) and same(t, 188), "LEE-20 Rect shifts the reserve, not the registered bar-column anchor")
end

-- Every layout: complete, valid, on screen and apart on every reference screen ---------------------------

local names = Layouts.Names()
assert(#names == 3 and names[1] == "DPS" and names[2] == "Tank" and names[3] == "Healer", "three layouts: DPS, Tank and Healer")

local function overlap(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

-- Size(name, key) -> the footprint the layout plans for: the element's, or the layout's own where it differs.
local function Size(name, key)
	local w, h, offsetX = Layouts.Footprint(name, key)
	return { width = w, height = h, offsetX = offsetX }
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
		local w, h = Layouts.Footprint(name, key)
		assert(type(w) == "number" and w > 0 and type(h) == "number" and h > 0, name .. " gives " .. key .. " a footprint")
	end
	for _, screen in ipairs(SCREENS) do
		local width = HEIGHT * screen[1] / screen[2]
		local label = name .. " at " .. screen[1] .. "x" .. screen[2]
		local rects = {}
		for _, key in ipairs(KEYS) do
			local l, b, r, t = Layouts.Rect(Size(name, key), layout[key], width, HEIGHT)
			assert(l >= 0 and b >= 0 and r <= width + 1e-6 and t <= HEIGHT, string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %.1f)", label, key, l, b, r, t, width, HEIGHT))
			rects[key] = { l, b, r, t }
		end
		-- A docked element sits inside its host card; the optional threat card has its own combat-cluster slot.
		local function shares(a, c)
			if Layouts.Dock(a) == c or Layouts.Dock(c) == a then
				return true
			end
			return false
		end
		-- Bars 3 to 6 are off in every layout, but each keeps a free slot on every screen, the owner's narrow 1.547 one
		-- included (owner pass 1, 2026-11-09: "not much room for adding more action bars").
		for i = 1, #KEYS do
			for j = i + 1, #KEYS do
				local a, c = KEYS[i], KEYS[j]
				if EXCLUSIVE[a] ~= c and not shares(a, c) and overlap(rects[a], rects[c]) then
					error(label .. ": " .. a .. " overlaps " .. c)
				end
				local ra, rc = rects[a], rects[c]
				local pictureGap = PICTURE_GAPS[a .. "/" .. c]
				if pictureGap then
					assert(same(math.max(rc[2] - ra[4], ra[2] - rc[4]), pictureGap), label .. ": LEE-20 " .. a .. " and " .. c .. " keep the picture's exact " .. pictureGap .. "-unit gap")
				elseif (a:find("^unitframes%.") or c:find("^unitframes%.")) and overlap({ ra[1] - 2, ra[2] - 2, ra[3] + 2, ra[4] + 2 }, rc) then
					error(label .. ": " .. a .. " comes within 2 units of " .. c)
				end
			end
		end
	end
end

-- Lumen Rails (handoff/arena2/parent: index.html, NOTES.md and the two HUD boards) ------------------------
-- Two 318-unit rails on the screen margin (17 units, the owner's picture of 2026-11-09) hold everything slow: in DPS and Tank the left rail the party and chat, the
-- right rail the map with the aura rows, the story slot, the damage card and the readout and menu. The
-- centre follows the LEE-20 picture: two action rows, the player and target bar columns, cooldowns and player cast.
-- Optional focus, target-of-target and Tank threat cards retain their upper slots. The boss column heads the centre's right edge,
-- 16 units in from the right rail. The world above the cluster stays clear. Healer stands the party and raid on the
-- cluster's left half, clear of the cast bars, heads the left rail with the boss column and keeps the right rail's
-- damage card under the aura rows, as DPS does (round 3: the buffs at 40 and 12 debuffs left no room for the boss
-- column on the right rail; Muse #2: the cast bars stay in the cluster).

local MARGIN, RAIL = 17, 318
local BAND = MARGIN + RAIL + 16
local CARD_GAP_MIN = 16
local LEFT_RAIL = {
	DPS = { "groupframes.party", "qol.lootfeed" },
	Tank = { "groupframes.party", "qol.lootfeed" },
	Healer = { "groupframes.party", "qol.lootfeed" },
}
-- The picture (LEE-20, LEE-69) draws the chat card 393 by 186. DPS and Tank take that width. Healer keeps the 318 rail:
-- on a 2383 x 1540 screen at UI scale 1, six tracked bars do not fit beside a 393 card (test-setup-editmode.lua).
local CHAT_WIDTH = { DPS = 393, Tank = 393, Healer = 318 }
-- The right rail, as the owner's picture draws it (LEE-20, "let the picture win", 2026-11-09), on the screenMargin
-- token's margin: the 188 map heads it with its 36-unit caption (zone, coordinates, clock) under it and the aura rows
-- 12 left of it; the 278 story slot hangs 15 under the caption; bars 4 and 5 stand as two 36.7-unit columns 4.6 apart (LEE-69: the centre bars' pitch, 1.4 inside the margin), 12
-- under the slot; the readout line 10 under them, right-aligned; the 269 x 158 damage card at the foot, 6 under the
-- readout. Bar 6, off, is a third column beside them, so its slot costs the rail no height. The micro menu, the bag bar
-- and the tooltip anchor stand left of the columns, off every card.
local EDGE = K.Tokens.Size("screenMargin")
local MAP, MAP_HEADING, MAP_CAPTION = 188, 22, 14
local RIGHT_EDGE = { ["minimap.main"] = 188, ["meters.damage"] = 269, ["databars.strip"] = 278 }
local RAIL_COLUMN, RAIL_PITCH, RAIL_INSET = 36.7, 4.6, 1.4
local STORY_W, STORY_RAIL_MIN = 278, 280
-- The aura rows: one row of ten 28-unit icons each, 307 x 42, the buffs 12 left of the map and top-aligned with it,
-- the debuffs 8 under the buffs, right-aligned with them.
local AURA_ROWS = { "auras.buffs", "auras.debuffs" }
local DOCKED = { ["databars.micro"] = "databars.strip", ["databars.bags"] = "databars.strip" }
local HANDS = set({
	"databars.xp", "databars.rep", "databars.honor", "actionbars.bar1", "actionbars.pet", "actionbars.stance",
	"unitframes.player", "unitframes.pet", "unitframes.resource", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs",
	"cooldowns.bars", "meters.swing",
})
-- The target and optional focus/target-of-target slots remain below the clear world column.
local CLUSTER = set({ "unitframes.target", "unitframes.targettarget", "unitframes.focus", "unitframes.focustarget" })
-- Both player and optional target cast bars remain below the clear world column.
local EXTRAS = set({ "unitframes.castbar.player", "unitframes.castbar.target" })
-- The world kept clear (system board): the centre 520 units wide, from the top of what stacks on the cluster (the plate
-- target cast bar's retained top, 664) to the top.
local CLEAR = { half = 260, bottom = 664 + LIFT, top = HEIGHT - 28 }
-- The boss column at the clear centre's edge: on a 16:10 screen it reaches into the zone's outer three quarters, never
-- past them. KSTY-33 moved it 75 units in to clear the quest card's column beside the RestedXP guide (the Captain's
-- ruling on the Fable audit), so on 16:10 it stands 69 units right of the centre line, where it stood 144.
local EDGE_RIGHT = set({ "unitframes.boss" })
local RAIL_KEYS = {
	DPS = set({ "groupframes.party", "groupframes.raid", "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor",
		"actionbars.bar4", "actionbars.bar5", "actionbars.bar6" }),
	Tank = set({ "groupframes.party", "groupframes.raid", "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor",
		"actionbars.bar4", "actionbars.bar5", "actionbars.bar6" }),
	Healer = set({ "groupframes.party", "groupframes.raid", "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor",
		"actionbars.bar4", "actionbars.bar5", "actionbars.bar6" }),
}
-- The optional focus target and Tank threat card retain their four-unit gaps.
local CLUSTER_GAP = 4

for _, name in ipairs(names) do
	local layout = Layouts.Get(name)
	for _, screen in ipairs(SCREENS) do
		local width = HEIGHT * screen[1] / screen[2]
		local label = name .. " at " .. screen[1] .. "x" .. screen[2]
		local mid = width / 2
		local function rect(key)
			local l, b, r, t = Layouts.Rect(Size(name, key), layout[key], width, HEIGHT)
			return { left = l, bottom = b, right = r, top = t, x = (l + r) / 2, y = (b + t) / 2, w = r - l, h = t - b }
		end
		local function centred(r)
			return math.abs(r.x - mid) < 1
		end

		-- The rails share their columns and width, the same on both sides.
		for _, key in ipairs(LEFT_RAIL[name]) do
			local r = rect(key)
			assert(r.left == MARGIN and r.w == RAIL, label .. ": " .. key .. " sits on the left rail, 318 wide on the margin")
		end
		for key, wantWidth in pairs(RIGHT_EDGE) do
			local r = rect(key)
			local inset = key == "minimap.main" and EDGE - 1 or EDGE
			assert(math.abs(r.right - (width - inset)) < 1e-6 and math.abs(r.w - wantWidth) < 1e-6, label .. ": " .. key .. " sits on its right inset, " .. wantWidth .. " wide")
		end
		local map, auraBuffs, auraDebuffs = rect("minimap.main"), rect(AURA_ROWS[1]), rect(AURA_ROWS[2])
		assert(map.top == HEIGHT - (EDGE - 1 + MAP_HEADING) and map.h == MAP + MAP_CAPTION and Layouts.Element("minimap.main").height == MAP, label .. ": the 188 map heads the right rail under its 22-unit zone heading, with its 14-unit row under it")
		assert(math.abs(auraBuffs.right - (map.left - 11.9)) < 1e-6 and math.abs(auraBuffs.top - (map.top + MAP_HEADING - RAIL_INSET - 1)) < 1e-6, label .. ": the unchanged buff row stands 11.9 left of the map and 2.4 under the top of the zone heading over it")
		assert(auraBuffs.right == auraDebuffs.right and math.abs(auraBuffs.bottom - 8 - auraDebuffs.top) < 1e-6, label .. ": the debuff row hangs 8 under the buffs, right-aligned")
		assert(auraBuffs.w == 306.5 and auraBuffs.h == 41.5 and auraDebuffs.w == 306.5 and auraDebuffs.h == 41.5, label .. ": each aura row is ten 27.5-unit icons 3.5 apart, 306.5 x 41.5")
		local meter, strip, tip = rect("meters.damage"), rect("databars.strip"), rect("tooltips.anchor")
		assert(meter.bottom == EDGE and meter.h == 158, label .. ": the damage card stands at the rail's foot on the margin")
		assert(math.abs(strip.bottom - meter.top - 6) < 1e-6 and strip.h == 12, label .. ": the readout line stands 6 over the damage card")
		local columns = { rect("actionbars.bar4"), rect("actionbars.bar5"), rect("actionbars.bar6") }
		for i, bar in ipairs(columns) do
			assert(math.abs(bar.w - RAIL_COLUMN) < 1e-6 and math.abs(bar.h - (12 * RAIL_COLUMN + 11 * RAIL_PITCH)) < 1e-6, label .. ": bar " .. (i + 3) .. " is a column of twelve 36.7-unit slots 4.6 apart")
			assert(math.abs(bar.bottom - strip.top - 10) < 1e-6, label .. ": bar " .. (i + 3) .. " stands 10 over the readout line")
			assert(i == 1 or math.abs(columns[i - 1].left - bar.right - RAIL_PITCH) < 1e-6, label .. ": bar " .. (i + 3) .. " stands 4.6 left of the column before it")
		end
		-- The micro menu and the bag bar no longer dock by default (the picture's readout is a line); their own slots and
		-- the tooltip anchor stand 16 left of the rail's columns, on no card.
		for key, host in pairs(DOCKED) do
			assert(Layouts.Dock(key) == host, key .. " docks into " .. host .. " when the player turns docking on")
		end
		local micro, bags = rect("databars.micro"), rect("databars.bags")
		for _, r in ipairs({ micro, bags, tip }) do
			assert(math.abs(columns[3].left - r.right - 16) < 1e-6, label .. ": the menus and the tooltip anchor stand 16 left of the rail's columns")
		end
		assert(micro.bottom == columns[1].bottom and bags.bottom == micro.top and tip.bottom - bags.top == 16, label .. ": the micro menu on the columns' foot, the bags over it, the tooltip anchor 16 over them")
		local chat = rect("chat.main")
		local margin = K.Tokens.Size("screenMargin")
		assert(chat.bottom == margin and chat.left == margin and chat.w == CHAT_WIDTH[name] and chat.h == 186, label .. ": chat sits on the screenMargin token, " .. CHAT_WIDTH[name] .. " by 186, got " .. chat.w .. " by " .. tostring(chat.h))
		local feed = rect("qol.lootfeed")
		assert(feed.left == chat.left and feed.w == RAIL and feed.bottom - chat.top == CARD_GAP_MIN, label .. ": the loot feed stands " .. CARD_GAP_MIN .. " over the chat card on its left edge, got " .. (feed.bottom - chat.top))
		for _, key in ipairs(KEYS) do
			local r = rect(key)
			if key ~= "chat.main" and r.bottom < chat.top + CARD_GAP_MIN and r.top > chat.bottom - CARD_GAP_MIN then
				assert(r.left - chat.right >= CARD_GAP_MIN or r.right <= chat.left, label .. ": " .. key .. " keeps " .. CARD_GAP_MIN .. " units clear of the chat card, got " .. (r.left - chat.right))
			end
		end

		-- The story slot hangs 15 under the map's caption (and the aura rows, which end higher) and ends 12 over bars 4
		-- and 5, the 278-unit column the picture draws.
		local caption = rect("minimap.main")
		local rows = rect(AURA_ROWS[2])
		local over = math.min(caption.bottom, rows.bottom)
		local slot = Layouts.Slot(name)
		assert(slot and slot.anchor and slot.label and slot.hint, name .. " has a labelled story slot with a hint")
		local s = { Layouts.Rect(slot, slot, width, HEIGHT) }
		local story = { left = s[1], bottom = s[2], right = s[3], top = s[4] }
		assert(math.abs(story.right - (width - EDGE)) < 1e-6 and math.abs(story.right - story.left - STORY_W) < 1e-6, label .. ": the story slot is on the right rail's column, 278 wide")
		assert(math.abs(over - story.top - CARD_GAP_MIN) < 1e-6, label .. ": the story slot hangs 16 under the corrected map's caption, got " .. (over - story.top))
		assert(math.abs(story.bottom - columns[1].top - 12) < 1e-6, label .. ": the story slot ends 12 over bars 4 and 5, got " .. (story.bottom - columns[1].top))
		assert(story.top - story.bottom >= STORY_RAIL_MIN, label .. ": the story slot holds the guide and four quests, got " .. (story.top - story.bottom))
		for _, key in ipairs(KEYS) do
			local r = rect(key)
			assert(not (r.left < story.right and story.left < r.right and r.bottom < story.top and story.bottom < r.top),
				label .. ": " .. key .. " stays off the story slot")
		end

		-- The left rail's head: the party and raid card, in every layout (KSTY-57: the raid card's real size leaves the
		-- Healer layout no other room that keeps the raid warnings' lane and the tracked bars' spot).
		local party, raid = rect("groupframes.party"), rect("groupframes.raid")
		assert(raid.left == MARGIN, label .. ": the raid card stands on the left margin")
		assert(party.top == HEIGHT - MARGIN and raid.top == HEIGHT - MARGIN, label .. ": the party and raid card heads the left rail")
		local head = party

		-- The left rail holds only its head, the loot feed and chat, on one left edge (the story slot moved to the right rail).
		assert(head.left == chat.left, label .. ": the left rail's head and chat share the left edge")
		-- Apply places the quest tracker itself, so the hint names Apply and Edit Mode (round 3: Opus #4, the carry
		-- list); a refusal gets Try again on the setup summary, so the hint gives no manual move (round 4, Muse #4).
		assert(slot.hint:find("Apply places the quest tracker here", 1, true) and slot.hint:find("Edit Mode", 1, true), name .. ": the slot hint says Apply places the tracker: " .. slot.hint)
		assert(not slot.hint:find("yourself", 1, true), name .. ": and gives no drag instruction")
		assert(slot.raid == nil and slot.raidHint == nil, label .. ": no raid card reaches the right rail's story slot")

		-- Nothing but the rails' own cards enters a rail column; nothing but (in Healer) the group frames crosses the clear
		-- centre over the cluster; the boss column stays in its outer half.
		for _, key in ipairs(KEYS) do
			local r = rect(key)
			local onRail = RAIL_KEYS[name][key]
			if key == "actionbars.bar3" then
				assert(same(r.left, K.Tokens.Size("screenMargin")) and same(r.bottom, 431.5 + LIFT) and same(r.w, 489) and same(r.h, 38), label .. ": LEE-20 bar 3 keeps its spare slot above the loot feed")
				assert(r.bottom - feed.top >= 16 and same(r.bottom - rect("unitframes.castbar.player").top, 16), label .. ": bar 3 clears the feed's full reserve and the player cast by at least 16")
				assert(r.right <= width * 0.3 or r.left >= width * 0.7, label .. ": LEE-20 bar 3 stays outside the central 40% band")
			elseif not onRail then
				assert(r.left >= BAND and r.right <= width - BAND + 1e-6, label .. ": " .. key .. " stays off the rails and their gap")
			end
			local inside = r.left < mid + CLEAR.half and r.right > mid - CLEAR.half and r.bottom < CLEAR.top and r.top > CLEAR.bottom
			if EDGE_RIGHT[key] and not onRail then
				assert(r.left >= mid + CLEAR.half / 4, label .. ": " .. key .. " stays at the clear centre's outer edge")
			else
				assert(not inside, label .. ": " .. key .. " crosses the clear centre")
			end
			if HANDS[key] or CLUSTER[key] or EXTRAS[key] then
				assert(r.top <= CLEAR.bottom, label .. ": " .. key .. " sits under the clear centre with the hands")
			end
		end

		-- LEE-20: the central bars share a 491-unit column; portraits reserve space outside that column.
		local xp, bar1, vitals = rect("databars.xp"), rect("actionbars.bar1"), rect("unitframes.player")
		local essential, utility, cast = rect("cooldowns.essential"), rect("cooldowns.utility"), rect("unitframes.castbar.player")
		for _, key in ipairs({ "databars.xp", "actionbars.bar1", "actionbars.bar2", "unitframes.resource", "cooldowns.essential", "unitframes.castbar.player", "unitframes.castbar.target", "meters.swing" }) do
			assert(centred(rect(key)), label .. ": " .. key .. " is centred")
		end
		assert(same(xp.bottom, TRAY_BOTTOM - 9 * 19 / 16 - 5) and same(bar1.bottom - xp.top, TRAY_PAD + 9 * 19 / 16), label .. ": the 5-unit experience strip sits 9 px under the KSTY-44 tray card")
		local playerBar = { Layouts.Rect(Layouts.Element("unitframes.player"), layout["unitframes.player"], width, HEIGHT) }
		assert(same((playerBar[1] + playerBar[3]) / 2, (bar1.left + bar1.right) / 2), label .. ": LEE-20 the player's bars, not its external portrait reserve, stand centred over the tray")
		assert(same(vitals.left, playerBar[1] - 95.5) and same(vitals.right, playerBar[3]), label .. ": LEE-20 the player reserve extends 91.5 left for the portrait plus a 4-unit pixel-rounding buffer")
		local resource = rect("unitframes.resource")
		assert(same(resource.bottom, 421 + LIFT) and same(resource.bottom - cast.top, 5.5), label .. ": the optional class resource sits 5.5 above the player cast, clear of its label after independent pixel snapping")
		assert(same(utility.x - mid, 218) and same(utility.bottom, 335.3 + LIFT) and same(utility.left - essential.right, 15.9), label .. ": the optional utility row keeps its slot beside the resized essential row")
		local buffs, bars = rect("cooldowns.buffs"), rect("cooldowns.bars")
		assert(same(buffs.x - mid, -442.8) and same(buffs.bottom, 155.9 + LIFT) and same(vitals.left - buffs.right, 10.5), label .. ": LEE-20 the tracked buffs sit 10.5 left of the player portrait reserve")
		assert(same(bars.x - mid, -480) and same(bars.bottom, 340 + LIFT), label .. ": LEE-20 the optional tracked buff bars keep a separate slot above the icons")
		local swing = rect("meters.swing")
		assert(same(swing.bottom - resource.top, 8) and swing.bottom - cast.top >= 8 + 14, label .. ": KSTY-60 item 13: the swing line has its own slot 8 above the class resource, clear of the player cast, as in Orbs")
		local block = math.max(bars.top, essential.top, utility.top)
		local petBar, stance = rect("actionbars.pet"), rect("actionbars.stance")
		local near = K.Tokens.Size("gapLarge")
		assert(same(bar1.left - TRAY_PAD - petBar.right, near) and same(petBar.bottom, TRAY_BOTTOM), label .. ": the optional pet sockets stand beside the tray card, on its bottom edge")
		assert(same(stance.left - bar1.right - TRAY_PAD, near) and same(stance.bottom, TRAY_BOTTOM), label .. ": the optional stance sockets stand beside the tray card, on its bottom edge")
		local rep, honor = rect("databars.rep"), rect("databars.honor")
		assert(same(rep.x - mid, -337.5) and same(rep.bottom, TRAY_BOTTOM - 9 * 19 / 16 - 15) and rep.top < TRAY_BOTTOM, label .. ": the reputation line keeps its old x under the tray card's left end")
		assert(same(honor.x - mid, 337.5) and same(honor.bottom, rep.bottom), label .. ": the honour line mirrors it under the right end")
		local pet = rect("unitframes.pet")
		assert(same(pet.x - mid, -317) and same(pet.bottom, 258 + LIFT) and pet.w == 120 and pet.h == 22, label .. ": the optional pet frame keeps its original compact slot")

		-- LEE-20 places the target over the player; optional compact frames keep their previous slots.
		local target, tot = rect("unitframes.target"), rect("unitframes.targettarget")
		local focus, focusTarget = rect("unitframes.focus"), rect("unitframes.focustarget")
		assert(same(target.bottom - vitals.top, 2) and same(target.top, 320 + LIFT), label .. ": LEE-20 the target sits 2 over the player, below the cooldown row")
		assert(same(target.left, playerBar[1]) and same(target.right, playerBar[3] + 246.4), label .. ": LEE-20 the target reserve extends 230.4 right for portrait and debuffs plus a 16-unit pixel-rounding buffer")
		assert(same(focus.x - mid, -357) and same(focus.top, 540 + LIFT), label .. ": the optional focus card keeps its original slot above the centre column")
		assert(focusTarget.left == focus.left and focus.bottom - focusTarget.top >= CLUSTER_GAP and focusTarget.bottom >= block + 4, label .. ": the focus target sits under the focus card, off the hands")
		assert(same(tot.x - mid, 317) and same(tot.top, 540 + LIFT), label .. ": the optional target of target keeps its original slot opposite the focus")
		local clusterTop = 540 + LIFT
		do
			local threat = rect("meters.threat")
			assert(threat.left == tot.left and tot.bottom - threat.top == CLUSTER_GAP and threat.bottom >= block + 4, label .. ": the threat card stands under the target of target")
			assert(threat.top <= clusterTop, label .. ": the threat card stays inside the cluster")
		end
		for _, key in ipairs({ "unitframes.focus", "unitframes.focustarget", "unitframes.targettarget", "unitframes.target" }) do
			assert(rect(key).top <= clusterTop, label .. ": " .. key .. " stays inside the cluster")
		end

		-- LEE-20 keeps bar 2 over bar 1 and parks bar 3 above chat; the side columns stay unchanged.
		local SIGIL = Layouts.SIGIL_CLEAR
		assert(type(SIGIL) == "number" and SIGIL >= 16, "Layouts retains the optional upper-slot clearance")
		local bar2, targetCast = rect("actionbars.bar2"), rect("unitframes.castbar.target")
		for _, key in ipairs(KEYS) do
			if key:find("^actionbars%.") or key:find("^unitframes%.castbar%.") or key:find("^cooldowns%.") or key == "meters.swing" then
				local bar = rect(key)
				if bar.left < target.right and target.left < bar.right and bar.bottom >= target.top - 1e-6 then
					if key == "cooldowns.essential" or key == "cooldowns.utility" then
						assert(same(bar.bottom - target.top, 15.3), label .. ": LEE-20 " .. key .. " keeps the picture's exact 15.3-unit gap over the target")
					else
						assert(bar.bottom - target.top >= SIGIL - 1e-6, label .. ": " .. key .. " keeps " .. SIGIL .. " over the target, got " .. (bar.bottom - target.top))
					end
				end
			end
		end
		assert(same(cast.bottom - essential.top, 13.5) and same(targetCast.bottom, 632 + LIFT) and same(targetCast.top, 664 + LIFT), label .. ": LEE-20 the player cast sits over the cooldowns; the optional target cast keeps its top under the clear centre")
		local bar3 = rect("actionbars.bar3")
		assert(same(bar2.w, bar1.w) and same(bar2.h, bar1.h) and same(bar3.w, 489) and same(bar3.h, 38), label .. ": LEE-20 bars 1 and 2 match; spare bar 3 keeps its old button dimensions")
		assert(same(bar2.left, bar1.left) and same(bar2.bottom - bar1.top, TRAY_GAP) and same(vitals.bottom, 138 + LIFT) and vitals.bottom - bar2.top - TRAY_PAD >= 6, label .. ": bars 1 and 2 stack at the KSTY-44 tray's gap, the tray card at least 6 under the player")

		-- The boss column stands on the centre's right edge in DPS and Tank, a rail gap left of the quest card's column
		-- beside the RestedXP guide (KSTY-33, the Captain's ruling on the Fable audit), its foot a rail gap over your combat
		-- text, which rises right of the cluster. It grows up from that foot, so a single boss sits by the cluster rather than
		-- alone at the top of the screen (round 6, Grok #4); five fill the column upward.
		local boss, text = rect("unitframes.boss"), rect("combattext.player")
		do
			local column = Layouts.Story(name, HEIGHT, true).quests
			local columnLeft = Layouts.Rect(column, column, width, HEIGHT)
			assert(math.abs(boss.right - (columnLeft - 16)) < 1e-6, label .. ": the boss column stands a rail gap left of the quest card's column, got " .. boss.right .. " for " .. columnLeft)
			assert(boss.bottom - text.top == 16, label .. ": the boss column's foot stands a rail gap over your combat text, got " .. (boss.bottom - text.top))
			assert(boss.top <= HEIGHT - MARGIN, label .. ": the full column stays under the top margin")
			local up = false
			for _, entry in ipairs(Layouts.Settings(name)) do
				if entry.module == "UnitFrames" and entry.key == "boss.growth" then
					up = entry.value == "UP"
				end
			end
			assert(up, label .. ": the layout grows the boss column up from its foot")
			assert(text.left >= mid + CLEAR.half, label .. ": your combat text rises beside the clear centre")
		end
		assert(text.bottom - clusterTop >= 16, label .. ": your combat text rises over the cluster")
		assert(text.left >= utility.right or text.bottom >= utility.top, label .. ": your combat text stays off the utility cooldowns")
	end

	-- LEE-20 keeps both central action rows and the separate player cast bar on; optional slots remain available. Bars 4 and 5 stand in the right rail (the picture, LEE-20).
	for _, key in ipairs({ "actionbars.bar3", "actionbars.bar6", "unitframes.castbar.target" }) do
		assert(Layouts.Shown(name, key) == false, name .. " switches " .. key .. " off")
	end
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "unitframes.castbar.player", "actionbars.bar4", "actionbars.bar5", "actionbars.pet", "actionbars.stance", "unitframes.player", "unitframes.target", "minimap.main", "chat.main" }) do
		assert(Layouts.Shown(name, key) == true, name .. " keeps " .. key .. " on")
	end
	assert(Layouts.Shown(name, "meters.threat") == (name == "Tank"), name .. ": the threat card shows in Tank only")
	local settings = {}
	for _, entry in ipairs(Layouts.Settings(name)) do
		assert(K.Features.modules[entry.module] ~= nil and type(entry.key) == "string" and entry.value ~= nil, name .. " writes a module's setting")
		settings[entry.module .. "." .. entry.key] = entry.value
	end
	for _, i in ipairs({ 3, 6 }) do
		assert(settings["ActionBars.bar" .. i .. ".enabled"] == false, name .. " writes bar " .. i .. " off")
	end
	assert(settings["ActionBars.bar4.enabled"] == true and settings["ActionBars.bar5.enabled"] == true, name .. " writes bars 4 and 5 on, the rail's two columns")
	assert(settings["ActionBars.bar1.enabled"] == true and settings["ActionBars.bar1.rows"] == 1, name .. " writes bar 1 on, one row")
	assert(settings["ActionBars.bar2.enabled"] == true and settings["ActionBars.bar2.rows"] == 1, name .. ": LEE-20 writes bar 2 on, one row")
	assert(settings["ActionBars.pet.rows"] == 3 and settings["ActionBars.stance.rows"] == 3, name .. " folds the pet and stance sockets into three rows of four beside the tray")
	assert(settings["ActionBars.stance.growth"] == "RIGHTUP", name .. " grows the stance sockets up from bar 1's baseline")
	assert(settings["UnitFrames.boss.auraPosition"] == "LEFT", name .. " hangs the boss debuffs towards the centre")
	assert(settings["ActionBars.bar1.showEmpty"] == true and settings["ActionBars.bar2.showEmpty"] == true, name .. ": LEE-20 shows both central bars' empty tiles")
	for _, i in ipairs({ 3, 6 }) do
		assert(settings["ActionBars.bar" .. i .. ".showEmpty"] == false, name .. " hides bar " .. i .. "'s empty sockets")
	end
	assert(settings["ActionBars.bar4.showEmpty"] == false and settings["ActionBars.bar5.showEmpty"] == false, name .. " draws only the filled slots of the rail columns at rest (KSTY-34); dragging an action or Layout Mode shows the rest")
	assert(settings["Meters.threat.shown"] == (name == "Tank"), name .. " writes the threat card's switch")
	assert(settings["DataBars.strip.menus"] == false, name .. " leaves the menu and the bags out of the readout line")
	-- Apply sizes the meters: six damage rows, or in Tank two damage rows over two threat rows, so the rail fits.
	local sizes = Layouts.Sizes(name)
	for key, size in pairs(sizes) do
		local w, h = Layouts.Footprint(name, key)
		assert(size.width == w and size.height == h, name .. " writes " .. key .. " at its footprint")
	end
	assert(sizes["meters.damage"].width == 269 and sizes["meters.damage"].height == 158, name .. ": the picture's 269 x 158 damage card")
	assert(settings["GroupFrames.raid.groupsPerRow"] == 4, name .. " folds the raid into four groups a row, for the rail")
	assert(settings["GroupFrames.raid.width"] == nil and settings["GroupFrames.party.spacing"] == nil, name .. " keeps the KSTY-47 mock-ups' cell width and party pitch (KSTY-57)")
end
do
	local function h(name, key)
		return select(2, Layouts.Footprint(name, key))
	end
	assert(h("Healer", "groupframes.party") > h("DPS", "groupframes.party") and Layouts.Footprint("Healer", "groupframes.raid") > Layouts.Footprint("DPS", "groupframes.raid"), "Healer gets taller party rows and wider raid rows")
	-- KSTY-57: a healer's raid card (623 wide at 20 players) left the Healer layout no room for the raid warnings'
	-- lane or the tracked bars' only Healer spot by the cluster, so Healer keeps the DPS places for its party, raid,
	-- boss column and combat text.
	local healerAt, dpsAt = Layouts.Get("Healer"), Layouts.Get("DPS")
	for _, key in ipairs({ "groupframes.party", "groupframes.raid", "unitframes.boss", "combattext.player" }) do
		local a, b = healerAt[key], dpsAt[key]
		assert(a.anchor == b.anchor and a.x == b.x and a.y == b.y, "Healer keeps the DPS place for " .. key)
	end
	local threatW, threatH = Layouts.Footprint("Tank", "meters.threat")
	assert(threatW == 200 and threatH == 112, "Tank sizes the threat card to the cluster's side, 200 by 112, got " .. threatW .. " x " .. threatH)
	local hs = {}
	for _, entry in ipairs(Layouts.Settings("Healer")) do hs[entry.module .. "." .. entry.key] = entry.value end
	assert(hs["GroupFrames.party.auraDispelCount"] == 2 and hs["GroupFrames.raid.auraDispelCount"] == 2, "Healer shows up to two dispellable debuffs first on every frame")
	assert(h("Tank", "groupframes.party") == h("DPS", "groupframes.party"), "Tank keeps the DPS party card")
	local dps, healer = {}, {}
	for _, entry in ipairs(Layouts.Settings("DPS")) do dps[entry.module .. "." .. entry.key] = entry.value end
	for _, entry in ipairs(Layouts.Settings("Healer")) do healer[entry.module .. "." .. entry.key] = entry.value end
	assert(healer["GroupFrames.party.height"] > dps["GroupFrames.party.height"] and healer["GroupFrames.raid.height"] == dps["GroupFrames.raid.height"], "Healer writes taller party rows; its raid rows keep the DPS height, so the 40-player card stays 401 tall")
	local spacing = 13
	local party = 5 * healer["GroupFrames.party.height"] + 4 * spacing
	assert(5 * dps["GroupFrames.party.height"] + 4 * spacing <= h("DPS", "groupframes.party"), "the DPS party fits its card")
	assert(party <= h("Healer", "groupframes.party"), "the Healer party fits its card, got " .. party)
	-- The tallest Healer raid card: 40 players, two rows of four groups of compact rows (8 shorter, 6 apart), in the
	-- card's 20-unit padding under its 12-unit cap and 8-unit gap.
	local raid = 2 * (5 * (healer["GroupFrames.raid.height"] - 8) + 4 * 6) + 13 + 20 + 12 + 8 + 20
	assert(raid <= h("Healer", "groupframes.raid"), "the Healer raid fits its card, got " .. raid)
	assert(Layouts.Shown("Raid", "actionbars.bar1") == nil and Layouts.Settings("Raid") == nil and Layouts.Slot("Raid") == nil and Layouts.Sizes("Raid") == nil, "an unknown layout gives nil")
end

-- LEE-20 supersedes the common 38-unit size: essential icons match the 36.7 action tiles,
-- tracked buffs include their timer row, and unchanged utility icons retain their optional 38-unit slot.
do
	assert(same(Layouts.Element("actionbars.bar1").height, TRAY_TILE) and same(Layouts.Element("cooldowns.essential").height, 36.7), "the action tiles take the KSTY-44 tray's 38 px; essential icons keep LEE-20's 36.7")
	assert(same(Layouts.Element("cooldowns.utility").height, 38) and same(Layouts.Element("cooldowns.buffs").height, 41.6), "LEE-20 utility keeps its size and tracked buffs include timers")
	assert(same(select(2, Layouts.Footprint("DPS", "unitframes.player")), 77.5), "LEE-20 the player frame is 77.5 tall with its cast in a separate element")
	for _, key in ipairs({ "unitframes.targettarget", "unitframes.focustarget", "unitframes.pet" }) do
		assert(Layouts.Element(key).height < 36, key .. " stays a compact frame")
	end
end

-- Footprints: LEE-20 centre dimensions and unchanged optional frames and rail cards. ----------------------------
local FOOTPRINTS = {
	["actionbars.bar1"] = { TRAY_ROW, TRAY_TILE },
	["actionbars.bar2"] = { TRAY_ROW, TRAY_TILE },
	["actionbars.bar3"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar4"] = { 36.7, 12 * 36.7 + 11 * 4.6 },
	["actionbars.bar5"] = { 36.7, 12 * 36.7 + 11 * 4.6 },
	["actionbars.bar6"] = { 36.7, 12 * 36.7 + 11 * 4.6 },
	["actionbars.pet"] = { 4 * 30 + 3 * 3, 3 * 30 + 2 * 3 },
	["actionbars.stance"] = { 4 * 30 + 3 * 3, 3 * 30 + 2 * 3 },
	-- LEE-20 reserves external portraits and target debuffs; the optional focus retains its 22-unit aura reserve.
	["cooldowns.essential"] = { 243.2, 36.7 },
	["cooldowns.utility"] = { 4 * 38 + 3 * 3, 38 },
	["cooldowns.buffs"] = { 182.6, 41.6 },
	["cooldowns.bars"] = { 6 * 38 + 5 * 3, 2 * 20 + 3 },
	["unitframes.player"] = { 586.5, 77.5 },
	["unitframes.target"] = { 737.4, 102.5 },
	["unitframes.boss"] = { 318, 334 },
	["unitframes.targettarget"] = { 120, 22 },
	["unitframes.pet"] = { 120, 22 },
	["unitframes.focustarget"] = { 120, 22 },
	["unitframes.focus"] = { 200, 112 },
	["unitframes.castbar.player"] = { 347, 30 },
	["unitframes.castbar.target"] = { 220, 32 },
	-- S4 (#157): six damage rows, four threat rows, the readout with the menu docked (at 318 the bag bar wraps under
	-- the micro menu: 118 holds both rows, with 3 units for the owner's pixel snapping), the party card. Chat is the
	-- picture's 393 by 186 card at the left rail's foot (LEE-20, LEE-69).
	-- The owner's picture (LEE-20): a 188 square map with its zone, coordinates and clock in 36 units under it; one
	-- row of ten 27.5-unit aura icons each (test-setup-collisions.lua and test-auras-counts.lua measure the live rows at
	-- 0 to 40 buffs); the 269 x 158 damage card; the readout as one 12-unit line.
	["minimap.main"] = { 188, 202 },
	["auras.buffs"] = { 306.5, 41.5 },
	["auras.debuffs"] = { 306.5, 41.5 },
	["meters.damage"] = { 269, 158 },
	["meters.threat"] = { 200, 112 },
	["databars.strip"] = { 278, 12 },
	["databars.micro"] = { 318, 44 },
	["chat.main"] = { 393, 186 },
	["groupframes.party"] = { 318, 324 },
	["groupframes.raid"] = { 543, 401 },
	["databars.xp"] = { 491, 5 },
	["databars.rep"] = { 162, 5 },
	["databars.honor"] = { 162, 5 },
}
for key, size in pairs(FOOTPRINTS) do
	local w, h = Layouts.Footprint("DPS", key)
	assert(same(w, size[1]) and same(h, size[2]), key .. " is " .. size[1] .. " x " .. size[2] .. " in Lumen, got " .. w .. " x " .. h)
end

-- Every element builds at its footprint (Element) and the layouts place it there, except a reserve and the sizes a
-- layout writes on Apply (the Tank meters).
do
	-- LEE-20 adds asymmetric portrait reserves; focus auras, boss debuffs and docked menus retain their reserves. The map's zone, coordinates and clock hang
	-- in the 36 units under its 188 square.
	local RESERVES = { ["unitframes.player"] = { 586.5, 77.5, -47.75 }, ["unitframes.target"] = { 737.4, 102.5, 123.2 }, ["unitframes.focus"] = { 200, 112 }, ["unitframes.boss"] = { 318, 334 }, ["minimap.main"] = { 188, 202 } }
	local reserved = {}
	for _, entry in ipairs(Layouts.Reserves()) do
		local want = RESERVES[entry.key]
		assert(want and want[1] == entry.width and want[2] == entry.height, entry.key .. " reserves " .. entry.width .. " x " .. entry.height)
		assert(entry.offsetX == want[3], entry.key .. " reserves its asymmetric portrait offset")
		reserved[entry.key] = true
	end
	for key in pairs(RESERVES) do
		assert(reserved[key], key .. " has its reserve")
	end
	local target, boss, focus = Layouts.Element("unitframes.target"), Layouts.Element("unitframes.boss"), Layouts.Element("unitframes.focus")
	assert(target.width == 491 and target.height == 102.5 and Layouts.Get("DPS")["unitframes.target"].anchor == "BOTTOM", "LEE-20 the target's bar column anchors its portrait and aura reserve from the bottom")
	assert(focus.width == 200 and focus.height == 90 and Layouts.Get("DPS")["unitframes.focus"].anchor == "BOTTOM", "the focus card's frame foots its reserve, so its debuffs sit inside it")
	assert(boss.width == 222 and boss.height == 5 * 62 + 4 * 6, "the boss column holds five 62-unit cards 6 apart, 222 wide beside a row of four 22-unit debuffs")
	for _, element in ipairs(Layouts.ELEMENTS) do
		if not RESERVES[element.key] then
			local w, h = Layouts.Footprint("DPS", element.key)
			assert(element.width == w and element.height == h, element.key .. " builds at its DPS footprint")
		end
	end
end
do
	local minimap = Layouts.Get("DPS")["minimap.main"]
	assert(minimap.anchor == "TOPRIGHT" and minimap.x == -(EDGE - 1) and minimap.y == -(EDGE - 1 + MAP_HEADING), "the square map sits one root unit nearer the right than the card margin, under its 22-unit zone heading")
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
