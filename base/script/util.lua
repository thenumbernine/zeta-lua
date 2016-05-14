local vec2 = require 'vec.vec2'

dirs = {
	up = vec2(0,1),
	down = vec2(0,-1),
	left = vec2(-1,0),
	right = vec2(1,0),
}

oppositeSide = {
	up = 'down',
	down = 'up',
	left = 'right',
	right = 'left',
}

-- unlike JS I put the function last ... so its args would go right after it
-- don't call this til after game is initialized
function setTimeout(delay, func, ...)
	local game = require 'base.script.singleton.game'
	local threads = require 'base.script.singleton.threads'
	local args = {...}
	return threads:add(function()
		local runtime = game.time + delay
		repeat coroutine.yield() until game.time > runtime
		func(unpack(args))
	end)
end

-- helper, same as require, but verifies spawnTypeStr is valid 
function create(spawnTypeStr)
	local game = require 'base.script.singleton.game'
	if not game.levelcfg.spawnTypes:find(nil, function(spawnType)
		return spawnType.spawn == spawnTypeStr
	end) then 
		error("failed to find spawntype "..spawnTypeStr)
	end
	return require(spawnTypeStr)
end
