local game = require 'base.script.singleton.game'

local BreakBlock = behaviors(require 'base.script.obj.object',
	require 'zeta.script.behavior.statemachine')

BreakBlock.useGravity = false
BreakBlock.solidFlags = 0
BreakBlock.touchFlags = 0
BreakBlock.blockFlags = 0
BreakBlock.initialState = 'break'
BreakBlock.drawCenter = {0,0}

function BreakBlock:init(...)
	BreakBlock.super.init(self, ...)
	-- can't set the class sprite if we want to clear it later, so set the object sprite here:
	self.sprite = 'breakblock'
end

BreakBlock.states = {}
BreakBlock.states['break'] = {
	seq = 'stand',
	nextState = 'wait',
	enter = function(self)
		local level = game.level
		local x = math.floor(self.pos[1])
		local y = math.floor(self.pos[2])
		if x < 1 or y < 1 or x > level.size[1] or y > level.size[2] then
			self.remove = true
			return
		end
		local index = (x-1)+level.size[1]*(y-1)
		self.index = index
		self.tileIndex = level.tileMap[index]
		self.fgTileIndex = level.fgTileMap[index]
		
		level.tileMap[index] = 0
		level.fgTileMap[index] = 0
		level:refreshFgTileTexels(x,y,x,y)
	
		local tileType = assert(level.tileTypes[self.tileIndex])
		self.regen = tileType.regen
		self.seqStartTime = game.time
	end,
	leave = function(self)
		self.sprite = nil
		if not self.regen then self.remove = true end
	end,
}

BreakBlock.waitTime = 5
BreakBlock.states.wait = {
	update = function(self)
		if game.time - self.stateStartTime > self.waitTime then
			self:setState'unbreak'
		end
	end,
}

BreakBlock.states.unbreak = {
	enter = function(self)
		self.sprite = 'breakblock'
		self:setSeq('unbreak')
	end,
	update = function(self)
		if self.seqHasFinished then
			local level = game.level
			local index = self.index
			level.tileMap[index] = self.tileIndex
			level.fgTileMap[index] = self.fgTileIndex
			level:refreshFgTileTexels(x,y,x,y)
			self.remove = true
		end
	end
}

return BreakBlock
