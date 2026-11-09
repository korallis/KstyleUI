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
		-- A docked element sits inside its host card; a threat card a layout switches off waits on the damage card's place.
		local function shares(a, c)
			if Layouts.Dock(a) == c or Layouts.Dock(c) == a then
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
-- the story slot between them, the right rail the lens, the Blessings, the damage card and the readout and menu. The
-- centre holds one combat cluster at the bottom: the hands, and right on them the target sigil, with the focus on its
-- left and the target of target on its right (in Tank the threat card under it), so you, your target, its target and
-- your focus read in one glance (round 2: Muse #1, Opus's eye travel). The boss column heads the centre's right edge,
-- 16 units in from the right rail. The world above the cluster stays clear. Healer stands the party and raid on the
-- cluster's left half, clear of the cast bars, heads the left rail with the boss column and keeps the right rail's
-- damage card under the Blessings, as DPS does (round 3: the Blessings card at 40 buffs and 12 debuffs left no room
-- for the boss column on the right rail; Muse #2: the cast bars stay in the cluster).

local MARGIN, RAIL, BAND = 28, 318, 28 + 318 + 16
local CARD_GAP_MIN, CARD_GAP_MAX = 16, 22
local LEFT_RAIL = {
	DPS = { "groupframes.party", "groupframes.raid", "chat.main" },
	Tank = { "groupframes.party", "groupframes.raid", "chat.main" },
	Healer = { "unitframes.boss", "chat.main" },
}
local RIGHT_STACK = {
	DPS = { "minimap.main", "auras.buffs", "meters.damage" },
	Tank = { "minimap.main", "auras.buffs", "meters.damage" },
	Healer = { "minimap.main", "auras.buffs", "meters.damage" },
}
local DOCKED = { ["auras.debuffs"] = "auras.buffs", ["databars.micro"] = "databars.strip", ["databars.bags"] = "databars.strip" }
local HANDS = set({
	"databars.xp", "databars.rep", "databars.honor", "actionbars.bar1", "actionbars.pet", "actionbars.stance",
	"unitframes.player", "unitframes.pet", "unitframes.resource", "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs",
	"cooldowns.bars", "meters.swing",
})
-- The combat cluster on the hands: the sigil, the focus and its target, the target of target, and in Tank the threat card.
local CLUSTER = set({ "unitframes.target", "unitframes.targettarget", "unitframes.focus", "unitframes.focustarget" })
-- What a player turns on stacks over the cluster: bar 2, then the plate cast bars (Healer: bar 2 at the top, the casts stay).
local EXTRAS = set({ "unitframes.castbar.player", "unitframes.castbar.target" })
-- The world kept clear (system board): the centre 520 units wide, from the top of what stacks on the cluster to the top.
local CLEAR = { half = 260, bottom = 574, top = 1080 - 28 }
-- The boss column at the clear centre's edge: on a 16:10 screen it reaches into the zone's outer half, never past it.
local EDGE_RIGHT = set({ "unitframes.boss" })
local RAIL_KEYS = {
	DPS = set({ "groupframes.party", "groupframes.raid", "chat.main", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "meters.threat", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
	Tank = set({ "groupframes.party", "groupframes.raid", "chat.main", "minimap.main", "auras.buffs", "auras.debuffs",
		"meters.damage", "databars.strip", "databars.micro", "databars.bags", "tooltips.anchor" }),
	Healer = set({ "chat.main", "minimap.main", "auras.buffs", "auras.debuffs", "unitframes.boss",
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
		-- The tooltip anchor sits just over the readout card's right corner, on no card (round 2: Fable R2-7): a tooltip
		-- grows up the rail from it, so hovering the micro menu never covers the menu or the readout you are reading.
		local tip = rect("tooltips.anchor")
		assert(math.abs(tip.right - strip.right) < 1e-6 and tip.bottom - strip.top == 8, label .. ": the tooltip anchor sits 8 over the readout card's right corner")
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

		-- The story slot: the space between the left rail's head and chat, where the player drops the guide and the tracker.
		local slot = Layouts.Slot(name)
		assert(slot and slot.anchor and slot.label and slot.hint, name .. " has a labelled story slot with a hint")
		-- Apply places the quest tracker itself, so the hint names Apply and Edit Mode (round 3: Opus #4, the carry
		-- list); a refusal gets Try again on the setup summary, so the hint gives no manual move (round 4, Muse #4).
		assert(slot.hint:find("Apply places the quest tracker here", 1, true) and slot.hint:find("Edit Mode", 1, true), name .. ": the slot hint says Apply places the tracker: " .. slot.hint)
		assert(not slot.hint:find("yourself", 1, true), name .. ": and gives no drag instruction")
		local s = { Layouts.Rect(slot, slot, width, HEIGHT) }
		assert(s[1] == MARGIN and s[3] - s[1] == RAIL, label .. ": the story slot is on the left rail's column")
		assert(s[2] - chat.top >= CARD_GAP_MIN and head.bottom - s[4] >= CARD_GAP_MIN, label .. ": the story slot sits between the rail's head and chat, 16 from each")
		assert(s[4] - s[2] >= 280, label .. ": the story slot has room for the guide and the quests")
		if healer then
			assert(slot.raid == 0, label .. ": in Healer the raid card stands on the cluster and covers none of the slot")
		else
			-- In a raid the taller raid card takes the slot's top: the slot says how far, and Layout Mode marks the line.
			assert(slot.raid == raid.h - party.h and slot.raid > 0 and slot.raid < s[4] - s[2] and slot.raidHint, label .. ": the story slot names the part the raid card covers")
			assert(party.bottom - slot.raid == raid.bottom, label .. ": the raid card ends that far into the slot")
		end

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
		assert(vitals.bottom - bar1.top == 12, label .. ": the vitals line sits 12 over bar 1, as the mockup")
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

		-- What a player turns on: bar 2 is a column of twelve beside bars 3 to 6, never over the character (round 5,
		-- Opus #2: it once stood across the screen's centre over the sigil): DPS and Tank stand it a rail gap in from the
		-- left rail, bars 3 to 6 beside it; Healer stands it under bar 3 at the right. The plate cast bars keep their place over the cluster,
		-- Layouts.SIGIL_CLEAR and one bar's room over the sigil cap (round 4, Opus #6).
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
		assert(bar2.w == bar3.w and bar2.h == bar3.h, label .. ": bar 2 is a column like bars 3 to 6")
		if healer then
			assert(bar2.left == bar3.left and bar3.bottom - bar2.top == 16, label .. ": bar 2 stands a rail gap under bar 3")
			for _, key in ipairs({ "groupframes.party", "groupframes.raid" }) do
				assert(rect(key).bottom - clusterTop == HEALER.gap, label .. ": " .. key .. " stands 16 over the cluster")
			end
		else
			assert(bar2.top == bar3.top and bar2.left == BAND and rect("actionbars.bar5").left - bar2.right == 3, label .. ": bar 2 is the column nearest the left rail, bars 3 to 6 beside it")
		end

		-- The boss column heads the centre's right edge in DPS and Tank, 16 in from the right rail; your combat text
		-- rises right of the cluster under it.
		local boss, text = rect("unitframes.boss"), rect("combattext.player")
		if not healer then
			assert(math.abs(boss.right - (width - BAND)) < 1e-6 and boss.top == HEIGHT - MARGIN, label .. ": the boss column heads the right edge of the centre, 16 in from the right rail")
			assert(boss.bottom - text.top >= 16, label .. ": your combat text rises under the boss column")
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
	-- Empty sockets hide in Lumen (round 3, Opus #6): bar 1's twelfth socket read as a dark tile at the row's end. A
	-- spell on the cursor still shows every socket to drop it on.
	for i = 1, 6 do
		assert(settings["ActionBars.bar" .. i .. ".showEmpty"] == false, name .. " hides bar " .. i .. "'s empty sockets")
	end
	assert(settings["Meters.threat.shown"] == (name == "Tank"), name .. " writes the threat card's switch")
	assert(settings["Auras.buffs.rows"] == 1 and settings["Auras.card.docked"] == true, name .. " writes one row of buffs in the Blessings card, the debuffs docked")
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
	["actionbars.bar2"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar3"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar4"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar5"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.bar6"] = { 38, 12 * 38 + 11 * 3 },
	["actionbars.pet"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	["actionbars.stance"] = { 5 * 30 + 4 * 3, 2 * 30 + 3 },
	-- S2 (#153): the vitals line holds its cast line (80) and the small frames are 120 by 22 pill rows. Round 2 (Q2):
	-- the sigil spans the vitals line at 490 with a bolder cast line (84) and keeps two rows of 24-unit debuff sockets
	-- under it (84 + 2 + 24 + 2 + 24, round 2 aura overflow);
	-- the focus is a 200 by 90 card beside it with its debuffs over it (90 + 22).
	["cooldowns.essential"] = { 6 * 44 + 5 * 6, 44 },
	["cooldowns.utility"] = { 4 * 38 + 3 * 6, 38 },
	["cooldowns.buffs"] = { 6 * 30 + 5 * 3, 30 },
	["cooldowns.bars"] = { 195, 2 * 20 + 3 },
	["unitframes.player"] = { 490, 80 },
	["unitframes.target"] = { 490, 136 },
	["unitframes.boss"] = { 318, 334 },
	["unitframes.targettarget"] = { 120, 22 },
	["unitframes.pet"] = { 120, 22 },
	["unitframes.focustarget"] = { 120, 22 },
	["unitframes.focus"] = { 200, 112 },
	["unitframes.castbar.player"] = { 272, 30 },
	["unitframes.castbar.target"] = { 220, 24 },
	-- S4 (#157): the lens card, the Blessings card at one buff row with the debuff row docked, six damage rows, four
	-- threat rows, the readout with the menu docked (at 318 the bag bar wraps under the micro menu: 118 holds both
	-- rows, with 3 units for the owner's pixel snapping), the party card. Chat is a 318-unit card at the left rail's foot.
	-- Round 3 (Muse #3): the lens card is a 306 lens under its dome, a rim round it, and the 34-unit foot.
	["minimap.main"] = { 318, 346 },
	-- Round 3 (Astra #1B): the Blessings footprint reserves the card at its cap, one buff row over the hairline and two
	-- docked debuff rows (test-setup-collisions.lua measures the live card against it).
	["auras.buffs"] = { 318, 230 },
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
	-- hang under its 84-unit frame in two rows, so the layouts keep 136 from its top; the focus card's debuffs sit over its 90-unit
	-- frame, so the layouts keep 112 from its foot; the boss column holds five compact cards and the layouts keep its
	-- full height plus the debuffs hanging to its left, 318 in all; the Blessings card starts at one buff row and grows
	-- by its docked debuff rows to 230 at its cap.
	local RESERVES = { ["unitframes.target"] = { 490, 136 }, ["unitframes.focus"] = { 200, 112 }, ["unitframes.boss"] = { 318, 334 }, ["auras.buffs"] = { 318, 230 } }
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
