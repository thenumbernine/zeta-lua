local game = require 'base.script.singleton.game'
local Player = require 'base.script.obj.player'

local Shell = behaviors(
	require 'base.script.obj.object',
--	require 'zeta.script.behavior.takesdamage',
--	require 'zeta.script.behavior.hurtstotouch',
	require 'mario.script.behavior.kickable')

Shell.sprite = 'shell'
Shell.seq = 'stand'
Shell.speed = 10
Shell.dir = 0
Shell.spinJumpDestroys = true
Shell.touchDamage = 1
Shell.maxHealth = 10

function Shell:update(dt)
	local level = game.level
	Shell.super.update(self, dt)
	
	if self.dead then return end
	
	if not self.heldby then
		--self.canCarry = self.dir == 0
		
		-- special for koopas
		if self.enterShellTime then
			if self.dir ~= 0 then
				self.enterShellTime = game.time
			else
				if self.enterShellTime + 10 < game.time then
					if self.heldby then
						self.heldby:setHeld(nil, false)
					end
				
					-- TODO keep track of what type we started as
					local Koopa = require 'mario.script.obj.koopa'	-- no require loops
					setmetatable(self, Koopa)
					--self.canCarry = false
					self.seq = nil
					self.dir = 1
					self.drawMirror = false
					return
				end
			end
		end
		if self.dir ~= 0 then
			self.vel[1] = self.dir * self.speed
		end
	end
end

function Shell:canBeHeldBy(player)
	return self.dir == 0
end

--[[
smw shell state:

if a player touches a shell then
	if the shell isn't in kick mode then
		if the player is holding grab then
			grab the shell.  make the player invincible to the shell
		else
			kick the shell.  make the player momentarily invincible to the shell
if a shell is being held and touches something then
	kill the shell and the thing
if a shell touches something when the shell has nonzero velocity
	then kill that other thing
--]]

function Shell:touch(other, side)
	if Shell.super.touch(self, other, side) then return true end
	
	if not self.heldby then
		if self.dir == 0 then -- stationary
			if Player.is(other) then
				local dx = other.pos[1] - self.pos[1]
				if dx < 0 then
					self.dir = 1
				else
					self.dir = -1
				end

				self.kickedBy = other
				self.kickHandicapTime = game.time + .5
			else	-- stationary/drop/throw collision
				if self.vel[1] ~= 0 then
					if other.hitByShell then
						other:hitByShell(self)
						self:playSound('kick')
					end
				end
			end
		else -- the shell is kicked and moving
			-- be generous to the player -- let him bounce
			if Player.is(other) and other.pos[2] > self.pos[2] then 
				return false
			end	
			-- moving collision
			if self.vel[1] ~= 0 then
				if other.hitByShell then
					other:hitByShell(self)
					self:playSound('kick')
				end
			end
			return true
		end
	else -- hold a shell and walk into an object
		if other.hitByShell 
		and other ~= self.heldby 
		then
			other:hitByShell(self)
			self:playSound('kick')
			self:die()
		end
		return true
	end
end

function Shell:touchTile(tileType, side, normal, x, y)
	if not self.heldby and self.dir ~= 0 then
		if tileType and tileType.solid and tileType.onHit then
			tileType:onHit(self, x, y)
		end
		if side == 'right' then
			self.dir = -1
			self.drawMirror = true
		elseif side == 'left' then
			self.dir = 1
			self.drawMirror = false
		end
	end
end

function Shell:takeDamage(damage, attacker, inflicter, side)
	self.heldBy = nil
	self:playerKick(attacker, 0, 0)
	Shell.super.takeDamage(self, damage, attacker, inflicter, side)
end

function Shell:playerKick(other, dx, dy)
	if dy == 0 then	-- ordinary kick
		local posDeltaX = other.pos[1] - self.pos[1]
		if posDeltaX < 0 then
			self.dir = 1
		else
			self.dir = -1
		end
	end
	Shell.super.playerKick(self, other, dx, dy)
	--self:hasBeenKicked(other)
end

function Shell:die()
	self.canCarry = false
	
	-- do this first so we can claer our flags later without carry interfering	
	if self.heldby then self.heldby:setHeld(nil) end
	
	-- WalkEnemy:die() ... consider super'ing
	self.solidFlags = 0
	self.touchFlags = 0
	self.blockFlags = 0
	self.drawFlipped = true
	self.vel[1] = 0
	self.vel[2] = 0
	self.dead = true
	self.removeTime = game.time + 1
end

function Shell:hitByShell(other)
	if self.dir ~= 0 and other.die then other:die() end
	self:die()
end

function Shell:playerBounce(other)
	if other == self.kickedBy and self.kickHandicapTime >= game.time then return end

	if self.dir == 0 then
		return self:touch(other, 'up')	-- don't provide a side <=> calculate shell velocity by position delta
	else
		self.dir = 0
		self.vel[1] = 0
	end
end

function Shell:hitByBlast(other) self:die() end

function Shell:draw(R, viewBBox, ...)

	local shaking

	if self.dir ~= 0 then 
		self.seq = 'spin'
	else
		if self.enterShellTime then
			shaking = self.enterShellTime + 9 < game.time
			self.seq = 'eyes'
		else
			self.seq = 'stand'
		end
	end
	
	local shift
	if shaking then
		shift = (math.floor(os.clock() * 32) % 2) * .1
		self.pos[1] = self.pos[1] + shift
	end
	
	Shell.super.draw(self, R, viewBBox, ...)
	
	if shaking then
		self.pos[1] = self.pos[1] - shift
	end
end


return Shell
