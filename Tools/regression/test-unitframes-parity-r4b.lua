-- test-unitframes-parity-r4b.lua: parity round 4b keeps v0.2.8 frames and makes nothing new, then turns on, probes after events and turns off idle cast bars, spell icon size, out-of-range grey, the player's dispel overlay, edge, type icon and own colours, totem timers and shared spell ID lists, and checks the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {} },
	setup = function(e)
		e._inRange = true
		e.C_Spell.IsSpellInRange = function(spellID)
			assert(spellID == 116, "the range check asks about the spell being cast")
			return e._inRange
		end
		e._recasts = 2
		e.C_TradeSkillUI = { GetRemainingRecasts = function() return e._recasts end }
		local casting = e.UnitCastingInfo
		e.UnitCastingInfo = function(token)
			local r = { casting(token) }
			if e._trade and r[1] ~= nil then r[6] = true end
			return unpack(r, 1, 11)
		end
		e._totems = {}
		e.GetNumTotemSlots = function() return 4 end
		e.GetTotemInfo = function(slot)
			local t = e._totems[slot]
			if not t then return false, "", 0, 0, 0, 1, 0 end
			return t.have, t.name, t.start, t.duration, t.icon, 1, t.spellID
		end
		e.GetTotemDuration = function(slot)
			local t = e._totems[slot]
			return t and { totem = slot } or nil
		end
	end,
})
local Settings, Frames = ns.Settings, ns.Frames

