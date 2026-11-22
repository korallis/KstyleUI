-- test-skins-questcard-lines.lua: Medallions defaults keep the reference quest and the next title, with no partly clipped text.
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")
local getenv = os.getenv
local frame
rawset(os, "getenv", function(key) if key == "RENDER_MINIMAP_FRAME" then return frame end return getenv(key) end)

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	for _, choice in ipairs({ "medallion", "ring", "classic" }) do
		frame = choice
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
		local Hud = dofile("Tools/render/scenes/hud.lua")
		local Reference = dofile("Tools/render/scenes/_reference.lua")
		local _, guide = Hud.Module("restedxp", { layout = "DPS", applyPreset = true })
		local minimap = guide.K.Store.Module("Minimap")
		assert(minimap.enabled and minimap.frame == choice,
			"the rendered guide must share the enabled minimap and frame choice so it reserves the live Crest clearance")
		local scene, ns = Hud.Module("tracker", { layout = "DPS", applyPreset = true, withGuide = true, quests = Reference.STATE.quests })
		local env = Hud.envs[scene]
		local rows, view = ns.Quests.Rows(), ns.Quests.Parts().view
		local _, top, _, height = Scene.Rect(env, view)
		local _, titleTop, _, titleHeight = Scene.Rect(env, rows[2].title)
		local label = choice .. " " .. screen[1] .. "x" .. screen[2]
		assert(rows[2]:IsShown() and titleTop >= top and titleTop + titleHeight <= top + height + 0.01,
			label .. ": give the Medallions quest card the tall column so one whole quest and the next title fit")
		for _, finding in ipairs(Guard.Check(scene)) do
			assert(finding.kind ~= "clipped", label .. ": fit quest text to whole lines above the footer: " .. finding.subject)
		end
		local text
		for _, item in ipairs(scene.items) do
			if item.object == rows[1].title then text = item; break end
		end
		assert(text, "the first quest title is drawn")
		text.clip = { text.rect[1], text.rect[2], text.rect[3], text.rect[4] / 2 }
		local caught = false
		for _, finding in ipairs(Guard.Check(scene)) do
			if finding.kind == "clipped" and finding.object == text.object then caught = true end
		end
		assert(caught, "the render guard must reject a partly clipped quest line even though the card takes the wheel")
		for _ = 1, #Reference.STATE.quests do
			ns.QuestCard.Scroll(1)
			for _, finding in ipairs(Guard.Check(Scene.Build(env))) do
				assert(finding.kind ~= "clipped", label .. ": scrolling must fit quest text to whole lines: " .. finding.subject)
			end
		end
		local K = env.KstyleUI
		assert(K.Layout.Set("skins.quests", "x", -900) and K.Layout.Set("skins.quests", "y", -400))
		K.Store.Module("Minimap").frame = choice == "classic" and "ring" or "classic"
		K.Callbacks.Fire("SettingChanged", "Minimap", "frame")
		env.RunTimers()
		local saved = K.Store.Layout()["skins.quests"]
		local placed = K.Layout.Get("skins.quests")
		assert(saved.x == -900 and saved.y == -400 and placed.x == -900 and placed.y == -400,
			"change Medallions quest defaults only; keep saved quest positions when the minimap frame changes")
	end
end
rawset(os, "getenv", getenv)
rawset(_G, "RENDER_SCREEN", nil)
print("test-skins-questcard-lines: ok (12 frame/screen cases)")
