-- test-meters-card.lua: the damage card as the owner's picture draws it (LEE-20, "let the picture win"): the cap names the meter with the rate at its right, five bars as tall as the row coloured by the spell's school, no icons, and "412 · 46%" at the right of each.
local M = dofile("Tools/regression/meters_env.lua")
local W = M.W

local SPELLS = {
	{ 403, "Lightning Bolt", 412, "meterNature" },
	{ 8050, "Flame Shock", 188, "meterFire" },
	{ 8042, "Earth Shock", 134, "meterNature" },
	{ 6603, "Melee", 107, "meterPhysical" },
	{ 3599, "Searing Totem", 54, "meterFire" },
}
local PERCENTS = { "46%", "21%", "15%", "12%", "6%" }

local function Spell(id, total, perSecond)
	return {
		spellID = id, totalAmount = total, amountPerSecond = perSecond or total / 60, creatureName = "", overkillAmount = 0,
		isAvoidable = false, isDeadly = false,
		combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 },
	}
end

local function Fight(env, group)
	env._group = group or { raid = false, size = 0 }
	env._units.player = { name = "Korallis", class = "SHAMAN", guid = "Player-7" }
	local spells, total = {}, 0
	for i, spell in ipairs(SPELLS) do
		env._spells[spell[1]] = { name = spell[2], icon = 100 + i }
		spells[i] = Spell(spell[1], spell[3])
		total = total + spell[3]
	end
	env._sources["Player-7"] = { combatSpells = spells, maxAmount = SPELLS[1][3], totalAmount = total }
	env._session = {
		combatSources = {
			{
				name = "Korallis", classFilename = "SHAMAN", totalAmount = total, amountPerSecond = 38.4, sourceGUID = "Player-7",
				sourceDisplayType = 1, isLocalPlayer = true, deathRecapID = 0, deathTimeSeconds = 0,
			},
		},
		maxAmount = total, totalAmount = total, durationSeconds = 60,
	}
end

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Hex(K, name)
	local r, g, b = K.Widgets.Rgba(name)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Color(frame)
	local fill = M.Last(frame, "SetStatusBarColor")
	return fill[1], fill[2], fill[3]
end

-- Alone: the card lists the player's own spells at rest, titled by the meter.
local env, K, ns = M.New({ game = function(e) Fight(e) end })
M.Enable(env, K)
env.RunTimers()
local list = ns.Damage.list
assert(list.block, "the damage card draws full-height bars")
assert(list.count == 5, "the player's five spells show: " .. tostring(list.count))
assert(W.Near(list.holder:GetWidth(), 269) and W.Near(list.holder:GetHeight(), 158), "the card is the picture's 269 by 158")

-- The cap: the meter's name in caps, the rate at its right; the source's name and the fight switch are not shown.
assert(Plain(Text(list.title)) == "DAMAGE  HEALING", "the cap is the damage and healing switch, not the source: " .. tostring(Text(list.title)))
assert(Text(list.title):find(Hex(K, "capsGold") .. "DAMAGE|r", 1, true) and Text(list.title):find(Hex(K, "muted") .. "HEALING|r", 1, true), "the meter shown is lit in caption gold, the other muted")
assert(Text(list.column) == "38.4 dps", "the cap's right end is the player's rate: " .. tostring(Text(list.column)))
assert(select(1, list.column:GetFont()) == K.Tokens.Font("number"), "the rate is set in the bold figure face")
local r, g, b = K.Tokens.Color("textEmphasis")
local tint = M.Last(list.column, "SetTextColor")
assert(tint and tint[1] == r and tint[2] == g and tint[3] == b, "and in white")
assert(not Plain(Text(list.column)):find("Now", 1, true), "the fight switch does not show at rest")
assert(list.cap.gem and list.cap.rule, "the cap carries the kit's gem and rule")
assert(select(1, list.title:GetFont()) == K.Tokens.Font("caps"), "DAMAGE is set in the tracked caps face")
local gr, gg, gb = K.Tokens.Color("capsGold")
local gold = M.Last(list.title, "SetTextColor")
assert(gold and gold[1] == gr and gold[2] == gg and gold[3] == gb, "in the picture's caption gold")
assert(not Text(list.title):find("\226\128\137", 1, true), "with no thin space: the face carries the tracking")

