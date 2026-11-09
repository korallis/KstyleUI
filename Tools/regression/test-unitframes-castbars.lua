-- test-unitframes-castbars.lua: cast bars run on duration objects through SetTimerDuration, pass secret cast data only to setters, and follow their settings.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

-- These checks pin the classic plate's cast bars, the style setting's other choice; test-unitframes-lumen.lua covers the Lumen cast lines.
local env, K, ns = U.New({ plate = true })
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

-- A player cast: the duration object drives the bar; the icon is the spell's file ID.
local player = CastBars.Get("player")[1]
assert(not player.frame:IsShown(), "no cast, no bar")
env._time = 1
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(player.frame:IsShown(), "a cast shows the bar")
local timer = W.LastCall(player.bar, "SetTimerDuration")
assert(timer and timer[1].finish == 3.5, "the bar runs on the cast's duration object")
assert(timer[3] == env.Enum.StatusBarTimerDirection.ElapsedTime, "a cast fills up")
assert(U.Shown(env, player.text) == "Frostbolt", "the spell name shows as the game writes it, like the mockup's Slam: " .. U.Shown(env, player.text))
assert(player.geometry.icon == nil, "the player cast bar has no icon, as on the mockup")
assert(W.LastCall(player.icon, "SetTexture")[1] == 135846, "the icon shows the spell's file ID")
env._time = 2
W.Tick(env, 0.1)
assert(U.Shown(env, player.timer) == "1.5s", "the timer counts down with the design's s suffix: " .. U.Shown(env, player.timer))
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
settle()
assert(not player.frame:IsShown(), "a finished cast fades out")
assert(player.frame:GetScript("OnUpdate") == nil, "the timer stops with the cast")
noErrors("player cast")

-- A failed or stopped event for another spell leaves the running cast alone.
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1500, finish = 4000, spellID = 116, barID = 7 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-7", 116, 7)
env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-8", 2139, 8)
assert(U.Shown(env, player.text) == "Frostbolt" and player.frame:GetScript("OnUpdate"), "a failed cast with another cast bar ID is ignored")
env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-8", 2139)
assert(U.Shown(env, player.text) == "Frostbolt", "without an ID, a failure while the cast still runs is ignored")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-7", 116, 7)
assert(U.Shown(env, player.text) == K.L["Failed"], "the running cast's own failure shows Failed")
settle()
K.Options.Write("UnitFrames", "player.castbarCaps", true)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1500, finish = 4000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-9", 116)
assert(U.Shown(env, player.text) == "FROSTBOLT", "with capitals on, the spell name is upper-cased: " .. U.Shown(env, player.text))
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-9", 116)
settle()

