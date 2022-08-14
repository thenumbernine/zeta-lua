#!/usr/bin/env luajit

local ffi = require 'ffi'
local bit = require 'bit'
local table = require 'ext.table'
local string = require 'ext.string'
local file = require 'ext.file'
local tolua = require 'ext.tolua'

--[[ hmm ...
local gcmem = require 'ext.gcmem'
function gcmem.new(format, size)
	return ffi.new(format..'['..size..']')
end 
function gcmem.free() end
--]]

local mapName = ... or 'mine'
local dir = 'mario/maps/'..mapName
os.execute('mkdir '..dir)
local box2 = require 'vec.box2'
local Image = require 'image'
local parser = require 'parser'

local tilePath = dir..'/tile.png'
local origTilePath = '../zeta2d-original/'..dir..'/tile.png'
assert(os.fileexists(origTilePath), "couldn't find the original tile file")

local oldSearchPath = table{'mario', 'base'}
local newSearchPath = table{'mario', 'base'}

-- gather all <mod>/script/tiles.lua
-- replace 'require' calls with arg strings
local origTileTypes = table()
for _,path in ipairs(oldSearchPath) do
	local inc = '../zeta2d-original/'..path..'/script/tiles.lua'
	local tree = parser.parse(file[inc])
	local function rmap(x)
		for k,v in pairs(x) do
			if type(v) == 'table' then
				if v.type == 'call' and v.func.name == 'require' then
					x[k] = v.args[1]
				else
					rmap(v)
				end
			end
		end
	end
	rmap(tree)
	print()
	print('inc',inc)
	print('tree',tree)
	origTileTypes:append(assert(load(tostring(tree)))())
end
print()
print'oldTileTypes'
for _,origTileType in ipairs(origTileTypes) do
	print(tolua(origTileType))
