--[[

level is going to contain ...
	tile.png: uchar 2D map of tile type
	tile-fg.png: short 2D map of back tile index in the texpack (draw before sprites)
	tile-bg.png: short 2D map of front tile index in the texpack (draw after sprites)
	background.png: uchar 2D map of background index
	spawn.lua: array of spawnInfo's
--]]

local ffi = require 'ffi'
local bit = require 'bit'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'
local vec4 = require 'vec.vec4'
local box2 = require 'vec.box2'
local modio = require 'base.script.singleton.modio'
local texsys = require 'base.script.singleton.texsys'
local game = require 'base.script.singleton.game'	-- this should exist by now, right?
local Image = require 'image'
local SpawnInfo = require 'base.script.spawninfo'

--[[
Level api:
pos = vec2()						level position offset ... experimental for multiple layers, and currently disabled
initialize()						called by Game when the level starts
getTile(x,y)						used by base.script.obj.object:
alignTileTemplates(x1,y1,x2,y2)		used by editor, by mod-specific objects, and internally within base.script.level
--]]
local Level = class()

local function rgbAt(image, x, y)
	local r = image.buffer[0 + image.channels * (x + image.width * y)]
	local g = image.buffer[1 + image.channels * (x + image.width * y)]
	local b = image.buffer[2 + image.channels * (x + image.width * y)]
	return bit.bor(
		r,
		bit.lshift(g, 8),
		bit.lshift(b, 16))
end

