-- Blizzard.lua: fades Blizzard's status tracking bars with alpha while the KstyleUI bars show, and takes the mouse off them; nothing is hidden or moved.
local _, ns = ...

local Blizzard = {}
ns.Blizzard = Blizzard

local faded = false

local function Frames(manager)
	local out = {}
	local containers = manager.barContainers
	if type(containers) ~= "table" then
		return out
	end
	for _, container in ipairs(containers) do
		local bars = type(container) == "table" and container.bars
		if type(bars) == "table" then
			for _, bar in pairs(bars) do
				if type(bar) == "table" then
					out[#out + 1] = bar
					if type(bar.ExhaustionTick) == "table" then
						out[#out + 1] = bar.ExhaustionTick
					end
				end
			end
		end
	end
	return out
end

local function SetMouse(frames, on)
	for _, frame in ipairs(frames) do
		if type(frame.EnableMouse) == "function" then
			local ok, err = pcall(frame.EnableMouse, frame, on)
			if not ok then
				ns.LogOnce("blizzard-mouse", "a Blizzard status bar refused EnableMouse: " .. tostring(err))
			end
		end
	end
end

function Blizzard.Apply(fade)
	fade = fade == true
	local manager = StatusTrackingBarManager
	if type(manager) ~= "table" or type(manager.SetAlpha) ~= "function" then
		ns.LogOnce("blizzard-missing", "StatusTrackingBarManager is missing; there are no Blizzard status bars to fade")
		return false
	end
	if fade == faded then
		return true
	end
	faded = fade
	manager:SetAlpha(fade and 0 or 1)
	SetMouse(Frames(manager), not fade)
	ns.Log(fade and "Blizzard's status bars faded with alpha and lost the mouse" or "Blizzard's status bars shown again")
	return true
end

function Blizzard.IsFaded()
	return faded
end

ns.AddPart({
	Enable = function()
		Blizzard.Apply(ns.Settings().fadeBlizzard)
	end,
	Disable = function()
		Blizzard.Apply(false)
	end,
	Setting = function(key)
		if key == "fadeBlizzard" then
			Blizzard.Apply(ns.Settings().fadeBlizzard)
		end
	end,
	Refresh = function()
		Blizzard.Apply(ns.Settings().fadeBlizzard)
	end,
})
