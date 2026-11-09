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
	"tooltips.anchor",
}
local ANCHORS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
-- Party and raid frames never show together, so they may share space.
local EXCLUSIVE = { ["groupframes.party"] = "groupframes.raid", ["groupframes.raid"] = "groupframes.party" }
local SPARE = { ["actionbars.bar3"] = true, ["actionbars.bar4"] = true, ["actionbars.bar5"] = true, ["actionbars.bar6"] = true }
-- 16:9 at three sizes, a MacBook, 16:10 and 21:9: the root is 1080 units tall on each.
local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 3456, 2234 }, { 2560, 1600 }, { 3440, 1440 } }
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
			assert(l >= 0 and b >= 0 and r <= width + 1e-6 and t <= HEIGHT, string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %d)", label, key, l, b, r, t, width, HEIGHT))
			rects[key] = { l, b, r, t }
		end
		-- A docked element sits inside its host card; the tooltip anchor lies over the readout card and what docks in it; a
		-- threat card a layout switches off waits on the damage card's place.
		local function covers(x, y)
			local host = Layouts.Covers(x)
			return host ~= nil and (host == y or Layouts.Dock(y) == host)
		end
		local function shares(a, c)
			if Layouts.Dock(a) == c or Layouts.Dock(c) == a or covers(a, c) or covers(c, a) then
				return true
			end
			local threat = a == "meters.threat" and c or (c == "meters.threat" and a)
			return threat == "meters.damage" and Layouts.Shown(name, "meters.threat") == false
		end
		-- Bars 3 to 6 are off in every layout. Below 16:10 there is no room for four 489-unit columns beside the boss
		-- column and the Healer's group frames, so there a player who turns one on places it; test-setup-collisions.lua
		-- holds them apart at 16:9, 16:10 and 21:9.
		local narrow = width / HEIGHT < 1.6 - 1e-6
		for i = 1, #KEYS do
			for j = i + 1, #KEYS do
				local a, c = KEYS[i], KEYS[j]
				local spare = narrow and (SPARE[a] or SPARE[c])
				if EXCLUSIVE[a] ~= c and not spare and not shares(a, c) and overlap(rects[a], rects[c]) then
					error(label .. ": " .. a .. " overlaps " .. c)
				end
				local ra, rc = rects[a], rects[c]
				if not spare and (a:find("^unitframes%.") or c:find("^unitframes%.")) and overlap({ ra[1] - 2, ra[2] - 2, ra[3] + 2, ra[4] + 2 }, rc) then
					error(label .. ": " .. a .. " comes within 2 units of " .. c)
				end
			end
		end
	end
end

-- Lumen Rails (handoff/arena2/parent: index.html, NOTES.md and the two HUD boards) ------------------------
-- Two 318-unit rails on a 28-unit margin hold everything slow: in DPS and Tank the left rail the party and chat with
-- the story slot between them, the right rail the lens, the Blessings, the meters and the readout and menu. The centre
-- holds the hands at the bottom and the enemy at the top: the target sigil, and beside it, 16 units in from the right
-- rail, the boss column, so all five boss cards fit clear of the meters. The world between stays clear. Healer brings
-- the party and raid beside the hands, puts the damage card and the focus at the head of the left rail and the boss
-- column on the right rail.

