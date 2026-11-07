-- color_lint.lua: find colour literals in addon source. Colours belong in Core/Tokens.lua.
--
--   local Lint = dofile("Tools/regression/color_lint.lua")
--   Lint.Lua(source) -> { { kind, text, line }, ... }
--   Lint.Xml(source) -> { { kind, text, line }, ... }
--
-- Kinds:
--   hex         A string that is "#rrggbb" or "#rrggbbaa", is six or eight hex digits alone, or holds a
--               |cAARRGGBB colour escape. "|cn<NAME>:" named colours and format strings are not literals.
--   hex-number  A 0x number with exactly six or eight hex digits.
--   rgb-call    A call of a function or method whose name holds Color or Colour, with number literals as
--               its first three arguments: SetVertexColor(1, 1, 1), CreateColor(0.2, 0.4, 1).
--   rgb-table   A table constructor whose r, g and b fields are all number literals.
--   xml-color   An XML element whose name ends in Color with r, g and b attributes.
--
-- Comments are skipped in both languages.

local Source = dofile("Tools/regression/lua_source.lua")

local Lint = {}

local function isHexString(s)
	if s:match("^#%x%x%x%x%x%x$") or s:match("^#%x%x%x%x%x%x%x%x$") then
		return true
	end
	if (#s == 6 or #s == 8) and s:match("^%x+$") then
		return true
	end
	return s:match("|[cC]%x%x%x%x%x%x%x%x") ~= nil
end

local function isHexNumber(s)
	local digits = s:match("^0[xX](%x+)$")
	return digits ~= nil and (#digits == 6 or #digits == 8)
end

local function isOp(t, value)
	return t.type == "op" and t.value == value
end

-- The number literal arguments at the start of a call whose "(" is at index i.
local function leadingNumbers(tokens, i)
	local count, j = 0, i + 1
	while tokens[j].type == "number" do
		count = count + 1
		if not isOp(tokens[j + 1], ",") then
			break
		end
		j = j + 2
	end
	return count
end

local RGB = { r = true, g = true, b = true }

function Lint.Lua(source)
	local tokens = Source.Lex(source)
	local findings = {}
	local function add(kind, text, line)
		findings[#findings + 1] = { kind = kind, text = text, line = line }
	end
	-- One frame per open { holds the r, g and b fields given number literals.
	local tables = {}
	for i, t in ipairs(tokens) do
		if t.type == "string" and isHexString(t.value) then
			add("hex", '"' .. t.value .. '"', t.line)
		elseif t.type == "number" and isHexNumber(t.value) then
			add("hex-number", t.value, t.line)
		elseif t.type == "name" and (t.value:find("Color", 1, true) or t.value:find("Colour", 1, true)) then
			local open = tokens[i + 1]
			if isOp(open, "(") and leadingNumbers(tokens, i + 1) >= 3 then
				add("rgb-call", t.value .. "(...)", t.line)
			end
		elseif isOp(t, "{") then
			tables[#tables + 1] = { line = t.line, fields = {} }
		elseif isOp(t, "}") then
			local frame = table.remove(tables)
			if frame and frame.fields.r and frame.fields.g and frame.fields.b then
				add("rgb-table", "{ r, g, b }", frame.line)
			end
		elseif t.type == "name" and RGB[t.value] and tables[#tables] then
			local before, eq, value, after = tokens[i - 1], tokens[i + 1], tokens[i + 2], tokens[i + 3]
			local starts = isOp(before, "{") or isOp(before, ",") or isOp(before, ";")
			local ends = after and (isOp(after, ",") or isOp(after, ";") or isOp(after, "}"))
			if starts and isOp(eq, "=") and value.type == "number" and ends then
				tables[#tables].fields[t.value] = true
			end
		end
	end
	return findings
end

function Lint.Xml(source)
	local findings = {}
	-- Blank out comments but keep their line breaks, so line numbers stay right.
	local text = source:gsub("<!%-%-(.-)%-%->", function(body)
		return (body:gsub("[^\n]", " "))
	end)
	local pos = 1
	while true do
		local start, stop, name, attrs = text:find("<([%w_]+)([^>]*)>", pos)
		if not start then
			break
		end
		if name:match("Colou?r$") then
			local has = {}
			for key in (" " .. attrs):gmatch("%s([rgb])%s*=%s*[\"'][%d%.]+[\"']") do
				has[key] = true
			end
			if has.r and has.g and has.b then
				local _, breaks = text:sub(1, start):gsub("\n", "")
				findings[#findings + 1] = { kind = "xml-color", text = "<" .. name .. ">", line = breaks + 1 }
			end
		end
		pos = stop + 1
	end
	return findings
end

return Lint
