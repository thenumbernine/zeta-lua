local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Sawblade = class(Object)
Sawblade.sprite = 'sawblade'
Sawblade.solid = false
Sawblade.bbox = {min={-.85,-.85+.5}, max={.85,.85+.5}}
Sawblade.rotCenter = {.5,.5}
Sawblade.useGravity = false
Sawblade.travel = {0,3}
Sawblade.travelTime = 4
Sawblade.damage = 3
Sawblade.rotation = 3000
Sawblade.pushForce = 7

function Sawblade:init(args)
	Sawblade.super.init(self, args)
	if args.travel then self.travel = {table.unpack(args.travel)} end
	if args.travelTime then self.travelTime = tonumber(args.travelTime) end 
	if args.damage then self.damage = tonumber(args.damage) end
	self.startPos = {self.pos:unpack()}
	-- start our internal clock
	self.t = math.random() * self.travelTime
	if args.timeOffset then self.t = tonumber(args.timeOffset) end
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
Sawblade.touchFlags = Sawblade.SOLID_YES + Sawblade.SOLID_GRENADE
Sawblade.blockFlags = 0
Sawblade.touch_v2 = Sawblade.pretouch

Sawblade.powerChangeRate = 3	-- how long does it take to start/stop?
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
end

function Sawblade:draw(R, viewBBox)
	self.pos[2] = self.pos[2]-.5
	Sawblade.super.draw(self, R, viewBBox)
	self.pos[2] = self.pos[2]+.5
end

return Sawblade
