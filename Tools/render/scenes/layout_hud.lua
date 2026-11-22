-- layout_hud.lua: real modules in Layout Mode, with their shared mover registry, toolbar and integration lanes.
local Common = dofile("Tools/render/scenes/_common.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local W = dofile("Tools/regression/widget_env.lua")

return Common.Run(function()
	local opts = { layout = "DPS", class = "SHAMAN", applyPreset = true }
	for key, value in pairs(Reference.STATE) do opts[key] = value end
	local scenes, elements, host = {}, {}, nil
	for _, name in ipairs({ "chat", "databars", "actionbars", "unitframes", "cooldowns" }) do
		local initial = Hud.Module(name, opts)
		local env = Hud.envs[initial]
		local K = env.KstyleUI
		assert(K.Layout.Enter())
		K.Layout.Mode.Overlay():Hide()
		K.Layout.Mode.Toolbar():Hide()
		K.Layout.Mode.Slot():Hide()
		for _ = 1, 20 do W.Tick(env, 0.05) end
		for _, el in ipairs(K.Layout.Elements()) do
			if K.Layout.Mode.Plate(el.key) then
				elements[el.key] = { rect = { K.Layout.Rect(el.key) }, label = el.label, opts = el.opts }
			end
		end
		scenes[#scenes + 1] = Common.Scene.Build(env, { iconDirs = Common.IconDirs(), time = env._time })
		assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
		host = host or env
	end
	local K = host.KstyleUI
	local keys = {}
	for key in pairs(elements) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local el = elements[key]
		if not K.Layout.Element(key) then
			local r = el.rect
			local frame = host.CreateFrame("Frame", nil, K.Scale.Root())
			frame:SetSize(r[3], r[4])
			K.Layout.Register(frame, key, { anchor = "BOTTOMLEFT", x = r[1], y = r[2] }, {
				label = el.label, scalable = el.opts.scalable, resizable = el.opts.resizable,
			})
		end
	end
	K.Layout.Mode.Overlay():Show()
	K.Layout.Mode.Toolbar():Show()
	K.Layout.Mode.Refresh()
	K.Layout.Mode.Select("cooldowns.utility")
	K.Layout.Mode.Slot():Hide()
	scenes[#scenes + 1] = Common.Scene.Build(host, { roots = { K.Layout.Mode.Overlay(), K.Layout.Mode.Toolbar() } })
	local scene = Common.Scene.Merge(scenes)
	scene.movers = elements
	scene.userScale, scene.origin = K.Scale.AppliedUserScale(), K.Scale.Origin()
	scene.toolbar = { K.Layout.Rect("Layout.Toolbar") }
	scene.style = K.HudStyle.Current()
	return scene
end)
