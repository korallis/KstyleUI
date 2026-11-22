-- test-unitframes-parity-r5.lua: parity round 5 keeps v0.2.8 frames and makes nothing new, then turns on, probes after events and turns off the spell target's own text, the global cooldown fill, the detached power bar and the buff block apart, with its fallbacks, and checks the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {} },
	setup = function(e)
		e.UnitShouldDisplaySpellTargetName = function() return e._castTarget ~= nil end
		e.UnitSpellTargetName = function() return e._castTarget end
		e._gcd, e._cooldownReads, e._left = {}, 0, 1.2
		e.C_Spell.GetSpellCooldown = function(id)
			e._cooldownReads = e._cooldownReads + 1
			return { startTime = e.Secret(10), duration = e.Secret(1.5), isEnabled = true, isActive = true, isOnGCD = e._gcd[id] }
		end
		e.C_Spell.GetSpellCooldownDuration = function(id)
			return { spell = id, GetRemainingDuration = function() return e._left end }
		end
		e.Enum.StatusBarTimerDirection = e.Enum.StatusBarTimerDirection or { ElapsedTime = 0, RemainingTime = 1 }
		e.C_DurationUtil = { CreateDuration = function() return { SetTimeSpan = function() end } end }
	end,
})
local Settings, Frames, CastBars, Geometry = ns.Settings, ns.Frames, ns.CastBars, ns.Geometry

