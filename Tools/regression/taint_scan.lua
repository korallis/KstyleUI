-- taint_scan.lua: find taint risks in addon Lua source, and compare them with the reviewed allow-list.
--
--   local Scan = dofile("Tools/regression/taint_scan.lua")
--   local names = Scan.BlizzardNames(dofile("Tools/data/forever_globals.lua").read)
--   Scan(source, names) -> { { kind, call, line, site }, ... }   -- by line; site is a token index
--   Scan.Check(scanned, allow) -> { problem, ... }                -- scanned = { [path] = findings }
--
-- Kinds, and what call holds:
--   frame-call           a listed frame method on a Blizzard frame, called with : or with . and
--                        the frame as first argument: "PlayerFrame:SetScript"
--   field-write          a field written on a Blizzard frame or table: "PlayerFrame.unit"
--   game-table-write     a write into UISpecialFrames, UIPanelWindows or hash_SlashCmdList, a
--                        StaticPopupDialogs key without KSTYLEUI_ or a SlashCmdList key without
--                        KSTYLE, or an assignment to a Blizzard name: "UISpecialFrames[?]"
--   protected-unguarded  a protected call with no InCombatLockdown or Combat.Queue in the 40 lines
--                        before it: "SetBinding"
--   setparent-unguarded  SetParent on any frame with no EditModeManagerFrame:IsShown or Safe.<name>
--                        in the 40 lines before it: "self.icon:SetParent"
--   aura-unguarded       C_UnitAuras in a file that never calls ShouldAurasBeSecret or
--                        issecretvalue: "C_UnitAuras.GetAuraDataByIndex"
--
-- The scan follows locals: a local given a Blizzard path (local f = PlayerFrame) counts as that
-- path until it is reassigned or its block ends, and a local or parameter with a Blizzard name hides
-- the global. A reassignment in a nested block or function may not run, so it never clears an
-- alias. The scan does not follow values through function calls, parameters or table fields. A key
-- computed at run time shows as [?].

local Source = dofile("Tools/regression/lua_source.lua")
local isOp = Source.IsOp

local function set(list)
	local out = {}
	for _, name in ipairs(list) do
		out[name] = true
	end
	return out
end

local FRAME_METHODS = set({
	"SetScript", "Hide", "SetParent", "ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth",
	"SetHeight", "SetScale", "UnregisterAllEvents", "UnregisterEvent", "RegisterEvent", "EnableMouse",
	"SetAttribute", "SetFrameStrata",
})

-- RunMacroText is C_Macro.RunMacroText on Forever; the bare name stays in case a shim returns.
local PROTECTED = set({
	"PickupAction", "PlaceAction", "SetBinding", "SetOverrideBinding", "SetOverrideBindingClick",
	"ClearOverrideBindings", "CreateMacro", "EditMacro", "C_Container.PickupContainerItem",
	"C_Container.UseContainerItem", "TargetUnit", "CastSpellByName", "CastSpellByID", "UseAction",
	"RunMacroText", "C_Macro.RunMacroText", "ShowUIPanel", "HideUIPanel",
})

local CLOSED_TABLES = set({ "UISpecialFrames", "UIPanelWindows", "hash_SlashCmdList" })
local KEY_PREFIX = { StaticPopupDialogs = "KSTYLEUI_", SlashCmdList = "KSTYLE" }
local MUTATORS = set({ "tinsert", "tremove", "wipe", "table.insert", "table.remove", "table.wipe" })
local GUARD_LINES = 40
local ALLOW_DIR = "Tools/regression/taint_allow"

