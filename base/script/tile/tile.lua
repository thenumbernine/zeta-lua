local ffi = require 'ffi'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local animsys = require 'base.script.singleton.animsys'
local game = require 'base.script.singleton.game' -- debug


-- almost their own GameObject...
-- but non-updating?
local Tile = class()

function Tile:init(args)
	-- [[ without ffi
	self.pos = vec2(args.pos[1], args.pos[2])
	--]]
	--[[ with ffi, keeping indexing
	self.pos = ffi.new('float[3]', 0, args.pos[1], args.pos[2])
	--]]
end

-- by popular demand
local keepFields = {pos=1, objs=1, bgtex=1, warp=1, template=1, color=1}
function Tile:makeEmpty()
	local EmptyTile = require 'base.script.tile.empty'
	
	if getmetatable(self) == EmptyTile then return end

	-- clear all member vars except 'pos'
	for k,_ in pairs(self) do
		if not keepFields[k] then
			self[k] = nil
		end
	end
	setmetatable(self, EmptyTile)	
end

function Tile:draw(R, viewBBox)
	-- draw background
	if self.bgtex then
        self.bgtex:bind()
		R:quad(
			self.pos[1], self.pos[2],
            1,1,
			(self.pos[1] - viewBBox.min[1] / 4) / 32,
            (1 - (self.pos[2] - viewBBox.min[2] / 4)) / 32,
			1/32, -1/32,
			0,
			1,1,1,1)
	end
	
	-- draw tile quad
	-- very similar to GameObject:draw ...
	
	local tex
	if self.tex then
		tex = self.tex
	elseif self.sprite and self.seq then
		tex = animsys:getTex(self.sprite, self.seq)
	end
	if not tex and not self.shader then return end
	
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
	
	if tex then tex:bind() end
	local cr,cg,cb,ca
	if self.color then
		cr,cg,cb,ca = unpack(self.color)
	else
		cr,cg,cb,ca = 1,1,1,1
	end

	R:quad(
		self.pos[1], self.pos[2],
		1, 1,
		uBias, vBias,
		uScale, vScale,
		0,
		cr,cg,cb,ca,
		self.shader,
		self.uniforms
	)
end
	
function Tile:drawObjs(R, viewBBox)
	if not self.objs then return end
	for _,obj in ipairs(self.objs) do
		if not obj.drawn then
			obj:draw(R, viewBBox)
			obj.drawn = true
		end
	end
end

return Tile