local function clean(where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
	assert(type(value) == "table" or K.Options.Read("UnitFrames", key) == value, key .. " must round-trip")
end

local function keys(schema)
	local out = {}
	for _, row in ipairs(schema) do
		if row.key then out[row.key] = row end
	end
	return out
end

-- A v0.2.8-shaped profile keeps today's settings and makes no dispel container or totem row.
local PLAYER = { castbarRangeGrey = false, dispelOverlay = "", dispelFilter = "PLAYER", dispelAlpha = 0.3, dispelEdge = false, dispelIcon = "", dispelIconSize = 14,
	totems = false, totemPosition = "ABOVE", totemSize = 24 }
for key, value in pairs(PLAYER) do
	assert(Settings.Value("player", key) == value, "player." .. key .. " keeps its default")
end
for _, kind in ipairs(U.KINDS) do
	assert(Settings.Value(kind, "castbarIconSize") == 0 and Settings.Value(kind, "auraLists") == "" and Settings.Value(kind, "castbarHideIdle") == true, kind .. " keeps its cast and list defaults")
end
assert(Settings.Module().dispelCustom == false and ns.Dispel.Key() == "game", "dispel colours follow the game")
local player = Frames.Get("player").views[1]
assert(player.dispel == nil, "no dispel container is made until an option needs it")
for _, c in ipairs(env._containers) do
	assert(next(c._slots) == nil, "no aura slot exists by default")
end
local schema = keys(Settings.Schema())
for _, key in ipairs({ "player.castbarHideIdle", "target.castbarHideIdle", "focus.castbarHideIdle", "player.castbarIconSize", "boss.castbarIconSize", "player.castbarRangeGrey",
	"player.dispelOverlay", "player.dispelAlpha", "player.dispelEdge", "player.dispelIcon", "player.dispelIconSize", "player.dispelFilter", "player.totems", "player.totemPosition",
	"player.totemSize", "target.auraLists", "dispelCustom", "dispelMagic", "dispelBleed" }) do
	assert(schema[key], key .. " has a row")
end
assert(not schema["target.castbarRangeGrey"] and not schema["target.dispelOverlay"] and not schema["target.totems"], "range grey, dispel and totems are the player's")

-- Hide when idle off on the player, target and focus: the empty track stays, and the target's only while it exists.
local function stop(token)
	env._units[token].cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", token, "Cast-1", 116, 1)
	env.RunTimers()
end
local pcb = ns.CastBars.Get("player")[1]
write("player.castbarHideIdle", false)
assert(pcb.idle and pcb.frame:IsShown(), "an idle player bar shows its track")
assert(U.Shown(env, pcb.text) == "" and select(1, U.Bar(env, pcb.bar)) == 0, "the idle player track is empty")
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(pcb.active and U.Shown(env, pcb.text) ~= "", "a cast fills the idle track")
stop("player")
for _ = 1, 3 do env.RunTimers() end
assert(pcb.frame:IsShown() and not pcb.active, "after the cast the track stays")
write("player.castbarHideIdle", true)
assert(not pcb.idle and not pcb.frame:IsShown(), "on hides the idle player bar again")
local tcb = ns.CastBars.Get("target")[1]
write("target.style", "bar")
write("target.castbarHideIdle", false)
assert(ns.CastBars.ElementLive("target"), "the wide bar target uses its own cast bar element")
local hadTarget = env._units.target
U.SetUnit(env, "target", hadTarget or { name = "Dummy", reaction = 2, health = 50, healthMax = 100 })
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(tcb.frame:IsShown() and tcb.idle, "a target shows the idle track")
U.SetUnit(env, "target", nil)
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(not tcb.frame:IsShown(), "no target, no idle target track")
U.SetUnit(env, "target", hadTarget)
env.FireEvent("PLAYER_TARGET_CHANGED")
write("target.castbarHideIdle", true)
assert(not tcb.idle and not tcb.frame:IsShown(), "on hides the idle target bar")
write("target.style", "column")
local focus = Frames.Get("focus").views[1]
U.SetUnit(env, "focus", env._units.focus or { name = "Focus", reaction = 2, health = 50, healthMax = 100 })
env.FireEvent("PLAYER_FOCUS_CHANGED")
write("focus.castbarHideIdle", false)
assert(focus.castbar.idle and focus.castbar.frame:IsShown(), "an idle focus bar keeps its track on the card")
write("focus.castbarHideIdle", true)
assert(not focus.castbar.frame:IsShown(), "on folds the focus bar away")
clean("idle")

-- Spell icon size: framed and caption icons shrink and centre on the bar; 0 restores the exact rectangle.
local G = ns.CastBars.Geometry
local base = G(200, 20, true, true, 10)
local small = G(200, 20, true, true, 10, nil, false, 12)
assert(small.icon.w == 12 and small.icon.h == 12 and small.icon.y == 4 and small.icon.x == 0, "a 12-unit icon centres on a 20-unit bar")
assert(small.panel.x < base.panel.x and small.panel.w > base.panel.w, "the bar takes the room a smaller icon frees")
local right = G(200, 20, true, true, 10, nil, true, 12)
assert(right.icon.x == 188, "a right-hand icon stays at the far end")
local big = G(200, 20, true, true, 10, nil, false, 64)
assert(big.icon.w == 20 and big.icon.y == 0, "an icon never outgrows the bar's height")
local same = G(200, 20, true, true, 10, nil, false, 0)
for _, part in ipairs({ "icon", "panel", "bar", "text", "timer" }) do
	for _, field in ipairs({ "x", "y", "w", "h" }) do
		assert(same[part][field] == base[part][field], "0 keeps the " .. part .. " " .. field)
	end
end
local tall = G(20, 120, true, true, 10, nil, false, 12)
assert(tall.icon.w == 12 and tall.icon.x == 4 and tall.icon.y == 0, "a tall bar centres a smaller icon across")
write("player.style", "plate")
write("player.castbarIconSize", 10)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
local w, h = pcb.iconFrame:GetSize()
assert(pcb.iconFrame:IsShown() and math.abs(w - 10) < 0.6 and math.abs(h - 10) < 0.6, "the player's framed icon takes its size: " .. tostring(w))
write("player.style", "column")
local caption = pcb.geometry.icon
assert(caption and caption.w <= 10.5, "the caption icon takes its size too")
write("player.castbarIconSize", 0)
stop("player")
clean("icon size")

-- Grey when out of range: a ticker reads the cast spell's range while the player casts, and only then.
local function fill()
	return pcb.pr, pcb.pg, pcb.pb
end
local live = env.LiveTickers()
local function cast()
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end
env._inRange = false
cast()
assert(env.LiveTickers() == live and pcb.outOfRange ~= true, "off reads no range")
write("player.castbarRangeGrey", true)
cast()
assert(env.LiveTickers() == live + 1, "a cast starts one range ticker")
local r, g, b = fill()
local gr, gg, gb = K.Tokens.Color("textDisabled")
assert(pcb.outOfRange and r == gr and g == gg and b == gb, "out of range greys the fill at once")
env._inRange = true
env.RunTickers()
r = fill()
assert(not pcb.outOfRange and r ~= gr, "back in range restores the colour")
env._inRange = env.Secret(false)
env.RunTickers()
assert(not pcb.outOfRange, "a secret answer never greys")
env._inRange = nil
env.RunTickers()
assert(not pcb.outOfRange, "no target, no grey")
env._inRange = false
env.RunTickers()
assert(pcb.outOfRange, "out of range again")
stop("player")
assert(env.LiveTickers() == live and not pcb.outOfRange, "the ticker stops with the cast and the grey goes")
cast()
env._units.player.cast.spellID = env.Secret(116)
env._units.player.secretCast = true
cast()
assert(env.LiveTickers() == live and not pcb.outOfRange, "a secret spell is never range checked")
env._units.player.secretCast = nil
cast()
assert(pcb.outOfRange, "a readable cast greys again")
write("player.castbarRangeGrey", false)
assert(env.LiveTickers() == live and not pcb.outOfRange, "turning it off mid-cast stops the ticker and the grey")
stop("player")
env._inRange = true
clean("range")

-- Whole batch on the bar: one fill across every craft of a batch, the last craft included.
local function craft(start, left)
	env._recasts, env._time = left, start / 1000
	env._units.player.cast = { name = "Bolt of Linen", texture = 135846, start = start, finish = start + 3000, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end
env._trade = true
craft(1000, 2)
assert(not pcb.batch and U.Shown(env, pcb.text):lower() == "bolt of linen", "off keeps each craft on its own")
write("player.castbarCraftBar", true)
craft(1000, 2)
local value, low, high = U.Bar(env, pcb.bar)
assert(low == 0 and high == 9 and value == 0 and U.Shown(env, pcb.text):find("(3)", 1, true), "the bar spans the batch's three crafts")
stop("player")
craft(4000, 1)
value, low, high = U.Bar(env, pcb.bar)
assert(low == 0 and high == 9 and value == 3, "the second craft carries on the batch's fill: " .. tostring(value))
craft(7000, 0)
value, low, high = U.Bar(env, pcb.bar)
assert(low == 0 and high == 9 and value == 6 and U.Shown(env, pcb.text):find("(1)", 1, true), "the last craft finishes the same fill")
craft(20000, 0)
assert(not pcb.batch and U.Shown(env, pcb.text):lower() == "bolt of linen", "a lone craft later is a plain cast")
craft(30000, 1)
value, low, high = U.Bar(env, pcb.bar)
assert(low == 0 and high == 6 and value == 0, "a new batch starts its own fill")
assert(not Settings.Value("player", "castbarCraft"), "the bar needs no Whole craft batch switch")
write("player.castbarCraftBar", false)
craft(30000, 1)
assert(not pcb.batch, "turning it off restores each craft")
stop("player")
env._trade, env._time = nil, 1
clean("craft bar")

-- Dispel overlay, edge and type icon: one engine slot on the player frame, made on first use.
write("player.dispelOverlay", "health")
local d = assert(player.dispel, "the overlay makes its container")
local slot = d.container._slots.dispel
assert(slot and slot.enabled and slot.filter == "HARMFUL|RAID" and d.container._unit == "player", "the slot follows debuffs the player can dispel")
local p = d.parts
assert(p.health:IsShown() and not p.card:IsShown() and not p.edge:IsShown() and not p.mark:IsShown(), "only the health wash shows")
assert(p.health:GetAlpha() == 0.3, "the wash takes the fill opacity")
local button = slot.frame
assert(#button._aura.dispel == #p.tinted + 1, "every wash, edge and icon texture is tinted by the engine")
assert(button._aura.dispelOptions.customDispelColorMap == nil, "the game's colours by default")
local point = W.LastCall(p.health, "SetAllPoints")
assert(point and point[1] == player.health, "the health wash covers the health bar")
assert(p.health:GetFrameLevel() == player.top:GetFrameLevel() - 1, "the wash sits over the bars and under the text")
write("player.dispelAlpha", 0.6)
assert(p.health:GetAlpha() == 0.6, "opacity applies live")
write("player.dispelOverlay", "frame")
assert(p.card:IsShown() and not p.health:IsShown() and W.LastCall(p.card, "SetAllPoints")[1] == player.panel, "the whole-frame wash follows the card")
write("player.dispelEdge", true)
assert(p.edge:IsShown(), "the edge outlines the frame")
write("player.dispelIcon", "TOPRIGHT")
write("player.dispelIconSize", 30)
assert(p.mark:IsShown(), "the type icon shows")
local pin = W.LastCall(p.mark, "SetPoint")
assert(pin[1] == "TOPRIGHT" and pin[2] == player.health, "the type icon pins to the health bar's corner")
local mw = W.LastCall(p.mark, "SetSize")[1]
assert(mw <= K.Widgets.Snap(player.health, player.geometry.health.h) + 0.01, "the type icon never outgrows the health bar")
write("player.dispelFilter", "GROUP")
assert(slot.filter == "HARMFUL|RAID_PLAYER_DISPELLABLE", "group dispellable debuffs")
env.SetCombat(true)
write("player.dispelFilter", "PLAYER")
assert(slot.filter == "HARMFUL|RAID_PLAYER_DISPELLABLE", "a change in combat waits")
env.SetCombat(false)
env.RunTimers()
assert(slot.filter == "HARMFUL|RAID", "and lands after combat")
write("dispelCustom", true)
assert(ns.Dispel.Key() ~= "game", "own colours make a palette")
local map = button._aura.dispelOptions.customDispelColorMap
assert(map and map.Magic and map.Bleed, "the overlay takes the own colours")
local target = Frames.Get("target").views[1]
local entry = target.auras and target.auras.buttons[1]
if entry then
	assert(entry.button._aura.dispelOptions.customDispelColorMap == map, "aura dispel edges take the own colours too")
end
write("dispelMagic", { r = 1, g = 0, b = 0 })
assert(button._aura.dispelOptions.customDispelColorMap ~= map, "a new colour re-tints")
write("dispelCustom", false)
assert(button._aura.dispelOptions.customDispelColorMap == nil, "off returns to the game's colours")
if entry then
	assert(entry.button._aura.dispelOptions.customDispelColorMap == nil, "and the aura edges too")
end
write("player.dispelOverlay", "")
write("player.dispelEdge", false)
assert(p.mark:IsShown() and slot.enabled, "the icon alone keeps the slot on")
write("player.dispelIcon", "")
assert(not slot.enabled and not p.mark:IsShown(), "all off disables the slot")
write("player.dispelOverlay", "health")
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(not slot.enabled, "Medallions keeps its forged portrait")
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
assert(slot.enabled, "back to Frames")
write("player.dispelOverlay", "")
assert(not slot.enabled, "off again")
clean("dispel")

-- Totem timers: a row of icon buttons beside the player frame, filled from the totem slots on their event.
write("player.totems", true)
local holder = Frames.Get("player").holder
env._totems[2] = { have = true, name = "Searing Totem", start = 1, duration = 60, icon = 135824, spellID = 3599 }
env.FireEvent("PLAYER_TOTEM_UPDATE", 2)
local function rowOf()
	for _, child in ipairs({ holder:GetChildren() }) do
		if child.buttons then return child end
	end
end
local totems = rowOf()
assert(totems and #totems.buttons == 4 and totems:IsShown(), "four totem slots")
assert(totems.buttons[2]:IsShown() and not totems.buttons[1]:IsShown(), "only a held slot shows")
assert(W.LastCall(totems.buttons[2].icon, "SetTexture")[1] == 135824, "the totem's icon")
assert(W.LastCall(totems.buttons[2].cooldown, "SetCooldownFromDurationObject")[1].totem == 2, "the countdown runs from the totem's duration")
local anchor = W.LastCall(totems, "SetPoint")
assert(anchor[1] == "BOTTOMLEFT" and anchor[2] == holder and anchor[3] == "TOPLEFT", "above the player frame by default")
env._totems[2].have = env.Secret(true)
env.FireEvent("PLAYER_TOTEM_UPDATE", 2)
assert(totems.buttons[2]:IsShown() and W.LastCall(totems.buttons[2], "SetAlphaFromBoolean"), "a secret slot shows through the engine's alpha")
env._totems[2] = nil
env.FireEvent("PLAYER_TOTEM_UPDATE", 2)
assert(not totems.buttons[2]:IsShown(), "a dropped totem hides")
write("player.totemPosition", "LEFT")
anchor = W.LastCall(totems, "SetPoint")
assert(anchor[1] == "RIGHT" and anchor[3] == "LEFT", "left of the frame")
assert(W.LastCall(totems.buttons[1], "SetPoint")[4] > W.LastCall(totems.buttons[4], "SetPoint")[4], "slot 1 sits nearest the frame")
write("player.totemSize", 32)
assert(math.abs(totems.buttons[1]:GetWidth() - 32) < 0.6, "the totem size applies")
write("player.totems", false)
assert(not totems:IsShown(), "off hides the row")
env._totems[1] = { have = true, name = "Stoneskin Totem", start = 1, duration = 60, icon = 136098, spellID = 8071 }
env.FireEvent("PLAYER_TOTEM_UPDATE", 1)
assert(not totems.buttons[1]:IsShown(), "off stops listening")
env._totems[1] = nil
write("player.totemPosition", "ABOVE")
write("player.totemSize", 24)
clean("totems")

-- Spell ID lists from another frame: the target reads the player's hidden and tracked lists, live.
write("target.auraFilter", "both")
write("player.auraHidden", "1234")
local tgroups = target.auras.container._groups
assert(tgroups.debuffs.candidates == nil, "the target keeps its own empty list")
write("target.auraLists", "player")
assert(Settings.Value("target", "auraHidden") == "1234", "the target reads the player's list")
assert(tgroups.debuffs.candidates and tgroups.debuffs.candidates.excludeSpellIDs and tgroups.debuffs.candidates.excludeSpellIDs[1234], "the engine hides the player's spell IDs on the target")
write("player.auraHidden", "1234 5678")
assert(tgroups.debuffs.candidates.excludeSpellIDs[5678], "a change on the player restyles the target")
write("edit", "target")
assert(not keys(Settings.Schema())["target.auraHidden"].showWhen(K.Store.Module("UnitFrames")), "the target's own list row hides while it reads the player's")
write("target.auraLists", "")
assert(tgroups.debuffs.candidates == nil and Settings.Value("target", "auraHidden") == "", "own lists again")
write("player.auraHidden", "")
write("target.auraFilter", "mine")
clean("lists")

-- The preview shows the dispel wash, the totems and the icon size.
write("edit", "player")
write("player.style", "plate")
write("player.dispelOverlay", "health")
write("player.dispelEdge", true)
write("player.totems", true)
write("player.castbarIconSize", 12)
local pane = ns.Preview.Build(env.UIParent)
local view = pane.views.player
local sample = assert(view.dispelSample, "the preview makes a dispel sample")
assert(sample.health:IsShown() and sample.edge:IsShown(), "the preview washes and outlines the frame")
local mr = W.LastCall(sample.fill, "SetVertexColor")
local tr = K.Tokens.Color("magic")
assert(mr[1] == tr, "the preview wash uses the magic colour")
write("dispelCustom", true)
write("dispelMagic", { r = 1, g = 0, b = 0 })
pane:Refresh()
assert(W.LastCall(sample.fill, "SetVertexColor")[1] == 1, "the preview follows own colours")
assert(pane.totems and pane.totems:IsShown() and #pane.totems.buttons == 4, "the preview shows the totem row")
local icon = pane.casts.player.iconFrame
assert(math.abs(icon:GetWidth() - 12) < 0.6, "the preview's spell icon takes its size")
write("player.dispelOverlay", "")
write("player.dispelEdge", false)
write("player.totems", false)
write("player.castbarIconSize", 0)
write("dispelCustom", false)
pane:Refresh()
assert(not sample.health:IsShown() and not sample.edge:IsShown() and not pane.totems:IsShown(), "the preview clears them")
clean("preview")
print("test-unitframes-parity-r4b: ok")
