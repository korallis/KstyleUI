-- test-auras.lua: KstyleUI_Auras against a fake AuraContainer engine: build, settings, weapon enchantments, the aura-secrecy gate, Blizzard's frames, Layout, fallbacks and the preview.
local A = dofile("Tools/regression/auras_env.lua")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function find(list, fn)
	for _, item in ipairs(list) do
		if fn(item) then
			return item
		end
	end
end

local function registered(env, key)
	return find(env._layout, function(entry)
		return entry.key == key
	end)
end

local function devlog(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog or {}) do
		if tostring(entry.message):find(text, 1, true) then
			return entry
		end
	end
end

local function size(frame)
	local w, h = frame:GetSize()
	return w, h
end

local function groupButtons(group)
	return group.frames
end

local function isAncestor(frame, of)
	local parent = of:GetParent()
	while parent do
		if parent == frame then
			return true
		end
		parent = parent:GetParent()
	end
	return false
end

local function start(opts)
	local env, K, ns = A.New(opts)
	K.Modules.Enable("Auras")
	env.RunTimers()
	return env, K, ns
end

-- Load: the module registers itself, its settings and its preview, and stays off.
do
	local env, K = A.New({ layout = true })
	check(find(K.Modules.List(), function(name)
		return name == "Auras"
	end), "Auras registers with Modules")
	check(K.Modules.IsRunning("Auras") == false, "Auras is off until the player turns it on")
	check(#env._containers == 0, "nothing is built while the module is off")
	check(type(K.Options.Preview("Auras")) == "function", "Auras gives the settings window a preview builder")
	check(K.Options.Row("Auras", "buffs.iconSize"), "the buff icon size is a setting")
	check(K.Options.Row("Auras", "debuffs.columns"), "the debuff columns are a setting")
	check(K.Options.Row("Auras", "timer.font").type == "font", "the timer font is a font row")
	check(K.Options.Row("Auras", "count.outline").type == "dropdown", "the stack outline is a dropdown")
	check(K.Options.Row("Auras", "accent.color").type == "color", "the accent has a custom colour row")
	check(env.BuffFrame:GetParent() == env.UIParent, "Blizzard's buffs stay while the module is off")
end

-- Enable: two containers on the engine, placed by Layout, with Blizzard's frames hidden.
do
	local env, K = start({ layout = true })
	check(K.Modules.IsRunning("Auras"), "the module runs")
	check(#A.Rows(env) == 4, "one container for buffs and one for debuffs, and the full list's two, built up front so it opens in combat, got " .. #A.Rows(env))
	local buffs, bg = A.Container(env, "HELPFUL")
	local debuffs, dg = A.Container(env, "HARMFUL")
	check(buffs and debuffs and buffs ~= debuffs, "buffs and debuffs are separate groups")
	check(buffs._unit == "player" and debuffs._unit == "player", "both follow the player")
	do
		local skin = (bg.frames[1]:GetChildren())
		local fr, fg, fb = K.Tokens.Color("buttonFill")
		local body = false
		for _, region in ipairs({ skin:GetRegions() }) do
			local set = region._state.Texture and region._state.Texture[1]
			local r, g, b = region:GetVertexColor()
			if type(r) == "number" and set == (K.Tokens.Texture("chamferTile")) and math.abs(r - fr) < 1e-3 and math.abs(g - fg) < 1e-3 and math.abs(b - fb) < 1e-3 then
				body = true
			end
		end
		check(body, "each aura button sits on the near-black button body every square icon shares")
	end
	check(bg.maxFrameCount == 12 and dg.maxFrameCount == 12, "2 rows of 6 buffs and 2 rows of 6 debuffs")
	check(bg.sortMethod == env.AuraContainerSortMethod.ExpirationOnly and bg.sortDirection == env.AuraContainerSortDirection.Normal, "buffs sort by time left")
	check(bg.layout.elementWidth == 38 and bg.layout.elementHeight == 51, "each buff is a 38-unit icon with its 12-unit timer under it")
	check(bg.layout.elementSpacing == 10 and bg.layout.lineSpacing == 0, "10-unit gaps between icons")
	check(buffs._flow.anchor == "TOPLEFT" and buffs._flow.horizontal == 1 and buffs._flow.vertical == -1, "buffs read right from under the cap's title, then down, so every row starts under the header")
	check(buffs._flow.lineSize >= 6 * 38 + 5 * 10 and buffs._flow.lineSize < 7 * 38 + 6 * 10, "six icons fit on a line, and a seventh wraps")

	local b, d = registered(env, "auras.buffs"), registered(env, "auras.debuffs")
	check(b and d, "both elements register with Layout under the element keys")
	check(b.opts.label == "Buffs" and d.opts.label == "Debuffs", "labels come from Setup.Layouts")
	check(b.opts.module == "Auras" and b.opts.scalable == true and not b.opts.resizable, "the elements scale in Layout Mode")
	-- Lumen Rails: the Blessings card sits on the right rail, on the 28-unit margin, 16 units under the 326-unit lens
	-- card; the docked debuff row's own element waits at the card's foot, where it stays when the player undocks it.
	check(b.position.anchor == "TOPRIGHT" and b.position.x == -28 and b.position.y == -370, "buffs sit on the right rail, under the lens card")
	check(d.position.anchor == "TOPRIGHT" and d.position.x == -28 and d.position.y == -484, "debuffs wait at the Blessings card's foot")
	-- The buff element is the whole Blessings card: the rail's 318 wide, with the cap, two rows of six, the hairline
	-- and the docked debuff row (test-auras-card.lua has the card's maths).
	local w, h = size(b.frame)
	check(near(w, 318), "the buff element is the 318 card, got " .. tostring(w) .. " x " .. tostring(h))
	check(h > 102 + 51, "and taller than both rows, for the cap, the padding and the hairline: " .. tostring(h))
	w, h = size(d.frame)
	check(near(w, 278) and near(h, 102), "the debuff element is its two rows, 278 x 102")
	check(not isAncestor(b.frame, buffs), "the Layout element is not an ancestor of the container, so Layout never touches an aura button")
	local host = buffs:GetParent()
	local point, rel, relPoint = buffs:GetPoint(1)
	check(rel and rel ~= host and rel:GetParent() == host, "the container hangs from a content frame on its host, inside the card's padding and under the cap")
	check(point == "TOPLEFT" and relPoint == "TOPLEFT", "from its top left corner, under the cap's title, so a short row sits under the header with no dead glass before it")

	for _, button in ipairs(groupButtons(bg)) do
		local aura = button._aura
		check(aura.icon and aura.timer and aura.count, "each buff gets an icon, a timer and a stack count")
		check(aura.cancel == "RightButtonUp", "right-click cancels a buff through the secure template")
		check(#aura.dispel == 0, "buffs show no dispel border")
		local bw, bh = button:GetSize()
		check(near(bw, 38) and near(bh, 51), "an aura button is sized to its element")
	end
	for _, button in ipairs(groupButtons(dg)) do
		local aura = button._aura
		check(aura.cancel == nil, "debuffs cannot be cancelled")
		check(#aura.dispel == 9, "each debuff gets a nine-piece dispel border, got " .. #aura.dispel)
		local opts = aura.dispel[1].options
		check(opts.style == env.Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, "the engine colours the border by dispel type")
		check(opts.showWithoutDispelType == true and opts.showWhenHarmful == true, "a debuff with no type still gets its border")
	end
	check(next(buffs._enchants) ~= nil, "weapon enchantments join the buffs")
	local count = 0
	for _, enchant in pairs(buffs._enchants) do
		count = count + 1
		check(enchant.enabled == true, "each weapon enchantment slot is on")
		check(enchant.frame._aura.icon and enchant.frame._aura.timer, "an enchantment button is styled like a buff")
	end
	check(count == 3, "main hand, off hand and ranged slots, got " .. count)
	check(buffs._enchantLayout.placement == env.CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups, "enchantments come first")
	check(next(debuffs._enchants) == nil, "debuffs have no weapon enchantments")

	check(A.Hidden(env, env.BuffFrame) and A.Hidden(env, env.DebuffFrame), "Blizzard's buff and debuff frames are hidden through Safe")
	check(K.Safe.IsHidden(env.BuffFrame) and K.Safe.IsHidden(env.DebuffFrame), "Safe owns the hidden frames")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Settings: each change reaches the engine and the buttons.
do
	local env, K, ns = start({ layout = true })
	local buffs, bg = A.Container(env, "HELPFUL")
	local _, dg = A.Container(env, "HARMFUL")
	local b = registered(env, "auras.buffs")

	K.Options.Write("Auras", "buffs.iconSize", 32)
	check(bg.layout.elementWidth == 32 and bg.layout.elementHeight == 45, "a new icon size reaches the group layout")
	local bw, bh = groupButtons(bg)[1]:GetSize()
	check(near(bw, 32) and near(bh, 45), "and the buttons")
	local w, h = size(b.frame)
	local card = ns.Model.Card({ width = 6 * 32 + 5 * 10, height = 2 * 45 }, { width = 6 * 38 + 5 * 10, height = 102 }, ns.Model.CARD_PAD, ns.Model.CARD_GAP)
	check(near(w, card.width) and near(h, card.height), "and the card round it: the wider debuff row sets the width, got " .. tostring(w) .. " x " .. tostring(h) .. " for " .. card.width .. " x " .. card.height)

	K.Options.Write("Auras", "buffs.sort", "name")
	K.Options.Write("Auras", "buffs.reverse", true)
	check(bg.sortMethod == env.AuraContainerSortMethod.NameOnly and bg.sortDirection == env.AuraContainerSortDirection.Reverse, "sorting by name, reversed")

	K.Options.Write("Auras", "buffs.growth", "RIGHT_UP")
	check(buffs._flow.anchor == "BOTTOMLEFT" and buffs._flow.horizontal == 1 and buffs._flow.vertical == 1, "growth right, then up")
	local point, _, relPoint = buffs:GetPoint(1)
	check(point == "BOTTOMLEFT" and relPoint == "BOTTOMLEFT", "the container moves to the corner it grows from")

	K.Options.Write("Auras", "buffs.rows", 3)
	K.Options.Write("Auras", "buffs.columns", 8)
	check(bg.maxFrameCount == 24, "3 rows of 8")
	check(buffs._flow.lineSize >= 8 * 32 + 7 * 8 and buffs._flow.lineSize < 9 * 32 + 8 * 8, "eight icons per line")

	K.Options.Write("Auras", "buffs.cancel", false)
	check(groupButtons(bg)[1]._aura.cancel == nil, "right-click cancel can be turned off")
	K.Options.Write("Auras", "buffs.enchants", false)
	for _, enchant in pairs(buffs._enchants) do
		check(enchant.enabled == false, "weapon enchantments can be turned off")
	end

	K.Options.Write("Auras", "debuffs.dispel", false)
	check(#groupButtons(dg)[1]._aura.dispel == 0, "the dispel border can be turned off")
	K.Options.Write("Auras", "debuffs.dispel", true)
	check(#groupButtons(dg)[1]._aura.dispel == 9, "and on again, without adding a piece twice")

	K.Options.Write("Auras", "timer.format", "none")
	check(groupButtons(dg)[1]._aura.timer == nil, "a hidden timer is cleared from the engine")
	check(dg.layout.elementHeight == 38, "and takes no room under the icon")
	K.Options.Write("Auras", "timer.format", "long")
	local aura = groupButtons(dg)[1]._aura
	check(aura.timer, "the timer comes back")
	local formatter = aura.timerOptions.textFormatter
	check(formatter and formatter.name == "seconds", "the long format uses its own seconds formatter")
	local units = find(formatter.calls, function(call)
		return call.method == "SetDesiredUnitCount"
	end)
	check(units and units.args[1] == 2, "with two units")
	check(aura.timerOptions.textColor and #aura.timerOptions.textColor.curve.points == 2, "the timer turns red near the end")
	K.Options.Write("Auras", "timer.expiring", 0)
	check(groupButtons(dg)[1]._aura.timerOptions.textColor == nil, "the red warning can be turned off")
	K.Options.Write("Auras", "timer.format", "short")
	check(groupButtons(dg)[1]._aura.timerOptions.textFormatter == nil, "the short format is the engine's default formatter")

	K.Options.Write("Auras", "timer.size", 12)
	local timer = groupButtons(dg)[1]._aura.timer
	local _, fontSize, flags = timer:GetFont()
	check(fontSize == 12 and flags == "OUTLINE", "the timer font follows its settings")
	K.Options.Write("Auras", "count.outline", "NONE")
	local _, _, countFlags = groupButtons(dg)[1]._aura.count:GetFont()
	check(countFlags == "", "a stack count with no outline gets the soft shadow")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Weapon enchantments share the buff rows: an active one takes a buff's place.
do
	local env = start({ layout = true })
	local _, bg = A.Container(env, "HELPFUL")
	check(bg.maxFrameCount == 12, "no enchantment, 12 buffs")
	env._enchants[env.INVSLOT_MAINHAND] = { enchantID = 1, hasExpirationTime = true, remainingTimeMs = 60000 }
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	check(bg.maxFrameCount == 11, "a main-hand enchantment leaves 11 buffs, got " .. bg.maxFrameCount)
	env._enchants[env.INVSLOT_OFFHAND] = { enchantID = 2, hasExpirationTime = false, remainingTimeMs = 0 }
	env.FireEvent("WEAPON_SLOT_CHANGED")
	check(bg.maxFrameCount == 10, "two enchantments leave 10")
	env._enchants = {}
	env.FireEvent("WEAPON_ENCHANT_CHANGED")
	check(bg.maxFrameCount == 12, "expired enchantments give their places back")
end

-- A panel smaller than the enchantment slots shows only as many enchantments as it has places.
do
	local env, K = start({ layout = true })
	local buffs, bg = A.Container(env, "HELPFUL")
	env._enchants[env.INVSLOT_MAINHAND] = { enchantID = 1, hasExpirationTime = true, remainingTimeMs = 60000 }
	env._enchants[env.INVSLOT_OFFHAND] = { enchantID = 2, hasExpirationTime = true, remainingTimeMs = 60000 }
	K.Options.Write("Auras", "buffs.rows", 1)
	K.Options.Write("Auras", "buffs.columns", 1)
	local enabled = 0
	for _, enchant in pairs(buffs._enchants) do
		if enchant.enabled then
			enabled = enabled + 1
		end
	end
	check(enabled == 1, "one place, one enchantment slot, got " .. enabled)
	check(buffs._enchants[env.AuraContainerItemEnchantmentSlot.MainHand].enabled, "the main hand keeps its place")
	check(bg.maxFrameCount == 0, "and no buff fits beside it")
	K.Options.Write("Auras", "buffs.columns", 12)
	enabled = 0
	for _, enchant in pairs(buffs._enchants) do
		if enchant.enabled then
			enabled = enabled + 1
		end
	end
	check(enabled == 3 and bg.maxFrameCount == 10, "a wider panel takes every slot back, got " .. enabled .. " and " .. bg.maxFrameCount)
end

-- The secrecy gate: while aura data is secret, nothing touches an aura button; the change applies after.
do
	local env, K = start({ layout = true })
	local buffs, bg = A.Container(env, "HELPFUL")
	local before = A.CallCount(buffs)
	env._aurasSecret = true
	K.Options.Write("Auras", "buffs.iconSize", 30)
	K.Callbacks.Fire("ThemeChanged")
	K.Callbacks.Fire("ScaleChanged")
	K.Widgets.RestyleAll()
	check(#env._errors == 0, "no access errors while auras are secret: " .. tostring(env._errors[1]))
	check(bg.layout.elementWidth == 30, "the container's own layout updates at once")
	local touched = 0
	for _, button in ipairs(A.Buttons(buffs)) do
		for _, call in ipairs(button._calls) do
			if call.method == "SetSize" and call.args and call.args[1] == 30 then
				touched = touched + 1
			end
		end
	end
	check(touched == 0, "no aura button is resized while auras are secret")
	local during = A.CallCount(buffs)
	check(devlog(env, "waits"), "the wait is logged")

	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
	env.RunTimers()
	local bw = groupButtons(bg)[1]:GetSize()
	check(near(bw, 30), "the buttons resize once auras are no longer secret")
	check(A.CallCount(buffs) > during and during >= before, "the restyle ran after the gate opened")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Without C_Secrets the gate falls back to combat lockdown.
do
	local env, K = start({ layout = true })
	local _, bg = A.Container(env, "HELPFUL")
	env.C_Secrets = nil
	env.SetCombat(true)
	K.Options.Write("Auras", "buffs.iconSize", 20)
	check(near(groupButtons(bg)[1]:GetSize(), 38), "nothing is resized in combat")
	env.SetCombat(false)
	env.RunTimers()
	check(near(groupButtons(bg)[1]:GetSize(), 20), "the change lands when combat ends")
end

-- In combat the restyle waits too, even when aura data is not secret.
do
	local env, K = start({ layout = true })
	local _, bg = A.Container(env, "HELPFUL")
	env.SetCombat(true)
	K.Options.Write("Auras", "buffs.iconSize", 22)
	check(near(groupButtons(bg)[1]:GetSize(), 38), "nothing is resized in combat")
	env.SetCombat(false)
	env.RunTimers()
	check(near(groupButtons(bg)[1]:GetSize(), 22), "the change lands when combat ends")
end

-- The Appearance page's text size scales the timers and stack counts, and the room under the icons.
do
	local env, K = start({ layout = true })
	local _, bg = A.Container(env, "HELPFUL")
	check(K.Theme.SetFontScale(1.2), "the text size changes")
	K.Callbacks.Fire("ThemeChanged")
	local _, fontSize = groupButtons(bg)[1]._aura.timer:GetFont()
	check(near(fontSize, 12 * 1.2), "a 12-unit timer at a text size of 1.2 is 14.4 units, got " .. tostring(fontSize))
	check(near(bg.layout.elementHeight, 53), "the timer's room grows to 15.4 units, snapped to 15 at 1080, got " .. tostring(bg.layout.elementHeight))
end

-- Buttons the engine makes later, even while auras are secret, are styled before restrictions apply.
do
	local env = start({ layout = true })
	local debuffs, dg = A.Container(env, "HARMFUL")
	local initialize = assert(env._initializers and env._initializers[dg.key], "the fake engine keeps the group's initializeFrame")
	env._aurasSecret = true
	local button = A.MakeButton(env, debuffs, initialize)
	check(button._aura.icon and #button._aura.dispel == 9, "a late button gets the full style")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Disable: frames hide, Blizzard's frames come back, and enabling again reuses the containers.
do
	local env, K = start({ layout = true })
	local buffs = A.Container(env, "HELPFUL")
	local holder = registered(env, "auras.buffs").frame
	K.Modules.Disable("Auras")
	env.RunTimers()
	check(not holder:IsShown() and not buffs:GetParent():IsShown(), "the panel hides")
	check(env.BuffFrame:GetParent() == env.UIParent and env.DebuffFrame:GetParent() == env.UIParent, "Blizzard's frames come back")
	K.Modules.Enable("Auras")
	env.RunTimers()
	check(#A.Rows(env) == 4, "enabling again reuses the containers")
	check(holder:IsShown() and buffs:GetParent():IsShown(), "and shows them")
	check(A.Hidden(env, env.BuffFrame), "and hides Blizzard's frames again")
	K.Options.Write("Auras", "hideBlizzard", false)
	env.RunTimers()
	check(env.BuffFrame:GetParent() == env.UIParent, "the player can keep Blizzard's frames")
end

-- The host mirrors the Layout element: scale, alpha, strata and visibility.
do
	local env = start({ layout = true })
	local buffs = A.Container(env, "HELPFUL")
	local host = buffs:GetParent()
	local holder = registered(env, "auras.buffs").frame
	check(host:GetNumPoints() == 2, "the host covers the element, got " .. host:GetNumPoints() .. " points")
	local p1, r1, rp1 = host:GetPoint(1)
	local p2, r2, rp2 = host:GetPoint(2)
	-- The card's bottom follows its content (test-auras-card.lua), through an edge frame whose right edge is the holder's.
	local edge = r2
	check(p1 == "TOPLEFT" and r1 == holder and rp1 == "TOPLEFT" and p2 == "BOTTOMRIGHT" and rp2 == "BOTTOMRIGHT" and edge:GetParent() == host, "so a Layout move moves the auras")
	local ep, er, erp = edge:GetPoint(1)
	check(ep == "TOPRIGHT" and er == holder and erp == "TOPRIGHT", "the card's edge frame takes the holder's right edge, so the card keeps the element's width")
	holder:SetScale(1.5)
	holder:SetAlpha(0.4)
	holder:SetFrameStrata("HIGH")
	check(host:GetScale() == 1.5 and near(host:GetAlpha(), 0.4) and host:GetFrameStrata() == "HIGH", "the host follows the element")
	holder:Hide()
	check(not host:IsShown(), "and hides with it")
	holder:Show()
	check(host:IsShown(), "and shows with it")
	check(host:GetFrameLevel() > holder:GetFrameLevel(), "the aura buttons sit above the element, so they keep the mouse")
end

-- With the real Layout service, the mouseover rule never hooks an aura button.
do
	local env, K = start({})
	local buffs = A.Container(env, "HELPFUL")
	check(K.Layout.Get("auras.buffs"), "the element is registered with Layout")
	local ok, reason = K.Layout.Set("auras.buffs", "shown", "mouseover")
	check(ok, "the mouseover rule applies: " .. tostring(reason))
	for _, button in ipairs(A.Buttons(buffs)) do
		check(not find(button._calls, function(call)
			return call.method == "HookScript"
		end), "Layout never hooks an aura button")
	end
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Fallback: without the AuraContainer engine, Blizzard's frames stay and the path is logged.
do
	local env, K = start({ layout = true, engine = { noContainer = true } })
	check(K.Modules.IsRunning("Auras") and not K.Modules.HasFailed("Auras"), "the module still runs")
	check(#env._containers == 0, "no container")
	check(env.BuffFrame:GetParent() == env.UIParent, "Blizzard's buffs stay")
	check(devlog(env, "AuraContainer"), "the fallback is logged")
	check(registered(env, "auras.buffs") == nil and registered(env, "auras.debuffs") == nil, "nothing empty is placed on screen")
end

-- The preview builds kit icons that follow the settings.
do
	local env, K = A.New({ layout = true })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(248, 300)
	local preview = K.Options.Preview("Auras")(parent)
	check(type(preview) == "table" and type(preview.Refresh) == "function", "the preview is a frame with Refresh")
	check(#preview.buffs > 0 and #preview.debuffs > 0, "it shows sample buffs and debuffs")
	K.Options.Write("Auras", "buffs.iconSize", 40)
	preview:Refresh()
	local w = preview.buffs[1].button:GetSize()
	check(near(w, 40), "sample buffs take the icon size")
	K.Options.Write("Auras", "accent.source", "custom")
	K.Options.Write("Auras", "accent.color", { r = 0.25, g = 0.5, b = 0.75 })
	preview:Refresh()
	K.Widgets.RestyleAll()
	local edge = preview.buffs[1].button.chrome.edge
	local nr, ng, nb = K.Widgets.MixTokens("edgeInner", 1, "textHover", 1, 0.15)
	check(near(edge[1], nr) and near(edge[2], ng) and near(edge[3], nb), "sample buffs keep the neutral rim (the rim light, lifted as every icon rim) whatever the accent")
	edge = preview.debuffs[1].button.chrome.edge
	local hr, hg, hb = K.Widgets.MixTokens("hostile", 1, "textHover", 1, 0.15)
	check(near(edge[1], hr) and near(edge[2], hg) and near(edge[3], hb), "sample debuffs draw theirs in the hostile colour")
	K.Options.Write("Auras", "timer.format", "long")
	preview:Refresh()
	check(preview.buffs[1].timer:GetText():find(" ", 1, true) or preview.buffs[1].timer:GetText():match("s$"), "sample timers use the format")
	check(#env._containers == 0, "the preview never builds an aura container")
	check(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
end

-- The real settings window builds the Auras page, its rows and its preview without errors.
do
	local O = dofile("Tools/regression/options_env.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local env, K = A.New({
		layout = true,
		setup = function(env)
			env.C_AddOns = {
				LoadAddOn = function(name)
					if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then
						Load(O.Files(), env)
					end
					return true
				end,
			}
		end,
	})
	K.Modules.Enable("Auras")
	env.RunTimers()
	K.Options.Open("Auras")
	env.RunTimers()
	local options = env._addons.KstyleUI_Options
	check(options and options.Pages, "the settings addon loaded")
	local page = find(options.Pages.List(), function(item)
		return item.module == "Auras"
	end)
	check(page, "the Auras page is listed")
	check(#env._errors == 0, "no errors opening the Auras page: " .. tostring(env._errors[1]))
	local preview = find(env._frames, function(frame)
		return type(rawget(frame, "buffs")) == "table" and type(rawget(frame, "Refresh")) == "function"
	end)
	check(preview and preview:IsShown(), "the page shows the Auras preview")
	check(not devlog(env, "preview for Auras"), "the preview built a frame")
end

print("auras ok")
