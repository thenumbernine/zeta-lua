local function walkEnemyBehavior(parentClass)
	local table = require 'ext.table'
	local game = require 'base.script.singleton.game'
	local behaviors = require 'base.script.behaviors'

	local WalkEnemyTemplate = behaviors(
		parentClass
		, require 'neko.script.behavior.hurtstotouch'
	)

	WalkEnemyTemplate.dir = -1
	WalkEnemyTemplate.drawMirror = true	-- by default, to match initial dir
	WalkEnemyTemplate.speed = 2
	WalkEnemyTemplate.touchDamage = 1

	function WalkEnemyTemplate:init(args)
		args = table(args)
		args.vel = args.vel or {self.speed * self.dir, 0}
		WalkEnemyTemplate.super.init(self, args)
	end

	function WalkEnemyTemplate:update(dt)
		local level = game.level
		
		WalkEnemyTemplate.super.update(self, dt)
		
		if self.dead then return end
	
		local room = level:getRoomAtMapTilePos(level:getMapTilePos(self.pos:unpack()))
		
		if self.turnsAtLedge and self.onground then
			local x = self.pos[1] + self.bbox.min[1] - level.pos[1]
			local y = self.pos[2] - .5 - level.pos[2]
			local tileUnderLeft = level:getTile(x, y)
			local roomUnderLeft = level:getRoomAtMapTilePos(level:getMapTilePos(x, y))
			if not tileUnderLeft 
			or not tileUnderLeft.solid 
			or roomUnderLeft ~= room
			then
				self.dir = 1
				self.drawMirror = false
			end

			local x = self.pos[1] + self.bbox.max[1] - level.pos[1]
			local y = self.pos[2] - .5 - level.pos[2]
			local tileUnderRight = level:getTile(x, y)
			local roomUnderRight = level:getRoomAtMapTilePos(level:getMapTilePos(x, y))
			if not tileUnderRight
			or not tileUnderRight.solid
			or roomUnderRight ~= room
			then
				self.dir = -1
				self.drawMirror = true
			end
		end
		
		if self.collidedLeft then
			self.dir = 1
			self.drawMirror = false
		elseif self.collidedRight then
			self.dir = -1
			self.drawMirror = true
		end
		self.vel[1] = self.speed * self.dir
	end
	
	WalkEnemyTemplate.removeOnDie = false
	function WalkEnemyTemplate:die(damage, attacker, inflicter, side)
		self.drawFlipped = true
		self.vel[1] = 0
		self.vel[2] = 0
		self.seq = 'die'
		self.dead = true
		self.removeTime = game.time + 1
		self.solidFlags = 0	--WalkEnemyTemplate.SOLID_NO
		self.touchFlags = 0
		local superDie = WalkEnemyTemplate.super.die
		if superDie then
			superDie(self, damage, attacker, inflicter, side)
		end
	end

	-- TODO :touch still gets called and does damage to player regardless...
	function WalkEnemyTemplate:playerBounce(other) 
		-- mario-style: insta-kill
		--self:die(other) 
		-- or otherwise ? deal damage?  bounce? do nothing?
		--other:takeDamage(self.damage, self, self, 'up')
	end

	return WalkEnemyTemplate
end
return walkEnemyBehavior
