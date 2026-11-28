-- png.lua: Png.Coverage(path) decodes an 8-bit RGBA or RGB, non-interlaced PNG (zlib inflate and row filters in plain Lua 5.1) and returns rows, width, height, where rows[y] (from 0) holds one coverage byte per pixel; Png.Alpha(path) returns alpha(x, y), width, height over the same rows. An RGB file has no alpha: the addon's only RGB files are the aura sheets under Media/Textures/Auras, drawn with the ADD blend, where black adds nothing, so its coverage is its brightest channel. Each file keeps only its coverage rows, and the reader keeps one inflate buffer that every file reuses, so the reach check can hold every crest texture it reads at once under the test runner's 4096 MB limit. Each reach test file has to read every crest texture inside its CPU budget on the hosted runner, so the reader is built for speed: a Huffman code of up to nine bits is read through one table lookup instead of a bit at a time, bits are shifted with a table of powers of two, not the ^ operator, the shared inflate buffer saves growing a new table per file for the collector to sweep, and each row filter has its own loop with no function call in it.
local Png = {}
local byte, char, unpack = string.byte, string.char, unpack

local LBASE, LEXT, DBASE, DEXT = {}, {}, {}, {}
do
	local b = 3
	for i = 0, 27 do
		LEXT[i] = i < 8 and 0 or math.floor(i / 4) - 1
		LBASE[i], b = b, b + 2 ^ LEXT[i]
	end
	LBASE[28], LEXT[28], b = 258, 0, 1
	for i = 0, 29 do
		DEXT[i] = i < 4 and 0 or math.floor(i / 2) - 1
		DBASE[i], b = b, b + 2 ^ DEXT[i]
	end
end
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local POW = {}
for i = 0, 31 do POW[i] = 2 ^ i end

-- A code of FAST bits or fewer is found in one lookup of the stream's next FAST bits; a longer one is read a bit at a
-- time. Nine bits cover every literal of the fixed code and nearly all of a dynamic one.
local FAST = 9
local SPAN = POW[FAST]

