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
local modio = require 'base.script.singleton.modio'
local game = require 'base.script.singleton.game'	-- this should exist by now, right?
local Image = require 'image'
local glapp = require 'base.script.singleton.glapp'
local vec4f = require 'vec-ffi.vec4f'
local SpawnInfo = require 'base.script.spawninfo'


--[[
float x, y, w, h;
float scaleX, scaleY;
float scrollX, scrollY;
--]]
ffi.cdef[[
typedef struct {
	float x, y, w, h;
	float scaleX, scaleY;
	float scrollX, scrollY;
} background_t;
]]

-- tile in the map system
local MapTile = class()

function MapTile:init(rx,ry)
	-- pos is in map tile coordinates ... 32 tile coordinates (or whatever level.mapTileSize says)
	self.pos = vec2(rx,ry)
end

function MapTile:addSpawnInfo(spawnInfo)
	if not self.spawnInfos then self.spawnInfos = table() end
	self.spawnInfos:insert(spawnInfo)
end

function MapTile:removeAllObjs()
	if not self.spawnInfos then return end
	for _,spawnInfo in ipairs(self.spawnInfos) do
		spawnInfo:removeObj()
	end
end

function MapTile:spawnAllObjs()
	if not self.spawnInfos then return end
	for _,spawnInfo in ipairs(self.spawnInfos) do
		spawnInfo:removeObj()
		spawnInfo:respawn()
	end
end

--[[
Level api:
pos = vec2()						level position offset ... experimental for multiple layers, and currently disabled
initialize()						called by Game when the level starts
getTile(x,y)						used by base.script.obj.object:
alignTileTemplates(x1,y1,x2,y2)		used by editor, by mod-specific objects, and internally within base.script.level
--]]
local Level = class()

-- how many pixels wide and high a tile is
-- used for sprites and for texpack tiles
Level.tileSize = 16

-- how many tiles in a 'maptile'
-- i.e. room size
Level.mapTileSize = vec2(32, 32)

