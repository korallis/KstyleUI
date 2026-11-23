-- test-cast-caster.lua: target, focus and nameplate casts name who they are aimed at in class colour (YOU for the player), name who interrupted them, shield uninterruptible casts and dim with a ready mark while the player's interrupt recharges; off builds and changes nothing.
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local PUMMEL = 6552

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-4
end

local function plain(env, value)
	if env.issecretvalue(value) then return env.Reveal(value) end
	return value
end

local function clean(env, K, where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function guids(env)
	env.UnitGUID = function(token) return token == "player" and "Player-1" or nil end
	env.UnitNameFromGUID = function(guid) return guid == "Player-1" and "Kstyle" or guid == "Player-2" and "Valerin" or nil end
	env.UnitClassFromGUID = function(guid) return "Mage", guid == "Player-2" and "MAGE" or "WARRIOR", 8 end
end

-- Nameplates -----------------------------------------------------------------------------------------------

do
	local env, K, ns = N.New({ playerClass = "WARRIOR", known = { [PUMMEL] = true } })
	guids(env)
	env.UnitShouldDisplaySpellTargetName = function(token) return env._units[token].spellTarget ~= nil end
	env.UnitSpellTargetClass = function() return env.Secret("MAGE") end
	env._me = false
	env.PlayerIsSpellTarget = function() return env.Secret(env._me) end
	N.Add(env, "nameplate1", { spellTarget = "Valerin" })
	N.Target(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	local who, you = plate.castWho, plate.castYou
	assert(who and you, "a targeted cast on the selected plate makes the who text")
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin", "the who text names the spell's target")
	local r, g, b = K.Theme.ClassColorForWidget(env.Secret("MAGE"))
	local c = W.LastCall(who, "SetTextColor")
	assert(near(plain(env, c[1]), plain(env, r)) and near(plain(env, c[2]), plain(env, g)) and near(plain(env, c[3]), plain(env, b)), "in the target's class colour")
	local alpha = W.LastCall(you, "SetAlphaFromBoolean")
	assert(alpha and env.issecretvalue(alpha[1]) and alpha[2] == 1 and alpha[3] == 0, "YOU shows only when the engine says the player is the target")
	assert(W.LastCall(who, "SetAlphaFromBoolean")[2] == 0, "and the name gives way to it")
	assert(who:IsShown(), "the who text shows on its own line under the spell name")
	local place = W.LastCall(who, "SetPoint")
	assert(place[1] == "TOPLEFT" and place[2] == plate.castBar and place[5] < W.LastCall(plate.castName, "SetPoint")[5], "below the spell name")
	assert(plate.castMark == nil, "Pummel ready: no ready mark")

	-- Pummel recharging with readable times: the bar dims and the mark sits where Pummel comes back.
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	local mark = assert(plate.castMark, "a recharging interrupt marks the running cast")
	assert(mark:IsShown(), "the mark shows")
	local p = W.LastCall(mark, "SetPoint")
	assert(p[1] == "LEFT" and near(p[4], K.Widgets.Snap(plate, 0.5 * plate.castBarOpts.width)), "halfway along a 1 to 3 second cast for a 2 second ready time")
	assert(mark:GetAlpha() == 1, "an interruptible cast shows the mark")
	env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1")
	assert(mark:GetAlpha() == 0, "an uninterruptible cast hides it under the shield")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = env.Secret(0), duration = env.Secret(2), isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not mark:IsShown(), "secret cooldown times give no mark")
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 5, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not mark:IsShown(), "an interrupt back only after the cast ends gives no mark")
	local wait = assert(plate.castWait, "#747 review 4: an interrupt back after the cast ends still shows its time left")
	assert(tostring(W.LastCall(wait, "SetText")[1]) == "4" and wait:GetAlpha() == 1, "the whole seconds left, 3.5 s rounded up")
	env._time = 2.6
	env.RunTimers()
	assert(tostring(W.LastCall(wait, "SetText")[1]) == "3", "and it counts down")
	env._time = 1.5
	env._cooldowns[PUMMEL] = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not mark:IsShown() and W.LastCall(wait, "SetText")[1] == "", "Pummel ready again: the mark and the time go")

	-- Who interrupted it, in their class colour; the player's own kick says YOU.
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1", "cast-guid", 133, "Player-2")
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin" and you:GetAlpha() == 0, "the interrupter's name shows")
	r, g, b = K.Theme.ClassColorForWidget("MAGE")
	c = W.LastCall(who, "SetTextColor")
	assert(near(c[1], r) and near(c[2], g) and near(c[3], b), "in the interrupter's class colour")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1", "cast-guid", 133, "Player-1")
	assert(you:GetAlpha() == 1 and who:GetAlpha() == 0, "the player's own interrupt says YOU")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1", "cast-guid", 133, env.Secret("Player-2"))
	clean(env, K, "nameplates: a secret interrupter GUID goes through the GUID APIs")

	-- #747 review 8: with the old Spell target option on too, its place gets the class colour and YOU.
	K.Options.Write("Nameplates", "cast.showTarget", true)
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	assert(W.LastCall(plate.castName, "SetText") and not W.LastCall(plate.castName, "SetFormattedText"), "Spell target with the name: the name keeps only the spell")
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin" and who:IsShown(), "and the target shows class coloured on the line under it")
	K.Options.Write("Nameplates", "cast.targetPlace", "RIGHT")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	assert(W.LastCall(plate.castTarget, "SetText")[1] == "" and W.LastCall(who, "SetAllPoints")[1] == plate.castTarget, "Spell target on the bar: who and YOU take its place")
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin" and who:IsShown() and you:IsShown(), "class coloured, with YOU")
	K.Options.Write("Nameplates", "cast.targetPlace", "")
	K.Options.Write("Nameplates", "cast.showTarget", false)
	K.Options.Write("Nameplates", "cast.caster", false)
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	assert(not who:IsShown() and W.LastCall(who, "SetText")[1] == "", "off: no who text")
	clean(env, K, "nameplates")
