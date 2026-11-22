-- parity_combat_options.lua: the real scoped Options page and its live preview, selected with RENDER_PARITY_MODULE; RENDER_PARITY_ENABLED=1 switches on round one's options, 2 the round two options (Auras, Cooldowns), 3 the Meters round two, Auras round three (the missing buff reminder, its sample named Arcane Intellect) or Cooldowns round three options 4 the Cooldowns round four options and 5 the Cooldowns round five custom bar group.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local module = os.getenv("RENDER_PARITY_MODULE") or "Auras"
local files = { Auras = "auras", Cooldowns = "cooldowns", CombatText = "combattext", Meters = "meters", Chat = "chat" }
local keys = { Auras = "count.shown", Cooldowns = "essential.swipe", CombatText = "direction", Meters = "damage.hover", Chat = "tabHeight" }
return Common.Run(function()
 local driver = dofile("Tools/regression/" .. assert(files[module], "unknown module") .. "_env.lua")
 local function setup(e)
  Gallery.Setup(e)
		if module == "CombatText" then
			e.AbbreviateNumbers = function(n) return tostring(n) end
			e.BreakUpLargeNumbers = e.AbbreviateNumbers
		end
  if module == "Cooldowns" then driver.Game(e) end
  if module == "Auras" then
   e.C_Spell = e.C_Spell or {}
   e.C_Spell.GetSpellName = function(id) return id == 1459 and "Arcane Intellect" or nil end
   e.C_Spell.GetSpellTexture = function(id) return id == 1459 and 135932 or nil end
  end
  e.C_AddOns = e.C_AddOns or {}
  e.C_AddOns.LoadAddOn = function(name)
   if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
   return true
  end
 end
 local env, K = driver.New(Common.ScreenOpts({ saved = Gallery.Saved({ module }), setup = setup }))
 local function settle()
  env.RunTimers()
  if module == "CombatText" then Gallery.Ticks(O.W, env, 40) else O.W.Settle(env) end
 end
 if not K.Modules.IsRunning(module) then K.Modules.Enable(module) end
 env.RunTimers()
 local enabled = os.getenv("RENDER_PARITY_ENABLED")
 if enabled == "1" or enabled == "2" or enabled == "3" or enabled == "4" or enabled == "5" then
  local values = {
   Auras2 = { ["extraBuffs.enabled"] = true, ["extraDebuffs.enabled"] = true, ["buffs.glow"] = true, ["debuffs.glow"] = true,
    ["timer.position"] = "TOPRIGHT", ["debuffs.typeIcon"] = "BOTTOM" },
   Auras = { ["buffs.swipe"] = true, ["debuffs.swipe"] = true, ["count.shown"] = false, iconZoom = 0.1, ["timer.x"] = 3,
    ["debuffs.typeIcon"] = "TOPLEFT", ["buffs.refresh"] = true, ["timer.seconds"] = false, ["timer.precise"] = 10, ["buffs.show"] = "cancelable" },
   Cooldowns2 = { path = "mirror", ["utility.numbersOnly"] = true, ["buffs.keepPlace"] = true, ["rules.activeGlow"] = "x", ["rules.timerColour"] = "x", timerSource = "custom",
    timerColor = { r = 1, g = 0.69, b = 0 }, ["rules.decimals"] = "x", decimalBelow = 30, ["bars.fillUp"] = true, ["bars.spark"] = true, ["bars.smooth"] = true, ["bars.nameWrap"] = true, ["bars.decimals"] = true, ["rules.names"] = "x=Haste" },
   Cooldowns = { ["essential.iconZoom"] = 0.2, ["utility.iconZoom"] = 0.2, ["buffs.iconZoom"] = 0.2, ["bars.iconZoom"] = 0.2, ["essential.edge"] = false, ["utility.edge"] = false, ["essential.vertical"] = true, ["essential.timerPosition"] = "TOP", ["utility.countOnly"] = true, glowsInCombat = true, ["buffs.inactiveShade"] = "colour", ["rules.fade"] = "Earth Shock" },
   CombatText = { direction = "down", shadow = "show", combat = true, power = true, fieldDistance = 24, fieldDistanceMedallions = 24 },
   Meters = { ["damage.refresh"] = 0.2, ["damage.hoverSpells"] = 8, ["damage.hideRank"] = true, ["damage.iconZoom"] = 0.2, ["damage.spellTooltips"] = true,
    ["damage.panelAlpha"] = 0.6, ["damage.capAlpha"] = 0.8, ["damage.headerHeight"] = 4, ["damage.titleX"] = 6, ["damage.resetButton"] = true, ["damage.nameScale"] = 0.9,
    ["damage.valueScale"] = 1.1, ["damage.playerMarker"] = true, ["timer.shown"] = true, ["timer.decimal"] = true, ["history.icons"] = true, ["history.bars"] = true },
   Cooldowns3 = { path = "mirror", ["rules.threshold"] = "x", thresholdBelow = 30, ["rules.chargeSwipe"] = "x", ["rules.chargeTimer"] = "x", ["rules.swing"] = "x",
    ["rules.swingGlow"] = "x", textAboveGlow = true, ["essential.rows"] = 2, ["essential.baseCount"] = 3, ["essential.secondSize"] = -6,
    ["utility.hideMissing"] = true, ["utility.trinkets"] = true, focusSpell = "1766", focusReminder = true },
   Cooldowns4 = { path = "mirror", ["essential.keybind"] = true, ["essential.pressMirror"] = true, ["utility.itemQuality"] = true, ["rules.cdBars"] = "x",
    ["bars.hashLines"] = true, ["bars.chargeShade"] = true, ["bars.lineWidth"] = 2 },
   Cooldowns5 = { path = "mirror", ["rules.group"] = "x", ["custom.name"] = "Burst", ["custom.count"] = 1 },
   Auras3 = { ["reminder.enabled"] = true },
   Meters3 = { ["damage2.shown"] = true, ["damage.report"] = true, ["damage.englishUnits"] = false },
  }
  for key, value in pairs(values[enabled == "1" and module or module .. enabled]) do K.Options.Write(module, key, value) end
 end
 assert(K.Options.Open(module))
 settle()
 local ns = env._addons.KstyleUI_Options
 ns.Window.Jump({ page = module, module = module, key = os.getenv("RENDER_OPTIONS_KEY") or keys[module] })
 settle()
 if module == "CombatText" then O.W.Tick(env, 0.5) end
 assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
 return Gallery.Build(env)
end)
