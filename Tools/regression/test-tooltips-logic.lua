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

print("tooltips logic ok")
