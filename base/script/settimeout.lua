-- unlike JS I put the function last ... so its args would go right after it
-- don't call this til after game is initialized
local function setTimeout(delay, func, ...)
	local game = require 'base.script.singleton.game'
	local threads = require 'base.script.singleton.threads'
	return threads:add(function(...)
		local runtime = game.time + delay
		repeat coroutine.yield() until game.time > runtime
		func(...)
	end, ...)
end

return setTimeout
