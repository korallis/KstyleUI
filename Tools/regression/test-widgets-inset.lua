-- test-widgets-inset.lua: the one content-inset rule: half the corner cut plus the three edge rows plus a gap, from Widgets.Inset and every chrome, and the kit's panel, dialog, tooltip and window padding follow it.
local W = dofile("Tools/regression/widget_env.lua")

local env, K = W.New()
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local root = Scale.Root()
local border = Scale.Border()

-- The rule: a 45-degree cut of c units clears a box inset c / 2, the edge band is three borders (outer, light,
-- fade), and a gap token keeps text off the light line: gapSmall for dense HUD panels, gapMedium for windows.
local function Rule(chamfer, gap)
	return Scale.Snap(chamfer / 2 + 3 * border + Tokens.Size(gap or "gapSmall"))
end

assert(type(Widgets.Inset) == "function", "Widgets.Inset exists")
assert(W.Near(Widgets.Inset(root, 12), Rule(12)), "a 12-unit cut: 6 + the edge band + gapSmall, got " .. tostring(Widgets.Inset(root, 12)))
assert(W.Near(Widgets.Inset(root, 12, "gapMedium"), Rule(12, "gapMedium")), "with gapMedium the window padding")
assert(W.Near(Widgets.Inset(root, 6), Rule(6)), "a tile's 6-unit cut")
assert(Widgets.Inset(root, 12) >= 12 and Widgets.Inset(root, 12) <= 12 + 3 * border, "12 to 15 units at the panel cap by the screen's border: the mockup's text margin")
assert(Widgets.Inset(root, 12, "gapMedium") >= 16 and Widgets.Inset(root, 12, "gapMedium") <= 16 + 3 * border, "and 16 to 19 for windows: never less than the padding every window has used")
assert(W.Near(Widgets.Inset(nil, 12), Rule(12)), "with no frame the rule is read in root units")

-- A chrome exposes the inset for its own cut.
local owner = env.CreateFrame("Frame", nil, root)
owner:SetSize(260, 174)
local chrome = Widgets.Chrome(owner, { shape = "panel" })
assert(type(chrome.Inset) == "function", "chrome:Inset exists")
assert(W.Near(chrome:Inset(), Widgets.Inset(owner, chrome:Chamfer())), "chrome:Inset is the rule at the chrome's cut")
assert(W.Near(chrome:Inset("gapMedium"), Widgets.Inset(owner, chrome:Chamfer(), "gapMedium")), "and takes the gap token")
local strip = env.CreateFrame("Frame", nil, root)
strip:SetSize(200, 24)
local stripChrome = Widgets.Chrome(strip, { shape = "panel" })
assert(stripChrome:Inset() < chrome:Inset(), "a shorter panel cuts less, so its content may sit closer to the edge")
assert(stripChrome:Inset() >= stripChrome:Chamfer() / 2 + 3 * border, "but never under the cut or on the light line")

-- The kit's panel pads its content by the rule with the window gap.
local panel = Widgets.Panel(root, { width = 300, height = 180 })
local p = panel.content._points[1]
assert(W.Near(p[4], panel.chrome:Inset("gapMedium")) and W.Near(p[5], -panel.chrome:Inset("gapMedium")), "panel content starts one rule inset in")
local titled = Widgets.Panel(root, { width = 320, height = 200, title = "Title" })
local t = titled.titleText._points[1]
assert(W.Near(t[4], titled.chrome:Inset("gapMedium")), "a panel title sits one rule inset from the left")
assert(W.Near(t[5], -titled.chrome:Inset("gapMedium")), "and from the top")

-- The kit's tooltip pads its lines by the rule.
local tip = Widgets.Tooltip and Widgets.Tooltip(root)
if tip then
	tip:ClearLines()
	tip:AddTitle("Vanquisher's Blade")
	tip:AddLine("Item Level 42")
	tip:Layout()
	local line = tip.used[1].left._points[1]
	assert(W.Near(line[4], tip.chrome:Inset()), "tooltip text starts one rule inset from the left, got " .. tostring(line[4]))
end

-- The window padding token is gone: every window asks the rule.
local ok = pcall(Tokens.Size, "panelPadding")
assert(not ok, "panelPadding is no longer a token; windows use Widgets.Inset(frame, chamfer, \"gapMedium\")")

assert(#env._errors == 0, tostring(env._errors[1]))
print("widgets inset ok")