-- The switch is still there: on hover it shows the fights, a click steps to the next, and the setting is kept.
local switch = list.switch
switch._scripts.OnEnter(switch)
assert(Plain(Text(list.column)) == "Now  Last  All", "hovering the cap's right end shows the fights: " .. Plain(Text(list.column)))
switch._scripts.OnLeave(switch)
assert(Text(list.column) == "38.4 dps", "leaving it brings the rate back")
switch._scripts.OnMouseUp(switch, "LeftButton")
env.RunTimers()
assert(ns.Get("damage.session") == "Previous", "a click on the switch still steps the fight setting")
M.Write(env, K, "damage.session", "Current")

-- The rows: bars 18 units tall, 21 apart, 16 in from the card's edge, the first 35.5 under its top (LEE-70 remeasured the picture's first fill at 2986, 1991).
for i, spell in ipairs(SPELLS) do
	local row = list.rows[i]
	local at = { row.frame:GetPoint(1) }
	assert(W.Near(row.frame:GetHeight(), 18), i .. ": the row is 18 units tall, got " .. tostring(row.frame:GetHeight()))
	assert(W.Near(row.bar:GetHeight(), 18), i .. ": the bar is as tall as the row")
	assert(at[1] == "TOPLEFT" and W.Near(at[4], 16), i .. ": the row is 16 units in from the left")
	assert(W.Near(-at[5], 35.5 + (i - 1) * 21, 0.51), i .. ": the row is " .. (35.5 + (i - 1) * 21) .. " units under the card's top, got " .. tostring(-at[5]))
	assert(W.Near(row.frame:GetWidth(), 237), i .. ": the row ends 16 units from the right edge")
	assert(row.icon:IsShown() and M.Last(row.icon, "SetTexture")[1] == 100 + i, i .. ": the spell's icon leads the row")
	assert(row.back:IsShown() and W.Near(row.back:GetWidth(), 18) and W.Near(row.back:GetHeight(), 18), i .. ": in a square as tall as the row")
	assert(W.Near(row.bar:GetWidth(), 237 - 18 - 2), i .. ": the bar starts 2 units after the icon")
	assert(Text(row.name) == spell[2], i .. ": the name is the spell's: " .. tostring(Text(row.name)))
	assert(Text(row.value) == tostring(spell[3]), i .. ": the amount: " .. tostring(Text(row.value)))
	assert(Text(row.percent) == PERCENTS[i], i .. ": the share is the percentage, got " .. tostring(Text(row.percent)))
	assert(row.dot and row.dot:IsShown() and Text(row.dot) == "\194\183", i .. ": the middle dot is its own piece")
	local cr, cg, cb = K.Tokens.Color(spell[4])
	local br, bg, bb = Color(row.bar)
	assert(br == cr and bg == cg and bb == cb, i .. ": the bar is the spell's school colour (" .. spell[4] .. ")")
	local range = M.Last(row.bar, "SetMinMaxValues")
	assert(range[2] == 412 and M.Last(row.bar, "SetValue")[1] == spell[3], i .. ": the fill is the spell's share of the top spell")
end