--[[
args:
	path = (optional) path where to find the map, excluding the prefix of "<mod>/maps/"
	
	tileFile. default tile.png
	backgroundFile. default background.png 
	fgTileFile. default tile-fg.png
	bgTileFile. default tile-bg.png
	
	initFile = (optional) file to run when the level inits.
		default "<path>/init.lua"
	
	spawnFile = (optional) file to find spawn info in addition to the tile data.
		useful when you need more than one spawn info per tile, or finer than per-tile mapping, or more info than just position and class.
		default "<path>/spawn.lua"

all the args values are valid properties of levelcfg.lua

spawnFile contents are as follows:
{
	{
		spawn='mario.script.obj.door',
		pos={2,2},
		...
	},
	...
}
--]]
function Level:init(args)

	-- enum of tileMap values. 0 => nil 
	self.tileTypes = assert(args.tileTypes)
	
	-- is this even needed? only by the editor.
	-- TODO enum upon creation of classes 
	self.spawnTypes = assert(args.spawnTypes)

	self.pos = vec2(0,0)
	self.vel = vec2(0,0)

	local mappath = args.path
	if mappath then mappath = 'maps/' .. mappath end

	local tileFile = args.tileFile or (mappath and (mappath..'/tile.png'))
	if tileFile then tileFile = modio:find(tileFile) end
	assert(tileFile, "couldn't find tile file")
	local tileImage = Image(tileFile)
	self.size = vec2(tileImage:size())

	self.tileMap = ffi.new('unsigned char[?]', self.size[1] * self.size[2])
	for j=0,self.size[2]-1 do
		for i=0,self.size[1]-1 do
			self.tileMap[i+self.size[1]*j] = rgbAt(tileImage,i,self.size[2]-j-1)
		end
	end

	local fgTileFile = args.fgTileFile or (mappath and (mappath..'/tile-fg.png'))
	if fgTileFile then fgTileFile = modio:find(fgTileFile) end
	local fgTileImage = fgTileFile and Image(fgTileFile)
	self.fgTileMap = ffi.new('unsigned short[?]', self.size[1] * self.size[2])
	if not fgTileImage then
		ffi.fill(self.fgTileMap, ffi.sizeof('unsigned short') * self.size[1] * self.size[2])
	else
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				self.fgTileMap[i+self.size[1]*j] = rgbAt(fgTileImage,i,self.size[2]-j-1)
			end
		end
	end

	local bgTileFile = args.bgTileFile or (mappath and (mappath..'/tile-bg.png'))
	if bgTileFile then bgTileFile = modio:find(bgTileFile) end
	local bgTileImage = bgTileFile and Image(bgTileFile)
	self.bgTileMap = ffi.new('unsigned short[?]', self.size[1] * self.size[2])
	if not bgTileImage then
		ffi.fill(self.bgTileMap, ffi.sizeof('unsigned short') * self.size[1] * self.size[2])
	else
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				self.bgTileMap[i+self.size[1]*j] = rgbAt(bgTileImage,i,self.size[2]-j-1)
			end
		end
	end

	-- load backgrounds here
	self.backgrounds = table(dofile(modio:find('script/backgrounds.lua')))
	for i,background in ipairs(self.backgrounds) do
		local fn = modio:find('backgrounds/'..background.name..'.png')
		if fn then
			background.tex = texsys:load(fn, true)
		end
	end

	local backgroundImage
	do
		local backgroundFile
		if mappath then backgroundFile = mappath..'/background.png' end
		if args.backgroundFile then backgroundFile = args.backgroundFile end
		if backgroundFile then
			local backgroundFile = modio:find(backgroundFile)
			if backgroundFile then
				backgroundImage = Image(backgroundFile)
				assert(vec2(backgroundImage:size()) == self.size)
			end
		end
	end
	backgroundImage = backgroundImage or templateImage 
	-- convert index enumeration into background map
	-- one-based, so zero is empty
	self.backgroundMap = ffi.new('unsigned char[?]', self.size[1] * self.size[2])
	if not backgroundImage then	
		ffi.fill(self.backgroundMap, self.size[1] * self.size[2])
	else
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				self.backgroundMap[i+self.size[1]*j] = rgbAt(backgroundImage,i,self.size[2]-j-1)
				-- one-based value, with 0 = nil
				-- TODO, warn if any oob values?
			end
		end
	end

	-- hold all textures in one place
	do
		local texpackFile = modio:find('texpack.png')
		assert(texpackFile, "better put your textures in a texpack")
		self.texpackTex = texsys:load(texpackFile)
	end
	
	self.startPositions = table(args.startPositions)
	self.spawnInfos = table()
	
	-- add any additional spawn infos
	do
		local spawnInfoFile
		if mappath then spawnInfoFile = mappath .. '/spawn.lua' end
		if args.spawnFile then spawnInfoFile = args.spawnInfoFile end
		if spawnInfoFile then
			spawnInfoFile = modio:find(spawnInfoFile)
			if spawnInfoFile then
				local spawnInfos = assert(assert(load('return '..file[spawnInfoFile]))())
				for _,args in ipairs(spawnInfos) do

					if type(args.spawn) ~= 'string' then
						error("don't know how to handle spawn of type "..tostring(args.spawn))
					end
					
					assert(type(args.pos) == 'table')
					args.pos = vec2(unpack(args.pos))
					
					self.spawnInfos:insert(SpawnInfo(args))	-- center on x and y
				end
			end
		end
	end

	-- remember this for initialize()'s sake
	local initFile
	if mappath then initFile = mappath..'/init.lua' end
	if args.initFile then initFile = args.initFile end
	self.initFile = initFile
end

-- init stuff to be run after level is assigned as game.level (so objs can reference it)
function Level:initialize()

	-- do an initial respawn
	self:initialSpawn()
	
	-- run any init scripts if they're there
	if self.initFile then
		local initFile = modio:find(self.initFile)
		if initFile then
-- TODO double with sandbox function?
			local sandbox = require 'zeta.script.sandbox'
			sandbox(file[initFile])
		end
	end
end

function Level:initialSpawn()
	for _,spawnInfo in ipairs(self.spawnInfos) do
		spawnInfo:respawn()
	end
end

-- returns a tile enum value
function Level:getTile(x,y)
	x = math.floor(x)
	y = math.floor(y)
	if x<1 or y<1 or x>self.size[1] or y>self.size[2] then return 0 end
	local tileIndex = self.tileMap[(x-1)+self.size[1]*(y-1)]
	return self.tileTypes[tileIndex]
