-- test-unitframes-parity-r5-review.lua: the round 5 review's probes: the global cooldown fill over a cast's fade and after a second instant with a secret time left, one cooldown read per spell, a secret name anchor, the spell target matching the name's type, the plate's detached power text on the bar's strata and back on a slab, buffs kept with the debuffs until their block exists, buff offsets only for a block, one enable per apply, and the preview's slab cooldown, detached bar room and per-group aura capacity.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	setup = function(e)
		e.UnitShouldDisplaySpellTargetName = function() return e._castTarget ~= nil end
		e.UnitSpellTargetName = function() return e._castTarget end
		e._reads, e._left = {}, 1
		e.C_Spell.GetSpellCooldown = function(id)
			e._reads[#e._reads + 1] = id
			return { isOnGCD = e._gcd }
		end
		e.C_Spell.GetSpellCooldownDuration = function(id)
			return { spell = id, GetRemainingDuration = function() return e._left end }
		end
	end,
})

local function set(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function clean(where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function row(key)
	for _, r in ipairs(ns.Settings.Schema()) do
		if r.key == key then return r end
	end
end

local db = K.Store.Module("UnitFrames")
local cb = ns.CastBars.Inline("player")[1]

-- 1. A cast's fade-out never hides the global cooldown that follows it.
set("player.castbarGcd", true)
env._units.player.cast = { name = "Frostbolt", texture = 1, start = 1000, finish = 3000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116, 1)
env.RunTimers()
env._gcd = true
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 133)
env.FireEvent("SPELL_UPDATE_COOLDOWN", 133)
assert(cb.gcd and cb.frame:IsShown(), "an instant after a cast shows the global cooldown")
W.Tick(env, 0.5)
assert(cb.gcd and cb.frame:IsShown() and cb.frame:GetAlpha() == 1, "the cast's fade does not hide it a tick later")
env.RunTimers()
assert(not cb.gcd and not cb.frame:IsShown(), "it ends with its cooldown")

-- 9a. One cooldown read per spell, however many of the event, cast and last spell coincide.
env._reads, env._gcd = {}, false
env.FireEvent("SPELL_UPDATE_COOLDOWN", 133)
assert(table.concat(env._reads, ",") == "133", "one read for one spell: " .. table.concat(env._reads, ","))

-- 2. A second instant after a short cooldown starts its own fill, and the first one's deadline leaves it alone.
env._gcd, env._left = true, env.Secret(1)
local after, timers = env.C_Timer.After, {}
env.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local starts = #W.Calls(cb.bar, "SetTimerDuration")
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 116)
env.FireEvent("SPELL_UPDATE_COOLDOWN", 116)
local first = timers[#timers]
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 133)
env.FireEvent("SPELL_UPDATE_COOLDOWN", 133)
env.C_Timer.After = after
assert(#W.Calls(cb.bar, "SetTimerDuration") == starts + 2 and W.LastCall(cb.bar, "SetTimerDuration")[1].spell == 133, "the second instant starts its own cooldown")
env.FireEvent("SPELL_UPDATE_COOLDOWN", 133)
assert(#W.Calls(cb.bar, "SetTimerDuration") == starts + 2, "a repeated cooldown event starts nothing")
first()
assert(cb.gcd and cb.frame:IsShown(), "the first cooldown's deadline leaves the second shown")
timers[#timers]()
assert(not cb.gcd and not cb.frame:IsShown(), "the second's own deadline ends it")
env._gcd, env._left = false, 1
set("player.castbarGcd", false)
clean("global cooldown")

-- 8. With size 0 the spell target takes the name's fitted size and its caption shadow.
env._castTarget = "Dawn"
for key, value in pairs({ castbarFit = true, castbarTarget = true, castbarTargetPlace = "RIGHT" }) do set("player." .. key, value) end
set("player.fonts.cast.size", 20)
cb.text.GetUnboundedStringWidth = function() return 500 end
env._units.player.cast = { name = string.rep("Arcane ", 30), texture = 1, start = 1000, finish = 3000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-5", 116)
local _, name = cb.text:GetFont()
local _, target = cb.targetText:GetFont()
assert(name < 20 and target == name, "the target follows the fitted name: " .. name .. " and " .. target)
local sx, sy = cb.text:GetShadowOffset()
local tx, ty = cb.targetText:GetShadowOffset()
assert(sx == tx and sy == ty, "and its shadow")
cb.text.GetUnboundedStringWidth = nil

-- 3. A secret name anchor is never passed back to SetPoint; the target rides with the name instead.
set("player.castbarTargetPlace", "LEFT")
local getPoint, setPoint, passed = cb.text.GetPoint, cb.text.SetPoint, false
cb.text.GetPoint = function(self, i)
	local _, relative, relPoint, x, y = getPoint(self, i)
	return env.Secret("TOPLEFT"), relative, relPoint, x, y
end
cb.text.SetPoint = function(self, point, ...)
	if env.issecretvalue(point) then passed = true return end
	return setPoint(self, point, ...)
end
ns.CastBars.Layout(cb, 260, 40)
cb.text.GetPoint, cb.text.SetPoint = getPoint, setPoint
assert(not passed and not cb.targetOn and not cb.targetText:IsShown(), "a secret anchor falls back to the target with the name")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-5", 116, 1)
for key, value in pairs({ castbarFit = false, castbarTarget = false, castbarTargetPlace = "" }) do set("player." .. key, value) end
set("player.fonts.cast.size", 0)
env._castTarget = nil
clean("spell target")

-- 4 and 9b. The plate's detached bar strata takes its text and fill clip, is set once, and goes on a Medallions slab.
local pv = ns.Frames.Get("player").views[1]
set("player.style", "plate")
set("player.powerDetach", "BELOW")
set("player.powerDetachStrata", "HIGH")
assert(pv.power:GetFrameStrata() == "HIGH" and pv.powerText:GetParent():GetFrameStrata() == "HIGH", "the text draws on the bar's strata")
assert(pv.powerFillClip:GetParent() == pv.powerText:GetParent(), "with its fill clip")
local calls = #W.Calls(pv.power, "SetFrameStrata")
ns.Style.Layout(pv, pv.s, pv.parent:GetWidth(), pv.parent:GetHeight())
assert(#W.Calls(pv.power, "SetFrameStrata") == calls, "an unchanged layout sets no strata")
set("player.style", "lumen")
assert(pv.form == "slab" and pv.power:GetFrameStrata() == pv.power:GetParent():GetFrameStrata() and pv.powerText:GetParent() == pv.top, "a slab inherits again")
set("player.style", "plate")
assert(pv.power:GetFrameStrata() == "HIGH" and pv.powerText:GetParent():GetFrameStrata() == "HIGH", "back on the plate it is raised again")
set("player.powerDetach", "")
assert(pv.powerText:GetParent() == pv.top and pv.powerFillClip:GetParent() == pv.top and pv.powerFillClip:GetFrameLevel() == pv.top:GetFrameLevel() + 1, "in the frame the text and clip go home")
set("player.powerDetachStrata", "")
set("player.style", "lumen")
clean("detached power")

-- 5 and 9c. Until the buff block exists the buffs keep their own line under the debuffs; its offsets show only for a block.
local focus = ns.Frames.Get("focus").views[1]
local a = focus.auras
set("edit", "focus")
set("focus.auraFilter", "both")
local _, together = ns.Auras.Footprint("focus")
env._restricted = true
set("focus.auraBuffPlace", "BELOW")
local _, held = ns.Auras.Footprint("focus")
local buffs = a.container._groups.buffs
assert(not a.buff and buffs.enabled and buffs.layout.forceNewLine and held == together, "held: the debuffs and buffs keep two rows, " .. together .. " then " .. held)
assert(not row("focus.auraBuffX").showWhen(db), "no block, no offsets")
env._restricted = false
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
env.RunTimers()
local _, apart = ns.Auras.Footprint("focus")
assert(a.buff and apart < together and row("focus.auraBuffX").showWhen(db), "the block made, each is one kind tall and offsets show")
local enable, enabled = a.buff.container.SetEnabled, 0
a.buff.container.SetEnabled = function(self, on)
	if on then enabled = enabled + 1 end
	return enable(self, on)
end
ns.Auras.Apply(focus)
a.buff.container.SetEnabled = nil
assert(enabled == 1, "one apply enables the block once: " .. enabled)
set("focus.auraBuffPlace", "ABOVE")
assert(not a.buff and not row("focus.auraBuffX").showWhen(db), "the debuffs' own side keeps them together and hides the offsets")
local bare, BK, bns = U.New({ setup = function(e) e.C_Secrets = nil end })
for key, value in pairs({ auraFilter = "both", auraBuffPlace = "BELOW" }) do BK.Options.Write("UnitFrames", "focus." .. key, value) end
bare.RunTimers()
local ba = bns.Frames.Get("focus").views[1].auras
assert(not ba.buff and ba.container._groups.buffs.enabled and ba.container._groups.buffs.layout.forceNewLine, "without the restriction API no block is made")
set("focus.auraBuffPlace", "")
set("focus.auraFilter", "mine")
clean("buffs apart")

-- 7. The preview: the slab cooldown, the detached bar inside its pane and each aura group's own capacity.
set("edit", "player")
local pane = ns.Preview.Build(env.UIParent)
set("player.castbarGcd", true)
pane:Refresh()
assert(ns.Settings.Form("player") == "slab" and pane.casts.player.frame:IsShown(), "the slab preview shows the cooldown fill")
set("player.castbarGcd", false)
pane:Refresh()
assert(not pane.casts.player.frame:IsShown(), "off, the slab preview has no cast bar again")
set("player.style", "plate")
set("player.powerDetach", "BELOW")
set("player.powerDetachWidth", 600)
set("player.powerDetachX", 50)
local box = env.CreateFrame("Frame", nil, env.UIParent)
box:SetSize(300, 170)
local small = ns.Preview.Build(box)
small:Refresh()
local scaled = small.views.player.power:GetWidth() * small.holders.player:GetScale()
assert(scaled <= small:GetWidth(), "the detached bar fits its pane: " .. scaled)
for _, key in ipairs({ "powerDetachWidth", "powerDetachX" }) do set("player." .. key, 0) end
set("player.powerDetach", "")
set("player.style", "column")
set("edit", "focus")
for key, value in pairs({ auraFilter = "both", auraBuffPlace = "BELOW", auraColumns = 2, auraRows = 1 }) do set("focus." .. key, value) end
pane:Refresh()
local count, chips = { 0, 0 }, 0
local host, block = pane.auraHosts.focus, pane.buffHosts.focus
for _, tile in ipairs(pane.auraTiles.focus) do
	if tile.skin:IsShown() then
		local into = W.LastCall(tile.skin, "SetPoint")[2] == block and 2 or 1
		count[into] = count[into] + 1
	end
end
for _, chip in pairs(pane.auraChips) do
	if chip:IsShown() and (chip:GetParent() == host or chip:GetParent() == block) then chips = chips + 1 end
end
assert(count[1] == 2 and count[2] == 2, "two debuffs and two buffs, each group at its own capacity: " .. count[1] .. " and " .. count[2])
assert(chips == 2, "each full group has its own +N: " .. chips)
clean("preview")
print("unit frames parity round 5 review ok")
