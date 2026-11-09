-- test-auras-rows.lua: the player's buffs and debuffs as plain icon rows (owner pass 1, 2026-11-09): no card, cap, gem, rule, flyout or "+00" chip; two bare elements under the minimap that grow left, then down; each tile a masked icon in a thin rim with its timer under it in the body face and its stack count on a corner badge the engine shows only past one application; a "+N" socket on the last cell, counted by the engine; dispel rims on debuffs; and the buffs the Cooldown Manager already tracks left out of the row through the engine's own spell filter.
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

-- The model: 30-unit icons, six apart, eight to a row, two rows of buffs and two of debuffs, growing left then
-- down; the timer in the body face under each icon, so an element is 30 by 42 and a row block 282 by 88.
check(buffs.iconSize == 30 and buffs.spacing == 6 and buffs.rowSpacing == 4 and buffs.columns == 8 and buffs.rows == 2, "the buff rows default to two rows of eight 30-unit icons, 6 apart")
check(debuffs.iconSize == 30 and debuffs.columns == 8 and debuffs.rows == 2, "and the debuffs the same")
check(buffs.growth == "LEFT_DOWN" and debuffs.growth == "LEFT_DOWN", "both rows grow left, then down")
check(timer.font == (Tokens.Font("body")) and timer.size == 11 and timer.outline == "NONE", "the timer is the body face at 11 with a soft shadow")
local w, h = Model.ElementSize(buffs, timer)
check(w == 30 and h == 42, "an element is the icon plus the timer lane: 30 x 42, got " .. w .. " x " .. h)
local fw, fh = Model.Footprint(buffs, timer)
check(fw == 282 and fh == 88, "the buff footprint is 282 x 88, got " .. fw .. " x " .. fh)
check(Model.Card == nil and Model.MORE == nil and Model.Docked == nil and Model.CARD_PAD == nil, "the card, its full list and its dock are gone from the model")
check(Model.defaults.card == nil and debuffs.dispelFirst == nil, "no card setting and no dispellable-first split: one group, one cap, one count")
check(Model.Capacity(buffs, 0) == 16, "two rows of eight hold sixteen buffs")
check(buffs.tracked == "cdm", "buffs the Cooldown Manager tracks show there only, by default")

