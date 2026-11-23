-- Rest.lua: two alpha-only rests through Layout, only where the player kept full alpha: the Medallions leave-combat dim of the secondary unit frames, and the clean screen, which eases the chosen panels to a rest opacity while nothing needs them and brings each back at once on hover, a target, a cast, combat, a health or power change or a drag; none begins while Layout Mode is open.
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

local CASTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }
local PULSES = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MAXPOWER" }

local panelOf = {}
for panel, keys in pairs(Rest.PANELS) do
	for _, key in ipairs(keys) do
		panelOf[key] = panel
	end
end

local quiet, watching, pending = false, false, 0
local hovered, over, followers, NONE = {}, {}, {}, {}
local hooked = setmetatable({}, { __mode = "k" })

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

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
	local panel = panelOf[key]
	if panel and quiet and not hovered[panel] and On(panel) then
		return Opacity()
	end
	return 1
end

local function Kept(key)
	local el = Layout.Element(key)
	local s = el and el.settings
	return s ~= nil and s.shown ~= "mouseover" and s.alphaCombat == 1 and s.alphaIdle == 1
end

local function Follow(key, duration)
	local level = Kept(key) and Rest.Level(key) or 1
	for _, frame in ipairs(followers[key] or NONE) do
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
		Follow(key, duration)
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
	over[frame] = true
	local panel = hooked[frame]
	if panel and not hovered[panel] then
		hovered[panel] = true
		if quiet then
			Refresh(panel, Rest.WAKE)
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
	over[frame] = nil
	local panel = hooked[frame]
	if panel and hovered[panel] then
		C_Timer.After(0, recheck[panel])
	end
end

local function Children(frame)
	return { frame:GetChildren() }
end

local function HookTree(frame, panel, depth)
	if IsSecret(frame) or type(frame) ~= "table" then
		return
	end
	if not hooked[frame] then
		if not (pcall(frame.HookScript, frame, "OnEnter", Enter) and pcall(frame.HookScript, frame, "OnLeave", Leave)) then
			return
		end
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
end

local function HookPanels()
	for _, panel in ipairs(Rest.ORDER) do
		if On(panel) then
			for _, key in ipairs(Rest.PANELS[panel]) do
				local el = Layout.Element(key)
				if el then
					HookTree(el.frame, panel, 0)
				end
				for _, frame in ipairs(followers[key] or NONE) do
					HookTree(frame, panel, 0)
				end
			end
		end
	end
end

local function Active(info)
	if type(info) ~= "function" then
		return false
	end
	local name = info("player")
	return IsSecret(name) or name ~= nil
end

local function Busy()
	return InCombatLockdown() or Layout.IsActive() or UnitExists("target") == true or Active(UnitCastingInfo) or Active(UnitChannelInfo)
		or type(GetCursorInfo) == "function" and GetCursorInfo() ~= nil
end

local function WakeAll()
	if quiet then
		quiet = false
		ApplyAll(Rest.WAKE)
	end
end

local function SettleAll()
	pending = pending - 1
	if pending > 0 or quiet or not watching or Busy() then
		return
	end
	quiet = true
	HookPanels()
	ApplyAll(Rest.FALL)
end

local function SettleLater()
	pending = pending + 1
	C_Timer.After(Rest.DELAY, SettleAll)
end

local function Check()
	if not watching then
		return
	end
	if Busy() then
		WakeAll()
	elseif not quiet then
		SettleLater()
	end
end

local function Pulse()
	WakeAll()
	SettleLater()
end

local function Power(_, _, token)
	local primary
	if type(UnitPowerType) == "function" then
		primary = select(2, UnitPowerType("player"))
	end
	if primary == nil or IsSecret(token) or IsSecret(primary) or token == primary then
		Pulse()
	end
end

local function Watch(on)
	if on then
		ns.Events.Register(FADE, "PLAYER_TARGET_CHANGED", Check)
		for _, event in ipairs(CASTS) do
			ns.Events.RegisterUnit(FADE, event, Check, "player")
		end
		for _, event in ipairs(PULSES) do
			ns.Events.RegisterUnit(FADE, event, Pulse, "player")
		end
		ns.Events.RegisterUnit(FADE, "UNIT_POWER_UPDATE", Power, "player")
		return
	end
	ns.Events.Unregister(FADE, "PLAYER_TARGET_CHANGED")
	for _, event in ipairs(CASTS) do
		ns.Events.Unregister(FADE, event)
	end
	for _, event in ipairs(PULSES) do
		ns.Events.Unregister(FADE, event)
	end
	ns.Events.Unregister(FADE, "UNIT_POWER_UPDATE")
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
	if not On() then
		return false
	end
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
			ns.Events.Register(FADE, "ACTIONBAR_SHOWGRID", Check)
			ns.Events.Register(FADE, "ACTIONBAR_HIDEGRID", Check)
			Watch(not InCombatLockdown())
		else
			ns.Events.UnregisterAll(FADE)
			WakeAll()
		end
	end
	if watching then
		Check()
		if quiet then
			HookPanels()
			ApplyAll(Rest.WAKE)
		end
	end
end

function Rest.Schema()
	local function off(s)
		return s.enabled ~= true
	end
	Rest.schema = {
		{ type = "header", label = L["Clean screen at rest"] },
		{
			type = "toggle", key = "enabled", label = L["Fade panels at rest"],
			help = L["Out of combat with no target, panels fade; hover, a target, a cast or combat brings them back."],
		},
		{
			type = "slider", key = "alpha", label = L["Rest opacity"], min = 0.1, max = 0.9, step = 0.05, disableWhen = off,
			help = L["How much of a resting panel still shows."],
		},
		{
			type = "toggle", key = "panels.actionBars", label = L["Action bars"], disableWhen = off,
			help = L["Every action bar, with the Medallions slab and hub."],
		},
		{
			type = "toggle", key = "panels.player", label = L["Player frame"], disableWhen = off,
			help = L["Your own unit frame and class resource."],
		},
		{
			type = "toggle", key = "panels.strip", label = L["Data strip"], disableWhen = off,
			help = L["The readout strip, its menus and the experience line."],
		},
		{
			type = "toggle", key = "panels.cooldowns", label = L["Cooldowns"], disableWhen = off,
			help = L["The cooldown and tracked buff rows."],
		},
	}
	return Rest.schema
end

Store.RegisterDefaults(SECTION, Rest.defaults)
ns.Options.Register(SECTION, Rest.Schema)

ns.Events.Register(FADE, "PLAYER_LOGIN", Rest.Listen)
ns.Callbacks.Register("ProfileChanged", FADE, Rest.Listen)
ns.Callbacks.Register("SettingChanged", FADE, function(_, module)
	if module == SECTION then
		Rest.Listen()
	end
end)
