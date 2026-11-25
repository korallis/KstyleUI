return function(object, method)
	local original, count = object[method], 0
	object[method] = function(...)
		count = count + 1
		return original(...)
	end
	return function() return count end
end
