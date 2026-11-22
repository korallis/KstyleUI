-- test-render-pips.lua: the class-themed pips in the HUD scenes: RENDER_PIPS=off turns them off in the unit frames' and the action bars' scenes alike, under Medallions the unit frames' scene gives a rogue's points to the crest's crown as the game does, a cat-form druid's bar sits above the crown in the unit frames' scene as in the game, and its lit points draw claws.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Hud, check, near = L.Hud, L.check, L.near

local function Lit(scene, art)
	local n = 0
	for _, item in ipairs(scene.items) do
		if item.kind == "texture" and item.bar and near(item.fraction, 1) and tostring(item.file):find("/" .. art .. "%d+%.png$") then
			n = n + 1
		end
	end
	return n
end

local opts = Hud.Options({ layout = "DPS", class = "ROGUE" })
rawset(_G, "RENDER_HUD_STYLE", "Medallions")

-- On by default: the crest wears the crown, so the unit frames' scene draws no row.
local _, ab = Hud.Module("actionbars", opts)
assert(ab.SlabCrown.state.shown, "a rogue's crest wears the crown")
local scene, uf = Hud.Module("unitframes", opts)
assert(not uf.Resource.state.showCombo and Lit(check("rogue", scene), "PipBlade") == 0, "the crown has the rogue's points, not the row")

-- RENDER_PIPS=off takes the crown off the crest as well as the row (review 678 #6).
rawset(_G, "RENDER_PIPS", "off")
_, ab = Hud.Module("actionbars", opts)
assert(not ab.SlabCrown.state.shown, "RENDER_PIPS=off takes the crown off the crest")
_, uf = Hud.Module("unitframes", opts)
assert(uf.Resource.state.showCombo and not uf.Resource.state.themed, "and the player's row draws the plain pips")

-- A cat-form druid's bar sits on the crown's seat, which lives in the action bars' scene, clear of the claws.
rawset(_G, "RENDER_PIPS", "3,3")
local dopts = Hud.Options({ layout = "DPS", class = "DRUID" })
_, ab = Hud.Module("actionbars", dopts)
_, uf = Hud.Module("unitframes", dopts)
local Scene = L.Common.Scene
local seat, claw = ab.SlabCrown.state.line, ab.SlabCrown.state.pips[3].frame
local sx, sy, sw, sh = Scene.Rect(seat._env, seat)
local _, cy = Scene.Rect(claw._env, claw)
local bx, by, bw, bh = Scene.Rect(uf.Resource.state.mana._env, uf.Resource.state.mana)
assert(uf.Resource.state.showMana and math.abs(bx + bw / 2 - (sx + sw / 2)) < 1, "the druid bar is centred on the crown's seat")
assert(math.abs(by + bh / 2 - (sy + sh / 2)) < 1 and by + bh <= cy, "and clears the middle claw's art")

-- A hunter keeps Summon Hawk and the same hawk slots with the arrows on or off, so RENDER_PIPS=off changes only the arrows.
for _, pips in ipairs({ "3,3", "off" }) do
	rawset(_G, "RENDER_PIPS", pips)
	_, ab = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = "HUNTER" }))
	local perch = ab.SlabHawks.state.perches[1]
	assert(perch and perch.holder:IsShown(), "RENDER_PIPS=" .. pips .. ": the hunter's hawk perches show")
	assert((ab.SlabCrown.state.crown ~= nil) == (pips ~= "off"), "RENDER_PIPS=" .. pips .. ": the arrows follow the setting")
end
rawset(_G, "RENDER_PIPS", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)

-- A cat-form druid's three points draw lit claws; the class scenes give only the rogue combo points.
scene = check("druid", (Hud.Module("unitframes", { class = "DRUID", combo = 3, player = { powerType = 3, powerToken = "ENERGY", power = 80, powerMax = 100 } })))
local claws = Lit(scene, "PipClaw")
assert(claws == 3, "a cat-form druid's three points draw lit claws, got " .. claws)

print("render pips ok")
