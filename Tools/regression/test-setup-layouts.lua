-- test-setup-layouts.lua: the Lumen DPS, Tank and Healer layouts place every known element key on screen, apart, on two rails around a clear centre, as the Lumen Rails mockup shows.
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
	"qol.lootfeed",
	"tooltips.anchor",
}
local ANCHORS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
-- Party and raid frames never show together, so they may share space.
local EXCLUSIVE = { ["groupframes.party"] = "groupframes.raid", ["groupframes.raid"] = "groupframes.party" }
-- 16:9 at three sizes, a MacBook, the owner's 2383 x 1540, 16:10 and 21:9: at the Interface size KstyleUI ships
-- (16 / 19) the root is Layouts.HEIGHT (1282.5) units tall on each.
local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 3456, 2234 }, { 2383, 1540 }, { 2560, 1600 }, { 3440, 1440 } }
local HEIGHT = Layouts.HEIGHT

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

-- Size(name, key) -> the footprint the layout plans for: the element's, or the layout's own where it differs.
local function Size(name, key)
	local w, h = Layouts.Footprint(name, key)
	return { width = w, height = h }
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
		-- A docked element sits inside its host card; a threat card a layout switches off waits on the damage card's place.
		local function shares(a, c)
			if Layouts.Dock(a) == c or Layouts.Dock(c) == a then
				return true
			end
			local threat = a == "meters.threat" and c or (c == "meters.threat" and a)
			return threat == "meters.damage" and Layouts.Shown(name, "meters.threat") == false
		end
		-- Bars 2 to 6 are off in every layout, but each keeps a free slot on every screen, the owner's narrow 1.547 one
		-- included (owner pass 1, 2026-11-09: "not much room for adding more action bars").
		for i = 1, #KEYS do
			for j = i + 1, #KEYS do
				local a, c = KEYS[i], KEYS[j]
				if EXCLUSIVE[a] ~= c and not shares(a, c) and overlap(rects[a], rects[c]) then
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

