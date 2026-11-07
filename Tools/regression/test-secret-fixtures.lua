-- test-secret-fixtures.lua: the secret lint finds each unsafe use of a secret value and accepts the guarded forms.
local Lint = dofile("Tools/regression/secret_lint.lua")

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function findings(source)
	local out = {}
	for _, f in ipairs(Lint(source)) do
		out[#out + 1] = f.line .. " " .. f.kind .. " " .. f.name
	end
	return table.concat(out, "\n")
end

local function expect(source, want)
	local got = findings(source)
	assert(got == want, "\nsource:\n" .. source .. "\ngot:\n" .. got .. "\nwant:\n" .. want)
end

-- The fixtures: bad.lua has one line per kind, and good.lua has none.
local kinds = {}
for _, f in ipairs(Lint(read("Tools/regression/fixtures/secrets/bad.lua"))) do
	kinds[f.kind] = true
end
for _, k in ipairs({ "compare", "arith", "length", "key", "bool", "combatlog" }) do
	assert(kinds[k], "bad.lua: no " .. k .. " finding")
end
expect(
	read("Tools/regression/fixtures/secrets/bad.lua"),
	table.concat({
		"2 compare hp",
		"3 arith power",
		"4 length name",
		"5 key aura",
		"6 bool inRange",
		"7 combatlog COMBAT_LOG_EVENT_UNFILTERED",
	}, "\n")
)
expect(read("Tools/regression/fixtures/secrets/good.lua"), "")

-- A secret compared on the line after it is fetched, through a local.
expect('local hp = UnitHealth("target")\nif hp <= 0 then end', "2 compare hp")
expect('local hp = UnitHealth("target")\nlocal dead = 0 >= hp', "2 compare hp")

-- Secret calls used directly, through select, through an alias, and every C_UnitAuras function.
expect("if UnitHealth(u) > 0 then end\nlocal f = UnitPowerMax(u) * 2", "1 compare UnitHealth\n2 arith UnitPowerMax")
expect("local d = select(4, UnitCastingInfo(u))\nif d == 0 then end", "2 compare d")
expect("local a, b, c, d = UnitChannelInfo(u)\nif d then end", "2 bool d")
expect("local UH = UnitHealth\nif UH(u) < 1 then end", "2 compare UH")
expect("local A = C_UnitAuras\nlocal aura = A.GetPlayerAuraBySpellID(1)\nlocal left = aura.expirationTime - now", "3 arith aura")
expect("if C_UnitAuras.GetAuraDataByIndex(u, 1).duration > 0 then end", "1 compare C_UnitAuras.GetAuraDataByIndex")
expect("local m = UnitHealthMax(u)\nif m > 0 then end", "2 compare m")
expect("local ok, hp = pcall(UnitHealth, u)\nif ok and hp > 0 then end", "2 compare hp")

-- Each kind.
expect("local hp = UnitHealth(u)\nlocal t = { [hp] = true }\nlocal ok = not hp\nlocal v = hp and 1\nwhile hp do end", "2 key hp\n3 bool hp\n4 bool hp\n5 bool hp")
expect("local hp = UnitHealth(u)\nlocal pct = -hp\nlocal s = hp % 2\nlocal p = 2 ^ hp", "2 arith hp\n3 arith hp\n4 arith hp")

-- Allowed: widget setters, concatenation, passing on, and an issecretvalue guard earlier on the
-- line, in the enclosing if, or as an early return.
expect("local hp = UnitHealth(u)\nbar:SetValue(hp)\ntext:SetText('HP ' .. hp)\nlocal copy = { hp }", "")
expect("local hp = UnitHealth(u)\nlocal low = not issecretvalue(hp) and hp < 10", "")
expect("local hp = UnitHealth(u)\nif not issecretvalue(hp) then\n\tif hp < 10 then end\nend", "")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then\n\treturn\nend\nif hp < 10 then end", "")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then\n\thp = 0\nend\nif hp < 10 then end", "")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then\n\tbar:SetValue(hp)\nelseif hp < 10 then\nelse\n\tlocal x = hp + 1\nend", "")