-- The dot is its own piece. The ink gap is 5/21 of the font, which is 5 px on the picture's screen, snapped
-- to the panel's pixel and never under one pixel. The bearings come from the drawn font file
-- (KstyleUI_Meters/Bearings.lua, written by Tools/media/make_bearings.py), so a trailing 1 sits closer than a
-- trailing 2 by exactly the difference of their right bearings, in Folio, in Lumen and in a picked number face.
local function DotOffsets(label)
	local row = list.rows[1]
	local dot = { row.dot:GetPoint(1) }
	local value = { row.value:GetPoint(1) }
	assert(dot[1] == "RIGHT" and dot[2] == row.percent and dot[3] == "LEFT", label .. ": the dot sits against the share")
	assert(value[1] == "RIGHT" and value[2] == row.dot and value[3] == "LEFT", label .. ": the amount sits against the dot")
	local path, size = row.value:GetFont()
	local face = assert(ns.BarList.Bearings(path), label .. ": the drawn face has bearings from its font file: " .. tostring(path))
	local step = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(list.panel)
	local x2, y = ns.BarList.JoinOffsets("2", "4", size, step, path)
	assert(W.Near(value[4], x2), label .. ": a trailing 2 leaves the picture's proportion after its ink, got " .. tostring(value[4]))
	assert(W.Near(dot[4], y), label .. ": the share's first figure leaves the same proportion after the dot, got " .. tostring(dot[4]))
	local x1 = ns.BarList.JoinOffsets("1", "4", size, step, path)
	assert(W.Near(x1 - x2, (face.rsb["1"] - face.rsb["2"]) * size), label .. ": a trailing 1 moves by the file's bearing difference")
	assert(x1 > x2, label .. ": a trailing 1, whose ink stops short of the advance, is pulled toward the dot")
	return face, path
end
do
	local folio = DotOffsets("Folio")
	assert(folio == ns.BEARINGS["ptserif-bold.ttf"], "Folio's amounts use PT Serif Bold's bearings")
	K.Options.Write("Appearance", "typeSet", "Lumen")
	env.RunTimers()
	local lumen = DotOffsets("Lumen")
	assert(lumen == ns.BEARINGS["alegreyasanstabular-extrabold.ttf"], "Lumen's amounts use Alegreya Sans ExtraBold's bearings")
	local kept = {
		rsb = { ["0"] = 0.025, ["1"] = 0.141, ["2"] = 0.022, ["3"] = 0.044, ["4"] = 0.016, ["5"] = 0.037, ["6"] = 0.024, ["7"] = 0.034, ["8"] = 0.034, ["9"] = 0.023, ["%"] = 0.027 },
		lsb = { ["0"] = 0.025, ["1"] = 0.033, ["2"] = 0.034, ["3"] = 0.029, ["4"] = 0.010, ["5"] = 0.022, ["6"] = 0.023, ["7"] = 0.021, ["8"] = 0.030, ["9"] = 0.024, ["%"] = 0.026 },
	}
	for side, values in pairs(kept) do
		for char, want in pairs(values) do
			assert(lumen[side][char] == want, "Lumen keeps the measured " .. side .. " of " .. char .. ": " .. tostring(lumen[side][char]))
		end
	end
	assert(lumen.lsb["\194\183"] == 0.033 and lumen.rsb["\194\183"] == 0.033, "and the dot's own bearings")
	K.Options.Write("Appearance", "roleFontNumber", K.Tokens.FontPath("SourceSans3Semibold"))
	env.RunTimers()
	local picked, path = DotOffsets("a picked number face")
	assert(path == K.Tokens.FontPath("SourceSans3Semibold") and picked == ns.BEARINGS["sourcesans3-semibold.ttf"], "a number face picked by role uses its own bearings")
	K.Options.Write("Appearance", "roleFontNumber", "")
	K.Options.Write("Appearance", "typeSet", "Folio")
	env.RunTimers()
	assert(ns.BarList.DOT_GAP_EM == 5 / 21, "the gap is 5 px against the 21 px the 12-unit face draws on the reference screen")
	assert(list.rows[1].amount == "412", "the amount is the text SetRow was handed, not a read back from the region")
end

