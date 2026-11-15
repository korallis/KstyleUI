-- test-unitframes-castbar-medallions.lua: under the Medallions HUD style every cast bar is a square icon with a one-pixel black edge beside a thin flat bar on a dark track, with the caps spell name and the elapsed time under it, and Frames and Orbs get their own look back.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local CastBars = ns.CastBars
local Tokens = K.Tokens

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local STEEL = { 185 / 255, 193 / 255, 204 / 255 }
local SPARK = { 227 / 255, 232 / 255, 238 / 255 }

local element = CastBars.Get("player")[1]
local bar = element.bar
local flat = Tokens.Texture("barFlat")

env._time = 2.2
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
W.Tick(env, 0.1)
assert(element.mode == "above" and not element.medal, "Frames draws the caption cast")
assert(near(select(2, bar:GetSize()), 14, 0.6), "Frames draws the 14-unit bar")
assert(not element.iconEdge:IsShown(), "Frames draws no icon edge")
assert(element.icon:GetNumMaskTextures() == 1, "Frames masks the icon")
assert(bar.innerEdgeToken == "castEdge", "Frames draws the near-black cast edge")
local framesTexture, framesText = bar.texturePath, element.text:GetFont()

K.Options.Write("HudStyle", "style", "medallions")
assert(K.HudStyle.Current() == "medallions", "the style switched")
W.Tick(env, 0.1)
assert(element.medal == true and element.mode == nil and element.line == false, "Medallions is its own form, not a caption or a line")
assert(element.geometry.medal == true, "the layout is the Medallions layout")
assert(element.frame:IsShown(), "the cast stays shown across the switch")

local frameW, frameH = element.frame:GetSize()
assert(near(frameH, 30) and near(frameW, 347), "the cast element keeps the picture's footprint, which this style does not move")

assert(element.iconFrame:IsShown(), "the spell icon shows on the left")
local iw, ih = element.iconFrame:GetSize()
assert(near(iw, ih) and near(iw, frameH), "the icon is a square as tall as the cast element: " .. tostring(iw) .. "x" .. tostring(ih))
local point, _, _, ix, iy = element.iconFrame:GetPoint(1)
assert(point == "TOPLEFT" and near(ix, 0) and near(iy, 0), "the icon stands at the top left")
assert(element.icon:GetNumMaskTextures() == 0, "the icon is square: no round mask")
local iconEdge = W.LastCall(element.iconEdge, "SetColorTexture")
assert(element.iconEdge:IsShown() and iconEdge[1] == 0 and iconEdge[2] == 0 and iconEdge[3] == 0, "the icon has a black edge behind it")
local edge = K.Widgets.Border(element.frame)
local _, _, _, ox, oy = element.icon:GetPoint(1)
assert(near(ox, edge) and near(oy, -edge), "the icon sits one pixel inside its edge")

local barW, barH = bar:GetSize()
assert(near(barH, 8, 0.6), "the bar is the 8-unit strip, got " .. tostring(barH))
local bp, _, _, bx, by = bar:GetPoint(1)
assert(bp == "TOPLEFT" and near(bx, iw + K.Widgets.Snap(element.frame, 7)) and near(by, 0), "the bar starts at the top, one gap right of the icon")
assert(near(barW, frameW - bx, 0.6), "and runs to the right edge")
assert(bar.texturePath == flat, "the fill is the flat bar texture")
assert(bar.innerEdgeOn == true and bar.innerEdgeToken == "black" and W.SameRGB(bar.innerEdge[1], 0, 0, 0), "a one-pixel black edge")
assert(bar.backingOn == true and bar.keyline:IsShown() == false, "a dark flat track with no keyline round it")
assert(bar.lit:IsShown() == false and bar.shade:IsShown() == false and bar.spark:IsShown() == false, "no lit edge, shade or glass spark")
assert(not element.chrome.visible and bar.sheenTop == nil, "no glass card or sheen round the bar")
local cursor = bar.fillCursor
assert(cursor and cursor:IsShown(), "the spark is the fill-edge cursor")
local spark = W.LastCall(cursor, "SetColorTexture")
assert(near(spark[1], SPARK[1]) and near(spark[2], SPARK[2]) and near(spark[3], SPARK[3]), "the spark is pale steel")
local _, relative, relPoint = cursor:GetPoint(1)
assert(relative == bar:GetStatusBarTexture() and relPoint == "RIGHT", "the spark rides the fill's edge without reading it")
local fill = W.LastCall(bar, "SetStatusBarColor")
assert(fill and near(fill[1], STEEL[1]) and near(fill[2], STEEL[2]) and near(fill[3], STEEL[3]), "the player's cast fills steel #b9c1cc")

