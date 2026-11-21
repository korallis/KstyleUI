-- test-cooldowns-parity-round1.lua: EllesmereUI parity round 1 for Cooldowns: every new option keeps today's defaults on a v0.2.8 profile, applies when switched on (spell rules, text placement, vertical grids, overflow, glows in combat, range tint, zero charges, counts only, inactive buff shading), follows the events that change it, and restores when switched off, on both paths.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function Game(e)
	C.Game(e)
	e.C_StringUtil.TruncateWhenZero = function() return "zero-safe" end
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

local function X(region) return W.LastCall(region, "SetPoint")[4] end
local function Clean(env, K, what) assert(#env._errors == 0 and K.ErrorCount() == 0, what .. " raised no errors") end

-- Defaults: a v0.2.8 profile keeps every new option off and today's look.
do
	local env, K, ns = New("mirror")
	local current = ns.Settings.current
	assert(not current.glowsInCombat and not current.closeGaps and current.fadeAlpha == 0.5, "new module switches default off")
	for _, key in ipairs(ns.Settings.RULES) do assert(current.rules[key] == "", "rule " .. key .. " starts empty") end
	for _, group in ipairs({ "essential", "utility", "buffs" }) do
		local cfg = current[group]
		assert(cfg.timerPosition == "" and cfg.timerX == 0 and cfg.timerY == 0 and cfg.countX == 0 and cfg.countY == 0 and not cfg.vertical, group .. " keeps its text and grid")
	end
	assert(not current.essential.hideZero and not current.essential.countOnly and not current.essential.overflow and current.buffs.inactiveShade == "", "group switches default off")
	for _, group in ipairs({ "essential", "utility" }) do
		local row = ns.Mirror.Row(group)
		for i = 1, row.count do
			local icon = row.icons[i]
			assert(icon:GetAlpha() == 1 and not icon.ruleHidden and not icon.outOfRange and icon.tint[1] == 1, group .. " icons stay as before")
			assert(#W.Calls(icon, "SetAlpha") == 0 and #W.Calls(icon.icon, "SetAlpha") == 0, "defaults write no fade")
		end
	end
	Clean(env, K, "defaults")
end

-- Spell rules on KstyleUI icons, each switched on, driven by its events, then switched off.
do
	local env, K, ns, Write = New("mirror")
	local cdm = env._cdm
	local a, b, c = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "essential", 1003)
	Write("essential.growth", "right")
	local slotB, slotC = X(b), X(c)
	env._cdm.cooldown[1002] = { active = true }; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	Write("rules.hideCooling", "spell 1002")
	assert(b:GetAlpha() == 0 and b.ruleHidden and not b:IsMouseEnabled(), "a spell named in any case hides and lets the pointer through")
	assert(X(c) == slotC, "without Close gaps the slot stays empty")
	Write("closeGaps", true)
	assert(X(c) == slotB, "Close gaps moves the next icon into the hidden slot")
	Write("rules.hideCooling", "")
	assert(b:GetAlpha() == 1 and b:IsMouseEnabled() and X(c) == slotC, "clearing the rule restores the icon and its place")
	env._cdm.cooldown[1002] = nil; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	Write("closeGaps", false)

	Write("rules.hideCooling", "1001")
	assert(a:GetAlpha() == 1, "a ready spell shows")
	cdm.cooldown[1001] = { active = true }; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(a:GetAlpha() == 0, "a cooling spell hides on the cooldown event")
	cdm.cooldown[1001] = nil; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(a:GetAlpha() == 1, "it returns when ready")
	Write("rules.hideCooling", "")

	Write("rules.hideReady", "1002")
	cdm.charges[1002] = { current = 2, max = 2 }; env.FireEvent("SPELL_UPDATE_CHARGES")
	assert(b:GetAlpha() == 0, "a charge spell at full charges counts as ready")
	cdm.charges[1002] = { current = 1, max = 2 }; env.FireEvent("SPELL_UPDATE_CHARGES")
	assert(b:GetAlpha() == 1, "a spent charge shows the icon")
	Write("rules.spent", "1002")
	assert(b:GetAlpha() == 0, "Hide until all charges are spent keeps it hidden while a charge is left")
	cdm.cooldown[1002] = { active = true }; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(b:GetAlpha() == 1, "it shows once every charge is spent")
	cdm.cooldown[1002], cdm.charges[1002] = nil, nil; env.FireEvent("SPELL_UPDATE_COOLDOWN"); env.FireEvent("SPELL_UPDATE_CHARGES")
	Write("rules.hideReady", ""); Write("rules.spent", "")

	Write("essential.usable", false)
	Write("rules.hideUnusable", "1001")
	cdm.usable[1001] = { usable = false, noMana = false }; env.FireEvent("SPELL_UPDATE_USABLE")
	assert(a:GetAlpha() == 0 and a.usable, "Hide until usable works with Dim unusable off, which still leaves the icon undimmed")
	cdm.usable[1001] = { usable = false, noMana = true }; env.FireEvent("SPELL_UPDATE_USABLE")
	assert(a:GetAlpha() == 1, "low resources do not hide it")
	Write("rules.hideUnusable", ""); Write("essential.usable", true)
	assert(not a.usable, "Dim unusable on dims a spell short of resources")
	Write("rules.noCost", "1001")
	assert(a.usable, "Ignore resource cost keeps it in full colour")
	cdm.usable[1001] = nil; env.FireEvent("SPELL_UPDATE_USABLE"); Write("rules.noCost", "")

	Write("rules.fade", "1001"); Write("fadeAlpha", 0.3)
	cdm.cooldown[1001] = { active = true }; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(a:GetAlpha() == 0.3, "a faded spell drops to the fade opacity while cooling")
	cdm.cooldown[1001] = nil; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(a:GetAlpha() == 1, "and returns when ready")
	Write("rules.fade", "")

	Write("essential.desaturate", true); Write("rules.colour", "1001"); Write("rules.grey", "")
	assert(a.greyWhileCooling == false and b.greyWhileCooling == true, "Keep these in colour overrides Grey while cooling")
	Write("essential.desaturate", false); Write("rules.colour", ""); Write("rules.grey", "1002")
	assert(b.greyWhileCooling == true and a.greyWhileCooling == false, "Grey these greys a spell with the group switch off")
	b.onCooldown = true; b:Paint()
	assert(W.LastCall(b.icon, "SetDesaturated")[1] == true, "the grey reaches the icon")
	b.onCooldown = nil; Write("rules.grey", "")

	Write("rules.reverse", "1001"); Write("rules.noSwipe", "1003"); Write("rules.noCount", "1002")
	assert(W.LastCall(a.cooldown, "SetReverse")[1] == true and W.LastCall(b.cooldown, "SetReverse")[1] == false, "Reverse swipe is per spell")
	assert(W.LastCall(c.cooldown, "SetDrawSwipe")[1] == false and W.LastCall(a.cooldown, "SetDrawSwipe")[1] == true, "Hide swipe is per spell")
	assert(b.count:GetAlpha() == 0 and a.count:GetAlpha() == 1, "Hide counts is per spell")
	Write("rules.reverse", ""); Write("rules.noSwipe", ""); Write("rules.noCount", "")
	assert(W.LastCall(a.cooldown, "SetReverse")[1] == false and W.LastCall(c.cooldown, "SetDrawSwipe")[1] == true and b.count:GetAlpha() == 1, "per-spell sweeps and counts restore")

	local black = W.LastCall(a.cooldown, "SetSwipeColor")
	Write("tintSource", "custom"); Write("tintColor", { r = 0.1, g = 0.2, b = 0.3 }); Write("rules.tint", "1001")
	a.onCooldown = true; a:Paint()
	local tint = W.LastCall(a.cooldown, "SetSwipeColor")
	assert(tint[1] == 0.1 and tint[2] == 0.2 and tint[3] == 0.3, "Tint swipe colours the sweep")
	Write("rules.tint", ""); a:Paint()
	assert(W.LastCall(a.cooldown, "SetSwipeColor")[1] == black[1], "clearing the tint restores the quiet sweep")
	a.onCooldown = nil

	Write("glowSource", "custom"); Write("glowColor", { r = 0.4, g = 0.5, b = 0.6 }); Write("rules.glow", "1001")
	assert(a.readyGlow.colorRGB and a.readyGlow.colorRGB[1] == 0.4 and not b.readyGlow.colorRGB, "Glow colour tints that spell's ready glow only")
	Write("rules.glow", "")
	assert(not a.readyGlow.colorRGB, "clearing it restores the accent glow")

	Write("essential.gcd", true); Write("rules.noGcd", "1001")
	cdm.calls = {}; env.FireEvent("SPELL_UPDATE_COOLDOWN")
	for _, args in ipairs(C.Calls(env, "GetSpellCooldownDuration")) do
		if args[1] < 2000 then assert(args[2] == (args[1] == 1001), "Ignore the global cooldown is per spell") end
	end
	Write("rules.noGcd", ""); Write("essential.gcd", false)

	cdm.charges[1002] = { current = 1, max = 2 }; env.FireEvent("SPELL_UPDATE_CHARGES")
	Write("rules.noEdge", "1002")
	assert(W.LastCall(b.chargeCooldown, "SetDrawEdge")[1] == false, "Hide recharge edge hides that spell's recharge line")
	Write("rules.noEdge", "")
	assert(W.LastCall(b.chargeCooldown, "SetDrawEdge")[1] == true, "and restores it")
	Write("essential.hideZero", true)
	assert(b.count:GetText() == "zero-safe", "Hide 0 charges formats the count through TruncateWhenZero")
	Write("essential.hideZero", false)
	assert(b.count:GetText() ~= "zero-safe", "and stops when off")

	Write("rules.range", "1001")
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 1001, false, true)
	local range = ns.Settings.current
	assert(a.outOfRange and a.tint[1] == range.rangeR, "Out of range tint follows the range event")
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 1001, true, true)
	assert(not a.outOfRange and a.tint[1] == 1, "and clears in range")
	env._range[1001] = false; Write("rangeColor", { r = 0.9, g = 0.1, b = 0.1 })
	assert(a.tint[1] == 0.9, "a new colour and the current range apply at once")
	Write("rules.range", "")
	assert(a.tint[1] == 1, "clearing the rule restores the icon colour")

	Write("essential.countOnly", true)
	assert(a.icon:GetAlpha() == 0 and W.LastCall(a.cooldown, "SetDrawSwipe")[1] == false and W.LastCall(a.cooldown, "SetHideCountdownNumbers")[1] == true, "Counts only leaves the socket and the count")
	Write("essential.countOnly", false)
	assert(a.icon:GetAlpha() == 1 and W.LastCall(a.cooldown, "SetDrawSwipe")[1] == true and W.LastCall(a.cooldown, "SetHideCountdownNumbers")[1] == false, "and restores the icon")

	env.SetCombat(true)
	Write("rules.hideReady", "1001")
	assert(a:GetAlpha() == 0, "rules apply in combat")
	env.SetCombat(false)
	Write("rules.hideReady", "")
	Clean(env, K, "spell rules")
