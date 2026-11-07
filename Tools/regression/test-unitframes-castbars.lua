-- test-unitframes-castbars.lua: cast bars run on duration objects through SetTimerDuration, pass secret cast data only to setters, and follow their settings.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local CastBars = ns.CastBars
assert(type(CastBars) == "table" and type(CastBars.Get) == "function", "ns.CastBars.Get is missing")

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function stopTimer(cb)
	cb.frame:SetScript("OnUpdate", nil)
end

-- The player and target cast bars are Layout elements; focus and boss bars sit inside their frames.
local elements = {}
for _, el in ipairs(K.Layout.Elements()) do
	elements[el.key] = el
end
for _, key in ipairs({ "unitframes.castbar.player", "unitframes.castbar.target" }) do
	local el = elements[key]
	assert(el and el.module == "UnitFrames" and el.opts.resizable, key .. " is a resizable element")
	assert(el.label == K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
end
assert(#CastBars.Get("player") == 1 and #CastBars.Get("target") == 1 and #CastBars.Get("focus") == 1 and #CastBars.Get("boss") == 5, "one cast bar per unit")
assert(CastBars.Get("targettarget") == nil and CastBars.Get("pet") == nil, "small frames have no cast bar")

-- A player cast: the duration object drives the bar; the icon goes through KstyleUI.Icons.
local player = CastBars.Get("player")[1]
assert(not player.frame:IsShown(), "no cast, no bar")
env._time = 1
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(player.frame:IsShown(), "a cast shows the bar")
local timer = W.LastCall(player.bar, "SetTimerDuration")
assert(timer and timer[1].finish == 3.5, "the bar runs on the cast's duration object")
assert(timer[3] == env.Enum.StatusBarTimerDirection.ElapsedTime, "a cast fills up")
assert(U.Shown(env, player.text) == "Frostbolt", "the spell name shows")
assert(W.LastCall(player.icon, "SetTexture")[1] == 135846, "the icon shows the spell's icon through KstyleUI.Icons")
env._time = 2
W.Tick(env, 0.1)
assert(U.Shown(env, player.timer) == "1.5", "the timer counts down: " .. U.Shown(env, player.timer))
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
settle()
assert(not player.frame:IsShown(), "a finished cast fades out")
assert(player.frame:GetScript("OnUpdate") == nil, "the timer stops with the cast")
noErrors("player cast")

-- An interrupted cast says so in the hostile colour, then fades.
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 2000, finish = 4500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 116)
assert(U.Shown(env, player.text) == K.L["Interrupted"], "an interrupt shows Interrupted")
local hr, hg, hb = K.Tokens.Color("hostile")
local color = W.LastCall(player.bar, "SetStatusBarColor")
assert(color[1] == hr and color[2] == hg and color[3] == hb, "in the hostile colour")
settle()
assert(not player.frame:IsShown(), "and fades after a moment")

-- A channel drains the bar.
env._units.player.channel = { name = "Arcane Missiles", texture = 136096, start = 5000, finish = 8000, spellID = 5143 }
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 5143)
timer = W.LastCall(player.bar, "SetTimerDuration")
assert(timer[3] == env.Enum.StatusBarTimerDirection.RemainingTime, "a channel drains")
env._units.player.channel = nil
env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 5143)
settle()
noErrors("channel")

-- A target's cast can be secret: every value reaches a widget setter untouched.
local target = CastBars.Get("target")[1]
U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, canAttack = true, secretCast = true,
	cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 } })
env.SetTarget(true)
assert(target.frame:IsShown(), "a target already casting shows its bar on PLAYER_TARGET_CHANGED")
assert(env.issecretvalue(W.LastCall(target.text, "SetText")[1]), "the secret spell name reaches SetText")
assert(env.issecretvalue(W.LastCall(target.icon, "SetTexture")[1]), "the secret icon reaches SetTexture, not KstyleUI.Icons")
local locked = W.LastCall(target.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(locked and env.issecretvalue(locked[1]), "a secret interruptible flag colours the bar from a boolean")
env._time = 2
W.Tick(env, 0.1)
assert(U.Shown(env, target.timer) == "1.8", "the timer shows a secret remaining time: " .. U.Shown(env, target.timer))
stopTimer(target)
U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 1, healthMax = 2, reaction = 2 })
env.SetTarget(true)
settle()
assert(not target.frame:IsShown(), "a new target that is not casting hides the bar")
noErrors("secret target cast")

-- A secret duration object cannot be read, but still drives the bar.
U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, secretCast = true, secretDuration = true,
	cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, spellID = 999 } })
env.SetTarget(true)
assert(env.issecretvalue(W.LastCall(target.bar, "SetTimerDuration")[1]), "the secret duration reaches SetTimerDuration")
W.Tick(env, 0.1)
assert(target.timer:IsShown() == false or U.Shown(env, target.timer) == "", "a secret duration shows no timer")
noErrors("secret duration")

-- A secret nil duration is no duration: the bar falls back without calling SetTimerDuration.
local timers = #W.Calls(target.bar, "SetTimerDuration")
U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, secretCast = true, nilDuration = true,
	cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, spellID = 999 } })
