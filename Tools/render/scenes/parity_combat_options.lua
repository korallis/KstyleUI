-- parity_combat_options.lua: the real scoped Options page and its live preview, selected with RENDER_PARITY_MODULE.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local module = os.getenv("RENDER_PARITY_MODULE") or "Auras"
local files = { Auras = "auras", Cooldowns = "cooldowns", CombatText = "combattext", Meters = "meters" }
local keys = { Auras = "count.shown", Cooldowns = "essential.swipe", CombatText = "direction", Meters = "damage.hover" }
return Common.Run(function()
 local driver = dofile("Tools/regression/" .. assert(files[module], "unknown module") .. "_env.lua")
 local function setup(e)
  Gallery.Setup(e)
		if module == "CombatText" then
			e.AbbreviateNumbers = function(n) return tostring(n) end
			e.BreakUpLargeNumbers = e.AbbreviateNumbers
		end
  if module == "Cooldowns" then driver.Game(e) end
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
 if os.getenv("RENDER_PARITY_ENABLED") == "1" then
  local values = {
   Auras = { ["buffs.swipe"] = true, ["debuffs.swipe"] = true, ["count.shown"] = false, iconZoom = 0.1, ["timer.x"] = 3,
    ["debuffs.typeIcon"] = "TOPLEFT", ["buffs.refresh"] = true, ["timer.seconds"] = false, ["timer.precise"] = 10, ["buffs.show"] = "cancelable" },
   Cooldowns = { ["essential.iconZoom"] = 0.2, ["utility.iconZoom"] = 0.2, ["buffs.iconZoom"] = 0.2, ["bars.iconZoom"] = 0.2, ["essential.edge"] = false, ["utility.edge"] = false },
   CombatText = { direction = "down", shadow = "show", combat = true, power = true, fieldDistance = 24 },
   Meters = { ["damage.refresh"] = 0.2, ["damage.hoverSpells"] = 8, ["damage.hideRank"] = true, ["damage.iconZoom"] = 0.2, ["damage.spellTooltips"] = true },
  }
  for key, value in pairs(values[module]) do K.Options.Write(module, key, value) end
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
