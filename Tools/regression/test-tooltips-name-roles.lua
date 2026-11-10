-- test-tooltips-name-roles.lua: Folio names on unit, spell and aura titles, Lumen's original titles, inherited font sentinels and pooled-title restoration.
local T = dofile("Tools/regression/tooltips_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(actual, expected, message)
	assert(actual == expected, message .. ": got " .. tostring(actual) .. ", wanted " .. tostring(expected))
end

local env, K = T.New()
assert(K.Modules.Enable("Tooltips"))
local tip = env.GameTooltip
local types = env.Enum.TooltipDataType

local function show(kind, text)
	tip:ClearLines()
	tip:AddLine(text, 0.2, 0.7, 0.4)
	tip:AddLine("Details stay mixed case", 1, 1, 1)
	T.BlizzardShow(tip, true)
	T.PostCall(env, tip, { type = kind, id = env.Secret(123) })
	return tip:GetLeftLine(1)
end

local function path(object)
	return (object:GetFont())
end

eq(path(env.GameTooltipHeaderText), (K.Tokens.Font("body")), "Folio's general tooltip header is body text")
for _, kind in ipairs({ types.Unit, types.Spell, types.UnitAura }) do
	local title = show(kind, "Valerin Longname")
	eq(path(title), (K.Tokens.Font("names")), "unit, spell and aura names use the names role even with unreadable IDs")
	eq(title:GetText(), "Valerin Longname", "name data retains its original bytes and case")
	eq((Scene.Font(env, tip:GetLeftLine(2))), (K.Tokens.Font("body")), "descriptions remain body text")
	local _, size, flags = title:GetFont()
	assert(T.Near(size, K.Widgets.FontSize(tip, 11)), "the title keeps the existing configured size")
	eq(flags, "", "the existing outline setting is preserved")
end

local title = show(types.Spell, "Mortal Strike")
title:SetWidth(82)
tip:SetSize(190, 120)
tip:ClearAllPoints()
tip:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 42, -48)
local anchor = { tip:GetPoint(1) }
local long = string.rep("Long Spell Name ", 12)
title:SetText(long)
T.PostCall(env, tip, { type = types.Spell, id = env.Secret(123) })
eq(title:GetText(), long, "a long name stays whole in data for native truncation")
eq(title:GetWidth(), 82, "the reserved native name width does not grow")
eq(tip:GetWidth(), 190, "the tooltip width allocation does not grow")
eq(tip:GetHeight(), 120, "the tooltip height is not manually changed")
for i, value in ipairs(anchor) do
	eq(select(i, tip:GetPoint(1)), value, "the tooltip anchor does not move")
end

assert(K.Theme.SetTypeSet("Lumen"))
eq(path(title), (K.Tokens.Font("heading")), "a visible name returns to Lumen's original heading treatment")
eq(path(env.GameTooltipHeaderText), (K.Tokens.Font("heading")), "Lumen's general header stays unchanged")
local r, g, b = title:GetTextColor()
assert(T.Near(r, 0.2) and T.Near(g, 0.7) and T.Near(b, 0.4), "restoring the inherited header keeps the name colour")
assert(K.Theme.SetTypeSet("Folio"))
eq(path(title), (K.Tokens.Font("names")), "a visible name follows a type-set change without another post-call")
assert(K.Theme.SetFontFace("InterSemiBold"))
eq(path(title), K.Tokens.FontPath("InterSemiBold"), "an explicit whole-interface font wins")
assert(K.Theme.SetFontFace(""))
eq(path(title), (K.Tokens.Font("names")), "clearing the global override restores the semantic face")

local custom = K.Tokens.FontPath("SourceSans3Regular")
K.Options.Write("Tooltips", "title.font", custom)
eq(path(title), (K.Tokens.Font("names")), "the saved per-line choice stays behind the existing follow toggle")
K.Options.Write("Tooltips", "followFont", false)
eq(path(title), custom, "the saved per-line title font wins when selected")
K.Options.Write("Tooltips", "title.outline", "THICKOUTLINE")
eq(select(3, title:GetFont()), "THICKOUTLINE", "the custom outline also wins")
assert(K.Theme.SetTypeSet("Lumen"))
eq(path(title), custom, "a type-set change cannot replace a saved title font")
assert(K.Theme.SetFontFace("InterSemiBold"))
eq(path(title), custom, "a global override cannot replace a selected per-line font")
K.Options.Write("Tooltips", "followFont", true)
eq(path(title), K.Tokens.FontPath("InterSemiBold"), "re-enabling inheritance selects the global override")
assert(K.Theme.SetFontFace(""))
assert(K.Theme.SetTypeSet("Folio"))
K.Options.Write("Tooltips", "title.outline", "NONE")

T.PostCall(env, tip, { type = types.Item, id = env.Secret(123) })
eq(path(title), (K.Tokens.Font("body")), "item reuse clears the previous name face without needing ClearLines")
for _, kind in ipairs({ types.Object, types.Currency, -1 }) do
	T.PostCall(env, tip, { type = types.Spell })
	eq(path(title), (K.Tokens.Font("names")), "the spell face is reapplied before reuse")
	T.PostCall(env, tip, { type = kind })
	eq(path(title), (K.Tokens.Font("body")), "object and unhandled types cannot retain a previous name face")
