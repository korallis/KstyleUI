-- test-widgets-inset.lua: the one content-inset rule: half the corner radius plus the rim plus a gap, from Widgets.Inset and every chrome, and the kit's panel, dialog, tooltip and window padding follow it.
local W = dofile("Tools/regression/widget_env.lua")

local env, K = W.New()
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local root = Scale.Root()
local border = Scale.Border()

-- The rule: a corner rounded r units clears a box inset r / 2 with room to spare (the arc only needs 0.29 r), the
-- rim is one border, and a gap token keeps text off the rim: gapSmall for dense HUD panels, gapMedium for windows.
local function Rule(radius, gap)
	return Scale.Snap(radius / 2 + border + Tokens.Size(gap or "gapSmall"))
end

assert(type(Widgets.Inset) == "function", "Widgets.Inset exists")
assert(W.Near(Widgets.Inset(root, 14), Rule(14)), "a 14-unit radius: 7 + the rim + gapSmall, got " .. tostring(Widgets.Inset(root, 14)))
assert(W.Near(Widgets.Inset(root, 14, "gapMedium"), Rule(14, "gapMedium")), "with gapMedium the window padding")
assert(W.Near(Widgets.Inset(root, 8), Rule(8)), "a tile's 8-unit radius")
assert(Widgets.Inset(root, 14) >= 11 and Widgets.Inset(root, 14) <= 12 + border, "11 to 13 units at the card radius: text clears the arc and the rim")
assert(Widgets.Inset(root, 14, "gapMedium") >= 15 and Widgets.Inset(root, 14, "gapMedium") <= 16 + border, "and 15 to 17 for windows, about the padding every window has used")
assert(Widgets.Inset(root, 14) >= 14 * (1 - math.sqrt(2) / 2) + border, "never inside the corner's arc")
assert(W.Near(Widgets.Inset(nil, 14), Rule(14)), "with no frame the rule is read in root units")

-- A chrome exposes the inset for its own radius.
local owner = env.CreateFrame("Frame", nil, root)
owner:SetSize(260, 174)
local chrome = Widgets.Chrome(owner, { shape = "panel" })
assert(type(chrome.Inset) == "function", "chrome:Inset exists")
assert(W.Near(chrome:Inset(), Widgets.Inset(owner, chrome:Chamfer())), "chrome:Inset is the rule at the chrome's cut")
assert(W.Near(chrome:Inset("gapMedium"), Widgets.Inset(owner, chrome:Chamfer(), "gapMedium")), "and takes the gap token")
local strip = env.CreateFrame("Frame", nil, root)
strip:SetSize(200, 24)
local stripChrome = Widgets.Chrome(strip, { shape = "panel" })
assert(stripChrome:Inset() < chrome:Inset(), "a shorter panel rounds less, so its content may sit closer to the edge")
assert(stripChrome:Inset() >= stripChrome:Chamfer() / 2 + border, "but never in the arc or on the rim")

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
assert(not ok, "panelPadding is no longer a token; windows use Widgets.Inset(frame, radius, \"gapMedium\")")

assert(#env._errors == 0, tostring(env._errors[1]))
print("widgets inset ok")
