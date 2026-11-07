-- Init.lua: the KstyleUI_Bags addon table, which the module's files share, with its event list and devlog helper.
local addonName, ns = ...

ns.addonName = addonName
ns.handlers = {}

function ns.On(event, fn)
	local list = ns.handlers[event]
	if not list then
		list = {}
		ns.handlers[event] = list
	end
	list[#list + 1] = fn
end

function ns.Log(message)
	local devtest = KstyleUI.DevTest
	if devtest and devtest.Log then
		devtest.Log("Bags", message)
	end
end
