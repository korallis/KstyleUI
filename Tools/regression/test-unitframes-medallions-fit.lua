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
local function seated()
	local y = select(5, icon:GetPoint(1))
	return y > 0 and near(y - socket:GetHeight() / 2, -player.rim, 1)
end
assert(seated(), "the socket sits on the slab's top edge, its rim seated in the bevel, not across it or floating")
for _, place in ipairs({ "TOPLEFT", "TOPRIGHT" }) do
	write("player.combatPlace", place)
	assert(seated(), place .. ": a cornered socket sits on the top edge too")
end
write("player.combatPlace", "")

-- The target and focus show a socket only with its lit icon.
local leader = target.icons.leader
assert(leader.socket and not leader.socket:IsShown(), "a target slot whose icon is dark draws no socket")
leader:Show()
assert(leader.socket:IsShown(), "and its socket follows the lit icon")
leader:Hide()

-- The player's socket row is even: every enabled slot keeps its socket, so a hidden PvP badge leaves no hole.
env._units.player.leader, env._units.player.role = true, "DAMAGER"
ns.Indicators.Status(player, "player")
local xs = {}
for _, key in ipairs(ns.Indicators.SLOTS) do
	local back = player.icons[key].socket
	if back and (back:IsShown() or back.rivet and back.rivet:IsShown()) then
		xs[#xs + 1] = select(4, player.icons[key]:GetPoint(1))
		assert(near(back:GetWidth(), back:GetHeight()) and back:GetWidth() > player.icons.combat:GetWidth(), key .. ": its socket is a round disc around the slot, even around the Zz text")
	end
end
table.sort(xs)
assert(#xs == #ns.Indicators.SLOTS, "every enabled status slot shows its socket")
for i = 3, #xs do
	assert(near(xs[i] - xs[i - 1], xs[2] - xs[1], 1), "the sockets are evenly spaced")
end
local pvp = player.icons.pvp.socket
assert(not player.icons.pvp:IsShown() and not pvp:IsShown() and pvp.rivet and pvp.rivet:IsShown(), "an empty player slot shows a lit steel rivet, not a dark hole")
local shade = U.W.LastCall(pvp.rivet, "SetGradient")
local steelR, steelG, steelB = K.Tokens.Color("steelLit")
assert(shade and near(shade[3].r, steelR) and near(shade[3].g, steelG) and near(shade[3].b, steelB) and shade[2].r < shade[3].r, "the rivet is lit steel, darker at its foot")
assert(pvp.rivet:GetWidth() < pvp:GetWidth(), "the rivet is smaller than a socket")
assert(player.icons.leader:IsShown() and player.icons.leader.socket:IsShown(), "a lit icon sits in its dark socket over the rivet")

-- Secondary values read brighter: the player's power value uses text, and a chosen colour is kept.
local xr, xg, xb = K.Tokens.Color("text")
local pr, pg, pb = player.powerText:GetTextColor()
assert(near(pr, xr) and near(pg, xg) and near(pb, xb), "the fitted player's power value uses text")
write("player.powerTextColor", "custom")
local c = player.s.powerTextCustom
write("fittedSlabs", false)
write("fittedSlabs", true)
pr, pg, pb = player.powerText:GetTextColor()
assert(near(pr, c.r) and near(pg, c.g) and near(pb, c.b), "an explicit power text colour survives a restyle")
write("player.powerTextColor", "")

-- An inline cast clears 35% of the actual portrait, also on a resized frame, and shows without a tween.
local cb = player.castbar
assert(K.Layout.Set("unitframes.player", "height", 116))
env.RunTimers()
assert(near(select(4, cb.bar:GetPoint(1)), 0.35 * player.geometry.medal.w, 1), "the cast clears 35% of the resized portrait")
K.Layout.Reset("unitframes.player")
env.RunTimers()
env._time = 2.2
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
assert(cb.frame:IsShown() and cb.frame:GetAlpha() == 1, "the cast on the frame shows at once, without a tween")

-- A restricted effective scale never reaches a comparison.
local scale = player.parent.GetEffectiveScale
player.parent.GetEffectiveScale = function(self)
	local v = scale(self)
	return debug.getinfo(2, "S").short_src:find("Indicators.lua", 1, true) and env.Secret(v) or v
end
for _ = 1, 2 do ns.Indicators.Layout(player, player.geometry, player.s) end
player.parent.GetEffectiveScale = scale

-- Heal prediction follows the fill in By health left, secret channels and all.
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 500, healthMax = 4000, reaction = 2, canAttack = true })
write("target.healthColor", "health")
env.FireEvent("UNIT_HEALTH", "target")
local function plain(v) return env.issecretvalue(v) and env.Reveal(v) or v end
local fill, sr, sg, sb = target.health.colorRGBA, target.incoming:GetStatusBarColor()
assert(near(plain(sr), plain(fill[1])) and near(plain(sg), plain(fill[2])) and near(plain(sb), plain(fill[3])), "incoming heals wear the by-share fill colour")
write("target.healthColor", "hud")

-- Only the player, target and focus slabs are fitted; pet and boss keep the earlier slab.
local others = {}
for _, kind in ipairs({ "pet", "boss" }) do
	local view = ns.Frames.Get(kind).views[1]
	others[kind] = { view = view, health = view.geometry.health and { view.geometry.health.x, view.geometry.health.y, view.geometry.health.w }, level = view.medallion and view.medallion:GetFrameLevel() }
end

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
for kind, was in pairs(others) do
	local h = was.view.geometry.health
	assert(not was.health or near(h.x, was.health[1]) and near(h.y, was.health[2]) and near(h.w, was.health[3]), kind .. ": the switch leaves its bars alone")
	assert(not was.level or was.view.medallion:GetFrameLevel() == was.level, kind .. ": the switch leaves its portrait level alone")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes medallions fit ok")
