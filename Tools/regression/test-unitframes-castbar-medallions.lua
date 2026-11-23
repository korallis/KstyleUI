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

local SPARK = { 227 / 255, 232 / 255, 238 / 255 }

local element = CastBars.Get("player")[1]
local bar = element.bar
local flat = Tokens.Texture("barFlat")

env._time = 2.2
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
W.Tick(env, 0.1)

K.Options.Write("UnitFrames", "castbarOnFrame", false)
W.Tick(env, 0.1)
assert(element.medal == true and element.mode == nil and element.line == false, "Medallions is its own form, not a caption or a line")
assert(element.geometry.medal == true, "the layout is the Medallions layout")
assert(element.frame:IsShown(), "the cast stays shown across the switch")

local frameW, frameH = element.frame:GetSize()
local styled = K.Setup.Layouts.Style("DPS", "unitframes.castbar.player")
assert(near(frameH, 20) and near(frameW, 300, 1) and near(styled.width, 300) and styled.x == 0, "the cast element is the 300 by 20 slab centred over the hub, got " .. tostring(frameW) .. "x" .. tostring(frameH))
assert(element.slab and element.slab[5]:IsShown() and element.slab[5]:GetTexture() == (Tokens.Texture("medUnitSlabCap")), "it wears the unit slab material with its forged end caps")
assert(not element.iconFrame:IsShown(), "no spell icon: the slab holds the bar and its two texts")

local inset, cap = K.Widgets.Snap(element.frame, 3), K.Widgets.Snap(element.frame, 9)
local barW, barH = bar:GetSize()
assert(near(barH, frameH - 2 * inset, 0.6) and near(barW, frameW - 2 * cap, 0.6), "the bar fills the slab inside its 3-unit rim, clear of the 9-unit end caps, got " .. tostring(barW) .. "x" .. tostring(barH))
local bp, _, _, bx, by = bar:GetPoint(1)
assert(bp == "TOPLEFT" and near(bx, cap) and near(by, -inset), "the bar sits inside the rim and the caps")
K.Options.Write("UnitFrames", "slabCaps", false)
env.RunTimers()
barW = bar:GetSize()
bx = select(4, bar:GetPoint(1))
assert(near(barW, frameW - 2 * inset, 0.6) and near(bx, inset), "Forged slab ends off gives the bar its 3-unit rim at the ends again")
K.Options.Write("UnitFrames", "slabCaps", true)
env.RunTimers()
assert(bar.texturePath == flat, "the fill is the flat bar texture")
local saved = K.Store.Module("UnitFrames")
saved.edit = "player"
local textureRow
for _, row in ipairs(ns.Settings.Schema()) do
	if row.key == "player.castbarTexture" then textureRow = row end
end
assert(textureRow and textureRow.showWhen(saved) == false, "no cast bar texture row: every Medallions cast bar paints the flat fill")
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
local ar, ag, ab = K.Theme.Accent()
local fill = W.LastCall(bar, "SetStatusBarColor")
assert(fill and near(fill[1], ar) and near(fill[2], ag) and near(fill[3], ab), "the player's cast fills in the class accent")

assert(U.Shown(env, element.text) == "LIGHTNING BOLT", "the spell name is in capitals: " .. U.Shown(env, element.text))
assert(element.text:GetFont() == ns.Settings.Font("player", "name"), "in the slab name face")
local pad = K.Widgets.Snap(element.frame, 5)
local tp, trel, trp, tx, ty = element.text:GetPoint(1)
assert(tp == "LEFT" and trel == bar and trp == "LEFT" and near(tx, pad) and near(ty, 0), "on the bar, on the left")
assert(element.text:GetJustifyH() == "LEFT", "left aligned")
local rp, rrel, rrp, rx, ry = element.timer:GetPoint(1)
assert(rp == "RIGHT" and rrel == bar and rrp == "RIGHT" and near(rx, -pad) and near(ry, 0), "the time sits on the bar on the right")
assert(element.timer:GetJustifyH() == "RIGHT", "right aligned")
assert(element.timer:GetFont() == Tokens.Font("number"), "in the number role")
assert(U.Shown(env, element.timer) == "1.3", "the time left: " .. U.Shown(env, element.timer))
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
assert(near(again[1], ar) and near(again[2], ag) and near(again[3], ab), "the next cast is in the accent again")
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
assert(tcb.bar.texturePath == flat and tcb.bar.innerEdgeToken == "black" and not tcb.iconFrame:IsShown(), "flat fill, black edge, no icon")
local targetW, slabH = tcb.frame:GetSize()
assert(near(targetW, 300, 1) and near(slabH, 20, 0.6), "the target cast slab must stay 300 by 20")
assert(near(tcb.frame:GetBottom() - element.frame:GetTop(), K.Widgets.Snap(tcb.frame, 9), 1), "the target cast stacks nine units above the player cast")
local _, targetH = tcb.bar:GetSize()
assert(targetH <= 14 + 0.6, "its bar fits inside the 20-unit slab, got " .. tostring(targetH))
for _, kind in ipairs({ "focus", "boss" }) do
	local cb = ns.Frames.Get(kind).views[1].castbar
	assert(cb.medal and cb.geometry.medal, kind .. "'s cast bar wears Medallions")
end
noErrors("medallions target")

env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", 188196)
K.Options.Write("HudStyle", "style", "frames")
W.Tick(env, 0.1)
assert(not element.medal and element.mode == "inside", "Frames gives back the caption cast, its name inside the bar")
assert(not CastBars.ElementLive("target") and not tcb.frame:IsShown(), "the target's cast goes back inside its frame")
assert(not tcb.medal, "and leaves the Medallions look")
assert(target.castbar.frame:IsShown() and target.castbar.active and not target.castbar.medal, "and the frame's own bar shows the cast")
assert(near(select(2, bar:GetSize()), 14, 0.6), "the 14-unit bar is back")
assert(not element.slab[5]:IsShown(), "the slab is gone")
assert(element.icon:GetNumMaskTextures() == 1, "the icon mask is back, once")
assert(bar.innerEdgeToken == "castEdge" and bar.textureKey == ns.Settings.Value("player", "castbarTexture"), "the near-black edge and the settings' texture are back")
assert(textureRow.showWhen(saved) == true, "and Frames offers the texture row again")
assert(bar.lit:IsShown() and bar.shade:IsShown(), "the lit edge and shade are back")
assert(element.text:GetFont() ~= ns.Settings.Font("player", "name"), "the slab name face goes")
local back = W.LastCall(bar, "SetStatusBarColor")
assert(near(back[1], K.Theme.Accent()), "the player's cast is in the class accent again")
noErrors("frames cast")

print("unitframes castbar medallions ok")
