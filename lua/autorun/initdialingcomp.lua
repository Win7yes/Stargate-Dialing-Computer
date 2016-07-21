//dialingcomputeryes Stuff Loader
for _,file in pairs(file.Find("dialingcomputer/*","LUA")) do
	if SERVER then
		AddCSLuaFile("dialingcomputer/"..file)
	end
	include("dialingcomputer/"..file)
end