-- pixel width of a tile for the renderer to switch to overworld map
Level.overmapZoomLevel = 16

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
	roomFile.  default room.png

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
	self.objsAtTile = table()

	-- enum of tileMap values. 0 => nil 
	self.tileTypes = assert(args.tileTypes)
	
	-- used by editor and by save/load 
	self.spawnTypes = assert(args.spawnTypes)
	self.serializeTypes = assert(args.serializeTypes)

	self.pos = vec2(0,0)
	self.vel = vec2(0,0)

	local mappath = args.path
	if mappath then mappath = 'maps/' .. mappath end

	local tileFile = args.tileFile or (mappath and (mappath..'/tile.png'))
	if not mappath and not args.tileFile then	
		error("didn't specify an args.tileFile or a mappath")
	end
	if tileFile then 
		local searchTileFile = modio:find(tileFile) 
		if not searchTileFile then
			for _,dir in ipairs(modio.search) do
				print('\tlooking in '..dir..'/'..tileFile)
			end
		end
		tileFile = searchTileFile
	end
	if not tileFile then
		error("couldn't find file at "..mappath.."/tile.png")
	end
	local tileImage = Image(tileFile)
	self.size = vec2(tileImage:size())

	-- how many tiles wide and high a maptile is (which rooms are comoposed of)
	self.sizeInMapTiles = vec2(
		math.ceil(self.size[1]/self.mapTileSize[1]),
		math.ceil(self.size[2]/self.mapTileSize[2]))

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
		if vec2(fgTileImage:size()) ~= self.size then
			print('expected tile-fg.png size '..vec2(fgTileImage:size())..' to match tile.png size '..self.size)
		end
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
		assert(vec2(bgTileImage:size()) == self.size)
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				self.bgTileMap[i+self.size[1]*j] = rgbAt(bgTileImage,i,self.size[2]-j-1)
			end
		end
	end

	-- load rooms here
	local roomFile = args.roomFile or (mappath and (mappath..'/room.png'))
	if roomFile then roomFile = modio:find(roomFile) end
	local roomImage = roomFile and Image(roomFile)
	self.roomMap = ffi.new('unsigned short[?]', self.sizeInMapTiles[1] * self.sizeInMapTiles[2])
	if not roomImage then
		ffi.fill(self.roomMap, ffi.sizeof('unsigned short') * self.sizeInMapTiles[1] * self.sizeInMapTiles[2])
	else
		assert(vec2(roomImage:size()) == self.sizeInMapTiles)
		for j=0,self.sizeInMapTiles[2]-1 do
			for i=0,self.sizeInMapTiles[1]-1 do
				self.roomMap[i+self.sizeInMapTiles[1]*j] = rgbAt(roomImage,i,self.sizeInMapTiles[2]-j-1)
			end
		end
	end
		
	local texsys = modio:require 'script.singleton.texsys'
	local Tex2D = texsys.GLTex2D

	-- load backgrounds here
	do
		self.backgrounds = table(assert(assert(load('return '..assert(file[assert(modio:find('script/backgrounds.lua'))])))()))
		self.bgtexpackFilename = modio:find(mappath..'/bgtexpack.png')
		if not self.bgtexpackFilename then
			self.bgtexpackFilename = modio:find'bgtexpack.png'
			assert(self.bgtexpackFilename, "better put your background textures in a texpack, and define their regions in your mod's scripts/backgrounds.lua file")
		end
		self.bgtexpackImage = Image(self.bgtexpackFilename)
		local gl = game.R.gl
		self.bgtexpackTex = Tex2D{
			image = self.bgtexpackImage,
			minFilter = gl.GL_LINEAR,
			magFilter = gl.GL_NEAREST,
			internalFormat = gl.GL_RGBA,
			format = gl.GL_RGBA,
			generateMipmap = true,
		}
	end

	local backgroundFile
	if mappath then backgroundFile = mappath..'/background.png' end
	if args.backgroundFile then backgroundFile = args.backgroundFile end
	if backgroundFile then backgroundFile = modio:find(backgroundFile) end
	local backgroundImage = backgroundFile and Image(backgroundFile)
	-- convert index enumeration into background map
	-- one-based, so zero is empty
	self.backgroundMap = ffi.new('unsigned char[?]', self.size[1] * self.size[2])
	if not backgroundImage then	
		ffi.fill(self.backgroundMap, self.size[1] * self.size[2])
	else
		assert(vec2(backgroundImage:size()) == self.size)
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				self.backgroundMap[i+self.size[1]*j] = rgbAt(backgroundImage,i,self.size[2]-j-1)
				-- one-based value, with 0 = nil
				-- TODO, warn if any oob values?
			end
		end
	end

	-- backup 
	self:backupTiles()

	-- hold all textures in one place
	do
		self.texpackFilename = modio:find(mappath..'/texpack.png')
		if not self.texpackFilename then
			self.texpackFilename = modio:find 'texpack.png'
			assert(self.texpackFilename, "better put your textures in a texpack")
		end
		-- save the Image for Editor
		self.texpackImage = Image(self.texpackFilename)
		assert(self.texpackImage.channels == 4)
		local gl = game.R.gl
		self.texpackTex = Tex2D{
			image = self.texpackImage,
			minFilter = gl.GL_LINEAR,
			magFilter = gl.GL_NEAREST,
			internalFormat = gl.GL_RGBA,
			format = gl.GL_RGBA,
			generateMipmap = true,	-- only used for the overworld texture
		}
	end

	do	-- for editor's sake, and maybe for overworld view's sake, keep a texture with each pixel equal to a tile
		local gl = game.R.gl
	
		local tilesWide = self.texpackTex.width / self.tileSize
		local tilesHigh = self.texpackTex.height / self.tileSize
		local tilesInTexpack = tilesWide * tilesHigh

		-- this is the texpack, but scaled down to 1 pixel per tile
		self.texpackDownsampleImage = Image(tilesWide, tilesHigh, 3, 'unsigned char')
		local log2tileSize = math.floor(math.log(self.tileSize + .5, 2))
		
		self.texpackTex:bind()
		gl.glGetTexImage(self.texpackTex.target, log2tileSize, gl.GL_RGB, gl.GL_UNSIGNED_BYTE, self.texpackDownsampleImage.buffer)
		self.texpackTex:unbind()

		
		-- LUMINANCE16 is more appropriate but not always supported, esp not always with 16 whole bits.  lum_alpha is more supported
		self.fgTileTex = Tex2D{
			internalFormat = gl.GL_LUMINANCE_ALPHA,
			width = self.size[1],
			height = self.size[2],
			format = gl.GL_LUMINANCE_ALPHA,
			type = gl.GL_UNSIGNED_BYTE,
			data = self.fgTileMap,
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}

		self.bgTileTex = Tex2D{
			internalFormat = gl.GL_LUMINANCE_ALPHA,
			width = self.size[1],
			height = self.size[2],
			format = gl.GL_LUMINANCE_ALPHA,
			type = gl.GL_UNSIGNED_BYTE,
			data = self.bgTileMap,
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}

		self.backgroundTex = Tex2D{
			internalFormat = gl.GL_LUMINANCE,
			width = self.size[1],
			height = self.size[2],
			format = gl.GL_LUMINANCE,
			type = gl.GL_UNSIGNED_BYTE,
			data = self.backgroundMap,
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}


		-- TODO every time self.backgrounds changes, this has to be updated
		-- but for now it looks like 'backgrounds' is static

		-- another option: use vertex arrays and just set them constant across the poly
		self.backgroundStructData = ffi.new('background_t[?]', #self.backgrounds)
		assert(ffi.sizeof(self.backgroundStructData) == ffi.sizeof'float' * 8 * #self.backgrounds)
		local ptr = self.backgroundStructData
		for i,background in ipairs(self.backgrounds) do
			ptr[0].x = background.x
			ptr[0].y = background.y
			ptr[0].w = background.w
			ptr[0].h = background.h
			ptr[0].scaleX = background.scaleX
			ptr[0].scaleY = background.scaleY
			ptr[0].scrollX = background.scrollX
			ptr[0].scrollY = background.scrollY
			ptr = ptr + 1
		end
		self.backgroundStructTex = Tex2D{
			internalFormat = gl.GL_RGBA32F,
			width = 2,
			height = #self.backgrounds,
			format = gl.GL_RGBA,
			type = gl.GL_FLOAT,
			data = ffi.cast('float*', self.backgroundStructData),
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}

		local GLProgram = require 'gl.program'
	
		-- render the background image (with scrolling effects) and the background tiles
		self.levelBgShader = GLProgram{
			vertexCode = [[
varying vec2 pos;
varying vec2 tc;
void main() {
	pos = gl_Vertex.xy;
	tc = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();
}
]],
			fragmentCode = [[
varying vec2 pos;
varying vec2 tc;

uniform sampler2D backgroundTex;		// unsigned char
uniform sampler2D bgTileTex;			// unsigned short <=> luminance_alpha
uniform sampler2D bgtexpackTex;			//backgroundTex uses this
uniform sampler2D texpackTex;			//bgTileTex uses this
uniform sampler2D backgroundStructTex;

uniform float tileSize;
uniform vec2 texpackTexSize;
uniform vec2 bgtexpackTexSize;
uniform vec2 viewMin;
uniform float backgroundStructTexSize;

void main() {
	vec2 posInTile = pos - floor(pos);
	posInTile.y = 1. - posInTile.y;		//because y is flipped in our image coordinate system

	//TODO background here!
	gl_FragColor = vec4(0.);

	// background color
	float bgIndexV = texture2D(backgroundTex, tc).x;
	float bgIndex = 255. * bgIndexV;
	if (bgIndex > 0.) {
		// lookup the background region from an array/texture somewhere ...
		// it should specify x, y, w, h, scaleX, scaleY, scrollX, scrollY
		// so 8 channels per background in all
		float u = (bgIndex - .5) / backgroundStructTexSize;
		vec4 xywh = texture2D(backgroundStructTex, vec2(.25, u));
		vec2 xy = xywh.xy;
		vec2 wh = xywh.zw;
		vec4 scaleScroll = texture2D(backgroundStructTex, vec2(.75, u));
		vec2 scale = scaleScroll.xy;
		vec2 scroll = scaleScroll.zw;

		vec2 uv = pos - viewMin * scroll;
		uv.y = 1. - uv.y;
		uv /= scale;
		uv = mod(uv, 1.);
		uv = (uv * wh + xy) / bgtexpackTexSize;
		vec4 backgroundColor = texture2D(bgtexpackTex, uv);
		
		gl_FragColor.rgb = mix(gl_FragColor.rgb, backgroundColor.rgb, backgroundColor.a);
	}

	
	float tilesWide = texpackTexSize.x / tileSize;
	float tilesHigh = texpackTexSize.y / tileSize;
	
	// bg tile color
	vec2 bgTileIndexV = texture2D(bgTileTex, tc).zw;
	float bgTileIndex = 255. * (bgTileIndexV.x + 256. * bgTileIndexV.y);
	if (bgTileIndex > 0.) {
		bgTileIndex = bgTileIndex - 1;
		float ti = mod(bgTileIndex, tilesWide);
		float tj = (bgTileIndex - ti) / tilesWide;
		
		// hmm, stamp stuff goes here, do I want to keep it?
		
		vec4 bgColor = texture2D(texpackTex, (vec2(ti, tj) + posInTile) / vec2(tilesWide, tilesHigh));
		
		gl_FragColor.rgb = mix(gl_FragColor.rgb, bgColor.rgb, bgColor.a);
	}

	//hmm, how to handle alpha, since this won't mix the same as applying these two layers separately
	gl_FragColor.a = 1.;
}
]],	
			uniforms = {
				backgroundTex = 0,
				bgTileTex = 1,
				bgtexpackTex = 2,
				texpackTex = 3,
				backgroundStructTex = 4,
				texpackTexSize = {self.texpackTex.width, self.texpackTex.height},
				bgtexpackTexSize = {self.bgtexpackTex.width, self.bgtexpackTex.height},
				backgroundStructTexSize = #self.backgrounds,
			},
		}

		self.levelFgShader = GLProgram{
			vertexCode = [[
varying vec2 pos;
varying vec2 tc;
void main() {
	pos = gl_Vertex.xy;
	tc = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();
}
]],
			fragmentCode = [[
varying vec2 pos;	//world coordinates
varying vec2 tc;	//in [0,1]^2

uniform sampler2D fgTileTex;
uniform sampler2D texpackTex;

uniform float tileSize;
uniform vec2 texpackTexSize;

void main() {
	vec2 posInTile = pos - floor(pos);
	posInTile.y = 1. - posInTile.y;		//because y is flipped in our image coordinate system
	
	float tilesWide = texpackTexSize.x / tileSize;
	float tilesHigh = texpackTexSize.y / tileSize;
	
	gl_FragColor = vec4(0.);

	// fg tile color
	vec2 fgTileIndexV = texture2D(fgTileTex, tc).zw;	// z = lum = lo byte, w = alpha = hi byte
	float fgTileIndex = 255. * (fgTileIndexV.x + 256. * fgTileIndexV.y);	// this looks too horrible to be correct
	if (fgTileIndex > 0.) {	//0 = transparent
		fgTileIndex = fgTileIndex - 1;
		float ti = mod(fgTileIndex, tilesWide);
		float tj = (fgTileIndex - ti) / tilesWide;
		
		ti = floor(ti + .5);
		tj = floor(tj + .5);

		// hmm, stamp stuff goes here, do I want to keep it?
		
		vec4 fgColor = texture2D(texpackTex, (vec2(ti, tj) + posInTile) / vec2(tilesWide, tilesHigh));
		
		gl_FragColor.rgb = mix(gl_FragColor.rgb, fgColor.rgb, 1. - gl_FragColor.a);
		gl_FragColor.a = fgColor.a;
	}
}
]],
			uniforms = {
				fgTileTex = 0,
				texpackTex = 1,
				texpackTexSize = {self.texpackTex.width, self.texpackTex.height},
			},
		}
	end

	-- chop world up into 32x32 map tiles, for the sake of linking and spawning
	-- map tiles will hold objs and spawnInfos
	-- because they're lua tables, these are 1-based (even though they're sparse)
	self.mapTiles = {}
--[[
	for i=1,math.ceil(self.size[1]/self.mapTileSize[1]) do
		self.mapTiles[i] = {}
		for j=1,math.ceil(self.size[2]/self.mapTileSize[2]) do
			self.mapTiles[i][j] = MapTile(i,j)
		end
	end
--]]

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
				self:processSpawnInfoArgs(spawnInfos)	
			end
		end
	end
	
	local roomsFile = args.roomsFile or (mappath and mappath..'/rooms.lua')
	if roomsFile then roomsFile = modio:find(roomsFile) end
	if roomsFile then
		self.roomProps = assert(assert(load('return '..file[roomsFile]))())
	else
		self.roomProps = table()
	end
	assert(type(self.roomProps)=='table')
	
	-- remember this for initialize()'s sake
	local initFile
	if mappath then initFile = mappath..'/init.lua' end
	if args.initFile then initFile = args.initFile end
	self.initFile = initFile
end

function Level:processSpawnInfoArgs(spawnInfos)
-- [[ only make what mapTiles we need
	local function addMapTile(x,y)
		local rx = math.floor((x-1) / self.mapTileSize[1]) + 1
		local ry = math.floor((y-1) / self.mapTileSize[2]) + 1
		if not self.mapTiles[rx] then self.mapTiles[rx] = {} end
		if not self.mapTiles[rx][ry] then self.mapTiles[rx][ry] = MapTile(rx,ry) end
	end
--]]
	
	for _,args in ipairs(spawnInfos) do
		if type(args.spawn) ~= 'string' then
			error("don't know how to handle spawn of type "..tostring(args.spawn))
		end
		
		assert(type(args.pos) == 'table')
		args.pos = vec2(unpack(args.pos))
	
		local spawnInfo = SpawnInfo(args)
		self.spawnInfos:insert(spawnInfo)	-- center on x and y

		addMapTile(args.pos:unpack())
		local mapTile = self:getMapTile(args.pos:unpack())
		if mapTile then
			mapTile:addSpawnInfo(spawnInfo)
		end
	end
end

function Level:backupTiles()
	for _,field in ipairs{'tileMap', 'fgTileMap', 'bgTileMap', 'backgroundMap'} do
		local src = self[field]
		local srctype = tostring(ffi.typeof(src))
		local ctype = assert(srctype:match('^ctype<(.*)>$'), "failed to deduce ctype from "..srctype)
		local dst = ffi.new(ctype, self.size[1] * self.size[2])
		ffi.copy(dst, src, ffi.sizeof(src))
		self[field..'Original'] = dst 
	end
end

function Level:refreshTiles()
	for _,field in ipairs{'tileMap', 'fgTileMap', 'bgTileMap', 'backgroundMap'} do
		ffi.copy(self[field], self[field..'Original'], ffi.sizeof(self[field]))
	end
	-- TODO refreshTileTexelsForLayer also?
end

-- return mapTile x,y for tile x,y
function Level:getMapTilePos(x,y)
	local rx = math.floor((x-1) / self.mapTileSize[1]) + 1
	local ry = math.floor((y-1) / self.mapTileSize[2]) + 1
	return rx, ry
end

-- return mapTile for tile x,y
function Level:getMapTile(x,y)
	local rx, ry = self:getMapTilePos(x,y)
	local col = self.mapTiles[rx]
	return col and col[ry]
end

-- get the room # for this tile
function Level:getRoom(x,y)
	local rx, ry = self:getMapTilePos(x,y)
	return self:getRoomAtMapTilePos(rx,ry)
end

function Level:getRoomAtMapTilePos(rx,ry)
	if rx < 1 or rx > self.sizeInMapTiles[1]
	or ry < 1 or ry > self.sizeInMapTiles[2]
	then
		return -1
	end
	return self.roomMap[rx-1+self.sizeInMapTiles[1]*(ry-1)]
end

-- init stuff to be run after level is assigned as game.level (so objs can reference it)
function Level:initialize()

	-- do an initial respawn
	self:initialSpawn()

	-- run any init scripts if they're there
	if self.initFile then
		local initFile = modio:find(self.initFile)
		if initFile then
			local sandbox = require 'base.script.singleton.sandbox' 
			return sandbox(assert(file[initFile]))
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

-- nil means don't set that particular layer
function Level:setTile(x,y, tileIndex, fgTileIndex, bgTileIndex, backgroundIndex)
	x = math.floor(x)
	y = math.floor(y)
	if x<1 or y<1 or x>self.size[1] or y>self.size[2] then return 0 end
	local index = (x-1)+self.size[1]*(y-1)
	if tileIndex then self.tileMap[index] = tileIndex end
	if fgTileIndex then self.fgTileMap[index] = fgTileIndex end
	if bgTileIndex then self.bgTileMap[index] = bgTileIndex end
	if backgroundIndex then self.backgroundMap[index] = backgroundIndex end
end

-- update downsampled texture of the whole map
-- if you call level:setTile then you have to manually call this
-- assumes that x1,y1,x2,y2 are integers in range [1,size] 
local gl
function Level:refreshTileTexelsForLayer(x1,y1,x2,y2, tileMap, tileTex)
	local tilesWide = self.texpackTex.width / self.tileSize
	local tilesHigh = self.texpackTex.height / self.tileSize
	local tilesInTexpack = tilesWide * tilesHigh

	if x2 < 1 or y2 < 1 or x1 > self.size[1] or y1 > self.size[2] then return end
	x1 = math.max(x1, 1)
	y1 = math.max(y1, 1)
	x2 = math.min(x2, self.size[1])
	y2 = math.min(y2, self.size[2])
	if x1 < x2 or y1 < y1 then return end

	tileTex:bind()
	for y = y1,y2 do
		gl.glTexSubImage2D(tileTex.target, 0, x1 - 1, y1 - 1, x2 - x1 + 1, 1, gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE, tileMap + (x1 - 1) + self.size[1] * (y1 - 1))
	end
	tileTex:unbind()
end
function Level:refreshFgTileTexels(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.fgTileMap, self.fgTileTex)
end
function Level:refreshBgTileTexels(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.bgTileMap, self.bgTileTex)
end
function Level:refreshBackgroundTexels(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.backgroundMap, self.backgroundTex)
end

function Level:makeEmpty(x,y)
	-- setTile calls floor()
	self:setTile(x,y,0,0,0)
	-- but refreshTileTexels does not ...
	x = math.floor(x)
	y = math.floor(y)
	-- assume the game is calling it ,not the editor, so i have to refresh stuff again
	self:refreshFgTileTexels(x,y,x,y)
	self:refreshBgTileTexels(x,y,x,y)
	self:refreshBackgroundTexels(x,y,x,y)
end

function Level:update(dt)
	self.pos[1] = self.pos[1] + self.vel[1] * dt
	self.pos[2] = self.pos[2] + self.vel[2] * dt
end

function Level:draw(R, viewBBox)
	gl = R.gl -- save externally for refreshFgTileTexels
	local patch = require 'base.script.patch'

	-- [[ testing lighting
if useLighting then
	local player = game.players[1]
	if player then
		local gl = R.gl
		gl.glEnable(gl.GL_LIGHTING)
		gl.glEnable(gl.GL_LIGHT0)
		gl.glLightModelfv(gl.GL_LIGHT_MODEL_AMBIENT, vec4f(0,0,0,0).s)
		gl.glLightModelf(gl.GL_LIGHT_MODEL_LOCAL_VIEWER, 1)
		local t = self.roomProps[player.room]
		local l = t and t.lightAmbient or 0
		gl.glLightfv(gl.GL_LIGHT0, gl.GL_AMBIENT, vec4f(l,l,l,1).s)
		gl.glLightfv(gl.GL_LIGHT0, gl.GL_DIFFUSE, vec4f(1,1,1,1).s)
		gl.glLightfv(gl.GL_LIGHT0, gl.GL_SPECULAR, vec4f(1,1,1,1).s)
		gl.glLightfv(gl.GL_LIGHT0, gl.GL_POSITION, vec4f(player.pos[1], player.pos[2]+1, 1, 1).s)
		gl.glLightf(gl.GL_LIGHT0, gl.GL_CONSTANT_ATTENUATION, 0)
		--gl.glLightf(gl.GL_LIGHT0, gl.GL_LINEAR_ATTENUATION, 1/10)
		gl.glLightf(gl.GL_LIGHT0, gl.GL_QUADRATIC_ATTENUATION, 1/10^2)
		gl.glMaterialfv(gl.GL_FRONT_AND_BACK, gl.GL_AMBIENT, vec4f(1,1,1,1).s)
		gl.glMaterialfv(gl.GL_FRONT_AND_BACK, gl.GL_DIFFUSE, vec4f(1,1,1,1).s)
		gl.glMaterialfv(gl.GL_FRONT_AND_BACK, gl.GL_SPECULAR, vec4f(0,0,0,0).s)
		gl.glNormal3f(0,0,1)
	end
end
	--]]

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

	do	
		self.levelBgShader:use()	-- I could use the shader param but then I'd have to set uniforms as a table, which is slower
		if self.levelBgShader.uniforms.tileSize then
			gl.glUniform1f(self.levelBgShader.uniforms.tileSize.loc, self.tileSize)
		end
		if self.levelBgShader.uniforms.viewMin then
			gl.glUniform2f(self.levelBgShader.uniforms.viewMin.loc, bbox.min[1], bbox.min[2])
		end
		self.backgroundTex:bind(0)
		self.bgTileTex:bind(1)
		self.bgtexpackTex:bind(2)
		self.texpackTex:bind(3)
		self.backgroundStructTex:bind(4)
		R:quad(
			1, 1,
			self.size[1],
			self.size[2],
			0,0,
			1,1,
			0,
			1,1,1,1)
		self.backgroundStructTex:unbind(4)
		self.texpackTex:unbind(3)
		self.bgtexpackTex:unbind(2)
		self.bgTileTex:unbind(1)
		self.backgroundTex:unbind(0)
		self.levelBgShader:useNone()
	end
	
	-- draw objects
	-- [[ all at once
	for _,obj in ipairs(game.objs) do
		if not obj.drawn then
			obj:draw(R, viewBBox)
			obj.drawn = true
		end
	end
	--]]
	--[[ only touching visible tiles
	-- this doesn't render temp objects though ...
	-- I wasn't attching them to tile.objs because they aren't collidable
	-- should I be making two separate lists on tile?  one for collidable, one for drawable?
	for x=xmin,xmax do
		local col = self.objsAtTile[x]
		if col then
			for y=ymin,ymax do
				local tile = col[y]
				if tile then
					for _,obj in ipairs(tile.objs) do
						if not obj.drawn then
							obj:draw(R, viewBBox)
							obj.drawn = true
						end
					end
				end
			end
		end
	end
	--]]

	do	 --if ibbox.max[1] - ibbox.min[1] > glapp.width / self.overmapZoomLevel then
		self.levelFgShader:use()	-- I could use the shader param but then I'd have to set uniforms as a table, which is slower
		if self.levelFgShader.uniforms.tileSize then
			gl.glUniform1f(self.levelFgShader.uniforms.tileSize.loc, self.tileSize)
		end
		self.fgTileTex:bind(0)
		self.texpackTex:bind(1)
		R:quad(
			1, 1,
			self.size[1],
			self.size[2],
			0,0,
			1,1,
			0,
			1,1,1,1)
		self.texpackTex:unbind(1)
		self.fgTileTex:unbind(0)
		self.levelFgShader:useNone()
	end

	-- [[ testing lighting
	local gl = R.gl
	gl.glDisable(gl.GL_LIGHTING)
	--]]
end

return Level
