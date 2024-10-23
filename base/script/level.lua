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
local table = require 'ext.table'
local path = require 'ext.path'
local fromlua = require 'ext.fromlua'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local modio = require 'base.script.singleton.modio'
local game = require 'base.script.singleton.game'	-- this should exist by now, right?
local Image = require 'image'
local glapp = require 'base.script.singleton.glapp'
local vec4f = require 'vec-ffi.vec4f'
local SpawnInfo = require 'base.script.spawninfo'
local glreport = require 'gl.report'

local gl

local int = ffi.new'int[1]'
local function glGetInteger(symbol)
	gl.glGetIntegerv(symbol, int)
	return tonumber(int[0])
end

-- here's the data that gets copied to the GPU
ffi.cdef[[
typedef struct background_t {
	float x, y, w, h;
	float scaleX, scaleY;
	float scrollX, scrollY;
} background_t;
]]


--[[
how the sprites will work?
each tile already has a list of attached objects
we just need to encode that in a texture.
have a texture2D of shorts that contains offset and size of sprite lists at each tile
	(null means no such list)
then have a texture1D of shorts of offsets to the visSprite_t texture
then have a texture2D for the visSprite_t data

so how to quickly encode the list of all tile objects into a texture?
we would have to keep track of a list of all tiles that do have objects
--]]
ffi.cdef[[
typedef struct visSprite_t {
	float x, y, w, h;		//vertexes

	float tx, ty, tw, th;	//texture coords

	float r, g, b, a;		//color

	float rcx, rcy, angle;	//rotation center, angle

	float padding;			//make things float[4] aligned

	/*
	TODO uniforms and shader, but that wouldn't go in here
	maybe pre-register sets of shaders (and uniforms and textures?) at the beginning of a level
	and give each object a lookup into that,
	and those pre-registered shader codes can be inlined into the raytracer?
	so that should be inlined as well, and constructed per level (pre-registered at level load)
	float shaderIndex;
	union {
		shaderUniforms1_t u1;
		shaderUniforms2_t u2;
		...
	};
	*/
} visSprite_t;
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

-- also in base.script.obj.object
Level.subbehavior = require 'base.script.behaviors'

-- how many pixels wide and high a tile is
-- used for sprites and for texpack tiles
Level.tileSize = 16

-- how many tiles in a 'maptile'
-- i.e. room size
Level.mapTileSize = vec2(32, 32)

-- pixel width of a tile for the renderer to switch to overworld map
Level.overmapZoomLevel = 16

-- max number of sprites visible (in the raytracer)
Level.visSpriteMax = 512

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

	-- store as a global
	gl = game.R.gl

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
	local tileImage
	if not tileFile then
		print("couldn't find file at "..mappath.."/tile.png ... loading default instead")
		tileImage = Image(32, 32, 4, 'unsigned char')
		ffi.fill(tileImage.buffer, tileImage.channels * tileImage.width * tileImage.height * ffi.sizeof(tileImage.format))
	else
		tileImage = Image(tileFile)
	end
	self.size = vec2(tileImage:size())

	-- hmm, ugly hack ...
	do
		local maptilesizepath = mappath..'/maptilesize.lua'
		local searchMapTileSizePath = modio:find(maptilesizepath)
print('maptilesizepath', maptilesizepath)
		if searchMapTileSizePath then
print('exists')
			self.mapTileSize = vec2(table.unpack(
				assert(fromlua(assert(path(searchMapTileSizePath):read())))
			))
print('found self.mapTileSize', self.mapTileSize)
		end
	end
print('self.mapTileSize', self.mapTileSize)

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
		local fn = 'script/backgrounds.lua'
		xpcall(function()
			self.backgrounds = table((assert(fromlua(assert(path(assert(modio:find(fn))):read())))))
		end, function(err)
			print('when loading '..fn)
			print(err..'\n'..debug.traceback())
			self.backgrounds = table()
		end)
		self.bgtexpackFilename = modio:find(mappath..'/bgtexpack.png')
		if not self.bgtexpackFilename then
			self.bgtexpackFilename = modio:find'bgtexpack.png'
		end
		if not self.bgtexpackFilename then
			-- fallback - no backgrounds
			self.bgtexpackImage = Image(1024,1024,4,'unsigned char')
			print("can't find bgtexpack.png anywhere -- using an empty image")
		else
			self.bgtexpackImage = Image(self.bgtexpackFilename)
		end
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
		self.texpackTex = Tex2D{
			image = self.texpackImage,
			internalFormat = gl.GL_RGBA,
			format = gl.GL_RGBA,
			generateMipmap = true,	-- only used for the overworld texture
			minFilter = gl.GL_LINEAR,
			magFilter = gl.GL_NEAREST,
		}
	end

	do
		-- GL_LUMINANCE16 is more appropriate but not always supported, esp not always with 16 whole bits.
		-- GL_LUMINANCE_ALPHA is more supported
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
			-- should I round this up to power of two, for accurate texel access?
			-- or should I use some extension to access the texture using integer coordinates?
			width = math.ceil(ffi.sizeof'background_t' / (4 * ffi.sizeof'float')),	-- should be 2
			height = #self.backgrounds,
			format = gl.GL_RGBA,
			type = gl.GL_FLOAT,
			data = ffi.cast('float*', self.backgroundStructData),
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}
		assert(self.backgroundStructTex.width == 2)		-- if it's not then change the lookups below


		-- TODO for some reason on the sprite scenegraph stuff, GL_LUMINANCE_ALPHA isn't cutting it
		-- even though it works fine for the tile info in the map
		-- so figure out why, or make a few pathways depending on the graphics card's support?

		-- offset into the sprite table
		self.spriteListOffsetTileMap = ffi.new('vec4f_t[?]', self.size[1] * self.size[2])
		ffi.fill(self.spriteListOffsetTileMap, ffi.sizeof'vec4f_t' * self.size[1] * self.size[2])

		-- map from x,y to offset in spriteListData
		self.spriteListOffsetTileTex = Tex2D{
			internalFormat = gl.GL_RGBA32F,
			width = self.size[1],
			height = self.size[2],
			format = gl.GL_RGBA,
			type = gl.GL_FLOAT,
			data = self.spriteListOffsetTileMap,
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}


		-- map to each entry in the visSprite_t table
		self.spriteListMax = 512
		--self.spriteListMax = 16
		self.spriteListData = ffi.new('vec4f_t[?]', self.spriteListMax)
		self.spriteListTex = Tex2D{
			internalFormat = gl.GL_RGBA32F,
			width = 1,
			height = self.spriteListMax,
			format = gl.GL_RGBA,
			type = gl.GL_FLOAT,
			data = self.spriteListData,
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}


		-- the visSprite_t data
		self.visSpriteData = ffi.new('visSprite_t[?]', self.visSpriteMax)

		self.visSpriteTex = Tex2D{
			internalFormat = gl.GL_RGBA32F,
			width = math.ceil(ffi.sizeof'visSprite_t' / (4 * ffi.sizeof'float')),
			height = self.visSpriteMax,
			format = gl.GL_RGBA,
			type = gl.GL_FLOAT,
			data = ffi.cast('float*', self.visSpriteData),
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		}
		assert(self.visSpriteTex.width == 4)


		local GLProgram = require 'gl.program'

		-- render the background image (with scrolling effects) and the background tiles
		self.levelBgShader = GLProgram{
			vertexCode = [[
#version 410
precision highp float;

layout(location=0) in vec2 vertex;

out vec2 pos;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;		//default shader rect.  x,y = pos, z,w = size
uniform vec4 defaultTexRect;	//default shader texcoords.  xy = texcoord offset, zw = texcoord size

void main() {
	pos = defaultRect.xy + defaultRect.zw * vertex;
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;
	gl_Position = mvProjMat * vec4(pos, 0., 1.);
}
]],
			fragmentCode = [[
#version 410
precision highp float;

in vec2 pos;
in vec2 tc;

out vec4 fragColor;

uniform vec2 viewMin;	//used by bg for scrolling effect

uniform float tileSize;

uniform sampler2D backgroundTex;		// unsigned char, reference into backgroundStructTex
uniform sampler2D bgTileTex;			// unsigned short <=> luminance_alpha, reference into texpackTex

uniform sampler2D texpackTex;			//bgTileTex uses this
uniform vec2 texpackTexSize;

uniform sampler2D backgroundStructTex;	// reference into bgtexpackTex
uniform float backgroundStructTexSize;

uniform sampler2D bgtexpackTex;
uniform vec2 bgtexpackTexSize;	// TODO bake this into the backgroundStruct data?


void main() {
	//TODO store this outside the shader and pass in as a uniform?
	float tilesWide = texpackTexSize.x / tileSize;
	float tilesHigh = texpackTexSize.y / tileSize;


	vec2 posInTile = pos - floor(pos);
	posInTile.y = 1. - posInTile.y;		//because y is flipped in our image coordinate system

	fragColor = vec4(0.);

	// background color
	float bgIndexV = texture(backgroundTex, tc).x;
	float bgIndex = 255. * bgIndexV;
	if (bgIndex > 0.) {
		// lookup the background region from an array/texture somewhere ...
		// it should specify x, y, w, h, scaleX, scaleY, scrollX, scrollY
		// so 8 channels per background in all
		float u = (bgIndex - .5) / backgroundStructTexSize;
		vec4 xywh = texture(backgroundStructTex, vec2(.25, u));
		vec2 xy = xywh.xy;
		vec2 wh = xywh.zw;
		vec4 scaleScroll = texture(backgroundStructTex, vec2(.75, u));
		vec2 scale = scaleScroll.xy;
		vec2 scroll = scaleScroll.zw;

		vec2 uv = pos - viewMin * scroll;
		uv.y = 1. - uv.y;
		uv /= scale;
		uv = mod(uv, 1.);
		uv = (uv * wh + xy) / bgtexpackTexSize;
		vec4 backgroundColor = texture(bgtexpackTex, uv);

		fragColor.rgb = mix(fragColor.rgb, backgroundColor.rgb, backgroundColor.a);
	}

	// bg tile color
	vec2 bgTileIndexV = texture(bgTileTex, tc).zw;
	float bgTileIndex = 255. * (bgTileIndexV.x + 256. * bgTileIndexV.y);
	if (bgTileIndex > 0.) {
		--bgTileIndex;
		float ti = mod(bgTileIndex, tilesWide);
		float tj = (bgTileIndex - ti) / tilesWide;

		// hmm, stamp stuff goes here, do I want to keep it?

		vec4 bgColor = texture(texpackTex, (vec2(ti, tj) + posInTile) / vec2(tilesWide, tilesHigh));

		fragColor.rgb = mix(fragColor.rgb, bgColor.rgb, bgColor.a);
	}

	//hmm, how to handle alpha, since this won't mix the same as applying these two layers separately
	fragColor.a = 1.;
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
		}:useNone()

		self.levelFgShader = GLProgram{
			vertexCode = [[
#version 410
precision highp float;

layout(location=0) in vec2 vertex;

out vec2 pos;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;		//default shader rect.  x,y = pos, z,w = size
uniform vec4 defaultTexRect;	//default shader texcoords.  xy = texcoord offset, zw = texcoord size

void main() {
	pos = defaultRect.xy + defaultRect.zw * vertex;
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;
	gl_Position = mvProjMat * vec4(pos, 0., 1.);
}
]],
			fragmentCode = [[
#version 410
precision highp float;

in vec2 pos;	//world coordinates.   TODO why varying?  why not just tc * levelSize ?
in vec2 tc;	//in [0,1]^2

out vec4 fragColor;

uniform sampler2D fgTileTex;
uniform sampler2D texpackTex;

uniform float tileSize;
uniform vec2 texpackTexSize;

void main() {
	vec2 posInTile = pos - floor(pos);
	posInTile.y = 1. - posInTile.y;		//because y is flipped in our image coordinate system

	float tilesWide = texpackTexSize.x / tileSize;
	float tilesHigh = texpackTexSize.y / tileSize;

	fragColor = vec4(0.);

	// fg tile color
	vec2 fgTileIndexV = texture(fgTileTex, tc).zw;	// z = lum = lo byte, w = alpha = hi byte
	float fgTileIndex = 255. * (fgTileIndexV.x + 256. * fgTileIndexV.y);	// this looks too horrible to be correct
	if (fgTileIndex > 0.) {	//0 = transparent
		--fgTileIndex;
		float ti = mod(fgTileIndex, tilesWide);
		float tj = (fgTileIndex - ti) / tilesWide;

		ti = floor(ti + .5);
		tj = floor(tj + .5);

		// hmm, stamp stuff goes here, do I want to keep it?

		vec4 fgColor = texture(texpackTex, (vec2(ti, tj) + posInTile) / vec2(tilesWide, tilesHigh));

		fragColor.rgb = mix(fragColor.rgb, fgColor.rgb, 1. - fragColor.a);
		fragColor.a = fgColor.a;
	}
}
]],
			uniforms = {
				fgTileTex = 0,
				texpackTex = 1,
				texpackTexSize = {self.texpackTex.width, self.texpackTex.height},
			},
		}:useNone()

		local shaderCode = assert(path'base/script/raytrace.shader':read())
		self.levelSceneGraphShader = GLProgram{
			vertexCode = table{
				'#version 410',	-- must be first
				'precision highp float;',
				'#define VERTEX_SHADER 1',
				shaderCode,
			}:concat'\n',

			fragmentCode = table{
				'#version 410',	-- must be first
				'precision highp float;',
				'#define FRAGMENT_SHADER 1',
				shaderCode
			}:concat'\n',

			uniforms = {

				levelSize = self.size,

				backgroundTex = 2,
				fgTileTex = 0,
				bgTileTex = 3,
				spriteListOffsetTileTex = 6,

				texpackTex = 1,
				texpackTexSizeInTiles = {self.texpackTex.width / self.tileSize, self.texpackTex.height / self.tileSize},

				backgroundStructTex = 4,
				backgroundStructTexSize = #self.backgrounds,

				bgtexpackTex = 5,
				bgtexpackTexSize = {self.bgtexpackTex.width, self.bgtexpackTex.height},

				spriteListTex = 7,
				spriteListMax = assert(self.spriteListMax),

				visSpriteTex = 8,
				visSpriteMax = self.visSpriteMax,

				spriteSheetTex = 9,
			},
		}:useNone()

		-- I'm disabling this by default for now
		local raytraceSprites = game.raytraceSprites
		if raytraceSprites then
			-- animation system debugging
			-- and raytracer
			-- write out all unique sprite textures
			local animsys = require 'base.script.singleton.animsys'
			local rects = table()
			local totalPixels = 0
			for spriteName, sprite in pairs(animsys.sprites) do
				for frameName,frame in pairs(sprite.frames) do
					local tex = frame.tex
					totalPixels = totalPixels + tex.width * tex.height
					rects:insert{
						sprite = spriteName,
						frame = frameName,
						tex = tex,
						x = 0,
						y = 0,
						w = tex.width,
						h = tex.height,
					}
				end
			end
			if totalPixels == 0 then
				-- NOTICE this will error if the animation system fails to load
				error("no pixels found in any of your "..#table.keys(animsys.sprites).." sprites could be loaded.")
			end
			-- what percent error should we give it?
			totalPixels = math.ceil(totalPixels * 1.5)
			local spriteSheetWidth = math.ceil(math.sqrt(totalPixels))

			require 'base.script.rectpack'(rects, spriteSheetWidth, spriteSheetWidth, 512)
			local spriteSheetImage = Image(spriteSheetWidth, spriteSheetWidth, 4, 'unsigned char')
			for _,rect in ipairs(rects) do
				--[[ color randomly
				local vec3d = require 'vec-ffi.vec3d'
				local r, g, b = (vec3d(math.random(), math.random(), math.random()):normalize() * 255):map(math.floor):unpack()
				for y=rect.y,rect.y + rect.h-1 do
					for x=rect.x,rect.x + rect.w-1 do
						local index = spriteSheetImage.channels * (x + spriteSheetImage.width * y)
						spriteSheetImage.buffer[0 + index] = r
						spriteSheetImage.buffer[1 + index] = g
						spriteSheetImage.buffer[2 + index] = b
						if spriteSheetImage.channels == 4 then
							spriteSheetImage.buffer[3 + index] = 255
						end
					end
				end
				--]]
				-- [[ color with the sprites themselves
				local srcTex = rect.tex
				local srcData = ffi.new('unsigned char[?]', srcTex.width * srcTex.height * spriteSheetImage.channels)
				local format = assert(({
					[3] = gl.GL_RGB,
					[4] = gl.GL_RGBA,
				})[spriteSheetImage.channels], "couldn't determine format from # channels "..spriteSheetImage.channels)
				srcTex:toCPU(srcData)
				srcTex:unbind()
				for y=0,rect.h-1 do
					local dstY = y + rect.y
					for x=0,rect.w-1 do
						local dstX = x + rect.x
						if dstX >= 0 and dstX < spriteSheetImage.width
						and dstY >= 0 and dstY < spriteSheetImage.height
						then
							local srcIndex = spriteSheetImage.channels * (x + rect.w * y)
							local dstIndex = spriteSheetImage.channels * (dstX + spriteSheetImage.width * dstY)
							for ch=0,spriteSheetImage.channels-1 do
								spriteSheetImage.buffer[ch + dstIndex] = srcData[ch + srcIndex]
							end
						else
							error'here'
						end
					end
				end
				--]]
			end

			-- save the rect positions in animsys
			for _,rect in ipairs(rects) do
				local frame = animsys.sprites[rect.sprite].frames[rect.frame]
				frame.x = rect.x
				frame.y = rect.y
				frame.w = rect.w
				frame.h = rect.h
			end

			--[[ debug write it out
			print(require 'ext.tolua'(rects:mapi(function(rect)
				rect = table(rect)
				rect.tex = nil
				return rect
			end)))
			--]]
			-- [[ debug save it
			spriteSheetImage:save'packedsprites.png'
			--]]

			assert(spriteSheetImage.channels == 4)
			self.spriteSheetTex = Tex2D{
				image = spriteSheetImage,
				internalFormat = gl.GL_RGBA,
				format = gl.GL_RGBA,
				generateMipmap = true,
				minFilter = gl.GL_LINEAR,
				magFilter = gl.GL_NEAREST,
			}
		end


		local op = require 'ext.op'
		local glmaxs = {}
		for _,symbol in ipairs{
			'GL_MAX_TEXTURE_UNITS',					-- deprecated
			'GL_MAX_TEXTURE_IMAGE_UNITS',			-- fragment shader max textures
			'GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS',	-- vertex shader max textures
			'GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS',	-- v.s. + f.s. + g.s. max textures
			'GL_MAX_TEXTURE_SIZE',					-- max texture width & height
		} do
			local k = op.safeindex(gl, symbol)
			if k then
				glmaxs[symbol] = glGetInteger(gl[symbol])
				print(symbol..' = '..glmaxs[symbol])
			else
				print(symbol..' ... not defined')
			end
		end

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
				local spawnInfos = assert(fromlua(path(spawnInfoFile):read()))
				self:processSpawnInfoArgs(spawnInfos)
			end
		end
	end

	local roomsFile = args.roomsFile or (mappath and mappath..'/rooms.lua')
	if roomsFile then roomsFile = modio:find(roomsFile) end
	if roomsFile then
		self.roomProps = assert(fromlua(path(roomsFile):read()))
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
	-- refreshTileTexelsForLayer
	self:onUpdateTileMap(1,1,self.size[1],self.size[2])
	self:onUpdateFgTileMap(1,1,self.size[1],self.size[2])
	self:onUpdateBgTileMap(1,1,self.size[1],self.size[2])
	self:onUpdateBackgroundMap(1,1,self.size[1],self.size[2])
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
			return sandbox(assert(path(initFile):read()))
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
	if x<1 or y<1 or x>self.size[1] or y>self.size[2] then
		return --self.tileTypes[0]	-- but there is no empty tile class ...
	end
	local tileIndex = self.tileMap[(x-1)+self.size[1]*(y-1)]

	local tileType = self.tileTypes[tileIndex]
	if not tileType then
		return --self.tileTypes[0]
	end
	return tileType
end

function Level:getTileWithOffset(x,y)
	x = x - self.pos[1]
	y = y - self.pos[2]
	return self:getTile(x,y)
end

-- nil means don't set that particular layer
function Level:setTile(x, y, tileIndex, fgTileIndex, bgTileIndex, backgroundIndex, dontUpdateTexs)
	x = math.floor(x)
	y = math.floor(y)
	if x<1 or y<1 or x>self.size[1] or y>self.size[2] then return 0 end
	local index = (x-1)+self.size[1]*(y-1)
	if tileIndex then
		self.tileMap[index] = tileIndex
		-- TODO change 'dontUpdateTexs' to 'dontOnUpdate' ?
		self:onUpdateTileMap(x,y,x,y)
	end
	if fgTileIndex then
		self.fgTileMap[index] = fgTileIndex
		if not dontUpdateTexs then
			self:onUpdateFgTileMap(x,y,x,y)
		end
	end
	if bgTileIndex then
		self.bgTileMap[index] = bgTileIndex
		if not dontUpdateTexs then
			self:onUpdateBgTileMap(x,y,x,y)
		end
	end
	if backgroundIndex then
		self.backgroundMap[index] = backgroundIndex
		if not dontUpdateTexs then
			self:onUpdateBackgroundMap(x,y,x,y)
		end
	end
end

-- update downsampled texture of the whole map
-- if you call level:setTile then you have to manually call this
-- assumes that x1,y1,x2,y2 are integers in range [1,size]
-- gltype should correspond with the texture being passed, and its associated ctype should be the type of tileMap
function Level:refreshTileTexelsForLayer(x1,y1,x2,y2, tileMap, tileTex, internalFormat, gltype)
--[[
	assert(tileTex.internalFormat == internalFormat, "tileTex.internalFormat was "..tileTex.internalFormat.." but you are using "..internalFormat)
	assert(tileTex.type == gltype, "tileTex.type was "..tileTex.type.." but you are using "..gltype)
	--assert(ffi.typeof(GLTex2D.cTypeForGLType[gltype]) == fi.typeof(timeMap[0]))
--]]
	local tilesWide = self.texpackTex.width / self.tileSize
	local tilesHigh = self.texpackTex.height / self.tileSize
	local tilesInTexpack = tilesWide * tilesHigh

	if x2 < 1 or y2 < 1 or x1 > self.size[1] or y1 > self.size[2] then return end
	x1 = math.max(x1, 1)
	y1 = math.max(y1, 1)
	x2 = math.min(x2, self.size[1])
	y2 = math.min(y2, self.size[2])
	if x2 < x1 or y2 < y1 then return end

	tileTex:bind()
	for y = y1,y2 do
		gl.glTexSubImage2D(tileTex.target, 0, x1 - 1, y - 1, x2 - x1 + 1, 1, internalFormat, gltype, tileMap + (x1 - 1) + self.size[1] * (y - 1))
	end
	tileTex:unbind()
end

function Level:onUpdateTileMap(x1,y1,x2,y2)
	-- nothing by default
end
-- TODO rename these to just 'refreshFgTile' etc ... and have the default behavior of refreshing be ... to update the texels
-- or maybe instead of 'refresh', call it 'OnUpdate' ?
function Level:onUpdateFgTileMap(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.fgTileMap, self.fgTileTex, gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE)
end
function Level:onUpdateBgTileMap(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.bgTileMap, self.bgTileTex, gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE)
end
function Level:onUpdateBackgroundMap(x1,y1,x2,y2)
	return self:refreshTileTexelsForLayer(x1, y1, x2, y2, self.backgroundMap, self.backgroundTex, gl.GL_LUMINANCE, gl.GL_UNSIGNED_BYTE)
end

function Level:makeEmpty(x,y)
	self:setTile(x, y, 0, 0, 0, nil)
end

function Level:update(dt)
	self.pos[1] = self.pos[1] + self.vel[1] * dt
	self.pos[2] = self.pos[2] + self.vel[2] * dt
end

local vec4i = require 'vec-ffi.vec4i'
local viewport = vec4i()

-- TODO just pass the client index
function Level:draw(R, viewBBox, playerPos)
	local patch = require 'base.script.patch'

	-- TODO how to toggle this ... hmmm
	local raytraceSprites = game.raytraceSprites

	local editor = require 'base.script.singleton.editor'()
	if editor.active then
		raytraceSprites = false
	end

	-- [[ raytracing
	if raytraceSprites then
		self:initQuadRenderer()

		local pushQuad = R.quad
		R.quad = function(r, ...)
			return self:addQuad(...)
		end

		for _,obj in ipairs(game.objs) do
			if not obj.drawn then
				obj:draw(R, viewBBox)
				obj.drawn = true
			end
		end

		R.quad = pushQuad

		self:finalizeQuadRenderer()

		-- and now the visSpriteTex should have all the visSprite_t data
		-- spriteListTex should have lookups into visSpriteTex
		-- and spriteListOffsetTileTex should have lookups into spriteListTex
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

	-- separate renderers for foreground and background, and for each sprite
	if not raytraceSprites then
		do
			self.backgroundTex:bind(0)
			self.bgTileTex:bind(1)
			self.bgtexpackTex:bind(2)
			self.texpackTex:bind(3)
			self.backgroundStructTex:bind(4)
			
			R:quad(
				1,1,
				self.size[1],self.size[2],
				0,0,
				1,1,
				0,
				1,1,1,1,
				self.levelBgShader,
				{
					tileSize = self.tileSize,
					viewMin = bbox.min,
				},
				0,0
			)
		
			self.backgroundStructTex:unbind(4)
			self.texpackTex:unbind(3)
			self.bgtexpackTex:unbind(2)
			self.bgTileTex:unbind(1)
			self.backgroundTex:unbind(0)
		end

		-- TODO what about tile types that have animated sprites?
		-- hmmmmm

		-- draw objects
		for _,obj in ipairs(game.objs) do
			if not obj.drawn then
				obj:draw(R, viewBBox)
				obj.drawn = true
			end
		end

		do	 --if ibbox.max[1] - ibbox.min[1] > glapp.width / self.overmapZoomLevel then
			self.fgTileTex:bind(0)
			self.texpackTex:bind(1)

			R:quad(
				1,1,
				self.size[1],self.size[2],
				0,0,
				1,1,
				0,
				1,1,1,1,
				self.levelFgShader,
				{
					tileSize = self.tileSize,
				},
				0,0
			)

			self.texpackTex:unbind(1)
			self.fgTileTex:unbind(0)
		end
	else
		gl.glGetIntegerv(gl.GL_VIEWPORT, viewport.s)

		self.fgTileTex:bind(0)					-- map from tile to fg tex in texpack
		self.texpackTex:bind(1)					-- bg/fg tile texture data

		self.backgroundTex:bind(2)				-- map from tile to backgroundStruct
		self.bgTileTex:bind(3)					-- map from tile to bg tex in texpack
		self.backgroundStructTex:bind(4)		-- backgroundStruct including map into bgtexpack
		self.bgtexpackTex:bind(5)				-- background texture data

		self.spriteListOffsetTileTex:bind(6)	-- map from tile to sprite list
		self.spriteListTex:bind(7)				-- map from sprite list to visSprite_t list
		self.visSpriteTex:bind(8)

		self.spriteSheetTex:bind(9)

		R:quad(
			-1,-1,
			2,2,
			0,0,
			1,1,
			0,
			1,1,1,1,
			self.levelSceneGraphShader,
			{
				mvProjMat = R.identMat,
				viewBBox = {viewBBox.min[1], viewBBox.min[2], viewBBox.max[1], viewBBox.max[2]},
				texpackTexSizeInTiles = {
					self.texpackTex.width / self.tileSize,
					self.texpackTex.height / self.tileSize,
				},
				viewSize = game.viewSize,
				eyePos = {playerPos[1], playerPos[2] + 1.5},
				viewport = {viewport:unpack()},
				aspectRatioH_W = tonumber(viewport.w) / tonumber(viewport.z),
			},
			0,0
		)
		
		for i=9,0,-1 do
			gl.glActiveTexture(gl.GL_TEXTURE0 + i)
			gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		end
	end
end


-- matches base/script/singleton/class/renderer
local uvs = {
	vec2(0,0),
	vec2(1,0),
	vec2(1,1),
	vec2(0,1),
}



-- reset this every frame
Level.visSpriteCount = 0

function Level:initQuadRenderer()
	-- current index in the visSprite_t table
	self.visSpriteCount = 0

	-- map from tile index to table of all sprites at this tile
	self.spritesAtTile = {}

	--have a map from each tile to an entry in the spriteListData table
	-- TODO clear the whole thing?  or keep track of tiles and clear only them?
	--  which is faster?
	ffi.fill(self.spriteListOffsetTileMap, ffi.sizeof'vec4f_t' * self.size[1] * self.size[2])
end

-- very similar to Object:link()
function Level:addQuad(
		x,y,
		w,h,
		tx,ty,
		tw,th,
		angle,
		r,g,b,a,
		shader,		-- TODO
		uniforms,	-- TODO
		rcx, rcy
)
	if self.visSpriteCount > self.visSpriteMax then return end

	angle = angle or 0
	rcx = rcx or 0
	rcy = rcy or 0


	-- store in our sprite struct
	local visSpriteIndex = self.visSpriteCount
	self.visSpriteCount = self.visSpriteCount + 1
	local s = self.visSpriteData[visSpriteIndex]

	s.x = x
	s.y = y
	s.w = w
	s.h = h

	--[[
	s.tx = tx
	s.ty = ty
	s.tw = tw
	s.th = th
	--]]
	-- [[ remap to sprite sheet unit coordinates
	-- but that means we need to know the sprite/frame associated with the current R:quad being drawn ...
	local frame = self.currentFrame
	s.tx = (tx * frame.w + frame.x) / self.spriteSheetTex.width
	s.ty = (ty * frame.h + frame.y) / self.spriteSheetTex.height
	s.tw = (tw * frame.w) / self.spriteSheetTex.width
	s.th = (th * frame.h) / self.spriteSheetTex.height
	--]]

	s.r = r
	s.g = g
	s.b = b
	s.a = a

	s.angle = math.rad(angle)	-- convert from deg to rad.  maybe store cos(theta),sin(theat) as well?
	s.rcx = rcx
	s.rcy = rcy


	local costh, sinth
	if angle ~= 0 then
		local radians = math.rad(angle)
		costh = math.cos(radians)
		sinth = math.sin(radians)
	end

	-- quad min/max
	local qminx, qminy, qmaxx, qmaxy
	for i,uv in ipairs(uvs) do
		local rx, ry = w * uv[1], h * uv[2]
		if angle ~= 0 then
			rx, ry = rx - rcx, ry - rcy
			rx, ry = rx * costh - ry * sinth, rx * sinth + ry * costh
			rx, ry = rx + rcx, ry + rcy
		end
		local vx, vy = x + rx, y + ry
		if i == 1 then
			qminx, qmaxx = vx, vx
			qminy, qmaxy = vy, vy
		else
			qminx = math.min(qminx, vx)
			qmaxx = math.max(qmaxx, vx)
			qminy = math.min(qminy, vy)
			qmaxy = math.max(qmaxy, vy)
		end
	end


	local minx = qminx - self.pos[1]
	local miny = qminy - self.pos[2]
	local maxx = qmaxx - self.pos[1]
	local maxy = qmaxy - self.pos[2]


	if minx > self.size[1]
	or miny > self.size[2]
	or maxx < 1
	or maxy < 1
	then return end	-- no tiles to link to

	if minx < 1 then minx = 1 end
	if miny < 1 then miny = 1 end
	if maxx > self.size[1] then maxx = self.size[1] end
	if maxy > self.size[2] then maxy = self.size[2] end


	for x=math.floor(minx),math.floor(maxx) do
		for y=math.floor(miny),math.floor(maxy) do
			local tileIndex = (x - 1) + self.size[1] * (y - 1)
			local visSpriteIndexes = self.spritesAtTile[tileIndex]
			if not visSpriteIndexes then
				visSpriteIndexes = table()
				self.spritesAtTile[tileIndex] = visSpriteIndexes
			end
			visSpriteIndexes:insert(visSpriteIndex)
		end
	end
end

function Level:finalizeQuadRenderer()
--print'begin'

	-- build per-tile lookup
	local spriteListIndex = 0
	for tileIndex,visSpriteIndexes in pairs(self.spritesAtTile) do
		if spriteListIndex >= self.spriteListMax then break end

		-- map from the tile location to the index in the spriteListData
		self.spriteListOffsetTileMap[tileIndex].x = spriteListIndex + 1	-- reserve zero for no list.

--local x = tileIndex % self.size[1]
--local y = (tileIndex - x) / self.size[1]
--print('sprite list offset tile['..x..','..y..'] = '..(spriteListIndex + 1))

		-- don't overflow the buffer
		local numSpritesCanCopy = math.min(#visSpriteIndexes, self.spriteListMax - spriteListIndex - 1)
--print('writing sprite list count '..numSpritesCanCopy)

		-- first entry of the spriteListData is the number of visSprite_t references
		self.spriteListData[spriteListIndex].x = numSpritesCanCopy
		spriteListIndex = spriteListIndex + 1

		-- each successive entry is a visSprite_t reference, 0-based
		for i=1,numSpritesCanCopy do
--print('writing sprite list value '..visSpriteIndexes[i])
			self.spriteListData[spriteListIndex].x = visSpriteIndexes[i]
			spriteListIndex = spriteListIndex + 1
		end
	end

	-- upload the sprite list offset tile map to the GPU
	self.spriteListOffsetTileTex:bind()
	-- TODO only upload individual tiles that are modified?
	-- or TODO only upload the subrectangle that is modified?
	-- [[ or ... upload the whole thing?
	--gl.glTexSubImage2D(self.spriteListOffsetTileTex.target, 0, 0, 0, self.size[1], self.size[2], gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE, self.spriteListOffsetTileMap)
	gl.glTexSubImage2D(self.spriteListOffsetTileTex.target, 0, 0, 0, self.size[1], self.size[2], gl.GL_RGBA, gl.GL_FLOAT, self.spriteListOffsetTileMap)
	--]]
	self.spriteListOffsetTileTex:unbind()

--[[ upload looks correct
print('uploading '..spriteListIndex..' values to sprite list')
print('before upload: ')
for i=0,spriteListIndex-1 do
	io.write(' '..self.spriteListData[i].x)
end
print()
--]]

	-- now we upload sprite list to the GPU
	self.spriteListTex:bind()
	--gl.glTexSubImage2D(self.spriteListTex.target, 0, 0, 0, 1, spriteListIndex, gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE, self.spriteListData)
	gl.glTexSubImage2D(self.spriteListTex.target, 0, 0, 0, 1, spriteListIndex, gl.GL_RGBA, gl.GL_FLOAT, self.spriteListData)
	self.spriteListTex:unbind()

--[[
-- try to grab it again and see what comes out
self.spriteListTex:toCPU(self.spriteListData)
self.spriteListTex:unbind()
print('after upload: ')
for i=0,spriteListIndex-1 do
	io.write(' '..self.spriteListData[i])
end
print()
-- ...and the data matches
--]]


-- [=[
	-- and we upload visSpriteData to the GPU
	self.visSpriteTex:bind()
	gl.glTexSubImage2D(self.visSpriteTex.target, 0, 0, 0, self.visSpriteTex.width, self.visSpriteCount, gl.GL_RGBA, gl.GL_FLOAT, ffi.cast('float*', self.visSpriteData))
	self.visSpriteTex:unbind()
--]=]
end


return Level