-- Not allowed: the guard on the wrong side, after the use, in a function that has ended, or
-- joined with and.
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then\n\tif hp < 10 then end\nend", "3 compare hp")
expect("local hp = UnitHealth(u)\nif hp < 10 and not issecretvalue(hp) then end", "2 compare hp")
expect("local hp = UnitHealth(u)\nlocal function f() if issecretvalue(hp) then return end end\nif hp < 10 then end", "3 compare hp")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) and x then return end\nif hp < 10 then end", "3 compare hp")
expect("local hp = UnitHealth(u)\nif not issecretvalue(hp) then\nelse\n\tlocal y = hp * 2\nend", "4 arith hp")
expect("local hp = UnitHealth(u)\nif not (issecretvalue(hp)) then\nelse\n\tlocal y = hp * 2\nend", "4 arith hp")
expect("local hp = UnitHealth(u)\nif not (issecretvalue(hp)) then return end\nif hp < 10 then end", "3 compare hp")

-- A guard holds only when it covers every secret case, names the exact path, and the value has
-- not changed since.
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) and ready then\n\treturn\nelseif hp < 10 then\nend", "4 compare hp")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) and ready then\nelse\n\tlocal y = hp * 2\nend", "4 arith hp")
expect("local hp = UnitHealth(u)\nif not issecretvalue(hp) or ready then\n\tlocal y = hp * 2\nend", "3 arith hp")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then\n\thp = UnitHealth(v)\nend\nif hp < 10 then end", "5 compare hp")
expect("local hp = UnitHealth(u)\nif not issecretvalue(hp) then\n\thp = UnitHealth(v)\n\tlocal n = hp - 1\nend", "4 arith hp")
expect("local aura = C_UnitAuras.GetAuraDataByIndex(u, 1)\nif not issecretvalue(aura.name) then\n\tlocal n = aura.duration - 1\nend", "3 arith aura")
expect("local aura = C_UnitAuras.GetAuraDataByIndex(u, 1)\nif not issecretvalue(aura.duration) then\n\tlocal n = aura.duration - 1\nend", "")
expect("local hp = (UnitHealth(u))\nif hp < 10 then end", "2 compare hp")
expect("if (UnitHealth(u)) < 10 then end\nlocal ok = f(UnitHealth(u)) < 10", "1 compare UnitHealth")

-- A check earlier in the same expression guards a use only through the right operator.
expect("local hp = UnitHealth(u)\nlocal x = issecretvalue(hp) or hp < 10", "")
expect("local hp = UnitHealth(u)\nlocal x = issecretvalue(hp) and hp < 10", "2 compare hp")
expect("local hp = UnitHealth(u)\nif issecretvalue(hp) then x = hp + 1 end", "2 arith hp")
expect("local hp = UnitHealth(u)\nif not issecretvalue(hp)\n\tand hp < 10 then end", "")
expect("local hp = UnitHealth(u)\nlocal t = { hp = UnitHealth(v) }\nif not issecretvalue(hp) then\n\tlocal n = hp - 1\nend", "")

-- Names that are not secret: a local that hides a source, a reassignment, strings and comments.
expect("local function UnitHealth() return 1 end\nif UnitHealth() > 0 then end", "")
expect("local hp = UnitHealth(u)\nhp = 5\nif hp < 10 then end", "")
expect("local s = 'UnitHealth(u) < 1'\n-- COMBAT_LOG_EVENT in a comment\nlocal n = UnitHealthPercent", "")

-- The combat log, in any form.
expect("local info = { CombatLogGetCurrentEventInfo() }\nf:RegisterEvent('COMBAT_LOG_EVENT')", "1 combatlog CombatLogGetCurrentEventInfo\n2 combatlog COMBAT_LOG_EVENT")

print("secret fixtures ok")
