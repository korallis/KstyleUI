-- test-qol-parity-r3.lua: the EllesmereUI parity round 3a QoL options (the movement alert, target distance, the crosshair's out-of-range colour and the potion ready alert): a v0.2.8 profile keeps today's behaviour, each option works switched on and follows the events that change it, nothing depends on a switch it does not name, secret and missing answers take the safe path, and turning an option off puts back exactly what it changed.
local Q = dofile("Tools/regression/qol_env.lua")

local SPRINT2, SPRINT3, FIREBALL, INTELLECT, ATTACK, POTION = 8696, 11305, 133, 1459, 6603, 858

local function recorder(env, name, result)
	return function(...)
		env._calls[name] = env._calls[name] or {}
		table.insert(env._calls[name], { ... })
		if type(result) == "function" then return result(...) end
		return result
	end
end

local function stand(env)
	env.UnitClass = function() return "Rogue", env._class or "ROGUE", 4 end
	env._known, env._cd, env._range, env._target, env._hostile = { [SPRINT2] = true }, {}, {}, false, true
	env.C_SpellBook = {
		IsSpellKnown = function(id) return env._known[id] == true end,
		GetNumSpellBookSkillLines = function() return 1 end,
		GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 3 } end,
		GetSpellBookItemInfo = function(slot) return ({ { spellID = FIREBALL, itemType = 1, isPassive = false }, { spellID = INTELLECT, itemType = 1, isPassive = false }, { spellID = 99, itemType = 1, isPassive = true } })[slot] end,
	}
	env.Enum = env.Enum or {}
	env.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
	env.Enum.SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2 }
	env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
	env.Enum.DurationTextBindingProperty = { RemainingDuration = 0 }
	env.Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
	env.Enum.SecondsFormatterInterval = { Seconds = 0 }
	env.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
	local noop = setmetatable({}, { __index = function() return function() end end })
	env.C_StringUtil = { CreateSecondsFormatter = function() return setmetatable({}, { __index = noop }) end }
	env.C_Spell = {
		GetSpellName = function(id) return ({ [SPRINT2] = "Sprint", [SPRINT3] = "Sprint", [2983] = "Sprint" })[id] end,
		GetSpellTexture = function() return 132307 end,
		GetSpellCooldown = function(id) return env._cd[id] or { isActive = false, isEnabled = true, startTime = 0, duration = 0 } end,
		GetSpellCooldownDuration = function(id) return env._cd[id] and { spell = id } or nil end,
		GetSpellInfo = function(id) return ({ [FIREBALL] = { minRange = 0, maxRange = 35 }, [INTELLECT] = { minRange = 0, maxRange = 30 } })[id] end,
		IsSpellHarmful = function(id) return id == FIREBALL end,
		IsSpellHelpful = function(id) return id == INTELLECT end,
		IsSpellInRange = function(id) return env._range[id] end,
	}
	env.C_DurationUtil = { CreateDurationTextBinding = function()
		local binding = { calls = {} }
		for _, method in ipairs({ "SetFontString", "SetTextFormat", "SetDuration", "SetEnabled" }) do
			binding[method] = function(self, ...) self.calls[#self.calls + 1] = { method, ... }; self[method .. "Arg"] = ... end
		end
		return binding
	end }
	env.C_VoiceChat = {
		GetTtsVoices = function() return { { voiceID = 5, name = "Voice A" }, { voiceID = 7, name = "Voice B" } } end,
		SpeakText = recorder(env, "SpeakText"),
	}
	env.UnitExists = function(unit) return unit == "target" and env._target end
	env.UnitCanAttack = function() return env._hostile end
	env.NUM_BAG_SLOTS = 4
	env._bag = {}
	env.C_Container = {
		GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
		GetContainerItemInfo = function(bag, slot) return bag == 0 and env._bag[slot] or nil end,
		GetItemCooldown = function() if env._potionCd then return unpack(env._potionCd) end end,
	}
	local instant = env.C_Item.GetItemInfoInstant
	env.C_Item.GetItemInfoInstant = function(id)
		if id == POTION then return id, "Consumable", "Potion", "", 134830, 0, 1 end
		return instant(id)
	end
end

local function boot(settings)
	local saved = { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = stand })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function near(a, b) return math.abs(a - b) < 0.01 end

