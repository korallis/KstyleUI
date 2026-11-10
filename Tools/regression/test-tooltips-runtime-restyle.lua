-- test-tooltips-runtime-restyle.lua: after a type-set or font change at run time, the compare header, its caption and the embedded item border match a fresh load with that setting, and a shown item keeps its quality edge.
local T = dofile("Tools/regression/tooltips_env.lua")

local function saved(appearance)
	return { version = 2, profiles = { Default = { Tooltips = { enabled = true }, Appearance = appearance } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function boot(appearance)
	local env, K, ns = T.New({ saved = saved(appearance) })
	if not K.Modules.IsRunning("Tooltips") then
		assert(K.Modules.Enable("Tooltips"))
	end
	env.RunTimers()
	T.W.Settle(env)
	return env, K, ns
end

local function round(v)
	return type(v) == "number" and string.format("%.4f", v) or tostring(v)
end

local function pieces(out, prefix, chrome)
	for key, list in pairs(chrome) do
		if type(list) == "table" and type(list[1]) == "table" and type(list[1].GetSize) == "function" then
			for i, texture in ipairs(list) do
				local w, h = texture:GetSize()
				out[prefix .. key .. i] = round(w) .. "x" .. round(h)
			end
		end
	end
end

local function points(out, prefix, frame)
	for i = 1, frame:GetNumPoints() do
		local point, _, relative, x, y = frame:GetPoint(i)
		out[prefix .. i] = point .. " " .. tostring(relative) .. " " .. round(x) .. " " .. round(y)
	end
end

local function snapshot(env, K, ns)
	local out = {}
	local header = env.ShoppingTooltip1.CompareHeader
	local panel = K.Skin.Backdrop(header)
	pieces(out, "header.", panel.chrome)
	points(out, "header.point", panel)
	local path, size, flags = header.Label:GetFont()
	out.caption = tostring(path) .. " " .. round(size) .. " " .. tostring(flags)
	local border = ns.Style.ItemBorder(env.GameTooltip.ItemTooltip)
	pieces(out, "border.", border.chrome)
	points(out, "border.point", border)
	return out
end

local function same(fresh, live, what)
	assert(live.caption == fresh.caption, what .. ": the Currently Equipped caption is " .. live.caption .. " after the change, " .. fresh.caption .. " after a fresh load")
	for key, value in pairs(fresh) do
		assert(live[key] == value, what .. ": " .. key .. " is " .. tostring(live[key]) .. " after the change, " .. tostring(value) .. " after a fresh load")
	end
	for key in pairs(live) do
		assert(fresh[key] ~= nil, what .. ": " .. key .. " exists only after the change")
	end
end

-- A type-set change at run time lands where a fresh load with that set lands, in both directions.
for _, case in ipairs({ { from = "Folio", to = "Lumen" }, { from = "Lumen", to = "Folio" } }) do
	local fresh = snapshot(boot({ typeSet = case.to }))
	local env, K, ns = boot({ typeSet = case.from })
	assert(K.Theme.SetTypeSet(case.to))
	env.RunTimers()
	T.W.Settle(env)
	same(fresh, snapshot(env, K, ns), case.from .. " to " .. case.to)
end

-- So does a whole-interface font chosen at run time.
do
	local fresh = snapshot(boot({ font = "InterSemiBold" }))
	local env, K, ns = boot({})
	assert(K.Theme.SetFontFace("InterSemiBold"))
	env.RunTimers()
	T.W.Settle(env)
	same(fresh, snapshot(env, K, ns), "a run-time font")
end

-- A fresh load is already settled: a theme refresh with nothing changed moves nothing.
do
	local env, K, ns = boot({})
	local before = snapshot(env, K, ns)
	K.Callbacks.Fire("ThemeChanged")
	K.Callbacks.Fire("ScaleChanged")
	env.RunTimers()
	T.W.Settle(env)
	same(before, snapshot(env, K, ns), "an idle refresh")
end

-- A shown embedded item keeps its quality edge through a change.
do
	local env, K, ns = boot({})
	local item = env.GameTooltip.ItemTooltip
	item.IconBorder:Show()
	item.IconBorder:SetVertexColor(0.12, 1, 0)
	local rim = ns.Style.ItemBorder(item).chrome.rim[1]
	local r, g, b = rim:GetVertexColor()
	assert(T.Near(r, 0.12) and T.Near(g, 1) and T.Near(b, 0), "the border takes the item's quality colour")
	assert(K.Theme.SetTypeSet("Lumen"))
	env.RunTimers()
	T.W.Settle(env)
	r, g, b = rim:GetVertexColor()
	assert(T.Near(r, 0.12) and T.Near(g, 1) and T.Near(b, 0), "the quality edge survives a type-set change")
end

print("tooltips runtime restyle ok")
