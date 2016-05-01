local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'


local DoorPortal = class(GameObject)

DoorPortal.sprite = 'door-portal'
--DoorPortal.solid = true
--DoorPortal.collidesWithWorld = false
--DoorPortal.useGravity = false
DoorPortal.bbox = box2(-.4, -.4, .4, .4)

function DoorPortal:init(args)
	DoorPortal.super.init(self, args)
	
	-- TODO color accordingly
	self.shottype = args.shottype
end


local Door = class(GameObject)

Door.sprite = 'samus'
Door.seq = 'stand'
Door.solid = true
Door.collidesWithWorld = false
Door.useGravity = false
Door.bbox = box2(-1.9, -.9, 1.9, .9)

function Door:init(args)
	print('Door')
	for k,v in pairs(args) do print('',k,v) end
	local vec2 = require 'vec.vec2'
	args.pos = args.pos + vec2(.5,.5)
	Door.super.init(self, args)

--	self.portal = DoorPortal(args)
--	self.portal.frame = self
end

function Door:draw(...)
	Door.super.draw(self, ...)
	print('door draw')
end


return Door