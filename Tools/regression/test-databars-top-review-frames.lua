-- test-databars-top-review-frames.lua: under the Frames HUD style, reviewed migration and default readouts stay safe on upgrade.
local D = dofile("Tools/regression/frames_lib.lua")(dofile("Tools/regression/databars_env.lua"))
local failures = {}
local function check(name, fn)
 local ok, err = pcall(fn)
 print(name .. ": " .. (ok and "PASS" or tostring(err)))
 if not ok then failures[#failures + 1] = name end
end
check("moved readout goes to the top once", function()
 for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
  local env, K = D.New({ width = screen[1], height = screen[2], size = "auto", saved = {
   version = 40, profiles = { Default = { HudStyle = { style = "frames" }, DataBars = { enabled = true } } }, layouts = { Default = {
    ["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -40, y = 300, width = 278, height = 12 },
   } },
  } })
  local position = K.Layout.Get("databars.strip")
  assert(position.anchor == "TOP" and position.x == 0 and position.y == 0, "reset the migrated readout to the default top placement")
  assert(position.width == K.Layout.RootSize() and position.height == 14)
  local layout = env.KstyleUIDB.layouts.Default
  assert(layout["medallions:databars.strip"].y == 300, "retain the Medallions rail")
  local count = 0
  for _, message in ipairs(env._printed) do
   if message == "KstyleUI: the data strip is now a top bar; move it in Layout Mode." then count = count + 1 end
  end
  assert(count == 1, "announce the moved readout once")
  local again = D.New({ saved = D.CoreEnv.DeepCopy(env.KstyleUIDB) })
  for _, message in ipairs(again._printed) do assert(not message:find("the data strip is now a top bar", 1, true), "do not repeat the notice on reload") end
 end
end)
check("all five readouts default on", function()
 local _, K, ns = D.New()
 assert(table.concat(ns.Strip.order, ",") == "hearth,time,friends,durability,bags,fps,latency,gold", "enable durability and time by default")
 assert(K.Store.Defaults("DataBars").strip.modules[7].id == "durability" and K.Store.Defaults("DataBars").strip.modules[4].id == "time")
end)
assert(#failures == 0, table.concat(failures, "; "))
print("databars review ok")
