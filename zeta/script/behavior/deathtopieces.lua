local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'

local SpritePieces = class(Object)
SpritePieces.solidFlags = 0
SpritePieces.touchFlags = 0
SpritePieces.blockFlags = SpritePieces.SOLID_WORLD
SpritePieces.lifetime = 5
SpritePieces.rotCenter = {.5,.5}
SpritePieces.angle = 0

function SpritePieces:init(args)
	SpritePieces.super.init(self, args)
	local sprite, seq, frameNumber = animsys:getInfo(self.sprite, self.seq, self.seqStartTime)
	self.frameNumber = frameNumber
	self.freq = seq.freq or sprite.freq or 1
	self.color = {1,1,1,1}
end

SpritePieces.moving = true
function SpritePieces:update(dt)
	if self.moving then
		SpritePieces.super.update(self, dt)
	end
	-- freeze animation
	self.seqStartTime = game.time - self.frameNumber / self.freq 
	-- fade out
	self.color[4] = self.color[4] - dt / self.lifetime 
	if self.color[4] < 0 then self.remove = true end
	if self.vel[1] ~= 0 or self.vel[2] ~= 0 then
		self.angle = self.angle + self.rotation * dt
	else
		-- turn off movement altogether and save collision tests
		self.useGravity = false
		self.moving = false
	end
end

-- I need to tweak uv coords ...
-- no easy way to do that
-- so I'm copying the body of Object.draw 
function SpritePieces:draw(R, viewBBox)
	if not self.sprite then return end
	
	local tex
	if self.tex then
		tex = self.tex
	elseif self.sprite then
		tex = animsys:getTex(self.sprite, self.seq or 'stand', self.seqStartTime)
	end
	if tex then tex:bind() end
	local cr,cg,cb,ca = unpack(self.color)

	local uBias, uScale
	if self.drawMirror then
		uBias, uScale = 1, -1
	else
		uBias, uScale = 0, 1
	end
	
	local vBias, vScale
	if self.drawFlipped then
		vBias, vScale = 0,1
	else
		vBias, vScale = 1, -1
	end

	local sx, sy = 1, 1
	if tex then
		local level = game.level
		sx = tex.width/level.tileSize
		sy = tex.height/level.tileSize
	end
	if self.drawScale then
		sx, sy = table.unpack(self.drawScale)
	end

	-- rotation center
	local rcx, rcy = 0, 0
	if self.rotCenter then
		rcx, rcy = self.rotCenter[1], self.rotCenter[2]
		if self.drawMirror then
			rcx = 1 - rcx
		end
		rcx = rcx * sx
		rcy = rcy * sy
	end

	local cx,cy = .5, 0
	if self.drawCenter then
		cx, cy = table.unpack(self.drawCenter)
	end
	cx = cx * sx
	cy = cy * sy

	local u,v = self.u, self.v
	local du,dv = self.du, self.dv
	rcx = rcx * du
	rcy = rcy * dv
	R:quad(
		--[[
		self.pos[1] - cx,
		self.pos[2] - cy,
		sx, sy,
		uBias, vBias, uScale, vScale,
		--]]
		-- [[
		self.pos[1] - cx + sx * u,
		self.pos[2] - cy + sy * v,
		sx * du,
		sy * dv,
	 	uBias + uScale * u,
		vBias + vScale * v,
		uScale * du,
		vScale * dv,
		--]]	
		self.angle,
		cr,cg,cb,ca,
		self.shader,
		self.uniforms,
		rcx, rcy)
end

function SpritePieces.makeFrom(args)
	local obj = args.obj
	local dir = args.dir
	local udivs, vdivs = table.unpack(args.divs)
	local baseVel = 7
	local spreadVel = 3
	local randVel = 1
	local baseVelY = obj.useGravity and 12 or 0
	local du = 1/udivs
	local dv = 1/vdivs
	for i=0,udivs-1 do
		for j=0,vdivs-1 do
			local u = i*du
			local v = j*dv
			SpritePieces{
				pos = obj.pos,
				angle = obj.angle,
				tex = obj.tex,
				sprite = obj.sprite,
				shader = obj.shader,
				uniforms = obj.uniforms,
				seq = obj.seq,
				seqStartTime = obj.seqStartTime,
				drawMirror = obj.drawMirror,
				drawScale = obj.drawScale,
				drawCenter = obj.drawCenter,
				useGravity = obj.useGravity,
				rotation = (math.random() * 2 - 1) * 2000,
				u = u, 
				v = v, 
				du = du,
				dv = dv,
				vel = dir * baseVel
					+ vec2(u-.5*(1-du), v-.5*(1-dv)) * spreadVel
					 + vec2(math.random()-.5, math.random()-.5)*(2*randVel)
					 + vec2(0, baseVelY),
			}
		end
	end
end

local deathToPiecesBehavior = function(parentClass)
	local DeathToPiecesTemplate = class(parentClass)
	
	DeathToPiecesTemplate.deathPieceDivs = {4,4}
	function DeathToPiecesTemplate:die(damage, attacker, inflicter, side)
		SpritePieces.makeFrom{
			obj=self,
			dir=(self.pos - attacker.pos):normalize(),
			divs=self.deathPieceDivs,
		}
		return DeathToPiecesTemplate.super.die(self, damage, attacker, inflicter, side)
	end

	return DeathToPiecesTemplate
end

return deathToPiecesBehavior
