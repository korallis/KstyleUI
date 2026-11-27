-- png.lua: Png.Alpha(path) decodes an 8-bit RGBA or RGB, non-interlaced PNG (zlib inflate and row filters in plain Lua 5.1) and returns alpha(x, y), width, height. An RGB file has no alpha: the addon's only RGB files are the aura sheets under Media/Textures/Auras, drawn with the ADD blend, where black adds nothing, so its alpha is its brightest channel.
local Png = {}
local floor = math.floor

local LBASE, LEXT, DBASE, DEXT = {}, {}, {}, {}
do
	local b = 3
	for i = 0, 27 do
		LEXT[i] = i < 8 and 0 or floor(i / 4) - 1
		LBASE[i], b = b, b + 2 ^ LEXT[i]
	end
	LBASE[28], LEXT[28], b = 258, 0, 1
	for i = 0, 29 do
		DEXT[i] = i < 4 and 0 or floor(i / 2) - 1
		DBASE[i], b = b, b + 2 ^ DEXT[i]
	end
end
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

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
	return { count = count, symbol = symbol }
end

local function Inflate(s)
	local pos, buf, have, out = 3, 0, 0, {}
	local function bits(n)
		while have < n do
			buf, pos, have = buf + s:byte(pos) * 2 ^ have, pos + 1, have + 8
		end
		local v = buf % 2 ^ n
		buf, have = (buf - v) / 2 ^ n, have - n
		return v
	end
	local function decode(h)
		local code, first, index = 0, 0, 0
		for len = 1, 15 do
			code = code + bits(1)
			local c = h.count[len]
			if code - c < first then return h.symbol[index + code - first] end
			index, first, code = index + c, (first + c) * 2, code * 2
		end
		error("png.lua: bad Huffman code")
	end
	repeat
		local last, kind = bits(1), bits(2)
		if kind == 0 then
			buf, have = 0, 0
			local len = s:byte(pos) + 256 * s:byte(pos + 1)
			for i = pos + 4, pos + 3 + len do out[#out + 1] = s:byte(i) end
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
			while true do
				local sym = decode(lit)
				if sym == 256 then break end
				if sym < 256 then
					out[#out + 1] = sym
				else
					local len = LBASE[sym - 257] + bits(LEXT[sym - 257])
					local d = decode(dists)
					local back = DBASE[d] + bits(DEXT[d])
					for _ = 1, len do out[#out + 1] = out[#out + 1 - back] end
				end
			end
		end
	until last == 1
	return out
end

local function U32(s, i)
	local a, b, c, d = s:byte(i, i + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

function Png.Alpha(path)
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
	local raw, stride, rows, prev = Inflate(table.concat(idat)), w * depth, {}, {}
	for y = 0, h - 1 do
		local base, cur = y * (stride + 1) + 1, {}
		local filter = raw[base]
		for i = 1, stride do
			local x, a, b, c = raw[base + i], cur[i - depth] or 0, prev[i] or 0, prev[i - depth] or 0
			if filter == 1 then x = x + a
			elseif filter == 2 then x = x + b
			elseif filter == 3 then x = x + floor((a + b) / 2)
			elseif filter == 4 then
				local p = a + b - c
				local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
				x = x + ((pa <= pb and pa <= pc) and a or pb <= pc and b or c)
			end
			cur[i] = x % 256
		end
		rows[y], prev = cur, cur
	end
	if depth == 3 then
		return function(x, y)
			local row = rows[y]
			return math.max(row[x * 3 + 1], row[x * 3 + 2], row[x * 3 + 3])
		end, w, h
	end
	return function(x, y) return rows[y][x * 4 + 4] end, w, h
end

return Png
