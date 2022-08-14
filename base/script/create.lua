-- helper, same as require, but verifies spawnTypeStr is valid 
-- used in scripts.

local function create(spawnTypeStr)
	local game = require 'base.script.singleton.game'
	if not game.levelcfg.spawnTypes:find(nil, function(spawnType)
		return spawnType.spawn == spawnTypeStr
	end) then 
		error("failed to find spawntype "..spawnTypeStr)
	end
	return require(spawnTypeStr)
end

return create
