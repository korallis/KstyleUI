-- Init.lua: the KstyleUI_QoL addon table, which the module's files share, with its log, secret-safe reads and the list of feature parts.
local addonName, ns = ...

local K = KstyleUI

ns.addonName = addonName
ns.MODULE = "QoL"
ns.K = K
ns.L = K.L
ns.parts = {}

local logged = {}

function ns.Log(message)
	K.DevTest.Log(ns.MODULE, message)
end

function ns.LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		ns.Log(message)
	end
end

function ns.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function ns.True(value)
	return not ns.IsSecret(value) and value == true
end

function ns.Number(value)
	if ns.IsSecret(value) or type(value) ~= "number" or value ~= value then
		return nil
	end
	return value
end

function ns.AddPart(part)
	ns.parts[#ns.parts + 1] = part
end
