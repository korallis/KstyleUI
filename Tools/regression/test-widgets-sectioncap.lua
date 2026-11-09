-- test-widgets-sectioncap.lua: the rail section cap: a gilt gem, a tracked Cinzel caption, a rule that fades out to the right, and an optional count at the right end.
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
local cap = Widgets.SectionCap(root, { text = "Party", width = 278 })

-- The gem leads, the caption follows it in the caption role, in gilt.
assert(file(cap.gem) == "LumenGem.png", "a gilt gem leads the cap")
assert(W.SameRGB(cap.gem, Tokens.Color("giltLit")), "the gem is lit gilt")
local path = cap.label:GetFont()
assert(path == (Tokens.Font("caption")), "the caption is in the caption role")
assert(path:match("Cinzel%-SemiBold%.ttf$"), "which is Cinzel")
assert(cap.label:GetText() == "PARTY", "and uppercase, got " .. tostring(cap.label:GetText()))
assert(textIs(cap.label, "giltLit"), "in lit gilt")
local lp = point(cap.label, "LEFT")
assert(lp and lp[2] == cap.gem and lp[3] == "RIGHT", "the caption sits right of the gem")

-- The rule fades out to the right, from the caption to the cap's right end when there is no count.
assert(file(cap.rule) == "RuleFade.png", "the rule fades out")
assert(W.SameRGB(cap.rule, Tokens.Color("gilt")), "a gilt rule")
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

-- A secret count reaches the font string untouched.
local secret = env.Secret and env.Secret(12)
if secret then
	cap:SetCount(secret)
	assert(cap.count:IsShown(), "a secret count shows")
end

cap:SetText("Quests")
assert(cap.label:GetText() == "QUESTS", "the caption can change")

-- The cap restyles with the theme.
K.Theme.SetFontFace("SourceSans3Semibold")
assert((cap.label:GetFont()):match("SourceSans3%-Semibold%.ttf$"), "a font change reaches the caption")

assert(#env._errors == 0, tostring(env._errors[1]))
print("widgets section cap ok")