end

-- Off from the start builds nothing on plates.
do
	local env, K, ns = N.New({ playerClass = "WARRIOR", known = { [PUMMEL] = true } })
	K.Options.Write("Nameplates", "cast.caster", false)
	env.UnitShouldDisplaySpellTargetName = function() return true end
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	N.Add(env, "nameplate1", { spellTarget = "Valerin" })
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 1, notInterruptible = false })
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.castWho == nil and plate.castMark == nil, "off makes no who text and no mark")
	clean(env, K, "nameplates off")
end

-- #747 review 5, 6 and 3 on plates.
do
	local env, K, ns = N.New({ playerClass = "WARRIOR", known = { [PUMMEL] = true } })
	local lookups = 0
	env.UnitShouldDisplaySpellTargetName = function() return true end
	env.UnitSpellTargetName = function() lookups = lookups + 1; return "Thrall" end
	N.Add(env, "nameplate1", { name = "Ogre" })
	N.Cast(env, "nameplate1", { name = "Spell", text = "Spell", texture = 1 })
	local plate = ns.Plates.Get("nameplate1")
	assert(not plate.castName:IsShown() and lookups == 0 and plate.castWho == nil, "an unselected plate with its spell name hidden asks for no target and builds no text")
	N.Target(env, "nameplate1")
	assert(lookups == 1 and plate.castWho and plate.castWho:IsShown(), "selecting the caster mid-cast names the target")
	local function width(t) local c = W.LastCall(t, "SetWidth"); return c and c[1] end
	assert(width(plate.castWho) == K.Widgets.Snap(plate, plate.castBarOpts.width) and width(plate.castYou) == width(plate.castWho), "who and YOU are bounded by the bar")
	K.Options.Write("Nameplates", "cast.nameAlign", "RIGHT")
	N.Cast(env, "nameplate1", { name = "Spell", text = "Spell", texture = 1 })
	assert(width(plate.castName) == width(plate.castWho) and width(plate.castYou) == width(plate.castWho), "right aligned: the spell, who and YOU share one width")
	assert(W.LastCall(plate.castWho, "SetJustifyH")[1] == "RIGHT" and W.LastCall(plate.castYou, "SetJustifyH")[1] == "RIGHT", "and one alignment")
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = true, startTime = 0, duration = 1.5, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(K.Interrupt.ready == true, "the cooldown event proves the GCD")
	ns.Cast.WatchInterrupt()
	assert(K.Interrupt.ready == true, "finding the spell again keeps the event's GCD answer")
	clean(env, K, "plates review")
end

-- Unit frames ----------------------------------------------------------------------------------------------

