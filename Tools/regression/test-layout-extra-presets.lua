-- test-layout-extra-presets.lua: Medallions extra layouts fit every role, owner screen and arrangement, including saved positions.
local C = dofile("Tools/regression/core_env.lua")
local screens = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local checked = 0
for _, screen in ipairs(screens) do
	local env, K = C.New({ width = screen[1], height = screen[2], fit = true })
	C.Boot(env)
	K.Options.Write("HudStyle", "style", "medallions")
	local L = K.Setup.Layouts
	for _, arrangement in ipairs({ "centred", "spread" }) do
		K.Options.Write("Layout", "arrangement", arrangement)
		for _, name in ipairs(L.Names()) do
			K.Options.Write("Layout", "preset", name)
			for _, kind in ipairs({ "rows", "beside" }) do
				local cfg = K.Store.Module("ActionBars")
				cfg.extraBarsApplied = kind
				cfg.bar4, cfg.bar5 = L.ExtraBarsPreset(kind, K.Scale.Aspect()), L.ExtraBarsPreset(kind, K.Scale.Aspect())
				local enabled = L.Enabled(name)
				enabled["consumables.bar"] = false
				enabled["actionbars.bar4"], enabled["actionbars.bar5"] = true, true
				local width = arrangement == "centred" and math.min(screen[1], screen[2] * 21 / 9) or screen[1]
				local cap, fits = L.ScaleLimit(width, screen[2], name, enabled, "medallions")
				local label = name .. " " .. kind .. " " .. screen[1] .. "x" .. screen[2] .. " " .. arrangement
				assert(fits(cap), label .. ": default overlap guard must fit")
				if kind == "beside" and name == "DPS" then assert(fits(0.9375), label .. ": D must not shrink the usual DPS HUD") end
				local at = L.Positions(name, "medallions", K.Scale.Aspect())
				local positions = K.Store.Layout()
				for _, key in ipairs({ "actionbars.bar4", "actionbars.bar5" }) do
					local p = at[key]
					positions["medallions:" .. key] = { anchor = p.anchor, x = p.x, y = p.y + 1 }
					at[key] = positions["medallions:" .. key]
				end
				assert(L.Fits(name, width, screen[2], cap * 0.99, enabled, at, "medallions"), label .. ": safe saved positions must fit")
				local oldChat = { anchor = "TOPLEFT", x = 24, y = -200 }
				positions["chat.main"] = oldChat
				K.Callbacks.Fire("ProfileChanged")
				assert(positions["chat.main"] == oldChat, "a saved chat position is never written")
				local styled = L.Style("medallions", name, "chat.main")
				assert(not styled, "a saved chat position keeps its usual layout scope")
				positions["chat.main"] = nil
				at["actionbars.bar4"] = { anchor = "BOTTOM", x = 0, y = at["actionbars.bar1"].y }
				assert(not L.Fits(name, width, screen[2], cap, enabled, at, "medallions"), label .. ": saved bar on the hub must fail")
				cfg.extraBarsApplied = "off"
				positions["medallions:actionbars.bar4"], positions["medallions:actionbars.bar5"] = nil, nil
				checked = checked + 1
			end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
	collectgarbage("collect")
end
print("ok layout extra presets: " .. checked .. " role, layout, screen and arrangement cases")
