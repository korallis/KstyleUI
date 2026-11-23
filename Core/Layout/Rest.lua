-- Rest.lua: two alpha-only rests through Layout, only where the player kept full alpha: the Medallions leave-combat dim of the secondary unit frames, and the clean screen, which eases the chosen panels to a rest opacity while nothing needs them and brings each back at once on hover, a target, a cast, combat, a health change, power short of full, death, the action bar grid or Layout Mode; it leaves alone a fade another owner set and never hooks another addon's frame.
local _, ns = ...

local Layout, Effects, Tokens, Motion, Store, L = ns.Layout, ns.Effects, ns.Tokens, ns.Motion, ns.Store, ns.L

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

local function Apply(seconds)
	local duration = Effects.Allows("flare") and seconds or 0
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

local SECTION, FADE = "Rest", "RestFade"
local HOOK_DEPTH = 3

Rest.WAKE = Tokens.Duration("hover")
Rest.ORDER = { "actionBars", "player", "strip", "cooldowns" }
Rest.PANELS = {
	actionBars = { "actionbars.bar1", "actionbars.bar2", "actionbars.bar3", "actionbars.bar4", "actionbars.bar5", "actionbars.bar6", "actionbars.pet", "actionbars.stance", "consumables.bar" },
	player = { "unitframes.player", "unitframes.resource" },
	strip = { "databars.strip", "databars.strip2", "databars.micro", "databars.bags", "databars.xp", "databars.rep", "databars.honor" },
	cooldowns = { "cooldowns.essential", "cooldowns.utility", "cooldowns.buffs", "cooldowns.bars", "cooldowns.custom" },
}
Rest.defaults = { enabled = true, alpha = 0.35, panels = { actionBars = true, player = true, strip = true, cooldowns = true } }

local ROWS = {
	actionBars = { L["Action bars"], L["Every action bar, with the Medallions slab and hub."] },
	player = { L["Player frame"], L["Your own unit frame and class resource."] },
	strip = { L["Data strip"], L["The readout strip, its menus and the experience line."] },
	cooldowns = { L["Cooldowns"], L["KstyleUI's own cooldown rows; rows the game draws itself stay as they are."] },
}
local CASTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }
local PULSES = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_SPELLCAST_SUCCEEDED" }

local panelOf = {}
for panel, keys in pairs(Rest.PANELS) do
	for _, key in ipairs(keys) do
		panelOf[key] = panel
	end
end

local quiet, watching, grid, timing, changed, due = false, false, false, false, false, 0
local hovered, over, followers, members, NONE = {}, {}, {}, {}, {}
local hooked = setmetatable({}, { __mode = "k" })
local IsSecret = ns.Widgets.IsSecret

local function On(panel)
	if not Store.IsLoaded() then
		return false
	end
	local s = Store.Module(SECTION)
	return s.enabled == true and (panel == nil or type(s.panels) == "table" and s.panels[panel] == true)
end

local function Opacity()
	local alpha = Store.Module(SECTION).alpha
	if type(alpha) ~= "number" or alpha ~= alpha or alpha < 0.1 or alpha > 0.9 then
		return Rest.defaults.alpha
	end
	return alpha
end

function Rest.Quiet()
	return quiet
end

function Rest.Level(key)
	if resting and secondary[key] then
		return Rest.ALPHA
	end
	if quiet and members[key] and not hovered[panelOf[key]] then
		return Opacity()
	end
	return 1
end

local function Follow(key, duration)
	local level = Rest.Level(key)
	for _, frame in ipairs(followers[key]) do
		local from = frame:GetAlpha()
		if IsSecret(from) or type(from) ~= "number" then
			from = level
		end
		Motion.Tween(frame, "SetAlpha", from, level, duration, Tokens.Easing("fade"))
	end
end

local function Refresh(panel, duration)
	for _, key in ipairs(Rest.PANELS[panel]) do
		Layout.RefreshAlpha(key, duration)
		if followers[key] then
			Follow(key, duration)
		end
	end
end

local function ApplyAll(duration)
	for _, panel in ipairs(Rest.ORDER) do
		Refresh(panel, duration)
	end
