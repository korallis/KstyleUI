-- test-skins-restedxp-box-click.lua: only movement during a mouse gesture releases RestedXP's docked boxes, across the screen and arrangement matrix.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, arrangement in ipairs({ "centred", "spread" }) do
		local what = string.format("%dx%d %s", screen[1], screen[2], arrangement)
		local rxp
		local env, K, ns = S.New({
			width = screen[1], height = screen[2],
			saved = { version = 39, profiles = {
				Default = { Layout = { arrangement = arrangement }, Skins = { restedXP = { boxes = false } } },
				Other = { Skins = { restedXP = { boxes = false, compose = false } } }, Empty = {},
			}, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
			setup = function(e)
				e._size, e._fitScale = "auto", true
				e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
				Quests.Install(e, Quests.List(3))
				rxp = Fake.Install(e, {})
			end,
			before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
		})
		local function Settle()
			env.RunTimers()
			S.W.Settle(env)
			env.RunTimers()
		end
		local function Rect(frame)
			return assert(Geometry.ScaledRect(K.Skin.Parts(frame).backdrop, env.UIParent, K.Scale.Root()))
		end
		local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
		for name, profile in pairs(env.KstyleUIDB.profiles) do
			assert(profile.Skins.restedXP.boxes == true, what .. ": migration restores docking for profile " .. name)
		end
		assert(env.KstyleUIDB.version == K.Store.DB_VERSION, what .. ": migration reaches the current version")
		assert(env.KstyleUIDB.profiles.Other.Skins.restedXP.compose == false, what .. ": migration preserves other settings")
		local function Docked()
			assert(ns.Skins.Setting("restedXP", "boxes"), what .. ": a stationary click must not disable docking")
			local guide, t, i = Rect(rxp.RXPFrame), Rect(targets), Rect(items)
			local gap, px = K.Tokens.Size("gapSmall"), 2 * K.Scale.Pixel(1) + 0.02
			for _, box in ipairs({ t, i }) do
				assert(math.abs(guide.bottom - box.top - gap) <= px, what .. ": both boxes dock a small gap below the guide")
			end
			assert(math.abs(t.left - guide.left) <= px and math.abs(i.right - guide.right) <= px and math.abs(i.left - t.right - gap) <= px, what .. ": the boxes share the guide's edges and gutter")
			assert(items.savePosition == false and targets.savePosition == false, what .. ": docked positions stay out of RestedXP's saves")
		end
		K.Modules.Enable("Skins")
		S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
		assert(K.Layout.Setting("arrangement") == arrangement, what .. ": the requested arrangement is active")
		rxp.SetStep()
		rxp.targeting:UpdateTargetFrame(1, 0)
		rxp.UpdateItemFrame(nil, 1)
		Settle()
		Docked()
		for _, box in ipairs({ items, targets }) do
			for _, surface in ipairs({ box, box.title }) do
				for _, locked in ipairs({ false, true }) do
					rxp.settings.profile.lockFrames = locked
					local mark = #box._calls
					surface:GetScript("OnMouseDown")(surface, "LeftButton")
					surface:GetScript("OnMouseUp")(surface, "LeftButton")
					Settle()
					Docked()
					for n = mark + 1, #box._calls do
						local method = box._calls[n].method
						assert(method ~= "ClearAllPoints" and method ~= "SetPoint", what .. ": a stationary click does no docking anchor work")
					end
				end
			end
		end
		-- Targeting.lua's UpdateVisuals changes activeTargetScale independently of the rail. The following click
		-- does not move the box, even though its geometry differs from the last docking on a centred ultrawide HUD.
		rxp.settings.profile.activeTargetScale = 1.25
		targets:UpdateVisuals()
		local left, top = targets:GetLeft(), targets:GetTop()
		targets.title:GetScript("OnMouseDown")(targets.title, "LeftButton")
		targets.title:GetScript("OnMouseUp")(targets.title, "LeftButton")
		assert(targets:GetLeft() == left and targets:GetTop() == top, what .. ": the click made no movement")
		assert(ns.Skins.Setting("restedXP", "boxes"), what .. ": RestedXP's scale change followed by a stationary click must not disable docking")
		rxp.SetStep()
		Settle()
		Docked()
		rxp.settings.profile.lockFrames = false
		items:GetScript("OnMouseDown")(items, "LeftButton")
		items:ClearAllPoints()
		items:SetPoint("CENTER", env.UIParent, "CENTER", -300, 40)
		items:GetScript("OnMouseUp")(items, "LeftButton")
		rxp.SetStep()
		Settle()
		assert(ns.Skins.Setting("restedXP", "boxes") == false, what .. ": a real drag releases docking")
		local point = { items:GetPoint(1) }
		assert(point[1] == "CENTER" and point[4] == -300 and point[5] == 40, what .. ": the dragged item box stays where the player put it")
		assert(rxp.settings.profile.framePositions.activeItemFrame[1][4] == -300, what .. ": RestedXP saves the real drag")
		S.W.CoreEnv.Logout(env)
		local _, reloaded = S.New({ saved = env.KstyleUIDB })
		assert(reloaded.Store.Module("Skins").restedXP.boxes == false, what .. ": a drag after migration stays undocked on the next login")
		assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
	end
end

print("skins restedxp box click ok: migration, clicks and saved drags across 8 screen/arrangement combinations")
