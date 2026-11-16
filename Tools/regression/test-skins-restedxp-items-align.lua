-- test-skins-restedxp-items-align.lua: docked Items and Targets have aligned single-row icons and glass feet.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { width = 5120, height = 1440 }, { width = 3456, height = 2234 } }) do
	local R = Boot(screen)
	local function Rect(f) return assert(Geometry.ScaledRect(f, R.env.UIParent, R.K.Scale.Root())) end
	local function Check()
		local items, targets = R.rxp.activeItemFrame, R.rxp.targeting.activeTargetFrame
		local i, t = Rect(R.K.Skin.Parts(items).backdrop), Rect(R.K.Skin.Parts(targets).backdrop)
		local ib, tb = Rect(items.buttonList[1]), Rect(targets.enemyTargetButtons[1])
		local px = R.K.Scale.Pixel(1) + 0.01
		assert(math.abs(ib.top - tb.top) <= px, string.format("Items icons sit low: %.2f root units; align their row with Targets", tb.top - ib.top))
		assert(math.abs(i.top - t.top) <= px and math.abs(i.bottom - t.bottom) <= px, "Items and Targets glass tops and feet align")
	end
	Check()
	R.rxp.UpdateItemFrame(nil, 1)
	R.rxp.targeting:UpdateTargetFrame(1, 0)
	R.settle()
	Check()
	R.env.SetCombat(true)
	R.rxp.UpdateItemFrame(nil, 1)
	R.settle()
	Check()
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end

print("test-skins-restedxp-items-align: ok")
