-- test-actionbars-crest-auras.lua: the aura kit's drawing rule (KstyleUI_ActionBars/SlabMedals.lua Medals.Mark, the KSTY-51 plan): a forged mark with an aura draws its sheet twice in white additive light over the empty socket, a fire looping the sheet's FlipBook and a still on its first cell; the fire loops only at Full with the crest awake and its owner shown, Calm, Off and the resting crest show the still, a hidden owner plays nothing until it shows, a mark under an engine aura button hands its loop to the engine's shown animations, and while auras are secret nothing touches it until the restriction ends.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local env, K, ns = AB.New({
	class = "WARRIOR",
	setup = function(e)
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		e._slotGroups = true
		Slots.Install(e)
		e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
	end,
})
AB.Enable(env, K)
env.RunTimers()
local Medals, Tokens = ns.SlabMedals, K.Tokens

-- No class takes the kit in this change, so a real forged glyph borrows a real 4x4 ambient sheet as its aura: the
-- shape every aura sheet has (Core/Tokens.lua medAmbient*), with span 1.25 for the bare variant.
local SHEET = "medAmbientWarrior"
local texture, flipbook = Tokens.Texture, Tokens.Flipbook
Tokens.Texture = function(name)
	if name == "glyphHawk" or name == "sigilVolley" then
		local file, slice, units, forged = texture(name)
		return file, slice, units, forged, name == "glyphHawk" and SHEET or SHEET .. "Bare"
	end
	return texture(name == SHEET .. "Bare" and SHEET or name)
end
Tokens.Flipbook = function(name)
	if name == SHEET .. "Bare" then
		local rows, columns, frames, seconds = flipbook(SHEET)
		return rows, columns, frames, seconds, 1.25
	end
	return flipbook(name)
end
local FILE = texture(SHEET)

local function Draws(region, file)
	local state = region._state or {}
	local r, g, b = region:GetVertexColor()
	return (state.Texture or {})[1] == file and (state.BlendMode or {})[1] == "ADD" and r == 1 and g == 1 and b == 1
end
local function Burning(fire)
	return fire:GetAlpha() == 1 and fire.still:GetAlpha() == 0 and fire.loop:IsPlaying()
end
local function Still(fire)
	return fire:GetAlpha() == 0 and fire.still:GetAlpha() == 1 and not fire.loop:IsPlaying()
end
local function Motion(level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
	Medals.Rest()
end

env.SetTarget(true)
env.RunTimers()
local parent = env.CreateFrame("Frame", nil, env.UIParent)

do
	local piece = Medals.Piece(parent, 5, 30)
	local fire, _, _, gold, aura = Medals.Mark(piece, piece, "glyphHawk", 30, "gilt")
	assert(aura and gold and Draws(fire, FILE) and Draws(fire.still, FILE), "a forged mark with an aura draws its sheet twice in white additive light")
	local left, right, top, bottom = fire.still:GetTexCoord()
	assert(left == 0 and right == 0.25 and top == 0 and bottom == 0.25, "the still shows the sheet's first cell")
	local body = piece._regions and piece._regions[3]
	assert(body and (body._state.Texture or {})[1] == texture("auraSocket"), "a seated aura burns over the empty socket")
	local flip = fire.loop._anims and fire.loop._anims[1]
	local rows, columns, frames, seconds = flipbook(SHEET)
	assert(fire.loop:GetLooping() == "REPEAT" and flip and flip._type == "FlipBook", "the fire is a repeating FlipBook")
	assert(flip:GetFlipBookRows() == rows and flip:GetFlipBookColumns() == columns and flip:GetFlipBookFrames() == frames and flip:GetDuration() == seconds, "playing the sheet's grid, frames and seconds")

	Motion("full")
	assert(Burning(fire), "at Full with the crest awake the fire loops")
	Motion("calm")
	assert(Still(fire), "Calm shows the still")
	Motion("off")
	assert(Still(fire), "Off shows the still")
	Motion("full")
	env.SetTarget(false)
	env.RunTimers()
	assert(ns.Slab.Resting() and Still(fire), "the resting crest shows the still")
	env.SetTarget(true)
	env.RunTimers()
	assert(Burning(fire), "a target wakes the crest and the fire loops again")
	piece:Hide()
	Medals.Rest()
	assert(not fire.loop:IsPlaying(), "a hidden owner plays nothing")
	piece:Show()
	assert(Burning(fire), "showing it again starts the loop")

	local bare = Medals.Piece(parent, 5, 30)
	local flame = Medals.Mark(bare, bare, "sigilVolley", 20, "jewelHawk")
	assert(flame.units == 20 * 1.25 and bare._regions[3].units == 20, "a bare aura's cell is its span wider than the figure")
	local figure = bare._regions[3]
	local r, g, b = figure:GetVertexColor()
	assert((figure._state.Texture or {})[1] == texture("sigilVolley") and r + g + b == 0, "and burns over its own figure drawn black")
end

do
	local m = Medals.Medal(parent, { feed = "aura", unit = "player", filter = "HELPFUL", spells = { 6673 }, color = "gilt" }, 5)
	local fire = Medals.Mark(m, m.lit, "glyphHawk", 30, "gilt")
	assert(Medals.Engine({ m }, true, true), "Engine runs while auras are readable")
	local shown = false
	for _, g in ipairs(m.lit._shownAnimations) do shown = shown or g == fire.loop end
	assert(shown, "under an engine aura button the fire loop is one of the engine's shown animations at Full")
	Medals.Engine({ m }, true, "calm")
	shown = false
	for _, g in ipairs(m.lit._shownAnimations) do shown = shown or g == fire.loop end
	assert(not shown, "and not below Full")
	Medals.Engine({ m }, true, true)
	Slots.Set(env, "player", { { id = 6673, count = 0, icon = 132333, start = 0, duration = 120 } })
	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	Medals.Rest()
	-- The stub forbids every region under an engine aura button while auras are secret, so any touch is an error here.
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Medals.Rest()
	assert(Still(fire), "once the restriction ends the motion chosen during it shows")
end

assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("actionbars crest auras ok")
