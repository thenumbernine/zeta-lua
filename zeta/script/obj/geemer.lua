local game = require 'base.script.singleton.game'
local Geemer = behaviors(require 'zeta.script.obj.enemy',
	require 'zeta.script.behavior.statemachine',
	require 'zeta.script.behavior.hurtstotouch'
	,require 'zeta.script.behavior.deathtopieces'
)
Geemer.sprite = 'geemer'
Geemer.maxHealth = 1
Geemer.attackDist = 5
Geemer.jumpVel = 20
Geemer.runVel = 7
Geemer.alertDist = 10
Geemer.nextShakeTime = -1
Geemer.shakeEndTime = -1
Geemer.searchYPaddingDown = 2
Geemer.searchYPaddingUp = 3
Geemer.initialState = 'searching'

-- itemDropOnDeathBehavior
Geemer.itemDrops = {
	['zeta.script.obj.healthitem'] = .1,
	['zeta.script.obj.cellitem'] = .1,
	['zeta.script.obj.grenadeitem'] = .1,
	['zeta.script.obj.missileitem'] = .1,
}
Geemer.deathSound = 'explode1'

function Geemer:init(args)
	Geemer.super.init(self, args)
	
	if self.hidden then
		self.seq = 'hiding'
	end

	-- see if there's a block near us
	-- if so, stick to that block
	local level = game.level
	for side,dir in pairs(dirs) do
		local pos = self.pos + dir
		local tile = level:getTile(pos:unpack())
		if tile and tile.solid then
			self.stuckPos = pos
			self.stuckSide = side
			self.useGravity = false
			if not self.hidden then
				self.angle = math.deg(math.atan2(dir[2], dir[1])) + 90
			end
			self.rotCenter = {.5, .5}
			break
		end
	end

	-- taken from thwomp code
	-- this determines the visible range below the geemer
	do
		local x = math.floor(self.pos[1])
		local y = math.floor(self.pos[2]) + 1
		repeat
			y = y - 1
			local tile = level:getTile(x,y)
			if y < 1 or y > level.size[2] then break end
			if tile and tile.solid then break end
		until y < 1
		self.ymin = y - self.searchYPaddingDown
		
		y = math.floor(self.pos[2]) - 1
		repeat
			y = y + 1
			local tile = level:getTile(x,y)
			if y < 1 or y > level.size[2] then break end
			if tile and tile.solid then break end
		until y > level.size[2]
		self.ymax = y + self.searchYPaddingUp
	end
end

Geemer.states = {
	searching = {
		update = function(self)
	
			if self.jumpBaseVelX then
				self.vel[1] = self.jumpBaseVelX
			end

			self.irritatedAt = nil
			if self.onground or self.stuckPos then 
				for _,player in ipairs(game.players) do
					local delta = player.pos - self.pos
					local len = delta:length()
					
					-- if the player is within their range then attack 
					if math.abs(delta[1]) < self.attackDist
					and player.pos[2] > self.ymin
					and player.pos[2] < self.ymax
					then
						self.madAt = player 
						break
					elseif len < self.alertDist then
						self.irritatedAt = player
					end
				end
			
				-- if something made us angry
				if self.madAt
				-- if we're looking for free space
				or self.avoiding
				then
					local delta = (self.madAt or self.avoiding).pos - self.pos
					local len = delta:length()
					
					self:setState('waitingToJump', delta)
				elseif self.irritatedAt then
					-- shake and let him know you're irritated
					if game.time > self.nextShakeTime then
						self.shakeEndTime = game.time + 1 + math.random()
						self.nextShakeTime = game.time + 3 + 2 * math.random()
					end
				end
			end
		end,
	},
	waitingToJump = {
		enter = function(self, delta)
			self.jumpingEndStateTime = game.time + math.random() * .5
			self.madDelta = delta
		end,
		update = function(self, dt)
			if game.time < self.jumpingEndStateTime then return end
			
			self:calcVelForJump(self.madDelta)					
		
			-- if we're on a wall then don't jump into the wa
			if (self.vel[1] > 0 and self.stuckSide == 'right')
			or (self.vel[1] < 0 and self.stuckSide == 'left')
			then
				self.vel[1] = -self.vel[1]
			end
			self.jumpBaseVelX = self.vel[1]

			--self.madAt = nil
			self.avoiding = nil
			self.angle = nil
			self.useGravity = true
			self.stuckPos = nil
			self.stuckSide = nil
			self:setState'jumping'
			self.seq = nil	-- clear hidden seq if you got it
		end,
	},
	jumping = {
		update = function(self, dt)
			if self.onground then self:setState'searching' end
			self.vel[1] = self.jumpBaseVelX
		end,
	},
}

function Geemer:calcVelForJump(delta)
	-- delta is the vector from our target to ourselves
	local avoiding = not self.madAt and self.avoiding
	local jumpVel = avoiding and 5 or self.jumpVel
	local runVel = avoiding and 3 or self.runVel
	runVel = runVel * (math.random() * .3 + .7)
	jumpVel = jumpVel * (math.random() * .2 + .8)
	if delta[1] < 0 then runVel = -runVel end

	-- jump at player
	self.vel[1] = runVel
	self.vel[2] = jumpVel
end

-- hmm... solid_no with geemers lets them pass through eachother
-- but thye collide when they hit hte player and the player can't get rid of them 
-- solid_yes doesn't,
-- but that mobs the player and the player gets stuck
Geemer.solidFlags = Geemer.SOLID_YES	-- Geemer.SOLID_NO
Geemer.touchFlags = Geemer.SOLID_YES
Geemer.blockFlags = Geemer.SOLID_WORLD + Geemer.SOLID_YES
Geemer.touchDamage = 1

function Geemer:touch(other, side)
	-- this makes collision run incredibly slow in crowds
	-- give this its own flags?
	-- make it non-solid?
	if other:isa(Geemer) then
		self.avoiding = other
		return true
	end

	return Geemer.super.touch(self, other, side)
end

function Geemer:draw(R, viewBBox, ...)
	local ofs = 0
	if game.time < self.shakeEndTime then
		ofs = 1/16 * math.sin(game.time * 100)
		self.pos[1] = self.pos[1] + ofs
	end
	Geemer.super.draw(self, R, viewBBox, ...)
	if game.time < self.shakeEndTime then
		self.pos[1] = self.pos[1] - ofs
	end

--[[ debug draw
	local gl = R.gl
	gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
	gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
	R:quad(
		self.spawnInfo.pos[1] - self.attackDist,
		self.ymin,
		2 * self.attackDist,
		self.ymax - self.ymin,
		0,0,
		1,1,
		0,
		1,0,0,1)
	gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
--]]
end

function Geemer:hit(damage, attacker, inflicter, side)
	Geemer.super.hit(self, damage, attacker, inflicter, side)
	self.vel = self.vel + (self.pos - inflicter.pos):normalize() * 5
	self.madAt = attacker
end

function Geemer:die(damage, attacker, inflicter, side)
	-- spawn item drops, remove self, sound explosion
	Geemer.super.die(self, damage, attacker, inflicter, side)
	
	-- piss off the geemers around you
	for _,other in ipairs(game.objs) do
		if other:isa(Geemer) then
			local delta = other.pos - self.pos
			if delta:length() < 2.5 then
				other.madAt = attacker
			end
		end
	end
end

return Geemer