-- An interrupted cast says so in the hostile colour, then fades.
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 2000, finish = 4500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 116)
assert(U.Shown(env, player.text) == K.L["Interrupted"]:upper(), "an interrupt shows Interrupted")
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
assert(env.issecretvalue(W.LastCall(target.icon, "SetTexture")[1]), "the secret icon reaches SetTexture untouched")
local locked = W.LastCall(target.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(locked and env.issecretvalue(locked[1]), "a secret interruptible flag colours the bar from a boolean")
env._time = 2
W.Tick(env, 0.1)
assert(U.Shown(env, target.timer) == "1.8s", "the timer shows a secret remaining time: " .. U.Shown(env, target.timer))
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
local focusH = K.Setup.Layouts.Element("unitframes.focus").height
local bossSlot = ns.Geometry.Slots(ns.Geometry.BOSS_COUNT, ns.Geometry.BOSS_GAP, 1, K.Setup.Layouts.Element("unitframes.boss").height)[1].h
assert(math.abs(focusView.geometry.panel.h - (focusH - 16 - 4)) < 1, "the focus frame leaves room for its 16-unit cast bar: " .. focusView.geometry.panel.h)
local _, _, _, _, y = focusBar.frame:GetPoint(1)
assert(y < -40, "the focus cast bar sits under the frame")
assert(frameH == focusH, "the focus button spans its element")
local bossView = ns.Frames.Get("boss").views[1]
assert(math.abs(bossView.geometry.panel.h - (bossSlot - 10 - 2)) < 1, "each boss frame leaves room for its cast bar")

-- A font that does not load falls back to KstyleUI's font at the chosen size.
do
	local calls = {}
	local real = player.text.SetFont
	player.text.SetFont = function(self, path, size, flags)
		calls[#calls + 1] = { path, size, flags }
		if path == "Interface\\Nope.ttf" then
			return false
		end
		return real(self, path, size, flags)
	end
	K.Options.Write("UnitFrames", "player.fonts.cast.font", "Interface\\Nope.ttf")
	local last = calls[#calls]
	assert(last[1] ~= "Interface\\Nope.ttf" and type(last[2]) == "number" and last[2] > 0, "the fallback font keeps a size")
	player.text.SetFont = nil
	K.Options.Write("UnitFrames", "player.fonts.cast.font", "theme")
end

-- Layout's shown rule keeps the player cast bar hidden through setting changes.
assert(K.Layout.Set("unitframes.castbar.player", "shown", "never"))
assert(not CastBars.Holder("player"):IsShown(), "the never rule hides the player cast bar")
K.Options.Write("UnitFrames", "player.castbarTimer", false)
K.Options.Write("UnitFrames", "player.castbarTimer", true)
assert(not CastBars.Holder("player"):IsShown(), "a cast bar setting change leaves Layout's rule alone")
K.Layout.Reset("unitframes.castbar.player")
assert(CastBars.Holder("player"):IsShown(), "and the rule's reset shows it again")

-- At the smallest focus height the frame keeps its room and the cast bar gives way.
assert(K.Layout.Set("unitframes.focus", "height", 24))
assert(focusView.geometry.panel.h >= 20, "a 24-unit focus element keeps the frame: " .. focusView.geometry.panel.h)
U.SetUnit(env, "focus", { name = "Elunara", level = 60, health = 1, healthMax = 2, reaction = 2,
	cast = { name = "Greater Heal", texture = 135913, start = 1000, finish = 3500, spellID = 2060 } })
env.FireEvent("UNIT_SPELLCAST_START", "focus", "Cast-1", 2060)
assert(not focusBar.frame:IsShown(), "a cast bar with no room stays hidden")
U.SetUnit(env, "focus", nil)
K.Layout.Reset("unitframes.focus")

-- Settings.
K.Options.Write("UnitFrames", "player.castbarIcon", false)
assert(not player.iconFrame:IsShown(), "the icon can be switched off")
local _, _, _, px = player.panel:GetPoint(1)
assert(math.abs(px) < 1e-6 and player.geometry.icon == nil, "and the glass bar takes its room")
local _, _, _, bx = player.bar:GetPoint(1)
local playerCastH = K.Setup.Layouts.Element("unitframes.castbar.player").height
assert(math.abs(bx - player.geometry.bar.x) < 1 and player.geometry.bar.x - player.geometry.panel.x == math.floor(0.5 * playerCastH + 0.5), "with the bar inside the glass at the mockup's 0.5 H inset (Slam's bar starts 18 units in on a 37-unit bar; 15 on the 30-unit bar)")
local narrowTall = CastBars.Geometry(200, 120, true, true, 14)
assert(narrowTall.stacked and narrowTall.bar.w >= 0.5 * narrowTall.panel.w and narrowTall.text.w > 0, "a tall, narrow bar beside its icon keeps at least half its glass for the fill: the insets never eat the panel, got " .. narrowTall.bar.w)
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
assert(math.abs(focusView.geometry.panel.h - (focusH - 30 - 4)) < 1, "a taller focus cast bar takes room from the frame")
K.Options.Write("UnitFrames", "focus.castbar", false)
assert(math.abs(focusView.geometry.panel.h - focusH) < 1, "without a cast bar the frame fills its element")
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

-- Every cast bar's icon takes the spell's texture file ID as the game gives it; the icon pack replaces the file.
do
	local pcb = player
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	assert(W.LastCall(pcb.icon, "SetTexture")[1] == 135846, "the player's cast bar shows the spell's icon file ID")
	assert(K.Icons == nil, "no icon service rewrites it")
end

-- A focus frame switched on after login listens for its casts.
do
	local lenv, LK, lns = U.New({ saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true, focus = { enabled = false } } } }, characters = {} } })
	U.SetUnit(lenv, "focus", { name = "Elunara", level = 60, health = 1, healthMax = 2, reaction = 2 })
	LK.Options.Write("UnitFrames", "focus.enabled", true)
	lenv._units.focus.cast = { name = "Greater Heal", texture = 135913, start = 1000, finish = 3500, spellID = 2060 }
	lenv.FireEvent("UNIT_SPELLCAST_START", "focus", "Cast-1", 2060)
	assert(lns.CastBars.Get("focus")[1].frame:IsShown(), "the focus cast bar shows a cast after the frame is switched on")
	assert(#lenv._errors == 0, "late focus: " .. tostring(lenv._errors[1]))
end

-- Saved cast bar sizes apply at login, while Layout resizes the holder during registration.
do
	local senv = U.New({
		saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {},
			layouts = { Default = { ["unitframes.castbar.player"] = { width = 300, height = 24 } } } },
		setup = U.SizeEvents,
	})
	assert(#senv._errors == 0, "a saved cast bar size raises no error at login: " .. tostring(senv._errors[1]))
end

-- Without duration objects the bar falls back to the cast times when they are plain, and logs the path.
local fenv, FK, fns = U.New({ plate = true, setup = function(e)
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
