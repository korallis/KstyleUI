-- test-lua-source.lua: the Lua tokenizer and walker that the source scanners share.
local Source = dofile("Tools/regression/lua_source.lua")

local function render(tokens)
	local out = {}
	for _, t in ipairs(tokens) do
		out[#out + 1] = t.type .. ":" .. t.value .. "@" .. t.line
	end
	return table.concat(out, " ")
end

local function expectEqual(got, want, what)
	assert(got == want, what .. "\n  got:  " .. tostring(got) .. "\n  want: " .. tostring(want))
end

-- Tokens: comments go, strings keep their contents, long brackets and escapes count lines.
expectEqual(
	render(Source.Lex('local a = "x\\"y" -- note\nb.c:d([[long\nstring]], 0x1F, 1e-3, .5, ...)\n--[==[ block\ncomment ]==] e ~= f')),
	"keyword:local@1 name:a@1 op:=@1 string:x\\\"y@1 name:b@2 op:.@2 name:c@2 op::@2 name:d@2 op:(@2 "
		.. "string:long\nstring@2 op:,@3 number:0x1F@3 op:,@3 number:1e-3@3 op:,@3 number:.5@3 op:,@3 op:...@3 "
		.. "op:)@3 name:e@5 op:~=@5 name:f@5 eof:@5",
	"tokens"
)
expectEqual(
	render(Source.Lex("a = 'it\\'s' .. [=[x]]y]=] == b <= c >= d\n-- last line comment")),
	"name:a@1 op:=@1 string:it\\'s@1 op:..@1 string:x]]y@1 op:==@1 name:b@1 op:<=@1 name:c@1 op:>=@1 name:d@1 eof:@2",
	"operators and long strings"
)
expectEqual(render(Source.Lex('s = "a\\\nb" t')), "name:s@1 op:=@1 string:a\\\nb@1 name:t@2 eof:@2", "escaped newline")
expectEqual(render(Source.Lex('s = "a\\\r\nb"\r\nt')), "name:s@1 op:=@1 string:a\\\r\nb@1 name:t@3 eof:@3", "escaped CRLF")

local ok, err = pcall(Source.Lex, 'x = 1\ny = "open')
assert(not ok and err:find("line 2", 1, true) and err:find("unfinished string", 1, true), tostring(err))
ok, err = pcall(Source.Lex, "x = [[open")
assert(not ok and err:find("unfinished long string", 1, true), tostring(err))
ok, err = pcall(Source.Walk, "if x then\n  f(\nend", {})
assert(not ok and err:find("line 2", 1, true), "an unclosed bracket names its line: " .. tostring(err))

-- The walker: each path gets a role, and each local hides the global of the same name. Annotate
-- gives each local the text of the value it was given, so the test can read what a name resolves to.
local function exprText(w, from, to, n)
	if not from then
		return "nil"
	end
	local parts = {}
	for i = from, to do
		parts[#parts + 1] = w.tokens[i].value
	end
	return table.concat(parts, " ") .. (n > 1 and "#" .. n or "")
end

local function walk(source)
	local seen = {}
	Source.Walk(source, {
		Annotate = exprText,
		Path = function(w, p)
			local isLocal, value = w:Resolve(p.root)
			local text = p.root
			for _, seg in ipairs(p.segs) do
				text = text .. Source.SegText(seg)
			end
			seen[#seen + 1] = p.role .. " " .. text .. (isLocal and " = " .. tostring(value) or "") .. " @" .. w.tokens[p.from].line
		end,
	})
	return table.concat(seen, "\n")
end

expectEqual(
	walk([[
local a, b = X, Y.z
local function f(button, ...)
	button:Hide()
	a.q[k] = 1
end
for i, v in pairs(t) do v:Show() end
c, d["e f"] = 1, 2
local t = { text = 1, [k] = 2, n }
a = W
local x, y, z = g(), h()
_G[name].field = nil
function M.On:Event() end
local q = q + 1]]),
	table.concat({
		"use X @1",
		"use Y.z @1",
		"use button = nil @3",
		'assign a.q[?] = X @4',
		"use k @4",
		"use pairs @6",
		"use t @6",
		"use v = nil @6",
		'assign c @7',
		'assign d["e f"] @7',
		"use k @8",
		"use n @8",
		"use W @9",
		"use g @10",
		"use h @10",
		"assign _G[?].field @11",
		"use name @11",
		"assign M.On.Event @12",
		"use q @13",
	}, "\n"),
	"walker paths"
)

-- Values a local is given: positional, the extra results of a final call, and none.
local values = {}
Source.Walk("local a, b, c = 1, f()\nlocal d\nlocal e = x and y or z, 2\nd = 7\nlocal g = function() return 1 end\nh = g", {
	Annotate = exprText,
	Path = function(w, p)
		if p.role == "use" then
			local _, value = w:Resolve(p.root)
			values[#values + 1] = p.root .. "=" .. tostring(value)
		end
	end,
	Token = function(w, i)
		if w.tokens[i].value == "d" and w.tokens[i].line == 4 then
			for _, name in ipairs({ "a", "b", "c", "d", "e" }) do
				local _, value = w:Resolve(name)
				values[#values + 1] = name .. "=" .. tostring(value)
			end
		end
	end,
})
expectEqual(
	table.concat(values, " "),
	"f=nil x=nil y=nil z=nil a=1 b=f ( ) c=f ( )#2 d=nil e=x and y or z g=function ( ) return 1 end",
	"local values"
)

-- Scope: a local ends with its block, a reassignment changes its value, and a local is not in
-- scope inside its own value.
values = {}
Source.Walk([[
local f = PlayerFrame
do
	local f = 1
	use(f)
end
use(f)
f = Other
use(f)
local g = g
if x then local h = 1 else use(h) end
while x do local w = 1 end
repeat local r = 1 until r
use(w, r)]], {
	Annotate = exprText,
	Path = function(w, p)
		local isLocal, value = w:Resolve(p.root)
		if p.root ~= "use" then
			values[#values + 1] = p.root .. (isLocal and "=" .. tostring(value) or "@global")
		end
	end,
})
expectEqual(
	table.concat(values, " "),
	"PlayerFrame@global f=1 f=PlayerFrame Other@global f=Other g@global x@global h@global x@global r=1 w@global r@global",
	"scopes"
)

-- Every Lua file in the repository walks without an error.
local pipe = assert(io.popen("git ls-files '*.lua'"))
local count = 0
for path in pipe:lines() do
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	local walked, walkErr = pcall(Source.Walk, text, {
		Path = function(w, p)
			w:Resolve(p.root)
		end,
	})
	assert(walked, path .. ": " .. tostring(walkErr))
	count = count + 1
end
pipe:close()
assert(count > 10, "expected the repository's Lua files, walked " .. count)

print("lua source ok: walked " .. count .. " files")
