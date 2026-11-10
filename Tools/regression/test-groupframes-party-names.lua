local check = dofile("Tools/regression/group_names_env.lua")

check({ { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 } })

print("party names: standard and wide screens ok")
