-- test-tooltips-logic.lua: KstyleUI_Tooltips' pure rules: the fixed anchor's corner, font flags, quality edges, softened line colours and the tooltip scale.
local T = dofile("Tools/regression/tooltips_env.lua")

local env, _, ns = T.New()
local Logic = ns.Logic
assert(type(Logic) == "table", "KstyleUI_Tooltips has no Logic table")

-- Corner: tooltips grow away from the screen edge nearest the anchor element ------------------------

do
	local W, H = 1920, 1080
	assert(Logic.Corner(1700, 450, 180, 24, W, H) == "BOTTOMRIGHT", "low right grows up and left")
	assert(Logic.Corner(20, 450, 180, 24, W, H) == "BOTTOMLEFT", "low left grows up and right")
	assert(Logic.Corner(1700, 900, 180, 24, W, H) == "TOPRIGHT", "high right grows down and left")
	assert(Logic.Corner(20, 900, 180, 24, W, H) == "TOPLEFT", "high left grows down and right")
	assert(Logic.Corner(870, 528, 180, 24, W, H) == "BOTTOMRIGHT", "the exact centre picks Blizzard's bottom right")
	assert(Logic.Corner(nil, 450, 180, 24, W, H) == "BOTTOMRIGHT", "a missing rect falls back to bottom right")
	assert(Logic.Corner(10, 10, 10, 10, 0, 0) == "BOTTOMRIGHT", "an empty root falls back to bottom right")
end

-- Flags: the outline dropdown's values become SetFont flags -------------------------------------

do
	assert(Logic.Flags("NONE") == "", "NONE draws no outline")
	assert(Logic.Flags("OUTLINE") == "OUTLINE")
	assert(Logic.Flags("THICKOUTLINE") == "THICKOUTLINE")
	assert(Logic.Flags("MONOCHROME") == "" and Logic.Flags(nil) == "", "anything else draws no outline")
end

-- EdgeQuality: only uncommon and better items colour the tooltip's edge ----------------------------

do
	assert(Logic.EdgeQuality(0) == false and Logic.EdgeQuality(1) == false, "poor and common items keep the glass edge")
	assert(Logic.EdgeQuality(2) and Logic.EdgeQuality(3) and Logic.EdgeQuality(4) and Logic.EdgeQuality(5), "uncommon and better colour it")
	assert(Logic.EdgeQuality(nil) == false and Logic.EdgeQuality("3") == false, "an uncached or odd quality keeps the glass edge")
	assert(Logic.EdgeQuality(env.Secret(4)) == false, "a secret quality is never compared")
end

-- Soften: Blizzard's gold and white line colours map to KstyleUI's grey text tokens ----------------

do
	local palette = { { 1, 0.82, 0, "text" }, { 1, 1, 1, "textEmphasis" } }
	assert(Logic.Soften(1, 0.82, 0, palette) == "text", "NORMAL_FONT_COLOR becomes body grey")
	assert(Logic.Soften(1, 0.8196, 0.0039, palette) == "text", "a near match counts")
	assert(Logic.Soften(1, 1, 1, palette) == "textEmphasis", "HIGHLIGHT_FONT_COLOR becomes emphasis white")
	assert(Logic.Soften(0.1, 1, 0.1, palette) == nil, "green bonus lines keep their colour")
	assert(Logic.Soften(1, 0.125, 0.125, palette) == nil, "red requirement lines keep their colour")
	assert(Logic.Soften(0.5, 0.5, 0.5, palette) == nil, "grey lines keep their colour")
	assert(Logic.Soften(nil, nil, nil, palette) == nil, "no colour stays as it is")
	assert(Logic.Soften(env.Secret(1), 1, 1, palette) == nil, "a secret colour is never compared")
	assert(Logic.Soften(1, 1, 1, {}) == nil and Logic.Soften(1, 1, 1, nil) == nil, "an empty palette softens nothing")
end

-- TooltipScale: one tooltip unit is one KstyleUI root unit, times the anchor element's scale ---------

do
	assert(T.Near(Logic.TooltipScale(0.711, 1, 1), 0.711), "root units at UI scale 1")
	assert(T.Near(Logic.TooltipScale(0.711, 0.64, 1.25), 0.711 / 0.64 * 1.25), "the element's scale multiplies")
	assert(Logic.TooltipScale(nil, 1, 1.5) == 1.5, "a missing root scale keeps the element's scale")
	assert(Logic.TooltipScale(0.7, 0, 1) == 1, "a zero parent scale falls back")
	assert(Logic.TooltipScale(0.7, 1, nil) == 0.7, "a missing element scale counts as 1")
end

-- GuildText: the guild in angle brackets, with the rank after it when given ----------------------

do
	assert(Logic.GuildText("Kstyle") == "<Kstyle>", "the guild in brackets")
	assert(Logic.GuildText("Kstyle", "Officer") == "<Kstyle> Officer", "the rank after it")
	assert(Logic.GuildText("Kstyle", "") == "<Kstyle>", "an empty rank adds nothing")
end

-- ID lines read as text -----------------------------------------------------------------------------

