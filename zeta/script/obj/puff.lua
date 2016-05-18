local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local vec4 = require 'vec.vec4'

local Puff = class(Object)

Puff.sprite = 'puff'
Puff.solid = false
Puff.collidesWithWorld = false
Puff.collidesWithObjects = false
Puff.useGravity = false
Puff.baseLiveTime = 1

Puff.solidFlags = 0
Puff.touchFlags = 0
Puff.blockFlags = 0

function Puff:init(...)
	Puff.super.init(self, ...)
	self.color = vec4(1,1,1,1)
	self.liveTime = self.baseLiveTime
end

function Puff:update(dt, ...)	
	Puff.super.update(self, dt, ...)
	self.liveTime = self.liveTime - dt
	if self.liveTime < 0 then
		self.liveTime = 0 
		self.remove = true 
	end
	self.color[4] = self.liveTime / self.baseLiveTime
end

-- static function
function Puff.puffAt(x, y)
	local pos = {x,y}
	for i=1,10 do
		Puff{pos=pos, vel={math.random()*2-1,math.random()*2-1}}
	end
end

return Puff
