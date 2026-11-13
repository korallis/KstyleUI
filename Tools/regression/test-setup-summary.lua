-- test-setup-summary.lua: the setup's summary lays out on the design bible's card grid (KSTY-60 item 27: text crammed
-- left, the diagram bottom right, empty space). Two even cards side by side, Your choices and the layout Apply builds,
-- one height and 12 units apart, over a full-width status card headed with what is left to do; each card keeps its
-- 16-unit padding around its heading, text, buttons and diagram, the diagram centred in its card, and nothing spills
-- past the page, before Apply and after it at the largest text size with every Edit Mode note showing.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local Scene = dofile("Tools/render/scene.lua")
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")

local MODULES = {
	"UnitFrames", "ActionBars", "Cooldowns", "GroupFrames", "Auras", "Nameplates", "CombatText", "Minimap", "Chat",
	"Bags", "Tooltips", "DataBars", "Meters", "Skins", "QoL",
}
local PAD, GAP, SLACK = 16, 12, 0.51

local function Boot()
	local env, K = W.New({
		boot = false,
		setup = function(e)
			e.C_AddOns = {
				DoesAddOnExist = function()
					return true
				end,
				LoadAddOn = function()
					return false, "MISSING"
				end,
			}
			e._textWidth = function(text, fontPath, size)
				return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
			end
		end,
	})
	for _, name in ipairs(MODULES) do
		K.Modules.Register(CoreEnv.Module(name))
	end
	CoreEnv.Boot(env)
	return env, K
end

local function near(a, b)
	return math.abs(a - b) <= SLACK
end

local function check(env, K, panel, what)
	Scene.Build(env, {})
	local function box(object)
		local x, y, w, h = Scene.Rect(env, object)
		assert(x, what .. ": a summary part has no rect")
		return { left = x, right = x + w, top = y, bottom = y + h }
	end
	assert(panel.summaryChoices and panel.summaryLayout and panel.summaryStatus, what .. ": the summary is three cards")
	local page = box(panel.pages[6])
	local left, right, low = box(panel.summaryChoices), box(panel.summaryLayout), box(panel.summaryStatus)
	local width = right.right - right.left
	assert(near(left.right - left.left, width), what .. ": the two columns are even, " .. (left.right - left.left) .. " and " .. width)
	assert(near(left.top, right.top) and near(left.bottom, right.bottom), what .. ": the choices and the layout cards are one height")
	assert(near(left.left, page.left) and near(right.right, page.right), what .. ": the columns fill the page's width")
	assert(near(right.left - left.right, GAP), what .. ": 12 units between the columns, got " .. (right.left - left.right))
	assert(near(low.left, page.left) and near(low.right, page.right), what .. ": the status card spans the page")
	assert(near(low.top - left.bottom, GAP), what .. ": 12 units between the rows, got " .. (low.top - left.bottom))
	assert(near(left.top, page.top) and low.bottom <= page.bottom + SLACK, what .. ": the grid starts at the page's top and stays on the page")
	local function inside(object, card, name)
		local r = box(object)
		assert(r.left >= card.left + PAD - SLACK and r.right <= card.right - PAD + SLACK and r.top >= card.top + PAD - SLACK and r.bottom <= card.bottom - PAD + SLACK,
			string.format("%s: %s keeps the card's padding (%.1f..%.1f x %.1f..%.1f in %.1f..%.1f x %.1f..%.1f)", what, name, r.left, r.right, r.top, r.bottom, card.left, card.right, card.top, card.bottom))
		return r
	end
	local function text(fs, card, name)
		local r = inside(fs, card, name)
		local height = K.Widgets.WrappedHeight(fs, r.right - r.left)
		assert(r.top + height <= card.bottom - PAD + SLACK, what .. ": " .. name .. "'s " .. height .. " units of text stay above the card's foot")
	end
	inside(panel.summaryChoices.cap, left, "the choices heading")
	text(panel.summary, left, "the choices")
	inside(panel.summaryLayout.cap, right, "the layout heading")
	local diagram = inside(panel.summaryPreview, right, "the diagram")
	assert(near((diagram.left + diagram.right) / 2, (right.left + right.right) / 2), what .. ": the diagram is centred in its card")
	inside(panel.summaryStatus.cap, low, "the status heading")
	text(panel.summaryHelp, low, "the help")
	if panel.editMode:IsShown() then
		text(panel.editMode, low, "the Edit Mode lines")
	end
	for _, button in ipairs({ panel.retry, panel.manager }) do
		if button:IsShown() then
			inside(button, low, "a button")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Before Apply, at the default text size.
do
	local env, K = Boot()
	K.Setup.Open()
	W.Settle(env)
	K.Setup.Go(6)
	W.Settle(env)
	check(env, K, K.Setup.window, "before Apply")
end

-- After Apply at the largest text size, with Edit Mode's layout written and both tracked viewers left in place.
do
	local env, K = Boot()
	EditModeFake.Install(env, { saved = {}, active = 1 })
	env.CooldownViewerSettings = { ShowUIPanel = function() end }
	K.Options.Write("Appearance", "fontScale", K.Theme.MAX_FONT_SCALE)
	K.Setup.EditMode.CountTracked(function(group)
		return ({ buffs = 80, bars = 60 })[group]
	end)
	K.Setup.Open()
	W.Settle(env)
	K.Setup.Go(6)
	W.Settle(env)
	local panel = K.Setup.window
	W.Click(panel.apply)
	W.Settle(env)
	assert(panel.editMode:IsShown() and panel.manager:IsShown() and panel.retry:IsShown(), "the notes, Try again and the Cooldown Manager show")
	check(env, K, panel, "after Apply at the largest text size")
end

print("setup summary ok")
