-- test-unitframes-medallions-fit.lua: Fitted slabs (on by default) tuck the bars under the portrait ring with even insets, keep power in its type colour, dock the player and target slabs into the crest with an arm under it only at their default place, set the status icons in sockets on the slab top, colour incoming heals as the health fill; each switch off restores the earlier look.
local U = dofile("Tools/regression/unitframes_env.lua")

local profile = { UnitFrames = { enabled = true }, ActionBars = { enabled = true }, HudStyle = { style = "medallions" } }
local env, K, ns = U.New({ saved = { version = 32, profiles = { Default = profile }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} } })
local G = ns.Geometry
local FIT = G.SLAB_FIT

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.01)
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local player, target = ns.Frames.Get("player").views[1], ns.Frames.Get("target").views[1]
local g = player.geometry
assert(player.s.fittedSlabs and g.form == "slab", "Fitted slabs is on by default on a Medallions slab")

-- Bars: under the ring at the portrait end, 3 short of the cap seam at the other, 3 below the lit bevel.
local ring = g.medal.x + g.medal.w
local k = g.glass.h / G.SLAB.player.h
assert(near(g.health.x, ring - FIT.tuck * k) and near(g.power.x, g.health.x), "the bars start under the portrait ring")
assert(near(g.glass.w - g.health.x - g.health.w, FIT.cap * k), "the bars stop 3 units short of the forged cap's seam")
assert(near(g.health.y, FIT.top * k), "the health bar sits 3 units below the lit top bevel")
assert(g.lane.x >= ring + FIT.textPad * k - 0.01, "the texts start clear of the ring")
assert(player.medallion:GetFrameLevel() > player.health.fillClip:GetFrameLevel(), "the ring draws over the bar ends it caps")
local tg = target.geometry
assert(near(tg.health.x + tg.health.w, tg.medal.x + FIT.tuck * k) and near(tg.health.x, FIT.cap * k), "the target mirrors it")

-- Power keeps its type colour, even beside a health colour of the same hue.
assert(not player.powerTypeLine:IsShown(), "no type line runs under a fitted slab's power bar")

-- Docking: an arm under the crest only at the default place, in LOW strata below the hub.
local arm = player.dock
assert(arm and arm:IsShown() and arm:GetFrameStrata() == "LOW", "the docked player slab plugs an arm under the crest")
assert(target.dock and target.dock:IsShown(), "and so does the target's")
local _, _, _, ax = arm:GetPoint(1)
assert(ax > 0 and arm:GetWidth() > 40, "the arm runs from inside the slab towards the crest")
K.Layout.Set("unitframes.player", "x", K.Layout.Get("unitframes.player").x - 200)
env.RunTimers()
assert(not arm:IsShown(), "a moved frame has no arm")
K.Layout.Reset("unitframes.player")
env.RunTimers()
assert(arm:IsShown(), "back at its place, the arm returns")

-- Status icons rest in sockets on the slab's top edge.
env._units.player.combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
local icon = player.icons.combat
local socket = icon.socket
assert(socket and socket:IsShown() and socket:GetWidth() > icon:GetWidth(), "the combat swords sit in a socket")
assert(select(5, icon:GetPoint(1)) >= socket:GetHeight() / 2 - 0.5, "the socket rests on the slab's top edge, not across it")

-- Heal prediction takes the health fill's colour.
local hr, hg, hb = player.healthR, player.healthG, player.healthB
local ir, ig, ib = player.incoming:GetStatusBarColor()
assert(near(ir, hr) and near(ig, hg) and near(ib, hb), "incoming heals wear the health colour")
write("predictionTint", false)
ir, ig, ib = player.incoming:GetStatusBarColor()
local fr, fg, fb = K.Tokens.Color("friendly")
assert(near(ir, fr) and near(ig, fg) and near(ib, fb), "off restores the green segment")

-- Off restores the earlier slab.
write("fittedSlabs", false)
g = player.geometry
assert(near(g.health.x, g.medal.w / 2 + G.SLAB_PAD.inner * k) and near(g.health.y, G.SLAB_PAD.top * k), "off: the bars start beside the ring again")
assert(not arm:IsShown() and not target.dock:IsShown() and not socket:IsShown(), "off: no arms and no sockets")
assert(near(select(5, icon:GetPoint(1)), 0, 0.5), "off: the icons centre on the top edge again")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes medallions fit ok")
