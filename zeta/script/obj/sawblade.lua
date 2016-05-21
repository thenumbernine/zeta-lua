local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Sawblade = class(Object)
Sawblade.sprite = 'sawblade'
Sawblade.solid = false
local radius = .75
Sawblade.bbox = {min={-radius,-radius+.5}, max={radius,radius+.5}}
Sawblade.rotCenter = {.5,.5}
Sawblade.useGravity = false
Sawblade.travel = {0,3}
Sawblade.travelTime = 4
Sawblade.damage = 3
Sawblade.rotation = 3000
Sawblade.pushForce = 7

function Sawblade:init(...)
	Sawblade.super.init(self, ...)
	self.startPos = {self.pos:unpack()}
	-- start our internal clock
	self.t = math.random() * self.travelTime
	if self.timeOffset then self.t = tonumber(self.timeOffset) end
	-- do we have power?
	self.power = game.session.defensesDeactivated and 0 or 1
end

function Sawblade:pretouch(other, side)
	if self.power < .5 then return true end
	if other.takeDamage then
		other:takeDamage(self.damage, self, self, side)
		local delta = (other.pos - self.pos):normalize()
		other.vel[1] = other.vel[1] + delta[1] * self.pushForce
		other.vel[2] = other.vel[2] + delta[2] * self.pushForce
	end
end
Sawblade.solidFlags = 0
Sawblade.touchFlags = Sawblade.SOLID_YES -- player
					+ Sawblade.SOLID_NO -- geemer
					+ Sawblade.SOLID_GRENADE -- grenades
Sawblade.blockFlags = 0
Sawblade.touchPriority = 9	-- above shots, below hero
Sawblade.touch_v2 = Sawblade.pretouch

Sawblade.powerChangeRate = 3	-- how long does it take to start/stop?
Sawblade.playSoundDuration = 3
Sawblade.nextSoundTime = math.random() * Sawblade.playSoundDuration
function Sawblade:update(dt)
	Sawblade.super.update(self, dt)

	if game.session.defensesDeactivated then
		self.power = math.max(0, self.power - dt / self.powerChangeRate)
	else
		self.power = math.min(1, self.power + dt / self.powerChangeRate)
	end

	-- only keep spinning as much sa we have power to spin
	self.t = self.t + self.power * dt
	
	self.angle = self.rotation * self.t 
	local f = math.sin(self.t * (2 * math.pi) / self.travelTime) * .5 + .5
	
	self.pos[1] = self.startPos[1] + self.travel[1] * f
	self.pos[2] = self.startPos[2] + self.travel[2] * f

	if not self.nextSoundTime or game.time > self.nextSoundTime then
		self.nextSoundTime = game.time + self.playSoundDuration
		self:playSound('skillsaw', .1)
	end
end

function Sawblade:draw(R, viewBBox)
	self.pos[2] = self.pos[2]-.5
	Sawblade.super.draw(self, R, viewBBox)
	self.pos[2] = self.pos[2]+.5
end

return Sawblade