-- Lumen Rails (handoff/arena2/parent: index.html, NOTES.md and the two HUD boards) ------------------------
-- Two 318-unit rails on the screen margin (17 units, the owner's picture of 2026-11-09) hold everything slow: in DPS and Tank the left rail the party and chat, the
-- right rail the map with the aura rows, the story slot, the damage card and the readout and menu. The
-- centre holds one combat cluster at the bottom: the hands, and right on them the target sigil, with the focus on its
-- left and the target of target on its right (in Tank the threat card under it), so you, your target, its target and
-- your focus read in one glance (round 2: Muse #1, Opus's eye travel). The boss column heads the centre's right edge,
-- 16 units in from the right rail. The world above the cluster stays clear. Healer stands the party and raid on the
-- cluster's left half, clear of the cast bars, heads the left rail with the boss column and keeps the right rail's
-- damage card under the aura rows, as DPS does (round 3: the buffs at 40 and 12 debuffs left no room for the boss
-- column on the right rail; Muse #2: the cast bars stay in the cluster).

local MARGIN, RAIL = 17, 318
local BAND = MARGIN + RAIL + 16
local CARD_GAP_MIN = 16
local LEFT_RAIL = {
	DPS = { "groupframes.party", "groupframes.raid", "qol.lootfeed" },
	Tank = { "groupframes.party", "groupframes.raid", "qol.lootfeed" },
	Healer = { "unitframes.boss", "qol.lootfeed" },
}
-- The picture (LEE-20) draws the chat card 393 by 200. DPS and Tank take that width. Healer keeps the 318 rail:
-- on a 2383 x 1540 screen at UI scale 1, six tracked bars do not fit beside a 393 card (test-setup-editmode.lua).
local CHAT_WIDTH = { DPS = 393, Tank = 393, Healer = 318 }
-- The right rail (owner, 2026-11-09: "The quest tracker can go back to the right side for better alignment"): the map
-- heads it with the aura rows beside it; the story slot (the quest card, under the RestedXP guide when it is loaded)
-- hangs 16 under the lower of the two, where a tracker sits in the classic UI, so the quests read right under the map.
-- The damage card stands on the readout card at the rail's foot, 16 over it, and the tooltip anchor 8 over the damage
-- card: a tooltip grows up over the story slot's foot, never over the damage meter you read in combat. The story slot
-- ends 16 over the tooltip anchor.
local RIGHT_STACK = {
	DPS = { "minimap.main", "meters.damage" },
	Tank = { "minimap.main", "meters.damage" },
	Healer = { "minimap.main", "meters.damage" },
}
local STORY_RAIL_MIN = 560
-- The aura rows (owner pass 1): two 282 x 88 blocks beside the map's left edge, top-aligned with it, the debuffs 16
-- under the buffs, growing left; they are not part of the rail's stack.
local AURA_ROWS = { "auras.buffs", "auras.debuffs" }
local DOCKED = { ["databars.micro"] = "databars.strip", ["databars.bags"] = "databars.strip" }
local HANDS = set({
	"databars.xp", "databars.rep", "databars.honor", "actionbars.bar1", "actionbars.pet", "actionbars.stance",
	"unitframes.player", "unitframes.pet", "unitframes.resource", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs",
	"cooldowns.bars", "meters.swing",
})
-- The combat cluster on the hands: the sigil, the focus and its target, the target of target, and in Tank the threat card.
local CLUSTER = set({ "unitframes.target", "unitframes.targettarget", "unitframes.focus", "unitframes.focustarget" })
-- What a player turns on over the cluster: the plate cast bars.
local EXTRAS = set({ "unitframes.castbar.player", "unitframes.castbar.target" })
-- The world kept clear (system board): the centre 520 units wide, from the top of what stacks on the cluster (the plate
-- cast bars, 664 now that the hands keep bars 2 and 3 a slot each) to the top.
local CLEAR = { half = 260, bottom = 664, top = HEIGHT - 28 }
-- The boss column at the clear centre's edge: on a 16:10 screen it reaches into the zone's outer half, never past it.
local EDGE_RIGHT = set({ "unitframes.boss" })
local RAIL_KEYS = {
	DPS = set({ "groupframes.party", "groupframes.raid", "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "meters.threat", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
	Tank = set({ "groupframes.party", "groupframes.raid", "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
	Healer = set({ "chat.main", "qol.lootfeed", "minimap.main", "auras.buffs", "auras.debuffs", "unitframes.boss",
		"meters.damage", "meters.threat", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
}
-- Healer: the party and raid stand on the cluster's left half, their right edge 16 units left of the player's cast bar
-- (152 off the centre line) and their foot 16 over the cluster's top; the character's column (centre +- 100) stays clear.
local HEALER = { right = 152, gap = 16, character = 100 }
-- The cluster's sizes: the sigil spans the vitals line; the cards beside it sit 12 out from it.
local NEAR, CLUSTER_GAP = 12, 4
local GROUP = set({ "groupframes.party", "groupframes.raid" })

for _, name in ipairs(names) do
	local layout = Layouts.Get(name)
	local healer = name == "Healer"
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
		for _, key in ipairs(RIGHT_STACK[name]) do
			local r = rect(key)
			-- Owner pass 1: the minimap is a 160 square at the rail's head, flush with the rail's right edge; the aura rows
			-- are narrower than the rail (eight 30-unit tiles, 282) and sit right-aligned on it.
			local wantWidth = key == "minimap.main" and 160 or RAIL
			assert(math.abs(r.right - (width - MARGIN)) < 1e-6 and r.w == wantWidth, label .. ": " .. key .. " sits on the right rail, " .. wantWidth .. " wide on the margin")
		end
		do
			local map, buffs, debuffs = rect("minimap.main"), rect(AURA_ROWS[1]), rect(AURA_ROWS[2])
			assert(math.abs(buffs.right - (map.left - 16)) < 1e-6 and buffs.top == map.top, label .. ": the buff rows stand 16 left of the map, top-aligned with it")
			assert(buffs.right == debuffs.right and math.abs(buffs.bottom - 16 - debuffs.top) < 1e-6, label .. ": the debuff rows hang 16 under the buffs")
			assert(buffs.w == 282 and buffs.h == 88 and debuffs.w == 282 and debuffs.h == 88, label .. ": each aura block is 282 x 88")
		end
		local strip = rect("databars.strip")
		assert(math.abs(strip.right - (width - MARGIN)) < 1e-6 and strip.w == RAIL and strip.bottom == MARGIN, label .. ": the readout and menu card sits on the right rail's foot")
		-- Docked: the menu and the bag bar in the readout card. Each sits inside its host, where it stays when the player
		-- undocks it.
		for key, host in pairs(DOCKED) do
			assert(Layouts.Dock(key) == host, key .. " docks into " .. host)
			local r, h = rect(key), rect(host)
			assert(r.left >= h.left and r.right <= h.right + 1e-6 and r.bottom >= h.bottom and r.top <= h.top, label .. ": " .. key .. " sits inside " .. host)
		end
		-- The tooltip anchor sits just over the damage card's right corner, on no card (round 2: Fable R2-7): a tooltip
		-- grows up the rail from it, so hovering the micro menu never covers the menu, the readout or the damage meter.
		local tip, meter = rect("tooltips.anchor"), rect("meters.damage")
		assert(math.abs(tip.right - meter.right) < 1e-6 and tip.bottom - meter.top == 8, label .. ": the tooltip anchor sits 8 over the damage card's right corner")
		assert(meter.bottom - strip.top == 16, label .. ": the damage card stands 16 over the readout card at the rail's foot, got " .. (meter.bottom - strip.top))
		local chat = rect("chat.main")
		local margin = K.Tokens.Size("screenMargin")
		assert(chat.bottom == margin and chat.left == margin and chat.w == CHAT_WIDTH[name] and chat.h == 200, label .. ": chat sits on the screenMargin token, " .. CHAT_WIDTH[name] .. " by 200, got " .. chat.w .. " by " .. tostring(chat.h))
		local feed = rect("qol.lootfeed")
		assert(feed.left == chat.left and feed.w == RAIL and math.abs(feed.bottom - chat.top - 2) < 1e-6, label .. ": the loot feed's foot sits 2 units over the chat card, so the lowest line is the picture's 22 px up, got " .. (feed.bottom - chat.top))
		for _, key in ipairs(KEYS) do
			local r = rect(key)
			if key ~= "chat.main" and key ~= "qol.lootfeed" and r.bottom < chat.top + CARD_GAP_MIN and r.top > chat.bottom - CARD_GAP_MIN then
				assert(r.left - chat.right >= CARD_GAP_MIN or r.right <= chat.left, label .. ": " .. key .. " keeps " .. CARD_GAP_MIN .. " units clear of the chat card, got " .. (r.left - chat.right))
			end
		end

		-- The right rail, top to bottom: the map with the aura rows beside it, the story slot, the tooltip anchor, the
		-- damage card, the readout. The aura rows reach into the rail's column (282 wide against a 160 map) and lower
		-- than the map, so the story slot clears them too.
		local map = rect("minimap.main")
		assert(map.top == HEIGHT - MARGIN, label .. ": the square map heads the right rail")
		local rows = rect(AURA_ROWS[2])
		local over = math.min(map.bottom, rows.bottom)
		local slot = Layouts.Slot(name)
		assert(slot and slot.anchor and slot.label and slot.hint, name .. " has a labelled story slot with a hint")
		local s = { Layouts.Rect(slot, slot, width, HEIGHT) }
		local story = { left = s[1], bottom = s[2], right = s[3], top = s[4] }
		assert(math.abs(story.right - (width - MARGIN)) < 1e-6 and math.abs(story.right - story.left - RAIL) < 1e-6, label .. ": the story slot is on the right rail's column, 318 wide")
		assert(math.abs(over - story.top - CARD_GAP_MIN) < 1e-6, label .. ": the story slot hangs 16 under the map and the aura rows, got " .. (over - story.top))
		assert(math.abs(story.bottom - tip.top - CARD_GAP_MIN) < 1e-6, label .. ": the story slot ends 16 over the tooltip anchor, got " .. (story.bottom - tip.top))
		assert(story.top - story.bottom >= STORY_RAIL_MIN, label .. ": the story slot holds the guide and the quests, got " .. (story.top - story.bottom))
		for _, key in ipairs(KEYS) do
			local r = rect(key)
			assert(not (r.left < story.right and story.left < r.right and r.bottom < story.top and story.bottom < r.top),
				label .. ": " .. key .. " stays off the story slot")
		end

		-- The left rail's head: the party and raid card, or in Healer the boss column.
		local party, raid = rect("groupframes.party"), rect("groupframes.raid")
		local head
		if healer then
			head = rect("unitframes.boss")
			assert(head.top == HEIGHT - MARGIN, label .. ": the boss column heads the left rail")
		else
			assert(party.top == HEIGHT - MARGIN and raid.top == HEIGHT - MARGIN, label .. ": the party and raid card heads the left rail")
			head = party
		end

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
			if not onRail then
				assert(r.left >= BAND and r.right <= width - BAND + 1e-6, label .. ": " .. key .. " stays off the rails and their gap")
			end
			local inside = r.left < mid + CLEAR.half and r.right > mid - CLEAR.half and r.bottom < CLEAR.top and r.top > CLEAR.bottom
			if healer and GROUP[key] then
				assert(r.right <= mid - HEALER.right + 1e-6 and r.right <= mid - HEALER.character, label .. ": " .. key .. " stays left of the character's column")
				assert(r.left >= BAND, label .. ": " .. key .. " stays off the left rail")
			elseif healer and key == "combattext.player" then
				-- Healer mirrors the group frames: your combat text rises right of the cast bars as the group frames stand
				-- left of them, the same 152 off the centre line.
				assert(math.abs(r.left - (mid + HEALER.right)) < 1e-6, label .. ": your combat text mirrors the group frames right of the cast bars")
			elseif EDGE_RIGHT[key] and not onRail then
				assert(r.left >= mid + CLEAR.half / 2, label .. ": " .. key .. " stays at the clear centre's outer edge")
			else
				assert(not inside, label .. ": " .. key .. " crosses the clear centre")
			end
			if HANDS[key] or CLUSTER[key] or EXTRAS[key] then
				assert(r.top <= CLEAR.bottom, label .. ": " .. key .. " sits under the clear centre with the hands")
			end
		end

		-- The hands, bottom to top: the XP line, one row of bar 1, the vitals line, the cooldowns with the swing line on them.
		local xp, bar1, vitals = rect("databars.xp"), rect("actionbars.bar1"), rect("unitframes.player")
		local essential, utility, cast = rect("cooldowns.essential"), rect("cooldowns.utility"), rect("unitframes.castbar.player")
		for _, key in ipairs({ "databars.xp", "actionbars.bar1", "unitframes.player", "unitframes.resource", "cooldowns.essential", "unitframes.castbar.player", "unitframes.castbar.target", "meters.swing", "unitframes.target" }) do
			assert(centred(rect(key)), label .. ": " .. key .. " is centred")
		end
		assert(xp.bottom - 34 >= 14 and xp.bottom - 34 <= 20, label .. ": the XP line sits 34 units up with room for its caption under it")
		assert(bar1.bottom - xp.top == 12, label .. ": bar 1 sits 12 over the XP line, as the mockup")
		assert(vitals.bottom - bar1.top == 2 * (38 + 3) + 12, label .. ": the vitals line sits 12 over the two bar slots kept over bar 1")
		assert(math.abs(vitals.w - bar1.w) <= 2, label .. ": the vitals line spans bar 1")
		local resource = rect("unitframes.resource")
		assert(resource.bottom >= vitals.top and essential.bottom >= resource.top, label .. ": the class resource sits between the vitals and the cooldowns")
		assert(essential.bottom - vitals.top <= 40, label .. ": the essential cooldowns sit just over the vitals")
		assert(utility.bottom == essential.bottom and utility.left - essential.right == 16, label .. ": the utility cooldowns sit beside the essential ones")
		local buffs, bars = rect("cooldowns.buffs"), rect("cooldowns.bars")
		assert(buffs.bottom == essential.bottom and essential.left - buffs.right >= 16, label .. ": the tracked buff icons sit beside the essential cooldowns' other end")
		assert(bars.bottom >= buffs.top + 4 and bars.left == buffs.left, label .. ": the tracked buff bars sit over the icons")
		local swing = rect("meters.swing")
		assert(swing.bottom - essential.top >= 4 and swing.bottom - essential.top <= 8, label .. ": the swing line sits on the essential cooldowns, part of the hands, not a stray bar")
		local block = math.max(swing.top, bars.top, essential.top, utility.top)
		local petBar, stance = rect("actionbars.pet"), rect("actionbars.stance")
		assert(petBar.right == bar1.left - 12 and petBar.bottom == bar1.bottom, label .. ": the pet sockets sit beside bar 1's left end")
		assert(stance.left == bar1.right + 12 and stance.bottom == bar1.bottom, label .. ": the stance sockets sit beside bar 1's right end")
		local rep, honor = rect("databars.rep"), rect("databars.honor")
		assert(rep.bottom == xp.bottom and rep.left == petBar.left and rep.right == petBar.right, label .. ": the reputation line runs under the pet sockets on the XP line's baseline")
		assert(honor.bottom == xp.bottom and honor.left == stance.left and honor.right == stance.right, label .. ": the honour line runs under the stance sockets on the XP line's baseline")
		local pet = rect("unitframes.pet")
		assert(pet.right == vitals.left - 12 and pet.top == vitals.top, label .. ": the pet frame sits beside the vitals line's ring, top-aligned")

		-- The combat cluster, in every layout: the sigil right on the hands block and as wide as the vitals line, so your
		-- target reads straight over you; the focus card on its left with the focus target under it; the target of target
		-- on its right, top-aligned. In Tank the threat card stands under the target of target.
		local sigil, tot = rect("unitframes.target"), rect("unitframes.targettarget")
		local focus, focusTarget = rect("unitframes.focus"), rect("unitframes.focustarget")
		assert(sigil.bottom >= block + 4 and sigil.bottom - block <= 16, label .. ": the sigil sits right on the hands block (" .. (sigil.bottom - block) .. " over)")
		assert(sigil.w == vitals.w, label .. ": the sigil spans the vitals line, one column")
		assert(sigil.top - vitals.top <= 260, label .. ": your target reads within 260 units of you, not a screen away")
		assert(sigil.left - focus.right == NEAR and focus.top == sigil.top, label .. ": the focus card sits 12 left of the sigil, top-aligned")
		assert(focusTarget.left == focus.left and focus.bottom - focusTarget.top >= CLUSTER_GAP and focusTarget.bottom >= block + 4, label .. ": the focus target sits under the focus card, off the hands")
		assert(tot.left - sigil.right == NEAR and tot.top == sigil.top, label .. ": the target of target sits 12 right of the sigil, top-aligned")
		local clusterTop = sigil.top
		if name == "Tank" then
			local threat = rect("meters.threat")
			assert(threat.left == tot.left and tot.bottom - threat.top == CLUSTER_GAP and threat.bottom >= block + 4, label .. ": the threat card stands under the target of target")
			assert(threat.top <= clusterTop, label .. ": the threat card stays inside the cluster")
		end
		for _, key in ipairs({ "unitframes.focus", "unitframes.focustarget", "unitframes.targettarget", "unitframes.target" }) do
			assert(rect(key).top <= clusterTop, label .. ": " .. key .. " stays inside the cluster")
		end

		-- What a player turns on (owner pass 1, 2026-11-09): bars 2 and 3 are rows of twelve stacked over bar 1, under
		-- the vitals line, as Blizzard stacks its bottom bars; bars 4, 5 and 6 are columns on the right edge of the play
		-- field, a rail gap left of the right rail, in every layout. The plate cast bars keep their place over the
		-- cluster, Layouts.SIGIL_CLEAR and one bar's room over the sigil cap (round 4, Opus #6).
		local SIGIL = Layouts.SIGIL_CLEAR
		assert(type(SIGIL) == "number" and SIGIL >= 16, "Layouts names the gap a bar keeps over the sigil cap")
		local bar2, targetCast = rect("actionbars.bar2"), rect("unitframes.castbar.target")
		local target = rect("unitframes.target")
		for _, key in ipairs(KEYS) do
			if key:find("^actionbars%.") or key:find("^unitframes%.castbar%.") or key:find("^cooldowns%.") or key == "meters.swing" then
				local bar = rect(key)
				if bar.left < target.right and target.left < bar.right and bar.bottom >= target.top - 1e-6 then
					assert(bar.bottom - target.top >= SIGIL - 1e-6, label .. ": " .. key .. " keeps " .. SIGIL .. " over the target's sigil cap, got " .. (bar.bottom - target.top))
				end
			end
		end
		assert(cast.bottom - clusterTop == SIGIL + 38 + 8 and targetCast.bottom - cast.top == 8, label .. ": the plate cast bars stay over the cluster")
		local bar3 = rect("actionbars.bar3")
		assert(bar2.w == bar1.w and bar3.w == bar1.w and bar2.h == bar1.h and bar3.h == bar1.h, label .. ": bars 2 and 3 are rows like bar 1")
		assert(bar2.left == bar1.left and bar2.bottom - bar1.top == 3 and bar3.left == bar1.left and bar3.bottom - bar2.top == 3, label .. ": bars 2 and 3 stack over bar 1 at the bar pitch")
		assert(vitals.bottom - bar3.top == 12, label .. ": the vitals line sits 12 over bar 3's slot")
		local right = width - BAND
		for i, key in ipairs({ "actionbars.bar4", "actionbars.bar5", "actionbars.bar6" }) do
			local bar = rect(key)
			assert(math.abs(bar.w - bar1.h) < 1e-6 and math.abs(bar.h - bar1.w) < 1e-6, label .. ": " .. key .. " is a column of twelve")
			assert(math.abs(bar.right - right) < 1e-6 and math.abs(bar.y - HEIGHT / 2) < 1e-6, label .. ": " .. key .. " stands on the right edge of the play field, centred on the screen")
			right = bar.left - 3
			assert(i < 3 or bar.left >= mid + CLEAR.half, label .. ": the side bars stay out of the clear centre")
		end
		if healer then
			for _, key in ipairs({ "groupframes.party", "groupframes.raid" }) do
				assert(rect(key).bottom - clusterTop == HEALER.gap, label .. ": " .. key .. " stands 16 over the cluster")
			end
		end

		-- The boss column stands on the centre's right edge in DPS and Tank, a rail gap left of the side bars' slots, its
		-- foot a rail gap over your combat text, which rises right of the cluster. It grows up from that foot, so a single boss sits
		-- by the cluster rather than alone at the top of the screen (round 6, Grok #4); five fill the column upward.
		local boss, text = rect("unitframes.boss"), rect("combattext.player")
		if not healer then
			assert(math.abs(boss.right - (rect("actionbars.bar6").left - 16)) < 1e-6, label .. ": the boss column stands on the right edge of the centre, a rail gap left of the side bars")
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

	-- Bars 2 to 6 are off in Lumen; bar 1 and the socket rows are on. The threat card shows in Tank only. The cast bar
	-- elements are off: S2's vitals line and sigil carry their cast lines.
	for _, key in ipairs({ "actionbars.bar2", "actionbars.bar3", "actionbars.bar4", "actionbars.bar5", "actionbars.bar6", "unitframes.castbar.player", "unitframes.castbar.target" }) do
		assert(Layouts.Shown(name, key) == false, name .. " switches " .. key .. " off")
	end
	for _, key in ipairs({ "actionbars.bar1", "actionbars.pet", "actionbars.stance", "unitframes.player", "unitframes.target", "minimap.main", "chat.main" }) do
		assert(Layouts.Shown(name, key) == true, name .. " keeps " .. key .. " on")
	end
	assert(Layouts.Shown(name, "meters.threat") == (name == "Tank"), name .. ": the threat card shows in Tank only")
	local settings = {}
	for _, entry in ipairs(Layouts.Settings(name)) do
		assert(K.Features.modules[entry.module] ~= nil and type(entry.key) == "string" and entry.value ~= nil, name .. " writes a module's setting")
		settings[entry.module .. "." .. entry.key] = entry.value
	end
	for i = 2, 6 do
		assert(settings["ActionBars.bar" .. i .. ".enabled"] == false, name .. " writes bar " .. i .. " off")
	end
	assert(settings["ActionBars.bar1.enabled"] == true and settings["ActionBars.bar1.rows"] == 1, name .. " writes bar 1 on, one row")
	assert(settings["ActionBars.pet.rows"] == 2 and settings["ActionBars.stance.rows"] == 2, name .. " folds the pet and stance sockets into two rows of five")
	assert(settings["ActionBars.stance.growth"] == "RIGHTUP", name .. " grows the stance sockets up from bar 1's baseline")
	assert(settings["UnitFrames.boss.auraPosition"] == (name == "Healer" and "RIGHT" or "LEFT"), name .. " hangs the boss debuffs towards the centre")
	-- Bar 1 keeps its empty sockets as quiet 35% sockets (first in-game test, 2026-11-09: at level 10 bar 1 showed
	-- slots 1-3 and 11-12 with a wide hole between them, which read as broken; round 3's hidden sockets are undone).
	-- The other bars are off in Lumen and still hide theirs. A spell on the cursor shows every socket to drop it on.
	assert(settings["ActionBars.bar1.showEmpty"] == true, name .. " shows bar 1's empty sockets, quiet, so the bar reads as one row")
	for i = 2, 6 do
		assert(settings["ActionBars.bar" .. i .. ".showEmpty"] == false, name .. " hides bar " .. i .. "'s empty sockets")
	end
	assert(settings["Meters.threat.shown"] == (name == "Tank"), name .. " writes the threat card's switch")
	assert(settings["DataBars.strip.menus"] == true, name .. " docks the menu and the bags in the readout card")
	-- Apply sizes the meters: six damage rows, or in Tank two damage rows over two threat rows, so the rail fits.
	local sizes = Layouts.Sizes(name)
	for key, size in pairs(sizes) do
		local w, h = Layouts.Footprint(name, key)
		assert(size.width == w and size.height == h, name .. " writes " .. key .. " at its footprint")
	end
	assert(sizes["meters.damage"].height == 190, name .. ": six damage rows")
	assert(settings["GroupFrames.raid.groupsPerRow"] == 4, name .. " folds the raid into four groups a row, for the rail")
	local raidW = 4 * settings["GroupFrames.raid.width"] + 3 * 3
	assert(raidW <= RAIL and raidW >= RAIL - 4, name .. ": four raid groups fill the rail's 318, got " .. raidW)
end
do
	local function h(name, key)
		return select(2, Layouts.Footprint(name, key))
	end
	assert(h("Healer", "groupframes.party") > h("DPS", "groupframes.party") and h("Healer", "groupframes.raid") > h("DPS", "groupframes.raid"), "Healer gets larger party and raid frames")
	local healerParty, dpsParty = Layouts.Get("Healer")["groupframes.party"], Layouts.Get("DPS")["groupframes.party"]
	assert(healerParty.anchor ~= dpsParty.anchor or healerParty.x ~= dpsParty.x, "Healer moves the party and raid: it is not the DPS layout with taller rows")
	local threatW, threatH = Layouts.Footprint("Tank", "meters.threat")
	assert(threatW == 200 and threatH == 112, "Tank sizes the threat card to the cluster's side, 200 by 112, got " .. threatW .. " x " .. threatH)
	local hs = {}
	for _, entry in ipairs(Layouts.Settings("Healer")) do hs[entry.module .. "." .. entry.key] = entry.value end
	assert(hs["GroupFrames.party.auraDispelCount"] == 2 and hs["GroupFrames.raid.auraDispelCount"] == 2, "Healer shows up to two dispellable debuffs first on every frame")
	assert(h("Tank", "groupframes.party") == h("DPS", "groupframes.party"), "Tank keeps the DPS party card")
	local dps, healer = {}, {}
	for _, entry in ipairs(Layouts.Settings("DPS")) do dps[entry.module .. "." .. entry.key] = entry.value end
	for _, entry in ipairs(Layouts.Settings("Healer")) do healer[entry.module .. "." .. entry.key] = entry.value end
	assert(healer["GroupFrames.party.height"] > dps["GroupFrames.party.height"] and healer["GroupFrames.raid.height"] > dps["GroupFrames.raid.height"], "Healer writes taller party and raid rows")
	assert(dps["GroupFrames.party.spacing"] == 8 and healer["GroupFrames.party.spacing"] == 8, "the party rows sit 8 apart, the mockup's pitch")
	local party = 5 * healer["GroupFrames.party.height"] + 4 * healer["GroupFrames.party.spacing"]
	assert(5 * dps["GroupFrames.party.height"] + 4 * 8 <= h("DPS", "groupframes.party"), "the DPS party fits its card")
	assert(party <= h("Healer", "groupframes.party"), "the Healer party fits its card, got " .. party)
	local raid = 2 * (5 * healer["GroupFrames.raid.height"] + 4 * 3) + 3
	assert(raid <= h("Healer", "groupframes.raid"), "the Healer raid fits its card, got " .. raid)
	assert(Layouts.Shown("Raid", "actionbars.bar1") == nil and Layouts.Settings("Raid") == nil and Layouts.Slot("Raid") == nil and Layouts.Sizes("Raid") == nil, "an unknown layout gives nil")
end

-- The HUD reads at one scale, the 38-unit action button (the owner's ruling of 2026-11-08). Every Cooldown Manager row
-- is the button's size (owner pass 1, 2026-11-09: CDM icons bigger than the buttons read as a mistake). The Lumen
-- vitals line is no frame: a 62-unit ring with a name and two lines, at most two buttons tall. The compact frames stay
-- compact.
do
	local button = Layouts.Element("actionbars.bar1").height
	for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs" }) do
		assert(Layouts.Element(key).height == button, key .. " is the action button's size")
	end
	-- S2 moved the player's cast line into the vitals line, 4 units over two buttons; the cast bar element stays off.
	assert(select(2, Layouts.Footprint("DPS", "unitframes.player")) <= 2 * button + 4, "the vitals line, its cast line inside, stands no taller than two action buttons and that line")
	for _, key in ipairs({ "unitframes.targettarget", "unitframes.focustarget", "unitframes.pet" }) do
		assert(Layouts.Element(key).height < 36, key .. " stays a compact frame")
	end
end

-- Footprints: the 38-unit module for the hands and what S2 to S4 shipped for the frames and the rail cards -----------
local FOOTPRINTS = {
	["actionbars.bar1"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar2"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar3"] = { 12 * 38 + 11 * 3, 38 },
	["actionbars.bar4"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar5"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar6"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.pet"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	["actionbars.stance"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	-- S2 (#153): the vitals line holds its cast line (80) and the small frames are 120 by 22 pill rows. Round 2 (Q2):
	-- the sigil spans the vitals line at 490 with a bolder cast line (84) and keeps two rows of 24-unit debuff sockets
	-- under it (84 + 2 + 24 + 2 + 24, round 2 aura overflow);
	-- the focus is a 200 by 90 card beside it with its debuffs over it (90 + 22).
	["cooldowns.essential"] = { 6 * 38 + 5 * 3, 38 },
	["cooldowns.utility"] = { 4 * 38 + 3 * 3, 38 },
	["cooldowns.buffs"] = { 6 * 38 + 5 * 3, 38 },
	["cooldowns.bars"] = { 6 * 38 + 5 * 3, 2 * 20 + 3 },
	["unitframes.player"] = { 490, 80 },
	["unitframes.target"] = { 490, 136 },
	["unitframes.boss"] = { 318, 334 },
	["unitframes.targettarget"] = { 120, 22 },
	["unitframes.pet"] = { 120, 22 },
	["unitframes.focustarget"] = { 120, 22 },
	["unitframes.focus"] = { 200, 112 },
	["unitframes.castbar.player"] = { 272, 30 },
	["unitframes.castbar.target"] = { 220, 24 },
	-- S4 (#157): six damage rows, four threat rows, the readout with the menu docked (at 318 the bag bar wraps under
	-- the micro menu: 118 holds both rows, with 3 units for the owner's pixel snapping), the party card. Chat is the
	-- picture's 393 by 200 card at the left rail's foot (LEE-20).
	-- Owner pass 1: a 160-unit square map, half the lens card, with the zone and clock inside it.
	["minimap.main"] = { 160, 160 },
	-- Owner pass 1 (2026-11-09): the buffs and debuffs are plain rows of eight 30-unit tiles, two rows each, beside
	-- the map (test-setup-collisions.lua and test-auras-counts.lua measure the live rows at 0 to 40 buffs).
	["auras.buffs"] = { 282, 88 },
	["auras.debuffs"] = { 282, 88 },
	["meters.damage"] = { 318, 190 },
	["meters.threat"] = { 318, 144 },
	["databars.strip"] = { 318, 118 },
	["databars.micro"] = { 318, 44 },
	["chat.main"] = { 393, 200 },
	["groupframes.party"] = { 318, 324 },
	["groupframes.raid"] = { 318, 427 },
	["databars.xp"] = { 489, 4 },
	["databars.rep"] = { 162, 5 },
	["databars.honor"] = { 162, 5 },
}
for key, size in pairs(FOOTPRINTS) do
	local w, h = Layouts.Footprint("DPS", key)
	assert(w == size[1] and h == size[2], key .. " is " .. size[1] .. " x " .. size[2] .. " in Lumen, got " .. w .. " x " .. h)
end

-- Every element builds at its footprint (Element) and the layouts place it there, except a reserve and the sizes a
-- layout writes on Apply (the Tank meters).
do
	-- A reserve is the room the layouts keep for an element that is not its frame's size: the sigil's debuff sockets
	-- hang under its 84-unit frame in two rows, so the layouts keep 136 from its top; the focus card's debuffs sit over its 90-unit
	-- frame, so the layouts keep 112 from its foot; the boss column holds five compact cards and the layouts keep its
	-- full height plus the debuffs hanging to its left, 318 in all; the readout card is one 42-unit line until the player
	-- shows the micro menu and bag rows, and the layouts keep the 118 both rows take.
	local RESERVES = { ["unitframes.target"] = { 490, 136 }, ["unitframes.focus"] = { 200, 112 }, ["unitframes.boss"] = { 318, 334 }, ["databars.strip"] = { 318, 118 } }
	local reserved = {}
	for _, entry in ipairs(Layouts.Reserves()) do
		local want = RESERVES[entry.key]
		assert(want and want[1] == entry.width and want[2] == entry.height, entry.key .. " reserves " .. entry.width .. " x " .. entry.height)
		reserved[entry.key] = true
	end
	for key in pairs(RESERVES) do
		assert(reserved[key], key .. " has its reserve")
	end
	local target, boss, focus = Layouts.Element("unitframes.target"), Layouts.Element("unitframes.boss"), Layouts.Element("unitframes.focus")
	assert(target.width == 490 and target.height == 84 and Layouts.Get("DPS")["unitframes.target"].anchor == "TOP", "the sigil's frame tops its reserve, so its sockets hang inside it")
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
	assert(minimap.anchor == "TOPRIGHT" and minimap.x == -MARGIN and minimap.y == -MARGIN, "the square map sits on the margin at the top right")
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
