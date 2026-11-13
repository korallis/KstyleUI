-- test-options-hud-pictures.lua: the HUD style picker shows real pictures of each style at a size that reads (KSTY-60
-- item 27: the picker drew schematic diagrams in two 106-unit cards). The General page's HUD style row stacks its two
-- picture cards under the label across the row, each picture 2:1 and the render crop Media/Textures holds, and the
-- setup's HUD style step shows the same two pictures.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local W = O.W

local MIN_PICTURE = 200
local SLACK = 1

local env, K, ns = O.New({
	setup = function(e)
		e._textWidth = function(text, fontPath, size)
			return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
		end
	end,
})

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

K.Options.Open("General")
settle()
local row
for _, candidate in ipairs(ns.Window.Parts().content.rows) do
	if candidate:IsShown() and candidate.item and candidate.item.kind == "pictures" then
		row = candidate
	end
end
assert(row, "General shows the HUD style row")
local holder = row.controls.pictures
local want = { (K.Tokens.Texture("hudStyleFrames")), (K.Tokens.Texture("hudStyleOrbs")) }
Scene.Build(env, {})
for i, card in ipairs(holder.cards) do
	local _, _, width, height = Scene.Rect(env, card.picture)
	assert(width >= MIN_PICTURE, "picture " .. i .. " is " .. width .. " units wide, at least " .. MIN_PICTURE)
	assert(math.abs(width - 2 * height) <= SLACK, "picture " .. i .. " keeps the textures' 2:1, got " .. width .. " by " .. height)
	assert(card.picture:GetTexture() == want[i], "picture " .. i .. " is " .. tostring(want[i]))
end
local labelTop = select(5, row.label:GetPoint(1))
local holderTop = select(5, holder:GetPoint(1))
assert(holderTop < labelTop, "the pictures sit under the label, across the row")

local S = dofile("Tools/regression/widget_env.lua")
local senv, SK = S.New({ boot = false })
S.CoreEnv.Boot(senv)
SK.Setup.Open()
S.Settle(senv)
SK.Setup.Go(2)
S.Settle(senv)
for value, texture in pairs({ frames = want[1], orbs = want[2] }) do
	local card = SK.Setup.window.styleCards[value]
	local width, height = card.picture:GetSize()
	assert(card.picture:GetTexture() == texture, "the setup's " .. value .. " card shows the same picture")
	assert(width >= MIN_PICTURE and math.abs(width - 2 * height) <= SLACK, "the setup's " .. value .. " picture is 2:1 and readable")
end

assert(#env._errors == 0 and #senv._errors == 0, "errors: " .. tostring(env._errors[1] or senv._errors[1]))
print("options hud pictures ok")
