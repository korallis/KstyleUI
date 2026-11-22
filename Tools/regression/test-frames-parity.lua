-- test-frames-parity.lua: frame parity controls round-trip, preserve old profiles, defer protected edits and pass secrets to engine setters.
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local G = dofile("Tools/regression/group_env.lua")
local function saved(module, settings)
	settings = settings or {}
	settings.enabled = true
	return { version = 42, profiles = { Default = { [module] = settings } }, characters = {}, layouts = {} }
end
local function write(env, K, module, key, value)
	K.Options.Write(module, key, value)
	env.RunTimers()
	local got = K.Options.Read(module, key)
	if type(value) == "table" then
		for k, v in pairs(value) do assert(got[k] == v, key .. " must round-trip") end
	else
		assert(got == value, key .. " must round-trip")
	end
end
local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
local function alpha(env, region)
	local value = region:GetAlpha()
	if env.issecretvalue(value) then return env.Reveal(value) end
	return value
end
do
	local env, K, ns = U.New({ plate = true, saved = saved("UnitFrames", { player = { healPrediction = false } }),
		setup = function(e) e.GetNetStats = function() return 0, 0, 20, 200 end end })
	local player = ns.Frames.Get("player").views[1]
	assert(not player.incoming:IsShown() and not player.absorb:IsShown(), "v0.2.8 prediction-off stays off")
	assert(ns.Settings.Value("player", "absorbs") and ns.Settings.Value("player", "castbarSpark"))
	assert(not ns.Settings.Value("player", "castbarLatency"), "latency stays off on old profiles")
	write(env, K, "UnitFrames", "player.healPrediction", true)
	write(env, K, "UnitFrames", "player.absorbs", false)
	assert(player.incoming:IsShown() and not player.absorb:IsShown(), "absorb switch leaves incoming heals visible")
	write(env, K, "UnitFrames", "player.absorbs", true)
	assert(player.absorb:IsShown(), "absorbs can be restored")
	local cb = ns.CastBars.Get("player")[1]
	write(env, K, "UnitFrames", "player.castbarSpark", false)
	assert(not cb.bar.spark:IsShown(), "spark off hides the plate spark")
	write(env, K, "UnitFrames", "player.castbarSpark", true)
	assert(cb.bar.spark:IsShown(), "spark on restores the plate spark")
	write(env, K, "UnitFrames", "player.castbarLatency", true)
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	assert(cb.latency and cb.latency:IsShown(), "readable cast times show the latency zone")
	assert(math.abs(cb.latency:GetWidth() / cb.bar:GetWidth() - 0.1) < 0.001, "world latency is a share of total cast time")
	assert(cb.latency:GetPoint(1) == "RIGHT", "normal casts place latency at their finish")
	env._units.player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
	assert(not cb.latency:IsShown(), "finished casts clear latency")
	env._units.player.secretCast = true
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
	assert(not cb.latency:IsShown(), "secret times never enter latency arithmetic")
	local color = { r = 0.2, g = 0.3, b = 0.4 }
	write(env, K, "UnitFrames", "player.castbarLockedColor", color)
	env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
	local call = U.W.LastCall(cb.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
	assert(call and call[2].r == color.r, "secret interrupt flags retain the custom locked colour")
	local focus = ns.Frames.Get("focus").views[1]
	write(env, K, "UnitFrames", "focus.auraFilter", "debuffs")
	write(env, K, "UnitFrames", "focus.auraFilters.onlyMine", true)
	write(env, K, "UnitFrames", "focus.auraFilters.dispellable", true)
	write(env, K, "UnitFrames", "focus.auraFilters.sort", "name")
	local group = focus.auras.container._groups.debuffs
	assert(group.filter == "HARMFUL|PLAYER|RAID", "shared filters reach the aura engine")
	assert(group.sortMethod == env.AuraContainerSortMethod.NameOnly, "shared sorting reaches the aura engine")
	env.SetCombat(true)
	write(env, K, "UnitFrames", "focus.auraFilters.onlyMine", false)
	assert(ns.Frames.Get("focus").layoutQueued, "protected relayout waits for combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(group.filter == "HARMFUL|RAID", "queued aura changes apply after combat")
	assert(not ns.Frames.Get("focus").layoutQueued, "protected relayout completes after combat")
	clean(env, K)
end
collectgarbage()
do
	local env, K, ns = U.New({ before = function(_, core)
		core.Store.Module("UnitFrames").auraLayout = "fan"
	end })
	local cb = ns.CastBars.Get("player")[1]
	write(env, K, "UnitFrames", "player.castbarSpark", false)
	assert(not cb.bar.fillCursor:IsShown(), "Medallions spark off hides its native edge")
	write(env, K, "UnitFrames", "player.castbarSpark", true)
	assert(cb.bar.fillCursor:IsShown(), "Medallions spark can be restored")
	write(env, K, "UnitFrames", "target.auraFilters.dispellable", true)
	write(env, K, "UnitFrames", "target.auraFilters.sort", "name")
	local fan = ns.Frames.Get("target").views[1].auras.fan
	for _, container in ipairs(fan.containers) do
		assert(container._groups.debuffs.filter == "HARMFUL|PLAYER|RAID", "crest fan shares the dispel filter")
		assert(container._groups.debuffs.sortMethod == env.AuraContainerSortMethod.NameOnly, "crest fan shares the sort")
	end
	clean(env, K)
end
collectgarbage()
do
	local env, K, ns = G.New({ saved = saved("GroupFrames"), setup = function(e)
		e.UnitHasIncomingResurrection = function() return e.Secret(true) end
		e.UnitIsAFK = function() return e.Secret(true) end
		e.C_IncomingSummon = { HasIncomingSummon = function() return e.Secret(true) end }
	end })
	G.SetRoster(env, "party", { { name = "Tank", role = "TANK", class = "WARRIOR" } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local frame
	ns.Unit.ForEach(function(f) if f.unit == "party1" then frame = f end end)
	assert(frame, "party frame exists")
	for _, key in ipairs({ "afk", "resurrection", "summon" }) do
		assert(ns.Settings.current.icons[key], "v0.2.8 retains " .. key)
		write(env, K, "GroupFrames", "icons." .. key, false)
		assert(alpha(env, frame.statusIcons[key]) == 0, key .. " can be disabled independently")
	end
	write(env, K, "GroupFrames", "icons.afk", true)
	assert(alpha(env, frame.statusIcons.afk) == 1, "AFK appears with higher priority states disabled")
	write(env, K, "GroupFrames", "icons.summon", true)
	assert(alpha(env, frame.statusIcons.summon) == 1 and alpha(env, frame.statusIcons.afk) == 0)
	write(env, K, "GroupFrames", "icons.resurrection", true)
	assert(alpha(env, frame.statusIcons.resurrection) == 1 and alpha(env, frame.statusIcons.summon) == 0)
	clean(env, K)
end
collectgarbage()
do
	local env, K, ns = N.New({ saved = saved("Nameplates") })
	for _, key in ipairs({ "cast.spark", "cast.hideUnitName", "cast.fullOpacity", "focus.fullOpacity" }) do
		assert(ns.Settings.Get(key) == false, "v0.2.8 retains the old nameplate default for " .. key)
	end
	N.Add(env, "nameplate1")
	N.Add(env, "nameplate2")
	local plate = ns.Plates.Get("nameplate2")
	write(env, K, "Nameplates", "target.smoothOpacity", false)
	write(env, K, "Nameplates", "target.dimOthers", 0.4)
	N.Target(env, "nameplate1")
	N.Focus(env, "nameplate2")
	assert(plate:GetAlpha() == 0.4, "focus dims by default")
	write(env, K, "Nameplates", "focus.fullOpacity", true)
	assert(plate:GetAlpha() == 1, "focus override applies")
	write(env, K, "Nameplates", "focus.fullOpacity", false)
	assert(plate:GetAlpha() == 0.4, "focus override restores dimming")
	write(env, K, "Nameplates", "cast.fullOpacity", true)
	write(env, K, "Nameplates", "cast.hideUnitName", true)
	write(env, K, "Nameplates", "cast.spark", true)
	assert(plate.castBar.fillCursor:IsShown(), "nameplate spark applies")
	N.Cast(env, "nameplate2", { name = "Fireball", text = "Fireball", texture = 135812 })
	assert(plate:GetAlpha() == 1 and plate.name:GetAlpha() == 0, "cast events apply both visibility options")
	env._units.nameplate2.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate2")
	assert(plate:GetAlpha() == 0.4 and plate.name:GetAlpha() == 1, "cast stop restores the name and opacity")
	write(env, K, "Nameplates", "cast.spark", false)
	assert(not plate.castBar.fillCursor:IsShown(), "nameplate spark restores off")
	clean(env, K)
end
print("frames parity ok: old profiles, controls, cast latency, shared aura filters, secret statuses and plate visibility")
