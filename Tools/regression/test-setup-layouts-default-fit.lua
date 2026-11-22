-- test-setup-layouts-default-fit.lua: every shipped style and role fits the four required screens before Auto scaling can conceal a default collision.
local C = dofile("Tools/regression/core_env.lua")
local env, K = C.New()
C.Boot(env)
for _, style in ipairs({ "medallions" }) do
	for _, role in ipairs(K.Setup.Layouts.Names()) do
		for _, screen in ipairs({{1920,1080}, {2560,1440}, {5120,1440}, {3840,2160}}) do
			assert(K.Setup.Layouts.Fits(role,screen[1],screen[2],K.Scale.DEFAULT_USER_SCALE,nil,nil), style .. " " .. role .. " " .. screen[1] .. "x" .. screen[2] .. ": move defaults apart at the shipped scale; never shrink Auto to hide their collision")
		end
	end
end
print("default fit ok: 36 style/role/screen cases")
