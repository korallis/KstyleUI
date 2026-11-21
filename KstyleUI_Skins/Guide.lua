-- Guide.lua: the guide slot of the story rail, shared by every addon that draws a guide window: each skin offers its guide here, and the guide shown last holds the slot.
local _, ns = ...

local K = KstyleUI

local Guide = { list = {}, seen = 0 }
ns.Guide = Guide

local function Answers(provider, name)
	local answer = provider[name]
	return type(answer) == "function" and answer(provider) == true
end

local function Find(key)
	for _, provider in ipairs(Guide.list) do
		if provider.key == key then
			return provider
		end
	end
end

function Guide.Add(key, provider)
	provider.key = key
	provider.stamp = 0
	Guide.list[#Guide.list + 1] = provider
	if type(provider.addon) == "string" and K.Setup and type(K.Setup.RegisterGuide) == "function" then
		K.Setup.RegisterGuide(provider.addon)
	end
end

function Guide.Touch(key)
	local provider = Find(key)
	if provider then
		Guide.seen = Guide.seen + 1
		provider.stamp = Guide.seen
	end
end

local function Owner()
	local first, best
	for _, provider in ipairs(Guide.list) do
		if Answers(provider, "Enabled") then
			first = first or provider
			if Answers(provider, "Visible") and (not best or provider.stamp > best.stamp) then
				best = provider
			end
		end
	end
	return best or first
end

function Guide.Key()
	local owner = Owner()
	return owner and owner.key
end

function Guide.Visible()
	local owner = Owner()
	return owner ~= nil and Answers(owner, "Visible")
end

function Guide.Is(key)
	local owner = Owner()
	return owner == nil or owner.key == key
end

function Guide.Schedule()
	for _, provider in ipairs(Guide.list) do
		if Answers(provider, "Enabled") and type(provider.Schedule) == "function" then
			provider.Schedule()
		end
	end
end
