-- Module.lua: registers the UnitFrames module, its settings page and its smoke check with the core.
local _, ns = ...

local K = KstyleUI
local Settings, Frames, Preview = ns.Settings, ns.Frames, ns.Preview

K.Modules.Register({
	name = Settings.MODULE,
	defaults = Settings.defaults,
	Enable = function()
		Frames.Enable()
	end,
	Disable = function()
		Frames.Disable()
	end,
})

local schema = Settings.Schema()
schema.preview = Preview.Build
K.Options.Register(Settings.MODULE, schema)

K.DevTest.AddCheck("UnitFrames", function()
	if not K.Modules.IsEnabled(Settings.MODULE) then
		return true, "switched off"
	end
	local built, missing = 0, {}
	for _, kind in ipairs(Settings.KINDS) do
		local uf = Frames.Get(kind)
		if uf then
			built = built + 1
		else
			missing[#missing + 1] = kind
		end
	end
	if #missing > 0 then
		return false, "frames not built: " .. table.concat(missing, ", ")
	end
	local apis = {}
	for _, name in ipairs({ "RegisterUnitWatch", "UnitHealthPercent", "AbbreviateNumbers", "CreateUnitHealPredictionCalculator", "SetPortraitTexture" }) do
		if _G[name] == nil then
			apis[#apis + 1] = name
		end
	end
	if #apis > 0 then
		return false, built .. " frames built; missing APIs: " .. table.concat(apis, ", ")
	end
	return true, built .. " frames built"
end)
