-- test-auras-rows.lua: the player's buffs and debuffs as plain icon rows (owner pass 1, 2026-11-09; the picture's one row of ten, the owner's ruling "let the picture win", LEE-20): no card, cap, gem, rule, flyout or "+00" chip; two bare elements beside the minimap that list the first aura at the left; each tile a square icon in a one-pixel dark rim with its timer under it in white in the body face and its stack count on a corner badge the engine shows only past one application; a "+N" socket on the last cell, counted by the engine; dispel plates on debuffs; and the buffs the Cooldown Manager already tracks left out of the row through the engine's own spell filter.
local A = dofile("Tools/regression/auras_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.5)
end

local function registered(env, key)
	for _, entry in ipairs(env._layout) do
		if entry.key == key then
			return entry
		end
	end
end

local function textures(frame, path)
	local out = {}
	for _, object in ipairs(A.Descendants(frame)) do
		local set = object._state and object._state.Texture and object._state.Texture[1]
		if object.GetObjectType and object:GetObjectType() == "Texture" and set == path and object:IsShown() then
			out[#out + 1] = object
		end
	end
	return out
end

local function sameRGB(region, r, g, b)
	local cr, cg, cb = region:GetVertexColor()
	return near(cr, r, 1e-3) and near(cg, g, 1e-3) and near(cb, b, 1e-3)
end

local env, K, ns = A.New({ layout = true })
env._tracked[501] = { spellID = 1001 }
env._tracked[502] = { spellID = 1002, overrideSpellID = 2002, linkedSpellIDs = { 3002 } }
env._tracked[503] = { spellID = 1003, category = env.Enum.CooldownViewerCategory.Essential }
K.Modules.Enable("Auras")
env.RunTimers()
local Model, Panel = ns.Model, ns.Panel
local Widgets, Tokens = K.Widgets, K.Tokens
local settings = K.Store.Module("Auras")
local buffs, debuffs = Model.Group(settings, "buffs"), Model.Group(settings, "debuffs")
local timer = Model.Timer(settings)
local root = K.Scale.Root()
local desc, ddesc = Panel.Group("buffs"), Panel.Group("debuffs")
local helpful, bg = A.Container(env, "HELPFUL")
local harmful, dg = A.Container(env, "HARMFUL")
local Layouts = K.Setup.Layouts

local function rect(object)
	local r, why = Geometry.Rect(object, root)
	check(r, tostring(why))
	return r
end

-- The model: 27.5-unit icons (the picture's 48 px), 3.5 apart (its 54 px pitch), ten to one row of buffs and one of
-- debuffs, the first aura at the left; the timer in the body face under each icon, so an element is 27.5 by 41.5 and a
-- row 306.5 by 41.5.
check(buffs.iconSize == 27.5 and buffs.spacing == 3.5 and buffs.rowSpacing == 4 and buffs.columns == 10 and buffs.rows == 1, "the buff row defaults to one row of ten 27.5-unit icons, 3.5 apart")
check(debuffs.iconSize == 27.5 and debuffs.columns == 10 and debuffs.rows == 1, "and the debuffs the same")
check(buffs.growth == "RIGHT_DOWN" and debuffs.growth == "RIGHT_DOWN", "both rows list the first aura at the left")
check(timer.font == (Tokens.Font("timer")) and timer.size == 11 and timer.outline == "NONE", "the timer is the medium face at 11 with a soft shadow, as the picture draws it")
local w, h = Model.ElementSize(buffs, timer)
check(w == 27.5 and h == 41.5, "an element is the icon plus the timer lane: 27.5 x 41.5, got " .. w .. " x " .. h)
local fw, fh = Model.Footprint(buffs, timer)
check(fw == 306.5 and fh == 41.5, "the buff footprint is 306.5 x 41.5, got " .. fw .. " x " .. fh)
check(Model.Card == nil and Model.MORE == nil and Model.Docked == nil and Model.CARD_PAD == nil, "the card, its full list and its dock are gone from the model")
check(Model.defaults.card == nil and debuffs.dispelFirst == nil, "no card setting and no dispellable-first split: one group, one cap, one count")
check(Model.Capacity(buffs, 0) == 10, "one row of ten holds ten buffs")
check(buffs.tracked == "cdm", "buffs the Cooldown Manager tracks show there only, by default")

-- Two bare elements: no card parts on either host, the debuff row its own live element, both at the footprint.
check(desc and desc.card == nil and desc.dock == nil and ddesc.dock == nil and ddesc.docked == nil, "no card, no dock")
for _, name in ipairs({ "cardShape", "ringLine6", "lumenShadow", "diamond" }) do
	check(#textures(desc.host, (Tokens.Texture(name))) == 0, "the buff host draws no " .. name .. ": no card fill, no ring, no gilt, no gem")
end
local b, d = registered(env, "auras.buffs"), registered(env, "auras.debuffs")
check(b and d, "both elements register with Layout")
check(env._live["auras.debuffs"] ~= false, "the debuff row is live in Layout Mode: its own mover plate")
check(Layouts.Dock("auras.debuffs") == nil, "the layouts dock nothing into the buffs")
local bw, bh = b.frame:GetSize()
local sw, sh = Model.Footprint(buffs, timer, K.Scale.Snap)
check(near(bw, sw) and near(bh, sh), "the buff element is its row: 306.5 x 41.5 in units, whole pixels at this size, got " .. tostring(bw) .. " x " .. tostring(bh))
local dw, dh = d.frame:GetSize()
check(near(dw, sw) and near(dh, sh), "the debuff element is its row: 306.5 x 41.5 in units, whole pixels at this size, got " .. tostring(dw) .. " x " .. tostring(dh))
local element = Layouts.Element("auras.buffs")
check(element.width == 306.5 and element.height == 41.5 and element.reserve == nil and Layouts.Element("auras.debuffs").reserve == nil, "the layouts plan the rows at their footprint, no reserve")
check(element.short == K.L["Auras"], "the setup preview names the block Auras (short in every language), not Blessings")
-- Beside the minimap's left edge, as the picture draws it: 11.9 left of the map's square, which stands its card's frame in
-- from the card margin (KSTY-60 item 28), and 1.4 under the screen margin
-- (its 32 px from the top); the debuffs 8 under the buffs, their right ends at the same x.
local map, margin = Layouts.Element("minimap.main"), Tokens.Size("screenMargin")
check(b.position.anchor == "TOPRIGHT" and near(b.position.x, -(margin + Layouts.MAP_FRAME + map.width + 11.9)) and near(b.position.y, -(margin + 1.4)), "the buffs stand 11.9 left of the map's square and 1.4 under the screen margin, got " .. tostring(b.position.x) .. ", " .. tostring(b.position.y))
check(d.position.anchor == "TOPRIGHT" and d.position.x == b.position.x and near(d.position.y, -(margin + 1.4 + 41.5 + 8)), "the debuffs hang 8 under the buffs, got " .. tostring(d.position.y))
for _, name in ipairs(Layouts.Names()) do
	for _, entry in ipairs(Layouts.Settings(name)) do
		check(entry.module ~= "Auras", name .. " writes no Auras setting: the rows are the same in every layout")
	end
end
-- The container hangs from the host's top right corner, so the row ends at the element's right edge whatever it holds,
-- and its flow starts at the container's top left, so the first buff stands at the left.
local point, rel, relPoint = helpful:GetPoint(1)
check(point == "TOPRIGHT" and rel == desc.host and relPoint == "TOPRIGHT", "the buff container hangs from the host's top right corner, got " .. tostring(point) .. " on " .. tostring(rel == desc.host))
check(helpful._flow.anchor == "TOPLEFT" and helpful._flow.horizontal == 1 and helpful._flow.vertical == -1, "the flow lists left to right, then down")
check(bg.layout.elementWidth == K.Scale.Snap(27.5) and bg.layout.elementHeight == K.Scale.Snap(27.5) + 14 and bg.layout.elementSpacing == K.Scale.Snap(31) - K.Scale.Snap(27.5) and bg.layout.lineSpacing == 4, "the engine lays 27.5 x 41.5 elements on one 31-unit pitch of whole pixels (so the row never outgrows the layout's reserve), in rows 4 apart")
check(bg.maxFrameCount == 10 and dg.maxFrameCount == 10, "ten buffs and ten debuffs at most")
check(#harmful._order == 1 and harmful._groups.debuffs and harmful._groups.debuffs.candidateFilters == nil, "the debuff container runs one group with no dispel split")

-- A tile: the icon, inset one border inside a square rim plate in the dark edge colour (under the engine's dispel
-- plate on debuffs), no mask, no chamfer, no body, no bezel, no shadow; the timer under the icon in white in the body face;
-- the stack count on a corner badge that is a StatusBar the engine shows only from two applications.
local entry = desc.buttons[1]
check(entry and entry.chrome == nil, "a buff tile has no icon chrome")
local chamfer = (Tokens.Texture("chamferTile"))
check(#textures(entry.skin, chamfer) == 0, "a tile draws no chamfered plate: its corners are square")
check(#entry.rim == 1 and entry.rim[1]:GetParent() == entry.skin and entry.rim[1]:IsShown(), "a buff tile carries one square rim plate")
local rp = entry.rim[1]._points
check(#rp == 2 and rp[1][2] == entry.skin and rp[2][2] == entry.skin, "covering the whole tile, so the icon one border inside leaves a one-pixel ring")
local er, eg, eb = Tokens.Color("black")
local fr, fg, fb = Tokens.Color("buttonFill")
check(sameRGB(entry.rim[1], er, eg, eb), "the rim is the dark edge colour")
check(not sameRGB(entry.rim[1], fr, fg, fb), "and never the button body")
local _, _, _, ra = entry.rim[1]:GetVertexColor()
check(ra == 1, "at full strength: " .. tostring(ra))
local ip = entry.icon._points[1]
check(ip and ip[1] == "TOPLEFT" and ip[2] == entry.skin and near(ip[4], Widgets.Border(entry.skin)), "the icon sits one border inside the rim")
check(entry.mask == nil and not (entry.icon._masks and entry.icon._masks[1]), "the icon wears no mask: it is a square")
local path, size, flags = entry.timer:GetFont()
check(path == (Tokens.Font("timer")) and size == 11 and flags == "", "the timer is the medium face, 11 units, no outline")
local wr, wg, wb = Tokens.Color("timerText")
local tr, tg, tb = entry.timer:GetTextColor()
check(near(tr, wr, 1e-3) and near(tg, wg, 1e-3) and near(tb, wb, 1e-3), "and the picture's soft grey-white, not pure white")
local sx, sy = entry.timer:GetShadowOffset()
check(sx > 0 and sy < 0, "with a soft shadow")
local tp = entry.timer._points[1]
check(tp[1] == "TOP" and tp[2] == entry.skin and tp[3] == "BOTTOM", "the timer hangs under the icon")
check(near(-tp[5], Widgets.Snap(entry.skin, Model.TIMER_GAP - 0.5), 1e-3) and Model.TIMER_GAP + size == 14, "the timer is lifted half a root unit inside its unchanged 14-unit lane")
check(tp[4] == 0, "the medium timer is centred on the icon, without the old two-pixel right shift")
check(entry.badge and entry.badge:GetObjectType() == "StatusBar", "the stack badge is a StatusBar the engine can show and hide")
local aura = bg.frames[1]._aura
check(aura.bar == entry.badge and aura.barOptions.minApplications == 2 and type(aura.barOptions.maxApplications) == "number", "the engine shows the badge from two applications")
check(aura.count == entry.count, "and writes the count on the badge's text")
local bp = entry.badge._points[1]
check(bp and bp[2] == entry.count, "the badge wraps the count text")
local cp = entry.count._points[1]
check(cp[1] == "TOPRIGHT" and cp[2] == entry.skin, "in the icon's top right corner")
check(entry.plate and entry.plate:GetParent() == entry.badge, "the badge plate draws on the bar, so it goes with it")
local dentry = ddesc.buttons[1]
check(#dentry.rim == 1 and dentry.rim[1]:IsShown() and dentry.dispel and #dentry.dispel == 1 and not dentry.dispel[1]:IsShown(), "a debuff tile shows its rim plate; the engine's dispel plate waits hidden for a type")
check(sameRGB(dentry.rim[1], er, eg, eb), "its own rim is the same dark edge")
check(#dg.frames[1]._aura.dispel == 1 and dg.frames[1]._aura.dispel[1].texture == dentry.dispel[1], "the dispel plate is the engine's")

-- The "+N" socket: one counting pair per row, on the row's own filter and cap, its window on the last cell (the
-- bottom right for a row listed left to right, hung from the right) covering the tile and its timer lane, so the covered aura's timer
-- never reads as the count's. No "+00" is reserved anywhere.
local chip = desc.chip
check(chip and #chip.pairs == 1 and chip.pairs[1].a._groups.count.filter == "HELPFUL", "the buff row counts its own filter")
check(chip.pairs[1].a._groups.count.maxFrameCount > 10, "and can count past the row")
check(ddesc.chip and #ddesc.chip.pairs == 1 and ddesc.chip.pairs[1].a._groups.count.filter == "HARMFUL", "the debuff row counts its own")
local host = rect(desc.host)
local window = rect(chip.window)
check(near(window.right, host.right) and near(window.bottom, host.bottom) and near(window.right - window.left, K.Scale.Snap(27.5)) and near(window.top - window.bottom, K.Scale.Snap(27.5) + 14), "the count window is the last cell: 27.5 wide, 41.5 tall (whole pixels at this size), at the host's bottom right corner")
for _, object in ipairs(A.Descendants(desc.host)) do
	if object.GetObjectType and object:GetObjectType() == "FontString" and object:IsShown() then
		check(object:GetText() ~= "+00", "no shown text reads +00")
	end
end
local function count(c)
	return (A.Chip(c))
end
for _, n in ipairs({ 0, 2, 8 }) do
	A.Ghosts(chip, { n })
	check(count(chip) == nil, n .. " buffs fit: no count, got " .. tostring(count(chip)))
end
A.Ghosts(chip, { 24 })
check(count(chip) == "+15", "24 buffs: the last cell reads +15, the covered one and the fourteen past the row, got " .. tostring(count(chip)))
A.Ghosts(chip, { 40 })
check(count(chip) == "+31", "40 buffs: +31, got " .. tostring(count(chip)))
A.Ghosts(ddesc.chip, { 12 })
check(count(ddesc.chip) == "+3", "twelve debuffs: the last cell reads +3, got " .. tostring(count(ddesc.chip)))
A.Ghosts(ddesc.chip, { 10 })
check(count(ddesc.chip) == nil, "ten debuffs fit the row")
A.Ghosts(ddesc.chip, { 20 })
check(count(ddesc.chip) == "+11", "twenty debuffs: +11, got " .. tostring(count(ddesc.chip)))
-- The count follows the enchantment slots: an active weapon enchantment takes one cell.
env._enchants[env.INVSLOT_MAINHAND] = { enchantID = 1, hasExpirationTime = true, remainingTimeMs = 60000 }
env.FireEvent("WEAPON_ENCHANT_CHANGED")
env.RunTimers()
check(chip.cap == 9 and chip.pairs[1].b == nil, "with an enchantment the buff cap is nine")
env._enchants = {}
env.FireEvent("WEAPON_ENCHANT_CHANGED")
env.RunTimers()
check(chip.cap == 10, "and ten again without")

-- Tracked buffs: the Cooldown Manager's tracked-buff category, read from C_CooldownViewer out of the secure
-- engine, becomes the buff group's excludeSpellIDs candidate filter (base, override and linked spells), on the
-- row and on its count. "Here as well" and a switched-off viewer drop the filter.
local candidates = bg.candidateFilters
check(candidates and candidates.excludeSpellIDs, "the buff group carries an exclude filter")
for _, id in ipairs({ 1001, 1002, 2002, 3002 }) do
	check(candidates.excludeSpellIDs[id] == true, "spell " .. id .. " of a tracked buff is left out of the row")
end
check(candidates.excludeSpellIDs[1003] == nil, "an essential cooldown is not a tracked buff")
check(chip.pairs[1].a._groups.count.candidateFilters.excludeSpellIDs[1001] == true, "the count leaves them out too")
env._tracked[504] = { spellID = 1004 }
env.FireEvent("COOLDOWN_VIEWER_DATA_LOADED")
check(bg.candidateFilters.excludeSpellIDs[1004] == true, "a tracked buff gained reaches the filter on COOLDOWN_VIEWER_DATA_LOADED")
env._tracked[505] = { spellID = env.Secret(1005) }
env.FireEvent("COOLDOWN_VIEWER_DATA_LOADED")
local secret = false
for id in pairs(bg.candidateFilters.excludeSpellIDs) do
	if env.issecretvalue(id) then
		secret = true
	end
end
check(not secret and bg.candidateFilters.excludeSpellIDs[1004] == true, "a secret spell id is skipped, never a table key")
env._cvars.cooldownViewerEnabled = "0"
env.FireEvent("CVAR_UPDATE", "cooldownViewerEnabled", "0")
check(bg.candidateFilters == nil, "with the Cooldown Manager off the row shows every buff")
env._cvars.cooldownViewerEnabled = "1"
env.FireEvent("CVAR_UPDATE", "cooldownViewerEnabled", "1")
check(bg.candidateFilters and bg.candidateFilters.excludeSpellIDs[1001], "and leaves the tracked ones out again when it comes back")
K.Options.Write("Auras", "buffs.tracked", "both")
env.RunTimers()
check(bg.candidateFilters == nil and chip.pairs[1].a._groups.count.candidateFilters == nil, "Here as well: no filter on the row or its count")
K.Options.Write("Auras", "buffs.tracked", "cdm")
env.RunTimers()
check(bg.candidateFilters and bg.candidateFilters.excludeSpellIDs[1001], "and back")
-- The player's own Cooldown Manager layout wins over the default set (codex review): a tracked buff the player
-- removed from the viewer, or moved to another category, shows in the row; a cooldown the default set hides
-- (HideByDefault) or the player has not learned is never excluded; the layout's changes reach the filter through
-- CooldownViewerSettings.OnDataChanged.
env._tracked[506] = { spellID = 1006, flags = env.Enum.CooldownSetSpellFlags.HideByDefault }
env._tracked[507] = { spellID = 1007, isKnown = false }
env.FireEvent("COOLDOWN_VIEWER_DATA_LOADED")
check(bg.candidateFilters.excludeSpellIDs[1006] == nil and bg.candidateFilters.excludeSpellIDs[1007] == nil, "a hidden-by-default or unlearned cooldown is not excluded")
env._cdmLayout = { [501] = false, [502] = env.Enum.CooldownViewerCategory.Essential, [506] = env.Enum.CooldownViewerCategory.TrackedBuff }
A.Trigger(env, "CooldownViewerSettings.OnDataChanged")
local filter = bg.candidateFilters and bg.candidateFilters.excludeSpellIDs
check(filter and filter[1001] == nil and filter[1002] == nil and filter[2002] == nil, "a tracked buff the player removed or moved shows in the row")
check(filter[1004] == true and filter[1006] == true, "the buffs the player's layout tracks are left out, a hidden-by-default one the player added too")
env._cdmLayout = nil
env._cdmDirty = true
A.Trigger(env, "CooldownViewerSettings.OnDataChanged")
check(bg.candidateFilters == nil and chip.pairs[1].a._groups.count.candidateFilters == nil, "without a clean layout the row and its count keep every buff")
env._cdmDirty = false
A.Trigger(env, "CooldownViewerSettings.OnDataChanged")
check(bg.candidateFilters.excludeSpellIDs[1001] == true, "a clean effective default layout restores the filter")
-- The viewer's own visibility: hidden or in-combat-only in Edit Mode, the tracked row is not a place the buff
-- shows, so the row keeps every buff (codex review).
env.BuffIconCooldownViewer.visibleSetting = env.Enum.CooldownViewerVisibleSetting.Hidden
A.Trigger(env, "EditMode.Exit")
check(bg.candidateFilters == nil, "with the tracked-buff viewer hidden the row shows every buff")
env.BuffIconCooldownViewer.visibleSetting = env.Enum.CooldownViewerVisibleSetting.InCombat
A.Trigger(env, "EditMode.Exit")
check(bg.candidateFilters == nil, "an in-combat-only viewer leaves the buffs out of combat with no place: the row shows them")
env.BuffIconCooldownViewer.visibleSetting = env.Enum.CooldownViewerVisibleSetting.Always
A.Trigger(env, "EditMode.Exit")
check(bg.candidateFilters and bg.candidateFilters.excludeSpellIDs[1001], "shown always, the filter returns")
check(K.Options.Row("Auras", "buffs.tracked") and K.Options.Row("Auras", "buffs.tracked").type == "dropdown", "the choice is a dropdown on the Auras page")
check(K.Options.Row("Auras", "card.docked") == nil and K.Options.Row("Auras", "debuffs.dispelFirst") == nil, "the card and dispellable-first rows are gone")

-- The host follows the holder, the element Layout owns, corner to corner.
local p1, r1 = desc.host:GetPoint(1)
local p2, r2 = desc.host:GetPoint(2)
check(p1 == "TOPLEFT" and r1 == desc.holder and p2 == "BOTTOMRIGHT" and r2 == desc.holder, "the host covers the holder")
check(desc.host:GetFrameLevel() > desc.holder:GetFrameLevel(), "above it, so the aura buttons keep the mouse")

check(#env._errors == 0, tostring(env._errors[1]))
check(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("auras rows ok")
