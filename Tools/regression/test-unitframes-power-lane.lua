-- test-unitframes-power-lane.lua: power stays inside the frame, automatic mana/resource formatting, secret-safe values, and opt-in hue separation.
local U = dofile("Tools/regression/unitframes_env.lua")
local function near(a, b) return math.abs(a - b) < 0.02 end
for _, style in ipairs({ "frames", "medallions" }) do
	local env, K, ns = U.New()
	local view = ns.Frames.Get("player").views[1]
	local g = view.geometry
	assert(view.powerText:IsShown() and g.powerText, "H2: " .. style .. " must display the power number")
	if style == "medallions" then
		assert(g.powerText.y == g.name.y and g.powerText.h == g.name.h, "Medallions power shares the identity row inside the card")
		assert(g.powerText.y + g.powerText.h <= g.glass.h, "the Player Frame mover must contain the power text")
		assert(g.healthSub == nil, "the in-card power number replaces the secondary health percentage")
		assert(g.name.x + g.name.w <= g.powerText.x, "the name and power number have separate room")
	else
		assert(g.powerReserve == nil and g.powerText.y == g.power.y and g.powerText.h == g.power.h, "Frames uses the existing power bar without moving its layout")
		assert(view.powerFillClip:IsShown(), "Frames must keep its fill-clipped ink visible")
	end
	assert(view.powerText:GetJustifyH() == "RIGHT", "the number is right-aligned")
	if style == "medallions" then
		local _, size, flags = view.caption:GetFont()
		assert((view.powerText:GetFont()) == ns.Settings.Font("player", "power") and select(2, view.powerText:GetFont()) == size,
			"Medallions power keeps the number face at the caption size")
		assert(select(3, view.powerText:GetFont()) == flags, "Medallions power uses the caption outline setting")
	else
		assert(select(2, view.powerText:GetFont()) >= 12 and (view.powerText:GetFont()) == K.Tokens.Font("number"),
			"Frames power keeps the number font and size")
	end
	assert(U.Shown(env, view.powerText) == "50%", "mana reads as a percent by default")
	local player = env._units.player
	player.powerType, player.powerToken, player.power, player.powerMax = 3, "ENERGY", 37, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, view.powerText) == "37", "energy reads as a current value")
	player.powerType, player.powerToken = 1, "RAGE"
	env._restricted = true
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, view.powerText) == "37", "secret rage goes straight to the number")
	local powerType = env.UnitPowerType
	env.UnitPowerType = function() return env.Secret(0), env.Secret("MANA") end
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, view.powerText) == "37", "a secret power type takes the current-value fallback")
	env.UnitPowerType = powerType
	ns.Format.Power(view.powerText, "player", "auto", env.Secret(3))
	assert(U.Shown(env, view.powerText) == "37", "a supplied secret power type is not compared")
	K.Options.Write("UnitFrames", "player.powerText", "none")
	assert(not view.powerText:IsShown() and not view.geometry.powerText, "None removes the lane")
	K.Options.Write("UnitFrames", "player.powerText", "legacy")
	assert(not view.powerText:IsShown() and not view.geometry.powerText, "Previous display restores the original hidden power text")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = U.New()
	local power = ns.Orbs.Get("power")
	assert(power.value:GetJustifyH() == "CENTER", "the resource number keeps its existing centred position")
	assert(U.Shown(env, power.value) == "50%", "Orbs keeps mana in its existing resource orb")
	local player = env._units.player
	player.powerType, player.powerToken, player.power, player.powerMax = 3, "ENERGY", 37, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, power.value) == "37%", "Orbs keeps its independent percent format")
	env._restricted = true
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, power.value) == "37%", "the orb passes restricted resource values to its number")
	K.Options.Write("UnitFrames", "player.powerText", "legacy")
	assert(power.value:GetJustifyH() == "CENTER" and U.Shown(env, power.value) == "37%", "frame text options leave the orb unchanged")
	K.Options.Write("UnitFrames", "player.powerText", "none")
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, power.value) == "37%", "None on the player frame leaves the orb's number visible")
end

