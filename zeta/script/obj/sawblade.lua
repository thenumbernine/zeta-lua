local game = require 'base.script.singleton.game'
local Sawblade = behaviors(require 'base.script.obj.object'
	,require 'zeta.script.behavior.deathtopieces'
)

Sawblade.sprite = 'sawblade'
local radius = .75
Sawblade.bbox = {min={-radius,-radius+.5}, max={radius,radius+.5}}
Sawblade.rotCenter = {.5,.5}
Sawblade.useGravity = false
Sawblade.travel = {0,3}
Sawblade.travelTime = 4
Sawblade.damage = 3
Sawblade.rotation = 3000
Sawblade.pushForce = 7
Sawblade.circuit = 'Main'
Sawblade.maxHealth = 20

function Sawblade:init(...)
	Sawblade.super.init(self, ...)
	self.startPos = {self.pos:unpack()}
	-- start our internal clock
	self.t = math.random() * self.travelTime
	if self.timeOffset then self.t = tonumber(self.timeOffset) end
	-- do we have power?
	self.power = game.session['defensesActive_'..self.circuit] and 1 or 0
end

Sawblade.solidFlags = 0
Sawblade.touchFlags = Sawblade.SOLID_YES -- player
					+ Sawblade.SOLID_NO -- geemer
					+ Sawblade.SOLID_GRENADE -- grenades
					+ Sawblade.SOLID_SHOT
Sawblade.blockFlags = 0
Sawblade.touchPriority = 9	-- above shots, below hero
function Sawblade:touch(other, side)
	if self.power < .5 then return true end
	if other.takeDamage then
		other:takeDamage(self.damage, self, self, side)
		local delta = (other.pos - self.pos):normalize()
		other.vel[1] = other.vel[1] + delta[1] * self.pushForce
		other.vel[2] = other.vel[2] + delta[2] * self.pushForce
	end
end

Sawblade.powerChangeRate = 3	-- how long does it take to start/stop?
Sawblade.playSoundDuration = 3
Sawblade.nextSoundTime = math.random() * Sawblade.playSoundDuration
function Sawblade:update(dt)
	Sawblade.super.update(self, dt)

	if game.session['defensesActive_'..self.circuit] then
		self.power = math.min(1, self.power + dt / self.powerChangeRate)
	else
		self.power = math.max(0, self.power - dt / self.powerChangeRate)
	end

	-- only keep spinning as much sa we have power to spin
	self.t = self.t + self.power * dt
	
	self.angle = self.rotation * self.t 
	local f = math.sin(self.t * (2 * math.pi) / self.travelTime) * .5 + .5
	
	self.pos[1] = self.startPos[1] + self.travel[1] * f
	self.pos[2] = self.startPos[2] + self.travel[2] * f

	if self.power > .5 and (not self.nextSoundTime or game.time > self.nextSoundTime) then
		self.nextSoundTime = game.time + self.playSoundDuration
		if math.random(5) == 1 then
			self:playSound('skillsaw', .1)
		end
	end
end

function Sawblade:draw(R, viewBBox)
	self.pos[2] = self.pos[2]-.5
	Sawblade.super.draw(self, R, viewBBox)
	self.pos[2] = self.pos[2]+.5
end

return Sawblade
