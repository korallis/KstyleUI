-- test-groupframes-frames.lua: party and raid frames on secure group headers: units, names, health, colours, range fade, sorting, layout registration, Blizzard frames, combat safety and Disable.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function same(list, want, what)
	eq(#list, #want, what .. " count")
	for i = 1, #want do
		eq(list[i], want[i], what .. " [" .. i .. "]")
	end
end

local function last(object, method)
	for i = #object._calls, 1, -1 do
		local call = object._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

local function children(header)
	local out, i = {}, 1
	while header._attributes["child" .. i] do
		out[i] = header._attributes["child" .. i]
		i = i + 1
	end
	return out
end

local env, K, ns = G.New()
local Headers, Button = ns.Headers, ns.Button

local party = {
	{ name = "Thaldren", class = "WARRIOR", health = 92, maxHealth = 100, role = "TANK" },
	{ name = "Sylaen", class = "DRUID", health = 87, maxHealth = 100, inRange = false },
	{ name = "Kragar", class = "SHAMAN", health = 0, maxHealth = 100, dead = true },
	{ name = "Lunara", class = "MAGE", health = 50, maxHealth = 100, online = false },
}
G.SetRoster(env, "party", party)

-- Nothing exists until the module is enabled.
assert(Headers.party == nil, "no header exists before Enable")
assert(K.Modules.Enable("GroupFrames"), "the module switches on")
env.RunTimers()
assert(K.Modules.IsRunning("GroupFrames"), "GroupFrames runs after Enable")
eq(#env._errors, 0, "Enable raised no error: " .. tostring(env._errors[1]))

-- Layout: each holder is placed and scalable under its element key.
for kind, key in pairs({ party = "groupframes.party", raid = "groupframes.raid" }) do
	local el = K.Layout.Element(key)
	assert(el, key .. " registers with Layout")
	eq(el.frame, Headers.holders[kind], key .. " places the " .. kind .. " holder")
	eq(el.module, "GroupFrames", key .. " belongs to GroupFrames")
	eq(el.opts.scalable, true, key .. " is scalable")
	eq(el.label, K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
end
local pw, ph = Headers.holders.party:GetSize()
eq(pw, 230, "the party holder is one frame wide")
eq(ph, 270, "the party holder is five frames tall")
local rw, rh = Headers.holders.raid:GetSize()
eq(rw, 597, "the raid holder fills its footprint")
eq(rh, 212, "the raid holder fills its footprint")

-- The party header: the player first, then the party, five buttons made at Enable.
local header = Headers.party
same(G.Shown(header), { "player", "party1", "party2", "party3", "party4" }, "party units")
assert(#children(header) >= 5, "the party header made its five buttons at Enable")
eq(header._attributes.point, "TOP", "party frames stack downward")
eq(header._attributes.yOffset, -10, "with 10-unit gaps")
for g = 1, 8 do
	assert(#children(Headers.raid[g]) >= 5, "raid group " .. g .. " made its five buttons at Enable, out of combat")
end
local w, h = children(header)[1]:GetSize()
eq(w, 230, "party buttons are 230 wide")
eq(h, 46, "party buttons are 46 tall")

local function content(unit)
	for _, button in ipairs(children(header)) do
		if button._attributes.unit == unit and button._shown then
			return Button.Content(button)
		end
	end
	for _, raidHeader in ipairs(Headers.raid) do
		for _, button in ipairs(children(raidHeader)) do
			if button._attributes.unit == unit and button._shown then
				return Button.Content(button)
			end
		end
	end
end

-- Names, health passed through as secrets, class colours and the health text.
local c = content("party1")
assert(c, "party1 has a frame")
eq(c.name:GetText(), "Thaldren", "party1's name")
local value = last(c.health, "SetValue")
assert(value and env.issecretvalue(value[1]), "health reaches the bar as a secret")
eq(env.Reveal(value[1]), 92, "the bar gets party1's health")
local range = last(c.health, "SetMinMaxValues")
eq(range[1], 0, "the bar starts at 0")
eq(env.Reveal(range[2]), 100, "and ends at the secret maximum")
local color = last(c.health, "SetStatusBarColor")
local warrior = G.CLASS_COLORS.WARRIOR
assert(near(color[1], warrior[1]) and near(color[2], warrior[2]) and near(color[3], warrior[3]), "party1's bar is warrior coloured")
-- The tracks under the fills are the button body, the mockup's one dark tone under every bar (the bar grade's
-- #101214 track), never the kit's translucent black.
eq(c.health.backgroundName, "buttonFill", "the health track is the button body")
eq(c.power.backgroundName, "buttonFill", "the power track is the button body")
local formatted = c.healthText._state.FormattedText
assert(formatted, "the percent text is formatted by the engine")
eq(formatted[1], "%.0f%%", "percent format")
eq(env.Reveal(formatted[2]), 92, "the percent reaches the text as a secret")

-- Range fade: members out of range fade through SetAlphaFromBoolean; the player never fades.
local inRange = last(c, "SetAlphaFromBoolean")
assert(inRange, "range uses SetAlphaFromBoolean")
eq(env.Reveal(inRange[1]), true, "party1 is in range")
eq(inRange[3], 0.4, "out of range alpha")
local far = last(content("party2"), "SetAlphaFromBoolean")
eq(env.Reveal(far[1]), false, "party2 is out of range")
local me = last(content("player"), "SetAlpha")
eq(me and me[1], 1, "the player's own frame never fades")

-- Dead and offline members.
eq(content("party3").healthText:GetText(), "Dead", "a dead member says Dead")
eq(content("party4").healthText:GetText(), "Offline", "an offline member says Offline")
local grey = last(content("party3").health, "SetStatusBarColor")
local gr, gg, gb = K.Tokens.Color("textDisabled")
assert(near(grey[1], gr) and near(grey[2], gg) and near(grey[3], gb), "a dead member's bar is grey")

-- A unit change re-reads everything: the roster shifts party2 into party1.
party[1].name = "Vexen"
party[1].class = "PRIEST"
env.FireEvent("UNIT_NAME_UPDATE", "party1")
eq(content("party1").name:GetText(), "Vexen", "a name update reaches the frame")

-- Raid: the party header hides, eight group headers fill in.
G.SetRoster(env, "raid", G.Members(12, function(i, m)
	m.role = i == 7 and "TANK" or (i == 3 and "HEALER" or "DAMAGER")
end))
eq(header._shown, false, "the party header hides in a raid")
eq(#Headers.raid, 8, "eight raid headers")
same(G.Shown(Headers.raid[1]), { "raid1", "raid2", "raid3", "raid4", "raid5" }, "group 1")
same(G.Shown(Headers.raid[3]), { "raid11", "raid12" }, "group 3")
eq(Headers.raid[2]._points[1][4], 75, "group 2 sits 75 units right of group 1")
eq(content("raid7").name:GetText(), "Member7", "raid names")

-- Sort by role: one header in role order, the others hidden.
K.Options.Write("GroupFrames", "raid.sortBy", "ROLE")
local flow = Headers.raid[1]
eq(flow._attributes.groupBy, "ASSIGNEDROLE", "role sort groups by assigned role")
eq(flow._attributes.unitsPerColumn, 5, "five per column")
assert(#children(flow) >= 40, "the role header made forty buttons out of combat")
eq(G.Shown(flow)[1], "raid7", "the tank comes first")
eq(G.Shown(flow)[2], "raid3", "then the healer")
eq(env.Driver(Headers.raid[2], "visibility"), "hide", "other headers hide while sorting by role")
K.Options.Write("GroupFrames", "raid.sortBy", "GROUP")
same(G.Shown(Headers.raid[1]), { "raid1", "raid2", "raid3", "raid4", "raid5" }, "back to groups")

-- Combat: a size change waits for the end of combat, and a roster change still updates the frames.
env.SetCombat(true)
K.Options.Write("GroupFrames", "raid.width", 80)
eq(#env._blocked, 0, "no protected call in combat: " .. tostring(env._blocked[1]))
eq((children(Headers.raid[1])[1]:GetSize()), 72, "the size waits for the end of combat")
local members = G.Members(6)
members[6].name = "Latecomer"
G.SetRoster(env, "raid", members)
eq(#env._blocked, 0, "a roster change in combat makes no protected call: " .. tostring(env._blocked[1]))
eq(content("raid6").name:GetText(), "Latecomer", "a roster change in combat updates the name")
env.SetCombat(false)
eq((children(Headers.raid[1])[1]:GetSize()), 80, "the size applies after combat")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- Blizzard's frames are hidden through Safe, and come back when switched off.
assert(K.Safe.IsHidden(env.PartyFrame), "Blizzard's party frames are hidden")
assert(K.Safe.IsHidden(env.CompactRaidFrameContainer), "Blizzard's raid frames are hidden")
assert(K.Safe.IsHidden(env.CompactRaidFrameManager), "the raid manager is hidden")
K.Options.Write("GroupFrames", "blizzard.manager", false)
env.RunTimers()
assert(not K.Safe.IsHidden(env.CompactRaidFrameManager), "the raid manager comes back when switched off")

-- Disable: headers hide, drivers go, Blizzard's frames return, and unit events stop.
K.Modules.Disable("GroupFrames")
env.RunTimers()
assert(not K.Modules.IsRunning("GroupFrames"), "GroupFrames stops")
eq(Headers.raid[1]._shown, false, "raid headers hide")
eq(env.Driver(Headers.raid[1], "visibility"), nil, "the state drivers are gone")
assert(not K.Safe.IsHidden(env.PartyFrame), "Blizzard's party frames return")
local any = false
for _, button in ipairs(children(Headers.raid[1])) do
	local frame = Button.Content(button)
	any = any or next(frame._events) ~= nil
end
eq(any, false, "no unit events while off")

-- Enable again reuses the frames.
local before = #env._frames
K.Modules.Enable("GroupFrames")
env.RunTimers()
eq(#env._frames, before, "enabling again builds nothing new")
same(G.Shown(Headers.raid[1]), { "raid1", "raid2", "raid3", "raid4", "raid5" }, "units come back")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- Hover eases the hairline toward the accent over the kit's hover time instead of switching at once.
do
	local hovered = Button.Content(children(Headers.raid[1])[1])
	local button = children(Headers.raid[1])[1]
	local ir, _, _, ia = K.Tokens.Color("edgeInner")
	local start = { unpack(hovered.chrome.edge, 1, 4) }
	assert(near(start[1], ir) and near(start[4], ia), "the hairline starts at the inner edge colour")
	button:GetScript("OnEnter")(button)
	local now = hovered.chrome.edge
	assert(near(now[1], ir) and near(now[4], ia), "entering does not jump to the hover colour")
	W.Tick(env, 0.05)
	local mid = hovered.chrome.edge[4]
	assert(not near(mid, ia) and mid ~= 0.6, "partway through, the hairline is between the two colours")
	W.Settle(env)
	assert(near(hovered.chrome.edge[4], 0.6), "it ends at the hover colour")
	button:GetScript("OnLeave")(button)
	W.Settle(env)
	assert(near(hovered.chrome.edge[1], ir) and near(hovered.chrome.edge[4], ia), "leaving eases back")
end

-- GROUP_ROSTER_UPDATE comes in bursts in a raid. A burst refreshes each frame once, on the next frame.
local function paints(frame)
	local n = 0
	for _, call in ipairs(frame.health._calls) do
		if call.method == "SetStatusBarColor" then
			n = n + 1
		end
	end
	return n
end
local first = Button.Content(children(Headers.raid[1])[1])
local painted = paints(first)
env.FireEvent("GROUP_ROSTER_UPDATE")
env.FireEvent("GROUP_ROSTER_UPDATE")
env.FireEvent("GROUP_ROSTER_UPDATE")
eq(paints(first), painted, "roster updates wait for the next frame")
env.RunTimers()
eq(paints(first), painted + 1, "a burst of roster updates refreshes each frame once")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- The level disc on a party portrait is the button body with the edge line the other badges wear: a ring in the
-- accent, one border outside the disc, so the badge reads on the glass as the unit frames' octagon does.
do
	local p1 = content("party1")
	assert(p1.badge:IsShown(), "the party frame shows its level disc")
	local br, bg, bb = p1.badge:GetVertexColor()
	local fr, fg, fb = K.Tokens.Color("buttonFill")
	assert(near(br, fr) and near(bg, fg) and near(bb, fb), "the disc is the button body, the mockup's #101214 badge")
	local ring = p1.badgeRing
	assert(ring and ring:IsShown(), "the disc wears an edge ring")
	eq(ring:GetTexture(), (K.Tokens.Texture("ringBevel")), "the edge is the kit's bevelled ring: the mockup's thin metal ring, dark outside, lit, then the accent")
	local ar, ag, ab = ns.Style.Accent()
	local rr, rg, rb, ra = ring:GetVertexColor()
	assert(near(rr, ar) and near(rg, ag) and near(rb, ab) and near(ra, 1), "the ring takes the accent, as the unit frames' round badge does")
	local outset = K.Widgets.Border(p1)
	local _, rel, relPoint, x, y = ring:GetPoint(1)
	assert(rel == p1.badge and relPoint == "TOPLEFT" and near(x, -outset) and near(y, outset), "the ring sits one border outside the disc")
	local _, rel2, relPoint2, x2, y2 = ring:GetPoint(2)
	assert(rel2 == p1.badge and relPoint2 == "BOTTOMRIGHT" and near(x2, outset) and near(y2, -outset), "on every side")
	K.Options.Write("GroupFrames", "party.portrait", false)
	assert(not ring:IsShown(), "the ring goes with the portrait")
	K.Options.Write("GroupFrames", "party.portrait", true)
	assert(ring:IsShown(), "and comes back with it")
end

print("groupframes frames ok")
