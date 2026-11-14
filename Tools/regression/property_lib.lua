-- property_lib.lua: seeded property checks. A deterministic generator makes each case from the run's seed and the case number, so the printed seed and case reproduce a failure; KSTYLE_PROPERTY_ITERATIONS sets the case count, KSTYLE_PROPERTY_SEED the seed, KSTYLE_PROPERTY_CASE runs one case alone and KSTYLE_PROPERTY_ALL=1 reports every failing case before it fails.
local Property = {}

local MODULUS = 2147483647
local DEFAULT_SEED = 20261114

local function Whole(name)
	local raw = os.getenv(name)
	if raw == nil or raw == "" then
		return nil
	end
	local n = tonumber(raw)
	assert(n and n >= 1 and n == math.floor(n), name .. " must be a whole number of 1 or more, got " .. raw)
	return n
end

function Property.Seed()
	return Whole("KSTYLE_PROPERTY_SEED") or DEFAULT_SEED
end

function Property.Iterations(default)
	return Whole("KSTYLE_PROPERTY_ITERATIONS") or default
end

local Gen = {}
Gen.__index = Gen

local function MulMod(a, b)
	local high, low = math.floor(b / 65536), b % 65536
	return (a * high % MODULUS * 65536 + a * low) % MODULUS
end

-- Park and Miller's minimal standard generator, every product below 2^53 so Lua 5.1 and LuaJIT draw the same numbers. Squaring
-- the start state scrambles it, so neighbouring cases start far apart instead of on one line.
function Property.Generator(seed, case)
	local state = (seed + (case or 0) * 104729) % (MODULUS - 1) + 1
	for round = 1, 4 do
		state = (MulMod(state, state) * 48271 + round) % MODULUS
		if state == 0 then
			state = round
		end
	end
	return setmetatable({ state = state }, Gen)
end

function Gen:next()
	self.state = self.state * 48271 % MODULUS
	return self.state
end

function Gen:float(low, high)
	return low + (high - low) * (self:next() - 1) / (MODULUS - 2)
end

function Gen:int(low, high)
	return math.min(high, low + math.floor((self:next() - 1) / (MODULUS - 1) * (high - low + 1)))
end

function Gen:bool(chance)
	return self:float(0, 1) < (chance or 0.5)
end

function Gen:pick(list)
	return list[self:int(1, #list)]
end

local function Describe(value, depth)
	depth = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" then
		return tostring(value)
	elseif depth > 4 then
		return "{...}"
	end
	local keys = {}
	for k in pairs(value) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in ipairs(keys) do
		local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or "[" .. Describe(k) .. "]"
		parts[#parts + 1] = key .. " = " .. Describe(value[k], depth + 1)
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

Property.Describe = Describe

-- Property.Check(spec) runs spec.property on generated cases and raises on the first failure no spec.known entry claims.
--   name, script     the property's name and its test file, for the reproduction line
--   iterations       the case count when KSTYLE_PROPERTY_ITERATIONS is unset
--   generate(g, n)   the case from generator g; show(case) prints it (default Describe)
--   property(case)   true, or false and why: a text or a list of texts, one per violation; an error counts as a failure
--   known            { { issue = "LEE-n", why = text, match = function(case, why) -> boolean } }, violations filed and not fixed yet;
--                    a case fails when any of its violations is unclaimed
--   regressions      { { seed = n, case = n, issue = "LEE-n" } }, cases an earlier run failed on; every run checks them
--                    first, whatever its seed, unless KSTYLE_PROPERTY_CASE picks one case
function Property.Check(spec)
	local seed = Property.Seed()
	local only = Whole("KSTYLE_PROPERTY_CASE")
	local first, last = 1, Property.Iterations(spec.iterations)
	if only then
		first, last = only, only
	end
	local all = os.getenv("KSTYLE_PROPERTY_ALL") == "1"
	local show = spec.show or Describe
	local passed, known, failed = 0, {}, {}
	local started = os.clock()
	local runs = {}
	for _, pinned in ipairs(not only and spec.regressions or {}) do
		runs[#runs + 1] = { pinned.seed, pinned.case }
	end
	for case = first, last do
		runs[#runs + 1] = { seed, case }
	end
	for _, run in ipairs(runs) do
		local from, case = run[1], run[2]
		local value = spec.generate(Property.Generator(from, case), case)
		local ok, holds, why = pcall(spec.property, value)
		if not ok then
			holds, why = false, "raised: " .. tostring(holds)
		end
		if holds then
			passed = passed + 1
		else
			local violations = type(why) == "table" and why or { why ~= nil and tostring(why) or "no reason given" }
			local open = {}
			for _, violation in ipairs(violations) do
				local claim
				for _, entry in ipairs(spec.known or {}) do
					if entry.match(value, violation) then
						claim = entry
						break
					end
				end
				if claim then
					known[claim.issue] = (known[claim.issue] or 0) + 1
					if known[claim.issue] == 1 then
						print(string.format("known failure %s (%s) at case %d of seed %d: %s\n  case: %s", claim.issue, claim.why, case, from, violation, show(value)))
					end
				else
					open[#open + 1] = violation
				end
			end
			if #open > 0 or #violations == 0 then
				local message = string.format("property %q failed at case %d of seed %d: %s\n  case: %s\n  reproduce: KSTYLE_PROPERTY_SEED=%d KSTYLE_PROPERTY_CASE=%d lua5.1 %s",
					spec.name, case, from, #open > 0 and table.concat(open, "; ") or "no reason given", show(value), from, case, spec.script or "<test file>")
				if not all then
					error(message, 0)
				end
				print(message)
				failed[#failed + 1] = from == seed and tostring(case) or case .. " of seed " .. from
			end
		end
	end
	local claimed = {}
	for issue, n in pairs(known) do
		claimed[#claimed + 1] = issue .. " x" .. n
	end
	table.sort(claimed)
	print(string.format("property %q: %d of %d cases hold, seed %d, %.2f s%s", spec.name, passed, #runs, seed, os.clock() - started,
		#claimed > 0 and ("; known failures " .. table.concat(claimed, ", ")) or ""))
	if #failed > 0 then
		error(string.format("property %q failed at %d cases of seed %d: %s", spec.name, #failed, seed, table.concat(failed, ", ")), 0)
	end
	return passed, known
end

return Property