-- Two bare elements: no card parts on either host, the debuff row its own live element, both at the footprint.
check(desc and desc.card == nil and desc.dock == nil and ddesc.dock == nil and ddesc.docked == nil, "no card, no dock")
for _, name in ipairs({ "cardShape", "ringLine6", "lumenShadow", "gem" }) do
	check(#textures(desc.host, (Tokens.Texture(name))) == 0, "the buff host draws no " .. name .. ": no card fill, no ring, no gilt, no gem")
end
local b, d = registered(env, "auras.buffs"), registered(env, "auras.debuffs")
check(b and d, "both elements register with Layout")
check(env._live["auras.debuffs"] ~= false, "the debuff row is live in Layout Mode: its own mover plate")
check(Layouts.Dock("auras.debuffs") == nil, "the layouts dock nothing into the buffs")
local bw, bh = b.frame:GetSize()
check(near(bw, 282) and near(bh, 88), "the buff element is its rows: 282 x 88, got " .. tostring(bw) .. " x " .. tostring(bh))
local dw, dh = d.frame:GetSize()
check(near(dw, 282) and near(dh, 88), "the debuff element is its rows: 282 x 88, got " .. tostring(dw) .. " x " .. tostring(dh))
local element = Layouts.Element("auras.buffs")
check(element.width == 282 and element.height == 88 and element.reserve == nil and Layouts.Element("auras.debuffs").reserve == nil, "the layouts plan the rows at their footprint, no reserve")
check(element.short == K.L["Auras"], "the setup preview names the block Auras (short in every language), not Blessings")
-- Beside the minimap's left edge, as the owner asked: top-aligned with the map, 16 left of it, growing towards the
-- screen's centre; the debuffs a gap under the buffs.
local map = Layouts.Element("minimap.main")
local margin = Tokens.Size("screenMargin")
check(b.position.anchor == "TOPRIGHT" and b.position.x == -(margin + map.width + 16) and b.position.y == -margin, "the buffs stand 16 left of the minimap, top-aligned with it, got " .. tostring(b.position.x) .. ", " .. tostring(b.position.y))
check(d.position.anchor == "TOPRIGHT" and d.position.x == b.position.x and d.position.y == -(margin + 88 + 16), "the debuffs hang 16 under the buffs, got " .. tostring(d.position.y))
for _, name in ipairs(Layouts.Names()) do
	for _, entry in ipairs(Layouts.Settings(name)) do
		check(entry.module ~= "Auras", name .. " writes no Auras setting: the rows are the same in every layout")
	end
end
-- The container hangs from the host's top right corner, the corner the rows grow from, so the first buff sits
-- under the minimap's right edge and the row fills leftwards.
local point, rel, relPoint = helpful:GetPoint(1)
check(point == "TOPRIGHT" and rel == desc.host and relPoint == "TOPRIGHT", "the buff container hangs from the host's top right corner, got " .. tostring(point) .. " on " .. tostring(rel == desc.host))
check(helpful._flow.anchor == "TOPRIGHT" and helpful._flow.horizontal == -1 and helpful._flow.vertical == -1, "the flow grows left, then down")
check(bg.layout.elementWidth == 30 and bg.layout.elementHeight == 42 and bg.layout.elementSpacing == 6 and bg.layout.lineSpacing == 4, "the engine lays 30 x 42 elements 6 apart in rows 4 apart")
check(bg.maxFrameCount == 16 and dg.maxFrameCount == 16, "sixteen buffs and sixteen debuffs at most")
check(#harmful._order == 1 and harmful._groups.debuffs and harmful._groups.debuffs.candidateFilters == nil, "the debuff container runs one group with no dispel split")

-- A tile: the icon under the socket mask, inset one border inside a thin rim plate in the edge colour (hostile on
-- debuffs, under the engine's dispel plate), no body, no bezel, no shadow; the timer under the icon in the body face;
-- the stack count on a corner badge that is a StatusBar the engine shows only from two applications.
local entry = desc.buttons[1]
check(entry and entry.chrome == nil, "a buff tile has no icon chrome")
local chamfer = (Tokens.Texture("chamferTile"))
local plates = textures(entry.skin, chamfer)
check(#plates == 9, "a buff tile carries one nine-piece rim plate, got " .. #plates)
local er, eg, eb = Tokens.Color("edgeInner")
local fr, fg, fb = Tokens.Color("buttonFill")
for _, plate in ipairs(plates) do
	check(sameRGB(plate, er, eg, eb) and plate:IsShown(), "the rim is the quiet edge colour")
	check(not sameRGB(plate, fr, fg, fb), "and never the button body")
end
local _, _, _, ra = plates[1]:GetVertexColor()
check(ra <= 0.6, "the rim rests at half strength: " .. tostring(ra))
local ip = entry.icon._points[1]
check(ip and ip[1] == "TOPLEFT" and ip[2] == entry.skin and near(ip[4], Widgets.Border(entry.skin)), "the icon sits one border inside the rim")
check(entry.mask and entry.icon._masks and entry.icon._masks[1] == entry.mask, "the icon wears the socket mask")
local path, size, flags = entry.timer:GetFont()
check(path == (Tokens.Font("body")) and size == 11 and flags == "", "the timer is the body face, 11 units, no outline")
local sx, sy = entry.timer:GetShadowOffset()
check(sx > 0 and sy < 0, "with a soft shadow")
local tp = entry.timer._points[1]
check(tp[1] == "TOP" and tp[2] == entry.skin and tp[3] == "BOTTOM", "the timer hangs under the icon")
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
local dplates = textures(dentry.skin, chamfer)
check(#dplates == 9 and dentry.dispel and #dentry.dispel == 9, "a debuff tile shows its rim plate; the engine's dispel plate waits hidden for a type, got " .. #dplates)
local hr, hg, hb = Tokens.Color("hostile")
for _, plate in ipairs(dplates) do
	check(sameRGB(plate, hr, hg, hb), "its own rim is the hostile colour")
end
check(#dg.frames[1]._aura.dispel == 9 and dg.frames[1]._aura.dispel[1].texture == dentry.dispel[1], "the dispel plate is the engine's")

-- The "+N" socket: one counting pair per row, on the row's own filter and cap, its window on the last cell (the
-- bottom left for rows growing left then down) covering the tile and its timer lane, so the covered aura's timer
-- never reads as the count's. No "+00" is reserved anywhere.
local chip = desc.chip
check(chip and #chip.pairs == 1 and chip.pairs[1].a._groups.count.filter == "HELPFUL", "the buff row counts its own filter")
check(chip.pairs[1].a._groups.count.maxFrameCount > 16, "and can count past the rows")
check(ddesc.chip and #ddesc.chip.pairs == 1 and ddesc.chip.pairs[1].a._groups.count.filter == "HARMFUL", "the debuff row counts its own")
local host = rect(desc.host)
local window = rect(chip.window)
check(near(window.left, host.left) and near(window.bottom, host.bottom) and near(window.right - window.left, 30) and near(window.top - window.bottom, 42), "the count window is the last cell: 30 wide, 42 tall, at the host's bottom left corner")
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
check(count(chip) == "+9", "24 buffs: the last cell reads +9, the covered one and the eight past the rows, got " .. tostring(count(chip)))
A.Ghosts(chip, { 40 })
check(count(chip) == "+25", "40 buffs: +25, got " .. tostring(count(chip)))
A.Ghosts(ddesc.chip, { 12 })
check(count(ddesc.chip) == nil, "twelve debuffs fit the two rows")
A.Ghosts(ddesc.chip, { 20 })
check(count(ddesc.chip) == "+5", "twenty debuffs: +5, got " .. tostring(count(ddesc.chip)))
-- The count follows the enchantment slots: an active weapon enchantment takes one cell.
env._enchants[env.INVSLOT_MAINHAND] = { enchantID = 1, hasExpirationTime = true, remainingTimeMs = 60000 }
env.FireEvent("WEAPON_ENCHANT_CHANGED")
check(chip.cap == 15 and chip.pairs[1].b == nil, "with an enchantment the buff cap is fifteen")
env._enchants = {}
env.FireEvent("WEAPON_ENCHANT_CHANGED")
check(chip.cap == 16, "and sixteen again without")

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
