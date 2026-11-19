-- abbreviate_env.lua: the client's number formatter, including custom breakpoints and secret results.
return function(env)
	local defaults = {
		{ breakpoint = 1000000, abbreviation = "M", significandDivisor = 10000, fractionDivisor = 100 },
		{ breakpoint = 1000, abbreviation = "K", significandDivisor = 10, fractionDivisor = 100 },
	}
	local function abbreviate(value, options)
		for _, point in ipairs(options and options.breakpointData or defaults) do
			if value >= point.breakpoint then
				return (math.floor(value / point.significandDivisor) / point.fractionDivisor) .. point.abbreviation
			end
		end
		return tostring(value)
	end
	env.AbbreviateNumbers = function(value, options)
		if env.issecretvalue(value) then
			return env.Secret(abbreviate(env.Reveal(value), options))
		end
		return abbreviate(value, options)
	end
	env.AbbreviateLargeNumbers = function(value)
		if env.issecretvalue(value) then
			return env.Secret(abbreviate(env.Reveal(value)))
		end
		return abbreviate(value)
	end
end
