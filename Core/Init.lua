-- Init.lua: create the KstyleUI namespace from the addon's private table.
local addonName, ns = ...

KstyleUI = ns
ns.VERSION = "@project-version@"
ns.CODE_BUILD = 1
ns.ADDON_NAME = addonName

local errors = 0

local function report(err)
	errors = errors + 1
	local DevTest = ns.DevTest
	if DevTest and DevTest.Log then
		DevTest.Log("Error", err)
	end
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	end
	return err
end

local XPCALL_PASSES_ARGS = select(2, xpcall(function(value)
	return value
end, report, true)) == true

function ns.Call(fn, ...)
	if XPCALL_PASSES_ARGS then
		return xpcall(fn, report, ...)
	end
	local n, args = select("#", ...), { ... }
	return xpcall(function()
		return fn(unpack(args, 1, n))
	end, report)
end

function ns.ErrorCount()
	return errors
end

function ns.Print(message)
	print("KstyleUI: " .. tostring(message))
end
