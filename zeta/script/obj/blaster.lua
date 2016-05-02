-- shot object:

local BlasterShot = (function()
	local class = require 'ext.class'
	local GameObject = require 'base.script.obj.object'
	local game = require 'base.script.singleton.game'
	local box2 = require 'vec.box2'

	local BlasterShot = class(GameObject)
	BlasterShot.bbox = box2(-.2, 0, .2, .4)
	BlasterShot.sprite = 'blaster-shot'
	BlasterShot.useGravity = false
	BlasterShot.solid = false
	BlasterShot.damage = 1

	function BlasterShot:init(args, ...)
		BlasterShot.super.init(self, args, ...)
		self.owner = args.owner
		self:playSound('shoot')
		setTimeout(.2, function() self.remove = true end)
	end

	function BlasterShot:touchTile(tile, side)
		-- generalize this for all projectiles
		if tile.onShoot then
			tile:onShoot(self, side)
		end
		
		self.vel[1] = 0
		self.vel[2] = 0
		self.collidesWithWorld = false
		self.collidesWithObjects = false
		self.remove = true
	end

	function BlasterShot:pretouch(other, side)
		if other == self.owner then return true end
		if other.takeDamage then
			other:takeDamage(self.damage, self.owner, self, side)
			self.collidesWithWorld = false
			self.collidesWithObjects = false
			self.remove = true
			return
		end
		if other.solid then
			self.collidesWithWorld = false
			self.collidesWithObjects = false
			self.remove = true
			return
		end
	end

	return BlasterShot
end)()

-- inventory object:

local BlasterInv = (function()
	local vec2 = require 'vec.vec2'
	local class = require 'ext.class'
	local OverlayObject = require 'base.script.item'
	local game = require 'base.script.singleton.game'

	local BlasterInv = class(OverlayObject)
	BlasterInv.sprite = 'blaster'
	BlasterInv.weapon = true
	BlasterInv.shootDelay = .05

	function BlasterInv:init(...)
		BlasterInv.super.init(self, ...)
		self.drawOffset = vec2()
		self.rotCenter = vec2()
	end

	function BlasterInv:onShoot(player)
		if player.inputShootLast then return end
		player.nextShootTime = game.time + self.shootDelay
		local pos = player.pos + vec2(0, .25)
		pos[2] = pos[2] + self.drawOffset[2]
		local vel = vec2()
		if player.drawMirror then
			vel[1] = -1
		else
			vel[1] = 1
		end
		if player.inputUpDown ~= 0 then
			if player.inputUpDown > 0 then
				-- if we're holding up then shoot up
				vel[2] = 1
			end
			if not player.onground then
				if player.inputUpDown < 0 then
					-- if we're holding down and jumping then shoot down
					vel[2] = -1
				end
			end
			-- if we're holding down ... but not left/right ... then duck and shoot left/right
			if player.inputLeftRight == 0 and player.inputUpDown > 0 then
				vel[1] = 0
			end
			if not player.onground and player.inputLeftRight == 0 and player.inputUpDown < 0 then
				vel[1] = 0
			end
		end	
		vel = vel * 35
		BlasterShot{
			owner = player,
			pos = pos,
			vel = vel,
		}
	end
	function BlasterInv:drawItem(player, R, viewBBox)
		self.rotCenter[1] = self.drawMirror and 1 or 0
		self.rotCenter[2] = .5
		self.drawOffset = vec2(.5,0)
		if not player.ducking then
			self.drawOffset[2] = .75
		else
			self.drawOffset[2] = 0
		end
	
		if player.inputUpDown > 0 then
			if player.inputLeftRight == 0 then
				self.angle = 90
			else
				self.angle = 45
			end
		else
			self.angle = 0
		end
		self.drawMirror = player.drawMirror
		if self.drawMirror then self.angle = -self.angle end

		BlasterInv.super.drawItem(self, player, R, viewBBox)
	end

	return BlasterInv
end)()

-- world object

local Blaster = (function()
	local class = require 'ext.class'
	local Item = require 'zeta.script.obj.item'
	local game = require 'base.script.singleton.game'

	local Blaster = class(Item)
	Blaster.sprite = 'blaster'

	function Blaster:give(player, side)
		local invObj = BlasterInv()
		player.items:insert(invObj)
		player.weapon = invObj
	end

	return Blaster
end)()

return Blaster
