-- test-cooldowns-parity.lua: every icon lane's swipe and charge switch, buff-bar stacks and fill opacity apply in both paths with unchanged legacy defaults.
local C = dofile("Tools/regression/cooldowns_env.lua")
for _, path in ipairs({ "mirror", "reskin" }) do
 local saved = { version = 4, profiles = { Default = { Cooldowns = { enabled = true, path = path, bars = { height = 20 } } } }, characters = {} }
 local env, K, ns = C.New({ saved = saved, setup = function(e)
  C.Game(e)
  for name, viewer in pairs(e._viewers) do
   if name ~= "BuffBarCooldownViewer" then
    viewer.timerShown = false
    for _, item in ipairs(viewer._items) do
     item.cooldownShowSwipe = false
     item.RefreshSpellCooldownInfo = function(self) self.Cooldown:SetDrawSwipe(self.cooldownShowSwipe) end
     item.SetTimerShown = function(self, shown) self.Cooldown:SetHideCountdownNumbers(not shown) end
     item:RefreshSpellCooldownInfo()
     item:SetTimerShown(viewer.timerShown)
    end
   end
  end
 end })
 env.RunTimers()
 for group, viewer in pairs({ essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer", buffs = "BuffIconCooldownViewer" }) do
  local row = ns.Mirror.Row(group)
  local icon = path == "mirror" and row:Icon(1) or env._viewers[viewer]._items[1]
  local count = path == "mirror" and icon.count or group == "buffs" and icon.Applications.Applications or icon.ChargeCount.Current
  local cooldown = path == "mirror" and icon.cooldown or icon.Cooldown
  assert(count:GetAlpha() == 1 and ns.Settings.current[group].swipe, path .. " keeps the old charge and swipe defaults")
  if path == "reskin" then
   assert(C.W.LastCall(cooldown, "SetDrawSwipe")[1] == false, "default respects Blizzard charge cooldown swipe")
   assert(C.W.LastCall(cooldown, "SetHideCountdownNumbers")[1] == true, "default respects Edit Mode Show timer off")
   icon:SetTimerShown(true)
   assert(C.W.LastCall(cooldown, "SetHideCountdownNumbers")[1] == false, "default respects Edit Mode Show timer on")
   K.Options.Write("Cooldowns", group .. ".timer", false); env.RunTimers()
   icon:SetTimerShown(true)
   assert(C.W.LastCall(cooldown, "SetHideCountdownNumbers")[1] == true, "timer off survives Edit Mode updates")
   K.Options.Write("Cooldowns", group .. ".timer", true); env.RunTimers()
   assert(C.W.LastCall(cooldown, "SetHideCountdownNumbers")[1] == false, "timer default restores Edit Mode setting")
  end
  for _, value in ipairs({ false, true }) do
   K.Options.Write("Cooldowns", group .. ".showCount", value)
   K.Options.Write("Cooldowns", group .. ".swipe", value)
   env.RunTimers()
   assert(count:GetAlpha() == (value and 1 or 0), path .. " applies " .. group .. " charges")
   if path == "reskin" then
    assert(C.W.LastCall(cooldown, "SetDrawSwipe")[1] == false, "re-enabling preserves native charge swipe")
    icon.cooldownShowSwipe = true
    icon:RefreshSpellCooldownInfo()
   end
   assert(C.W.LastCall(cooldown, "SetDrawSwipe")[1] == value, path .. " applies " .. group .. " swipe after native refresh")
   if path == "reskin" then icon.cooldownShowSwipe = false; icon:RefreshSpellCooldownInfo() end
  end
 end
 local bar = path == "mirror" and ns.Mirror.Row("bars"):Bar(1) or env._viewers.BuffBarCooldownViewer._items[1]
 local count = path == "mirror" and bar.count or bar.Icon.Applications
 assert(ns.Settings.current.bars.fillOpacity == 0.15, "v0.2.8 keeps the quiet fill")
 K.Options.Write("Cooldowns", "bars.showCount", false); K.Options.Write("Cooldowns", "bars.fillOpacity", 0.65); env.RunTimers()
 assert(count:GetAlpha() == 0, path .. " hides bar stacks")
 local color = C.W.LastCall(path == "mirror" and bar.status or bar.Bar, "SetStatusBarColor")
 assert(color[4] == 0.65, path .. " applies fill opacity")
 assert(#env._errors == 0 and K.ErrorCount() == 0, path .. " has no errors")
end
print("cooldowns parity ok")