local function clean(where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

-- A v0.2.8-shaped profile keeps today's settings, has a row for each option and makes no new region.
for _, kind in ipairs(U.KINDS) do
	for key, value in pairs({ castbarTargetPlace = "", castbarTargetSize = 0, castbarTargetX = 0, castbarTargetY = 0, powerDetach = "", powerDetachWidth = 0,
		powerDetachX = 0, powerDetachY = 0, auraBuffPlace = "", auraBuffX = 0, auraBuffY = 0 }) do
		assert(Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
end
assert(Settings.Value("player", "castbarGcd") == false, "the global cooldown fill starts off")
local schema = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then schema[row.key] = row end
end
for _, key in ipairs({ "target.castbarTargetPlace", "target.castbarTargetSize", "target.castbarTargetColor", "target.castbarTargetX", "player.castbarGcd",
	"player.powerDetach", "player.powerDetachWidth", "player.powerDetachStrata", "player.powerDetachX", "focus.auraBuffPlace", "focus.auraBuffX" }) do
	assert(schema[key], key .. " has a row")
end
assert(not schema["target.castbarGcd"], "the global cooldown fill is the player's")
local pcb, tcb = CastBars.Inline("player")[1], CastBars.Inline("target")[1]
assert(pcb.targetText == nil and tcb.targetText == nil, "no spell target text exists by default")
local focus = Frames.Get("focus").views[1]
for _, cached in pairs(focus.auras.styles) do
	assert(cached.buff == nil, "no buff block exists by default")
end
env._gcd[116] = true
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-0", 116)
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(env._cooldownReads == 0 and not pcb.frame:IsShown(), "off, the cooldown events are never heard")
clean("defaults")

-- Spell target on its own: the name keeps one half of its line and the target the other, a secret name included.
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
env._castTarget = "Valerin"
write("target.castbarTarget", true)
local function cast()
	env._units.target.cast = { name = "Shadow Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686 }
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
end
cast()
local full = tcb.text:GetWidth()
assert(U.Shown(env, tcb.text):find(" - Valerin", 1, true), "with the spell name by default")
write("target.castbarTargetPlace", "RIGHT")
cast()
local t = tcb.targetText
assert(t and t:IsShown() and U.Shown(env, t) == "Valerin", "the target has its own text")
assert(not U.Shown(env, tcb.text):find("Valerin", 1, true), "the name no longer carries it")
assert(tcb.text:GetWidth() < full / 2 and tcb.text:GetWidth() > full / 2 - 4 and near(t:GetWidth(), tcb.text:GetWidth()), "each takes half the name's room")
local p = W.LastCall(t, "SetPoint")
local pad = p[4]
assert(p[1] == "LEFT" and p[2] == tcb.text and p[3] == "RIGHT" and pad > 0, "right of the name, a gap clear of it")
env._castTarget = env.Secret("Brute")
cast()
assert(U.Shown(env, t) == "Brute", "a secret target name still shows")
env._castTarget = nil
cast()
assert(U.Shown(env, t) == "", "no shown target leaves its half empty")
env._castTarget = "Valerin"
cast()
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-1", 686)
assert(U.Shown(env, t) == "", "an interrupted cast clears the target with the name")
write("target.castbarTargetPlace", "LEFT")
cast()
local name = W.LastCall(tcb.text, "SetPoint")
p = W.LastCall(t, "SetPoint")
assert(p[1] == "RIGHT" and p[2] == tcb.text and p[3] == "LEFT" and p[4] < 0, "left of the name")
pad = -p[4]
assert(W.LastCall(t, "SetJustifyH")[1] == "LEFT" and name[4] > 0, "the name moves to the right half")
write("target.castbarTargetSize", 15)
write("target.castbarTargetColor", { r = 1, g = 0.5, b = 0 })
write("target.castbarTargetX", 3)
write("target.castbarTargetY", -2)
cast()
local c = W.LastCall(t, "SetTextColor")
assert(c[1] == 1 and c[2] == 0.5 and c[3] == 0, "its own colour")
assert(near(select(2, t:GetFont()), 15 * K.Theme.FontScale()), "its own size")
p = W.LastCall(t, "SetPoint")
assert(near(p[4], -pad + K.Widgets.Snap(tcb.frame, 3)) and near(p[5], -K.Widgets.Snap(tcb.frame, 2)), "its own offsets")
write("target.castbarTarget", false)
cast()
assert(not t:IsShown() and near(tcb.text:GetWidth(), full) and not U.Shown(env, tcb.text):find("Valerin", 1, true), "Spell target off hides it and gives the name its room back")
write("target.castbarTarget", true)
write("target.castbarTargetPlace", "")
cast()
assert(not t:IsShown() and near(tcb.text:GetWidth(), full) and U.Shown(env, tcb.text):find(" - Valerin", 1, true), "back with the spell name, the name's room restored")
write("target.castbarTarget", false)
write("edit", "focus")
write("focus.castbarTarget", true)
assert(schema["focus.castbarTargetPlace"].showWhen(K.Store.Module("UnitFrames")), "the focus slab's cast bar offers the place row")
write("edit", "player")
write("focus.castbarTarget", false)
clean("spell target")

-- Global cooldown: an instant spell fills the player bar over the cooldown, a cast takes over, and the bar goes when it ends.
write("player.castbarGcd", true)
env._gcd = { [116] = true }
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-0", 116)
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(pcb.gcd and pcb.frame:IsShown(), "the global cooldown shows the bar")
local timer = W.LastCall(pcb.bar, "SetTimerDuration")
assert(timer[1].spell == 116 and timer[3] == env.Enum.StatusBarTimerDirection.ElapsedTime, "it runs the spell's cooldown duration object")
assert(U.Shown(env, pcb.text) == "" and U.Shown(env, pcb.timer) == "", "with no name or timer")
local runs = #W.Calls(pcb.bar, "SetTimerDuration")
env.FireEvent("SPELL_UPDATE_COOLDOWN", 116)
assert(#W.Calls(pcb.bar, "SetTimerDuration") == runs, "more cooldown events during it change nothing")
env.RunTimers()
assert(not pcb.gcd and not pcb.frame:IsShown(), "it goes when the cooldown ends")
env._gcd = { [116] = true, [133] = false }
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 133)
env.FireEvent("SPELL_UPDATE_COOLDOWN", 133)
assert(pcb.gcd and W.LastCall(pcb.bar, "SetTimerDuration")[1].spell == 116, "a spell on its own cooldown reads the last spell seen on the global one")
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 116)
env.RunTimers()
assert(pcb.active and pcb.frame:IsShown() and not pcb.gcd, "a cast takes over and the cooldown's end leaves it alone")
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(pcb.active and not pcb.gcd, "no cooldown fill during a cast")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-3", 116, 1)
for _ = 1, 3 do env.RunTimers() end
env._gcd = { [116] = env.Secret(true) }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(not pcb.gcd, "a secret answer is never tested")
env._gcd, env._left = { [116] = true }, env.Secret(1.1)
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(pcb.gcd, "a secret time left still shows the fill")
env.RunTimers()
assert(not pcb.gcd and not pcb.frame:IsShown(), "and ends it at the longest global cooldown")
env._left = 1.2
write("player.castbarHideIdle", false)
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(pcb.gcd and pcb.frame:IsShown(), "it fills the idle track too")
env.RunTimers()
assert(pcb.frame:IsShown() and select(1, U.Bar(env, pcb.bar)) == 0 and not pcb.gcd, "and leaves the empty track")
write("player.castbarHideIdle", true)
local api = env.C_Spell.GetSpellCooldownDuration
env.C_Spell.GetSpellCooldownDuration = nil
write("player.castbarSmooth", true)
local reads = env._cooldownReads
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(env._cooldownReads == reads and not pcb.gcd, "without the duration API it hears nothing")
env.C_Spell.GetSpellCooldownDuration = api
write("player.castbarSmooth", false)
write("player.castbarGcd", false)
reads = env._cooldownReads
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(env._cooldownReads == reads and not pcb.gcd and not pcb.frame:IsShown(), "off stops hearing the cooldowns")
clean("global cooldown")

-- Detached power bar on the plate: apart below or above the bars at its own width, the frame's size and everything around it unchanged.
write("player.style", "plate")
local player = Frames.Get("player").views[1]
local holder = Frames.Get("player").holder
local w0, h0 = holder:GetSize()
local function rects(g)
	local out = {}
	for key, r in pairs(g) do
		if type(r) == "table" and type(r.y) == "number" then out[key] = { r.x, r.y, r.w, r.h } end
	end
	return out
end
local before = rects(player.geometry)
local height = select(2, player.parent:GetSize())
write("player.powerDetach", "BELOW")
local g, ph = player.geometry, Settings.Value("player", "powerHeight")
assert(g.power and near(g.power.y, height - ph) and near(g.power.h, ph), "the bar sits at the foot of the frame's room")
assert(g.health.y + g.health.h <= height - ph - 4 + 1e-6, "clear of the bars above it by the gap")
assert(near(g.power.w, g.panel.w) and near(g.power.x, g.panel.x), "as wide as the frame")
assert(g.powerText and g.powerText.y == g.power.y, "its text rides the bar")
local bar = W.LastCall(player.power, "SetPoint")
assert(bar[2] == player.parent and near(bar[5], -K.Widgets.Snap(player.parent, height - ph)), "the bar is placed there")
assert(near(select(1, holder:GetSize()), w0) and near(select(2, holder:GetSize()), h0), "the frame keeps its size")
env._units.player.power = 1234
env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
assert(U.Bar(env, player.power) == 1234, "the detached bar follows power events")
write("player.powerDetachWidth", 150)
write("player.powerDetachX", 10)
write("player.powerDetachY", 5)
g = player.geometry
assert(near(g.power.w, 150) and near(g.power.x, g.panel.x + (g.panel.w - 150) / 2 + 10) and near(g.power.y, height - ph - 5), "its own width and offsets")
write("player.powerDetachStrata", "HIGH")
assert(W.LastCall(player.power, "SetFrameStrata")[1] == "HIGH", "its own strata")
write("player.powerDetach", "ABOVE")
g = player.geometry
assert(near(g.power.y, -5) and g.health.y >= ph + 4 - 1e-6, "above: on top, the bars below it")
write("player.style", "plate")
g = player.geometry
assert(g.form == "plate" and near(g.power.y, -5) and g.glass.y >= ph + 4 - 1e-6, "a plate frame detaches it too")
for _, key in ipairs({ "powerDetachWidth", "powerDetachX", "powerDetachY" }) do write("player." .. key, 0) end
write("player.powerDetach", "")
assert(W.LastCall(player.power, "SetFrameStrata")[1] == player.power:GetParent():GetFrameStrata(), "off returns the bar to the frame's strata")
local strataCalls = #W.Calls(player.power, "SetFrameStrata")
write("player.powerHeight", 6)
assert(#W.Calls(player.power, "SetFrameStrata") == strataCalls, "a frame in place never sets the strata again")
write("player.powerHeight", 7)
write("player.powerDetachStrata", "")
local after = rects(player.geometry)
for key, r in pairs(before) do
	for i = 1, 4 do assert(near(after[key][i], r[i]), "off restores the frame's " .. key) end
end
write("player.style", "lumen")
local slab = Geometry.Frame({ form = "slab", kind = "player", power = true, powerHeight = 7, powerDetach = "BELOW", powerDetachWidth = 0, powerDetachX = 0, powerDetachY = 0, name = true, healthText = "none", powerText = "none" }, 200, 58)
assert(not slab.power or slab.power.y < 58 - 7, "Medallions slabs keep their own power bar")
clean("detached power")

-- Buffs apart: their own block on another side, the debuffs where they were; the same side keeps them together.
U.SetUnit(env, "focus", { name = "Elunara", level = 60, health = 1, healthMax = 2, reaction = 2 })
env.FireEvent("PLAYER_FOCUS_CHANGED")
write("focus.auraFilter", "both")
local a = focus.auras
local main = a.container
assert(main._groups.buffs.enabled and main._groups.buffs.layout.forceNewLine, "with the debuffs by default")
local _, together = ns.Auras.Footprint("focus")
write("focus.auraBuffPlace", "BELOW")
local block = a.buff
assert(block and block.container._groups.buffs.enabled and block.container._groups.buffs.filter == "HELPFUL", "the buffs have their own block")
assert(main._groups.buffs.enabled == false and main._groups.debuffs.enabled and main._groups.debuffs.filter == "HARMFUL", "the debuffs stay on")
assert(block.container._groups.buffs.layout.forceNewLine == false, "the block starts on its first line")
local _, alone = ns.Auras.Footprint("focus")
assert(alone < together, "each block is one kind tall")
local anchor = W.LastCall(block.host, "SetPoint")
assert(anchor[1] == "TOPLEFT" and anchor[2] == focus.button and anchor[3] == "BOTTOMLEFT", "below the frame")
assert(W.LastCall(a.host, "SetPoint")[3] == "TOPLEFT", "the debuffs stay above")
assert(block.host:IsShown() == a.host:IsShown(), "shown with the frame's auras")
assert(#block.container._groups.buffs.buttons > 0 and a.buttons[#a.buttons].key == "buffs", "its buttons are dressed with the rest")
local chip = a.overflow and a.overflow.buffs
if chip then
	assert(W.LastCall(chip.window, "SetPoint")[2] == block.container, "the buffs' +N follows the block")
end
local debuffAt = W.LastCall(a.host, "SetPoint")
write("focus.auraBuffX", 6)
write("focus.auraBuffY", -4)
local moved, kept = W.LastCall(block.host, "SetPoint"), W.LastCall(a.host, "SetPoint")
assert(near(moved[4], anchor[4] + K.Widgets.Snap(block.host, 6)) and near(moved[5], anchor[5] - K.Widgets.Snap(block.host, 4)), "its own offsets")
assert(near(kept[4], debuffAt[4]) and near(kept[5], debuffAt[5]), "the debuffs keep theirs")
U.SetUnit(env, "focus", { name = "Krazhk", level = 60, health = 1, healthMax = 2, reaction = 5 })
env.FireEvent("PLAYER_FOCUS_CHANGED")
assert(block.container._unit == "focus" and block.container._enabled, "a new focus keeps the block")
write("focus.auraBuffPlace", "ABOVE")
assert(not a.buff and main._groups.buffs.enabled and not block.container._enabled and not block.host:IsShown(), "the debuffs' own side keeps them together")
write("focus.auraBuffPlace", "LEFT")
assert(a.buff == block and block.container._enabled, "the block comes back without a new one")
write("focus.auraFilter", "debuffs")
assert(not a.buff and not block.container._enabled, "with only debuffs there is no block")
write("focus.auraFilter", "both")
env._restricted = true
write("focus.auraBuffPlace", "")
write("focus.auraBuffPlace", "RIGHT")
assert(a.buff == block, "the block made before restriction is reused")
env._restricted = false
local target = Frames.Get("target").views[1]
write("target.auraFilter", "both")
env._restricted = true
write("target.auraBuffPlace", "BELOW")
assert(target.auras.buff == nil and target.auras.buffWait, "a block is never made while auras are restricted")
env._restricted = false
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
env.RunTimers()
assert(target.auras.buff and not target.auras.buffWait, "it is made when they are readable")
write("target.auraBuffPlace", "ABOVE")
assert(not target.auras.buff, "the target's debuffs above its slab count as the side above")
write("target.auraBuffPlace", "")
write("target.auraFilter", "mine")
write("focus.auraBuffPlace", "")
write("focus.auraFilter", "mine")
assert(not a.buff and main._groups.buffs.enabled == false, "off restores one block")
clean("buffs apart")

-- The live preview shows each option.
write("edit", "player")
write("player.style", "plate")
local pane = ns.Preview.Build(env.UIParent)
local pview, pc = pane.views.player, pane.casts.player
assert(not pview.geometry.power, "the compact plate preview has no power bar of its own")
write("player.powerDetach", "ABOVE")
pane:Refresh()
assert(pview.geometry.power and pview.geometry.power.y <= 0 + 1e-6, "the preview detaches the power bar")
write("player.powerDetach", "")
write("player.castbarGcd", true)
pane:Refresh()
assert(U.Shown(env, pc.text) == "" and select(1, U.Bar(env, pc.bar)) > 0, "the preview fills the cast bar over a global cooldown")
write("player.castbarGcd", false)
pane:Refresh()
assert(U.Shown(env, pc.text) ~= "", "and shows the sample cast again when off")
write("player.castbarTarget", true)
write("player.castbarTargetPlace", "RIGHT")
pane:Refresh()
assert(pc.targetText and pc.targetText:IsShown() and U.Shown(env, pc.targetText) ~= "" and not U.Shown(env, pc.text):find(" - ", 1, true), "the preview shows the target on its own")
write("player.castbarTargetPlace", "")
write("player.castbarTarget", false)
write("edit", "focus")
write("focus.auraFilter", "both")
write("focus.auraBuffPlace", "BELOW")
pane:Refresh()
local bhost = pane.buffHosts.focus
assert(bhost and bhost:IsShown() and W.LastCall(bhost, "SetPoint")[3] == "BOTTOMLEFT", "the preview's buffs sit apart below the frame")
local inBlock = 0
for _, tile in ipairs(pane.auraTiles.focus) do
	if tile.skin:IsShown() and W.LastCall(tile.skin, "SetPoint")[2] == bhost then inBlock = inBlock + 1 end
end
assert(inBlock > 0, "with the sample buffs in it")
write("focus.auraBuffPlace", "")
pane:Refresh()
assert(not bhost:IsShown(), "off folds the preview's block back")
write("focus.auraFilter", "mine")
write("player.style", "column")
clean("preview")
print("unit frames parity round 5 ok")
