-- test-qol-alerts.lua: quiet error text hides the cooldown, range and resource errors Retail's UI already hides and Forever shows, through UIErrorsFrame's own switch, and gives them back when it stops.
local Q = dofile("Tools/regression/qol_env.lua")

-- Off by default: Forever's error frame shows them all.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	assert(Q.Muted(env) == 0, "nothing is hidden until asked")
end

do
	local env, K = Q.New()
	Q.Enable(env, K)
	Q.Write(env, K, "quietErrors", true)
	assert(Q.Muted(env) == #Q.ERRORS, "every type on Retail's list is hidden, got " .. Q.Muted(env) .. " of " .. #Q.ERRORS)
	assert(env.BLACK_LISTED_MESSAGE_TYPES[Q.QUEST_PROGRESS_INFO] == nil, "other messages still show")

	Q.Write(env, K, "quietErrors", false)
	assert(Q.Muted(env) == 0, "turning it off shows them again")
	assert(env.BLACK_LISTED_MESSAGE_TYPES[Q.ANOTHER_IN_PROGRESS] == true, "the type Forever hides itself stays hidden")

	Q.Write(env, K, "quietErrors", true)
	Q.Disable(env, K)
	assert(Q.Muted(env) == 0, "turning the module off shows them again")
	assert(env.BLACK_LISTED_MESSAGE_TYPES[Q.ANOTHER_IN_PROGRESS] == true, "and Forever's own type stays hidden")
end

-- A type the game already hid before KstyleUI is not shown when KstyleUI stops.
do
	local env, K = Q.New()
	local first = env[Q.ERRORS[1]]
	env.BLACK_LISTED_MESSAGE_TYPES[first] = true
	Q.Enable(env, K)
	Q.Write(env, K, "quietErrors", true)
	Q.Write(env, K, "quietErrors", false)
	assert(env.BLACK_LISTED_MESSAGE_TYPES[first] == true, "a type hidden before stays hidden")
	assert(Q.Muted(env) == 1, "and only that one")
end

-- A client without the switch or a constant: the feature does nothing and raises nothing.
do
	local env, K = Q.New({ setup = function(env)
		env.LE_GAME_ERR_OUT_OF_MANA = nil
	end })
	env.UIErrorsFrame.SetMessageTypeEnabled = nil
	Q.Enable(env, K)
	Q.Write(env, K, "quietErrors", true)
	assert(Q.Muted(env) == 0, "no switch, nothing hidden")
	assert(K.ErrorCount() == 0, "and no error")
end

print("qol alerts ok")
