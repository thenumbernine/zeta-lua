local game = require 'base.script.singleton.game'

local Thwomp = behaviors(
	require 'base.script.obj.object',
	require 'mario.script.behavior.hurtstotouch')

Thwomp.sprite = 'thwomp'
Thwomp.useGravity = false
Thwomp.bbox = box2(-.9, 0, .9, 1.9)
Thwomp.pushPriority = 10
Thwomp.spinJumpImmune = true
Thwomp.touchDamage = 5

Thwomp.stompDist = 2
Thwomp.readyDist = 4
Thwomp.raiseSpeed = 4	-- 2

function Thwomp:init(args)
	Thwomp.super.init(self, args)
	
	self.pos[1] = self.pos[1] + .5
	self.pos[2] = self.pos[2] - 1
	
	local level = game.level
	local x, y = math.floor(self.pos[1]), math.floor(self.pos[2])
	
	repeat
		y = y - 1
		local tile = level:getTile(x,y)
		if tile and tile.solid then break end
	until y < 1
	y = y + 1
	self.ymin = y - 2	-- leeway?

	repeat
		y = y + 1
		local tile = level:getTile(x,y)
		if tile and tile.solid then break end
	until y > level.size[2]
	y = y - 1
	self.ymax = y
end

function Thwomp:makesMeAngry(other)
	return other.health
end

function Thwomp:update(dt)
	Thwomp.super.update(self, dt)
	
	if self.useGravity then	-- falling?
		-- hit the ground?
		if self.collidedDown then
			self.useGravity = false
			self.vel[2] = self.raiseSpeed
			self.raising = true
			self.seq = 'ready'
			self:playSound'thwomp'
			-- TODO shake screen?
		end
	elseif self.raising then		-- raising?
		if self.collidedUp and not self.touchEntUp then
			self.raising = false
		else
			self.vel[2] = self.raiseSpeed
		end
	else						-- waiting ...
		
		self.seq = nil
		for _,player in ipairs(game.players) do
			if player.pos[2] >= self.ymin and player.pos[2] <= self.ymax then
				local dist = math.abs(player.pos[1] - self.pos[1])
				if dist < self.stompDist then
					self.seq = 'stomp'
					self.useGravity = true
					break
				elseif dist < self.readyDist then
					self.seq = 'ready'
				end
			end
		end
	end
end

function Thwomp:touch(other, side, ...)
	if side == 'down' and self.vel[2] < 0 then
		if other.hit then other:hit(self) end
		--if Thwomp.super.touch then
		--	return Thwomp.super.touch(self, other, side, ...)
		--end
	else
		if Thwomp.super.super.touch then
			Thwomp.super.super.touch(self, other, side, ...)
		end
	end
end

return Thwomp
