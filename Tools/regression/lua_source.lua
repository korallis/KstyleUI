-- lua_source.lua: tokenize Lua 5.1 source and walk it with blocks and local scopes, for the source scanners.
--
--   local Source = dofile("Tools/regression/lua_source.lua")
--   local tokens = Source.Lex(text)        -- { { type, value, line }, ..., { type = "eof" } }
--   Source.Walk(text, hooks)               -- errors on unbalanced brackets or blocks
--
-- Token types: name, keyword, number, string (value is the text between the quotes), op, eof.
-- Comments are dropped.
--
-- Walk visits the tokens in order. It keeps a stack of open blocks and brackets and the locals each
-- block declares, and calls these optional hooks:
--
--   hooks.Annotate(w, from, to, n) -> value
--     The value to store for a local, from the expression in tokens from..to. n is 1, or 2 and up
--     for the extra results of a final call (local a, b = f()). from is nil when the local gets
--     no value. Reassigning a local calls Annotate again. A reassignment in a nested block or
--     function may not run, so there a nil value never replaces the local's value.
--   hooks.Path(w, p)
--     A name and its field and index suffixes: p = { from, to, root, segs, role }. role is
--     "assign" for an assignment target or a function statement's name, else "use". Each seg is
--     { kind = "name" | "string" | "number" | "expr", key, from, to }. Plain assignments to a
--     local, local declarations, parameters and table-constructor keys are not paths.
--   hooks.Token(w, i)
--     Every token the walk visits. Names in local, for and function headers are not visited.
--
-- During a hook, w:Resolve(name) returns isLocal, value; w:Path(i) parses a path at name token i;
-- w:ExprEnd(i) returns the last token of the expression that starts at i.

local Source = {}

local KEYWORDS = {}
for word in ([[and break do else elseif end false for function if in local nil not or repeat return then true until while]]):gmatch("%a+") do
	KEYWORDS[word] = true
end

local OPS3 = { ["..."] = true }
local OPS2 = { [".."] = true, ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, ["::"] = true }

local function fail(line, message)
	error("line " .. line .. ": " .. message, 0)
end

-- Returns the index after a long bracket's closing ]=*], the contents, and the lines it spans.
local function longBracket(text, pos, line)
	local open = text:match("^%[(=*)%[", pos)
	if not open then
		return nil
	end
	local start = pos + #open + 2
	local close = "]" .. open .. "]"
	local stop = text:find(close, start, true)
	if not stop then
		return false
	end
	local body = text:sub(start, stop - 1)
	local _, newlines = body:gsub("\n", "")
	return stop + #close, body, line + newlines
end

