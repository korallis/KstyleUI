-- test-widgets-sectioncap.lua: the rail section cap: the picture's solid gilt diamond, a tracked Cinzel caption, a half-strength gilt rule and an optional count at the right end.
local W = dofile("Tools/regression/widget_env.lua")

local env, K = W.New()
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local root = Scale.Root()

local function file(region)
	local call = W.LastCall(region, "SetTexture")
	return call and type(call[1]) == "string" and call[1]:match("([^\\]+)$") or nil
end

local function textIs(text, name)
	local r, g, b = text:GetTextColor()
	local wr, wg, wb = Tokens.Color(name)
	return W.Near(r, wr) and W.Near(g, wg) and W.Near(b, wb)
end

local function point(region, name)
	for _, p in ipairs(region._points or {}) do
		if p[1] == name then
			return p
		end
	end
end

assert(type(Widgets.SectionCap) == "function", "Widgets.SectionCap exists")
K.Options.Write("Widgets", "cardMaterial", "Glass")
local cap = Widgets.SectionCap(root, { text = "Party", width = 278 })

-- The diamond leads, the head follows it in the caps role, in the picture's gold.
assert(file(cap.gem) == "Diamond.png", "the diamond leads the cap")
assert(W.SameRGB(cap.gem, Tokens.Color("capsGold")), "the diamond is the caption's gold, not the lit gilt")
assert(W.SameColor(cap.gem, select(1, Tokens.Color("capsGold")), select(2, Tokens.Color("capsGold")), select(3, Tokens.Color("capsGold")), 1), "and solid")
local gemAt = point(cap.gem, "CENTER")
assert(gemAt and gemAt[2] == cap and gemAt[3] == "LEFT" and gemAt[4] > 0, "centred a little in from the cap's left edge, on its midline")
local _, headSize = cap.label:GetFont()
assert(headSize > Tokens.Size("caps"), "the head reads larger than the kit's caps size, at the picture's 12")
local path = cap.label:GetFont()
assert(path == (Tokens.Font("caps")), "the head is in the caps role")
assert(path:match("CinzelCaps%-Medium%.ttf$"), "which is tracked Cinzel")
assert(cap.label:GetText() == "PARTY", "and uppercase, got " .. tostring(cap.label:GetText()))
assert(textIs(cap.label, "capsGold"), "in the picture's muted gold")
local lp = point(cap.label, "LEFT")
assert(lp and lp[2] == cap.gem and lp[3] == "CENTER" and lp[4] > 0, "the caption is set off the diamond's centre")

-- The rule is one flat half-strength line in the caption's gold, from the caption to the cap's right end when there is no count: the picture's does not fade.
assert(file(cap.rule) == nil, "the rule is a flat colour, not a fading strip")
local flat = W.LastCall(cap.rule, "SetColorTexture")
assert(flat, "the rule is a colour texture")
local cr, cg, cb = Tokens.Color("capsGold")
assert(W.Near(flat[1], cr) and W.Near(flat[2], cg) and W.Near(flat[3], cb) and W.Near(flat[4], 0.5), "in the caption's gold at half strength")
local rl, rr = point(cap.rule, "LEFT"), point(cap.rule, "RIGHT")
assert(rl and rl[2] == cap.label and rl[3] == "RIGHT", "the rule starts after the caption")
assert(rr and rr[2] == cap and rr[3] == "RIGHT", "with no count the rule runs to the cap's right end")
assert(not cap.count:IsShown(), "no count is shown")
assert(W.Near(cap:GetWidth(), 278), "the cap takes the width it is given")
assert(cap:GetHeight() >= Tokens.Size("caption"), "and is at least one caption tall")

-- A count sits at the right end in the body face, muted, and the rule stops short of it.
cap:SetCount(3)
assert(cap.count:IsShown() and tostring(cap.count:GetText()) == "3", "the count shows")
assert(textIs(cap.count, "muted"), "muted")
assert((cap.count:GetFont()) == (Tokens.Font("number")), "in the number role, so it keeps its width")
rr = point(cap.rule, "RIGHT")
assert(rr[2] == cap.count and rr[3] == "LEFT", "the rule stops before the count")
local cp = point(cap.count, "RIGHT")
assert(cp and cp[2] == cap and cp[3] == "RIGHT", "the count sits at the right end")
cap:SetCount(nil)
assert(not cap.count:IsShown() and point(cap.rule, "RIGHT")[2] == cap, "clearing the count gives the rule back its length")

