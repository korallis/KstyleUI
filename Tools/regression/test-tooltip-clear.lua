-- test-tooltip-clear.lua: a kit tooltip opens on the side of its owner with room on the screen, so it never comes
-- down over the bar the pointer is on: the data bar readouts and micro menu at four screen
-- sizes, and an owner flush against each screen edge. The render solver clamps to the screen as the client does.
local D = dofile("Tools/regression/databars_env.lua")
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
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = function(e) D.Menus(e) end })
	local view, tip = ns.Strip.view, K.Widgets.Tooltip()
	local where = screen[1] .. "x" .. screen[2]
	for _, id in ipairs(ns.Strip.order) do
		local button = view.items[id].button
		D.W.Enter(button)
		assert(tip:IsOwned(button), where .. ": the " .. id .. " readout shows the kit tooltip")
		clear(env, tip, button, { view.frame }, where .. " " .. id)
		D.W.Leave(button)
	end
	local micro = ns.Menus.Shown("micro")
	assert(#micro > 0, where .. ": the micro menu has buttons")
	local rows = { ns.Menus.Content("micro") }
	for _, button in ipairs(micro) do
		D.W.Enter(button)
		assert(tip:IsOwned(button), where .. ": a micro button shows the kit tooltip")
		clear(env, tip, button, rows, where .. " micro")
		D.W.Leave(button)
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
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
-- A two-row menu along the bottom edge: a lower-row button's tooltip clears the whole bar, not only the button.
do
	local env, K, ns = D.New({ width = 1920, height = 1080, size = "auto", setup = function(e) D.Menus(e) end })
	K.Options.Write("DataBars", "strip.menus", false)
	K.Options.Write("DataBars", "micro.rows", 2)
	local holder = ns.Menus.Holder("micro")
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOM", env.UIParent, "BOTTOM")
	for _, button in ipairs(ns.Menus.Shown("micro")) do
		D.W.Enter(button)
		clear(env, K.Widgets.Tooltip(), button, { ns.Menus.Content("micro") }, "two-row bottom menu")
		D.W.Leave(button)
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A tooltip too tall for above or below opens beside its owner; an offset away from the owner flips with the
-- tooltip; a restricted owner and an owner whose measurements turn secret show the tooltip without an error.
do
	local env, K = D.New({ width = 1920, height = 1080, size = "auto" })
	local tip = K.Widgets.Tooltip()
	local function Owner(point, lines, x, y)
		local owner = env.CreateFrame("StatusBar", nil, K.Scale.Root())
		owner:SetSize(40, 14)
		owner:SetPoint(point, env.UIParent, point)
		tip:SetOwner(owner, "ANCHOR_TOP", x, y)
		for _ = 1, lines do tip:AddLine("test") end
		return owner
	end
	local tall = Owner("CENTER", 49)
	tip:Show()
	assert(not overlaps(rect(env, tip), rect(env, tall)), "a tooltip too tall for above or below covers its owner")
	local offset = Owner("TOP", 1, 0, 12)
	tip:Show()
	assert(not overlaps(rect(env, tip), rect(env, offset)), "a flipped tooltip keeps its offset toward the owner")
	env.RestrictAnchoring(Owner("TOP", 1))
	tip:Show()
	assert(tip:IsShown(), "a restricted owner shows the tooltip")
	local secret = Owner("TOP", 1)
	secret:SetValue(env.Secret(10))
	tip:Show()
	tip:SetOwner(secret, "ANCHOR_TOP")
	tip:AddLine("test")
	tip:Show()
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("tooltip clear ok: data bar readouts and micro menu at four sizes, owners on every edge, a two-row bottom menu, restricted, secret, tall and offset owners")