local MARGIN, RAIL, BAND = 28, 318, 28 + 318 + 16
local CARD_GAP_MIN, CARD_GAP_MAX = 16, 22
local LEFT_RAIL = {
	DPS = { "groupframes.party", "groupframes.raid", "chat.main" },
	Tank = { "groupframes.party", "groupframes.raid", "chat.main" },
	Healer = { "meters.damage", "unitframes.focus", "chat.main" },
}
local RIGHT_STACK = {
	DPS = { "minimap.main", "auras.buffs", "meters.damage" },
	Tank = { "minimap.main", "auras.buffs", "meters.threat", "meters.damage" },
	Healer = { "minimap.main", "auras.buffs", "unitframes.boss" },
}
local DOCKED = { ["auras.debuffs"] = "auras.buffs", ["databars.micro"] = "databars.strip", ["databars.bags"] = "databars.strip" }
local HANDS = set({
	"databars.xp", "databars.rep", "databars.honor", "actionbars.bar1", "actionbars.bar2", "actionbars.pet", "actionbars.stance",
	"unitframes.player", "unitframes.pet", "unitframes.resource", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs",
	"cooldowns.bars", "unitframes.castbar.player", "meters.swing",
})
local SIGIL = set({ "unitframes.target", "unitframes.castbar.target", "unitframes.targettarget" })
-- The mockup's "world, kept clear" (system board): the centre 520 units wide, from the hands' top to the sigil's foot.
local CLEAR = { half = 260, bottom = 390, top = 880 }
-- Cards at the clear centre's edge (the brief: "inside the centre clear zone's edge"): on a 16:10 screen they reach
-- into the zone's outer half, never past it. The focus card on the left; the boss column on the right.
local EDGE_LEFT = set({ "unitframes.focus", "unitframes.focustarget" })
local EDGE_RIGHT = set({ "unitframes.boss" })
local RAIL_KEYS = {
	DPS = set({ "groupframes.party", "groupframes.raid", "chat.main", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "meters.threat", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
	Healer = set({ "chat.main", "minimap.main", "auras.buffs", "auras.debuffs", "unitframes.boss", "unitframes.focus",
		"unitframes.focustarget", "meters.damage", "meters.threat", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
}
RAIL_KEYS.Tank = RAIL_KEYS.DPS
-- Healer: the party and raid sit beside the hands, left of centre, their right edge 116 units off the centre line and
-- their foot 400 up, just over the hands' top; the character's column (centre +- 100) stays clear.
local HEALER = { right = 116, bottom = 400, character = 100 }
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
			assert(r.left == MARGIN and r.w == RAIL, label .. ": " .. key .. " sits on the left rail, 318 wide on the 28 margin")
		end
		for _, key in ipairs(RIGHT_STACK[name]) do
			local r = rect(key)
			assert(math.abs(r.right - (width - MARGIN)) < 1e-6 and r.w == RAIL, label .. ": " .. key .. " sits on the right rail, 318 wide on the 28 margin")
		end
		local strip = rect("databars.strip")
		assert(math.abs(strip.right - (width - MARGIN)) < 1e-6 and strip.w == RAIL and strip.bottom == MARGIN, label .. ": the readout and menu card sits on the right rail's foot")
		-- Docked: the debuff row in the Blessings card, the menu and the bag bar in the readout card. Each sits inside its
		-- host, where it stays when the player undocks it.
		for key, host in pairs(DOCKED) do
			assert(Layouts.Dock(key) == host, key .. " docks into " .. host)
			local r, h = rect(key), rect(host)
			assert(r.left >= h.left and r.right <= h.right + 1e-6 and r.bottom >= h.bottom and r.top <= h.top, label .. ": " .. key .. " sits inside " .. host)
		end
		-- The tooltip anchor lies on the readout card at the right rail's foot: fixed tooltips cover the idle readout and
		-- grow up the rail, never over the hands, the combat text or the boss column.
		local tip = rect("tooltips.anchor")
		assert(Layouts.Covers("tooltips.anchor") == "databars.strip", "the tooltip anchor covers the readout card")
		assert(math.abs(tip.right - strip.right) < 1e-6 and tip.bottom == strip.bottom and tip.left >= strip.left, label .. ": the tooltip anchor sits in the readout card's corner")
		local chat = rect("chat.main")
		assert(chat.bottom == MARGIN, label .. ": chat sits at the left rail's foot")

		-- The right rail, top to bottom, 16 to 22 units between cards.
		local top = HEIGHT - MARGIN
		for i, key in ipairs(RIGHT_STACK[name]) do
			local r = rect(key)
			if i == 1 then
				assert(r.top == top, label .. ": the lens card heads the right rail")
			else
				local gap = top - r.top
				assert(gap >= CARD_GAP_MIN and gap <= CARD_GAP_MAX, label .. ": " .. key .. " sits 16 to 22 under the card above it, got " .. gap)
			end
			top = r.bottom
		end
		assert(top - strip.top >= CARD_GAP_MIN, label .. ": the readout and menu card clears the card above it")

		-- The left rail's head: the party and raid card, or in Healer the damage card with the focus under it.
		local party, raid = rect("groupframes.party"), rect("groupframes.raid")
		local head
		if healer then
			local damage, focus = rect("meters.damage"), rect("unitframes.focus")
			assert(damage.top == HEIGHT - MARGIN, label .. ": the damage card heads the left rail")
			assert(damage.bottom - focus.top == 16, label .. ": the focus card sits 16 under it")
			local ft = rect("unitframes.focustarget")
			assert(ft.left == MARGIN and focus.bottom - ft.top >= 4, label .. ": the focus target sits under the focus card")
			head = ft
		else
			assert(party.top == HEIGHT - MARGIN and raid.top == HEIGHT - MARGIN, label .. ": the party and raid card heads the left rail")
			head = party
		end

		-- The story slot: the space between the left rail's head and chat, where the player drops the guide and the tracker.
		local slot = Layouts.Slot(name)
		assert(slot and slot.anchor and slot.label and slot.hint, name .. " has a labelled story slot with a hint")
		local s = { Layouts.Rect(slot, slot, width, HEIGHT) }
		assert(s[1] == MARGIN and s[3] - s[1] == RAIL, label .. ": the story slot is on the left rail's column")
		assert(s[2] - chat.top >= CARD_GAP_MIN and head.bottom - s[4] >= CARD_GAP_MIN, label .. ": the story slot sits between the rail's head and chat, 16 from each")
		assert(s[4] - s[2] >= 280, label .. ": the story slot has room for the guide and the quests")
		if healer then
			assert(slot.raid == 0, label .. ": in Healer the raid card is beside the hands and covers none of the slot")
		else
			-- In a raid the taller raid card takes the slot's top: the slot says how far, and Layout Mode marks the line.
			assert(slot.raid == raid.h - party.h and slot.raid > 0 and slot.raid < s[4] - s[2] and slot.raidHint, label .. ": the story slot names the part the raid card covers")
			assert(party.bottom - slot.raid == raid.bottom, label .. ": the raid card ends that far into the slot")
		end

		-- Nothing but the rails' own cards enters a rail column; nothing but the hands, the sigil and (in Healer) the group
		-- frames crosses the clear centre; the edge cards stay in its outer half.
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
				assert(r.bottom == HEALER.bottom, label .. ": " .. key .. " stands just over the hands")
			elseif EDGE_LEFT[key] and not onRail then
				assert(r.right <= mid - CLEAR.half / 2, label .. ": " .. key .. " stays at the clear centre's outer edge")
			elseif EDGE_RIGHT[key] and not onRail then
				assert(r.left >= mid + CLEAR.half / 2, label .. ": " .. key .. " stays at the clear centre's outer edge")
			else
				assert(not inside, label .. ": " .. key .. " crosses the clear centre")
			end
			if HANDS[key] and math.abs(r.x - mid) < CLEAR.half then
				assert(r.top <= CLEAR.bottom, label .. ": " .. key .. " sits under the clear centre with the hands")
			end
			if SIGIL[key] then
				assert(r.bottom >= CLEAR.top, label .. ": " .. key .. " sits over the clear centre with the sigil")
			end
		end

		-- The hands, bottom to top: the XP line, one row of bar 1, the vitals line, the cooldowns with the swing line on
		-- them, then bar 2 and the plate's cast bar for a player who turns them on.
		local xp, bar1, vitals = rect("databars.xp"), rect("actionbars.bar1"), rect("unitframes.player")
		local essential, utility, cast = rect("cooldowns.essential"), rect("cooldowns.utility"), rect("unitframes.castbar.player")
		for _, key in ipairs({ "databars.xp", "actionbars.bar1", "actionbars.bar2", "unitframes.player", "unitframes.resource", "cooldowns.essential", "unitframes.castbar.player", "meters.swing" }) do
			assert(centred(rect(key)), label .. ": " .. key .. " is centred")
		end
		assert(xp.bottom - 34 >= 14 and xp.bottom - 34 <= 20, label .. ": the XP line sits 34 units up with room for its caption under it")
		assert(bar1.bottom - xp.top == 12, label .. ": bar 1 sits 12 over the XP line, as the mockup")
		assert(vitals.bottom - bar1.top == 12, label .. ": the vitals line sits 12 over bar 1, as the mockup")
		assert(math.abs(vitals.w - bar1.w) <= 2, label .. ": the vitals line spans bar 1")
		local resource = rect("unitframes.resource")
		assert(resource.bottom >= vitals.top and essential.bottom >= resource.top, label .. ": the class resource sits between the vitals and the cooldowns")
		assert(essential.bottom - vitals.top <= 40, label .. ": the essential cooldowns sit just over the vitals")
		assert(utility.bottom == essential.bottom and utility.left - essential.right == 16, label .. ": the utility cooldowns sit beside the essential ones")
		local buffs, bars = rect("cooldowns.buffs"), rect("cooldowns.bars")
		assert(buffs.bottom == essential.bottom and essential.left - buffs.right >= 16, label .. ": the tracked buff icons sit beside the essential cooldowns' other end")
		assert(bars.bottom >= buffs.top + 4 and bars.left == buffs.left, label .. ": the tracked buff bars sit over the icons")
		local bar2, swing = rect("actionbars.bar2"), rect("meters.swing")
		assert(swing.bottom - essential.top >= 4 and swing.bottom - essential.top <= 8, label .. ": the swing line sits on the essential cooldowns, part of the hands, not a stray bar")
		local block = math.max(swing.top, bars.top, essential.top, utility.top)
		assert(bar2.bottom >= block and bar2.bottom - block <= 8, label .. ": bar 2 sits on the hands block, not floating over it (" .. (bar2.bottom - block) .. " over)")
		assert(cast.bottom >= bar2.top, label .. ": the plate's cast bar waits over bar 2")
		local petBar, stance = rect("actionbars.pet"), rect("actionbars.stance")
		assert(petBar.right == bar1.left - 12 and petBar.bottom == bar1.bottom, label .. ": the pet sockets sit beside bar 1's left end")
		assert(stance.left == bar1.right + 12 and stance.bottom == bar1.bottom, label .. ": the stance sockets sit beside bar 1's right end")
		local rep, honor = rect("databars.rep"), rect("databars.honor")
		assert(rep.bottom == xp.bottom and rep.left == petBar.left and rep.right == petBar.right, label .. ": the reputation line runs under the pet sockets on the XP line's baseline")
		assert(honor.bottom == xp.bottom and honor.left == stance.left and honor.right == stance.right, label .. ": the honour line runs under the stance sockets on the XP line's baseline")
		local pet = rect("unitframes.pet")
		assert(pet.right == vitals.left - 12 and pet.top == vitals.top, label .. ": the pet frame sits beside the vitals line's ring, top-aligned")

		-- The sigil near the top centre; the target's cast bar under it and the target of target under its right end.
		local sigil, targetCast, tot = rect("unitframes.target"), rect("unitframes.castbar.target"), rect("unitframes.targettarget")
		assert(centred(sigil) and sigil.top == HEIGHT - 40, label .. ": the sigil sits 40 under the top, centred")
		assert(centred(targetCast) and sigil.bottom - targetCast.top == 8, label .. ": the target cast bar hangs under the sigil")
		assert(tot.right == sigil.right and tot.top == targetCast.top, label .. ": the target of target sits under the sigil's right end")

		-- The enemy at the top: in DPS and Tank the boss column sits 16 in from the right rail, 16 under the target of
		-- target, and all five cards end above your combat text.
		local boss, text = rect("unitframes.boss"), rect("combattext.player")
		if not healer then
			assert(math.abs(boss.right - (width - BAND)) < 1e-6, label .. ": the boss column sits 16 units in from the right rail")
			assert(tot.bottom - boss.top == 16, label .. ": the boss column hangs 16 under the target of target")
			assert(boss.bottom - text.top >= 16, label .. ": your combat text rises under the boss column")
		end
		assert(text.left >= utility.right or text.bottom >= utility.top, label .. ": your combat text stays off the utility cooldowns")

		-- The focus card at mid-left, at the clear centre's edge; its target under it. In Healer they head the left rail.
		local focus, focusTarget = rect("unitframes.focus"), rect("unitframes.focustarget")
		if not healer then
			assert(focus.left == BAND and focus.y > HEIGHT / 3 and focus.y < HEIGHT * 2 / 3, label .. ": the focus card sits mid-left, beside the left rail")
			assert(focusTarget.left == focus.left and focus.bottom - focusTarget.top >= 4, label .. ": the focus target sits under the focus card")
		end
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
	assert(settings["Meters.threat.shown"] == (name == "Tank"), name .. " writes the threat card's switch")
	assert(settings["Auras.buffs.rows"] == 1 and settings["Auras.card.docked"] == true, name .. " writes one row of buffs in the Blessings card, the debuffs docked")
	assert(settings["DataBars.strip.menus"] == true, name .. " docks the menu and the bags in the readout card")
	-- Apply sizes the meters: six damage rows, or in Tank two damage rows over two threat rows, so the rail fits.
	local sizes = Layouts.Sizes(name)
	for key, size in pairs(sizes) do
		local w, h = Layouts.Footprint(name, key)
		assert(size.width == w and size.height == h, name .. " writes " .. key .. " at its footprint")
	end
	assert(sizes["meters.damage"].height == (name == "Tank" and 98 or 190), name .. ": the damage card's rows")
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
	assert(h("Tank", "meters.threat") > h("Tank", "meters.damage"), "Tank gives the threat card more rows than the damage card")
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

-- The HUD reads at one scale, the 38-unit action button (the owner's ruling of 2026-11-08). The essential icons step up
-- one notch from it and the utility icons are the button's size. The Lumen vitals line is no frame: a 62-unit ring with
-- a name and two lines, at most two buttons tall. The compact frames stay compact.
do
	local button = Layouts.Element("actionbars.bar1").height
	assert(Layouts.Element("cooldowns.utility").height == button, "the utility icons are the action button's size")
	local essential = Layouts.Element("cooldowns.essential").height
	assert(essential > button and essential <= button * 1.2, "the essential icons are one notch larger than the action buttons, not half again")
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
	["actionbars.bar3"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar4"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar5"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar6"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.pet"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	["actionbars.stance"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	-- S2 (#153): the vitals line holds its cast line (80), the sigil keeps its debuff sockets under it (80 + 46), the
	-- boss and focus are 318 by 120 cards, and the small frames 120 by 22 pill rows.
	["cooldowns.essential"] = { 6 * 44 + 5 * 6, 44 },
	["cooldowns.utility"] = { 4 * 38 + 3 * 6, 38 },
	["cooldowns.buffs"] = { 6 * 30 + 5 * 3, 30 },
	["cooldowns.bars"] = { 195, 2 * 20 + 3 },
	["unitframes.player"] = { 490, 80 },
	["unitframes.target"] = { 640, 126 },
	["unitframes.boss"] = { 318, 334 },
	["unitframes.targettarget"] = { 120, 22 },
	["unitframes.pet"] = { 120, 22 },
	["unitframes.focustarget"] = { 120, 22 },
	["unitframes.focus"] = { 318, 120 },
	["unitframes.castbar.player"] = { 272, 30 },
	["unitframes.castbar.target"] = { 220, 24 },
	-- S4 (#157): the lens card, the Blessings card at one buff row with the debuff row docked, six damage rows, four
	-- threat rows, the readout with the menu docked (at 318 the bag bar wraps under the micro menu: 118 holds both
	-- rows, with 3 units for the owner's pixel snapping), the party card. Chat is a 318-unit card at the left rail's foot.
	["minimap.main"] = { 318, 326 },
	["auras.buffs"] = { 318, 177 },
	["auras.debuffs"] = { 318, 63 },
	["meters.damage"] = { 318, 190 },
	["meters.threat"] = { 318, 144 },
	["databars.strip"] = { 318, 118 },
	["databars.micro"] = { 318, 44 },
	["chat.main"] = { 318, 260 },
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
	-- hang under its 80-unit frame, so the layouts keep 126 from its top; the boss column holds five compact cards and
	-- the layouts keep its full height plus the debuffs hanging to its left, 318 in all.
	local RESERVES = { ["unitframes.target"] = { 640, 126 }, ["unitframes.boss"] = { 318, 334 } }
	local reserved = {}
	for _, entry in ipairs(Layouts.Reserves()) do
		local want = RESERVES[entry.key]
		assert(want and want[1] == entry.width and want[2] == entry.height, entry.key .. " reserves " .. entry.width .. " x " .. entry.height)
		reserved[entry.key] = true
	end
	for key in pairs(RESERVES) do
		assert(reserved[key], key .. " has its reserve")
	end
	local target, boss = Layouts.Element("unitframes.target"), Layouts.Element("unitframes.boss")
	assert(target.width == 640 and target.height == 80 and Layouts.Get("DPS")["unitframes.target"].anchor == "TOP", "the sigil's frame tops its reserve, so its sockets hang inside it")
	assert(boss.width == 258 and boss.height == 5 * 62 + 4 * 6, "the boss column holds five 62-unit cards 6 apart")
	for _, element in ipairs(Layouts.ELEMENTS) do
		if not RESERVES[element.key] then
			local w, h = Layouts.Footprint("DPS", element.key)
			assert(element.width == w and element.height == h, element.key .. " builds at its DPS footprint")
		end
	end
end
do
	local minimap = Layouts.Get("DPS")["minimap.main"]
	assert(minimap.anchor == "TOPRIGHT" and minimap.x == -MARGIN and minimap.y == -MARGIN, "the lens card sits on the 28 margin at the top right")
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
