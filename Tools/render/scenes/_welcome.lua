-- _welcome.lua: Chrome draws the pixel-identical PNG companion of the client's TGA welcome logo.
return function(scene)
	for _, item in ipairs(scene.items) do
		if item.file == "Media/Logo/Logo256.tga" then
			item.file = "Media/Logo/Logo256.png"
		end
	end
	return scene
end
