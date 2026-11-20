-- instruction_budget.lua: count addon VM instructions for one warmed path, excluding the test harness and widget stubs.
return function(run, budget, fix, step)
	step = step or 1
	local count = 0
	debug.sethook(function()
		local source = debug.getinfo(2, "S").source
		if source:match("^@Core/") or source:match("^@KstyleUI_") then
			count = count + step
		end
	end, "", step)
	local ok, err = pcall(run)
	debug.sethook()
	assert(ok, err)
	assert(count < budget, fix .. ": " .. count .. " addon instructions, budget " .. budget)
	return count
end
