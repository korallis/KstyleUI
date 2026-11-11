-- test-ornament-stale.lua: a restyle reaches only ornaments whose owner is shown; a hidden owner's handle is marked stale, places nothing, and is correct on the first frame its owner shows, even when only an ancestor's OnShow fires.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "target", { name = "Wolf", level = 12, health = 50, healthMax = 200, reaction = 2, canAttack = true, classification = "elite" })
env.SetTarget(true)
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local function Fire(frame)
	local script = frame._scripts.OnShow
	if script then script(frame) end
end
for _, frame in ipairs(env._frames) do
	for _, method in ipairs({ "Show", "SetShown" }) do
		local original = frame[method]
		frame[method] = function(self, ...)
			local was = self:IsVisible()
			original(self, ...)
			if not was and self:IsVisible() then Fire(self) end
		end
	end
end

local Handle = getmetatable(ns.Frames.Get("target").views[1].health.ornament)
local restyled, placed = {}, {}
local restyle, place = Handle.Restyle, Handle.Place
Handle.Restyle = function(self, ...)
	restyled[self] = true
	return restyle(self, ...)
end
Handle.Place = function(self, ...)
	placed[self] = true
	return place(self, ...)
end

env._units.target.classification = "normal"
env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
env.RunTimers()
local shown, hidden = 0, 0
for handle in pairs(restyled) do
	if handle.owner:IsVisible() then
		shown = shown + 1
		assert(not handle.stale, "a shown owner's handle restyles")
	else
		hidden = hidden + 1
		assert(handle.stale, "a hidden owner's handle is marked stale")
		assert(not placed[handle], "a hidden owner's handle places nothing")
	end
end
assert(shown >= 2 and hidden >= 1, "a rank change reaches shown and hidden blocks: " .. shown .. " shown, " .. hidden .. " hidden")

local focus = ns.Frames.Get("focus").views[1]
local block = focus.health.ornament
assert(not focus.panel:IsVisible() and block.stale, "the hidden focus card's block is stale")
local function drawn(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then
			local _, _, _, x, y = texture:GetPoint(1)
			names[#names + 1] = texture:GetTexture():match("([%w]+)%.png$") .. "@" .. string.format("%.3f,%.3f", x, y)
		end
	end
	return table.concat(names, " ")
end
U.SetUnit(env, "focus", { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, classification = "rare" })
env.FireEvent("PLAYER_FOCUS_CHANGED")
assert(focus.panel:IsVisible(), "the focus card shows")
assert(not block.stale, "showing the owner restyles its stale handle")
local first = drawn(block)
assert(first ~= "", "the focus card's block draws on its first shown frame")
env.RunTimers()
block:Restyle()
assert(drawn(block) == first, "the first shown frame matches a fresh restyle: " .. first .. " | " .. drawn(block))

local cast = ns.CastBars.Get("player")[1]
local bar = cast.ornament
assert(not cast.panel:IsVisible() and bar.stale, "the idle player cast bar's ornament is stale")
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(cast.panel:IsVisible() and not bar.stale, "a cast shows the bar and restyles its stale ornament")
local casting = drawn(bar)
assert(casting ~= "", "the cast bar draws its ornament on its first shown frame")
bar:Restyle()
assert(drawn(bar) == casting, "the cast bar's first shown frame matches a fresh restyle: " .. casting .. " | " .. drawn(bar))

env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
env.RunTimers()
U.W.Settle(env)
env.RunTimers()
assert(not cast.panel:IsVisible(), "the cast bar hides after its cast")
K.Options.Write("Widgets", "ornaments", "Subtle")
env.RunTimers()
assert(bar.stale, "a level change while the cast bar is hidden leaves its ornament stale")
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(cast.panel:IsVisible() and not bar.stale, "the same spell again shows the bar, and only its OnShow restyles the stale ornament")
local subtle = drawn(bar)
bar:Restyle()
assert(subtle ~= casting and drawn(bar) == subtle, "the cast bar draws Subtle on its first shown frame: " .. subtle .. " | " .. drawn(bar))
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok hidden ornaments wait until their owner shows")