local function setup(e)
	guids(e)
	e.UnitShouldDisplaySpellTargetName = function() return e._castTarget ~= nil end
	e.UnitSpellTargetName = function() return e._castTarget end
	e.UnitSpellTargetClass = function() return e.Secret("MAGE") end
	e._me = false
	e.PlayerIsSpellTarget = function() return e.Secret(e._me) end
	e._cooldowns = {}
	e.C_SpellBook = { IsSpellKnown = function(id) return id == PUMMEL end }
	e.C_Spell.GetSpellCooldown = function(id) return e._cooldowns[id] or { startTime = 0, duration = 0, isEnabled = true, isActive = false } end
end

local function activeBar(ns, unit)
	for _, list in ipairs({ ns.CastBars.Get(unit) or {}, ns.CastBars.Inline(unit) or {} }) do
		for _, cb in ipairs(list) do
			if cb.active then return cb end
		end
	end
end

local function targetBar(hud)
	local env, K, ns = U.New({ frames = hud == "frames", setup = setup })
	U.SetUnit(env, "player", { name = "Kstyle", class = "WARRIOR", level = 60, health = 100, healthMax = 100 })
	env.FireEvent("SPELLS_CHANGED")
	assert(not K.Interrupt.running, hud .. ": idle unit frames do not listen for the interrupt")
	U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	local tcb = (ns.CastBars.Inline("target") or ns.CastBars.Get("target"))[1]
	if not tcb.caster or not tcb.unit then tcb = ns.Frames.Get("target").views[1].castbar end
	local function cast(locked)
		env._units.target.cast = { name = "Shadow Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686, notInterruptible = locked }
		env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
	end
	env._castTarget = "Valerin"
	return env, K, ns, tcb, cast
end

local function frames(hud)
	local env, K, ns, tcb, cast = targetBar(hud)
	cast(false)
	assert(tcb.active, hud .. ": the target casts")
	assert(K.Interrupt.running and K.Interrupt.spell == PUMMEL, hud .. ": a target cast asks for the interrupt")
	local who, you = tcb.whoText, tcb.youText
	assert(who and who:IsShown() and plain(env, W.LastCall(who, "SetText")[1]) == "Valerin", hud .. ": the who text names the target")
	assert(not U.Shown(env, tcb.text):find("Valerin", 1, true), hud .. ": the name keeps only the spell")
	assert(near(tcb.text:GetWidth(), K.Widgets.Snap(tcb.frame, tcb.textW * 0.58)), hud .. ": the spell name keeps the left share")
	assert(W.LastCall(you, "SetAlphaFromBoolean")[2] == 1, hud .. ": YOU waits on the secret answer")
	local br, bg, bb = tcb.pr, tcb.pg, tcb.pb
	local width0, slotted = tcb.textW, tcb.slot and tcb.slot + K.Widgets.Snap(tcb.frame, 2)

	-- Uninterruptible: the icon darkens under a shield glyph; the colour is the locked colour.
	cast(true)
	assert(tcb.glyph and tcb.glyph:GetAlpha() == 1, hud .. ": an uninterruptible cast shows the shield")
	assert((tcb.slot ~= nil) ~= tcb.iconFrame:IsShown(), hud .. ": the shield sits on the icon, or in a slot before the name when there is none")
	if tcb.slot then
		local p = W.LastCall(tcb.glyph, "SetPoint")
		assert(tcb.shade:GetAlpha() == 0 and p[1] == "RIGHT" and p[2] == tcb.text and p[3] == "LEFT", hud .. ": the glyph leads the spell name")
	else
		assert(tcb.shade:GetAlpha() == 0.6, hud .. ": the icon darkens under the glyph")
	end
	cast(false)
	assert(tcb.shade:GetAlpha() == 0 and tcb.glyph:GetAlpha() == 0, hud .. ": an interruptible cast has no shield")
	env._units.target.secretCast = true
	cast(false)
	assert(W.LastCall(tcb.glyph, "SetAlphaFromBoolean")[2] == 1, hud .. ": a secret flag goes to the engine")
	assert(who:IsShown(), hud .. ": a secret spell name keeps the who text, measured from the layout and not read back")
	env._units.target.secretCast = nil

	-- Pummel recharging: the fill dims and the mark sits where it comes back.
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	cast(false)
	assert(near(tcb.pr, br * 0.55) and near(tcb.pb, bb * 0.55), hud .. ": a recharging interrupt dims the fill")
	local mark = assert(tcb.mark, hud .. ": and marks the bar")
	assert(mark:IsShown() and mark:GetAlpha() == 1, hud .. ": the mark shows")
	env._cooldowns[PUMMEL] = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not mark:IsShown() and near(tcb.pr, br) and near(tcb.pg, bg), hud .. ": Pummel ready: full colour, no mark")
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 5, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	local wait = assert(tcb.wait, hud .. ": #747 review 4: an interrupt back after the cast ends shows its time left")
	assert(not mark:IsShown() and tostring(W.LastCall(wait, "SetText")[1]) == "4" and wait:GetAlpha() == 1, hud .. ": the whole seconds left, in the shield's place")
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = true, startTime = 0, duration = 1.5, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(K.Interrupt.ready == true and W.LastCall(wait, "SetText")[1] == "", hud .. ": the cooldown event proves the GCD; no time left")
	ns.CastBars.Apply()
	assert(K.Interrupt.ready == true, hud .. ": #747 review 3: a restyle keeps the event's GCD answer")
	env._cooldowns[PUMMEL] = nil

	-- Who interrupted it.
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-1", 686, "Player-2", 1)
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin" and who:IsShown(), hud .. ": the interrupter's name shows")
	assert(tcb.shade:GetAlpha() == 0, hud .. ": an interrupted cast has no shield")
	clean(env, K, hud)

	-- #747 review 2: a restricted channel's secret interrupter still reads as interrupted, looked up by its GUID.
	local lookups, name = 0, env.UnitNameFromGUID
	env.UnitNameFromGUID = function(guid) lookups = lookups + 1; return name(env.Reveal(guid)) end
	env._units.target.cast = nil
	env._units.target.channel = { name = "Drain Life", texture = 1, start = 1000, finish = 3000, spellID = 689, barID = 2 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "Cast-2", 689, 2)
	env._units.target.channel = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", "Cast-2", 689, env.Secret("Player-2"), 2)
	assert(tcb.error and not tcb.landed and lookups == 1, hud .. ": a secret interrupter ends the channel as interrupted")
	assert(plain(env, W.LastCall(who, "SetText")[1]) == "Valerin" and who:IsShown(), hud .. ": and names them")
	env.UnitNameFromGUID = name

	-- #747 review 9: without SetAlphaFromBoolean the secret cues fall back to their plain look.
	for _, region in ipairs({ who, you, tcb.glyph, tcb.shade, tcb.wait, mark }) do region.SetAlphaFromBoolean = false end
	env._units.target.secretCast = true
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	cast(false)
	assert(who:GetAlpha() == 1 and you:GetAlpha() == 0 and tcb.glyph:GetAlpha() == 0, hud .. ": the name shows, YOU and the shield stay hidden")
	env._units.target.secretCast, env._cooldowns[PUMMEL] = nil, nil
	for _, region in ipairs({ who, you, tcb.glyph, tcb.shade, tcb.wait, mark }) do region.SetAlphaFromBoolean = nil end
	clean(env, K, hud .. " no boolean alpha")

	-- Off restores the old bar: no who text, no dim, the name's full room.
	K.Options.Write("UnitFrames", "castCaster", false)
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(K.Interrupt.ready == nil and not K.Interrupt.running, hud .. ": off stops asking for the interrupt")
	cast(false)
	assert(not who:IsShown() and near(tcb.pr, br) and not mark:IsShown() and tcb.glyph:GetAlpha() == 0, hud .. ": off restores the old bar")
	assert(tcb.slot == nil and near(W.LastCall(tcb.text, "SetWidth")[1], width0 + (slotted and slotted or 0)), hud .. ": off gives the spell name its slot back")
	clean(env, K, hud .. " off")
