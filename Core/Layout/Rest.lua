-- Rest.lua: the Medallions leave-combat fade: three seconds after combat ends the secondary unit frames (target of target, focus, its target and the pet) dim to 60% over 0.6 s and return the moment combat starts; alpha only, through Layout, only where the player kept full alpha, and only under the Medallions style.
local _, ns = ...

local Layout, Effects, Tokens, Motion = ns.Layout, ns.Effects, ns.Tokens, ns.Motion

local Rest = {}
Layout.Rest = Rest

Rest.KEYS = { "unitframes.targettarget", "unitframes.focus", "unitframes.focustarget", "unitframes.pet" }
Rest.ALPHA = 0.6
Rest.DELAY, Rest.FALL, Rest.RISE = Tokens.Duration("combatOutDelay"), Tokens.Duration("combatOut"), Tokens.Duration("combatIn")

local OWNER = "Rest"
local secondary = {}
for _, key in ipairs(Rest.KEYS) do
	secondary[key] = true
end

local resting, waiting = false, 0

function Rest.Resting()
	return resting
end

function Rest.Level(key)
	if resting and secondary[key] then
		return Rest.ALPHA
	end
	return 1
end

local function Apply(seconds)
	local duration = Effects.Allows("flare") and Motion.FadeDuration(seconds) or 0
	if Effects.Level() == "calm" then duration = math.min(duration, Tokens.Duration("panelClose")) end
	for _, key in ipairs(Rest.KEYS) do
		Layout.RefreshAlpha(key, duration)
	end
end

local function Wake(seconds)
	if resting then
		resting = false
		Apply(seconds)
	end
end

local function Settle()
	waiting = waiting - 1
	if waiting > 0 or resting or InCombatLockdown() or not Effects.Active() then
		return
	end
	resting = true
	Apply(Rest.FALL)
end

local function Later()
	if not Effects.Active() then
		return
	end
	waiting = waiting + 1
	C_Timer.After(Rest.DELAY, Settle)
end

local function Woken()
	Wake(Rest.RISE)
end

local listening = false

function Rest.Update()
	local active = Effects.Active()
	if active == listening then
		return
	end
	listening = active
	if not active then
		ns.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED")
		ns.Events.Unregister(OWNER, "PLAYER_REGEN_DISABLED")
		Wake(0)
		return
	end
	ns.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Later)
	ns.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Woken)
	if not InCombatLockdown() then
		Later()
	end
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", Rest.Update)
ns.Callbacks.Register("HudStyleChanged", OWNER, Rest.Update)
ns.Callbacks.Register("ProfileChanged", OWNER, Rest.Update)
