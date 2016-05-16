local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local box2 = require 'vec.box2'

local GeemerChunk = class(Object)
GeemerChunk.sprite = 'geemer'
GeemerChunk.seq = 'chunk'

function GeemerChunk:init(args)
	GeemerChunk.super.init(self, args)
	self.removeTime = game.time + 2
end
GeemerChunk.bbox = box2(-.2, 0, .2, .4)
GeemerChunk.collidesWithWorld = true
GeemerChunk.collidesWithObjects = false
GeemerChunk.solidFlags = 0
GeemerChunk.touchFlags = 0
GeemerChunk.blockFlags = GeemerChunk.SOLID_WORLD

-- TODO personal gravity and personal fall speed limit
function GeemerChunk:update(...)
	GeemerChunk.super.update(self, ...)
	self.vel[2] = self.vel[2] * .96
end

-- static function
function GeemerChunk.makeAt(args)
	local baseVel = 7
	local baseVelY = 12
	for i=1,math.random(2)+3 do
		local theta = math.random() * math.pi * 2
		local chunk = GeemerChunk{
			pos = args.pos,
			vel = (args.dir + {math.cos(theta), math.sin(theta)}) * baseVel + {0,baseVelY},
		}
		chunk.color = args.color
	end
end

return GeemerChunk
