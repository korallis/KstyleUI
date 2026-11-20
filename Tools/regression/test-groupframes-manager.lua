-- test-groupframes-manager.lua: legacy manager flags still follow keepManager through Refresh.
local G = dofile("Tools/regression/group_env.lua")
local saved = { version = 42, profiles = { Default = { GroupFrames = { enabled = true,
	blizzard = { manager = false, keepManager = false } } } }, characters = {}, layouts = {} }
local env, K, ns = G.New({ saved = saved })
env.RunTimers()
print("current.blizzard.manager =", ns.Settings.current.blizzard.manager)
print("raid manager hidden:", K.Safe.IsHidden(env.CompactRaidFrameManager))
assert(ns.Settings.current.blizzard.manager == ns.Settings.Get("blizzard.manager"),
	"Settings.Refresh must resolve blizzard.manager through the keepManager alias")
assert(K.Safe.IsHidden(env.CompactRaidFrameManager), "keepManager=false must hide the legacy raid manager")
K.Options.Write("GroupFrames", "blizzard.keepManager", true)
env.RunTimers()
assert(not ns.Settings.current.blizzard.manager and not K.Safe.IsHidden(env.CompactRaidFrameManager),
	"keepManager=true must restore the raid manager")
assert(#env._errors == 0 and K.ErrorCount() == 0)
print("groupframes manager alias ok")
