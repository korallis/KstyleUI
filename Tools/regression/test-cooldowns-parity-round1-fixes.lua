-- test-cooldowns-parity-round1-fixes.lua: the review of parity round 1, each probe kept as a check: a vertical essential grid reserves its rotated footprint, a spell override rematches its rules, Grey these repaints a cooling icon, Blizzard's texts, counts and shading return exactly, the preview shows rules, zero charges and overflow, events write nothing unchanged, and localised names match case-insensitively within the letter limit.
local C = dofile("Tools/regression/cooldowns_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local G = dofile("Tools/regression/geometry.lua")
local W = C.W

local failed = 0
local function case(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function Game(e)
	C.Game(e)
	e.C_StringUtil.TruncateWhenZero = function(count) return count == 0 and "" or tostring(count) end
	e._range = {}
	e.C_Spell.IsSpellInRange = function(spell) return e._range[spell] end
	for name, viewer in pairs(e._viewers) do
		for i, item in ipairs(viewer._items) do
			item.GetSpellID = function() return name == "BuffIconCooldownViewer" and 3000 + i or 1000 + i end
			if item.Cooldown then
				item.Cooldown:GetCountdownFontString():SetPoint("CENTER", item.Cooldown, "CENTER", 0, 0)
				item.ChargeCount.Current:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
				item.Applications.Applications:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
			end
		end
	end
end

local function New(path, cooldowns)
	local saved = { version = 42, profiles = { Default = { Cooldowns = { enabled = true, path = path } } }, characters = {} }
	local env, K, ns = C.New({ saved = saved, setup = Game, cooldowns = cooldowns })
	env.RunTimers()
	return env, K, ns, function(key, value) K.Options.Write("Cooldowns", key, value); env.RunTimers() end
end

local function IconOf(ns, group, spell)
	local row = ns.Mirror.Row(group)
	for i = 1, row.count do
		if row.icons[i].entry and row.icons[i].entry.spellID == spell then return row.icons[i] end
	end
end

local function Preview(env, ns)
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(280, 300)
	return ns.Preview.Build(parent)
end

case("a vertical essential grid keeps clear of the utility row at every screen size", function()
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K = C.W.New({ boot = false, width = screen[1], height = screen[2], size = "auto", fit = true, setup = function(e) C.Install(e) end })
		Load(C.Files(), env)
		C.CoreEnv.Boot(env)
		K.Options.Write("HudStyle", "style", "medallions")
		C.Enable(env, K)
		env.RunTimers()
		local ns = env._addons.KstyleUI_Cooldowns
		local a, b = ns.Mirror.Row("essential"), ns.Mirror.Row("utility")
		for _, vertical in ipairs({ false, true }) do
			K.Options.Write("Cooldowns", "essential.vertical", vertical)
			env.RunTimers()
			a:SetCount(6)
			b:SetCount(6)
			for i = 1, a.count do
				for j = 1, b.count do
					local x, y = G.ScaledRect(a.icons[i], env.UIParent, K.Scale.Root()), G.ScaledRect(b.icons[j], env.UIParent, K.Scale.Root())
					local overlap = math.min(x.right, y.right) - math.max(x.left, y.left) > 1 and math.min(x.top, y.top) - math.max(x.bottom, y.bottom) > 1
					assert(not overlap, screen[1] .. "x" .. screen[2] .. " vertical " .. tostring(vertical) .. ": essential icon " .. i .. " overlaps utility icon " .. j)
				end
			end
		end
	end
end)

case("Vertical fills an attached row's own box column first and stands a detached or moved row upright", function()
	local _, K, ns, Write = New("mirror")
	Write("essential.columns", 6)
	Write("essential.rows", 2)
	local row = ns.Mirror.Row("essential")
	local width, height = row.holder:GetWidth(), row.holder:GetHeight()
	Write("essential.vertical", true)
	assert(row.holder:GetWidth() == width and row.holder:GetHeight() == height, "attached, the row keeps its size")
	local first, second = { row.icons[1]:GetPoint(1) }, { row.icons[2]:GetPoint(1) }
	assert(first[4] == second[4] and first[5] ~= second[5], "the second icon sits below the first")
	Write("attached", false)
	assert(math.abs(row.holder:GetWidth() - height) < 1 and math.abs(row.holder:GetHeight() - width) < 1, "detached, the row stands upright")
	Write("attached", true)
	assert(row.holder:GetWidth() == width, "attached again, it keeps its size")
	assert(K.Layout.Set("cooldowns.essential", "x", 40), "the row moves in Layout Mode")
	assert(math.abs(row.holder:GetHeight() - width) < 1, "moved, it stands upright")
end)

case("a spell override rematches its rules and visibility", function()
	local env, _, ns, Write = New("mirror")
	Write("rules.hideReady", "1033")
	local icon = IconOf(ns, "essential", 1003)
	assert(icon:GetAlpha() == 0, "the overridden spell named in the rule hides")
	env.FireEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 1003, 1077)
	assert(icon.entry.spell == 1077 and icon:GetAlpha() == 1, "the new override is not in the rule, so the icon shows")
end)

case("Grey these repaints a cooling icon when the rule changes", function()
	local env, _, ns, Write = New("mirror")
	Write("rules.grey", "1001")
	local icon = IconOf(ns, "essential", 1001)
	env._cdm.cooldown[1001] = { active = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(W.LastCall(icon.icon, "SetDesaturated")[1] == true, "a listed cooling spell is grey")
	Write("rules.grey", "")
	assert(W.LastCall(icon.icon, "SetDesaturated")[1] == false, "clearing the rule repaints it in colour")
	Write("rules.grey", "1001")
	assert(W.LastCall(icon.icon, "SetDesaturated")[1] == true, "listing it again greys it at once")
end)

case("Blizzard's texts, counts and shading return exactly", function()
	local env, _, ns, Write = New("reskin")
	local item = env._viewers.UtilityCooldownViewer._items[1]
	local text = item.Cooldown:GetCountdownFontString()
	text:SetJustifyH("CENTER")
	text:SetPoint("LEFT", item, "LEFT", 1, 2)
	Write("utility.timerPosition", "RIGHT")
	Write("utility.timerPosition", "")
	assert(text:GetNumPoints() == 2 and W.LastCall(text, "SetJustifyH")[1] == "CENTER", "both native anchors and the justification return")
	local buff = env._viewers.BuffIconCooldownViewer._items[1]
	Write("rules.noCount", "3001")
	Write("utility.timerX", 5)
	ns.definition.Disable()
	assert(buff.Applications.Applications:GetAlpha() == 1, "stopping the module gives the buff its stack count back")
	assert(select(4, text:GetPoint(1)) == 0, "stopping the module puts the native timer back")
end)

case("a secret activity reading still releases this addon's grey", function()
	local env, _, _, Write = New("reskin")
	local buff = env._viewers.BuffIconCooldownViewer._items[1]
	buff._active = false
	Write("buffs.inactiveShade", "grey")
	assert(W.LastCall(buff.Icon, "SetDesaturated")[1] == true, "the inactive buff greys")
	buff.IsActive = function() return env.Secret(false) end
	Write("buffs.inactiveShade", "")
	assert(W.LastCall(buff.Icon, "SetDesaturated")[1] == false, "switching Grey off restores its colour")
end)

case("a native text anchored through a secret is left where it is", function()
	local env, K, _, Write = New("reskin")
	local item = env._viewers.UtilityCooldownViewer._items[2]
	local text = item.Cooldown:GetCountdownFontString()
	text.GetPoint = function() return "CENTER", item, "CENTER", env.Secret(0), env.Secret(0) end
	local before = #W.Calls(text, "SetPoint")
	Write("utility.timerX", 5)
	Write("utility.timerX", 0)
	assert(#W.Calls(text, "SetPoint") == before, "a secret anchor is never replayed or offset")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "and nothing raises")
end)

case("the preview shows spell rules, zero charges and overflow", function()
	local env, _, ns, Write = New("mirror")
	local frame = Preview(env, ns)
	Write("essential.columns", 1)
	Write("essential.rows", 1)
	frame:Refresh()
	local plain = frame.rows.utility.count
	Write("essential.overflow", true)
	frame:Refresh()
	assert(frame.rows.utility.count > plain, "essential samples past its grid join the utility preview")
	Write("rules.hideReady", "1001")
	frame:Refresh()
	local hidden = false
	for _, icon in ipairs(frame.rows.essential.icons) do hidden = hidden or icon.ruleHidden == true end
	for _, icon in ipairs(frame.rows.utility.icons) do hidden = hidden or icon.ruleHidden == true end
	assert(hidden, "an applied hide rule hides a preview sample")
	local zero
	for _, icon in ipairs(frame.rows.utility.icons) do
		if tostring(icon.count:GetText()) == "0" then zero = icon end
	end
	assert(zero, "a preview sample has no charge left")
	Write("utility.hideZero", true)
	frame:Refresh()
	assert(tostring(zero.count:GetText()) ~= "0", "Hide 0 charges reaches the preview")
end)

case("the Fade row follows the path the groups really took", function()
	local _, _, ns = New("mirror")
	ns.Path.Fail("essential", "test")
	ns.Path.Fail("utility", "test")
	for _, row in ipairs(ns.Settings.Schema()) do
		if row.key == "rules.fade" then assert(not row.showWhen(ns.Settings.current), "a group that fell back to the reskin hides its mirror-only rows") end
	end
end)

case("one cooldown event lays a row out once", function()
	local cooldowns = C.Sample()
	for j = 1, 9 do cooldowns[600 + j] = { spellID = 6000 + j, category = C.CATEGORY.Essential } end
	local env, _, ns, Write = New("mirror", cooldowns)
	Write("essential.columns", 12)
	Write("essential.rows", 1)
	local row = ns.Mirror.Row("essential")
	local ids = {}
	for j = 1, row.count do ids[j] = row.icons[j].entry.spell end
	Write("rules.hideCooling", table.concat(ids, ","))
	Write("closeGaps", true)
	local passes, place = 0, row.Place
	row.Place = function(self) passes = passes + 1; return place(self) end
	for _, id in ipairs(ids) do env._cdm.cooldown[id] = { active = true } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(passes == 1, "hiding " .. row.count .. " icons took " .. passes .. " layout passes")
end)

case("unchanged refreshes and range events write nothing", function()
	local env, _, _, Write = New("reskin")
	local ns
	local buff = env._viewers.BuffIconCooldownViewer._items[2]
	local stacks = buff.Applications.Applications
	buff._active = false
	Write("buffs.inactiveShade", "grey")
	local alphas, greys = #W.Calls(stacks, "SetAlpha"), #W.Calls(buff.Icon, "SetDesaturated")
	for _ = 1, 4 do buff:UpdateShownState(); env.RunTimers() end
	assert(#W.Calls(stacks, "SetAlpha") == alphas, "four unchanged buff refreshes write no count alpha")
	assert(#W.Calls(buff.Icon, "SetDesaturated") == greys, "and no desaturation")

	env, _, ns, Write = New("mirror")
	Write("rules.range", "1001")
	local icon = IconOf(ns, "essential", 1001)
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 1001, false, true)
	local paints = #W.Calls(icon.icon, "SetVertexColor")
	for _ = 1, 3 do env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 1001, false, true) end
	assert(#W.Calls(icon.icon, "SetVertexColor") == paints, "repeated identical range events repaint nothing")
	assert(icon.outOfRange, "the icon stays tinted")
end)

case("localised names match in any case, within the letter limit", function()
	local env, _, ns, Write = New("mirror")
	local icon = IconOf(ns, "essential", 1001)
	env.C_Spell.GetSpellName = function(spell) return spell == 1001 and "\195\137clair" or "Other" end
	Write("rules.hideReady", "\195\169clair")
	assert(icon:GetAlpha() == 0, "an accented capital matches its lower-case spelling")
	local list = string.rep("\231\129\171", 81)
	Write("rules.grey", list)
	assert(ns.Settings.current.rules.grey == list, "81 letters fit under the 240-letter limit whatever their bytes")
end)

assert(failed == 0, failed .. " review checks failed")
print("cooldowns parity round 1 fixes ok")