local env, K, ns = U.New()
local view = ns.Frames.Get("player").views[1]
assert(view.s.powerSeparate == true, "H2b defaults on under the owner's new-settings rule")
K.Options.Write("UnitFrames", "player.powerSeparate", false)
K.Options.Write("UnitFrames", "player.healthColor", "custom")
K.Options.Write("UnitFrames", "player.healthCustom", { r = 1, g = 1, b = 0 })
K.Options.Write("UnitFrames", "player.powerColor", "custom")
K.Options.Write("UnitFrames", "player.powerCustom", { r = 1, g = 0.9, b = 0 })
local r, g, b = view.power:GetStatusBarColor()
assert(near(r, 1) and near(g, 0.9) and near(b, 0), "power colour stays with the option off")
K.Options.Write("UnitFrames", "player.powerSeparate", true)
local sr, sg, sb = K.Tokens.Color("steelLit")
r, g, b = view.power:GetStatusBarColor()
assert(near(r, sr) and near(g, sg) and near(b, sb), "nearby hues use steel for power when enabled")
local ir, ig, ib, ia = K.Widgets.InkFor(sr, sg, sb)
assert(view.powerFillText, "a fill-clipped ink layer leaves the empty power track readable")
local tr, tg, tb, ta = view.powerFillText:GetTextColor()
assert(near(tr, ir) and near(tg, ig) and near(tb, ib) and near(ta, ia), "text inside the light power fill uses the merged dark-ink rule")
assert(select(3, view.powerFillText:GetFont()) == "", "dark ink on a light fill does not rely on an outline")
assert(select(1, view.powerText:GetTextColor()) > 0.9 and select(3, view.powerText:GetFont()) == "OUTLINE", "light outlined ink stays readable over the empty track")
local player = env._units.player
for _, amount in ipairs({ 0, 50, 100 }) do
	player.power = amount
	env._restricted = true
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, view.powerText) == U.Shown(env, view.powerFillText), "both ink layers format the same restricted power")
end
env._restricted = false
assert(U.W.LastCall(view.powerFillClip, "SetClipsChildren")[1] and select(2, view.powerFillClip:GetPoint(1)) == view.power:GetStatusBarTexture(), "the engine clips fill ink to the actual fill without Lua reading power")
assert(view.powerTypeLine:IsShown() and near(env.Look(view.powerTypeLine:GetHeight()), 1), "a 1-unit line keeps the power colour")
K.Options.Write("UnitFrames", "player.powerSeparate", false)
r, g, b = view.power:GetStatusBarColor()
assert(near(r, 1) and near(g, 0.9) and near(b, 0) and not view.powerTypeLine:IsShown(), "turning the option off restores the original fill")
K.Options.Write("UnitFrames", "player.powerSeparate", true)
K.Options.Write("UnitFrames", "player.powerCustom", { r = 0, g = 0, b = 1 })
r, g, b = view.power:GetStatusBarColor()
assert(near(r, 0) and near(g, 0) and near(b, 1) and not view.powerTypeLine:IsShown(), "distant hues keep their power colour")
ir, ig, ib = K.Widgets.InkFor(0, 0, 1)
tr, tg, tb = view.powerFillText:GetTextColor()
assert(near(tr, ir) and near(tg, ig) and near(tb, ib), "a dark fill restores light ink")
K.Options.Write("UnitFrames", "player.powerCustom", { r = 1, g = 0.9, b = 0 })
tr, tg, tb = view.powerText:GetTextColor()
ir, ig, ib = K.Tokens.Color("labelMuted")
assert(near(tr, ir) and near(tg, ig) and near(tb, ib), "Medallions power uses the muted caption colour")
assert(not view.powerFillClip:IsShown(), "the in-card Medallions caption has no clipped overlay")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Guard = dofile("Tools/render/guard.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	_G.RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
	_G.RENDER_HUD_STYLE = "Medallions"
	local e, kit, units = U.New(Common.ScreenOpts({
		saved = Hud.Saved(Hud.Options({ layout = "DPS" }), "UnitFrames", {}),
		setup = function(game) Common.ForceScreen(game, true) end,
	}))
	e.RunTimers()
	local v = units.Frames.Get("player").views[1]
	for _, health in ipairs({ "both", "percent", "currentMax", "none" }) do
		kit.Options.Write("UnitFrames", "player.healthText", health)
		local geometry = v.geometry
		assert(geometry.powerText and geometry.powerText.y + geometry.powerText.h <= geometry.glass.h,
			"keep every power format inside the Medallions card at " .. screen[1] .. "x" .. screen[2])
	end
	for _, kind in ipairs({ "target", "focus", "pet" }) do
		U.SetUnit(e, kind, { name = "Boar", level = 60, health = 50, healthMax = 100, power = 100, powerMax = 100, powerType = 0, powerToken = "MANA" })
		kit.Options.Write("UnitFrames", kind .. ".enabled", true)
		kit.Options.Write("UnitFrames", kind .. ".power", true)
		kit.Options.Write("UnitFrames", kind .. ".powerText", "percent")
		local other = units.Frames.Get(kind).views[1]
		local geometry = other.geometry
		local text = geometry.powerText
		assert(text and text.y == geometry.name.y and text.h == geometry.name.h, kind .. " power shares the identity row")
		assert(text.y + 0.02 >= geometry.power.y + geometry.power.h and text.y + text.h <= geometry.glass.h + 0.02,
			kind .. " power fits below the bar inside the card")
		local _, size, flags = units.Settings.Font(kind, "level")
		local path = units.Settings.Font(kind, "power")
		assert((other.powerText:GetFont()) == path and select(3, other.powerText:GetFont()) == flags,
			kind .. " power uses the caption font")
		assert(text.h >= size and text.w >= Common.Scene.TextWidth("100%", size, path),
			kind .. " power must fit without truncation at " .. screen[1] .. "x" .. screen[2])
		e.SetTarget(true)
		e.FireEvent("PLAYER_FOCUS_CHANGED")
		e.FireEvent("UNIT_PET", "player")
		local scene = Common.Scene.Build(e)
		local drawn = false
		for _, item in ipairs(scene.items) do
			if item.object == other.powerText then
				drawn = true
				assert(item.rect[4] >= item.font.size, kind .. " rendered power rect must fit the caption height")
			end
		end
		assert(drawn and U.Shown(e, other.powerText) == "100%", kind .. " enabled power text must render")
		for _, finding in ipairs(Guard.Check(scene)) do
			assert(finding.object ~= other.powerText, kind .. " power fails strict render: " .. finding.kind .. " " .. finding.detail)
		end
		kit.Options.Write("UnitFrames", kind .. ".powerText", "none")
		assert(not other.geometry.powerText and not other.powerText:IsShown(), kind .. " power text switches off")
	end
	kit.Layout.Enter()
	e.RunTimers()
	local px, py, pw, ph = Common.Scene.Rect(e, kit.Layout.Mode.Plate("unitframes.player"))
	local tx, ty, tw, th = Common.Scene.Rect(e, v.powerText)
	assert(tx >= px - 1 and ty >= py - 1 and tx + tw <= px + pw + 1 and ty + th <= py + ph + 1,
		"the Player Frame mover must contain the entire power text at " .. screen[1] .. "x" .. screen[2])
	assert(#e._errors == 0 and kit.ErrorCount() == 0, tostring(e._errors[1]))
end
_G.RENDER_SCREEN, _G.RENDER_HUD_STYLE = nil, nil

print("unitframes power lane ok")
