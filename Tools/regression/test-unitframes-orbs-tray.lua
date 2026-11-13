-- test-unitframes-orbs-tray.lua: the Orbs style's forged tray: hole, rails, arms and crest placed round action bar 1 from the base art's own measurements, the rings hung on the arms, the tray shown only with the orbs and a live bar 1, and every piece following bar 1 when it moves or scales.
local U = dofile("Tools/regression/unitframes_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1.5)
end

local env, K, ns = U.New({
	saved = { version = 21, profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = { style = "orbs" } } }, characters = {} },
	setup = function(e)
		e.Enum = e.Enum or {}
		e.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
	end,
})
assert(ns.Orbs.Active(), "the orbs run under Orbs")
local tray = assert(ns.Orbs.Tray(), "the tray is built with the orbs")
assert(not tray:IsShown(), "no tray while bar 1 is not live")

local Layouts = K.Setup.Layouts
local grid = Layouts.Grid("actionbars.bar1")
local bar = env.CreateFrame("Frame", nil, K.Scale.Root())
bar:SetSize(12 * grid.size + 11 * grid.spacing, grid.size)
K.Layout.Register(bar, "actionbars.bar1", Layouts.Default("actionbars.bar1"), { label = "Bar 1", scalable = true })
K.Callbacks.Fire("LayoutChanged", "actionbars.bar1")
assert(tray:IsShown(), "the tray shows round a live bar 1")
for _, name in ipairs({ "orbArm", "orbCrest", "orbRail", "orbRailBottom" }) do
	assert(K.Tokens.Texture(name), name .. " is a texture token")
end

local function Check(label)
	local left, bottom, width, height = K.Layout.Rect("actionbars.bar1")
	local cx, cy = left + width / 2, bottom + height / 2
	local art = Layouts.OrbsTray(width)
	local tl, tb = tray:GetLeft(), tray:GetBottom()
	local tx, ty = tl + tray:GetWidth() / 2, tb + tray:GetHeight() / 2
	assert(near(tx, cx) and near(ty, cy), label .. ": the tray centres on bar 1")
	local hole = tray.hole
	assert(hole:GetLeft() <= left + 0.5 and hole:GetRight() >= left + width - 0.5 and hole:GetBottom() <= bottom + 0.5 and hole:GetTop() >= bottom + height - 0.5,
		label .. ": the hole holds bar 1")
	assert(near(tray.armLeft:GetRight() - tx, -(tray.armRight:GetLeft() - tx), 0.01) and near(tray.armLeft:GetLeft() - tx, -(tray.armRight:GetRight() - tx), 0.01),
		label .. ": the right arm mirrors the left exactly")
	assert(near(tray.armLeft:GetLeft(), cx + art.arm.left) and near(tray.rail:GetTop(), cy + art.rail.top), label .. ": arms and rails at the art's measurements")
	assert(near(tray.rail:GetLeft(), tray.armLeft:GetRight()) and near(tray.rail:GetRight(), tray.armRight:GetLeft()), label .. ": the rails run arm to arm")
	local health, power = ns.Orbs.Get("health"), ns.Orbs.Get("power")
	local hx, hy = health:GetLeft() + health:GetWidth() / 2, health:GetBottom() + health:GetHeight() / 2
	local px = power:GetLeft() + power:GetWidth() / 2
	assert(near(hx, cx - art.ringX) and near(px, cx + art.ringX) and near(hy, cy + art.lift), label .. ": each ring hangs at the arm's end")
	assert(near(health:GetWidth(), art.ring), label .. ": the ring is the art's size")
	assert(health:GetRight() > tray.armLeft:GetLeft() and health:GetRight() < tray.armLeft:GetRight() + 8, label .. ": the ring meets its arm")
end
Check("default")
assert(K.Layout.Set("actionbars.bar1", "y", K.Layout.Get("actionbars.bar1").y + 40), "bar 1 moves")
Check("moved")
assert(K.Layout.Set("actionbars.bar1", "scale", 1.2), "bar 1 scales")
Check("scaled")
assert(K.Layout.Set("actionbars.bar1", "scale", 1), "bar 1 back to its size")

-- The tray hides with bar 1 (its shown rule, a hidden holder) and while bar 1 fades until hovered.
bar:Hide()
assert(not tray:IsVisible(), "a hidden bar 1 hides the tray with it")
bar:Show()
assert(tray:IsVisible(), "the tray returns with bar 1")
local bars = K.Store.Module("ActionBars")
bars.bar1 = { fade = true }
K.Callbacks.Fire("SettingChanged", "ActionBars", "bar1.fade")
assert(not tray:IsShown(), "a bar 1 that fades until hovered has no tray")
bars.bar1.fade = false
K.Callbacks.Fire("SettingChanged", "ActionBars", "bar1.fade")
assert(tray:IsShown(), "the tray returns when the fade is off")

-- Bar 1 dragged into a corner: the rings stay on the screen and stay on the tray's arms.
assert(K.Layout.Update("actionbars.bar1", { anchor = "BOTTOMLEFT", x = 0, y = 0 }), "bar 1 moves into the corner")
do
	local _, _, width = K.Layout.Rect("actionbars.bar1")
	local art = Layouts.OrbsTray(width)
	local tx = tray:GetLeft() + tray:GetWidth() / 2
	local ty = tray:GetBottom() + tray:GetHeight() / 2
	local health = ns.Orbs.Get("health")
	local hx, hy = health:GetLeft() + health:GetWidth() / 2, health:GetBottom() + health:GetHeight() / 2
	assert(health:GetLeft() >= 0 and health:GetBottom() >= 0, "the ring stays on the screen")
	assert(near(hx, tx - art.ringX) and near(hy, ty + art.lift), "the ring stays on its arm")
end

-- Moved out of the corner in combat: the rings follow at once, the tray hangs on bar 1 again the moment combat ends.
env.SetCombat(true)
assert(K.Layout.Update("actionbars.bar1", { anchor = "BOTTOM", x = 0, y = 200 }), "bar 1 moves back to the centre in combat")
env.SetCombat(false)
env.RunTimers()
Check("moved in combat")

K.Options.Write("HudStyle", "style", "frames")
assert(not tray:IsShown() and not ns.Orbs.Get("health"):IsShown(), "Frames hides the tray with the orbs")
K.Options.Write("HudStyle", "style", "orbs")
assert(tray:IsShown(), "Orbs shows it again")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok orbs tray")