local function watched(env, event)
	local n = 0
	for _, frame in ipairs(env._frames) do
		if not frame._blizzard and frame:IsEventRegistered(event) then n = n + 1 end
	end
	return n
end

local function cooling(env, id, gcd)
	env._cd[id] = { isActive = true, isEnabled = true, isOnGCD = gcd == true, startTime = env.Secret(100), duration = env.Secret(120) }
	env.FireEvent("SPELL_UPDATE_COOLDOWN", id)
	env.RunTimers()
end

local function slot(ns, i)
	local _, slots = ns.MoveFrame()
	return slots[i or 1]
end

local function color(fs)
	local r, g, b = fs:GetTextColor()
	return { r = r, g = g, b = b }
end

local function painted(texture)
	for i = #texture._calls, 1, -1 do
		local call = texture._calls[i]
		if call.method == "SetColorTexture" then return { r = call.args[1], g = call.args[2], b = call.args[3] } end
	end
end

local function same(a, b) return near(a.r, b.r) and near(a.g, b.g) and near(a.b, b.b) end

-- Defaults: a v0.2.8 profile reads every new key as today's behaviour, builds nothing, watches nothing and keeps the crosshair's colour.
do
	local env, K, ns = boot({ enabled = true, crosshair = "normal" })
	for key, value in pairs({ potionAlert = false, moveAlert = false, moveCombat = false, moveMode = "text", moveDecimal = false, moveBarIcon = true, moveBarText = true,
		moveClass = false, moveSound = "none", moveVoice = -1, moveVolume = 100, rangeText = false, rangeFormat = "range", rangeAlign = "CENTER", crosshairRange = false,
		crosshairMelee = false, moveSprint = true, moveTexture = "Flat" }) do
		assert(ns.Get(key) == value, key .. " keeps today's behaviour by default")
	end
	assert(not ns.MoveFrame() and env.LiveTickers() == 0, "no movement alert is built and nothing polls")
	for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED" }) do
		assert(watched(env, event) == 0, event .. " stays unwatched")
	end
	local cross = ns.AidFrames()
	local r, g, b = K.Tokens.Color("textEmphasis")
	assert(same(painted(cross.h), { r = r, g = g, b = b }), "the crosshair keeps its colour")
	env._target, env._range[FIREBALL] = true, false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(same(painted(cross.h), { r = r, g = g, b = b }), "an out-of-range target does not tint it while the option is off")
	clean(env, K)
end

