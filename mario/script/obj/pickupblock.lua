local SpinParticle = require 'mario.script.obj.spinparticle'
local game = require 'base.script.singleton.game'
local Mario = require 'mario.script.obj.mario'
local behaviors = require 'base.script.behaviors'

--[[
up + release Y : kick up
down + release Y : drop in front of you
release Y : drop in front of you
left/right + release Y : kick like a shell, but break rather than bounce
--]]

local PickUpBlock = behaviors(require 'base.script.obj.object',
	require 'mario.script.behavior.kickable')

PickUpBlock.solidFlags = PickUpBlock.SOLID_YES
PickUpBlock.sprite = 'pickupblock'
PickUpBlock.seq = 'pickedup'
PickUpBlock.speed = 10	-- when kicked
PickUpBlock.dir = 0	-- kick dir.  parallels shell.

-- all these .7 bbox's are only to fix the run-up-slopes physics issues ...
PickUpBlock.bbox = box2(-.35, 0, .35, .7)

function PickUpBlock:init(args, ...)
	PickUpBlock.super.init(self, args, ...)
	
	self.dieTime = game.time + 8
end

-- TODO like shells, blocks will hit player during the first few frames ...
function PickUpBlock:kick(other, dx)
	if dx < 0 then self.dir = -1 else self.dir = 1 end
	--self.canCarry = false
	self:hasBeenKicked(other)
end

function PickUpBlock:touch(other, side, ...)
	if PickUpBlock.super.touch(self, other, side, ...) then return true end
	
	if not self.heldby then
		if self.dir == 0 then 
			if Mario:isa(other) then
				local dx = self.pos[1] - other.pos[1]
				self:kick(other, dx)
			else
				if self.vel[1] ~= 0 then
					if other.hitByShell then
						other:hitByShell(self)
					end
				end
			end
		else
			if self.vel[1] ~= 0 then
				if other.hitByShell then
				
					-- it's not really a shell...
					local result
					if other.hitByShell then
						other:hitByShell(self)
						result = true			-- don't stop!
					end
					if other.solid then
						self:die()
					end
					return result
				end
			end
		end
	else
		if other.hitByShell then
			other:hitByShell(self)
			return true
		end
	end
end

function PickUpBlock:touchTile(tileType, side, normal, x, y)
	-- matches shell
	if not self.heldby
	and ((self.dir ~= 0 and math.floor(self.pos[2]) == y) or side == 'up')
	then
		if tileType and tileType.solid and tileType.onHit then
			tileType:onHit(self, x, y)
			self:die()
		end
	end
end

-- have player drop the object even if they're not holding down?
function PickUpBlock:playerKick(other, dx, dy)
	PickUpBlock.super.playerKick(self, other, dx, dy)
	if dy == 0 and dx ~= 0 then
		self:kick(other, dx)
	end
end

function PickUpBlock:update(...)
	local level = game.level

	if self.dir ~= 0 then

		-- TODO alot like Shell ... though Shell is messy too
		-- half this should go in touch(), and touch() should get a worldTouch() function ...

		self.vel[1] = self.speed * self.dir

		local didhit = false
		if self.collidedLeft and not self.touchEntLeft then	-- world collision
			local x = math.floor(self.pos[1] + self.bbox.min[1] - .5 - level.pos[2])
			for y=math.floor(self.pos[2] + self.bbox.min[2] - level.pos[1]),math.floor(self.pos[2] + self.bbox.max[2] - level.pos[1]) do
				local tile = level:getTile(x,y)
				if tile and tile.solid then
					if tile.onHit then tile:onHit(self, x, y) end
					didhit = true
					break
				end
			end
			
		elseif self.collidedRight and not self.touchEntRight then
			local x = math.floor(self.pos[1] + self.bbox.max[1] + .5 - level.pos[1])
			for y=math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]),math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
				local tile = level:getTile(x,y)
				if tile and tile.solid then
					if tile.onHit then tile:onHit(self, x, y) end
					didhit = true
					break
				end
			end
		end
				
		if didhit then
			self:die()
			return
		end
	else
		if self.dieTime < game.time then
			self.remove = true
			-- TODO poof
		elseif self.dieTime - 2 < game.time then
			self.seq = 'almostgone'
		end
	end
	
	PickUpBlock.super.update(self, ...)
end

function PickUpBlock:die()
	SpinParticle.breakAt(self.pos[1], self.pos[2] + .5)
	self.remove = true
end

return PickUpBlock
