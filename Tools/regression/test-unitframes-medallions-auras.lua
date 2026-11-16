local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	saved = { version = 2, characters = {}, profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = { style = "medallions" } } } },
})
local Tokens, Settings = K.Tokens, ns.Settings

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

assert(K.HudStyle.Current() == "medallions", "the profile starts in Medallions")
U.SetUnit(env, "target", { name = "Decrepit Darkhound", level = 6, health = 99, healthMax = 120, reaction = 2, canAttack = true, creature = "Demon" })
env.SetTarget(true)
noErrors("login")

assert(Settings.Value("target", "auraSize") == 22 and Settings.Value("target", "auraGrowth") == "LEFT_DOWN", "Medallions takes 22-unit tiles growing away from the medallion")
local view = ns.Frames.Get("target").views[1]
local g = view.geometry
local line = 6 * 22 + 5 * 2
assert(g.aura and math.abs(g.aura.x + line - (g.health.x + g.health.w)) < 1e-6, "the debuff row ends at the bar's medallion end")
assert(g.aura.y == -38, "the 22-unit row stands 16 units over the slab; restore its -38 y")

local c = view.auras.container
local button = c._groups.debuffs.buttons[1]
local w, h = button:GetSize()
assert(math.abs(w - 22) < 0.6 and math.abs(h - 22) < 0.6, "tiles are 22 units: " .. tostring(w))
local entry
for _, each in ipairs(view.auras.buttons) do
	if each.button == button then
		entry = each
	end
end
assert(entry and entry.slab and entry.slab[5]:IsShown(), "the tile wears the aura slab material")
assert(entry.slab[5]:GetTexture() == (Tokens.Texture("medAuraBorder")), "from the medAuraBorder slice")
assert(not entry.chrome.visible, "the Frames chrome stays off")
local dispel = button._aura.dispel
assert(dispel and dispel[#dispel] == entry.underline, "the engine paints the Medallions underline")
assert(button._aura.dispelOptions.showWithoutDispelType == false, "a debuff with no dispel type draws no line")
assert(entry.lineFrame:IsShown(), "the underline's frame shows")
local _, lh = entry.underline:GetSize()
local px = K.Widgets.Border(entry.skin)
assert(lh >= px - 1e-6 and lh <= K.Widgets.Snap(entry.skin, 1.5) + 1e-6, "the underline is 1.5 units, at least a pixel: " .. tostring(lh))
local p1, _, r1 = entry.underline:GetPoint(1)
assert(p1 == "BOTTOMLEFT" and r1 == "BOTTOMLEFT", "along the tile's foot")
assert(entry.timer:GetFont() == Tokens.Font("timer"), "durations read in the timer role")
noErrors("medallions tiles")

K.Options.Write("UnitFrames", "target.auraSize", 30)
assert(Settings.Value("target", "auraSize") == 30, "a saved aura size wins over the Medallions default")
K.Options.Write("UnitFrames", "target.auraSize", 27.6)

local function DispelColour(style)
	local visible = 0
	for _, texture in ipairs(button._aura.dispel) do
		texture:SetVertexColor(0.2, 0.4, 0.8)
		texture:Show()
		if texture:IsVisible() then
			assert(W.SameRGB(texture, 0.2, 0.4, 0.8), style .. ": the visible dispel texture keeps the engine's colour")
			visible = visible + 1
		end
	end
	assert(visible == (style == "medallions" and 1 or 9), style .. ": live switching must restore only the active style's dispel colour without a reload")
end
for _, style in ipairs({ "frames", "medallions", "orbs", "medallions", "frames" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	W.Settle(env)
	local slab = style == "medallions"
	assert(entry.slab[5]:IsShown() == slab and entry.lineFrame:IsShown() == slab, style .. ": only Medallions shows the slab and underline")
	assert(entry.chrome.visible ~= slab, style .. ": the chrome follows the live style")
	DispelColour(style)
	noErrors(style)
end
assert(Settings.Value("target", "auraSize") == 27.6, "Frames keeps its own aura size")
print("ok unitframes medallions auras")