do
	assert(Logic.IDText(19019) == "19019" and Logic.IDText(135349) == "135349", "IDs print as whole numbers")
	assert(Logic.IDText("Interface\\Icons\\Spell_Fire") == nil, "a texture path is not an ID")
	assert(Logic.IDText(env.Secret(5)) == nil and Logic.IDText(nil) == nil and Logic.IDText(1.5) == nil, "secrets, nothing and fractions give no line")
end

-- TitleText: titles keep their case (the heading face sets its own capitals) and lose the thin spaces an earlier
-- tracked title carried; an item's title keeps a blank second line for its caption
do
	local THIN = "\226\128\137"
	local function Tracked(text)
		return (text:gsub("([\1-\127\194-\244][\128-\191]*)", "%1" .. THIN):sub(1, -#THIN - 1))
	end
	assert(Logic.TitleText("Ranger's Long Bow") == "Ranger's Long Bow", "titles keep their case")
	assert(Logic.TitleText("Ranger's Long Bow", true) == "Ranger's Long Bow\n ", "an item title reserves the caption's line")
	assert(Logic.TitleText("Ranger's Long Bow\n ", true) == "Ranger's Long Bow\n ", "a second pass adds no second line")
	assert(Logic.TitleText(Tracked("Ranger's Long Bow") .. "\n ", true) == "Ranger's Long Bow\n ", "a title an earlier pass tracked loses its thin spaces")
	assert(Logic.TitleText("Bow |cff00ff00x|r") == nil and Logic.TitleText("|A:Tier3:16:16|a Ore") == nil, "escape codes stay as Blizzard set them")
	assert(Logic.TitleText(env.Secret("Bow")) == nil and Logic.TitleText(nil) == nil and Logic.TitleText("") == nil, "secrets and empty titles are left alone")
	assert(Logic.TitleText("Gro\195\159er B\195\164r", true) == "Gro\195\159er B\195\164r\n ", "a name with accents keeps its bytes")
	assert(Logic.Caption(60, "Rare") == "Item level 60 \194\183 Rare", "an item's caption reads its level and rarity")
	assert(Logic.Caption(nil, "Common") == "Common" and Logic.Caption(env.Secret(60), "Rare") == "Rare", "without a readable level the rarity stands alone")
	assert(Logic.Caption(60, nil) == nil, "no rarity, no caption")
	assert(Logic.IsLevelLine("Item Level 42") and not Logic.IsLevelLine("Requires Level 38") and not Logic.IsLevelLine(env.Secret("Item Level 42")), "Blizzard's Item Level line is told from the others, and a secret is never read")
end

-- A secrecy check comes before any nil test of the same value ------------------------------------
-- The game raises an error when a secret is compared, even with nil, and the stub secrets cannot catch
-- a comparison with a plain value, so the module's source is checked instead.

local function NilBeforeSecret(line)
	for var, at in line:gmatch("([%w_%.]+)%s*[=~]=%s*nil()") do
		local escaped = var:gsub("%p", "%%%0")
		if line:find("IsSecret%(%s*" .. escaped .. "%s*%)", at) or line:find("issecretvalue%(%s*" .. escaped .. "%s*%)", at) then
			return var
		end
	end
end

do
	assert(NilBeforeSecret("if info == nil or Logic.IsSecret(info) then") == "info", "the check finds a nil test first")
	assert(NilBeforeSecret("return v ~= nil and not Logic.IsSecret(v)") == "v")
	assert(NilBeforeSecret("if Logic.IsSecret(info) or info == nil then") == nil, "secrecy first passes")
	assert(NilBeforeSecret("if a == nil or Logic.IsSecret(b) then") == nil, "other values pass")
	for _, path in ipairs(T.Files()) do
		local n = 0
		for line in io.lines(path) do
			n = n + 1
			local var = NilBeforeSecret(line)
			assert(not var, path .. ":" .. n .. ": test issecretvalue(" .. tostring(var) .. ") before comparing it with nil")
		end
	end
end

-- Sections: the stat run and the footer of an item's lines -------------------------------------------

do
	assert(Logic.IsStat("+24 Agility") and Logic.IsStat("+18 Critical Strike"), "a line that starts with a plus and a number is a stat")
	assert(not Logic.IsStat("Equip: +5 ranged attack power") and not Logic.IsStat("Two-Handed Bow"), "bonus and base lines are not")
	assert(not Logic.IsStat(env.Secret("+5 Agility")) and not Logic.IsStat(nil), "secrets and nothing are not")
	local stats, footer = Logic.Sections({ "Ranger's Long Bow", "Level 38", "Two-Handed Bow", "+24 Agility", "+18 Critical Strike", "Durability 96 / 100", "Requires Level 38" })
	assert(stats == 4, "the first stat line")
	assert(footer == 6, "the first durability or requirement line")
	assert(Logic.Sections({ "Linen Cloth", "Crafting Reagent" }) == nil, "no stats, no footer")
	local none, requires = Logic.Sections({ "Hat", "Requires Level 10" })
	assert(none == nil and requires == 2, "a requirement alone starts the footer")
	assert(select(2, Logic.Sections({ "Bow", "+1 Agility", env.Secret("Durability 1 / 2") })) == nil, "a secret line is skipped")
	assert(Logic.Sections({ "+5 Agility", "+5 Stamina" }) == 2, "the title is never a stat")
end

print("tooltips logic ok")
