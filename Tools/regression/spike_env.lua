-- spike_env.lua: load the spike addon into a stub environment that fakes the game APIs its spikes call.
--
--   local SpikeEnv = dofile("Tools/regression/spike_env.lua")
--   local env, ns = SpikeEnv({ height = 2234, remove = { "C_EncodingUtil" } })
--   env.Slash("encoding")
--   local run = env.LastRun()
--
-- opts are passed to Stubs.NewEnv, plus:
--   globals  table of globals to set before the addon loads (they replace the fakes below)
--   remove   list of global names to leave unset, to test the path for a missing API
--   noLogin  load the files without firing ADDON_LOADED and PLAYER_LOGIN
-- Every print goes to env.chat instead of the terminal. C_Timer.After runs on a virtual clock:
-- env.Advance(seconds) runs the timers due in that time, in order, and env.RunTimers() runs them all.
-- env.RunTickers(n) calls each live ticker n times.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local ROOT = "Tools/spikes/KstyleUI_Spike"
local ADDON = "KstyleUI_Spike"

local function readFile(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- A stand-in for C_EncodingUtil that round-trips through a registry, so tests see the real call order.
local function fakeEncoding()
	local store, nextId = {}, 0
	local function wrap(tag, value)
		nextId = nextId + 1
		local key = tag .. ":" .. nextId
		store[key] = value
		return key
	end
	local function unwrap(tag, key)
		if type(key) ~= "string" or key:sub(1, #tag + 1) ~= tag .. ":" or store[key] == nil then
			error("bad " .. tag .. " input", 2)
		end
		return store[key]
	end
	return {
		SerializeCBOR = function(value) return wrap("cbor", value) end,
		DeserializeCBOR = function(text) return unwrap("cbor", text) end,
		CompressString = function(text) return wrap("deflate", text) end,
		DecompressString = function(text) return unwrap("deflate", text) end,
		EncodeBase64 = function(text) return wrap("b64", text) end,
		DecodeBase64 = function(text) return unwrap("b64", text) end,
	}
end

return function(opts)
	opts = opts or {}
	local env = Stubs.NewEnv(opts)
	local tickers = {}

	env.chat = {}
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		env.chat[#env.chat + 1] = table.concat(parts, " ")
	end
	env._now = 1000
	env.GetTime = function() return env._now end
	env.GetServerTime = function() return 1762480000 end
	env.GetBuildInfo = function() return "1.60.1", "70840", "Nov 1 2026", 16001, "", "" end
	env.SlashCmdList = {}
	local timers, queued = {}, 0
	env.C_Timer.After = function(seconds, fn)
		queued = queued + 1
		timers[#timers + 1] = { due = env._now + seconds, order = queued, fn = fn }
	end

	-- Runs the earliest timer due by limit, and returns false when none is due.
	local function runNext(limit)
		local best
		for i, timer in ipairs(timers) do
			if timer.due <= limit and (not best or timer.due < timers[best].due or (timer.due == timers[best].due and timer.order < timers[best].order)) then
				best = i
			end
		end
		if not best then
			return false
		end
		local timer = table.remove(timers, best)
		env._now = math.max(env._now, timer.due)
		timer.fn()
		return true
	end

	function env.Advance(seconds)
		local limit = env._now + seconds
		while runNext(limit) do
		end
		env._now = limit
	end

	function env.RunTimers()
		local rounds = 0
		while runNext(math.huge) do
			rounds = rounds + 1
			assert(rounds <= 10000, "RunTimers: timers keep scheduling timers")
		end
	end

	env.C_Timer.NewTicker = function(_, fn, iterations)
		local ticker = { fn = fn, left = iterations }
		function ticker.Cancel() ticker.cancelled = true end
		function ticker.IsCancelled() return ticker.cancelled == true end
		tickers[#tickers + 1] = ticker
		return ticker
	end
	env.C_EncodingUtil = fakeEncoding()
	env.C_CVar = { GetCVar = function(name) return (opts.cvars or {})[name] end }
	env.screenshots = 0
	env.Screenshot = function() env.screenshots = env.screenshots + 1 end

	-- Spike.xml's <Font> objects become stub Font objects with the same font settings.
	local xml = readFile(ROOT .. "/Spike.xml")
	for attrs in xml:gmatch("<Font%s([^>]*)>") do
		local name = attrs:match('name="([^"]+)"')
		local font = env.CreateFrame("Font", name)
		font:SetFont(attrs:match('font="([^"]+)"'), tonumber(attrs:match('height="([^"]+)"')), "")
	end

	for name, value in pairs(opts.globals or {}) do
		env[name] = value
	end
	for _, name in ipairs(opts.remove or {}) do
		env[name] = nil
	end

	function env.RunTickers(n)
		for _ = 1, n or 1 do
			for _, ticker in ipairs({ unpack(tickers) }) do
				if not ticker.cancelled then
					ticker.fn(ticker)
					if ticker.left then
						ticker.left = ticker.left - 1
						ticker.cancelled = ticker.cancelled or ticker.left <= 0
					end
				end
			end
		end
	end

	function env.LiveTickers()
		local n = 0
		for _, ticker in ipairs(tickers) do
			n = n + (ticker.cancelled and 0 or 1)
		end
		return n
	end

	function env.Slash(msg)
		return env.SlashCmdList.KSPIKE(msg or "")
	end

	function env.Runs()
		return env.KstyleUISpikeDB and env.KstyleUISpikeDB.runs or {}
	end

	function env.LastRun()
		local runs = env.Runs()
		return runs[#runs]
	end

	function env.ChatHas(text)
		for _, line in ipairs(env.chat) do
			if line:find(text, 1, true) then
				return true
			end
		end
		return false
	end

	local files = TocFiles("%.lua$", ROOT)
	assert(#files > 0, "no spike Lua files found in " .. ROOT)
	Load(files, env)
	if not opts.noLogin then
		env.FireEvent("ADDON_LOADED", ADDON)
		env.FireEvent("PLAYER_LOGIN")
	end
	return env, env._addons[ADDON]
end