assert(U.Shown(env, element.text) == "LIGHTNING BOLT", "the spell name is in capitals: " .. U.Shown(env, element.text))
assert(element.text:GetFont() == Tokens.Font("caps"), "in the caps role")
local tp, _, _, tx, ty = element.text:GetPoint(1)
assert(tp == "TOPLEFT" and near(tx, bx) and near(ty, -K.Widgets.Snap(element.frame, 11)), "under the bar, on the left")
assert(element.text:GetJustifyH() == "LEFT", "left aligned")
local rp, _, _, rx, ry = element.timer:GetPoint(1)
assert(rp == "TOPRIGHT" and near(rx, 0) and near(ry, ty), "the time sits under the bar on the right")
assert(element.timer:GetJustifyH() == "RIGHT", "right aligned")
assert(U.Shown(env, element.timer) == "1.2 / 2.5", "elapsed over total: " .. U.Shown(env, element.timer))
assert(element.label:IsShown() == false and element.lock:IsShown() == false, "no Casting or Locked word")
noErrors("medallions cast")

env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 4000, finish = 6500, spellID = 188196, notInterruptible = true }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 188196)
local locked = W.LastCall(bar, "SetStatusBarColor")
local lr, lg, lb = Tokens.Color("textDisabled")
assert(locked and near(locked[1], lr) and near(locked[2], lg) and near(locked[3], lb), "an uninterruptible cast keeps the locked colour")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 188196)
local stopped = W.LastCall(bar, "SetStatusBarColor")
local hr, hg, hb = Tokens.Color("hostile")
assert(stopped and near(stopped[1], hr) and near(stopped[2], hg) and near(stopped[3], hb), "an interrupted cast keeps the hostile colour")
settle()
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 8000, finish = 10500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 188196)
local again = W.LastCall(bar, "SetStatusBarColor")
assert(near(again[1], STEEL[1]) and near(again[2], STEEL[2]) and near(again[3], STEEL[3]), "the next cast is steel again")
K.Options.Write("UnitFrames", "player.castbarColor", "custom")
local custom = K.Options.Read("UnitFrames", "player.castbarCustom")
local painted = W.LastCall(bar, "SetStatusBarColor")
assert(near(painted[1], custom.r) and near(painted[2], custom.g) and near(painted[3], custom.b), "a custom colour is still the player's choice")
K.Options.Write("UnitFrames", "player.castbarColor", "class")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-3", 188196)
settle()

local target = ns.Frames.Get("target").views[1]
U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 50, healthMax = 100, reaction = 2, canAttack = true,
	cast = { name = "Howl", texture = 135808, start = 1000, finish = 3800, spellID = 999 } })
env.SetTarget(true)
W.Tick(env, 0.1)
local tcb = CastBars.Get("target")[1]
assert(CastBars.ElementLive("target"), "the target's cast runs in its own element, as the player's does: the Medallions frame is too short for a second bar")
assert(tcb.medal and tcb.geometry.medal and tcb.frame:IsShown(), "the target's cast bar wears Medallions too")
assert(not target.castbar.frame:IsShown() and not target.castbar.active, "and the frame carries no second bar")
assert(tcb.bar.texturePath == flat and tcb.bar.innerEdgeToken == "black" and tcb.iconEdge:IsShown(), "flat fill, black edge, square icon")
local _, targetH = tcb.bar:GetSize()
assert(targetH <= 8 + 0.6, "its bar is no taller than the strip, got " .. tostring(targetH))
for _, kind in ipairs({ "focus", "boss" }) do
	local cb = ns.Frames.Get(kind).views[1].castbar
	assert(cb.medal and cb.geometry.medal, kind .. "'s cast bar wears Medallions")
end
noErrors("medallions target")

env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", 188196)
K.Options.Write("HudStyle", "style", "frames")
W.Tick(env, 0.1)
assert(not element.medal and element.mode == "above", "Frames gives back the caption cast")
assert(not CastBars.ElementLive("target") and not tcb.frame:IsShown(), "the target's cast goes back inside its frame")
assert(not tcb.medal, "and leaves the Medallions look")
assert(target.castbar.frame:IsShown() and target.castbar.active and not target.castbar.medal, "and the frame's own bar shows the cast")
assert(near(select(2, bar:GetSize()), 14, 0.6), "the 14-unit bar is back")
assert(not element.iconEdge:IsShown(), "the icon edge is gone")
assert(element.icon:GetNumMaskTextures() == 1, "the icon mask is back, once")
assert(bar.innerEdgeToken == "castEdge" and bar.texturePath == framesTexture, "the near-black edge and the settings' texture are back")
assert(bar.lit:IsShown() and bar.shade:IsShown(), "the lit edge and shade are back")
assert(element.text:GetFont() == framesText, "the label face is back")
local back = W.LastCall(bar, "SetStatusBarColor")
assert(near(back[1], K.Theme.Accent()), "the player's cast is in the class accent again")

K.Options.Write("HudStyle", "style", "orbs")
assert(not element.medal and element.mode == "above", "Orbs keeps the caption cast")
noErrors("switch back")
print("unitframes castbar medallions ok")
