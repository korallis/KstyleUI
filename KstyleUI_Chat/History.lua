-- History.lua: keeps each chat window's last lines across a reload or a relog in KstyleUI's own saved data, bounded per window, and puts them back once when the chat starts.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Format, Windows = ns.Format, ns.Windows

local History = { restoring = false }
ns.History = History

local SECTION = "chatHistory"
local VERSION = 1

local state = { on = false, limit = 0, restored = false }

local IsSecret = Format.IsSecret

local function Saved(create)
	local Store = K.Store
	if type(Store) ~= "table" or type(Store.IsLoaded) ~= "function" or not Store.IsLoaded() then
		return nil
	end
	local key = Store.CharacterKey()
	if type(key) ~= "string" then
		return nil
	end
	local account = Store.Account()
	local saved = account[SECTION]
	if type(saved) ~= "table" then
		if not create then
			return nil
		end
		saved = {}
		account[SECTION] = saved
	end
	saved.version = VERSION
	if type(saved.characters) ~= "table" then
		saved.characters = {}
	end
	local mine = saved.characters[key]
	if type(mine) ~= "table" then
		if not create then
			return nil
		end
		mine = {}
		saved.characters[key] = mine
	end
	return mine, saved, key
end

local function Name(frame)
	local name = type(frame.GetName) == "function" and frame:GetName() or nil
	if IsSecret(name) or type(name) ~= "string" then
		return nil
	end
	return name
end

local function Channel(v)
	if IsSecret(v) or type(v) ~= "number" or v ~= v then
		return 1
	end
	return math.min(1, math.max(0, v))
end

local function Oldest(lines)
	local first = lines.first
	if type(first) == "number" and first % 1 == 0 and first > 1 and first <= #lines then
		return first
	end
	return 1
end

local function Unwrap(lines)
	local first, n = Oldest(lines), #lines
	lines.first = nil
	if first == 1 then
		return
	end
	local ordered = {}
	for i = 1, n do
		ordered[i] = lines[(first + i - 2) % n + 1]
	end
	for i = 1, n do
		lines[i] = ordered[i]
	end
end

local function Trim(lines, limit)
	Unwrap(lines)
	local extra = #lines - limit
	if extra <= 0 then
		return
	end
	local n = #lines
	for i = 1, n - extra do
		lines[i] = lines[i + extra]
	end
	for i = n, n - extra + 1, -1 do
		lines[i] = nil
	end
end

local function Keeps(frame, text)
	return state.on and state.limit > 0 and not History.restoring and not IsSecret(text) and type(text) == "string"
		and text ~= "" and not text:find("|K", 1, true) and not Windows.IsCombatLog(frame)
end

function History.Record(frame, text, r, g, b)
	if not Keeps(frame, text) then
		return
	end
	local name = Name(frame)
	local mine = name and Saved(true)
	if not mine then
		return
	end
	local lines = mine[name]
	if type(lines) ~= "table" then
		lines = {}
		mine[name] = lines
	end
	local line, n = { text, Channel(r), Channel(g), Channel(b) }, #lines
	if n == state.limit then
		local first = Oldest(lines)
		lines[first] = line
		lines.first = first < n and first + 1 or nil
	else
		Trim(lines, state.limit - 1)
		lines[#lines + 1] = line
	end
end

local function Restore()
	local mine = Saved(false)
	if not mine then
		return
	end
	local mr, mg, mb = K.Tokens.Color("muted")
	History.restoring = true
	for _, frame in ipairs(Windows.List()) do
		local name = Name(frame)
		local lines = name and mine[name]
		if type(lines) == "table" and #lines > 0 and not Windows.IsCombatLog(frame) and type(frame.AddMessage) == "function" then
			Trim(lines, state.limit)
			for _, line in ipairs(lines) do
				if type(line) == "table" and type(line[1]) == "string" then
					K.Call(frame.AddMessage, frame, line[1], Channel(line[2]), Channel(line[3]), Channel(line[4]))
				end
			end
			K.Call(frame.AddMessage, frame, L["Chat from your last session"], mr, mg, mb)
		end
	end
	History.restoring = false
end

local function Forget()
	local _, saved, key = Saved(false)
	if saved then
		saved.characters[key] = nil
		if next(saved.characters) == nil then
			K.Store.Account()[SECTION] = nil
		end
	end
end

function History.Refresh(settings, key)
	state.on = settings.history == true
	local limit = settings.historyLines
	if IsSecret(limit) or type(limit) ~= "number" or limit ~= limit then
		limit = ns.defaults.historyLines
	end
	state.limit = math.floor(math.min(ns.HISTORY_MAX, math.max(0, limit)))
	if not state.on then
		if key == "history" then
			Forget()
		end
		return
	end
	if key == "historyLines" then
		local mine = Saved(false)
		for _, lines in pairs(mine or {}) do
			if type(lines) == "table" then
				Trim(lines, state.limit)
			end
		end
	end
end

function History.Start(settings)
	History.Refresh(settings)
	if not state.restored then
		state.restored = true
		if state.on then
			Restore()
		end
	end
end

function History.Stop()
	state.on = false
end