end

-- #747 review 8 and 7, on a target bar that never showed a secret name.
local function legacy(hud)
	local env, K, _, tcb, cast = targetBar(hud)
	cast(false)
	local who = tcb.whoText
	-- #747 review 8: the old Spell target option's place gets the class colour and YOU too.
	K.Options.Write("UnitFrames", "target.castbarTarget", true)
	env.RunTimers()
	cast(false)
	assert(not U.Shown(env, tcb.text):find("Valerin", 1, true) and who:IsShown() and plain(env, W.LastCall(who, "SetText")[1]) == "Valerin", hud .. ": Spell target after the name: who takes it")
	K.Options.Write("UnitFrames", "target.castbarTargetPlace", "RIGHT")
	env.RunTimers()
	cast(false)
	assert(tcb.targetOn == "RIGHT" and W.LastCall(tcb.targetText, "SetText")[1] == "" and W.LastCall(who, "SetAllPoints")[1] == tcb.targetText, hud .. ": Spell target placed apart: who and YOU take its place")
	assert(who:IsShown() and plain(env, W.LastCall(who, "SetText")[1]) == "Valerin", hud .. ": class coloured")
	env._units.target.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-1", 686, "Player-2", 1)
	assert(who:IsShown() and W.LastCall(who, "SetAllPoints")[1] == tcb.targetText, hud .. ": and the interrupter shows there")
	K.Options.Write("UnitFrames", "target.castbarTargetPlace", "")
	K.Options.Write("UnitFrames", "target.castbarTarget", false)
	env.RunTimers()
	clean(env, K, hud .. " spell target")

	-- #747 review 7: Show full spell name fits the first cast to the shared width, as it does the second.
	K.Options.Write("UnitFrames", "target.castbarFit", true)
	env.RunTimers()
	env._castTarget = nil
	cast(false)
	local full, size = tcb.text:GetWidth(), tcb.nameStyle.size
	env._textWidth = function(_, _, s) return full * 0.61 * s / size end
	env._castTarget = "Valerin"
	cast(false)
	local first, cut = tcb.fitSize, tcb.text:IsTruncated()
	cast(false)
	assert(not cut and near(first, tcb.fitSize) and not tcb.text:IsTruncated(), hud .. ": the first cast fits as the second does")
	env._textWidth = nil
	K.Options.Write("UnitFrames", "target.castbarFit", false)
	env.RunTimers()
	clean(env, K, hud .. " fit")
