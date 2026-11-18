-- test-type-tooltips.lua: tooltip title semantics, reading sizes, quality ink and the original-look switches.
local T = dofile("Tools/regression/tooltips_env.lua")
local env, K, ns = T.New()
assert(K.Modules.Enable("Tooltips"))
local S = ns.Settings
assert(S.Get("title.size") == 13 and S.Get("body.size") == 12 and S.Get("small.size") == 11, "C4: title 13, body 12, caption 11")
assert(S.Get("iconSize") == 44, "C4: the icon is 44 units")
assert(ns.Style.FontSpec("title") == K.Tokens.Font("heading"), "C4: item and quest titles use the heading face")
assert(ns.Style.FontSpec("title", "names") == K.Tokens.Font("names"), "C4: units and spells use the names face")
for quality, token in pairs({ [0] = "poor", [1] = "common", [2] = "uncommon", [5] = "legendary" }) do
	local r, g, b = K.Theme.QualityColor(quality, true)
	local tr, tg, tb = K.Tokens.Color(token)
	assert(T.Near(r, tr) and T.Near(g, tg) and T.Near(b, tb), "C4: use named item quality tokens")
end
K.Options.Write("Tooltips", "hierarchy", false)
assert(S.Get("title.size") == 11 and S.Get("body.size") == 11 and S.Get("small.size") == 9 and S.Get("iconSize") == 50, "C4 off: restore the original sizes")
assert(ns.Style.FontSpec("title") == K.Tokens.Font("body"), "C4 off: restore the Folio body title face")
K.Options.Write("Tooltips", "title.size", 17)
assert(S.Get("title.size") == 17, "C4: preserve an explicit size choice")
assert(#env._errors == 0, tostring(env._errors[1]))
print("test-type-tooltips: semantic titles, reading sizes, quality tokens and original sizes")
