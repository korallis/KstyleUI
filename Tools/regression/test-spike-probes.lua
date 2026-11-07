-- test-spike-probes.lua: the paging, header, combat, auras, meters, cdm and presets spikes record results offline without touching a secret.
local SpikeEnv = dofile("Tools/regression/spike_env.lua")

local DRIVER = "[possessbar] 12; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; [stealth] 7; 1"

-- Fakes for the Forever APIs these spikes read. Each returns plain values out of combat and secrets in it,
-- the worst case the spikes must survive.
local function Fakes(state)
	local g = {}
	local env -- set after the environment exists
	local function secretInCombat(value)
		if env and env._combat then
			return env.Secret(value)
		end
		return value
	end
	g.Enum = {
		PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4 },
		SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 },
		CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 },
		DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
		DamageMeterType = { DamageDone = 0, Dps = 1 },
		ForeverExperiencePreset = { Classic = 0, Enhanced = 1 },
		EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Override = 3 },
		AddOnRestrictionType = { Combat = 0, Encounter = 1 },
		AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
	}
	g.C_Secrets = {
		ShouldAurasBeSecret = function() return state.aurasSecret == true end,
		GetPowerTypeSecrecy = function(powerType) return powerType == 4 and 2 or 0 end,
		ShouldUnitPowerBeSecret = function(_, powerType) return env._combat and powerType == 4 end,
	}
	g.C_RestrictedActions = { GetAddOnRestrictionState = function() return env._combat and 2 or 0 end }
	g.UnitPower = function(_, powerType) return powerType == 4 and secretInCombat(3) or 100 end
	g.UnitExists = function(unit) return unit == "player" or state.target == true end
	g.IsInInstance = function() return true, "party" end

	-- Secure templates and drivers.
	state.drivers, state.wraps, state.refs, state.watches = {}, {}, {}, {}
	g.RegisterStateDriver = function(frame, name, values) state.drivers[#state.drivers + 1] = { frame = frame, name = name, values = values } end
	g.UnregisterStateDriver = function(frame, name) state.unregistered = (state.unregistered or 0) + 1 end
	g.SecureHandlerWrapScript = function(frame, script, header, pre) state.wraps[#state.wraps + 1] = { frame = frame, script = script, header = header, pre = pre } end
	g.SecureHandlerSetFrameRef = function(frame, label, ref) state.refs[label] = { frame = frame, ref = ref } end
	g.RegisterUnitWatch = function(frame) state.watches[#state.watches + 1] = frame end
	g.UnregisterUnitWatch = function() state.unwatched = (state.unwatched or 0) + 1 end
	g.SecureCmdOptionParse = function(text) return text:find("^%[stealth%]") and state.stealthed and "yes" or "no" end
	g.GetShapeshiftForm = function() return state.form or 0 end
	g.IsStealthed = function() return state.stealthed == true end
	g.C_ActionBar = {
		GetBonusBarOffset = function() return state.bonus or 0 end,
		GetActionBarPage = function() return 1 end,
		IsPossessBarVisible = function() return false end,
		HasBonusActionBar = function() return (state.bonus or 0) > 0 end,
		GetActionTexture = function(action) return 100 + action end,
	}

	-- Cooldown Manager.
	local function duration(secret)
		return { HasSecretValues = function() return secret end }
	end
	state.cdmCalls = 0
	g.C_CooldownViewer = {
		IsCooldownViewerAvailable = function() return true, "" end,
		GetCooldownViewerCategorySet = function(category) return ({ [0] = { 11, 12 }, [1] = { 21 } })[category] or {} end,
		GetCooldownViewerCooldownInfo = function(id)
			return { cooldownID = id, spellID = id * 100, charges = id == 12, isKnown = true, category = id < 20 and 0 or 1, linkedSpellIDs = {}, selfAura = false, hasAura = false, isInvisible = false, flags = 0 }
		end,
	}
	g.C_Spell = {
		GetSpellTexture = function(id) return 5000 + id end,
		GetSpellCooldownDuration = function() state.cdmCalls = state.cdmCalls + 1 return duration(env._combat) end,
		GetSpellChargeDuration = function() state.cdmCalls = state.cdmCalls + 1 return duration(env._combat) end,
		GetSpellCooldown = function() return { startTime = secretInCombat(1), duration = secretInCombat(2), isEnabled = true, modRate = 1 } end,
	}

	-- Damage Meter.
	g.C_DamageMeter = {
		IsDamageMeterAvailable = function() return true, "" end,
		GetCombatSessionFromType = function()
			return {
				totalAmount = secretInCombat(1000), maxAmount = secretInCombat(600), durationSeconds = 12,
				combatSources = { { name = secretInCombat("Bob"), totalAmount = secretInCombat(600), amountPerSecond = secretInCombat(50), classFilename = "ROGUE", isLocalPlayer = true } },
			}
		end,
	}
	g.issecrettable = function() return false end

	-- Presets and Edit Mode.
	g.C_GameRules = { GetForeverExperiencePreset = function() return 1 end }
	g.C_EditMode = { GetLayouts = function() return { layouts = { { layoutName = "Mine", layoutType = 1 } }, activeLayout = 1 } end }
	g.EditModePresetLayoutManager = { presetLayoutInfo = { {}, {} } }

	return g, function(e) env = e end
end

local function NewEnv(opts)
	opts = opts or {}
	local state = opts.state or {}
	local globals, bind = Fakes(state)
	for k, v in pairs(opts.globals or {}) do
		globals[k] = v
	end
	local env, ns = SpikeEnv({ globals = globals, remove = opts.remove, noLogin = true })
	bind(env)
	-- Blizzard frames the presets and cdm spikes look at.
	for _, name in ipairs({ "PlayerFrame", "TargetFrame", "MainActionBar" }) do
		env.CreateFrame("Frame", name, env.UIParent)
	end
	env.FocusFrame = env.CreateFrame("Frame", "FocusFrame", env.UIParent)
	env.FocusFrame:Hide()
	env.EditModeManagerFrame = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
	rawset(env.EditModeManagerFrame, "GetActiveLayoutInfo", function() return { layoutName = "Modern", layoutType = 0 } end)
	local viewer = env.CreateFrame("Frame", "EssentialCooldownViewer", env.UIParent)
	local items = {}
	for _, id in ipairs({ 11, 12 }) do
		local item = env.CreateFrame("Frame", nil, viewer)
		rawset(item, "GetCooldownID", function() return id end)
		rawset(item, "Cooldown", env.CreateFrame("Cooldown", nil, item))
		items[#items + 1] = item
	end
	rawset(viewer, "GetItemFrames", function() return items end)
	env.FireEvent("ADDON_LOADED", "KstyleUI_Spike")
	env.FireEvent("PLAYER_LOGIN")
	return env, ns, state
end

-- A frame handle as restricted snippets see it: attribute access and frame refs, nothing else.
local function Handle(frame, state)
	return {
		SetAttribute = function(_, key, value) frame:SetAttribute(key, value) end,
		GetAttribute = function(_, key) return frame:GetAttribute(key) end,
		GetFrameRef = function(_, label) return Handle(state.refs[label].ref, state) end,
	}
end

-- Runs a snippet with only the names the restricted environment gives it, so a misspelled name fails here.
local function RunSnippet(body, names)
	local chunk = assert(loadstring(body))
	local env = { tonumber = tonumber }
	for key, value in pairs(names) do
		env[key] = value
	end
	setfenv(chunk, setmetatable(env, { __index = function(_, key) error("restricted snippet reads unknown name " .. key, 2) end }))
	return chunk()
end

local function find(list, fn)
	for _, item in ipairs(list or {}) do
		if fn(item) then
			return item
		end
	end
end

local env, ns, state = NewEnv()
for _, name in ipairs({ "paging", "header", "combat", "auras", "meters", "cdm", "presets" }) do
	assert(ns.spikes[name], "spike not registered: " .. name)
end

-- paging: one secure button on the plan's page driver, with a wrapped OnClick.
env.Slash("paging")
local paging = env.LastRun()
assert(paging.spike == "paging" and paging.results.driver == DRIVER)
local driver = state.drivers[1]
assert(driver and driver.name == "page" and driver.values == DRIVER, "paging must register the plan's page driver")
assert(driver.frame._template == "SecureHandlerStateTemplate", "the driver is a SecureHandlerStateTemplate frame")
local button = state.refs.button and state.refs.button.ref
assert(button and button._template == "SecureActionButtonTemplate", "the paged button is a SecureActionButtonTemplate")
assert(button:GetAttribute("type") == "action", "the button performs its action")
assert(state.wraps[1] and state.wraps[1].frame == button and state.wraps[1].script == "OnClick" and state.wraps[1].header == driver.frame)
assert(driver.frame:GetAttribute("_onstate-page"), "the driver pages the button in a restricted snippet")
RunSnippet(driver.frame:GetAttribute("_onstate-page"), { self = Handle(driver.frame, state), stateid = "page", newstate = "7" })
assert(button:GetAttribute("action") == 73, "page 7 points the button at action 73")
RunSnippet(state.wraps[1].pre, { self = Handle(button, state), control = Handle(driver.frame, state), button = "LeftButton", down = false })
RunSnippet(state.wraps[1].pre, { self = Handle(button, state), control = Handle(driver.frame, state), button = "LeftButton", down = false })
assert(driver.frame:GetAttribute("kspike-clicks") == 2, "the wrapped click counts on the driver")
assert(paging.results.displayedPage == 1, "the button shows its page as soon as the spike starts")
state.stealthed = true
local onAttr = driver.frame:GetScript("OnAttributeChanged")
assert(onAttr, "paging hooks the driver's attribute changes")
onAttr(driver.frame, "state-page", "7")
onAttr(driver.frame, "kspike-clicks", 1)
local change = paging.results.changes[1]
assert(change and change.page == "7" and change.stealthed == true and change.conditions.stealth == "yes", "paging logs each page with the game state")
assert(paging.results.displayedPage == 7, "the button follows the page")
assert(paging.results.clicks == 1, "paging counts wrapped clicks")
env.FireEvent("ADDON_ACTION_BLOCKED", "KstyleUI_Spike", "KstyleUISpike_PagingButton:SetAttribute()")
assert(paging.results.blocked == 1, "paging counts blocked actions")
assert(env.KstyleUISpikeDB.autostart.paging == true, "paging rebuilds at the next PLAYER_LOGIN")

-- paging asked for in combat refuses to build secure frames.
local fresh, _, freshState = NewEnv()
fresh._combat = true
fresh.Slash("paging")
assert(fresh.LastRun().results.refused and #freshState.drivers == 0, "paging must not create secure frames in combat")

-- paging autostarts at PLAYER_LOGIN, even in combat, and stop clears that.
local db = { runs = {}, autostart = { paging = true } }
local login, _, loginState = NewEnv({ globals = { KstyleUISpikeDB = db } })
assert(login.LastRun().spike == "paging" and login.LastRun().origin == "PLAYER_LOGIN", "paging autostarts at login")
assert(#loginState.drivers == 1, "the login run builds the driver")
login.Slash("stop")
assert(db.autostart.paging == nil, "stop clears autostart")

-- Stopping paging in combat waits for combat to end before hiding the secure driver.
local combatStop, combatStopNs, combatStopState = NewEnv()
combatStop.Slash("paging")
local pagingDriver = combatStopState.drivers[1].frame
combatStop._combat = true
combatStop.Slash("stop")
assert(pagingDriver:IsShown(), "a secure frame is not hidden in combat")
combatStop.SetCombat(false)
assert(not pagingDriver:IsShown(), "the driver hides once combat ends")
combatStop.Slash("paging")
combatStop._combat = true
combatStop.Slash("stop")
combatStop.Slash("paging")
combatStop.SetCombat(false)
assert(pagingDriver:IsShown(), "a deferred cleanup must not hide a spike that restarted")
assert(combatStopNs.active.paging, "paging is running again")

-- header: a party header and a target unit watch button.
env.Slash("header")
local header = env.LastRun()
assert(header.results.template == "SecurePartyHeaderTemplate", "header uses SecurePartyHeaderTemplate")
assert(#state.watches == 1, "header registers a unit watch")
env.Advance(2)
assert(header.results.children ~= nil, "header counts its children a moment later")
local partyHeader = env.KstyleUISpike_PartyHeader
env._combat = true
env.Slash("stop")
assert(partyHeader:IsShown() and (state.unwatched or 0) == 0, "header leaves its secure frames alone in combat")
env.SetCombat(false)
assert(not partyHeader:IsShown() and state.unwatched == 1, "header cleans up once combat ends")
env.Slash("paging")

-- combat: UNIT_COMBAT per unit token, secret arguments counted, nothing compared.
env.Slash("combat")
local combat = env.LastRun()
env.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
env.SetCombat(true)
env.FireEvent("UNIT_COMBAT", "player", "WOUND", "CRITICAL", env.Secret(250), 1)
env.FireEvent("UNIT_COMBAT", "nameplate3", "HEAL", "", env.Secret(80), 2)
env.FireEvent("UNIT_COMBAT", env.Secret("target"), "WOUND", "", env.Secret(5), 1)
local player = combat.results.units.player
assert(player.outOfCombat.count == 1 and player.inCombat.count == 1)
assert(player.inCombat.secret[4] == 1 and player.outOfCombat.secret[4] == 0, "combat counts a secret amount per argument")
assert(combat.results.nameplateFired == true, "combat notes nameplate tokens")
assert(combat.results.units["<secret>"].inCombat.count == 1, "a secret unit token is counted, not used as a key")
assert(combat.results.kinds.WOUND >= 2 and combat.results.kinds.HEAL == 1)

-- auras: flips of ShouldAurasBeSecret, encounter and regen timing, combo point secrecy.
env.SetCombat(false)
env.Slash("auras")
local auras = env.LastRun()
state.aurasSecret = true
env.RunTickers(1)
env.FireEvent("ENCOUNTER_START", 1084, "Onyxia", 9, 40)
env.SetCombat(true)
env.RunTickers(1)
local flip = auras.results.flips[1]
assert(flip and flip.aurasSecret == true and flip.inCombat == false, "auras logs the flip before combat starts")
assert(find(auras.results.events, function(e) return e.event == "ENCOUNTER_START" end), "auras logs ENCOUNTER_START")
assert(find(auras.results.events, function(e) return e.event == "PLAYER_REGEN_DISABLED" end), "auras logs PLAYER_REGEN_DISABLED")
assert(auras.results.comboPoints.inCombat.secret >= 1 and auras.results.comboPoints.outOfCombat.plain >= 1, "auras samples combo point secrecy in and out of combat")

-- meters: secrecy per power type, and the damage meter session in combat.
env.SetCombat(false)
env.Slash("meters")
local meters = env.LastRun()
assert(meters.results.powerTypes.ComboPoints.secrecy == "ContextuallySecret" and meters.results.powerTypes.Mana.secrecy == "NeverSecret")
env.SetCombat(true)
env.Advance(4)
env.RunTickers(1)
local sample = find(meters.results.samples, function(s) return s.inCombat end)
assert(sample and sample.fields.totalAmount == "secret" and sample.fields.durationSeconds == "plain", "meters records which session fields are secret")
assert(sample.source.name == "secret" and sample.source.classFilename == "plain")

-- cdm: categories listed, icons built in combat from duration objects, compared with Blizzard's viewer.
env.SetCombat(false)
env.Slash("cdm")
local cdm = env.LastRun()
assert(cdm.results.categories.Essential.count == 2 and cdm.results.categories.Utility.count == 1)
assert(#cdm.results.cooldowns == 3, "cdm records each cooldown's info")
env.RunTickers(1)
assert(cdm.results.icons == nil, "cdm builds its icons only once combat lockdown starts")
env.SetCombat(true)
env.RunTickers(1)
assert(cdm.results.icons == 2 and cdm.results.builtInCombat == true, "cdm builds one icon per essential cooldown in combat")
assert(cdm.results.calls.setFromDuration.calls >= 2 and cdm.results.calls.setFromDuration.errors == 0)
assert(cdm.results.calls.duration.secret >= 2, "cdm counts duration objects that carry secret values")
local cdmSample = cdm.results.samples[#cdm.results.samples]
assert(cdmSample and cdmSample.idsMatch == true, "cdm compares its icons with EssentialCooldownViewer")
local viewerItems = env.EssentialCooldownViewer:GetItemFrames()
rawset(viewerItems[1], "GetCooldownID", function() return 12 end)
rawset(viewerItems[2], "GetCooldownID", function() return 11 end)
env.RunTickers(1)
assert(cdm.results.samples[#cdm.results.samples].idsMatch == false, "cdm notices when Blizzard's order differs")

-- presets: the experience preset, the Edit Mode layout and the Blizzard frames KstyleUI hides.
env.SetCombat(false)
env.Slash("presets")
local presets = env.LastRun().results
assert(presets.preset == "Enhanced" and presets.editMode.activeLayout == 1)
assert(presets.frames.PlayerFrame.shown == true and presets.frames.FocusFrame.shown == false)
assert(presets.frames.PartyFrame.exists == false, "a missing frame is recorded, not an error")

-- Each pull spike ends on its own after its 15-minute window.
env.Advance(901)
for _, name in ipairs({ "combat", "auras", "meters", "cdm" }) do
	assert(not ns.active[name], name .. " must stop after its window")
end

-- pull starts combat, auras, meters and cdm at once; stop ends them all and cancels their tickers.
local pull, pullNs = NewEnv()
pull.Slash("pull")
for _, name in ipairs({ "combat", "auras", "meters", "cdm" }) do
	assert(pullNs.active[name], "pull must start " .. name .. " at once")
end
pull.Slash("stop")
assert(next(pullNs.active) == nil and pull.LiveTickers() == 0, "stop cancels every ticker")

-- Every spike survives a client without the APIs it probes.
local bare = NewEnv({ remove = { "C_Secrets", "C_DamageMeter", "C_CooldownViewer", "C_GameRules", "C_EditMode", "C_Spell", "C_RestrictedActions", "C_ActionBar" } })
for _, name in ipairs({ "combat", "auras", "meters", "cdm", "presets" }) do
	bare.Slash(name)
	assert(bare.LastRun().results.error == nil, name .. " errored without its APIs: " .. tostring(bare.LastRun().results.error))
end
bare.SetCombat(true)
bare.Advance(5)
bare.RunTickers(2)
bare.Slash("stop")

print("spike probes ok")