end

frames("medallions")
frames("frames")
legacy("medallions")
legacy("frames")

-- #747 review 1: the Frames focus line keeps its design and names the target, the ready time and the interrupter.
do
	local env, K, ns = U.New({ frames = true, setup = setup })
	U.SetUnit(env, "player", { name = "Kstyle", class = "WARRIOR", level = 60, health = 100, healthMax = 100 })
	U.SetUnit(env, "focus", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	env.RunTimers()
	env._castTarget = "Valerin"
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false, startTime = 0, duration = 2, isEnabled = true }
	env._units.focus.channel = { name = "Drain Life", texture = 1, start = 1000, finish = 3000, spellID = 689 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "focus", "Cast-1", 689, 1)
	local cb = assert(activeBar(ns, "focus"), "the focus channels")
	assert(cb.line, "Frames focus uses the line")
	assert(cb.whoText and cb.whoText:IsShown() and plain(env, W.LastCall(cb.whoText, "SetText")[1]) == "Valerin", "the line names who the cast is aimed at")
	assert(W.LastCall(cb.bar, "SetPoint")[2] == cb.whoText, "and its bar starts after the name")
	assert(cb.mark and cb.mark:IsShown(), "the line marks where the interrupt is back")
	assert(tostring(W.LastCall(cb.wait, "SetText")[1]) == "1" and cb.wait:IsShown(), "with the time left where Casting reads")
	env._units.focus.channel = nil
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus", "Cast-1", 689, "Player-2", 1)
	assert(cb.error and cb.whoText:IsShown() and plain(env, W.LastCall(cb.whoText, "SetText")[1]) == "Valerin", "the line names who interrupted it")
	clean(env, K, "focus line")
end

-- Off from the start builds nothing on the unit frames and registers no interrupt events.
do
	local env, K, ns = U.New({ saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, castCaster = false } } }, characters = {}, layouts = {} } })
	assert(not K.Interrupt.running, "off: nothing asks for the interrupt")
	U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
	env._units.target.cast = { name = "Shadow Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686, notInterruptible = true }
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
	local tcb = ns.CastBars.Inline("target")[1]
	assert(tcb.whoText == nil and tcb.shade == nil and tcb.mark == nil, "off builds no who text, shield or mark")
	clean(env, K, "unit frames off")
end

print("cast caster ok")
