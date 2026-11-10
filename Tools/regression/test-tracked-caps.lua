-- test-tracked-caps.lua: the caps role draws Cinzel Regular from CinzelTracked-Regular.ttf, whose advances carry the letter spacing; Locale.TrackMode tells how a face is spaced, a client whose script the face lacks falls back, and the tracking left after the last letter never moves centred or right-aligned text.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local THIN_SPACE = "\226\128\137"

local function Boot(locale)
	return W.New({
		setup = function(env)
			env._textWidth = function(text, fontPath, size)
				return Scene.TextWidth(text, size, fontPath)
			end
			if locale then
				env.GetLocale = function()
					return locale
				end
			end
		end,
	})
end

local env, K = Boot("enUS")
local Widgets, Tokens, Scale, Locale = K.Widgets, K.Tokens, K.Scale, K.Locale
local root = Scale.Root()

local path, size, flags = Tokens.Font("caps")
assert(path:match("CinzelTracked%-Regular%.ttf$"), "the caps role is the tracked Cinzel file, got " .. tostring(path))
assert(size == Tokens.Size("caps") and size == 10 and flags == "", "the picture's 10-unit heading, no outline")
local _, upper = Tokens.TextStyle("caps")
assert(upper == true, "the caps role is uppercase")
assert(Tokens.FaceTracking(path) == 0.08, "the face is tracked 0.08 em, the picture's")
assert(Tokens.FaceTracking(Tokens.FontPath("CinzelSemiBold")) == 0, "Cinzel SemiBold is not tracked")
local r, g, b = Tokens.Color("capsGold")
assert(W.Near(r, 0xd3 / 255) and W.Near(g, 0xb5 / 255) and W.Near(b, 0x74 / 255), "capsGold is the picture's #d3b574")

local semibold = Tokens.FontPath("CinzelSemiBold")
assert(Locale.TrackMode(path) == "face" and Locale.CanTrack(path) == true, "the tracked face spaces its own letters")
assert(Locale.TrackMode(semibold) == nil and Locale.CanTrack(semibold) == false, "Cinzel SemiBold cannot be spaced at all")
assert(Locale.TrackMode(Tokens.FontPath("AlegreyaSansRegular")) == "space", "Alegreya is spaced with thin spaces")

local text = Widgets.Text(root, "caps", "capsGold")
local px = Scale.Pixel(1) / Widgets.ScaleFactor(text)
Widgets.ApplyFont(text, path, 100 * px, "")
Widgets.SetText(text, "Skyborne")
assert(text:GetText() == "SKYBORNE" and not text:GetText():find(THIN_SPACE, 1, true), "capitals, no thin space")
local pad = Widgets.TrackPad(text)
local _, fontSize = text:GetFont()
assert(pad > 0 and math.abs(pad - 0.08 * fontSize) < 1e-6, "the pad after the last letter is 0.08 em, got " .. tostring(pad))
local natural = Scene.TextWidth("SKYBORNE", fontSize, (text:GetFont()))
assert(math.abs(Widgets.TextWidth(text) - (natural - pad)) < 1e-6, "the measure stops at the last letter's ink")

