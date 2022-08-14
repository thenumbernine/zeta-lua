-- TODO global namespace?  vec2 box2 ext?
-- TODO use ffi vec2's with x and y fields?
local class = require 'ext.class'
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
	return threads:add(function(...)
		local runtime = game.time + delay
		repeat coroutine.yield() until game.time > runtime
		func(...)
	end, ...)
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

-- accepts parentClass, behavior1, behavior2, ...
-- applies them, in order
function behaviors(baseClass, ...)
	local classObj = baseClass
	for i=1,select('#', ...) do
		local behavior = select(i, ...)
		classObj = behavior(classObj)
	end
	return class(classObj)
end