-- A chosen font sizes the dot itself. Pinning every face to the number face's 0.228 em clips a wider
-- middle dot (Inter's is 0.319 em) and the render guard reports it truncated.
do
	M.Write(env, K, "damage.font", K.Tokens.FontPath("InterSemiBold"))
	local row = list.rows[1]
	assert(select(1, row.dot:GetFont()) == K.Tokens.FontPath("InterSemiBold"), "the chosen font reaches the dot")
	assert(row.dot:GetWidth() == 0, "the dot is not pinned to the number face's advance, got " .. tostring(row.dot:GetWidth()))
	assert(row.dot:IsShown(), "the dot still shows")
	M.Write(env, K, "damage.font", "")
	assert(select(1, list.rows[1].value:GetFont()) == K.Tokens.Font("number"), "clearing the font returns the amount to the number face")
end

-- GetFont may hand a bundled face's path back in another spelling: the same file's bearings apply. A face
-- KstyleUI does not ship has no bearings, so the defaults place the dot, and nothing raises.
do
	local row = list.rows[1]
	local real = row.value.GetFont
	local path, size = real(row.value)
	local step = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(list.panel)
	local kept = row.amount
	row.amount = "411"
	local spelled = path:gsub("\\", "/"):upper()
	row.value.GetFont = function()
		return spelled, size, ""
	end
	list:Restyle()
	assert(ns.BarList.Bearings(spelled) == ns.BarList.Bearings(path), "another spelling finds the same face")
	assert(W.Near(select(4, row.value:GetPoint(1)), (ns.BarList.JoinOffsets("1", "4", size, step, path))), "a differently spelled path keeps its face's bearings, got " .. tostring(select(4, row.value:GetPoint(1))))
	row.value.GetFont = function()
		return "Interface\\AddOns\\SharedMedia\\fonts\\Other.ttf", size, ""
	end
	list:Restyle()
	assert(ns.BarList.Bearings("Interface\\AddOns\\SharedMedia\\fonts\\Other.ttf") == nil, "a face KstyleUI does not ship has no bearings")
	local fallen = ns.BarList.JoinOffsets(nil, nil, size, step, "Interface\\AddOns\\SharedMedia\\fonts\\Other.ttf")
	assert(not W.Near(fallen, (ns.BarList.JoinOffsets("1", "4", size, step, path))), "the default bearing is not a trailing 1's")
	assert(W.Near(select(4, row.value:GetPoint(1)), fallen), "an unknown face uses the default bearing, got " .. tostring(select(4, row.value:GetPoint(1))))
	assert(#env._errors == 0, "neither path raises: " .. tostring(env._errors[1]))
	row.amount = kept
	row.value.GetFont = real
	list:Restyle()
end

-- The text sits inside the fill: the name at the left, the amount and share at the right, the value bold.
do
	local row = list.rows[1]
	local name = { row.name:GetPoint(1) }
	assert(name[1] == "LEFT" and name[2] == row.bar and name[4] > 0 and name[4] < 12, "the name starts just inside the bar's left edge")
	local share = { row.percent:GetPoint(1) }
	assert(share[1] == "RIGHT" and share[4] < 0 and share[4] > -12, "the share ends just inside the bar's right edge")
	assert(M.Last(row.value, "SetFont")[1] == K.Tokens.Font("number"), "the amount is bold")
	assert(M.Last(row.percent, "SetFont")[1] == K.Tokens.Font("number"), "and so is the share")
	assert(M.Last(row.dot, "SetFont")[1] == K.Tokens.Font("number"), "and so is the dot")
	assert(M.Last(row.name, "SetFont")[1] == K.Tokens.Font("body"), "the name is the body face")
	assert(row.name:GetParent() ~= row.frame and row.name:GetParent():GetFrameLevel() > row.bar:GetFrameLevel(), "the text is drawn above the bar")
	local nr, ng, nb = K.Tokens.Color("textEmphasis")
	local tnt = M.Last(row.name, "SetTextColor")
	assert(tnt[1] == nr and tnt[2] == ng and tnt[3] == nb, "the name is white")
	local track = K.Tokens.Color("buttonFill")
	assert(row.bar.background ~= nil and track ~= nil, "the rest of the row is a dark track")
end

-- No class-blue line, no pill: the bar is the whole row and nothing else rides under it.
assert(list.rows[1].edge == nil and list.rows[1].glow == nil, "no thin line under a row")
assert(M.Calls(list.rows[1].bar.keyline, "Hide") > 0 and list.rows[1].bar.lit:IsShown(), "no outside keyline; the fill keeps the mock-up's lit top edge (KSTY-60 item 4)")

-- Clicking a row does nothing: the spell list is the rest state, and there is nothing behind it to go back to.
local before = env._lastSource
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton")
env.RunTimers()
assert(env._lastSource == before or env._lastSource[4] == "Player-7", "a click on a spell row opens nothing new")
assert(Plain(Text(list.title)) == "DAMAGE  HEALING" and list.count == 5, "and the card stays on the spell list")
assert(list.rows[1].more == nil or not list.rows[1].more:IsShown(), "no chevron on a spell row")

-- The meter's name follows the meter type; the rate's unit follows it too.
M.Write(env, K, "damage.meter", "Dps")
assert(Plain(Text(list.title)) == "DAMAGE  HEALING" and Text(list.title):find(Hex(K, "capsGold") .. "DAMAGE|r", 1, true), "damage per second is still the damage card")
M.Write(env, K, "damage.meter", "HealingDone")
assert(Text(list.title):find(Hex(K, "capsGold") .. "HEALING|r", 1, true) and Text(list.title):find(Hex(K, "muted") .. "DAMAGE|r", 1, true), "healing lights its own word: " .. tostring(Text(list.title)))
M.Write(env, K, "damage.meter", "Interrupts")
assert(Text(list.title) == "INTERRUPTS", "a meter outside the two names itself: " .. tostring(Text(list.title)))
M.Write(env, K, "damage.meter", "DamageDone")

-- The percent switch drops the share and the dot together.
M.Write(env, K, "damage.percent", false)
assert(Text(list.rows[1].percent) == "" and not list.rows[1].percent:IsShown() and not list.rows[1].dot:IsShown(), "no share, no dot")
M.Write(env, K, "damage.percent", true)

-- The old default stays a setting: the colour source "class" brings the class colour back on spells.
M.Write(env, K, "damage.colorSource", "class")
local cr, cg, cb = K.Theme.ClassColor("SHAMAN")
local br, bg, bb = Color(list.rows[1].bar)
cr, cg, cb = cr * ns.DAMAGE_CLASS_TONE, cg * ns.DAMAGE_CLASS_TONE, cb * ns.DAMAGE_CLASS_TONE
assert(br == cr and bg == cg and bb == cb, "the class colour source colours a spell by class")
M.Write(env, K, "damage.colorSource", "school")
assert(ns.defaults.damage.colorSource == "school" and ns.defaults.damage.spacing == 3 and ns.defaults.damage.rowHeight == 18, "the picture's look is the default")

-- In a group the card lists the sources, titled by the meter, with the player's rate in the cap; a click opens one
-- source's spells, titled by the source.
do
	local envG, KG, nsG = M.New({ game = function(e) Fight(e, { raid = false, size = 2 }) end })
	M.Enable(envG, KG)
	envG.RunTimers()
	local group = nsG.Damage.list
	assert(Plain(Text(group.title)) == "DAMAGE  HEALING" and group.count == 1, "in a group the card lists the sources under the meter's name")
	assert(Text(group.column) == "38.4 dps", "the cap shows the local player's rate: " .. tostring(Text(group.column)))
	local ar, ag, ab = KG.Theme.ClassColor("SHAMAN")
	local sr, sg, sb = Color(group.rows[1].bar)
	ar, ag, ab = ar * nsG.DAMAGE_CLASS_TONE, ag * nsG.DAMAGE_CLASS_TONE, ab * nsG.DAMAGE_CLASS_TONE
	assert(sr == ar and sg == ag and sb == ab, "a source's bar is its class colour")
	group.rows[1].frame._scripts.OnMouseUp(group.rows[1].frame, "LeftButton")
	envG.RunTimers()
	assert(Plain(Text(group.title)) == "Korallis" or tostring(Text(group.title)):upper() == "KORALLIS", "an opened source titles the card: " .. tostring(Text(group.title)))
	assert(group.count == 5 and group.rows[1].icon:IsShown(), "its spells list as bars led by their icons")
	assert(Text(group.column) == "38.4 dps", "and the cap keeps the source's rate")
	assert(#envG._errors == 0, "no Lua error: " .. tostring(envG._errors[1]))
end

-- In combat on a client that hides the data the rows stay and nothing is compared: a secret rate and secret
-- amounts reach only widget setters.
do
	local envS, KS, nsS = M.New({ game = function(e) Fight(e) end })
	M.Enable(envS, KS)
	envS.RunTimers()
	local card = nsS.Damage.list
	local S = envS.Secret
	local Cap = getmetatable(card.cap)
	local setAside = Cap.SetAside
	function Cap.SetAside(self, text)
		assert(not envS.issecretvalue(text), "a secret reached the cap's aside, which compares its text")
		return setAside(self, text)
	end
	envS.SetCombat(true)
	local secretSpells = { Spell(403, S(412), S(7)), Spell(8050, S(188), S(3)) }
	envS._sources["Player-7"] = { combatSpells = secretSpells, maxAmount = S(412), totalAmount = S(895) }
	envS._session.combatSources[1].amountPerSecond = S(38.4)
	envS.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 8)
	envS.RunTimers()
	assert(#envS._errors == 0, "secret values raise no error: " .. tostring(envS._errors[1]))
	assert(envS.issecretvalue(Text(card.column)), "a secret rate reaches the cap through AbbreviateNumbers whole")
	assert(envS.Reveal(Text(card.column)) == "38 dps", "and keeps its unit, joined to the secret as the game allows: " .. tostring(envS.Reveal(Text(card.column))))
	assert(card.column:IsShown() and card.hasRest, "the aside shows and the list tracks it itself")
	envS.SetCombat(false)
	envS._session.combatSources[1].amountPerSecond = 38.4
	envS.FireEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", M.METER.DamageDone, 8)
	envS.RunTimers()
	assert(Text(card.column) == "38.4 dps" and card.hasRest, "the plain rate takes the aside back after combat")
	Cap.SetAside = setAside
	assert(envS.issecretvalue(Text(card.rows[1].value)), "a secret amount is abbreviated by the game")
	assert(Text(card.rows[1].percent) == "" and not card.rows[1].percent:IsShown(), "no share is worked out from secret values")
	local nr, ng, nb = KS.Tokens.Color("meterNature")
	local fr, fg, fb = Color(card.rows[1].bar)
	assert(fr == nr and fg == ng and fb == nb, "a secret amount still gets its school colour: the school comes from the spell ID")
end

-- A fight that has no data clears the rate: Previous with no earlier fight shows no rate beside its note.
do
	local envP, KP, nsP = M.New({ game = function(e) Fight(e) end })
	M.Enable(envP, KP)
	envP.RunTimers()
	local card = nsP.Damage.list
	assert(Text(card.column) == "38.4 dps", "Now shows the rate")
	M.Write(envP, KP, "damage.session", "Previous")
	envP.RunTimers()
	assert(card.count == 0 and Text(card.note) == "No earlier fight yet", "Previous has no rows and says so")
	assert(Text(card.column) == "" and not card.hasRest, "and no rate stays beside it: " .. tostring(Text(card.column)))
	M.Write(envP, KP, "damage.session", "Current")
	envP.RunTimers()
	assert(Text(card.column) == "38.4 dps", "back on Now the rate returns")
	assert(#envP._errors == 0, "no Lua error: " .. tostring(envP._errors[1]))
end

-- The school table: the client gives no school for a spell ID, so KstyleUI_Meters carries the table
-- Tools/build/gen_spell_schools.py writes from Tools/data/abilities.json.
do
	local L = ns.Logic
	assert(L.SchoolToken(403) == "meterNature" and L.SchoolToken(8042) == "meterNature", "nature spells")
	assert(L.SchoolToken(8050) == "meterFire" and L.SchoolToken(3599) == "meterFire", "fire spells")
	assert(L.SchoolToken(116) == "meterFrost", "frost: Frostbolt")
	assert(L.SchoolToken(686) == "meterShadow", "shadow: Shadow Bolt")
	assert(L.SchoolToken(3044) == "meterArcane", "arcane: Arcane Shot")
	assert(L.SchoolToken(585) == "meterHoly", "holy: Smite")
	assert(L.SchoolToken(6603) == "meterPhysical" and L.SchoolToken(5215) == "meterPhysical", "melee and physical spells")
	assert(L.SchoolToken(99999999) == "meterPhysical" and L.SchoolToken(nil) == "meterPhysical", "an unknown spell falls back to physical")
	assert(L.SchoolToken(env.Secret(403)) == "meterPhysical", "a secret spell ID is never looked up")
	assert(L.FormatRate(38.4, "dps") == "38.4 dps" and L.FormatRate(0, "dps") == "0.0 dps", "a rate shows one decimal and its unit")
	assert(L.FormatRate(1234.5, "dps") == "1.2K dps", "a large rate is abbreviated: one decimal to 10K")
	assert(L.FormatRate(nil, "dps") == "" and L.FormatRate("x", "dps") == "", "no rate, no text")
end

assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- On each screen, in Folio, in Lumen and in a picked number face, the share holds the row's right edge and
-- the ink gap each side of the dot, in physical pixels, is within one pixel of 5/21 of the font, and it is
-- still 5 on the picture's 3456 by 2234 screen. A fixed 5 px on every screen fails this.
local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
for _, screen in ipairs(screens) do
	local envS, KS, nsS = M.New({ width = screen[1], height = screen[2], game = function(e) Fight(e) end })
	M.Enable(envS, KS)
	envS.RunTimers()
	local label = screen[1] .. "x" .. screen[2]
	if screen[1] == 3456 and screen[2] == 2234 then
		assert(KS.Scale.SetUserScale(16 / 19), label .. ": the picture's screen uses the shipped interface size")
		envS.RunTimers()
	end
	local states = {
		{ "Folio", function() end },
		{ "Lumen", function() KS.Options.Write("Appearance", "typeSet", "Lumen") end },
		{ "a picked number face", function() KS.Options.Write("Appearance", "roleFontNumber", KS.Tokens.FontPath("SourceSans3Semibold")) end },
	}
	for _, state in ipairs(states) do
		state[2]()
		envS.RunTimers()
		local at = label .. ", " .. state[1]
		local row = nsS.Damage.list.rows[1]
		local path, size = row.value:GetFont()
		local face = assert(nsS.BarList.Bearings(path), at .. ": the amount's face has bearings from its font file")
		local step = KS.Scale.Pixel(1) / KS.Widgets.ScaleFactor(row.frame)
		local valueX = select(4, row.value:GetPoint(1))
		local dotX = select(4, row.dot:GetPoint(1))
		local right = { row.percent:GetPoint(1) }
		local inset = KS.Widgets.Snap(nsS.Damage.list.panel, 7)
		assert(right[1] == "RIGHT" and right[2] == row.frame and right[3] == "RIGHT" and W.Near(right[4], -inset), at .. ": the share holds the row's right edge")
		local dotInk = face.lsb["\194\183"]
		local gaps = {
			face.rsb["2"] * size + dotInk * size - valueX,
			face.lsb["4"] * size + face.rsb["\194\183"] * size - dotX,
		}
		local wanted = nsS.BarList.DOT_GAP_EM * size / step
		assert(row.dot:IsShown(), at .. ": the dot shows")
		for side, gap in ipairs(gaps) do
			local gapPx = gap / step
			local which = at .. (side == 1 and ", amount side" or ", share side")
			assert(math.abs(gapPx - math.floor(gapPx + 0.5)) < 1e-3, which .. ": the gap is whole pixels, got " .. tostring(gapPx))
			assert(math.abs(gapPx - wanted) <= 1 + 1e-6, which .. ": the gap is the picture's proportion, got " .. tostring(gapPx) .. " for " .. tostring(wanted))
			assert(gapPx + 1e-6 >= 1, which .. ": the gap is at least one pixel")
			if screen[1] == 3456 and screen[2] == 2234 then
				assert(math.abs(gapPx - 5) < 0.05, which .. ": the picture's screen still has 5 px, got " .. tostring(gapPx))
			end
		end
	end
	assert(#envS._errors == 0, label .. ": " .. tostring(envS._errors[1]))
end

print("meters card ok")
