-- meters_role.lua: the real role-following party meter; RENDER_ROLE selects TANK or DAMAGER.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local opts = Hud.Options({ layout = "DPS" })
	opts.followRole = true
	opts.role = os.getenv("RENDER_ROLE") or "TANK"
	opts.damage = {
		{ "Valerin", "WARRIOR", 79120 }, { "Leduc", "PALADIN", 42000 },
		{ "Trolly", "PRIEST", 23000 }, { "Lunara", "MAGE", 18500 }, { "Thargor", "ROGUE", 14200 },
	}
	return Hud.Module("meters", opts)
end)
