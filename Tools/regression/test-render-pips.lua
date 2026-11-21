-- test-render-pips.lua: the class-themed pips in the HUD scenes: RENDER_PIPS=off turns them off in the unit frames' and the action bars' scenes alike, under Medallions the unit frames' scene gives a rogue's points to the crest's crown as the game does, and a cat-form druid's lit points draw claws.
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
rawset(_G, "RENDER_PIPS", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)

-- A cat-form druid's three points draw lit claws; the class scenes give only the rogue combo points.
scene = check("druid", (Hud.Module("unitframes", { class = "DRUID", combo = 3, player = { powerType = 3, powerToken = "ENERGY", power = 80, powerMax = 100 } })))
local claws = Lit(scene, "PipClaw")
assert(claws == 3, "a cat-form druid's three points draw lit claws, got " .. claws)

print("render pips ok")