function Source.Lex(text)
	local tokens = {}
	local pos, line, len = 1, 1, #text
	local function push(kind, value, at)
		tokens[#tokens + 1] = { type = kind, value = value, line = at }
	end
	while pos <= len do
		local c = text:sub(pos, pos)
		if c == "\n" then
			line = line + 1
			pos = pos + 1
		elseif c:match("%s") then
			pos = pos + 1
		elseif text:sub(pos, pos + 1) == "--" then
			local after, _, endLine = longBracket(text, pos + 2, line)
			if after then
				pos, line = after, endLine
			elseif after == false then
				fail(line, "unfinished long comment")
			else
				pos = (text:find("\n", pos, true) or len + 1)
			end
		elseif c:match("[%a_]") then
			local word = text:match("^[%w_]+", pos)
			push(KEYWORDS[word] and "keyword" or "name", word, line)
			pos = pos + #word
		elseif c:match("%d") or (c == "." and text:sub(pos + 1, pos + 1):match("%d")) then
			local number = text:match("^0[xX]%x+", pos)
			if not number then
				number = text:match("^%d*%.?%d*", pos)
				number = number .. (text:match("^[eE][%+%-]?%d+", pos + #number) or "")
			end
			push("number", number, line)
			pos = pos + #number
		elseif c == '"' or c == "'" then
			local i, startLine = pos + 1, line
			while true do
				local ch = text:sub(i, i)
				if ch == "" or ch == "\n" then
					fail(startLine, "unfinished string")
				elseif ch == "\\" then
					-- A backslash before a line break continues the string. CRLF counts as one break.
					local pair = text:sub(i + 1, i + 2)
					if pair == "\r\n" or pair == "\n\r" then
						line, i = line + 1, i + 3
					elseif pair:sub(1, 1) == "\n" or pair:sub(1, 1) == "\r" then
						line, i = line + 1, i + 2
					else
						i = i + 2
					end
				elseif ch == c then
					break
				else
					i = i + 1
				end
			end
			push("string", text:sub(pos + 1, i - 1), startLine)
			pos = i + 1
		elseif c == "[" and text:match("^%[=*%[", pos) then
			local after, body, endLine = longBracket(text, pos, line)
			if not after then
				fail(line, "unfinished long string")
			end
			push("string", body, line)
			pos, line = after, endLine
		else
			local three, two = text:sub(pos, pos + 2), text:sub(pos, pos + 1)
			local op = OPS3[three] and three or OPS2[two] and two or c
			push("op", op, line)
			pos = pos + #op
		end
	end
	push("eof", "", line)
	return tokens
end

local function isOp(t, value)
	return t.type == "op" and t.value == value
end

local function isKeyword(t, value)
	return t.type == "keyword" and t.value == value
end
Source.IsOp, Source.IsKeyword = isOp, isKeyword

-- A call's arguments start with (, { or a string.
function Source.IsArgs(t)
	return t.type == "string" or isOp(t, "(") or isOp(t, "{")
end

local CLOSERS = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local OPENS_BLOCK = { ["function"] = true, ["if"] = true, ["do"] = true, ["repeat"] = true }

-- Pairs each bracket and block opener with its closer: match[open] = close and match[close] = open.
local function matchPairs(tokens)
	local match, stack = {}, {}
	local function close(i, want)
		local open = stack[#stack]
		local t = tokens[i]
		if not open then
			fail(t.line, "'" .. t.value .. "' closes nothing")
		end
		local o = tokens[open]
		if not want[o.value] then
			fail(o.line, "'" .. o.value .. "' is not closed before '" .. t.value .. "' on line " .. t.line)
		end
		stack[#stack] = nil
		match[open], match[i] = i, open
	end
	for i, t in ipairs(tokens) do
		if t.type == "op" and CLOSERS[t.value] then
			stack[#stack + 1] = i
		elseif t.type == "op" and (t.value == ")" or t.value == "]" or t.value == "}") then
			close(i, { [t.value == ")" and "(" or t.value == "]" and "[" or "{"] = true })
		elseif t.type == "keyword" and OPENS_BLOCK[t.value] then
			stack[#stack + 1] = i
		elseif isKeyword(t, "end") then
			close(i, { ["function"] = true, ["if"] = true, ["do"] = true })
		elseif isKeyword(t, "until") then
			close(i, { ["repeat"] = true })
		end
	end
	if #stack > 0 then
		local o = tokens[stack[#stack]]
		fail(o.line, "'" .. o.value .. "' is not closed")
	end
	return match
end

local UNARY = { ["not"] = true, ["-"] = true, ["#"] = true }
local BINARY = {}
for op in ([[+ - * / % ^ .. == ~= < > <= >= and or]]):gmatch("%S+") do
	BINARY[op] = true
end

local function isUnary(t)
	return (t.type == "op" or t.type == "keyword") and UNARY[t.value]
end

local function isBinary(t)
	return (t.type == "op" or t.type == "keyword") and BINARY[t.value]
end

local Walker = {}
Walker.__index = Walker

-- The last token of a primary expression with its suffixes, starting at i.
function Walker:PrimaryEnd(i)
	local tokens, match = self.tokens, self.match
	local t = tokens[i]
	if isOp(t, "{") or isKeyword(t, "function") then
		return match[i]
	end
	if t.type ~= "name" and not isOp(t, "(") then
		return i
	end
	if isOp(t, "(") then
		i = match[i]
	end
	while true do
		local n = tokens[i + 1]
		if isOp(n, ".") and tokens[i + 2].type == "name" then
			i = i + 2
		elseif isOp(n, "[") or isOp(n, "(") or isOp(n, "{") then
			i = match[i + 1]
		elseif n.type == "string" then
			i = i + 1
		elseif isOp(n, ":") and tokens[i + 2].type == "name" then
			local args = tokens[i + 3]
			i = args.type == "string" and i + 3 or match[i + 3] or i + 2
		else
			return i
		end
	end
end

function Walker:ExprEnd(i)
	local tokens = self.tokens
	while isUnary(tokens[i]) do
		i = i + 1
	end
	i = self:PrimaryEnd(i)
	while isBinary(tokens[i + 1]) do
		i = i + 2
		while isUnary(tokens[i]) do
			i = i + 1
		end
		i = self:PrimaryEnd(i)
	end
	return i
end

-- Expressions separated by commas from i: { { from, to }, ... }.
function Walker:ExprList(i)
	local list = {}
	while true do
		local stop = self:ExprEnd(i)
		list[#list + 1] = { from = i, to = stop }
		if not isOp(self.tokens[stop + 1], ",") then
			return list
		end
		i = stop + 2
	end
end

function Walker:Path(i)
	local tokens = self.tokens
	local p = { from = i, to = i, root = tokens[i].value, segs = {} }
	while true do
		local n = tokens[p.to + 1]
		if isOp(n, ".") and tokens[p.to + 2].type == "name" then
			p.segs[#p.segs + 1] = { kind = "name", key = tokens[p.to + 2].value, from = p.to + 1, to = p.to + 2 }
			p.to = p.to + 2
		elseif isOp(n, "[") then
			local close = self.match[p.to + 1]
			local inner = tokens[p.to + 2]
			local seg = { kind = "expr", from = p.to + 1, to = close }
			if close == p.to + 3 and (inner.type == "string" or inner.type == "number") then
				seg.kind, seg.key = inner.type, inner.value
			end
			p.segs[#p.segs + 1] = seg
			p.to = close
		else
			return p
		end
	end
end

-- ".name", ["key"], [1], or [?] for a key computed at run time.
function Source.SegText(seg)
	if seg.kind == "name" or (seg.kind == "string" and seg.key:match("^[%a_][%w_]*$") and not KEYWORDS[seg.key]) then
		return "." .. seg.key
	elseif seg.kind == "string" then
		return '["' .. seg.key .. '"]'
	elseif seg.kind == "number" then
		return "[" .. seg.key .. "]"
	end
	return "[?]"
end

function Walker:Resolve(name)
	for s = #self.stack, 1, -1 do
		local vars = self.stack[s].vars
		local entry = vars and vars[name]
		if entry then
			return true, entry.value
		end
	end
	local entry = self.vars[name]
	if entry then
		return true, entry.value
	end
	return false, nil
end

-- The locals table of the innermost block, or the file's.
function Walker:Scope()
	for s = #self.stack, 1, -1 do
		if self.stack[s].vars then
			return self.stack[s].vars
		end
	end
	return self.vars
end

-- The locals table that declares name, if any.
function Walker:Owner(name)
	for s = #self.stack, 1, -1 do
		local vars = self.stack[s].vars
		if vars and vars[name] then
			return vars
		end
	end
	return self.vars[name] and self.vars or nil
end

function Walker:Annotate(list, n)
	local hook = self.hooks.Annotate
	if not hook then
		return nil
	end
	if not list or #list == 0 then
		return hook(self, nil, nil, 1)
	end
	if n <= #list then
		return hook(self, list[n].from, list[n].to, 1)
	end
	local last = list[#list]
	return hook(self, last.from, last.to, n - #list + 1)
end

-- Sets name in vars once the walk reaches token at.
function Walker:Later(at, vars, name, value)
	self.pending[#self.pending + 1] = { at = at, vars = vars, name = name, value = value }
end

-- Reassigns a local that owner declares. An assignment in a nested block or function may not run,
-- so there it can give the local a value but never clear one.
function Walker:Reassign(at, owner, name, value)
	if value ~= nil or owner == self:Scope() then
		self:Later(at, owner, name, value)
	end
end

function Walker:ApplyPending(i)
	local keep = {}
	for _, item in ipairs(self.pending) do
		if item.at <= i then
			item.vars[item.name] = { value = item.value }
		else
			keep[#keep + 1] = item
		end
	end
	self.pending = keep
end

function Walker:Push(kind, i, vars)
	self.stack[#self.stack + 1] = { kind = kind, at = i, vars = vars }
end

function Walker:Pop()
	local top = self.stack[#self.stack]
	self.stack[#self.stack] = nil
	return top
end

-- local a, b = ... and local function f. Returns the next token to visit.
function Walker:Local(i)
	local tokens = self.tokens
	if isKeyword(tokens[i + 1], "function") then
		self:Scope()[tokens[i + 2].value] = { value = nil }
		return self:Function(i + 1, true)
	end
	local names = {}
	local j = i + 1
	while tokens[j].type == "name" do
		names[#names + 1] = tokens[j].value
		if not isOp(tokens[j + 1], ",") then
			j = j + 1
			break
		end
		j = j + 2
	end
	local vars = self:Scope()
	if not isOp(tokens[j], "=") then
		for _, name in ipairs(names) do
			vars[name] = { value = self:Annotate(nil) }
		end
		return j
	end
	local list = self:ExprList(j + 1)
	local at = list[#list].to + 1
	for n, name in ipairs(names) do
		self:Later(at, vars, name, self:Annotate(list, n))
	end
	return j + 1
end

-- function [name] (params) body end. Returns the token after the parameter list.
function Walker:Function(i, isLocal)
	local tokens = self.tokens
	local j = i + 1
	local params = {}
	if tokens[j].type == "name" then
		local p = self:Path(j)
		local method = isOp(tokens[p.to + 1], ":") and tokens[p.to + 2]
		if method then
			p.segs[#p.segs + 1] = { kind = "name", key = method.value, from = p.to + 1, to = p.to + 2 }
			p.to = p.to + 2
			params.self = { value = nil }
		end
		if not isLocal then
			local owner = #p.segs == 0 and self:Owner(p.root)
			if owner then
				self:Reassign(i, owner, p.root, nil)
			elseif self.hooks.Path then
				p.role = "assign"
				self.hooks.Path(self, p)
			end
		end
		j = p.to + 1
	end
	if not isOp(tokens[j], "(") then
		fail(tokens[j].line, "expected ( after function")
	end
	for k = j + 1, self.match[j] - 1 do
		if tokens[k].type == "name" then
			params[tokens[k].value] = { value = nil }
		end
	end
	self:Push("function", i, params)
	return self.match[j] + 1
end

-- for a, b in ... do / for i = ... do: the names belong to the block the next do opens.
function Walker:For(i)
	local tokens = self.tokens
	local names = {}
	local j = i + 1
	while tokens[j].type == "name" or isOp(tokens[j], ",") do
		if tokens[j].type == "name" then
			names[tokens[j].value] = { value = nil }
		end
		j = j + 1
	end
	self.loopVars = names
	return j
end

-- A path that starts a statement may be the first target of an assignment.
function Walker:Statement(i, p)
	local tokens = self.tokens
	local targets = { p }
	local k = p.to + 1
	while isOp(tokens[k], ",") and tokens[k + 1].type == "name" do
		local q = self:Path(k + 1)
		targets[#targets + 1] = q
		k = q.to + 1
	end
	if not isOp(tokens[k], "=") then
		return false
	end
	local list = self:ExprList(k + 1)
	local at = list[#list].to + 1
	for n, target in ipairs(targets) do
		self.visited[target.from] = true
		local owner = #target.segs == 0 and self:Owner(target.root)
		if owner then
			self:Reassign(at, owner, target.root, self:Annotate(list, n))
		elseif self.hooks.Path then
			target.role = "assign"
			self.hooks.Path(self, target)
		end
	end
	return true
end

local function inStatement(stack)
	local top = stack[#stack]
	return not top or top.vars ~= nil or top.kind == "if" or top.kind == "repeat"
end

function Source.Walk(text, hooks)
	local tokens = Source.Lex(text)
	local w = setmetatable({
		tokens = tokens,
		match = matchPairs(tokens),
		hooks = hooks or {},
		stack = {},
		vars = {},
		pending = {},
		visited = {},
		closeAt = {},
	}, Walker)
	local i = 1
	while tokens[i].type ~= "eof" do
		w:ApplyPending(i)
		while w.closeAt[#w.stack] and w.closeAt[#w.stack] < i do
			w.closeAt[#w.stack] = nil
			w:Pop()
		end
		local t = tokens[i]
		if w.hooks.Token then
			w.hooks.Token(w, i)
		end
		local nextI = i + 1
		local prev = tokens[i - 1]
		if t.type == "keyword" then
			if t.value == "local" then
				nextI = w:Local(i)
			elseif t.value == "function" then
				nextI = w:Function(i, false)
			elseif t.value == "for" then
				nextI = w:For(i)
			elseif t.value == "do" then
				w:Push("do", i, w.loopVars or {})
				w.loopVars = nil
			elseif t.value == "if" then
				w:Push("if", i, {})
			elseif t.value == "else" or t.value == "elseif" then
				w.stack[#w.stack].vars = {}
			elseif t.value == "repeat" then
				w:Push("repeat", i, {})
			elseif t.value == "until" then
				w.closeAt[#w.stack] = w:ExprEnd(i + 1)
			elseif t.value == "end" then
				w:Pop()
			end
		elseif t.type == "op" then
			if CLOSERS[t.value] then
				w:Push(t.value, i, nil)
			elseif t.value == ")" or t.value == "]" or t.value == "}" then
				w:Pop()
			end
		elseif t.type == "name" and not w.visited[i] and not (prev and (isOp(prev, ".") or isOp(prev, ":"))) then
			local top = w.stack[#w.stack]
			local isKey = top and top.kind == "{" and isOp(tokens[i + 1], "=")
			if not isKey then
				local p = w:Path(i)
				if not (inStatement(w.stack) and w:Statement(i, p)) and w.hooks.Path then
					p.role = "use"
					w.hooks.Path(w, p)
				end
			end
		end
		i = nextI
	end
	return w
end

return Source
