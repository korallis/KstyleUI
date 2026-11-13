-- test-groupframes-card.lua: the cards round the group frames: by default (KSTY-57) the party stands bare and the raid sits in a quest card whose cap counts the raid and that hugs the groups in use, in combat too; with the card turned on, the Lumen party card of KSTY-31 (a section cap with Party and the count over the member rows, each a role ring in the class colour, a name, a class and level caption and a class pill) is still a choice.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local env, K, ns = G.New()
local Headers, Settings = ns.Headers, ns.Settings
local Widgets = K.Widgets

local party = {
	{ name = "Leduc", class = "PALADIN", health = 92, maxHealth = 100, role = "HEALER", level = 9 },
	{ name = "Trolly", class = "PRIEST", health = 87, maxHealth = 100, role = "DAMAGER", level = 8 },
	{ name = "Khont", class = "ROGUE", health = 50, maxHealth = 100, role = "DAMAGER", level = 9 },
}
G.SetRoster(env, "party", party)
assert(K.Modules.Enable("GroupFrames"), "the module switches on")
env.RunTimers()
eq(#env._errors, 0, "Enable raised no error: " .. tostring(env._errors[1]))

-- KSTY-57 defaults: the party stands bare on the world, as the KSTY-44 mock-up draws it: no card, no tile, its
-- holder the rows themselves.
do
	local s = Settings.current.party
	eq(s.card, false, "the party has no card by default")
	assert(not Headers.cards.party.frame:IsShown(), "so its card is hidden")
	local geo = ns.Geometry.Party(s)
	local w, h = Headers.holders.party:GetSize()
	assert(near(w, geo.width) and near(h, geo.height), "the holder is the rows: " .. tostring(w) .. " by " .. tostring(h))
	local hp = Headers.party._points[1]
	assert(hp[1] == geo.corner and near(hp[4], 0) and near(hp[5], 0), "the header hangs from the holder's corner")
end

-- The Lumen party card of KSTY-31 stays a choice: the card on, the portrait slot holding the role ring, the class
-- and level caption, the class pill and no power bar or health number.
for key, value in pairs({
	["party.card"] = true, ["party.portrait"] = true, ["party.roleRing"] = true, ["party.classLine"] = true, ["party.power"] = false,
	["party.width"] = 278, ["party.height"] = 40, ["party.spacing"] = 8, ["party.nameSize"] = 11, ["party.healthText"] = "NONE",
	["text.nameColorSource"] = "text", ["health.colorSource"] = "class",
}) do
	K.Options.Write("GroupFrames", key, value)
end
env.RunTimers()

-- That look: a 278 row for the 318 card, one class pill, no power bar, the class and level caption on.
local s = Settings.current.party
eq(s.width, 278, "a party row is 278 wide, the 318 card inside its 20 padding")
eq(s.power, false, "no power bar under the pill")
eq(s.healthText, "NONE", "no health number: the pill says it")
eq(s.classLine, true, "the class and level caption is on")
eq(s.roleRing, true, "the role ring stands where the portrait was")
eq(ns.Geometry.CARD_PAD, 20, "the card pads by the Lumen rail padding")

-- The card: the party holder wears a panel chrome and a cap reading Party with the member count aside; the header
-- hangs under the cap.
local holder, header = Headers.holders.party, Headers.party
local card = Headers.cards.party
assert(card and card.chrome and card.cap, "the party holder carries a card with a chrome and a section cap")
assert(card.frame:GetParent() == header, "the card is the header's child, so the secure driver hides it with the party")
assert(card.frame:GetFrameLevel() <= header:GetFrameLevel(), "and it draws under the member rows")
eq(card.cap.title:GetText(), "PARTY", "the cap reads Party")
eq(card.cap.aside:GetText(), "4", "the aside counts the whole group, you included")
local geo = ns.Geometry.Party(s)
local w, h = holder:GetSize()
assert(near(w, geo.width + 2 * 20), "the holder is the rows plus the padding: " .. tostring(w))
assert(near(h, geo.height + 20 + Widgets.SECTION_CAP_HEIGHT + 8 + 20), "and the cap, a gap and the padding tall: " .. tostring(h))
local hp = header._points[1]
assert(hp[1] == geo.corner and hp[2] == holder and near(hp[4], 20) and near(-hp[5], 20 + Widgets.SECTION_CAP_HEIGHT + 8), "the header hangs under the cap inside the padding: " .. tostring(hp[4]) .. ", " .. tostring(hp[5]))
local cp = card.cap.frame._points[1]
assert(cp[1] == "TOPLEFT" and cp[2] == card.frame and near(cp[4], 20) and near(cp[5], -20), "the cap sits inside the card's padding at its top")

-- The card hugs its rows: you and three others make four rows of glass, not five; the holder keeps the five-row
-- footprint Layout places, and the card hangs from its top.
W.Settle(env)
local function rows(n)
	return n * s.height + (n - 1) * s.spacing + 20 + Widgets.SECTION_CAP_HEIGHT + 8 + 20
end
local fp = card.frame._points[1]
assert(fp[1] == "TOPLEFT" and fp[2] == holder and fp[3] == "TOPLEFT", "the card hangs from the holder's top left")
assert(near(card.frame:GetHeight(), rows(4)), "four members make a four-row card: " .. tostring(card.frame:GetHeight()) .. ", want " .. rows(4))
assert(near(card.frame:GetWidth(), w), "at the rail width")
assert(near(select(2, holder:GetSize()), h), "while the holder keeps its five-row footprint")

-- A member leaves in combat: the card eases to three rows with no protected call, since it is a plain frame that
-- nothing secure hangs from.
env._combat = true
G.SetRoster(env, "party", { party[1], party[2] })
env.RunTimers()
W.Settle(env)
eq(#env._blocked, 0, "resizing the card in combat touches nothing protected: " .. tostring(env._blocked[1]))
assert(near(card.frame:GetHeight(), rows(3)), "three members make a three-row card: " .. tostring(card.frame:GetHeight()))
eq(card.cap.aside:GetText(), "3", "and the cap counts three")
env._combat = false
G.SetRoster(env, "party", party)
env.RunTimers()
W.Settle(env)
assert(near(card.frame:GetHeight(), rows(4)), "back to four rows")

-- Each member: a role ring in the class colour with the role's letter, the name, the class and level caption at the
-- right, and a thin class pill along the row's foot.
local function Button(unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end
local f = Button("party1")
assert(f and f.unit == "party1", "the first member is shown")
assert(not f.portrait:IsShown(), "no portrait")
assert(not f.chrome.fill[5]:IsShown(), "a row in the card wears no tile of its own: the card is the glass")
assert(f.ring:IsShown() and f.roleText and f.roleText:IsShown(), "a ring with a role letter")
eq(f.roleText:GetText(), "H", "the healer's ring reads H")
local pr, pg, pb = K.Theme.ClassColorForWidget("PALADIN")
local rr, rg, rb = f.ring:GetVertexColor()
assert(near(rr, pr) and near(rg, pg) and near(rb, pb), "the ring is the class colour")
assert(f.ring:GetWidth() <= ns.Style.ROLE_RING and f.ring:GetWidth() > 0, "the ring is at most the role ring size: " .. tostring(f.ring:GetWidth()))
assert(f.classLine and f.classLine:IsShown(), "the class and level caption shows")
eq(f.classLine:GetText(), "PALADIN 9", "it reads the class the game names and the level (the stub names the class by its file)")
local lp = f.classLine._points[1]
assert(lp[1] == "TOPRIGHT" and lp[2] == f, "at the row's top right")
assert(near(env.Look(f.health:GetHeight()), ns.Style.PILL_HEIGHT) and ns.Style.PILL_HEIGHT >= 6 and ns.Style.PILL_HEIGHT <= 7, "the health bar is the 6 to 7 unit class pill: " .. tostring(env.Look(f.health:GetHeight())))
local hb = f.health._points[1]
local foot = env.Look(f:GetHeight()) - (-hb[5] + env.Look(f.health:GetHeight()))
assert(hb[1] == "TOPLEFT" and foot >= ns.Style.PILL_RISE and foot <= ns.Style.PILL_RISE + 4, "the pill runs along the row's foot, inside the row's inner padding: " .. tostring(foot))
assert(-hb[5] > f.parts.name.top + f.parts.name.height + 4, "with air between the name line and the pill")
-- Grok R3 #1, R5 #1: your heals never sit on the 6-unit pill nor in its row: they ride the name line's right end,
-- and the pill runs the row past the ring.
local row = f.parts.healRow
assert(row and row.width > 0 and row.side == "RIGHT", "your heals keep the name line's right end")
assert(row.top + row.height <= f.parts.health.top - 4, "wholly above the pill")
assert(env.Look(f.health:GetWidth()) > env.Look(f:GetWidth()) - 60, "the pill spans the row past the ring: " .. tostring(env.Look(f.health:GetWidth())))
local second = Button("party2")
eq(second.roleText:GetText(), "D", "a damage dealer's ring reads D")

-- A secret role or level: the ring stays, the letter and the level go, never a guess.
local member = env._member(f.unit)
member.role = env.Secret("TANK")
member.level = env.Secret(9)
ns.Unit.Refresh(f)
eq(f.roleText:GetText(), "", "a secret role shows no letter")
eq(f.classLine:GetText(), "PALADIN", "a secret level leaves the class alone")
member.role, member.level = "HEALER", 9

-- Settings: the ring and the caption can be turned off; the portrait comes back with the ring off.
K.Options.Write("GroupFrames", "party.roleRing", false)
env.RunTimers()
assert(f.portrait:IsShown() and not f.roleText:IsShown(), "without the role ring the portrait returns")
assert(f.chrome.fill[5]:IsShown(), "and the row wears its tile again")
K.Options.Write("GroupFrames", "party.classLine", false)
env.RunTimers()
assert(not f.classLine:IsShown(), "the caption can be turned off")
K.Options.Write("GroupFrames", "party.roleRing", true)
K.Options.Write("GroupFrames", "party.classLine", true)

eq(#env._errors, 0, tostring(env._errors[1]))

-- KSTY-57: the raid sits in a quest card, as the KSTY-47 raid mock-ups draw it at 10, 20 and 40: the window chrome
-- and a cap reading Raid with the raid's size aside, the groups hanging under the cap inside the 20 padding, and a
-- card that hugs the groups in use while the holder keeps the eight-group footprint Layout places.
do
	local renv, RK, rns = G.New()
	G.SetRoster(renv, "raid", G.Members(12))
	assert(RK.Modules.Enable("GroupFrames"))
	renv.RunTimers()
	W.Settle(renv)
	local rs = rns.Settings.current.raid
	local rcard, rholder = rns.Headers.cards.raid, rns.Headers.holders.raid
	eq(rs.card, true, "the raid has a card by default")
	assert(rcard and rcard.frame:IsShown() and rcard.chrome and rcard.cap, "a shown card with a chrome and a section cap")
	assert(rcard.frame:GetParent() == rns.Headers.raid[1], "the card is the first raid header's child, so the secure driver hides it with the raid")
	assert(rcard.frame:GetFrameLevel() <= rns.Headers.raid[1]:GetFrameLevel(), "and draws under the raid's rows")
	eq(rcard.cap.title:GetText(), "RAID", "the cap reads Raid")
	eq(rcard.cap.aside:GetText(), "12", "the aside counts the raid")
	local cap = RK.Widgets.SECTION_CAP_HEIGHT
	local full = rns.Geometry.RaidGroups(rs)
	local fw, fh = rholder:GetSize()
	assert(near(fw, full.width + 40) and near(fh, full.height + 40 + cap + 8), "the holder keeps the eight groups' footprint")
	local first = rns.Headers.raid[1]._points[1]
	assert(first[1] == full.corner and near(first[4], 20) and near(-first[5], 20 + cap + 8), "group 1 hangs under the cap inside the padding")
	local function cardFor(groups)
		local shown = rns.Geometry.RaidGroups(rs, groups)
		return shown.width + 40, shown.height + 40 + cap + 8
	end
	local w3, h3 = cardFor(3)
	assert(near(rcard.frame:GetWidth(), w3) and near(rcard.frame:GetHeight(), h3), "twelve members in three groups make a three-group card: " .. tostring(rcard.frame:GetWidth()))
	-- Eight join in combat: the card widens to five groups with no protected call.
	renv._combat = true
	G.SetRoster(renv, "raid", G.Members(20))
	renv.RunTimers()
	W.Settle(renv)
	eq(#renv._blocked, 0, "resizing the raid card in combat touches nothing protected: " .. tostring(renv._blocked[1]))
	local w4 = cardFor(4)
	assert(near(rcard.frame:GetWidth(), w4), "twenty members make a four-group card: " .. tostring(rcard.frame:GetWidth()))
	eq(rcard.cap.aside:GetText(), "20", "and the cap counts twenty")
	renv._combat = false
	renv.RunTimers()
	-- A member alone in group 7 widens the card to the seventh group.
	local members = G.Members(11)
	members[11].group = 7
	G.SetRoster(renv, "raid", members)
	renv.RunTimers()
	W.Settle(renv)
	assert(near(rcard.frame:GetWidth(), (cardFor(7))), "the card reaches the highest group in use")
	-- The card can be turned off: the raid stands bare and its holder is the groups.
	RK.Options.Write("GroupFrames", "raid.card", false)
	renv.RunTimers()
	assert(not rcard.frame:IsShown(), "the card hides")
	fw, fh = rholder:GetSize()
	assert(near(fw, full.width) and near(fh, full.height), "and the holder is the groups")
	first = rns.Headers.raid[1]._points[1]
	assert(near(first[4], 0) and near(first[5], 0), "group 1 hangs from the holder's corner")
	-- A raid row wears no tile of its own in the lanes layout.
	local lead = rns.Button.Content(rns.Headers.raid[1]._attributes.child1)
	assert(lead and lead.tileless and not lead.chrome.fill[5]:IsShown(), "a raid row wears no tile: the card is the glass")
	eq(#renv._errors, 0, tostring(renv._errors[1]))
end
print("groupframes card ok")