-- Movement alert, switched on: a real cooldown shows with its duration bound to the text, the global cooldown alone does not, and the poll ends it with a sound.
do
	local env, K, ns = boot()
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveSound", "warning")
	local holder = ns.MoveFrame()
	assert(holder:IsShown() and not (slot(ns) and slot(ns):IsShown()), "nothing shows while every spell is ready")
	cooling(env, SPRINT2, true)
	assert(not (slot(ns) and slot(ns):IsShown()) and env.LiveTickers() == 0, "the global cooldown alone shows nothing")
	cooling(env, SPRINT2)
	local s = slot(ns)
	assert(s:IsShown() and s.text:IsShown() and s.binding.SetTextFormatArg == "Sprint {}" and s.binding.SetDurationArg.spell == SPRINT2, "a secret cooldown counts down through the engine")
	assert(s.binding.SetEnabledArg == true and s.binding.SetFontStringArg == s.text, "the binding drives the text")
	assert(env.LiveTickers() == 1, "a poll watches for the end")
	assert(same(color(s.text), ns.Get("moveColor")), "the text takes the alert colour")
	env._cd[SPRINT2] = nil
	env.RunTickers()
	assert(not s:IsShown() and s.binding.SetEnabledArg == false, "a ready spell leaves the alert")
	assert(env.LiveTickers() == 0, "the poll stops")
	assert(#Q.Calls(env, "PlaySound") == 1 and Q.Calls(env, "PlaySound")[1][1] == env.SOUNDKIT.RAID_WARNING, "the ready sound plays once")
	env.RunTickers()
	assert(#Q.Calls(env, "PlaySound") == 1, "no second sound")
	-- An unrelated spell's cooldown event does no work.
	local formats = #s.binding.calls
	env.FireEvent("SPELL_UPDATE_COOLDOWN", 12345)
	assert(#s.binding.calls == formats, "other spells' cooldowns are ignored")
	clean(env, K)
end

-- Modes, sizes, colours, the decimal formatter and the bar's parts, each switched on.
do
	local env, K, ns = boot()
	Q.Write(env, K, "moveAlert", true)
	cooling(env, SPRINT2)
	Q.Write(env, K, "moveMode", "timeFirst")
	assert(slot(ns).binding.SetTextFormatArg == "{} Sprint", "time first")
	Q.Write(env, K, "moveMode", "time")
	assert(slot(ns).binding.SetTextFormatArg == "{}", "time only")
	local short = slot(ns).formatter
	Q.Write(env, K, "moveDecimal", true)
	assert(slot(ns).formatter ~= short, "tenths use the decimal formatter")
	Q.Write(env, K, "moveSize", 40)
	local _, size = slot(ns).text:GetFont()
	assert(near(size, 40 * K.Theme.FontScale()), "the text size applies")
	Q.Write(env, K, "moveClass", true)
	assert(same(color(slot(ns).text), (function() local r, g, b = K.Theme.ClassColor("ROGUE"); return { r = r, g = g, b = b } end)()), "class colour")
	Q.Write(env, K, "moveMode", "icon")
	local s = slot(ns)
	assert(s.icon:IsShown() and not s.text:IsShown(), "the icon replaces the text")
	assert(s.binding == nil or s.binding.SetEnabledArg == false, "the text binding stops in icon mode")
	Q.Write(env, K, "moveIconSize", 64)
	assert(near(s.icon:GetWidth(), 64) and near(ns.MoveFrame():GetHeight(), 64), "the icon size applies and the element follows it")
	Q.Write(env, K, "moveMode", "bar")
	assert(s.bar:IsShown() and not s.icon:IsShown() and s.bar.art:IsShown(), "the bar shows with its icon")
	assert(s.binding.SetFontStringArg == s.bar.label and s.binding.SetTextFormatArg == "Sprint {}", "the bar's label counts down")
	local timer
	for _, call in ipairs(s.bar._calls) do if call.method == "SetTimerDuration" then timer = call.args end end
	assert(timer and timer[1].spell == SPRINT2 and timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "the bar empties with the duration")
	Q.Write(env, K, "moveBarIcon", false)
	assert(not s.bar.art:IsShown() and near(s.bar:GetWidth(), s:GetWidth()), "no icon: the bar takes the whole width")
	Q.Write(env, K, "moveBarText", false)
	assert(s.binding.SetTextFormatArg == "Sprint", "no time on the bar: the name alone")
	Q.Write(env, K, "moveTexture", "Smooth")
	assert(s.bar.textureKey == "Smooth", "the bar texture applies")
	clean(env, K)
end

-- Combat only, speech, the per-spell switch, a new rank and turning off.
do
	local env, K, ns = boot()
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveCombat", true)
	cooling(env, SPRINT2)
	assert(not (slot(ns) and slot(ns):IsShown()), "combat only: hidden out of combat")
	env.SetCombat(true)
	assert(slot(ns):IsShown(), "shown in combat")
	Q.Write(env, K, "moveVoice", 7)
	Q.Write(env, K, "moveVolume", 40)
	Q.Write(env, K, "moveSound", "ready")
	env._cd[SPRINT2] = nil
	env.RunTickers()
	local speak = Q.Calls(env, "SpeakText")
	assert(#speak == 1 and speak[1][1] == 7 and speak[1][2] == "Sprint" and speak[1][4] == 40, "speech says the name at the volume")
	assert(#Q.Calls(env, "PlaySound") == 0, "speech replaces the sound")
	env.SetCombat(false)
	cooling(env, SPRINT2)
	env._cd[SPRINT2] = nil
	env.RunTickers()
	assert(#Q.Calls(env, "SpeakText") == 1, "out of combat, a hidden alert stays silent")
	Q.Write(env, K, "moveCombat", false)
	Q.Write(env, K, "moveSprint", false)
	cooling(env, SPRINT2)
	assert(not (slot(ns) and slot(ns):IsShown()), "a switched-off spell is not counted")
	Q.Write(env, K, "moveSprint", true)
	env._known[SPRINT3] = true
	env.FireEvent("SPELLS_CHANGED")
	cooling(env, SPRINT3)
	assert(slot(ns):IsShown() and slot(ns).binding.SetDurationArg.spell == SPRINT3, "a new rank is tracked")
	Q.Write(env, K, "moveAlert", false)
	assert(not ns.MoveFrame():IsShown() and env.LiveTickers() == 0 and watched(env, "SPELL_UPDATE_COOLDOWN") == 0, "off: hidden, unwatched, no poll")
	assert(slot(ns).binding.SetEnabledArg == false, "off: the binding stops")
	clean(env, K)
end

-- Missing APIs take the safe path: no binding shows the name; no spell API tracks nothing; a class without movement spells gets a note.
do
	local env, K, ns = boot()
	env.C_DurationUtil = nil
	Q.Write(env, K, "moveAlert", true)
	cooling(env, SPRINT2)
	assert(slot(ns).text:GetText() == "Sprint", "names only without text bindings")
	env.C_Spell = nil
	Q.Write(env, K, "moveSize", 30)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not slot(ns):IsShown(), "no spell API: nothing is tracked")
	env._class = "PRIEST"
	local rows = ns.MoveRows(function() return false end)
	assert(#rows == 1 and rows[1].type == "note", "a class without movement spells gets a note")
	clean(env, K)
end

-- Target distance, switched on: the band from the spellbook, every format and alignment, the poll while a target exists, and secrets as unknown.
do
	local env, K = boot()
	Q.Write(env, K, "rangeText", true)
	assert(watched(env, "PLAYER_TARGET_CHANGED") == 1 and env.LiveTickers() == 0, "no target: no poll")
	local holder = K.Layout.Element("qol.range").frame
	env._target, env._range[ATTACK], env._range[FIREBALL] = true, false, true
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	assert(env.LiveTickers() == 1, "a target is polled")
	assert(holder.text:GetText() == "5-35", "melee is out, Fireball is in")
	Q.Write(env, K, "rangeFormat", "plus")
	assert(holder.text:GetText() == "5+", "lower bound")
	Q.Write(env, K, "rangeFormat", "min")
	assert(holder.text:GetText() == "5", "minimum")
	Q.Write(env, K, "rangeFormat", "range")
	env._range[FIREBALL] = false
	env.RunTickers()
	assert(holder.text:GetText() == "35+", "beyond every check: the last band's lower end")
	env._range[FIREBALL] = env.Secret(true)
	env._range[ATTACK] = env.Secret(false)
	env.RunTickers()
	assert(holder.text:GetText() == "", "secret answers count as unknown")
	env._hostile, env._range[INTELLECT] = false, true
	env.RunTickers()
	assert(holder.text:GetText() == "0-30", "a friendly target uses helpful spells")
	Q.Write(env, K, "rangeAlign", "RIGHT")
	local point = holder.text:GetPoint(1)
	assert(point == "RIGHT" and holder.text:GetJustifyH() == "RIGHT", "the text lines up to the right")
	Q.Write(env, K, "rangeSize", 30)
	local _, size = holder.text:GetFont()
	assert(near(size, 30 * K.Theme.FontScale()), "the distance size applies")
	env._target = false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(env.LiveTickers() == 0 and holder.text:GetText() == "", "no target: blank and the poll stops")
	Q.Write(env, K, "rangeText", false)
	assert(not holder:IsShown() and watched(env, "PLAYER_TARGET_CHANGED") == 0, "off: hidden and unwatched")
	clean(env, K)
end

-- The crosshair's out-of-range colour works without the distance text, follows the target, honours the melee cutoff and turns back off.
do
	local env, K, ns = boot({ enabled = true, crosshair = "normal" })
	Q.Write(env, K, "crosshairRange", true)
	local cross = ns.AidFrames()
	local hostile, plain = ns.Get("crosshairRangeColor"), { K.Tokens.Color("textEmphasis") }
	local function tint() return painted(cross.h) end
	env._target, env._range[ATTACK], env._range[FIREBALL] = true, false, false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(same(tint(), hostile), "out of reach: the crosshair turns the out-of-range colour")
	env._range[FIREBALL] = true
	env.RunTickers()
	assert(same(tint(), { r = plain[1], g = plain[2], b = plain[3] }), "back in reach")
	Q.Write(env, K, "crosshairMelee", true)
	assert(same(tint(), hostile), "melee cutoff: beyond melee is out of range")
	Q.Write(env, K, "crosshairRangeColor", { r = 0, g = 1, b = 0 })
	assert(same(tint(), { r = 0, g = 1, b = 0 }), "the colour applies")
	Q.Write(env, K, "crosshairRange", false)
	assert(same(tint(), { r = plain[1], g = plain[2], b = plain[3] }) and env.LiveTickers() == 0, "off: the colour comes back and the poll stops")
	clean(env, K)
end

-- Potion ready alert: a potion's cooldown end flashes once; the global cooldown, a held cooldown and secrets are ignored; turning off cancels a waiting flash.
do
	local env, K, ns = boot()
	env._bag = { { itemID = 4 }, { itemID = POTION } }
	Q.Write(env, K, "potionAlert", true)
	assert(watched(env, "BAG_UPDATE_COOLDOWN") == 1, "watched while on")
	env.Release()
	env._potionCd = { 100, 1, 1 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env._potionCd = { 100, 120, 0 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env._potionCd = { env.Secret(100), env.Secret(120), 1 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#env._held == 0, "the global cooldown, a held cooldown and secrets wait for nothing")
	env._potionCd = { 100, 120, 1 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#env._held == 1, "one wait per cooldown")
	env.Release()
	local flash = ns.noticeLines.flash
	assert(flash and flash.wanted and flash.text:GetText() == "Potion ready", "the potion flash shows")
	env.Release()
	env._bag = {}
	env.FireEvent("BAG_UPDATE_DELAYED")
	env._potionCd = { 300, 120, 1 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#env._held == 1, "the last potion seen stays known after the bags run out")
	Q.Write(env, K, "potionAlert", false)
	env.Release()
	assert(not ns.noticeLines.flash.wanted, "off: a waiting flash is cancelled")
	assert(watched(env, "BAG_UPDATE_COOLDOWN") == 0, "off: unwatched")
	clean(env, K)
end

-- The page: every new row exists and writes, and the live preview shows each option.
do
	local env, K, ns = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(preview.lines[4]:GetText() == "Potion ready" and preview.lines[4]:GetAlpha() < 1, "an off potion alert is dimmed")
	assert(preview.move:GetAlpha() < 1 and preview.move.text:GetText() == "Sprint 2s", "the movement sample, dimmed")
	assert(preview.range:GetAlpha() < 1 and preview.range.text:GetText() == "30-35", "the distance sample, dimmed")
	for key, value in pairs({ potionAlert = true, moveAlert = true, moveDecimal = true, rangeText = true, rangeFormat = "plus", crosshair = "thin", crosshairRange = true,
		moveCombat = true, moveSound = "ready", moveVoice = 5, moveVolume = 50, moveClass = true, crosshairMelee = true, rangeAlign = "LEFT", rangeSize = 20, moveSize = 30 }) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
		Q.Write(env, K, key, value)
	end
	preview:Refresh()
	assert(preview.lines[4]:GetAlpha() == 1 and preview.move:GetAlpha() == 1 and preview.range:GetAlpha() == 1, "switched on, the samples light")
	assert(preview.move.text:GetText() == "Sprint 2.4", "the decimal sample")
	assert(preview.range.text:GetText() == "30+" and preview.range.text:GetJustifyH() == "LEFT", "the format and alignment samples")
	assert(same(painted(preview.cross.h), ns.Get("crosshairRangeColor")), "the crosshair sample shows the out-of-range colour")
	Q.Write(env, K, "moveMode", "bar")
	preview:Refresh()
	assert(preview.move.bar:IsShown() and preview.move.bar.label:GetText() == "Sprint 2.4", "the bar sample")
	Q.Write(env, K, "moveMode", "icon")
	preview:Refresh()
	assert(preview.move.icon:IsShown(), "the icon sample")
	for _, key in ipairs({ "moveTexture", "moveBarIcon", "moveBarText", "moveIconSize", "moveColor", "moveMode", "crosshairRangeColor", "moveSprint" }) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
	end
	clean(env, K)
end

-- Review of PR #639: each block replays a probe that showed a defect while the option was on.
-- Range: a spell with a minimum range says nothing about the near side of it, and a spell not yet learned never stands in for a learned one.
do
	local env, K, ns = boot({ enabled = true, crosshair = "normal" })
	env.C_Spell.GetSpellInfo = function(id) if id == FIREBALL then return { minRange = 8, maxRange = 25 } end end
	env._target, env._range[FIREBALL], env._range[ATTACK] = true, false, false
	Q.Write(env, K, "rangeText", true)
	Q.Write(env, K, "crosshairRange", true)
	local text = K.Layout.Element("qol.range").frame.text
	assert(text:GetText() == "5+" and not ns.rangeOut, "6 yards, inside a spell's minimum range: beyond melee, not beyond the spell")
	env.C_Spell.GetSpellInfo = function(id) return ({ [FIREBALL] = { minRange = 8, maxRange = 35 }, [INTELLECT] = { minRange = 0, maxRange = 30 } })[id] end
	env.C_Spell.IsSpellHarmful = function() return true end
	env.FireEvent("SPELLS_CHANGED")
	env._range[INTELLECT] = false
	env.RunTickers()
	assert(text:GetText() == "35+" and ns.rangeOut, "beyond a spell with no minimum, a longer spell's false answer means beyond it")
	clean(env, K)
end
do
	local env, K = boot()
	env.C_SpellBook.GetSpellBookItemInfo = function(i) return { spellID = i == 1 and 999 or FIREBALL, itemType = i == 1 and 2 or 1, isPassive = false } end
	env.C_Spell.GetSpellInfo = function() return { minRange = 0, maxRange = 35 } end
	env.C_Spell.IsSpellHarmful = function() return true end
	env._target, env._range[FIREBALL], env._range[ATTACK] = true, true, false
	Q.Write(env, K, "rangeText", true)
	assert(K.Layout.Element("qol.range").frame.text:GetText() == "5-35", "a spell not yet learned never stands in for a learned one")
	clean(env, K)
end

-- Movement alert: switching it on mid global cooldown shows nothing and plays nothing; a readable real cooldown still shows at once.
do
	local env, K, ns = boot()
	env._cd[SPRINT2] = { isActive = true, isEnabled = true, startTime = 100, duration = 1.5 }
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveSound", "ready")
	assert(not (slot(ns) and slot(ns):IsShown()), "switched on mid global cooldown: no row")
	env._cd[SPRINT2] = nil
	env.RunTickers()
	assert(#Q.Calls(env, "PlaySound") == 0, "and no ready sound when it ends")
	env._cd[SPRINT2] = { isActive = true, isEnabled = true, startTime = 100, duration = 120 }
	Q.Write(env, K, "moveSize", 20)
	assert(slot(ns):IsShown(), "a readable real cooldown shows at once")
	clean(env, K)
end

-- Movement alert: unchanged cooldown events rebind nothing; with no text binding, Time left shows the spell's name.
do
	local env, K, ns = boot()
	Q.Write(env, K, "moveAlert", true)
	cooling(env, SPRINT2)
	local s = slot(ns)
	local before = #s.binding.calls
	for _ = 1, 10 do env.FireEvent("SPELL_UPDATE_COOLDOWN") end
	assert(#s.binding.calls == before, "ten unchanged all-spell events rebind nothing")
	clean(env, K)
	env, K, ns = boot()
	env.C_DurationUtil = nil
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveMode", "time")
	cooling(env, SPRINT2)
	assert(slot(ns).text:GetText() == "Sprint", "Time left without a binding shows the name")
	clean(env, K)
end

-- The preview dims the movement sample when no class spell is switched on, or the class has none.
do
	local env, K = boot()
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveSprint", false)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(preview.move:GetAlpha() < 1, "its only spell off: the movement sample dims")
	env._class = "PRIEST"
	Q.Write(env, K, "moveSprint", true)
	preview:Refresh()
	assert(preview.move:GetAlpha() < 1, "a class without movement spells: the sample dims")
	clean(env, K)
end

-- Potion ready alert: empty slots and a known potion ask nothing; an unknown or held cooldown never flashes.
do
	local env, K, ns = boot()
	env.C_Container.GetContainerNumSlots = function() return 16 end
	local n, instant = 0, env.C_Item.GetItemInfoInstant
	env.C_Item.GetItemInfoInstant = function(id) n = n + 1; return instant(id) end
	Q.Write(env, K, "potionAlert", true)
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(n == 0, "80 empty slots ask nothing")
	env._bag = { { itemID = POTION } }
	env.FireEvent("BAG_UPDATE_DELAYED")
	n = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(n == 0, "a known potion is not looked for again")
	env.Release()
	env._potionCd = { 100, 120, env.Secret(0) }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#env._held == 0, "an unknown enable waits for nothing")
	env._potionCd = { 100, 120, 1 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env._potionCd = { 100, 120, 0 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env.Release()
	assert(not (ns.noticeLines.flash and ns.noticeLines.flash.wanted), "a cooldown put on hold does not flash")
	clean(env, K)
end

-- Layout scales both elements.
do
	local env, K = boot()
	Q.Write(env, K, "rangeText", true)
	Q.Write(env, K, "moveAlert", true)
	assert(K.Layout.Set("qol.range", "scale", 1.2) and K.Layout.Set("qol.movement", "scale", 1.2), "both elements take Layout's scale")
	clean(env, K)
end

-- Movement alert placement: the bars clear a lowered, longer crosshair on every screen size, and the largest text fits its bar.
do
	local scene = dofile("Tools/render/scene.lua")
	local cross = { crosshair = "normal", crosshairY = -24, crosshairVLength = 60, crosshairBorder = 1, moveAlert = true, moveMode = "bar" }
	for _, wh in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K, ns = Q.New({ width = wh[1], height = wh[2], uiScale = 768 / 1080, size = "auto", setup = stand })
		Q.Enable(env, K)
		for _, key in ipairs({ "crosshair", "crosshairY", "crosshairVLength", "crosshairBorder", "moveAlert", "moveMode" }) do Q.Write(env, K, key, cross[key]) end
		cooling(env, SPRINT2)
		local _, cy, _, ch = scene.Rect(env, ns.AidFrames())
		local _, sy, _, sh = scene.Rect(env, ns.MoveFrame())
		assert(cy + ch <= sy or sy + sh <= cy, wh[1] .. "x" .. wh[2] .. ": the movement bars clear the crosshair")
		clean(env, K)
	end
	local env, K, ns = boot({ enabled = true })
	env._textWidth = function(t, f, z) return scene.TextWidth(t, z, f) end
	Q.Write(env, K, "moveAlert", true)
	Q.Write(env, K, "moveMode", "bar")
	cooling(env, SPRINT2)
	Q.Write(env, K, "moveSize", 72)
	local s = slot(ns)
	s.bar.label:SetText("Feral Charge 28s")
	assert(s.bar.label:GetStringWidth() <= s.bar:GetWidth(), "the largest name and time fit the bar")
	clean(env, K)
end

print("qol parity round 3a ok")
