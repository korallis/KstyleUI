-- secret_lint.lua: find unsafe uses of secret values, and any use of the combat log, in addon Lua source.
--
--   local Lint = dofile("Tools/regression/secret_lint.lua")
--   Lint(source) -> { { kind, name, line }, ... }   -- sorted by line
--
-- A secret source is one of SOURCES below or any C_UnitAuras function. A secret value is a local
-- given a secret source's result, directly, through select or pcall, or from another secret value,
-- and each field of one (aura.duration). Kinds, and what name holds:
--   compare    a secret value or secret call next to <, >, <=, >=, == or ~=
--   arith      next to +, -, *, /, % or ^
--   length     after #
--   key        after [, as a table key or index
--   bool       after if, elseif, while, until or not, or before and, or, then or do
--   combatlog  any COMBAT_LOG_EVENT name or string, or CombatLogGetCurrentEventInfo
-- name is the local for a secret value and the function as written for a secret call.
--
-- A use is guarded, and allowed, when a check issecretvalue(<the same path>) proves it is not
-- secret:
--   - earlier in the same expression: not issecretvalue(x) and ... x, or issecretvalue(x) or ... x;
--   - in an enclosing if: the branch's condition holds not issecretvalue(x) and no or, or an earlier
--     branch's condition holds issecretvalue(x) and no and;
--   - after if issecretvalue(x) then ... end in the same block, with no and, no other branch, and a
--     body that returns or gives x a value that is not secret.
-- A guard ends when x is given a secret value after the check.

local Source = dofile("Tools/regression/lua_source.lua")
local isOp, isKeyword = Source.IsOp, Source.IsKeyword

local function set(list)
	local out = {}
	for _, name in ipairs(list) do
		out[name] = true
	end
	return out
end

-- UnitHealthMax is secret while unit health is restricted (SecretWhenUnitHealthMaxRestricted).
local SOURCES = set({
	"UnitHealth", "UnitHealthMax", "UnitHealthMissing", "UnitHealthPercent", "UnitInRange", "UnitPower",
	"UnitPowerMax", "UnitCastingInfo", "UnitChannelInfo", "UnitGetIncomingHeals",
})
local COMPARE = set({ "<", ">", "<=", ">=", "==", "~=" })
local ARITH = set({ "+", "-", "*", "/", "%", "^" })
local BOOL_BEFORE = set({ "if", "elseif", "while", "until", "not" })
local BOOL_AFTER = set({ "and", "or", "then", "do" })
local VALUE_KEYWORDS = set({ "nil", "true", "false" })

local function isSourceFunction(text)
	return SOURCES[text] or text:match("^C_UnitAuras%.[%a_][%w_]*$") ~= nil
end

local function isName(t, value)
	return t.type == "name" and t.value == value
end

local function pathText(p)
	local text = p.root
	for _, seg in ipairs(p.segs) do
		text = text .. Source.SegText(seg)
	end
	return text
end

-- What a path holds: { secret = true } for a secret value, { source = text } for a secret source
-- or the C_UnitAuras table, else { text = text } for a global path, or {} for another local.
local function classify(w, p)
	local isLocal, value = w:Resolve(p.root)
	local text
	if isLocal then
		if not value then
			return {}
		elseif value.secret then
			return { secret = true }
		end
		text = value.source
	else
		text = p.root
	end
	for _, seg in ipairs(p.segs) do
		text = text .. Source.SegText(seg)
	end
	text = text:gsub("^_G%.", "")
	if text == "C_UnitAuras" or isSourceFunction(text) then
		return { source = text }
	end
	return { text = (not isLocal) and text or nil }
end

-- Whether the call at path p returns secrets: a secret source, or select(n, <secret source>(...)).
local function secretCall(w, p, info)
	local tokens = w.tokens
	if not Source.IsArgs(tokens[p.to + 1]) then
		return false
	end
	if info.source and isSourceFunction(info.source) then
		return true
	end
	if info.text == "select" and isOp(tokens[p.to + 1], "(") then
		local first = w:ExprEnd(p.to + 2)
		if isOp(tokens[first + 1], ",") and tokens[first + 2].type == "name" then
			local q = w:Path(first + 2)
			local inner = classify(w, q)
			return inner.source ~= nil and isSourceFunction(inner.source) and Source.IsArgs(tokens[q.to + 1])
		end
	end
	return false
end

-- What a local holds when it is given value n of the expression in tokens from..to:
-- { secret = true }, { source = text } for an alias of a secret source, or nil.
local function valueOf(w, from, to, n)
	if not from then
		return nil
	end
	local tokens = w.tokens
	if isOp(tokens[from], "(") and w.match[from] == to then
		return n == 1 and valueOf(w, from + 1, to - 1, 1) or nil -- (f()) keeps only the first value
	end
	if tokens[from].type ~= "name" then
		return nil
	end
	local p = w:Path(from)
	local info = classify(w, p)
	-- pcall(<secret source>, ...) returns ok, then the source's secret results.
	if info.text == "pcall" and isOp(tokens[p.to + 1], "(") and tokens[p.to + 2].type == "name" then
		local q = w:Path(p.to + 2)
		local inner = classify(w, q)
		if inner.source and isSourceFunction(inner.source) and (isOp(tokens[q.to + 1], ",") or isOp(tokens[q.to + 1], ")")) then
			return n >= 2 and { secret = true } or nil
		end
	end
	if secretCall(w, p, info) then
		return { secret = true }
	elseif info.secret then
		return n == 1 and { secret = true } or nil
	elseif info.source and p.to == to and n == 1 then
		return { source = info.source }
	end
	return nil
end

-- The path text that issecretvalue(<path>) at token j checks, or nil.
local function checkAt(w, j)
	local tokens = w.tokens
	if isName(tokens[j], "issecretvalue") and isOp(tokens[j + 1], "(") and tokens[j + 2].type == "name" then
		local p = w:Path(j + 2)
		if isOp(tokens[p.to + 1], ")") then
			return pathText(p)
		end
	end
	return nil
end

-- "not" when a not applies to the check at token j, through any opening brackets
-- (not (issecretvalue(x))), else "is".
local function polarity(tokens, j)
	local k = j - 1
	while k >= 1 and isOp(tokens[k], "(") do
		k = k - 1
	end
	return k >= 1 and isKeyword(tokens[k], "not") and "not" or "is"
end

local function hasKeyword(tokens, from, to, word)
	for k = from, to do
		if isKeyword(tokens[k], word) then
			return true
		end
	end
	return false
end

-- Whether a condition proves text is not secret: when the condition is true ("true": it holds not
-- issecretvalue(text) and no or), or when it is false ("false": issecretvalue(text) and no and).
local function proves(w, cond, text, when)
	local tokens = w.tokens
	local joiner, wanted = "or", "not"
	if when == "false" then
		joiner, wanted = "and", "is"
	end
	if hasKeyword(tokens, cond.from, cond.to, joiner) then
		return false
	end
	for j = cond.from, cond.to do
		if checkAt(w, j) == text and polarity(tokens, j) == wanted then
			return true
		end
	end
	return false
end

-- A check earlier in the same expression: not issecretvalue(text) and ... use, or
-- issecretvalue(text) or ... use. The search stops at a statement keyword, = or ;.
local function guardedInExpression(w, index, text)
	local tokens = w.tokens
	local sawAnd, sawOr = false, false
	for j = index - 1, 1, -1 do
		local t = tokens[j]
		if (t.type == "keyword" and not (t.value == "and" or t.value == "or" or t.value == "not" or VALUE_KEYWORDS[t.value]))
			or isOp(t, "=") or isOp(t, ";") then
			return false
		end
		if isKeyword(t, "and") then
			sawAnd = true
		elseif isKeyword(t, "or") then
			sawOr = true
		elseif checkAt(w, j) == text then
			if polarity(tokens, j) == "not" then
				if not sawOr then
					return true
				end
			elseif not sawAnd then
				return true
			end
		end
	end
	return false
end

-- Whether if block e proves text is not secret, when its value last turned secret at token last.
local function guardedByIf(w, e, text, last)
	for c = 1, #e.conds - 1 do
		local cond = e.conds[c]
		if last <= cond.to and proves(w, cond, text, "false") then
			return true -- an earlier branch took every secret case
		end
	end
	local cond = e.conds[#e.conds]
	if e.inCond or last > cond.to then
		return false
	elseif e.inElse then
		return proves(w, cond, text, "false")
	end
	return proves(w, cond, text, "true")
end

-- A call's ( follows a name, a string or a closing bracket. Any other ( groups an expression.
local function isCallParen(tokens, k)
	local prev = tokens[k - 1]
	return prev ~= nil and (prev.type == "name" or prev.type == "string" or isOp(prev, ")") or isOp(prev, "]") or isOp(prev, "}"))
end

local function kindOf(prev, after)
	local function op(t, list)
		return t.type == "op" and list[t.value]
	end
	if op(prev, COMPARE) or op(after, COMPARE) then
		return "compare"
	elseif op(prev, ARITH) or op(after, ARITH) then
		return "arith"
	elseif isOp(prev, "#") then
		return "length"
	elseif isOp(prev, "[") then
		return "key"
	elseif (prev.type == "keyword" and BOOL_BEFORE[prev.value]) or (after.type == "keyword" and BOOL_AFTER[after.value]) then
		return "bool"
	end
	return nil
end

return function(source)
	local findings = {}
	local lastSecret = {} -- local name -> the token where it was last given a secret value
	local function add(kind, name, line)
		findings[#findings + 1] = { kind = kind, name = name, line = line, order = #findings }
	end
	local function guarded(w, index, text, root)
		if guardedInExpression(w, index, text) then
			return true
		end
		local last = lastSecret[root] or 0
		for s = #w.stack, 1, -1 do
			local e = w.stack[s]
			if e.kind == "if" and guardedByIf(w, e, text, last) then
				return true
			end
		end
		return false
	end

	local w = Source.Walk(source, {
		Annotate = valueOf,

		Path = function(w, p)
			if p.role ~= "use" then
				return
			end
			local tokens = w.tokens
			local info = classify(w, p)
			local name
			if info.secret then
				name = p.root
			elseif secretCall(w, p, info) then
				name = pathText(p)
			else
				return
			end
			local from, stop = p.from, w:PrimaryEnd(p.from)
			while isOp(tokens[from - 1] or tokens[from], "(") and w.match[from - 1] == stop + 1 and not isCallParen(tokens, from - 1) do
				from, stop = from - 1, stop + 1 -- (hp) < 10 compares hp
			end
			local kind = kindOf(tokens[from - 1] or tokens[from], tokens[stop + 1])
			if kind and not guarded(w, p.from, pathText(p), p.root) then
				add(kind, name, tokens[p.from].line)
			end
		end,

		-- Records assignments: when a local turns secret, and what the guarding branch of an if
		-- does to it, for BlockEnd.
		Token = function(w, i)
			local tokens = w.tokens
			local t = tokens[i]
			local top = w.stack[#w.stack]
			local branch = top and top.kind == "if" and not top.inCond and not top.inElse and #top.conds == 1 and top
			if isKeyword(t, "return") then
				if branch then
					branch.exits = true
				end
				return
			end
			local prev = tokens[i - 1]
			if t.type ~= "name" or not isOp(tokens[i + 1], "=") or (top and top.kind == "{")
				or (prev and (isOp(prev, ".") or isOp(prev, ":"))) then
				return
			end
			local value = valueOf(w, i + 2, w:ExprEnd(i + 2), 1)
			local secret = (prev and isOp(prev, ",")) or (value and value.secret) -- a, x = ...: assume secret
			if secret then
				lastSecret[t.value] = i
			end
			if branch then
				branch.assigned = branch.assigned or {}
				if branch.assigned[t.value] ~= "secret" then
					branch.assigned[t.value] = secret and "secret" or "plain"
				end
			end
		end,

		-- After if issecretvalue(x) then return end, or then x = <not secret> end, x is not secret.
		BlockEnd = function(w, e)
			if e.kind ~= "if" or #e.conds > 1 or e.inElse then
				return
			end
			local tokens, cond = w.tokens, e.conds[1]
			if hasKeyword(tokens, cond.from, cond.to, "and") then
				return
			end
			for j = cond.from, cond.to do
				local text = checkAt(w, j)
				if text and polarity(tokens, j) == "is" and text:match("^[%a_][%w_]*$") and w:Resolve(text) then
					local assigned = e.assigned and e.assigned[text]
					if e.exits or assigned == "plain" then
						w:Shadow(text, nil)
					end
				end
			end
		end,
	})

	for _, t in ipairs(w.tokens) do
		if (t.type == "name" or t.type == "string")
			and (t.value:find("COMBAT_LOG_EVENT", 1, true) or t.value == "CombatLogGetCurrentEventInfo") then
			add("combatlog", t.value, t.line)
		end
	end

	table.sort(findings, function(a, b)
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.order < b.order
	end)
	for _, f in ipairs(findings) do
		f.order = nil
	end
	return findings
end