assert(pad >= 6 * px, "the pad is several pixels wide here, so a missing shift cannot hide inside the rounding")
local function Placed(region, point)
	for _, anchor in ipairs(region._points) do
		if anchor[1] == point then
			return anchor[#anchor - 1]
		end
	end
end
local function Moved(point, set)
	return (Placed(text, point) or 1e9) - set
end
local function Near(value, expected)
	return math.abs(value - expected) <= px
end

text:ClearAllPoints()
text:SetPoint("CENTER", root, "CENTER", 40, 0)
assert(Near(Moved("CENTER", 40), pad / 2), "a centre anchor moves right by half the pad")
assert(select(4, text:GetPoint()) == 40, "GetPoint still answers the offset the caller set")
text:ClearAllPoints()
text:SetPoint("RIGHT", root, "RIGHT", -10, 0)
assert(Near(Moved("RIGHT", -10), pad), "a right anchor moves right by the whole pad")
text:ClearAllPoints()
text:SetPoint("LEFT", root, "LEFT", 10, 0)
assert(Near(Moved("LEFT", 10), 0), "a left anchor does not move")

text:ClearAllPoints()
text:SetWidth(200)
text:SetPoint("LEFT", root, "LEFT", 10, 0)
text:SetJustifyH("CENTER")
assert(Near(Moved("LEFT", 10), pad / 2), "centred in a wide box: half the pad")
text:SetJustifyH("RIGHT")
assert(Near(Moved("LEFT", 10), pad), "right-aligned in a wide box: the whole pad")
text:SetJustifyH("LEFT")
assert(Near(Moved("LEFT", 10), 0), "left-aligned in a wide box: none")
text:SetWidth(0)
text:ClearAllPoints()
text:SetPoint("LEFT", root, "LEFT", 5, 0)
text:SetPoint("RIGHT", root, "RIGHT", -5, 0)
text:SetJustifyH("RIGHT")
assert(Near(Moved("LEFT", 5), pad) and Near(Moved("RIGHT", -5), pad), "both anchors of a right-aligned text move together")
text:SetJustifyH("CENTER")
assert(Near(Moved("LEFT", 5), pad / 2) and Near(Moved("RIGHT", -5), pad / 2), "and the centred one by half")

text:SetJustifyH("LEFT")
text:ClearAllPoints()
text:SetPoint("CENTER", root, "CENTER", 0, 0)
Widgets.ApplyFont(text, Tokens.FontPath("AlegreyaSansRegular"), 12, "")
assert(Widgets.TrackPad(text) == 0 and Near(Moved("CENTER", 0), 0), "an untracked face leaves the anchor where it was set")
Widgets.ApplyFont(text, path, 200 * px, "")
assert(Near(Moved("CENTER", 0), 0.08 * select(2, text:GetFont()) / 2), "a bigger size means a bigger pad")
assert(Widgets.TrackPad(text) > pad * 1.9, "the pad follows the size")

local own = Widgets.FontString(root, "OVERLAY")
own:SetPoint("RIGHT", root, "RIGHT", 0, 0)
own:SetFont(path, 100 * px, "")
Widgets.SyncTracking(own)
assert(Widgets.TrackPad(own) > 0 and Near(Placed(own, "RIGHT"), Widgets.TrackPad(own)), "SyncTracking reads whatever font a text has been given")

local cap = Widgets.SectionCap(root, { text = "Party", count = 3, width = 278 })
assert((cap.label:GetFont()) == path, "the section cap head is in the caps role")
local cr, cg, cb = cap.label:GetTextColor()
assert(W.Near(cr, r) and W.Near(cg, g) and W.Near(cb, b), "in capsGold")
assert(cap.label:GetText() == "PARTY", "uppercase")
local rule
for _, anchor in ipairs(cap.rule._points) do
	if anchor[1] == "LEFT" then
		rule = anchor
	end
end
assert(rule and rule[2] == cap.label, "the rule starts at the head")
assert(math.abs(rule[#rule - 1] + Widgets.TrackPad(cap.label) - Widgets.Snap(cap, 10)) <= 2 * px, "one gap after the last letter's ink, not after its pad")

for _, locale in ipairs({ "enUS", "deDE", "frFR", "esES" }) do
	local _, localeK = Boot(locale)
	local tracked = localeK.Tokens.Font("caps")
	assert(tracked:match("CinzelTracked%-Regular%.ttf$"), locale .. " draws the tracked face")
	assert(localeK.Locale.TrackMode(tracked) == "face", locale .. " leaves the spacing to the face")
end

for _, locale in ipairs({ "ruRU", "zhCN", "zhTW", "koKR" }) do
	local fallbackEnv, localeK = Boot(locale)
	local fallback = localeK.Tokens.Font("caps")
	assert(not fallback:match("CinzelTracked"), locale .. " falls back to the game's font, got " .. tostring(fallback))
	assert(localeK.Tokens.FaceTracking(fallback) == 0, locale .. " reads no tracking for the game's font")
	assert(localeK.Locale.TrackMode(fallback) ~= "face", locale .. " does not call the game's font tracked")
	local t = localeK.Widgets.Text(localeK.Scale.Root(), "caps", "capsGold")
	assert(localeK.Widgets.TrackPad(t) == 0, locale .. " compensates nothing for a font without tracking")
	assert(#fallbackEnv._errors == 0, tostring(fallbackEnv._errors[1]))
end

assert(Tokens.FaceShadow(path) == false and Tokens.FaceShadow(semibold) == true, "only the tracked face is drawn without the kit's text shadow")
local shaded = Widgets.Text(root, "heading", "text")
Widgets.ApplyFont(shaded, semibold, 12, "")
local shadeOffset = W.LastCall(shaded, "SetShadowOffset")
assert(shadeOffset and shadeOffset[1] ~= 0 and shadeOffset[2] ~= 0, "an ordinary face keeps the kit's text shadow")
Widgets.ApplyFont(text, path, 12, "")
local flatOffset = W.LastCall(text, "SetShadowOffset")
assert(flatOffset and flatOffset[1] == 0 and flatOffset[2] == 0, "the picture draws its captions without a shadow")
Widgets.TextShadow(text)
flatOffset = W.LastCall(text, "SetShadowOffset")
assert(flatOffset[1] == 0 and flatOffset[2] == 0, "and TextShadow leaves it off")

assert(#env._errors == 0, tostring(env._errors[1]))
print("test-tracked-caps: the caps role is tracked Cinzel, spaced by its own advances, pad-corrected and locale-safe")