-- Huffman(lengths, n) -> count and symbol, the canonical code read a bit at a time (zlib's puff.c), and fast:
-- fast[next FAST bits of the stream, first bit lowest] = symbol * 16 + length, for every code of FAST bits or fewer.
local function Huffman(lengths, n)
	local count, symbol, offs = {}, {}, { 0 }
	for len = 0, 15 do count[len] = 0 end
	for i = 0, n - 1 do count[lengths[i]] = count[lengths[i]] + 1 end
	for len = 1, 14 do offs[len + 1] = offs[len] + count[len] end
	for i = 0, n - 1 do
		local len = lengths[i]
		if len ~= 0 then
			symbol[offs[len]], offs[len] = i, offs[len] + 1
		end
	end
	-- Canonical codes in symbol order (RFC 1951 3.2.2). The stream sends a code's first bit first, so the table is
	-- indexed by the code's bits reversed, and every index whose low bits are that reversal holds the symbol.
	local fast, nextCode, code = {}, {}, 0
	for len = 1, FAST do
		code = (code + (len > 1 and count[len - 1] or 0)) * 2
		nextCode[len] = code
	end
	for i = 0, n - 1 do
		local len = lengths[i]
		if len ~= 0 and len <= FAST then
			local c, reversed = nextCode[len], 0
			nextCode[len] = c + 1
			for _ = 1, len do
				local bit = c % 2
				reversed, c = reversed * 2 + bit, (c - bit) / 2
			end
			for at = reversed, SPAN - 1, POW[len] do fast[at] = i * 16 + len end
		end
	end
	return { count = count, symbol = symbol, fast = fast }
end

-- Inflate(s) -> out, n: the zlib stream s (from its third byte, past the header) inflated into out[1..n]. out is the
-- one buffer every call reuses, so its contents past n are another file's.
local OUT = {}
local function Inflate(s)
	local pos, buf, have, n, out = 3, 0, 0, 0, OUT
	local function bits(k)
		while have < k do
			buf, pos, have = buf + byte(s, pos) * POW[have], pos + 1, have + 8
		end
		local v = buf % POW[k]
		buf, have = (buf - v) / POW[k], have - k
		return v
	end
	-- decode(h) -> the next symbol of code h. The lookup reads ahead up to FAST bits; a valid stream always has them,
	-- since the zlib stream ends with its four-byte checksum after the last code.
	local function decode(h)
		while have < FAST do
			buf, pos, have = buf + byte(s, pos) * POW[have], pos + 1, have + 8
		end
		local entry = h.fast[buf % SPAN]
		if entry then
			local len = entry % 16
			local p = POW[len]
			buf, have = (buf - buf % p) / p, have - len
			return (entry - len) / 16
		end
		local count, symbol = h.count, h.symbol
		local code, first, index = 0, 0, 0
		for len = 1, 15 do
			if have == 0 then buf, pos, have = byte(s, pos), pos + 1, 8 end
			local bit = buf % 2
			buf, have, code = (buf - bit) / 2, have - 1, code + bit
			local c = count[len]
			if code - c < first then return symbol[index + code - first] end
			index, first, code = index + c, (first + c) * 2, code * 2
		end
		error("png.lua: bad Huffman code")
	end
	repeat
		local last, kind = bits(1), bits(2)
		if kind == 0 then
			-- A stored block starts on a byte: the partial byte's bits are dropped, and whole bytes read ahead go back.
			pos = pos - (have - have % 8) / 8
			buf, have = 0, 0
			local len = byte(s, pos) + 256 * byte(s, pos + 1)
			for i = 1, len do out[n + i] = byte(s, pos + 3 + i) end
			n = n + len
			pos = pos + 4 + len
		else
			local lengths, nlen, ndist = {}, 288, 30
			if kind == 1 then
				for i = 0, 317 do lengths[i] = i < 144 and 8 or i < 256 and 9 or i < 280 and 7 or i < 288 and 8 or 5 end
			else
				nlen, ndist = bits(5) + 257, bits(5) + 1
				local code = {}
				for i = 0, 18 do code[i] = 0 end
				for i = 1, bits(4) + 4 do code[ORDER[i]] = bits(3) end
				code = Huffman(code, 19)
				local i = 0
				while i < nlen + ndist do
					local sym, rep, val = decode(code), 1
					if sym < 16 then val = sym
					elseif sym == 16 then val, rep = lengths[i - 1], 3 + bits(2)
					else val, rep = 0, sym == 17 and 3 + bits(3) or 11 + bits(7) end
					for _ = 1, rep do lengths[i], i = val, i + 1 end
				end
			end
			local dist = {}
			for i = 0, ndist - 1 do dist[i] = lengths[nlen + i] end
			local lit, dists = Huffman(lengths, nlen), Huffman(dist, ndist)
			local fast = lit.fast
			while true do
				-- decode(lit)'s lookup, written out: most of a file's bytes are literals, and a call each costs a third
				-- of the inflate time.
				while have < FAST do
					buf, pos, have = buf + byte(s, pos) * POW[have], pos + 1, have + 8
				end
				local sym
				local entry = fast[buf % SPAN]
				if entry then
					local len = entry % 16
					local p = POW[len]
					buf, have, sym = (buf - buf % p) / p, have - len, (entry - len) / 16
				else
					sym = decode(lit)
				end
				if sym < 256 then
					n = n + 1
					out[n] = sym
				elseif sym == 256 then
					break
				else
					local len, extra = LBASE[sym - 257], LEXT[sym - 257]
					if extra > 0 then len = len + bits(extra) end
					local d = decode(dists)
					local back = DBASE[d]
					if DEXT[d] > 0 then back = back + bits(DEXT[d]) end
					for i = n + 1, n + len do out[i] = out[i - back] end
					n = n + len
				end
			end
		end
	until last == 1
	return out, n
end

local function U32(s, i)
	local a, b, c, d = s:byte(i, i + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

-- HALF[v] = floor(v / 2), for the Average filter's sum of two bytes.
local HALF = {}
for v = 0, 510 do HALF[v] = (v - v % 2) / 2 end

function Png.Coverage(path)
	local file = assert(io.open(path, "rb"), "png.lua: cannot open " .. path)
	local s = file:read("*a")
	file:close()
	assert(s:sub(1, 8) == "\137PNG\r\n\26\n", path .. " is no PNG")
	local pos, idat, w, h, depth = 9, {}, nil, nil, nil
	while pos < #s do
		local len, kind = U32(s, pos), s:sub(pos + 4, pos + 7)
		if kind == "IHDR" then
			w, h = U32(s, pos + 8), U32(s, pos + 12)
			local color = s:byte(pos + 17)
			assert(s:byte(pos + 16) == 8 and (color == 6 or color == 2) and s:byte(pos + 20) == 0, path .. ": png.lua reads 8-bit RGBA or RGB, non-interlaced PNGs only")
			depth = color == 6 and 4 or 3
		elseif kind == "IDAT" then
			idat[#idat + 1] = s:sub(pos + 8, pos + 7 + len)
		end
		pos = pos + 12 + len
	end
	local stride = w * depth
	local raw, n = Inflate(table.concat(idat))
	-- The reused buffer holds another file's bytes past n, so a short stream must stop here rather than be read past.
	assert(n == h * (stride + 1), path .. ": png.lua inflated " .. n .. " bytes, not the " .. h * (stride + 1) .. " its size needs")
	local rows, prev, cur, cover = {}, {}, {}, {}
	for i = 1, stride do prev[i] = 0 end
	for y = 0, h - 1 do
		local base = y * (stride + 1) + 1
		local filter = raw[base]
		-- The filters add modulo 256 by subtracting 256 from a sum over 255; a byte to the left of the row is 0.
		if filter == 0 then
			for i = 1, stride do cur[i] = raw[base + i] end
		elseif filter == 1 then
			for i = 1, depth do cur[i] = raw[base + i] end
			for i = depth + 1, stride do
				local v = raw[base + i] + cur[i - depth]
				cur[i] = v > 255 and v - 256 or v
			end
		elseif filter == 2 then
			for i = 1, stride do
				local v = raw[base + i] + prev[i]
				cur[i] = v > 255 and v - 256 or v
			end
		elseif filter == 3 then
			for i = 1, depth do
				local v = raw[base + i] + HALF[prev[i]]
				cur[i] = v > 255 and v - 256 or v
			end
			for i = depth + 1, stride do
				local v = raw[base + i] + HALF[cur[i - depth] + prev[i]]
				cur[i] = v > 255 and v - 256 or v
			end
		else
			assert(filter == 4, "png.lua: bad row filter")
			-- Paeth with the left and upper-left bytes 0 predicts the byte above.
			for i = 1, depth do
				local v = raw[base + i] + prev[i]
				cur[i] = v > 255 and v - 256 or v
			end
			for i = depth + 1, stride do
				local a, b, c = cur[i - depth], prev[i], prev[i - depth]
				local pa, pb, pc = b - c, a - c, a + b - c - c
				if pa < 0 then pa = -pa end
				if pb < 0 then pb = -pb end
				if pc < 0 then pc = -pc end
				local v = raw[base + i] + ((pa <= pb and pa <= pc) and a or pb <= pc and b or c)
				cur[i] = v > 255 and v - 256 or v
			end
		end
		if depth == 4 then
			for x = 1, w do cover[x] = cur[x * 4] end
		else
			for x = 1, w do
				local r, g, b = cur[x * 3 - 2], cur[x * 3 - 1], cur[x * 3]
				if g > r then r = g end
				cover[x] = b > r and b or r
			end
		end
		rows[y], prev, cur = char(unpack(cover, 1, w)), cur, prev
	end
	return rows, w, h
end

function Png.Alpha(path)
	local rows, w, h = Png.Coverage(path)
	return function(x, y) return byte(rows[y], x + 1) end, w, h
end

return Png
