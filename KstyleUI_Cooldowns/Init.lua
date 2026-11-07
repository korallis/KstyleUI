-- Init.lua: the KstyleUI_Cooldowns addon table, which the module's files share, and its devlog helpers.
local addonName, ns = ...

ns.addonName = addonName
ns.MODULE = "Cooldowns"

local logged = {}

function ns.Log(message)
	local K = KstyleUI
	if K and K.DevTest then
		K.DevTest.Log(ns.MODULE, message)
	end
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

function ns.Plain(value)
	if ns.IsSecret(value) then
		return nil
	end
	return value
end
