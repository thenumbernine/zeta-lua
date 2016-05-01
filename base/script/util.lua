local vec2 = require 'vec.vec2'

uvs = {
	vec2(0,0),
	vec2(1,0),
	vec2(1,1),
	vec2(0,1),
}

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
