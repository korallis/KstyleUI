-- test-tracked-caps.lua: the caps role draws Cinzel Medium from CinzelCaps-Medium.ttf, whose advances carry the letter spacing; Locale.TrackMode tells how a face is spaced, a client whose script the face lacks falls back, and the tracking left after the last letter never moves centred or right-aligned text.
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
assert(path:match("CinzelCaps%-Medium%.ttf$"), "the caps role is the tracked Cinzel file, got " .. tostring(path))
assert(size == Tokens.Size("caps") and size == 10 and flags == "", "the picture's 10-unit heading, no outline")
local _, upper = Tokens.TextStyle("caps")
assert(upper == true, "the caps role is uppercase")
assert(Tokens.FaceTracking(path) == 0.065, "the face is tracked 0.065 em, the picture's")
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
assert(pad > 0 and math.abs(pad - 0.065 * fontSize) < 1e-6, "the pad after the last letter is 0.065 em, got " .. tostring(pad))
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
assert(Near(Moved("CENTER", 0), 0.065 * select(2, text:GetFont()) / 2), "a bigger size means a bigger pad")
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
	assert(tracked:match("CinzelCaps%-Medium%.ttf$"), locale .. " draws the tracked face")
	assert(localeK.Locale.TrackMode(tracked) == "face", locale .. " leaves the spacing to the face")
end

for _, locale in ipairs({ "ruRU", "zhCN", "zhTW", "koKR" }) do
	local fallbackEnv, localeK = Boot(locale)
	local fallback = localeK.Tokens.Font("caps")
	assert(not fallback:match("CinzelCaps"), locale .. " falls back to the game's font, got " .. tostring(fallback))
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

local namesPath, namesSize, namesFlags = Tokens.Font("names")
assert(namesPath:match("CinzelNames%-Medium%.ttf$"), "the names role is the lightly tracked Cinzel file, got " .. tostring(namesPath))
assert(namesSize == 10 and namesFlags == "", "the picture's 10-unit names, no outline")
local _, namesUpper = Tokens.TextStyle("names")
assert(namesUpper == true, "the names role is uppercase")
assert(Tokens.FaceTracking(namesPath) == 0.02, "the names face is tracked 0.02 em, the picture's white headings")
assert(Locale.TrackMode(namesPath) == "face" and Locale.CanTrack(namesPath), "the names face spaces its own letters")
local namesShadow = Tokens.FaceShadow(namesPath)
assert(type(namesShadow) == "table" and namesShadow.x == 1 and namesShadow.y == 1 and namesShadow.alpha == 0.5, "the picture's names carry a soft halo; the client draws only a hard offset copy, so the names face casts a lighter one: one border down and right at half the kit's opacity")
local named = Widgets.Text(root, "names", "text")
Widgets.ApplyFont(named, namesPath, 100 * px, "")
assert(math.abs(Widgets.TrackPad(named) - 0.02 * select(2, named:GetFont())) < 1e-6, "the names pad is 0.02 em")
local namedShadow = W.LastCall(named, "SetShadowOffset")
local border = Scale.Border() / Widgets.ScaleFactor(named)
assert(namedShadow and W.Near(namedShadow[1], border) and W.Near(namedShadow[2], -border), "the names shadow is one border down and right, a whole pixel")
local namedColour = W.LastCall(named, "SetShadowColor")
assert(namedColour and namedColour[1] == 0 and namedColour[2] == 0 and namedColour[3] == 0 and W.Near(namedColour[4], 0.5), "black at half opacity")
Widgets.ApplyFont(shaded, semibold, 12, "")
assert(W.Near(W.LastCall(shaded, "SetShadowColor")[4], select(4, Tokens.Color("textShadow"))), "every other face keeps the kit's opacity")
local unitPath, unitSize, unitFlags = Tokens.Font("unit")
assert(unitPath:match("CinzelUnit%-Medium%.ttf$"), "the unit role is the tight Cinzel file, got " .. tostring(unitPath))
assert(unitSize == 18 and unitFlags == "", "the picture's unit names are about 37 px, 18 units, no outline")
local _, unitUpper = Tokens.TextStyle("unit")
assert(unitUpper == true, "the unit role is uppercase")
assert(Tokens.FaceTracking(unitPath) == -0.055, "the unit face is tracked -0.055 em: the picture draws KORALLIS and SHADOWGALE POACHER tighter than Cinzel's own advances")
assert(Locale.TrackMode(unitPath) == "face" and Locale.CanTrack(unitPath), "the unit face spaces its own letters")
assert(Tokens.FaceShadow(unitPath) == namesShadow or (Tokens.FaceShadow(unitPath).x == 1 and Tokens.FaceShadow(unitPath).alpha == 0.5), "the unit face casts the names' lighter shadow")
local unit = Widgets.Text(root, "unit", "text")
unit:SetPoint("RIGHT", root, "RIGHT", -10, 0)
Widgets.ApplyFont(unit, unitPath, 100 * px, "")
local unitPad = Widgets.TrackPad(unit)
assert(unitPad < 0 and math.abs(unitPad + 0.055 * select(2, unit:GetFont())) < 1e-6, "the unit pad is -0.055 em, a negative trailing advance")
assert(Near((Placed(unit, "RIGHT") or 1e9) + 10, unitPad), "a right anchor moves left by the whole negative pad, so the ink ends where the caller put it")
unit:ClearAllPoints()
unit:SetPoint("CENTER", root, "CENTER", 0, 0)
assert(Near(Placed(unit, "CENTER"), unitPad / 2), "a centre anchor moves left by half of it")
for _, role in ipairs({ "caps", "names", "unit" }) do
	for _, locale in ipairs({ "ruRU", "zhCN", "zhTW", "koKR" }) do
		local _, localeK = Boot(locale)
		local face = localeK.Tokens.Font(role)
		assert(not face:match("Cinzel") and localeK.Tokens.FaceTracking(face) == 0 and localeK.Tokens.FaceShadow(face) == true, locale .. " " .. role .. " falls back to the game's font, untracked, with its shadow")
	end
end

assert(#env._errors == 0, tostring(env._errors[1]))
print("test-tracked-caps: the caps role is tracked Cinzel, spaced by its own advances, pad-corrected and locale-safe")
