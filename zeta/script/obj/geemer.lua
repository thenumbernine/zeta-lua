local class = require 'ext.class'
local Enemy = require 'zeta.script.obj.enemy'
local game = require 'base.script.singleton.game'

local Geemer = class(Enemy)

Geemer.color = {.4,.7,.4,1}
Geemer.sprite = 'geemer'

local hidden = false
if hidden then
	Geemer.seq = 'hiding'
end

Geemer.solid = true

Geemer.maxHealth = 1

Geemer.attackDist = 5
Geemer.jumpVel = 11
Geemer.runVel = 7

Geemer.alertDist = 10
Geemer.nextShakeTime = -1
Geemer.shakeEndTime = -1

function Geemer:init(...)
	Geemer.super.init(self, ...)

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
			if not hidden then
				self.angle = math.deg(math.atan2(dir[2], dir[1])) + 90
			end
			self.rotCenter = {.5, .5}
			break
		end
	end

	self.state = self.states.searching

	-- taken from thwomp code
	-- this determines the visible range below the geemer
	do
		local x, y = math.floor(self.pos[1]), math.floor(self.pos[2])
		repeat
			y = y - 1
			local tile = level:getTile(x,y)
			if y < 1 or y > level.size[2] then break end
			if tile and tile.solid then break end
		until y < 1
		y = y + 1
		self.ymin = y - 2	-- leeway?

		y = math.floor(self.pos[2])
		repeat
			y = y + 1
			local tile = level:getTile(x,y)
			if y < 1 or y > level.size[2] then break end
			if tile and tile.solid then break end
		until y > level.size[2]
		y = y - 1
		self.ymax = y
	end
end

Geemer.states = {
	searching = function(self)
	
		if self.jumpBaseVelX then
			self.vel[1] = self.jumpBaseVelX
		end

		self.irritatedAt = nil
		if self.onground or self.stuckPos then 
			for _,player in ipairs(game.players) do
				local delta = player.pos - self.pos
				local len = delta:length()
				
				-- if the player is within their range then attack 
				if len < self.attackDist 
				-- or if the player is directl below them then attack. TODO traceline as well?
				or (math.abs(delta[1]) < 3 and player.pos[2] > self.ymin and player.pos[2] < self.ymax)
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
				if self.avoiding then delta[1] = -delta[1] end
				local len = delta:length()
				setTimeout(math.random() * .4, function()
					self:calcVelForJump(delta)					
				
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
					self.state = self.states.searching
					if hidden then
						self.seq = 'stand'
					end
				end)
				self.state = nil
			elseif self.irritatedAt then
				if not hidden then
					-- shake and let him know you're irritated
					if game.time > self.nextShakeTime then
						self.shakeEndTime = game.time + 1 + math.random()
						self.nextShakeTime = game.time + 3 + 2 * math.random()
					end
				end
			end
		end
	end,
}

function Geemer:update(dt)
	Geemer.super.update(self, dt)
	if self.state then self:state() end
end

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

function Geemer:pretouch(other, side)
	if other:isa(Geemer) then
		self.avoiding = other
		return true
	end
end

local Hero = require 'zeta.script.obj.hero'
function Geemer:touch(other, side)
	if other:isa(Hero) then
		other:takeDamage(1, self, self, side)
	end
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
end

function Geemer:hit(damage, attacker, inflicter, side)
	self:playSound('explode1')
	self.vel = self.vel + (self.pos - inflicter.pos):normalize() * 5
	self.madAt = attacker
end

Geemer.itemDrops = {
	['zeta.script.obj.heart'] = .1,
}

function Geemer:die(damage, attacker, inflicter, side)
	self:playSound('explode1')
	-- spawn item drops
	Geemer.super.die(self, damage, attacker, inflicter, side)
	-- puff of smoke	
	--local Puff = require 'zeta.script.obj.puff'
	--Puff.puffAt(self.pos:unpack())
	local GeemerChunk = require 'zeta.script.obj.geemerchunk'
	GeemerChunk.makeAt{
		pos = self.pos,
		-- should be inflicter.pos, but the shot needs to stop at the surface for that to happen
		dir = (self.pos - attacker.pos):normalize(),
		color = self.color,
	}
	-- get rid of self
	self.remove = true
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