-- What a path names once locals are followed: { root, segs = { { key, text } }, text, global,
-- blizz }. global is false for a path that starts at a local with no known value; root is then
-- the local's name. blizz is true when the root is a Blizzard name.
local function resolve(w, p, names)
	local isLocal, value = w:Resolve(p.root)
	local root, segs, global = p.root, {}, not isLocal
	if value then
		root, global = value.root, value.global
		for _, seg in ipairs(value.segs) do
			segs[#segs + 1] = seg
		end
	end
	for _, seg in ipairs(p.segs) do
		segs[#segs + 1] = { key = seg.kind ~= "expr" and seg.key or nil, text = Source.SegText(seg) }
	end
	if global and root == "_G" and segs[1] then
		root = table.remove(segs, 1).key or "_G[?]"
	end
	local text = root
	for _, seg in ipairs(segs) do
		text = text .. seg.text
	end
	local blizz = global and (root == "_G[?]" or names[root] == true)
	return { root = root, segs = segs, text = text, global = global, blizz = blizz }
end

-- The kind of finding for a write to a Blizzard path, or nil when the write is allowed.
local function writeKind(r)
	if #r.segs == 0 or CLOSED_TABLES[r.root] then
		return "game-table-write"
	end
	local prefix = KEY_PREFIX[r.root]
	if prefix then
		local key = r.segs[1].key
		if key and key:sub(1, #prefix) == prefix then
			return nil
		end
		return "game-table-write"
	end
	return "field-write"
end

local function isName(t, value)
	return t.type == "name" and t.value == value
end

local function combatGuard(tokens, j)
	return isName(tokens[j], "InCombatLockdown")
		or (isName(tokens[j], "Combat") and isOp(tokens[j + 1], ".") and isName(tokens[j + 2], "Queue"))
end

local function editModeGuard(tokens, j)
	return (isName(tokens[j], "EditModeManagerFrame") and isOp(tokens[j + 1], ":") and isName(tokens[j + 2], "IsShown"))
		or (isName(tokens[j], "Safe") and isOp(tokens[j + 1], ".") and tokens[j + 2].type == "name")
end

-- Whether a guard appears before token index, no more than GUARD_LINES lines above it.
local function guarded(tokens, index, guard)
	local first = tokens[index].line - GUARD_LINES
	for j = index - 1, 1, -1 do
		if tokens[j].line < first then
			return false
		end
		if guard(tokens, j) then
			return true
		end
	end
	return false
end

local function hasAuraGuard(tokens)
	for _, t in ipairs(tokens) do
		if isName(t, "ShouldAurasBeSecret") or isName(t, "issecretvalue") then
			return true
		end
	end
	return false
end

local function scan(source, names)
	local findings = {}
	local receivers = {}
	local auraGuard
	-- site is the token where the call or write happens, so Check can count places, not findings.
	local function add(kind, call, line, site)
		findings[#findings + 1] = { kind = kind, call = call, line = line, site = site, order = #findings }
	end
	local function setParent(tokens, site, receiver)
		if not guarded(tokens, site, editModeGuard) then
			add("setparent-unguarded", receiver .. ":SetParent", tokens[site].line, site)
		end
	end
	-- A frame method called on receiver, written receiver:Method(...) or receiver.Method(receiver, ...).
	local function method(tokens, r, receiver, name, site)
		if r.blizz and FRAME_METHODS[name] then
			add("frame-call", receiver .. ":" .. name, tokens[site].line, site)
		end
		if name == "SetParent" then
			setParent(tokens, site, receiver)
		end
	end

	Source.Walk(source, {
		Annotate = function(w, from, to, n)
			if not from or n > 1 or w.tokens[from].type ~= "name" then
				return nil
			end
			local p = w:Path(from)
			return p.to == to and resolve(w, p, names) or nil
		end,

		Path = function(w, p)
			local tokens = w.tokens
			local r = resolve(w, p, names)
			local line = tokens[p.from].line
			if auraGuard == nil then
				auraGuard = hasAuraGuard(tokens)
			end
			if r.global and r.root == "C_UnitAuras" and r.segs[1] and not auraGuard then
				add("aura-unguarded", "C_UnitAuras" .. r.segs[1].text, line, p.from)
			end
			if p.role == "assign" then
				local kind = r.blizz and writeKind(r)
				if kind then
					add(kind, r.text, line, p.from)
				end
				return
			end
			local after = tokens[p.to + 1]
			if isOp(after, ":") and tokens[p.to + 2].type == "name" and Source.IsArgs(tokens[p.to + 3]) then
				receivers[p.to + 1] = true
				method(tokens, r, r.text, tokens[p.to + 2].value, p.to + 2)
			elseif Source.IsArgs(after) then
				local last = r.segs[#r.segs]
				if last and last.key then
					method(tokens, r, r.text:sub(1, #r.text - #last.text), last.key, p.from)
				end
				if r.global and PROTECTED[r.text] and not guarded(tokens, p.from, combatGuard) then
					add("protected-unguarded", r.text, line, p.from)
				end
				if r.global and MUTATORS[r.text] and isOp(after, "(") and tokens[p.to + 2].type == "name" then
					local q = w:Path(p.to + 2)
					local stop = tokens[q.to + 1]
					local rq = (isOp(stop, ",") or isOp(stop, ")")) and resolve(w, q, names)
					if rq and rq.blizz then
						-- The function writes a key of its first argument.
						local segs = { unpack(rq.segs) }
						segs[#segs + 1] = { text = "[?]" }
						local kind = writeKind({ root = rq.root, segs = segs })
						if kind then
							add(kind, r.text .. "(" .. rq.text .. ")", line, p.from)
						end
					end
				end
			end
		end,

		-- SetParent on a receiver that is not a path, such as CreateFrame(...):SetParent(...).
		Token = function(w, i)
			local tokens = w.tokens
			if not receivers[i] and isOp(tokens[i], ":") and isName(tokens[i + 1], "SetParent") and Source.IsArgs(tokens[i + 2]) then
				setParent(tokens, i + 1, "?")
			end
		end,
	})

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

local Scan = setmetatable({}, {
	__call = function(_, source, names)
		return scan(source, names)
	end,
})

-- The set of Blizzard names from forever_globals.lua's read list, without KstyleUI's own names.
function Scan.BlizzardNames(list)
	local out = {}
	for _, name in ipairs(list) do
		if not name:match("^KstyleUI") then
			out[name] = true
		end
	end
	return out
end

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

-- Compares each scanned file's findings with the allow-list. A call's count is the number of
-- places (sites) in the file that make it; one place can give a frame-call and a
-- setparent-unguarded finding. The count must match exactly, so the list never holds room for an
-- unreviewed place.
function Scan.Check(scanned, allow)
	local problems = {}
	local function problem(message)
		problems[#problems + 1] = message
	end
	for _, path in ipairs(sortedKeys(scanned)) do
		local byCall = {}
		for _, f in ipairs(scanned[path]) do
			local group = byCall[f.call] or { findings = {}, sites = {}, lines = {} }
			byCall[f.call] = group
			group.findings[#group.findings + 1] = f
			local site = f.site or {} -- a finding without a site is its own place
			if not group.sites[site] then
				group.sites[site] = true
				group.lines[#group.lines + 1] = f.line
			end
		end
		local entry = allow[path]
		local calls = entry and entry.calls or {}
		local file = entry and entry.file or ALLOW_DIR .. "/" .. (path:match("^([^/]+)/") or path) .. ".lua"
		for _, call in ipairs(sortedKeys(byCall)) do
			local group, limit = byCall[call], calls[call]
			local count, lines = #group.lines, table.concat(group.lines, ", ")
			if not limit then
				for _, f in ipairs(group.findings) do
					problem(string.format(
						"%s:%d: %s %s is not allowed. Fix it, or add [%q] = %d with a why to %s.",
						path, f.line, f.kind, call, call, count, file
					))
				end
			elseif count > limit then
				problem(string.format(
					"%s: %s is found %d times (lines %s) but allowed %d in %s. Fix the new place, or raise the count with a why.",
					path, call, count, lines, limit, file
				))
			elseif count < limit then
				problem(string.format(
					"%s: %s %s is allowed %d times but found %d (lines %s). Lower the count to %d.",
					file, path, call, limit, count, lines, count
				))
			end
		end
		for _, call in ipairs(sortedKeys(calls)) do
			if not byCall[call] then
				problem(string.format("%s: %s %s is no longer found. Remove it.", file, path, call))
			end
		end
	end
	for _, path in ipairs(sortedKeys(allow)) do
		if not scanned[path] then
			problem(string.format("%s: %s is not a scanned TOC-loaded Lua file. Remove its entry.", allow[path].file, path))
		end
	end
	return problems
end

return Scan
