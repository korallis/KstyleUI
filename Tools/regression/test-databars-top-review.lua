-- test-databars-top-review.lua: reviewed migration and default readouts stay safe on upgrade.
local D = dofile("Tools/regression/databars_env.lua")
local failures = {}
local function check(name, fn)
 local ok, err = pcall(fn)
 print(name .. ": " .. (ok and "PASS" or tostring(err)))
 if not ok then failures[#failures + 1] = name end
end
check("moved readout goes to the top once", function()
 for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
  local env, K = D.New({ width = screen[1], height = screen[2], size = "auto", saved = {
   version = 40, profiles = { Default = { DataBars = { enabled = true } } }, layouts = { Default = {
    ["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -40, y = 300, width = 278, height = 12 },
    ["orbs:databars.strip"] = { anchor = "BOTTOM", x = 37, y = 80, width = 500, height = 22 },
   } },
  } })
  local position = K.Layout.Get("databars.strip")
  local dock = K.Setup.Layouts.DataBarDock()
  assert(position.anchor == dock.anchor and position.x == dock.x and position.y == dock.y, "reset the migrated readout to the dock under the XP bar")
  assert(position.width == dock.width and position.height == dock.height)
  local layout = env.KstyleUIDB.layouts.Default
  assert(layout["medallions:databars.strip"].y == 300, "retain the Medallions rail")
  assert(not layout["orbs:databars.strip"], "reset the moved Orbs rail too")
  local count = 0
  for _, message in ipairs(env._printed) do
   if message == "KstyleUI: the data strip is now a top bar; move it in Layout Mode." then count = count + 1 end
  end
  assert(count == 1, "announce the moved readout once")
  local again = D.New({ saved = D.CoreEnv.DeepCopy(env.KstyleUIDB) })
  for _, message in ipairs(again._printed) do assert(not message:find("the data strip is now a top bar", 1, true), "do not repeat the notice on reload") end
 end
end)
check("disabled module stays off", function()
 local _, K = D.New({ enable = false, saved = { version = 40, profiles = { Default = { DataBars = { enabled = false } } } } })
 assert(K.Store.Module("DataBars").enabled == false and not K.Modules.IsEnabled("DataBars"), "respect the player's disabled DataBars module")
end)
check("all five readouts default on", function()
 local _, K, ns = D.New()
 assert(table.concat(ns.Strip.order, ",") == "fps,latency,gold,durability,time", "enable durability and time by default")
 assert(K.Store.Defaults("DataBars").strip.dockModules[4].id == "durability" and K.Store.Defaults("DataBars").strip.dockModules[5].id == "time")
end)
assert(#failures == 0, table.concat(failures, "; "))
print("databars review ok")