end
print('got',#origTileTypes,'origTileTypes')

local backgrounds = assert(load('return '..file['mario/script/backgrounds.lua']))()
local backgroundName = assert(({
	doors = 'cave',
	fight = 'cave',
	gen = 'cave',
	level1 = 'cave',	-- technically this has a template layer, which should be used for backgrounds
	lifttest = 'cave',
	mine = 'cave',
	mine2 = 'cave',
	['pswitch-fluids'] = 'cave',
	['pswitch-platform'] = 'cave',
	race = 'cave',
})[mapName])
local backgroundIndex = assert(table.find(backgrounds, nil, function(background)
	print('searching ',tolua(background))
	return background.name == backgroundName
end), "failed to find background "..backgroundName)
print('backgroundIndex',backgroundIndex)

local newTileTypes = table()
for i=#newSearchPath,1,-1 do
	local ls = 
		string.split(
			string.trim(
				file[newSearchPath[i]..'/script/tiletypes.lua']
			),
			'\n'
		)
		:map(function(l) return l:match("'(.-)'") or '' end)
		:filter(function(l) return #l > 0 end)
	newTileTypes:append(ls)
end
print()
print'newTileTypes'
for _,newTileType in ipairs(newTileTypes) do
	print(tolua(newTileType))
end
print('got',#newTileTypes,'newTileTypes')
print()

local origTileImage = Image(origTilePath)
local w,h,ch = origTileImage:size()
assert(ch == 4)
local newTileImage = Image(w,h,ch,'unsigned char')
local fgTileImage = Image(w,h,ch,'unsigned char')
local bgTileImage = Image(w,h,ch,'unsigned char')
local backgroundImage = Image(w,h,ch,'unsigned char')

local spawnInfos = table()

assert(ch == 4)

local function writepixel(image,x,y,rgba)
	image.buffer[0+ch*(x+w*y)] = bit.band(0xff, rgba) 
	image.buffer[1+ch*(x+w*y)] = bit.band(0xff, bit.rshift(rgba, 8))
	image.buffer[2+ch*(x+w*y)] = bit.band(0xff, bit.rshift(rgba, 16))
	image.buffer[3+ch*(x+w*y)] = bit.band(0xff, bit.rshift(rgba, 24))
end

local tw = 64	-- width of texpack, in tiles
local newIndexForTile = {
	['base.script.tile.solid'] = {1+4*tw,1},
	['base.script.tile.slope45'] = {1+4*tw,1},
	['base.script.tile.slope27'] = {1+4*tw,1},
	['base.script.tile.water'] = {1+8,1},
	['mario.script.tile.notsolid'] = {1+8,1},
	['mario.script.tile.fence'] = {0,1+12*tw},
	['mario.script.tile.stone'] = {1+9,1},
	['mario.script.tile.spin'] = {1+4,1},
	['mario.script.tile.coin'] = {1+4+2*tw,1},
	['mario.script.tile.anticoin'] = {1+12,1},
	['mario.script.tile.pickup'] = {1+13,1},
	['mario.script.tile.vine'] = {1+10,1},
	['mario.script.tile.spike'] = {1+4*tw,1},
	['mario.script.tile.question'] = {1+4+1*tw,1},
	['mario.script.tile.break'] = {1+4+3*tw,1},
	['mario.script.tile.exclaim'] = {1+11,1},
	['mario.script.tile.exclaimoutline'] = {1+14,1},
}

for y=0,h-1 do
	for x=0,w-1 do
		local r = origTileImage.buffer[0+ch*(x+w*y)]
		local g = origTileImage.buffer[1+ch*(x+w*y)]
		local b = origTileImage.buffer[2+ch*(x+w*y)]
		local a = origTileImage.buffer[3+ch*(x+w*y)]
		local origTileIndex = bit.bor(
			b,
			bit.lshift(g, 8),
			bit.lshift(r, 16))
		-- find origTileIndex in origTileTypes
		-- then find the spawn name in mario/script/tiletypes.lua
		-- then write that index to the map
		local origTileType = select(2, origTileTypes:find(nil, function(t) 
			return t.color == origTileIndex 
		end))
		
		local fgTileIndex = 0
		local bgTileIndex = 0

		if origTileType then
			local nf, nb = table.unpack(newIndexForTile[origTileType and origTileType.tile or nil] or {})
			fgTileIndex = nf or fgTileIndex
			bgTileIndex = nb or bgTileIndex
		end

		local newTileIndex = 0
		if not origTileType then
			print("failed to find origTileType for origTileIndex "..('%x'):format(origTileIndex))
		else
			local newTileType
			if origTileIndex == 0xffffff then -- empty
			else
				newTileIndex, newTileType = newTileTypes:find(nil, function(t)
					return t == origTileType.tile
				end)
			end
			
			-- look for spawn
			local foundSpawn
			if origTileType.spawn then
				foundSpawn = true
				spawnInfos:insert{
					pos = {x+1.5, h-y},
					spawn = origTileType.spawn,
				}
			end
			if origTileType.startPos then
				foundSpawn = true
				spawnInfos:insert{
					pos = {x+1.5, h-y},
					spawn = 'base.script.obj.start',
				}
			end
			
			if not newTileIndex and not foundSpawn then
				print('got unknown tile type '..('%x'):format(origTileIndex))
			end
			newTileIndex = newTileIndex or 0
		end	
		--print(('%x'):format(origTileIndex), tolua(origTileType), ('%x'):format(newTileIndex), tolua(newTileType))

		writepixel(newTileImage, x,y, newTileIndex)
		writepixel(fgTileImage, x,y, fgTileIndex)
		writepixel(bgTileImage, x,y, bgTileIndex)
		writepixel(backgroundImage, x,y, backgroundIndex)
	end
end

newTileImage:save(dir..'/tile.png')
fgTileImage:save(dir..'/tile-fg.png')
bgTileImage:save(dir..'/tile-bg.png')
backgroundImage:save(dir..'/background.png')
file[dir..'/spawn.lua'] = '{\n'
	..spawnInfos:map(function(spawnInfo)
		return '\t'..tolua(spawnInfo)..','
	end):concat'\n'
	..'}\n'
