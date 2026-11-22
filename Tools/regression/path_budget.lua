-- path_budget.lua: sample addon VM instructions (every step-th, 100 unless given; 1 counts a short path exactly) and count widget method calls for one complete user path.
local Budget = {}

function Budget.Count(env, run, step)
	step = step or 100
	local meta = getmetatable(env.UIParent)
	local index, wrappers = meta.__index, {}
	local result = { instructions = 0, calls = 0 }
	meta.__index = function(object, key)
		local fn = index(object, key)
		if type(fn) ~= "function" or type(key) ~= "string" or not key:match("^%u") then return fn end
		local wrapped = wrappers[fn]
		if not wrapped then
			wrapped = function(self, ...)
				result.calls = result.calls + 1
				return fn(self, ...)
			end
			wrappers[fn] = wrapped
		end
		return wrapped
	end
	debug.sethook(function()
		local source = debug.getinfo(2, "S").source
		if source:match("^@Core/") or source:match("^@KstyleUI_") then
			result.instructions = result.instructions + step
		end
	end, "", step)
	local ok, err = pcall(run)
	debug.sethook()
	meta.__index = index
	assert(ok, err)
	return result
end

function Budget.Check(result, instructions, calls, fix)
	assert(result.instructions <= instructions, fix .. ": " .. result.instructions .. " addon instructions, budget " .. instructions)
	assert(result.calls <= calls, fix .. ": " .. result.calls .. " widget calls, budget " .. calls)
end

function Budget.Objects(env)
	local frames, regions = 0, 0
	for _, frame in ipairs(env._frames) do
		frames, regions = frames + 1, regions + #frame._regions
	end
	return frames, regions
end

return Budget