env.SetTarget(true)
assert(#W.Calls(target.bar, "SetTimerDuration") == timers, "a secret nil never reaches SetTimerDuration")
assert(target.frame:IsShown() and W.LastCall(target.bar, "SetValue")[1] == 1, "the bar shows full with the spell name")
noErrors("secret nil duration")

-- Focus and boss cast bars sit under their frame, inside the element.
local focusView = ns.Frames.Get("focus").views[1]
local focusBar = CastBars.Get("focus")[1]
local _, frameH = focusView.button:GetSize()
assert(math.abs(focusView.geometry.panel.h - (70 - 20 - 4)) < 1, "the focus frame leaves room for its cast bar: " .. focusView.geometry.panel.h)
local _, _, _, _, y = focusBar.frame:GetPoint(1)
assert(y < -40, "the focus cast bar sits under the frame")
assert(frameH == 70, "the focus button spans its element")
local bossView = ns.Frames.Get("boss").views[1]
assert(math.abs(bossView.geometry.panel.h - (58 - 10 - 2)) < 1, "each boss frame leaves room for its cast bar")

-- Settings.
K.Options.Write("UnitFrames", "player.castbarIcon", false)
assert(not player.iconFrame:IsShown(), "the icon can be switched off")
local _, _, _, bx = player.bar:GetPoint(1)
assert(math.abs(bx) < 1e-6, "and the bar takes its room")
K.Options.Write("UnitFrames", "player.castbarTimer", false)
K.Options.Write("UnitFrames", "player.castbarText", false)
assert(not player.timer:IsShown() and not player.text:IsShown(), "the timer and the spell name can be switched off")
K.Options.Write("UnitFrames", "player.castbarColor", "custom")
K.Options.Write("UnitFrames", "player.castbarCustom", { r = 0.5, g = 0.25, b = 1 })
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 9000, finish = 11500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", 116)
color = W.LastCall(player.bar, "SetStatusBarColor")
assert(color[1] == 0.5 and color[2] == 0.25 and color[3] == 1, "a custom bar colour applies")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-4", 116)
settle()
K.Options.Write("UnitFrames", "focus.castbarHeight", 30)
assert(math.abs(focusView.geometry.panel.h - (70 - 30 - 4)) < 1, "a taller focus cast bar takes room from the frame")
K.Options.Write("UnitFrames", "focus.castbar", false)
assert(math.abs(focusView.geometry.panel.h - 70) < 1, "without a cast bar the frame fills its element")
K.Options.Write("UnitFrames", "player.castbar", false)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 9000, finish = 11500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-5", 116)
assert(not player.frame:IsShown(), "a switched-off cast bar ignores casts")
env._units.player.cast = nil
noErrors("settings")

-- Blizzard's player cast bar hides while KstyleUI's is on.
env.RunTimers()
assert(not K.Safe.IsHidden(env.PlayerCastingBarFrame), "with KstyleUI's player cast bar off, Blizzard's stays")
K.Options.Write("UnitFrames", "player.castbar", true)
env.RunTimers()
assert(K.Safe.IsHidden(env.PlayerCastingBarFrame), "with it on, Blizzard's player cast bar hides")

-- A stale start event with no cast in progress shows nothing.
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-9", 116)
assert(not player.frame:IsShown(), "a start event without a cast keeps the bar hidden")

-- With a custom icon set on, the player's cast bar shows the custom icon; other units keep Blizzard's.
do
	local CUSTOM = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\135846.png"
	local ienv, IK, ins = U.New({
		saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true }, Icons = { enabled = true } } }, characters = {} },
		setup = function(e)
			e.C_AddOns = {
				LoadAddOn = function()
					e.KstyleUIIconData = { set = "A", icons = { [135846] = CUSTOM } }
					return true
				end,
				IsAddOnLoaded = function()
					return e.KstyleUIIconData ~= nil
				end,
			}
		end,
	})
	assert(IK.Icons.Resolve(135846) == CUSTOM, "the test icon set is active")
	local pcb = ins.CastBars.Get("player")[1]
	ienv._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
	ienv.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	assert(W.LastCall(pcb.icon, "SetTexture")[1] == CUSTOM, "the player's cast bar shows the custom icon")
	local tcb = ins.CastBars.Get("target")[1]
	U.SetUnit(ienv, "target", { name = "Mage", level = 60, health = 1, healthMax = 1, reaction = 2,
		cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 } })
	ienv.SetTarget(true)
	assert(W.LastCall(tcb.icon, "SetTexture")[1] == 135846, "another unit's cast keeps Blizzard's icon")
	assert(#ienv._errors == 0, "icons: " .. tostring(ienv._errors[1]))
end

-- Without duration objects the bar falls back to the cast times when they are plain, and logs the path.
local fenv, FK, fns = U.New({ setup = function(e)
	e.UnitCastingDuration, e.UnitChannelDuration = nil, nil
end })
local fallback = fns.CastBars.Get("player")[1]
fenv._time = 1
fenv._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
fenv.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
local range = W.LastCall(fallback.bar, "SetMinMaxValues")
assert(range[1] == 0 and range[2] == 2, "the bar spans the cast's two seconds")
fenv._time = 2
W.Tick(fenv, 0.1)
assert(W.LastCall(fallback.bar, "SetValue")[1] == 1, "the bar fills from the cast times")
local logged = false
for _, entry in ipairs(FK.Store.Data().devlog) do
	logged = logged or (entry.module == "UnitFrames" and entry.message:find("cast bars", 1, true) ~= nil)
end
assert(logged, "the fallback path is logged")
assert(#fenv._errors == 0, "fallback: " .. tostring(fenv._errors[1]))

print("unitframes castbars ok")
