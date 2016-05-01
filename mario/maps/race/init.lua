local game = require 'base.script.singleton.game'
local Flag = require 'mario.script.obj.flag'
local Puff = require 'mario.script.obj.puff'

-- give the flag a warp hack
for _,obj in ipairs(game.objs) do
	if obj:isa(Flag) then
		-- first person to grab the flag gets warped back to the start!
		obj.playerGrab = function(flag, player)
			Puff.puffAt(unpack(player.pos))
			player.pos:set(unpack(game:getStartPos()))
			flag.playerGrab = nil
		end
	end
end

