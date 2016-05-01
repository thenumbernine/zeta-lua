local game = require 'base.script.singleton.game'
local Door = require 'mario.script.obj.door'

for _,obj in ipairs(game.objs) do
	if obj:isa(Door) then
		-- let folks carry thru our doors	
		obj.canCarryThru = true
		
		-- [[ all doors have random destinations!
		obj.playerLook = function(self, player)
			self.destIndex = math.random(#self.dests)
			Door.playerLook(self, player)
		end
		--]]
	end
end
