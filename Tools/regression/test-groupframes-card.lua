-- test-groupframes-card.lua: the Lumen party card: a section cap with Party and the count over the member rows, each a role ring in the class colour, a name, a class and level caption and a class pill, with the raid frames in the same language.
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

-- Defaults: a 278 row for the 318 card, one class pill, no power bar, the class and level caption on.
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
assert(near(f.health:GetHeight(), ns.Style.PILL_HEIGHT) and ns.Style.PILL_HEIGHT >= 6 and ns.Style.PILL_HEIGHT <= 7, "the health bar is the 6 to 7 unit class pill: " .. tostring(f.health:GetHeight()))
local hb = f.health._points[1]
local foot = f:GetHeight() - (-hb[5] + f.health:GetHeight())
assert(hb[1] == "TOPLEFT" and foot >= ns.Style.PILL_RISE and foot <= ns.Style.PILL_RISE + 4, "the pill runs along the row's foot, inside the row's inner padding: " .. tostring(foot))
assert(-hb[5] > f.parts.name.top + f.parts.name.height + 4, "with air between the name line and the pill")
assert(f.health:GetWidth() > f:GetWidth() - 60, "the pill spans the row past the ring: " .. tostring(f.health:GetWidth()))
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

-- Raid frames: compact rows in the same language, a thin pill under the name, no card of their own.
local raid = Settings.current.raid
assert(raid.roleRing == false and raid.classLine == false, "raid frames keep their compact face")
assert(Headers.cards.raid == nil, "no card round the raid frames: they are the compact grid")

eq(#env._errors, 0, tostring(env._errors[1]))
print("groupframes card ok")
