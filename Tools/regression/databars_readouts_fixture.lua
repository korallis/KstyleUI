-- databars_readouts_fixture.lua: the Forever readout APIs with editable values, used by behaviour tests and HUD renders.
return function(env)
	local game = { groups = 2, group = 1, spec = "Elemental", bind = "Stormwind", start = 0, duration = 0,
		guild = true, guildOnline = 17, friends = 4, battle = 3, invites = 2, now = 100, requests = 0,
		currencies = { { name = "Honor", quantity = 1250 }, { name = "Justice", quantity = 350 } } }
	env.GetTime = function() return game.now end
	env.GetNumSpecGroups = function() return game.groups end
	env.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return 262, game.spec end,
		GetActiveSpecGroup = function() return game.group end,
		SetActiveSpecGroup = function(group) assert(not env.InCombatLockdown()); game.group = group end,
	}
	env.GetBindLocation = function() return game.bind end
	env.C_Item = { GetItemCooldown = function() return game.start, game.duration end }
	env.IsInGuild = function() return game.guild end
	env.GetNumGuildMembers = function() return 48, game.guildOnline end
	env.C_GuildInfo = { GuildRoster = function() game.requests = game.requests + 1 end }
	env.C_FriendList = { GetNumOnlineFriends = function() return game.friends end }
	env.BNGetNumFriends = function() return 12, game.battle end
	env.C_Calendar = { GetNumPendingInvites = function() return game.invites end }
	env.C_CurrencyInfo = { GetBackpackCurrencyInfo = function(index) return game.currencies[index] end }
	env.CreateFrame("Button", "TalentMicroButton", env.UIParent)
	return game
end
