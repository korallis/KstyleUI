-- qol_parity.lua: the full HUD with every QoL parity round 1 option on, most away from its default (a larger alert size, class colours, a lower crosshair with set lengths and thicknesses, a larger class-coloured ring, a higher durability warning), after a combat round trip and then a party member's death, so the flash line shows the death alert over the talent line; RENDER_QOL_ROUND=2 adds round 2: the character stats (percent and rating, coloured, short labels), the bevelled ring with its centre dot and a trail mid-move, and the cast circle 40% into a cast; with RENDER_QOL_OPTIONS=1 the QoL page and its live preview.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Q = dofile("Tools/regression/qol_env.lua")

local ON = {
	alertSize = 40, combatAlert = true, combatLeaveClass = true, talentAlert = true, talentClass = true, deathAlert = true, deathSound = "ready",
	durabilityAlert = true, durabilityPercent = 50, durabilityY = 290, durabilityThrown = false,
	crosshair = "normal", crosshairHLength = 60, crosshairVLength = 60, crosshairHWidth = 3, crosshairVWidth = 3, crosshairBorder = 1, crosshairY = -24,
	cursorRing = true, cursorScale = 125, cursorOpacity = 90, cursorClass = true,
	hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = "all", skipCinematics = true, skipMode = "both",
}
local ROUND2 = {
	stats = true, statsValue = "both", statsColored = true, statsShort = true, cursorTexture = "ringBevel", cursorDot = true, cursorTrail = true, castRing = true,
}
local round2 = os.getenv("RENDER_QOL_ROUND") == "2"

local function Stats(e)
	e.UnitStat = function(_, i) return 120, 120 + 31 * i, 0, 0 end
	e.GetCritChance, e.GetSpellCritChance, e.GetMeleeHaste = function() return 18.42 end, function() return 14.07 end, function() return 6.25 end
	e.GetSpellBonusDamage, e.GetSpellBonusHealing, e.UnitArmor = function() return 412 end, function() return 455 end, function() return 2100, 2380 end
	e.GetCombatRating = function(i) return 40 + 13 * i end
	e.CR_CRIT_MELEE, e.CR_CRIT_SPELL, e.CR_HASTE_MELEE = 9, 11, 18
	e.UnitCastingInfo = function() return "Lightning Bolt", "Lightning Bolt", 136048, 99000, 101500 end
end

return Common.Run(function()
	local options = os.getenv("RENDER_QOL_OPTIONS") == "1"
	local env, K, ns = Q.New(Common.ScreenOpts({
		saved = Gallery.Saved({ QoL = {} }),
		setup = function(e)
			Gallery.Setup(e)
			if round2 then Stats(e) end
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	if not K.Modules.IsRunning("QoL") then assert(K.Modules.Enable("QoL")) end
	for key, value in pairs(ON) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	for key, value in pairs(round2 and ROUND2 or {}) do assert(K.Options.Write("QoL", key, value) ~= false, key) end
	if round2 then env.FireEvent("UNIT_SPELLCAST_START", "player") end
	env._unspent, env._durability[5] = true, { 21, 100 }
	env.FireEvent("TRAIT_CONFIG_UPDATED", 1)
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	env.SetCombat(true)
	env.SetCombat(false)
	env._group, env._names.party1, env._dead.party1 = true, "Valerin", true
	env.FireEvent("UNIT_HEALTH", "party1")
	local root = K.Scale.Root()
	env._cursor = { root:GetWidth() * (options and 0.85 or 0.35) * root:GetEffectiveScale(), root:GetHeight() * 0.68 * root:GetEffectiveScale() }
	local _, ring = ns.AidFrames()
	if round2 then
		local x, y = env._cursor[1], env._cursor[2]
		env._cursor = { x - 90, y - 50 }
		ring:GetScript("OnUpdate")(ring, 0)
		for i = 1, 3 do
			env._cursor = { x - 90 + 30 * i, y - 50 + 16 * i }
			ring:GetScript("OnUpdate")(ring, 0)
		end
	end
	ring:GetScript("OnUpdate")(ring, 0)
	ring:SetScript("OnUpdate", nil) -- the pointer stands still for the picture, and Settle waits for every OnUpdate to stop
	env.RunTimers()
	O.W.Settle(env)
	if options then
		assert(K.Options.Open("QoL"))
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		assert(K.Layout.Set("Options.Window", "width", 1240))
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		env._addons.KstyleUI_Options.Window.Jump({ page = "QoL", module = "QoL", key = os.getenv("RENDER_QOL_KEY") or "combatAlert" })
		env.RunTimers()
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	if not options then
		scene = Common.Scene.Merge({ Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS" }), scene })
	end
	scene.log[#scene.log + 1] = "qol parity: round " .. (round2 and "1 and 2" or "1") .. " options " .. (options and "page" or "on over the HUD")
	return scene
end)
