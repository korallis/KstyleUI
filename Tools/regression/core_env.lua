-- core_env.lua: load the core addon into a stub environment and drive its saved data, login, combat and logout.
--
--   local CoreEnv = dofile("Tools/regression/core_env.lua")
--   local env, K = CoreEnv.New({ saved = { ... }, encoding = CoreEnv.FakeEncoding() })
--   CoreEnv.Boot(env)   -- ADDON_LOADED for KstyleUI, then PLAYER_LOGIN
--
-- The helpers that build profile strings (Base64, Adler32, WriteLua, CraftLua, CraftCBOR) are written
-- separately from Core/Codec.lua, so a test that uses them pins the string format, not the core's code.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local CoreEnv = {}

local coreFiles
function CoreEnv.Files()
	if not coreFiles then
		coreFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if not path:match("^KstyleUI_") then
				coreFiles[#coreFiles + 1] = path
			end
		end
	end
	return coreFiles
end

-- CoreEnv.New(opts) -> env, KstyleUI. opts holds the Stubs.NewEnv options plus:
--   saved     KstyleUIDB as the game loads it before ADDON_LOADED
--   encoding  the C_EncodingUtil table, or nil for a client without it
--   setup     function(env) that runs before the core files load
function CoreEnv.New(opts)
	opts = opts or {}
	local env = Stubs.NewEnv(opts)
	env.KstyleUIDB = opts.saved
	env.C_EncodingUtil = opts.encoding
	env._printed = {}
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		env._printed[#env._printed + 1] = table.concat(parts, " ")
	end
	if opts.setup then
		opts.setup(env)
	end
	Load(CoreEnv.Files(), env)
	return env, env.KstyleUI
end

function CoreEnv.LoadSaved(env)
	env.FireEvent("ADDON_LOADED", "KstyleUI", false)
end

function CoreEnv.Login(env)
	env.FireEvent("PLAYER_LOGIN")
end

function CoreEnv.Logout(env)
	env.FireEvent("PLAYER_LOGOUT")
end

function CoreEnv.Boot(env)
	CoreEnv.LoadSaved(env)
	CoreEnv.Login(env)
end

-- Printed(env, text) -> the first printed line that contains text, or nil.
function CoreEnv.Printed(env, text)
	for _, line in ipairs(env._printed) do
		if line:find(text, 1, true) then
			return line
		end
	end
end

-- Raises(fn, text) checks that fn raises an error whose message contains text.
function CoreEnv.Raises(fn, text, what)
	local ok, err = pcall(fn)
	assert(not ok, (what or "call") .. " must raise an error containing: " .. text)
	assert(tostring(err):find(text, 1, true), (what or "call") .. ": wrong error: " .. tostring(err))
	return err
end

-- Module(name, fields) -> a module definition that records its Enable and Disable calls in def.calls.
function CoreEnv.Module(name, fields)
	local def = { name = name, defaults = {}, calls = {} }
	for key, value in pairs(fields or {}) do
		def[key] = value
	end
	local onEnable, onDisable = def.onEnable, def.onDisable
	def.onEnable, def.onDisable = nil, nil
	function def.Enable(self)
		assert(self == def, "Enable must be called with the definition as self")
		def.calls[#def.calls + 1] = "Enable"
		if onEnable then
			onEnable(self)
		end
	end
	function def.Disable(self)
		assert(self == def, "Disable must be called with the definition as self")
		def.calls[#def.calls + 1] = "Disable"
		if onDisable then
			onDisable(self)
		end
	end
	return def
end

function CoreEnv.Count(list, value)
	local n = 0
	for _, item in ipairs(list) do
		if item == value then
			n = n + 1
		end
	end
	return n
end

function CoreEnv.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[CoreEnv.DeepCopy(k)] = CoreEnv.DeepCopy(v)
	end
	return out
end

-- DeepEqual(a, b) -> true, or false and the path where they differ.
function CoreEnv.DeepEqual(a, b, path)
	path = path or "value"
	if type(a) ~= type(b) then
		return false, path .. ": " .. type(a) .. " vs " .. type(b)
	end
	if type(a) ~= "table" then
		if a ~= b then
			return false, path .. ": " .. tostring(a) .. " vs " .. tostring(b)
		end
		return true
	end
	for k, v in pairs(a) do
		local same, where = CoreEnv.DeepEqual(v, b[k], path .. "." .. tostring(k))
		if not same then
			return false, where
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false, path .. "." .. tostring(k) .. ": missing on the left"
		end
	end
	return true
end

-- Base64 (RFC 4648, standard alphabet, with padding) -------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, 64 do
	VALUE[ALPHABET:sub(i, i)] = i - 1
end

function CoreEnv.Base64Encode(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = {}
		for j = 1, 4 do
			local index = math.floor(n / 64 ^ (4 - j)) % 64
			chars[j] = ALPHABET:sub(index + 1, index + 1)
		end
		if not b then
			chars[3], chars[4] = "=", "="
		elseif not c then
			chars[4] = "="
		end
		out[#out + 1] = table.concat(chars)
	end
	return table.concat(out)
end

-- Base64Decode(text) -> data, or nil when text is not well-formed base64.
function CoreEnv.Base64Decode(text)
	if #text % 4 ~= 0 or not text:match("^[A-Za-z0-9+/]*=?=?$") then
		return nil
	end
	local out = {}
	for i = 1, #text, 4 do
		local quad = text:sub(i, i + 3)
		local pad = select(2, quad:gsub("=", ""))
		if pad > 0 and i + 3 < #text then
			return nil
		end
		local n = 0
		for j = 1, 4 do
			n = n * 64 + (VALUE[quad:sub(j, j)] or 0)
		end
		local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
		out[#out + 1] = bytes:sub(1, 3 - pad)
	end
	return table.concat(out)
end

function CoreEnv.Adler32(data)
	local a, b = 1, 0
	for i = 1, #data do
		a = (a + data:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

-- The Lua profile format: s<len>:<bytes>, n<number>;, T, F, and { key value ... }, keys sorted.
function CoreEnv.WriteLua(value)
	local t = type(value)
	if t == "string" then
		return "s" .. #value .. ":" .. value
	elseif t == "number" then
		return "n" .. string.format("%.17g", value) .. ";"
	elseif t == "boolean" then
		return value and "T" or "F"
	end
	assert(t == "table", "WriteLua: cannot write a " .. t)
	local keys = {}
	for k in pairs(value) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(x, y)
		if type(x) ~= type(y) then
			return type(x) == "number"
		end
		return x < y
	end)
	local out = { "{" }
	for _, k in ipairs(keys) do
		out[#out + 1] = CoreEnv.WriteLua(k)
		out[#out + 1] = CoreEnv.WriteLua(value[k])
	end
	out[#out + 1] = "}"
	return table.concat(out)
end

-- CraftLua(payload) -> a KSUI1: string in the Lua format. A string payload is used as the body as is.
-- opts.length and opts.checksum override the header fields.
function CoreEnv.CraftLua(payload, opts)
	opts = opts or {}
	local body = type(payload) == "string" and payload or CoreEnv.WriteLua(payload)
	local length = opts.length or #body
	local checksum = opts.checksum or CoreEnv.Adler32(body)
	return "KSUI1:" .. CoreEnv.Base64Encode("KSL1:" .. length .. ":" .. checksum .. ":" .. body)
end

-- A C_EncodingUtil stand-in. SerializeCBOR keeps the value and returns a token, so DeserializeCBOR can
-- return any Lua value a hostile string could decode to. CompressString wraps the data in a zlib-like
-- header and length, and DecompressString returns nothing when either is wrong, as a truncated or
-- corrupt zlib stream does. Base64 is real. api.calls counts the calls by name; api.methods records
-- each compression method the core passed.
function CoreEnv.FakeEncoding()
	local values = {}
	local api = { calls = {}, methods = {} }
	local function count(name)
		api.calls[name] = (api.calls[name] or 0) + 1
	end
	function api.SerializeCBOR(value)
		count("SerializeCBOR")
		values[#values + 1] = CoreEnv.DeepCopy(value)
		return "CBOR" .. #values .. "."
	end
	function api.DeserializeCBOR(data)
		count("DeserializeCBOR")
		local id = tonumber(data:match("^CBOR(%d+)%.$") or "")
		if not id or values[id] == nil then
			error("DeserializeCBOR: invalid CBOR")
		end
		return CoreEnv.DeepCopy(values[id])
	end
	function api.CompressString(data, method)
		count("CompressString")
		api.methods[#api.methods + 1] = method
		return "\120\156" .. string.format("%08d", #data) .. data
	end
	function api.DecompressString(data, method)
		count("DecompressString")
		api.methods[#api.methods + 1] = method
		local length = tonumber(data:match("^\120\156(%d%d%d%d%d%d%d%d)") or "")
		if not length or #data ~= 10 + length then
			return
		end
		return data:sub(11)
	end
	function api.EncodeBase64(data)
		count("EncodeBase64")
		return CoreEnv.Base64Encode(data)
	end
	function api.DecodeBase64(text)
		count("DecodeBase64")
		return CoreEnv.Base64Decode(text)
	end
	return api
end

-- CraftCBOR(api, payload) -> a KSUI1: string whose CBOR decodes to payload through the fake api.
function CoreEnv.CraftCBOR(api, payload)
	return "KSUI1:" .. CoreEnv.Base64Encode(api.CompressString(api.SerializeCBOR(payload), 1))
end

return CoreEnv
