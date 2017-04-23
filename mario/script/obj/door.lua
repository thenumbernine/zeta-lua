local class = require 'ext.class'
local GameObject  = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local threads = require 'base.script.singleton.threads'
local vec2 = require 'vec.vec2'

local Door = class(GameObject)

Door.sprite = 'door'
Door.solidFlags = 0
Door.touchFlags = 0
Door.blockFlags = 0
Door.useGravity = false
--Door.canCarryThru = false	-- can we carry objects through this door?
Door.canCarryThru = true	-- can we carry objects through this door?

function Door:init(args)
	Door.super.init(self, args)

	self.dests = table()
	self.destIndex = 1

	-- wait for all objects to be linked before testing what tiles have and what don't have doors on them
	threads:add(function()
		coroutine.yield()
		for i,obj in ipairs(game.objs) do
			if obj ~= self
			and Door.is(obj) 
			and obj.name == self.name 
			then
				print('obj',i,'is a door')
				self.dests:insert(vec2(obj.pos[1], obj.pos[2]))
			end
		end
	end)
end

function Door:playerLook(player)
	if #self.dests == 0 then return end
	local destx, desty = unpack(self.dests[self.destIndex])
	self.destIndex = self.destIndex % #self.dests + 1
	local level = game.level
	destx, desty = destx + level.pos[1], desty + level.pos[2]
	self:playSound('door')
	player:beginWarp()
	setTimeout(.25, player.endWarp, player, destx, desty, self.canCarryThru)
end

return Door