end

function Rest.Follow(key, ...)
	local list = followers[key] or {}
	followers[key] = list
	for i = 1, select("#", ...) do
		list[#list + 1] = select(i, ...)
	end
	if quiet then
		Follow(key, 0)
	end
end

local function Enter(frame)
	local panel = watching and hooked[frame]
	if panel then
		over[frame] = true
		if not hovered[panel] then
			hovered[panel] = true
			if quiet then
				Refresh(panel, Rest.WAKE)
			end
		end
	end
end

local recheck = {}
for panel in pairs(Rest.PANELS) do
	recheck[panel] = function()
		if not hovered[panel] then
			return
		end
		for frame in pairs(over) do
			if hooked[frame] == panel then
				return
			end
		end
		hovered[panel] = nil
		if quiet then
			Refresh(panel, Rest.FALL)
		end
	end
end

local function Leave(frame)
	local panel = watching and hooked[frame]
	if panel then
		over[frame] = nil
		if hovered[panel] then
			C_Timer.After(0, recheck[panel])
		end
	end
end

local function Children(frame)
	return { frame:GetChildren() }
end

local function Hook(frame, script, fn)
	local ok, done = pcall(frame.HookScript, frame, script, fn)
	return ok and done ~= false
end

local function HookTree(frame, panel, depth)
	if IsSecret(frame) or type(frame) ~= "table" then
		return false
	end
	local name = frame:GetName()
	if name ~= nil and (IsSecret(name) or name:sub(1, 8) ~= "KstyleUI") then
		return false
	end
	if not hooked[frame] and not (Hook(frame, "OnEnter", Enter) and Hook(frame, "OnLeave", Leave)) then
		return false
	end
	hooked[frame] = panel
	if depth < HOOK_DEPTH then
		local ok, children = pcall(Children, frame)
		if ok then
			for _, child in ipairs(children) do
				HookTree(child, panel, depth + 1)
			end
		end
	end
	return true
end

local function Plain(v)
	return not IsSecret(v) and v
end

local function Joins(el)
	local s, alpha = el.settings, el.frame:GetAlpha()
	local bar = el.key:match("^actionbars%.(.+)$")
	local cfg = bar and Store.Module("ActionBars")[bar]
	return s.shown ~= "mouseover" and s.alphaCombat == 1 and s.alphaIdle == 1 and not IsSecret(alpha)
		and (Motion.IsPlaying(el.alphaTween) or math.abs(alpha - (el.alphaSet and el.alphaTarget or 1)) < 0.01)
		and not (type(cfg) == "table" and cfg.fade == true)
end

local function Gather()
	members = {}
	for panel, keys in pairs(Rest.PANELS) do
		if On(panel) then
			for _, key in ipairs(keys) do
				local el = Layout.Element(key)
				if el and Layout.Live(key) and Plain(el.frame:IsShown()) == true and HookTree(el.frame, panel, 0) then
					members[key] = Joins(el)
					for _, frame in ipairs(followers[key] or NONE) do
						HookTree(frame, panel, 0)
					end
					local ok, inside = pcall(el.frame.IsMouseOver, el.frame)
					if ok and Plain(inside) == true then
						hovered[panel] = true
					end
				end
			end
		end
	end
end

local function Yes(fn, ...)
	return type(fn) == "function" and fn(...) == true
end

local function Active(info)
	if type(info) ~= "function" then
		return false
	end
	local name = info("player")
	return IsSecret(name) or name ~= nil
end

local function Short()
	if type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then
		return false
	end
	local power, most = UnitPower("player"), UnitPowerMax("player")
	return IsSecret(power) or IsSecret(most) or power ~= 0 and power ~= most
end

local function Busy()
	return grid or Layout.IsActive() or Yes(InCombatLockdown) or Yes(UnitExists, "target") or Yes(UnitIsDeadOrGhost, "player")
		or Active(UnitCastingInfo) or Active(UnitChannelInfo) or Short()
end

local function WakeAll()
	if quiet then
		quiet = false
		ApplyAll(Rest.WAKE)
	end
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

local function SettleAll()
	timing = false
	if quiet or not watching or Busy() then
		changed = false
		return
	end
	if changed then
		changed, timing = false, true
		C_Timer.After(math.max(due - Now(), 0), SettleAll)
		return
	end
	quiet = true
	Gather()
	ApplyAll(Rest.FALL)
end

local function SettleLater()
	due, changed = Now() + Rest.DELAY, timing
	if not timing then
		timing = true
		C_Timer.After(Rest.DELAY, SettleAll)
	end
end

local function Check()
	if Busy() then
		WakeAll()
	elseif not quiet then
		SettleLater()
	end
end

local function Pulse()
	WakeAll()
	Check()
end

local function Power(_, _, token)
	local primary = type(UnitPowerType) == "function" and select(2, UnitPowerType("player")) or nil
	if primary == nil or IsSecret(token) or token == primary then
		Check()
	end
end

local function Grid(event)
	grid = event == "ACTIONBAR_SHOWGRID"
	Check()
end

local function Watch(on)
	local register = on and ns.Events.Register or ns.Events.Unregister
	local unit = on and ns.Events.RegisterUnit or ns.Events.Unregister
	register(FADE, "PLAYER_TARGET_CHANGED", Check)
	for _, event in ipairs(CASTS) do
		unit(FADE, event, Check, "player")
	end
	for _, event in ipairs(PULSES) do
		unit(FADE, event, Pulse, "player")
	end
	unit(FADE, "UNIT_POWER_UPDATE", Power, "player")
	unit(FADE, "UNIT_MAXPOWER", Power, "player")
end

local function Fought()
	Watch(false)
	WakeAll()
end

local function Calmed()
	Watch(true)
	Check()
end

local function Wanted()
	for _, panel in ipairs(Rest.ORDER) do
		if On(panel) then
			return true
		end
	end
	return false
end

function Rest.Listen()
	local want = Wanted()
	if want ~= watching then
		watching = want
		if want then
			ns.Events.Register(FADE, "PLAYER_REGEN_DISABLED", Fought)
			ns.Events.Register(FADE, "PLAYER_REGEN_ENABLED", Calmed)
			ns.Events.Register(FADE, "PLAYER_ENTERING_WORLD", Pulse)
			ns.Events.Register(FADE, "ACTIONBAR_SHOWGRID", Grid)
			ns.Events.Register(FADE, "ACTIONBAR_HIDEGRID", Grid)
			Watch(not Yes(InCombatLockdown))
		else
			ns.Events.UnregisterAll(FADE)
			grid, hovered, over = false, {}, {}
			WakeAll()
		end
	end
	if watching then
		Check()
		if quiet then
			Gather()
			ApplyAll(Rest.WAKE)
		end
	end
end

function Rest.Schema()
	local function off(s)
		return s.enabled ~= true
	end
	local rows = {
		{ type = "header", label = L["Clean screen at rest"] },
		{
			type = "toggle", key = "enabled", label = L["Fade panels at rest"],
			help = L["Out of combat with no target, panels fade; hover, a target, a cast or combat brings them back."],
		},
		{
			type = "slider", key = "alpha", label = L["Rest opacity"], min = 0.1, max = 0.9, step = 0.05, disableWhen = off,
			help = L["How much of a resting panel still shows."],
		},
	}
	for _, panel in ipairs(Rest.ORDER) do
		rows[#rows + 1] = { type = "toggle", key = "panels." .. panel, label = ROWS[panel][1], help = ROWS[panel][2], disableWhen = off }
	end
	return rows
end

Store.RegisterDefaults(SECTION, Rest.defaults)
ns.Options.Register(SECTION, Rest.Schema)

ns.Events.Register(FADE, "PLAYER_LOGIN", Rest.Listen)
ns.Callbacks.Register("ProfileChanged", FADE, Rest.Listen)
ns.Callbacks.Register("SettingChanged", FADE, function(_, module)
	if module == SECTION or module == "ActionBars" then
		Rest.Listen()
	end
end)