-- A count drawn by another frame: the cap measures its text on a ruler that is never shown and reserves that
-- width, so the rule stops short of it while the cap's own count stays hidden and empty.
local ruled = cap.ruler
assert(ruled and not ruled:IsShown(), "the ruler is hidden")
local width = cap:MeasureCount("+00")
assert(type(width) == "number" and width >= 0, "the ruler measures the count's text")
assert(ruled:GetText() == "" and not ruled:IsShown(), "and keeps no text after measuring")
cap:SetReserve(30)
rr = point(cap.rule, "RIGHT")
assert(rr[2] == cap and rr[3] == "RIGHT" and W.Near(rr[4], -(30 + Widgets.Snap(cap, 8.6))), "the rule stops a gap short of the reserved width")
assert(not cap.count:IsShown() and (cap.count:GetText() == nil or cap.count:GetText() == ""), "the cap's own count stays hidden and empty")
cap:Restyle()
assert(W.Near(point(cap.rule, "RIGHT")[4], -(30 + Widgets.Snap(cap, 8.6))) and not cap.count:IsShown(), "a restyle keeps the reserve and the hidden count")
cap:SetCount(3)
assert(cap.count:IsShown() and point(cap.rule, "RIGHT")[2] == cap.count, "a count of its own wins over the reserve")
cap:SetCount(nil)
cap:SetReserve(nil)
assert(point(cap.rule, "RIGHT")[2] == cap and W.Near(point(cap.rule, "RIGHT")[4] or 0, 0), "clearing the reserve gives the rule back its length")

-- A secret count reaches the font string untouched.
local secret = env.Secret and env.Secret(12)
if secret then
	cap:SetCount(secret)
	assert(cap.count:IsShown(), "a secret count shows")
end

cap:SetText("Quests")
assert(cap.label:GetText() == "QUESTS", "the caption can change")

-- The caption follows the Appearance page's text size like the count does.
local _, plain = cap.label:GetFont()
assert(K.Theme.SetFontScale(1.3), "the text size changes")
cap:Restyle()
local _, scaled = cap.label:GetFont()
assert(scaled > plain * 1.2, "a larger text size grows the caption: " .. tostring(plain) .. " to " .. tostring(scaled))
assert(K.Theme.SetFontScale(0.8), "a smaller text size")
cap:Restyle()
local _, small = cap.label:GetFont()
assert(small >= Tokens.Size("caps") * 0.99, "never below the kit's minimum text size: " .. tostring(small))
K.Theme.SetFontScale(1)
cap:Restyle()

-- The cap restyles with the theme.
K.Theme.SetFontFace("SourceSans3Semibold")
assert((cap.label:GetFont()):match("SourceSans3%-Semibold%.ttf$"), "a font change reaches the caption")

-- The mark is the Skins caption bullet's `diamond` texture at 8 root units from point to point (14 px on the reference
-- panel), on whole pixels, and on each of the nine screens within a pixel of 8.
do
	local screens = { { 1280, 720 }, { 1366, 768 }, { 1600, 900 }, { 1920, 1080 }, { 2234, 1234 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 2160 } }
	for _, size in ipairs(screens) do
		local senv, SK = W.New()
		senv._physical = size
		senv.GetPhysicalScreenSize = function()
			return senv._physical[1], senv._physical[2]
		end
		senv.FireEvent("DISPLAY_SIZE_CHANGED")
		local scap = SK.Widgets.SectionCap(SK.Scale.Root(), { text = "Party" })
		local pixel = SK.Scale.Pixel(1)
		local quad = scap.gem:GetWidth() / pixel
		local label = size[1] .. "x" .. size[2]
		assert(W.Near(quad, math.floor(quad + 0.5)), "the diamond's quad is whole pixels on " .. label .. ", got " .. quad)
		assert(math.abs(quad - 8 / pixel) <= 1, "the diamond is within a pixel of 8 root units on " .. label .. ", got " .. quad .. " pixels for " .. 8 / pixel)
	end
end

assert(#env._errors == 0, tostring(env._errors[1]))
print("widgets section cap ok")
