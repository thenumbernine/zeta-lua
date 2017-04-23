local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local ItemObject  = require 'mario.script.obj.item'
local PlayerItem = require 'base.script.item'
local game = require 'base.script.singleton.game'


local BazookaShot = class(GameObject)
BazookaShot.sprite = 'supermissile'
BazookaShot.solidFlags = BazookaShot.SOLID_GRENADE
BazookaShot.touchFlags = BazookaShot.SOLID_WORLD 
					+ BazookaShot.SOLID_YES 
					+ BazookaShot.SOLID_NO 
					+ BazookaShot.SOLID_GRENADE
BazookaShot.blockFlags = BazookaShot.SOLID_WORLD
BazookaShot.useGravity = false
BazookaShot.speed = 50

function BazookaShot:init(args)
	local shooter = assert(args.shooter)

	args.pos = {shooter.pos[1], shooter.pos[2] + shooter.bbox.max[2] - .4}
	BazookaShot.super.init(self, args)
	
	self:hasBeenKicked(shooter)
	if shooter.inputUpDown > 0 then
		self.vel[1] = shooter.inputLeftRight
		self.vel[2] = shooter.inputUpDown
	else
		if args.shooter.drawMirror then
			self.vel[1] = -1
		else
			self.vel[1] = 1
		end
	end
	self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	
	self.vel[1], self.vel[2] = self.vel[1] * self.speed, self.vel[2] * self.speed
	
	self.touch = self.activeTouch
end

function BazookaShot:activeTouch(other, side)
	if other.hitByShell then other:hitByShell(self) end
	self:blast()
end

function BazookaShot:touchTile(tileType, side, normal, x, y)
	if tileType and tileType.solid and tileType.onHit then
		tileType:onHit(self, x, y)
	end
	self:blast()
end

function BazookaShot:blast()
	self.touch = nil
	
	self.sprite = 'missileblast'
	self.pos[2] = self.pos[2] - 1
	self.angle = nil

	-- TODO reset frame counter...
	self.solidFlags = 0
	self.touchFLags = 0
	self.blockFlags = 0
	self.vel[1], self.vel[2] = 0, 0
	
	self.removeTime = game.time + 1.25
end


local BazookaItem = class(PlayerItem)
BazookaItem.sprite = 'bazooka'
BazookaItem.drawOffset = {0, .5}

function BazookaItem:onShoot(player)
	BazookaShot{shooter=player}
end


local Bazooka = class(ItemObject)
Bazooka.sprite = 'bazooka'
Bazooka.itemClass = BazookaItem

return Bazooka