end
title = show(types.Item, "Ranger's Long Bow")
eq(path(title), (K.Tokens.Font("body")), "item names retain the body face and mixed case")
eq(title:GetText(), "Ranger's Long Bow", "item text is not capitalized")
title = show(types.Spell, "Mortal Strike")
local secret = env.Secret("Hidden Name")
title:SetText(secret)
T.PostCall(env, tip, { type = types.UnitAura, id = env.Secret(123) })
eq(title._state.Text[1], secret, "a secret name is never compared or rewritten")
tip:ClearLines()
eq(path(title), (K.Tokens.Font("body")), "clearing a tooltip removes the per-instance name face")
title = show(types.Spell, "Mortal Strike")
T.BlizzardShow(tip, false)
eq(path(title), (K.Tokens.Font("body")), "hiding a tooltip also removes the per-instance face")
title = show(types.Spell, "Mortal Strike")
K.Modules.Disable("Tooltips")
eq(path(title), "Fonts\\FRIZQT__.TTF", "Disable restores the native inherited font, not a stale names instance")
local x, y = title:GetShadowOffset()
eq(x, 1, "Disable restores the native shadow X")
eq(y, -1, "Disable restores the native shadow Y")
assert(K.Modules.Enable("Tooltips"))

local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(260, 430)
local preview = K.Options.Preview("Tooltips")(parent)
eq(path(preview.item.rows[1].left), (K.Tokens.Font("body")), "the item preview uses body")
eq(path(preview.unit.rows[1].left), (K.Tokens.Font("names")), "the unit preview agrees with native name titles")
assert(K.Theme.SetTypeSet("Lumen"))
preview:Refresh()
eq(path(preview.item.rows[1].left), (K.Tokens.Font("heading")), "the Lumen item preview keeps its original face")
eq(path(preview.unit.rows[1].left), (K.Tokens.Font("heading")), "the Lumen unit preview keeps its original face")
assert(#env._errors == 0, tostring(env._errors[1]))

do
	local game, kit, addon = T.New()
	assert(kit.Modules.Enable("Tooltips"))
	kit.Options.Write("Tooltips", "followFont", false)
	for _, role in ipairs({ "title", "body", "small" }) do
		eq(addon.Settings.Get(role .. ".font"), "theme", "an unchosen per-line default is a sentinel, not a captured path")
	end
	for _, row in ipairs(kit.Options.Get("Tooltips")) do
		if row.type == "font" then
			local first = row.options()[1]
			eq(first.value, "theme", "each per-line picker can reselect inheritance")
			eq(first.label, kit.L["KstyleUI font"], "the inherited choice has its existing readable label")
		end
	end
	local native = game.GameTooltip
	for _, value in ipairs({ "", "theme", "kit" }) do
		kit.Options.Write("Tooltips", "title.font", value)
		kit.Options.Write("Tooltips", "body.font", value)
		kit.Options.Write("Tooltips", "small.font", value)
		for _, set in ipairs({ "Folio", "Lumen" }) do
			assert(kit.Theme.SetTypeSet(set))
			native:ClearLines()
			native:AddLine("Unchosen Name")
			T.BlizzardShow(native, true)
			T.PostCall(game, native, { type = game.Enum.TooltipDataType.Spell })
			eq(path(native:GetLeftLine(1)), (kit.Tokens.Font(set == "Lumen" and "heading" or "names")), "every supported sentinel follows the current set with the toggle off")
			eq(path(game.GameTooltipText), (kit.Tokens.Font("body")), "unchosen body lines follow the current set too")
			eq(path(game.GameTooltipTextSmall), (kit.Tokens.Font("caption")), "unchosen small lines follow the current set too")
		end
	end
	kit.Options.Write("Tooltips", "title.font", custom)
	local reloaded, reloadKit = T.New({ saved = game.KstyleUIDB })
	assert(reloadKit.Modules.Enable("Tooltips"))
	eq(path(reloaded.GameTooltipHeaderText), custom, "a saved explicit per-line choice survives a reload")
	assert(#reloaded._errors == 0, tostring(reloaded._errors[1]))
	assert(#game._errors == 0, tostring(game._errors[1]))
end

do
	local game, kit = T.New()
	assert(kit.Modules.Enable("Tooltips"))
	local native = game.GameTooltip
	local function post(kind)
		native:ClearLines()
		native:AddLine("Reused Title")
		T.BlizzardShow(native, true)
		T.PostCall(game, native, { type = kind })
		return native:GetLeftLine(1)
	end
	post(game.Enum.TooltipDataType.Spell)
	local line = post(game.Enum.TooltipDataType.Item)
	kit.Layout.Set("tooltips.anchor", "scale", 1.5)
	local hx, hy = game.GameTooltipHeaderText:GetShadowOffset()
	local lx, ly = line:GetShadowOffset()
	assert(T.Near(lx, hx) and T.Near(ly, hy), "a reset title keeps following the header shadow after a scale change")
	kit.Modules.Disable("Tooltips")
	eq(path(line), "Fonts\\FRIZQT__.TTF", "Disable after a plain reset restores the native font")
	lx, ly = line:GetShadowOffset()
	eq(lx, 1, "Disable after a plain reset restores the native shadow X")
	eq(ly, -1, "Disable after a plain reset restores the native shadow Y")
	assert(#game._errors == 0, tostring(game._errors[1]))
end

-- The title roles live in the type set's data: no tooltip file names a type set.
for _, file in ipairs(T.Files()) do
	if file:match("^KstyleUI_Tooltips/.*%.lua$") then
		local handle = assert(io.open(file, "rb"))
		local source = handle:read("*a")
		handle:close()
		for set in pairs({ Folio = true, Lumen = true }) do
			assert(not source:find('"' .. set .. '"', 1, true), file .. " tests the " .. set .. " type set by name")
		end
	end
end

print("tooltip semantic names and Lumen compatibility ok")
