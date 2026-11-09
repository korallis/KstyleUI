-- test-widgets-rail.lua: the rail cards' shared Lumen pieces: the Lumen colour names with their fallbacks, the section cap (gem, tracked title, fading rule, aside), the class pill and the crystal disc.
local W = dofile("Tools/regression/widget_env.lua")

local env, K = W.New()
local Widgets, Tokens = K.Widgets, K.Tokens
local root = K.Scale.Root()

-- Lumen colour names resolve, through a fallback token until the material foundation adds the real token.
assert(type(Widgets.LumenColor) == "function", "Widgets.LumenColor exists")
assert(type(Widgets.LUMEN_FALLBACK) == "table", "the fallbacks are listed in one table")
for name, alias in pairs(Widgets.LUMEN_FALLBACK) do
	local r, g, b, a = Widgets.LumenColor(name)
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number" and type(a) == "number", name .. " gives r, g, b, a")
	assert(pcall(Tokens.Color, alias[1]), name .. " falls back to an existing token")
end
local gr, gg, gb = Widgets.LumenColor("gilt")
assert(gr > gb, "gilt is warm: more red than blue")
local r, g, b, a = Widgets.LumenColor("gilt", 0.5)
assert(W.Near(a, 0.5) and r == gr and g == gg and b == gb, "an alpha scale scales only the alpha")
assert(not pcall(Widgets.LumenColor, "noSuchLumenName"), "an unknown name is an error, as Tokens.Color is")
assert(pcall(Widgets.LumenColor, "hostile"), "a plain token name passes straight through")

-- The section cap: a gem, a tracked caption title, a rule that fades out, and an optional aside at the right.
local card = env.CreateFrame("Frame", nil, root)
card:SetSize(318, 120)
local cap = Widgets.SectionCap(card, { title = "Blessings" })
assert(type(cap) == "table" and cap.frame and cap.gem and cap.title and cap.rule, "the cap has a frame, a gem, a title and a rule")
assert(cap.frame:GetParent() == card, "the cap frame sits on the card")
assert(cap.title:GetText() == "BLESSINGS", "the title is set in tracked caps through the caption role")
assert(W.Near(cap.frame:GetHeight(), Widgets.SECTION_CAP_HEIGHT), "the cap frame is the shared cap height")
assert(W.Near(cap.gem:GetWidth(), Widgets.GEM_SIZE) and W.Near(cap.gem:GetHeight(), Widgets.GEM_SIZE), "the gem is the shared gem size")
local rotation = W.LastCall(cap.gem, "SetRotation")
assert(rotation and W.Near(rotation[1], math.pi / 4), "the gem is a square turned 45 degrees")
assert(W.SameRGB(cap.gem, gr, gg, gb), "the gem is gilt")
assert(W.SameRGB(cap.title, gr, gg, gb) or select(1, cap.title:GetTextColor()) == gr, "the title is gilt")
local gp = cap.gem._points[1]
assert(gp[1] == "LEFT" and gp[2] == cap.frame, "the gem leads at the left")
local tp = cap.title._points[1]
assert(tp[1] == "LEFT" and tp[2] == cap.gem and tp[3] == "RIGHT", "the title follows the gem")
local rp = cap.rule._points[1]
assert(rp[1] == "LEFT" and rp[2] == cap.title and rp[3] == "RIGHT", "the rule starts after the title")
assert(cap.rule._points[2] and cap.rule._points[2][1] == "RIGHT" and cap.rule._points[2][2] == cap.frame, "and runs to the cap's right edge")
assert(W.LastCall(cap.rule, "SetTexture")[1] == (Tokens.Texture("divider")), "the rule is the divider texture, which fades out along its length")
assert(cap.aside == nil or not cap.aside:IsShown() or cap.aside:GetText() == "", "no aside until one is set")
cap:SetAside("Last fight")
assert(cap.aside and cap.aside:GetText() == "Last fight" and cap.aside:IsShown(), "SetAside shows a muted text at the right")
local ap = cap.aside._points[1]
assert(ap[1] == "RIGHT" and ap[2] == cap.frame, "the aside hugs the right edge")
assert(cap.rule._points[2][2] == cap.aside, "the rule now stops before the aside")
cap:SetAside(nil)
assert(not cap.aside:IsShown(), "clearing the aside hides it")
assert(cap.rule._points[2][2] == cap.frame, "and the rule runs to the edge again")
cap:SetTitle("Damage")
assert(cap.title:GetText() == "DAMAGE", "SetTitle sets the tracked title")
cap:Restyle()
assert(W.Near(cap.frame:GetHeight(), Widgets.SECTION_CAP_HEIGHT), "Restyle keeps the height")

-- The class pill: a 4-unit pill track that fills by a share and glows in its colour.
local pill = Widgets.ClassPill(card, { height = 4 })
assert(pill.track and pill.fill and pill.glow, "the pill has a track, a fill and a glow")
pill:SetColor(0.2, 0.6, 1)
assert(W.SameRGB(pill.fill[2], 0.2, 0.6, 1) and W.SameRGB(pill.glow, 0.2, 0.6, 1), "fill and glow take the colour")
local _, _, _, ta = pill.track[2]:GetVertexColor()
assert(ta < 1, "the track is dim")
pill:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
pill:SetWidth(200)
pill:SetShare(0.5)
assert(W.Near(pill.fill[2]:GetParent():GetWidth(), 100) or W.Near(pill.fillBox:GetWidth(), 100), "half a share fills half the width")
pill:SetShare(2)
assert(W.Near(pill.fillBox:GetWidth(), 200), "a share above one fills the whole track")
pill:SetShare(0)
assert(pill.fillBox:GetWidth() <= 1, "no share leaves the track bare")
assert(W.Near(pill:GetHeight(), 4), "the pill is the height asked for")

-- The crystal disc: a round dark disc with a bevelled ring, for round buttons on a lens edge or a menu row.
local button = env.CreateFrame("Button", nil, card)
button:SetSize(24, 24)
local disc = Widgets.CrystalDisc(button)
assert(disc.disc and disc.ring, "a disc and a ring")
assert(disc.disc._points[1][2] == button, "the disc fills the button")
assert(select(1, Tokens.Texture("dot")) == W.LastCall(disc.disc, "SetTexture")[1], "the disc is the dot texture")
assert(select(1, Tokens.Texture("ringBevel")) == W.LastCall(disc.ring, "SetTexture")[1], "the ring is the bevelled ring")
disc:SetRim(1, 0, 0, 1)
assert(W.SameRGB(disc.ring, 1, 0, 0), "SetRim colours the ring")
disc:Restyle()
local fr, fg, fb = Tokens.Color("buttonFill")
assert(W.SameRGB(disc.disc, fr, fg, fb), "the disc is the button fill")

assert(#env._errors == 0, tostring(env._errors[1]))
print("ok")
