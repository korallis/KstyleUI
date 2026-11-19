-- test-actionbars-extra-presets.lua: one-shot extra-bar layouts, restoration, editing and combat on the four owner screens.
local AB = dofile("Tools/regression/actionbars_env.lua")
local C = AB.CoreEnv
local screens = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local function Near(a, b, why) assert(math.abs(a - b) < 2, why .. ": " .. a .. " ~= " .. b) end
for _, screen in ipairs(screens) do
	local env, K, ns = AB.New({ width = screen[1], height = screen[2] })
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	local cfg, positions = K.Store.Module("ActionBars"), K.Store.Layout()
	assert(cfg.extraBarsLayout == "off" and cfg.extraBarsApplied == "off", "presets ship off")
	local option = K.Options.Row("ActionBars", "extraBarsLayout")
	assert(option and option.showWhen(cfg), "Medallions offers the preset selector")
	K.Options.Write("ActionBars", "bar4.rows", 3)
	K.Options.Write("ActionBars", "bar5.enabled", false)
	assert(K.Layout.Update("actionbars.bar4", { anchor = "TOPLEFT", x = 80, y = -200, scale = 0.8 }))
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2" }) do
		assert(K.Layout.Set(key, "y", K.Layout.Get(key).y + 8))
	end
	local before4, before5 = C.DeepCopy(cfg.bar4), C.DeepCopy(cfg.bar5)
	local original = C.DeepCopy(positions)
	local baseline = K.Layout.Get("actionbars.bar1")
	for _, kind in ipairs({ "rows", "beside" }) do
		K.Options.Write("ActionBars", "extraBarsLayout", kind)
		for _, key in ipairs({ "bar4", "bar5" }) do
			local expected = K.Setup.Layouts.ExtraBarsPreset(kind, K.Scale.Aspect())
			for field, value in pairs(expected) do assert(cfg[key][field] == value, kind .. " writes " .. key .. "." .. field) end
			local bar, base = ns.bars[key], ns.bars[key == "bar4" and "bar1" or "bar2"]
			assert(bar.count == expected.buttons and bar.header:IsShown(), "preset enables both bars")
			assert(math.abs(bar.holder:GetScale() - 1) < 1e-6, "preset resets layout scale")
			if kind == "rows" then
				assert(ns.Slab.joined[key], "the upper row joins the slab")
				Near(bar.holder:GetLeft(), base.holder:GetLeft(), "rows align")
				Near(bar.holder:GetBottom() - base.holder:GetTop(), expected.spacing, "slab socket gap")
			else
				assert(ns.Slab.sides[key]:IsShown(), "beside bars use the slab plate builder")
				Near(ns.Slab.sides[key]:GetTop(), ns.Slab.frame:GetTop(), "beside plates align at their tops")
			end
		end
		assert(K.Layout.Get("actionbars.bar1").y == baseline.y, "main bars keep their baseline")
		if kind == "rows" then
			Near(select(2, ns.Slab.hub:GetCenter()), (ns.bars.bar1.holder:GetBottom() + ns.bars.bar4.holder:GetTop()) / 2, "crest centres across both rows")
		end
		local schema = K.Options.Row("ActionBars", "bar4.rows")
		cfg.editBar = "bar4"
		assert(schema.showWhen(cfg), "preset bars keep row controls")
		K.Options.Write("ActionBars", "bar4.rows", 4)
		K.Options.Write("ActionBars", "bar4.buttons", 4)
		K.Options.Write("ActionBars", "bar4.size", 24)
		assert(K.Layout.Update("actionbars.bar4", { anchor = "TOPLEFT", x = 600, y = -250, scale = 1.2 }))
		K.Callbacks.Fire("ProfileChanged")
		K.Callbacks.Fire("ScaleChanged")
		assert(cfg.bar4.rows == 4 and cfg.bar4.buttons == 4 and cfg.bar4.size == 24, "refreshes preserve edits")
		assert(K.Layout.Get("actionbars.bar4").x == 600 and K.Layout.Get("actionbars.bar4").scale == 1.2, "position and scale edits stick")
		assert(ns.Slab.sides.bar4:IsShown(), "a moved or reshaped row gets its own slab")
		if screen[1] == 1920 then
			local reloaded, RK, RN = AB.New({ saved = C.DeepCopy(env.KstyleUIDB) })
			AB.Enable(reloaded, RK)
			assert(RN.Config("bar4").rows == 4 and RK.Layout.Get("actionbars.bar4").x == 600, "reload preserves the player's edits")
			RK.Options.Write("ActionBars", "extraBarsLayout", "off")
			assert(C.DeepEqual(RN.Config("bar4"), before4), "the original snapshot survives reload")
			assert(#reloaded._errors == 0 and #reloaded._blocked == 0, AB.Errors(reloaded))
		end
		K.Options.Write("ActionBars", "extraBarsLayout", "off")
		assert(C.DeepEqual(cfg.bar4, before4) and C.DeepEqual(cfg.bar5, before5), "Off restores every previous bar setting")
		assert(C.DeepEqual(positions, original), "Off restores the raw saved positions exactly")
	end
	local width = ns.bars.bar4.holder:GetWidth()
	env.SetCombat(true)
	K.Options.Write("ActionBars", "extraBarsLayout", "rows")
	K.Options.Write("ActionBars", "extraBarsLayout", "beside")
	assert(cfg.extraBarsApplied == "off" and ns.bars.bar4.holder:GetWidth() == width, "combat keeps the current bars")
	env.SetCombat(false)
	assert(cfg.extraBarsApplied == "beside" and cfg.bar4.buttons == 8, "combat end applies the last request")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "extraBarsLayout", "off")
	assert(cfg.extraBarsApplied == "beside", "Off also waits for combat")
	env.SetCombat(false)
	assert(C.DeepEqual(cfg.bar4, before4), "queued Off restores the original snapshot")
	local chat = env.CreateFrame("Frame", nil, K.Scale.Root())
	chat:SetSize(442, 186)
	K.Layout.Register(chat, "chat.main", K.Setup.Layouts.Default("chat.main"), { module = "Chat" })
	K.Options.Write("ActionBars", "extraBarsLayout", "beside")
	local chatY = K.Layout.Get("chat.main").y
	assert(K.Layout.Set("chat.main", "x", 20))
	assert(K.Layout.Get("chat.main").y == chatY, "editing default chat x keeps its current y")
	K.Options.Write("ActionBars", "extraBarsLayout", "off")
	K.Layout.Update("chat.main", { anchor = "BOTTOMLEFT", x = 18, y = 18 })
	local savedChat = C.DeepCopy(positions["chat.main"])
	K.Options.Write("ActionBars", "extraBarsLayout", "beside")
	assert(C.DeepEqual(positions["chat.main"], savedChat), "D preserves saved chat positions")
	assert(K.Layout.Set("chat.main", "x", 20))
	assert(positions["chat.main"].x == 20 and not positions["medallions:chat.main"], "chat edits keep the usual position scope")
	local x, y, w, h = K.Layout.Rect("actionbars.bar4")
	local cx, cy, cw, ch = K.Layout.Rect("chat.main")
	local pad = K.Setup.Layouts.MEDALLIONS_SLAB.pad
	assert(x + w + pad <= cx or cx + cw <= x - pad or y + h + pad <= cy or cy + ch <= y - pad, "D moves its left bar clear of saved chat")
	K.Options.Write("ActionBars", "extraBarsLayout", "rows")
	K.Options.Write("ActionBars", "extraBarsLayout", "off")
	assert(C.DeepEqual(cfg.bar4, before4) and C.DeepEqual(cfg.bar5, before5), "switching C and D keeps the original restore point")
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2" }) do assert(K.Layout.Set(key, "scale", 0.8)) end
	K.Options.Write("ActionBars", "extraBarsLayout", "rows")
	local hub, lower, upper = ns.Slab.hub, ns.bars.bar1.holder, ns.bars.bar4.holder
	Near(select(2, hub:GetCenter()) * hub:GetEffectiveScale(), (lower:GetBottom() * lower:GetEffectiveScale() + upper:GetTop() * upper:GetEffectiveScale()) / 2, "crest centres across saved scaled rows")
	K.Options.Write("ActionBars", "extraBarsLayout", "off")
	K.Options.Write("HudStyle", "style", "frames")
	assert(not option.showWhen(cfg), "other HUD styles hide this option")
	assert(#env._blocked == 0 and #env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env) .. table.concat(env._blocked, ", "))
	collectgarbage("collect")
end
print("ok extra bar presets: settings, editing, restoration and combat on four screens")