end

function Level:getTileWithOffset(x,y)
	x = x - self.pos[1]
	y = y - self.pos[2]
	return self:getTile(x,y)
end

function Level:update(dt)
	self.pos[1] = self.pos[1] + self.vel[1] * dt
	self.pos[2] = self.pos[2] + self.vel[2] * dt
end

function Level:draw(R, viewBBox)

	-- clone & offset
	local bbox = box2(
		viewBBox.min[1] - self.pos[1],
		viewBBox.min[2] - self.pos[2],
		viewBBox.max[1] - self.pos[1],
		viewBBox.max[2] - self.pos[2])

	local ibbox = box2(
		math.floor(bbox.min[1]),
		math.floor(bbox.min[2]),
		math.floor(bbox.max[1]),
		math.floor(bbox.max[2]))
	
	local xmin = ibbox.min[1]
	local xmax = ibbox.max[1]
	local ymin = ibbox.min[2]
	local ymax = ibbox.max[2]

	if xmin > self.size[1] then return end
	if xmax < 1 then return end
	if ymin > self.size[2] then return end
	if ymax < 1 then return end
	
	if xmin < 1 then xmin = 1 end
	if xmax > self.size[1] then xmax = self.size[1] end
	if ymin < 1 then ymin = 1 end
	if ymax > self.size[2] then ymax = self.size[2] end

	for y=ymin,ymax do
		for x=xmin,xmax do
			local offset = x-1+self.size[1]*(y-1)
			local bgindex = self.backgroundMap[offset]
			local background = self.backgrounds[bgindex]
			local scaleX, scaleY = 32, 32
			local scrollX, scrollY = 4, 4
			if background then
				scaleX, scaleY = background.scaleX, background.scaleY
				scrollX, scrollY = background.scrollX, background.scrollY
			end
			local bgtex = background and background.tex
			if bgtex then
				bgtex:bind()
				R:quad(
					x, y,
					1,1,
					(x - bbox.min[1] * scrollX) / scaleX,
					(1 - (y - bbox.min[2] * scrollY)) / scaleY,
					1/scaleX, -1/scaleY,
					0,
					1,1,1,1)
			end	
		end
	end
	
	local tilesWide = self.texpackTex.width/16
	local tilesHigh = self.texpackTex.height/16
	
	self.texpackTex:bind()
	for y=ymin,ymax do
		for x=xmin,xmax do
			local offset = x-1+self.size[1]*(y-1)
			-- draw bg tile
			local bgtileindex = self.bgTileMap[offset]
			if bgtileindex > 0 then
				bgtileindex = bgtileindex - 1
				local ti = bgtileindex % tilesWide
				local tj = (bgtileindex - ti) / tilesWide
				
				R:quad(
					x, y,
					1, 1,
					ti/tilesWide, (tj+1)/tilesHigh,
					1/tilesWide, -1/tilesHigh,
					0,
					1,1,1,1)
			end
		end
	end

	-- draw objects
	for _,obj in ipairs(game.objs) do
		if not obj.drawn then
			obj:draw(R, viewBBox)
			obj.drawn = true
		end
	end

	self.texpackTex:bind()
	for y=ymin,ymax do
		for x=xmin,xmax do
			local offset = x-1+self.size[1]*(y-1)
			-- draw fg tile
			local fgtileindex = self.fgTileMap[offset]
			if fgtileindex > 0 then
				fgtileindex = fgtileindex - 1
				local ti = fgtileindex % tilesWide
				local tj = (fgtileindex - ti) / tilesWide
				
				R:quad(
					x, y,
					1, 1,
					ti/tilesWide, (tj+1)/tilesHigh,
					1/tilesWide, -1/tilesHigh,
					0,
					1,1,1,1)
			end
		end
	end
end

return Level
