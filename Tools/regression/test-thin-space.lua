-- test-thin-space.lua: Cinzel has no thin-space glyph, so the game draws a box for one; tracked headings set in Cinzel must never carry a thin space, while fonts that have the glyph still get the tracking.
local S = dofile("Tools/regression/skins_env.lua")
local THIN_SPACE = "\226\128\137"

local env, K, ns = S.New()
local Locale, Tokens = K.Locale, K.Tokens
local cinzel = Tokens.FontPath("CinzelSemiBold")
local alegreya = Tokens.FontPath("AlegreyaSansTabularRegular") or Tokens.FontPath("AlegreyaSansRegular")

assert(type(cinzel) == "string" and cinzel:find("Cinzel", 1, true), "the Cinzel path resolves")
assert(Locale.CanTrack(cinzel) == false, "Cinzel lacks a thin-space glyph, so it is never tracked")
if type(alegreya) == "string" then
	assert(Locale.CanTrack(alegreya) == true, "Alegreya has the glyph and keeps its tracking")
end

assert(select(1, Tokens.Font("title")) == cinzel, "the Lumen title role is Cinzel")
local tracked = ns.Lumen.Tracked("QUESTS")
assert(not tracked:find(THIN_SPACE, 1, true), "the quest cap carries no thin space: " .. tracked)
assert(tracked == "QUESTS", "the quest cap reads its letters as given, got " .. tracked)

local tip = K.Widgets.Tooltip and K.Widgets.Tooltip()
if tip and tip.AddTitle then
	tip:AddTitle("Vanquisher's Blade")
	for _, line in ipairs(tip.lines or {}) do
		local text = line.left and line.left:GetText()
		if type(text) == "string" then
			assert(not text:find(THIN_SPACE, 1, true), "a Cinzel tooltip title carries no thin space: " .. text)
		end
	end
end

local tracked = Tokens.Font("caps")
assert(Locale.TrackMode(tracked) == "face" and Locale.CanTrack(tracked) == true, "the tracked face is spaced by its own advances")
assert(Locale.TrackMode(cinzel) == nil and Locale.TrackMode(tracked) ~= "space", "no Cinzel file is ever spaced with thin spaces")
assert(not ns.Lumen.Tracked("QUESTS"):find(THIN_SPACE, 1, true), "the caps cap carries no thin space")

local files = { "Core/Widgets/Tooltip.lua", "KstyleUI_Skins/Lumen.lua", "KstyleUI_UnitFrames/Unit.lua" }
for _, file in ipairs(files) do
	local handle = assert(io.open(file, "rb"))
	local source = handle:read("*a")
	handle:close()
	assert(source:find('TrackMode', 1, true) and source:find('"space"', 1, true), file .. " asks Locale.TrackMode for the thin-space method before it inserts thin spaces")
end

assert(#env._errors == 0, tostring(env._errors[1]))
print("test-thin-space: tracked Cinzel text never carries a thin space")
