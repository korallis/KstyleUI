-- Codec.lua: pure-Lua base64, Adler-32 and a strict data serializer for profile strings when C_EncodingUtil is missing.
local _, ns = ...

local Codec = {}
ns.Codec = Codec

local byte, char, sub, floor = string.byte, string.char, string.sub, math.floor
local MAX_DEPTH = 12
local MAX_NODES = 20000
local MAX_LENGTH_DIGITS = 7

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENCODE, DECODE = {}, {}
for i = 1, 64 do
	local c = sub(ALPHABET, i, i)
	ENCODE[i - 1] = c
	DECODE[byte(c)] = i - 1
end

function Codec.EncodeBase64(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = byte(data, i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = ENCODE[floor(n / 262144) % 64]
		local c2 = ENCODE[floor(n / 4096) % 64]
		local c3 = b and ENCODE[floor(n / 64) % 64] or "="
		local c4 = c and ENCODE[n % 64] or "="
		out[#out + 1] = c1 .. c2 .. c3 .. c4
	end
	return table.concat(out)
end

function Codec.IsBase64(text)
	return type(text) == "string" and #text % 4 == 0 and text:match("^[A-Za-z0-9+/]*=?=?$") ~= nil
end

function Codec.DecodeBase64(text)
	if not Codec.IsBase64(text) then
		return nil
	end
	local out = {}
	local length = #text
	for i = 1, length, 4 do
		local a, b, c, d = byte(text, i, i + 3)
		local pad = 0
		if d == 61 then
			pad = c == 61 and 2 or 1
			if i + 3 ~= length then
				return nil
			end
		end
		local n = DECODE[a] * 262144 + DECODE[b] * 4096 + (DECODE[c] or 0) * 64 + (DECODE[d] or 0)
		local bytes = char(floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
		out[#out + 1] = pad == 0 and bytes or sub(bytes, 1, 3 - pad)
	end
	return table.concat(out)
end

function Codec.Adler32(data)
	local a, b = 1, 0
	for i = 1, #data, 4096 do
		local chunk = { byte(data, i, i + 4095) }
		for j = 1, #chunk do
			a = a + chunk[j]
			b = b + a
		end
		a, b = a % 65521, b % 65521
	end
	return b * 65536 + a
end

local function isFinite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end
Codec.IsFinite = isFinite

local function keyOrder(x, y)
	local tx, ty = type(x), type(y)
	if tx ~= ty then
		return tx == "number"
	end
	return x < y
end

local function write(out, value, depth)
	local t = type(value)
	if t == "string" then
		out[#out + 1] = "s" .. #value .. ":" .. value
	elseif t == "number" then
		if not isFinite(value) then
			error("KstyleUI.Codec.Serialize: numbers must be finite", 0)
		end
		out[#out + 1] = "n" .. string.format("%.17g", value) .. ";"
	elseif t == "boolean" then
		out[#out + 1] = value and "T" or "F"
	elseif t == "table" then
		if depth > MAX_DEPTH then
			error("KstyleUI.Codec.Serialize: tables nest too deeply", 0)
		end
		local keys = {}
		for k in pairs(value) do
			local kt = type(k)
			if not (kt == "string" or (kt == "number" and isFinite(k))) then
				error("KstyleUI.Codec.Serialize: a key must be a string or a finite number, got " .. kt, 0)
			end
			keys[#keys + 1] = k
		end
		table.sort(keys, keyOrder)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			write(out, k, depth + 1)
			write(out, value[k], depth + 1)
		end
		out[#out + 1] = "}"
	else
		error("KstyleUI.Codec.Serialize: cannot serialize a " .. t, 0)
	end
end

function Codec.Serialize(value)
	local out = {}
	write(out, value, 1)
	return table.concat(out)
end

local FAIL = {}

local function fail()
	error(FAIL, 0)
end

local function parseNumber(text)
	if not (text:match("^%-?%d+$") or text:match("^%-?%d+%.%d+$") or text:match("^%-?%d+%.?%d*[eE][%+%-]?%d+$")) then
		fail()
	end
	local n = tonumber(text)
	if not n or not isFinite(n) then
		fail()
	end
	return n
end

local function parse(text, pos, depth, state)
	local c = sub(text, pos, pos)
	if c == "s" then
		local digits, colon = text:match("^(%d+)():", pos + 1)
		if not digits or #digits > MAX_LENGTH_DIGITS then
			fail()
		end
		local length = tonumber(digits)
		local last = colon + length
		if last > #text then
			fail()
		end
		return sub(text, colon + 1, last), last + 1
	elseif c == "n" then
		local digits, after = text:match("^([^;]+);()", pos + 1)
		if not digits or #digits > 32 then
			fail()
		end
		return parseNumber(digits), after
	elseif c == "T" then
		return true, pos + 1
	elseif c == "F" then
		return false, pos + 1
	elseif c == "{" then
		if depth > MAX_DEPTH then
			fail()
		end
		local result = {}
		pos = pos + 1
		while true do
			local ch = sub(text, pos, pos)
			if ch == "}" then
				return result, pos + 1
			elseif ch == "" then
				fail()
			end
			local key
			key, pos = parse(text, pos, depth + 1, state)
			if type(key) ~= "string" and type(key) ~= "number" then
				fail()
			end
			if result[key] ~= nil then
				fail()
			end
			local value
			value, pos = parse(text, pos, depth + 1, state)
			result[key] = value
			state.nodes = state.nodes + 1
			if state.nodes > MAX_NODES then
				fail()
			end
		end
	end
	fail()
end

function Codec.Deserialize(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, value, pos = pcall(parse, text, 1, 1, { nodes = 0 })
	if not ok or pos ~= #text + 1 then
		return nil
	end
	return value
end
