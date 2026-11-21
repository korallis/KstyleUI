-- test-tooltip-clear.lua: a kit tooltip opens on the side of its owner with room on the screen, so it never comes
-- down over the bar the pointer is on: the data bar readouts and micro menu in every HUD style at four screen
-- sizes, and an owner flush against each screen edge. The render solver clamps to the screen as the client does.
local D = dofile("Tools/regression/databars_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function rect(env, frame)
	local x, y, w, h = Scene.Rect(env, frame)
	assert(x and w > 0 and h > 0, "the frame resolves")
	return { x, y, w, h }
end

local function overlaps(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

local function clear(env, tip, owner, rows, what)
	local t = rect(env, tip)
	for _, row in ipairs(rows) do
		local r = rect(env, row)
		assert(not overlaps(t, r), what .. ": the tooltip " .. table.concat(t, ",") .. " covers the hovered row "
			.. table.concat(r, ",") .. " and the pointer on it")
	end
	assert(not overlaps(t, rect(env, owner)), what .. ": the tooltip covers the hovered element")
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = function(e) D.Menus(e) end })
		K.Options.Write("HudStyle", "style", style)
		K.Options.Write("DataBars", "micro.shown", true)
		local view, tip = ns.Strip.view, K.Widgets.Tooltip()
		local where = style .. " " .. screen[1] .. "x" .. screen[2]
		assert(view.topBar == (style ~= "medallions"), where .. ": Frames and Orbs put the data bar along the top")
		for _, id in ipairs(ns.Strip.order) do
			local button = view.items[id].button
			W.Enter(button)
			assert(tip:IsOwned(button), where .. ": the " .. id .. " readout shows the kit tooltip")
			clear(env, tip, button, { view.frame }, where .. " " .. id)
			W.Leave(button)
		end
		local micro = ns.Menus.Shown("micro")
		assert(#micro > 0, where .. ": the micro menu has buttons")
		local rows = { ns.Menus.Content("micro") }
		if view.topBar then rows[2] = view.frame end
		for _, button in ipairs(micro) do
			W.Enter(button)
			assert(tip:IsOwned(button), where .. ": a micro button shows the kit tooltip")
			clear(env, tip, button, rows, where .. " micro")
			W.Leave(button)
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- Any owner against a screen edge: the tooltip asked toward that edge opens on the other side; in open space it
-- keeps the side asked for.
do
	local env, K = D.New({ width = 1920, height = 1080, size = "auto" })
	local tip = K.Widgets.Tooltip()
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(40, 14)
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		for _, edge in ipairs({ true, false }) do
			owner:ClearAllPoints()
			owner:SetPoint(edge and side or "CENTER", env.UIParent, edge and side or "CENTER")
			tip:SetOwner(owner, "ANCHOR_" .. side)
			tip:AddLine("A tooltip line long enough to be wider than its owner")
			tip:Show()
			local t, o = rect(env, tip), rect(env, owner)
			assert(not overlaps(t, o), side .. (edge and " edge" or " centre") .. ": the tooltip covers its owner")
			local above, left = t[2] + t[4] <= o[2], t[1] + t[3] <= o[1]
			local want = ({ TOP = above, BOTTOM = t[2] >= o[2] + o[4], LEFT = left, RIGHT = t[1] >= o[1] + o[3] })[side]
			assert(want ~= edge, side .. (edge and " edge: the tooltip opens away from the edge" or " centre: the tooltip keeps the side asked for"))
			tip:Hide()
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("tooltip clear ok: data bar readouts and micro menu in every style at four sizes, and owners on every edge")
