-- test-setup-editmode-medallions.lua: under Medallions, Apply's Edit Mode writer measures each Medallions surface at the size the style gives it, so Blizzard's tracked buff bars take their own slot above the player's medallion instead of climbing over the focus into the nameplates, and the buff icons stay at the essential row's left end when the player's cast bar hangs under the slab (KSTY-97's warlock render, LEE-1535).
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local VIEWER, BUFF_ICON, BUFF_BAR = EditModeFake.VIEWER, EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR
local Find, Named = EditModeFake.Find, EditModeFake.Named

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.6
end

local function Overlaps(a, b)
	return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
end

local SCREENS = {
	{ label = "1920x1080", width = 1920, height = 1080, uiScale = 768 / 1080, size = "default" },
	{ label = "2383x1540", width = 2383, height = 1540, uiScale = 768 / 1080, size = "default" },
	{ label = "5120x1440", width = 5120, height = 1440, uiScale = 768 / 1080, size = "default" },
}

local checked = 0
for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs(SCREENS) do
		local state = { saved = {}, active = 1 }
		local opts = { boot = false, setup = function(env) EditModeFake.Install(env, state) end }
		for key, value in pairs(screen) do
			opts[key] = value
		end
		local env, K = W.New(opts)
		CoreEnv.Boot(env)
		K.Setup.EditMode.CountTracked(function(group)
			return ({ buffs = 5, bars = 2 })[group]
		end)
		assert(K.Setup.Apply({ layout = name, modules = {}, hudStyle = "medallions" }), "Apply " .. name .. " under Medallions")
		assert(K.HudStyle.Current() == "medallions", "the style is Medallions")
		local Layouts = K.Setup.Layouts
		local rw, rh = K.Layout.RootSize()
		local positions = Layouts.Positions(name, "medallions", K.Scale.Aspect(), K.Scale.Band())
		local function Box(key)
			local w, h, offsetX = Layouts.Footprint(name, key)
			local styled = Layouts.Style("medallions", name, key)
			if styled and styled.width then
				w, h, offsetX = styled.width, styled.height, nil
			end
			return { Layouts.Rect({ width = w, height = h, offsetX = offsetX }, positions[key], rw, rh) }
		end
		local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
		local origin = K.Scale.Origin()
		local layout = Named(state, "KstyleUI " .. name)
		local icon, bar = Find(layout, VIEWER, BUFF_ICON), Find(layout, VIEWER, BUFF_BAR)
		local iconBox, barBox = { EditModeFake.ViewerRect(icon, 5, k) }, { EditModeFake.ViewerRect(bar, 2, k, true) }
		for _, box in ipairs({ iconBox, barBox }) do
			box[1], box[3] = box[1] - origin, box[3] - origin
		end
		local where = name .. " at " .. screen.label
		local slot = Box("cooldowns.bars")
		assert(K.Scale.Aspect() ~= "16:9" or bar.anchorInfo.point == "BOTTOMLEFT" and near(bar.anchorInfo.offsetX, slot[1] * k) and near(bar.anchorInfo.offsetY, slot[2] * k),
			string.format("%s: the tracked bars take their own slot at %.1f %.1f, got %.1f %.1f", where, slot[1], slot[2], bar.anchorInfo.offsetX / k, bar.anchorInfo.offsetY / k))
		local focus = Box("unitframes.focus")
		assert(barBox[4] <= focus[2] + 0.5, where .. ": the bars stay under the focus frame, out of the nameplates over it")
		local essential = Box("cooldowns.essential")
		assert(near(iconBox[3], essential[1] - Layouts.GAP) and near(iconBox[2], essential[2]), where .. ": the buff icons stand a cluster gap left of the essential row, on its foot")
		for _, key in ipairs({ "unitframes.player", "unitframes.castbar.player", "unitframes.focus", "unitframes.focustarget", "unitframes.pet", "cooldowns.essential" }) do
			if Layouts.Shown(name, key) ~= false then
				local box = Box(key)
				assert(not Overlaps(iconBox, box), where .. ": the buff icons touch " .. key)
				assert(not Overlaps(barBox, box), where .. ": the tracked bars touch " .. key)
			end
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		checked = checked + 1
	end
end
assert(checked == 9, "three presets at three screens")
print("setup editmode medallions ok")