end

-- Glows only in combat follows combat start and end.
do
	local env, K, ns, Write = New("mirror")
	local a = IconOf(ns, "essential", 1001)
	Write("essential.readyGlow", true)
	assert(a.ready, "a ready spell glows")
	Write("glowsInCombat", true)
	assert(not a.ready, "out of combat the glow hides")
	env._cdm.overlay[1001] = true; env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1001)
	assert(not a.proc, "a proc waits for combat")
	env.SetCombat(true)
	assert(a.ready and a.proc, "combat brings both glows back")
	env.SetCombat(false)
	assert(not a.ready and not a.proc, "leaving combat hides them")
	Write("glowsInCombat", false)
	assert(a.ready and a.proc, "switching off restores the glows")
	Clean(env, K, "glows in combat")
end

-- Text placement, vertical grids and overflow on KstyleUI rows.
do
	local cooldowns = C.Sample()
	for i = 1, 14 do cooldowns[600 + i] = { spellID = 6000 + i, category = C.CATEGORY.Essential } end
	local env, K, ns, Write = New("mirror", cooldowns)
	local a = IconOf(ns, "essential", 1001)
	local countdown, count = a.countdown, a.count
	local before, countBefore = { countdown:GetPoint(1) }, { count:GetPoint(1) }
	Write("essential.timerPosition", "TOP"); Write("essential.timerX", 3); Write("essential.countX", 2); Write("essential.countY", -1)
	local point = W.LastCall(countdown, "SetPoint")
	assert(point[1] == "TOP" and point[3] == "TOP" and math.abs(point[4] - 3) < 0.6, "the countdown moves to the chosen place and offset")
	local moved = { count:GetPoint(1) }
	assert(math.abs(moved[4] - countBefore[4] - 2) < 0.6 and math.abs(moved[5] - countBefore[5] + 1) < 0.6, "the count follows its offsets")
	Write("essential.size", 40)
	moved = { count:GetPoint(1) }
	assert(math.abs(moved[4] - countBefore[4] - 2) < 0.6, "a restyle keeps one count offset, not two")
	Write("essential.size", 36.7)
	for _, key in ipairs({ "timerX", "countX", "countY" }) do Write("essential." .. key, 0) end
	Write("essential.timerPosition", "")
	local after, countAfter = { countdown:GetPoint(1) }, { count:GetPoint(1) }
	for i = 1, 5 do assert(after[i] == before[i] and countAfter[i] == countBefore[i], "the default placement returns exactly") end

	local row = ns.Mirror.Row("essential")
	local cap = ns.Grid.Capacity(row.cfg)
	assert(row.count == cap and #ns.Mirror.Row("utility").icons >= 2, "a long essential list fills its grid")
	local width, height = row.holder:GetWidth(), row.holder:GetHeight()
	Write("essential.vertical", true)
	assert(row.holder:GetWidth() == width and row.holder:GetHeight() == height, "attached, Vertical keeps the grid's box")
	Write("essential.vertical", false)
	assert(math.abs(row.holder:GetWidth() - width) < 1, "and returns")

	local utility = ns.Mirror.Row("utility")
	local plain = utility.count
	Write("essential.overflow", true)
	assert(utility.count > plain and utility.icons[plain + 1].entry.spellID == ns.Mirror.Row("essential").icons[cap].entry.spellID + 1, "Overflow sends the next essential cooldown to the utility row")
	Write("essential.overflow", false)
	assert(utility.count == plain, "and takes it back")
	Clean(env, K, "placement and grids")
end

-- Restyled Blizzard viewers: text offsets restore exactly, per-buff counts and inactive shading follow the active state.
do
	local env, K, ns, Write = New("reskin")
	local item = env._viewers.UtilityCooldownViewer._items[1]
	local countdown, charge = item.Cooldown:GetCountdownFontString(), item.ChargeCount.Current
	Write("utility.timerX", 5); Write("utility.countY", 4)
	local function near(value, want) return math.abs(value - want) < 0.6 end
	assert(near(select(4, countdown:GetPoint(1)), 5) and near(select(5, charge:GetPoint(1)), 6), "offsets move Blizzard's texts from their own anchors")
	K.Callbacks.Fire("ScaleChanged"); env.RunTimers()
	assert(near(select(4, countdown:GetPoint(1)), 5), "a restyle does not add the offset twice")
	Write("utility.timerX", 0); Write("utility.countY", 0)
	assert(select(4, countdown:GetPoint(1)) == 0 and select(5, charge:GetPoint(1)) == 2, "zero offsets put the texts back exactly")

	local buffs = env._viewers.BuffIconCooldownViewer._items
	Write("rules.noCount", "3001")
	assert(buffs[1].Applications.Applications:GetAlpha() == 0 and buffs[2].Applications.Applications:GetAlpha() == 1, "Hide counts reaches Blizzard's buff by its spell")
	Write("rules.noCount", "")
	assert(buffs[1].Applications.Applications:GetAlpha() == 1, "and restores it")

	buffs[2]._active = false
	Write("buffs.inactiveShade", "grey")
	assert(W.LastCall(buffs[2].Icon, "SetDesaturated")[1] == true and not W.LastCall(buffs[1].Icon, "SetDesaturated"), "an inactive buff greys, an active one is untouched")
	buffs[2]._active = true; buffs[2]:UpdateShownState(); env.RunTimers()
	assert(W.LastCall(buffs[2].Icon, "SetDesaturated")[1] == false, "it regains colour when it turns active")
	buffs[2]._active = false; buffs[2]:UpdateShownState(); env.RunTimers()
	Write("rules.colour", "3002")
	assert(W.LastCall(buffs[2].Icon, "SetDesaturated")[1] == false, "Keep these in colour overrides the group")
	Write("rules.colour", ""); Write("buffs.inactiveShade", "")
	assert(W.LastCall(buffs[2].Icon, "SetDesaturated")[1] == false, "switching off restores Blizzard's colour")
	Write("buffs.inactiveShade", "grey")
	ns.definition.Disable()
	assert(W.LastCall(buffs[2].Icon, "SetDesaturated")[1] == false, "stopping the module restores the icon")
	Clean(env, K, "restyled viewers")
end

-- KstyleUI buff icons keep an inactive buff in colour on request, and the preview follows the group options.
do
	local env, K, ns, Write = New("mirror")
	Write("buffs.inactive", true)
	local row = ns.Mirror.Row("buffs")
	local icon = row.icons[1]
	assert(not icon.usable and W.LastCall(icon.icon, "SetDesaturated")[1] == true, "an inactive KstyleUI buff greys by default")
	Write("buffs.inactiveShade", "colour")
	icon:Paint()
	assert(W.LastCall(icon.icon, "SetDesaturated")[1] == false, "Full colour keeps it in colour")
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(280, 300)
	local frame = ns.Preview.Build(parent)
	local essential = frame.rows.essential
	local width = essential.holder:GetWidth()
	Write("essential.vertical", true); Write("glowsInCombat", true); Write("essential.readyGlow", true); Write("essential.timerPosition", "TOP")
	frame:Refresh()
	assert(math.abs(essential.holder:GetWidth() - width) < 1 and not essential.icons[4].proc and not essential.icons[2].ready, "the preview follows vertical grids and glows in combat")
	assert(W.LastCall(essential.icons[1].countdown, "SetPoint")[1] == "TOP", "the preview follows the timer position")
	assert(W.LastCall(frame.rows.buffs.icons[3].icon, "SetDesaturated")[1] == false, "the preview keeps the inactive sample in colour")
	Clean(env, K, "buff icons and preview")
end

print("cooldowns parity round 1 ok")

-- A count text whose anchor offsets read secret (as the client returns them on some cooldown icons) is left where it is;
-- moving its offsets raises no arithmetic-on-secret error, and the offsets apply once the anchor reads plain again.
do
	local env, K, ns, Write = New("mirror")
	local a = IconOf(ns, "essential", 1001)
	local count, get = a.count, a.count.GetPoint
	rawset(count, "GetPoint", function(self, i)
		local point, rel, relPoint, x, y = get(self, i)
		return point, rel, relPoint, env.Secret(x), env.Secret(y)
	end)
	a.countBase = nil
	Write("essential.countX", 2)
	Clean(env, K, "a secret count anchor")
	assert(a.countBase == nil, "a secret anchor is not cached")
	rawset(count, "GetPoint", nil)
	Write("essential.countY", -1)
	assert(type(a.countBase) == "table", "a plain anchor is cached on the next restyle")
	Clean(env, K, "a plain count anchor after a secret one")
end
