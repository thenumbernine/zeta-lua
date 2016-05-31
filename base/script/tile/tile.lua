local Tile = class()
function Tile:init(args)
	if args then
		for k,v in pairs(args) do
			self[k] = v
		end
	end
end
return Tile
