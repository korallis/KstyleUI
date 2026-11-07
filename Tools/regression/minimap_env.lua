-- minimap_env.lua: load the core and KstyleUI_Minimap into a stub environment with Forever's minimap frames, and drive them.
--
--   local M = dofile("Tools/regression/minimap_env.lua")
--   local env, K, ns = M.New({ enabled = true })   -- core and module loaded, saved data loaded, logged in
--   M.Settle(env)                                   -- deferred hides, tweens and tickers run
--
-- The Blizzard frames follow Blizzard_Minimap's Camelot layout on Forever 1.60.1: MinimapCluster holds the
-- header, tracking, indicators and MinimapContainer, which holds Minimap; Minimap holds the zoom buttons
-- and MinimapBackdrop. GameTimeFrame, TimeManagerClockButton and AddonCompartmentFrame sit on the cluster.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local M = {}
M.W = W
M.CoreEnv = W.CoreEnv

local moduleFiles
function M.Files()
	if not moduleFiles then
		moduleFiles = TocFiles("^KstyleUI_Minimap/.*%.lua$")
		assert(#moduleFiles > 0, "KstyleUI_Minimap has no TOC-loaded Lua files")
	end
	return moduleFiles
end

-- Blizzard(env, opts) creates the stand-in Blizzard frames and the game functions the module reads.
function M.Blizzard(env, opts)
	local CreateFrame = env.CreateFrame
	local cluster = CreateFrame("Frame", "MinimapCluster", env.UIParent)
	cluster.ZoneTextButton = CreateFrame("Button", nil, cluster)
	cluster.Tracking = CreateFrame("Frame", nil, cluster)
	cluster.Tracking.Button = CreateFrame("DropdownButton", nil, cluster.Tracking)
	cluster.IndicatorFrame = CreateFrame("Frame", nil, cluster)
	cluster.IndicatorFrame.MailFrame = CreateFrame("Frame", nil, cluster.IndicatorFrame)
	cluster.MinimapContainer = CreateFrame("Frame", nil, cluster)
	local minimap = CreateFrame("Minimap", "Minimap", cluster.MinimapContainer)
	cluster.MinimapContainer.Minimap = minimap
	minimap:SetSize(198, 198)
	minimap:SetPoint("CENTER")
	minimap.ZoomIn = CreateFrame("Button", nil, minimap)
	minimap.ZoomOut = CreateFrame("Button", nil, minimap)
	minimap.ZoomHitArea = CreateFrame("Frame", nil, minimap)
	CreateFrame("Frame", "MinimapBackdrop", minimap)
	CreateFrame("Button", "GameTimeFrame", cluster)
	CreateFrame("Button", "TimeManagerClockButton", cluster)
	CreateFrame("DropdownButton", "AddonCompartmentFrame", cluster)
	env.AddonCompartmentFrame.registeredAddons = {}
	CreateFrame("Button", "QueueStatusButton", env.UIParent)
	env.QueueStatusButton:Hide()

	env._zoom = opts.zoom or 2
	minimap.GetZoom = function()
		return env._zoom
	end
	minimap.GetZoomLevels = function()
		return opts.zoomLevels or 6
	end
	minimap.SetZoom = function(_, zoom)
		env._zoomCalls = (env._zoomCalls or 0) + 1
		env._zoom = zoom
	end
	cluster.UpdateMinimapConfig = function()
		minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask")
	end

	env._zone = { text = opts.zone or "Riverglades", sub = opts.subzone or "Old Mill", pvp = opts.pvp }
	env.GetMinimapZoneText = function()
		return env._zone.text
	end
	env.GetZoneText = function()
		return env._zone.text
	end
	env.GetSubZoneText = function()
		return env._zone.sub
	end
	env.C_PvP = {
		GetZonePVPInfo = function()
			return env._zone.pvp, false, nil
		end,
	}

	env._position = opts.position
	env.C_Map = {
		GetBestMapForUnit = function()
			return 1429
		end,
		GetPlayerMapPosition = function()
			local p = env._position
			if not p then
				return nil
			end
			return {
				GetXY = function()
					return p[1], p[2]
				end,
			}
		end,
	}

	env._cvars = { rotateMinimap = false, timeMgrUseLocalTime = true, timeMgrUseMilitaryTime = true }
	env.GetCVarBool = function(name)
		return env._cvars[name]
	end

	env._clock = { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
	env.date = function(fmt)
		if fmt == "*t" then
			return { hour = env._clock.hour, min = env._clock.minute, sec = 0 }
		end
		return string.format("%02d:%02d", env._clock.hour, env._clock.minute)
	end
	env.GetGameTime = function()
		return env._clock.realmHour, env._clock.realmMinute
	end

	local callbacks = {}
	env.EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = callbacks[event] or {}
			callbacks[event][owner or fn] = fn
		end,
		UnregisterCallback = function(_, event, owner)
			if callbacks[event] then
				callbacks[event][owner] = nil
			end
		end,
		TriggerEvent = function(_, event, ...)
			for owner, fn in pairs(callbacks[event] or {}) do
				fn(owner, ...)
			end
		end,
	}

	env._tickers = {}
	env.C_Timer.NewTicker = function(interval, fn)
		local ticker = { interval = interval, fn = fn }
		function ticker.Cancel(self)
			self.cancelled = true
		end
		function ticker.IsCancelled(self)
			return self.cancelled == true
		end
		env._tickers[#env._tickers + 1] = ticker
		return ticker
	end
end

-- RunTickers(env) runs each live ticker once, as one tick of its interval.
function M.RunTickers(env)
	for _, ticker in ipairs(env._tickers) do
		if not ticker.cancelled then
			ticker.fn(ticker)
		end
	end
end

-- LiveTickers(env) -> the number of tickers that were not cancelled.
function M.LiveTickers(env)
	local n = 0
	for _, ticker in ipairs(env._tickers) do
		if not ticker.cancelled then
			n = n + 1
		end
	end
	return n
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts:
--   enabled   true saves the Minimap switch on, so PLAYER_LOGIN enables the module
--   settings  extra Minimap settings for the saved profile
--   combat    true starts the login in combat
--   boot      false loads everything without ADDON_LOADED and PLAYER_LOGIN
--   setup     function(env) that runs after the Blizzard frames exist
--   and the stand-in options: zoom, zoomLevels, zone, subzone, pvp, position
function M.New(opts)
	opts = opts or {}
	local saved
	if opts.enabled or opts.settings then
		local section = { enabled = opts.enabled == true }
		for key, value in pairs(opts.settings or {}) do
			section[key] = value
		end
		saved = { version = 2, profiles = { Default = { Minimap = section } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	end
	local env, K = W.New({
		saved = saved,
		boot = false,
		setup = function(env)
			M.Blizzard(env, opts)
			if opts.setup then
				opts.setup(env)
			end
		end,
	})
	Load(M.Files(), env)
	if opts.combat then
		env._combat = true
	end
	if opts.boot ~= false then
		M.CoreEnv.Boot(env)
	end
	return env, K, env._addons.KstyleUI_Minimap
end

-- Settle(env) runs deferred timers, then every OnUpdate until none is left.
function M.Settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

-- Holder(K) -> the frame registered as minimap.main.
function M.Holder(K)
	local el = K.Layout.Element("minimap.main")
	return el and el.frame
end

-- Wheel(frame, delta) runs the frame's OnMouseWheel.
function M.Wheel(frame, delta)
	local fn = frame:GetScript("OnMouseWheel")
	assert(fn, "the frame has no OnMouseWheel script")
	fn(frame, delta)
end

-- Resize(frame, w, h) sets the size and runs OnSizeChanged, as the game does.
function M.Resize(frame, w, h)
	frame:SetSize(w, h)
	local fn = frame:GetScript("OnSizeChanged")
	if fn then
		fn(frame, w, h)
	end
end

return M
