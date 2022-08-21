--[[
instructions:
copy this zeta/maps/gen/ 
to zeta/maps/gen####/ for some number ####

if we're loading from a save point then return
 .. but the code that calls this is wrapped in a block:
 "don't do this if game.savePoint exists"
 so why's it getting this far?
--]]
local string = require 'ext.string'
local table = require 'ext.table'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'

local mapbasename = 'gen'

getmetatable(game).viewSize = 16

if game.savePoint then return end

for _,obj in ipairs(game.objs) do obj.remove = true end
game.objs = table()
level.spawnInfos = table()

local modio = require 'base.script.singleton.modio'
local path = modio.search[1]..'/maps/'..modio.levelcfg.path
local seed = assert(tonumber(assert(path:match(string.patescape(mapbasename)..'(%d+)'))))

local blocksWide = level.size[1] / level.mapTileSize[1]
local blocksHigh = level.size[2] / level.mapTileSize[2]
local spawnInfos = table()

math.randomseed(seed)
print('seed',seed)

local simplexNoise = require 'simplexnoise.2d'
local function lInfLength(v) return math.max(math.abs(v[1]), math.abs(v[2])) end
local function l1Length(v) return math.abs(v[1]) + math.abs(v[2]) end
local function square(x) return x*x end


local emptyTileType = 0
local solidTileType = game:findTileType'base.script.tile.solid'
local ladderTileType = game:findTileType'base.script.tile.ladder'
local blasterBreakTileType = game:findTileType'zeta.script.tile.blasterbreak'

local emptyFgTile = 0
local solidFgTile = 0x000101
local ladderFgTile = 2


local offsets = {vec2(1,0), vec2(0,1), vec2(-1,0), vec2(0,-1)}
local sideForName={right=1, up=2, left=3, down=4}
local oppositeOffsetIndex = {3,4,1,2}
local axisForOffsetIndex = {1,2,1,2}
local positiveOffsetIndexForAxis = {1,2}
local negativeOffsetIndexForAxis = {3,4}


local function getGenMaxExtraDoors()
	return 0
	--return math.random(25)
end
local function getGenNumRoomsInChain()
	return math.random(2,4)
	--return math.random(10,20)
	--return math.random(100,200)
end
local function getGenRoomSize()
	return math.random(1,3)
	--return math.ceil(math.random() * math.random() * 20)
end
local probToRemoveInterRoomWalls = 0



local blocks = {}
local rooms = table()
for i=0,blocksWide-1 do
	blocks[i] = {}
	for j=0,blocksHigh-1 do
		blocks[i][j] = {
			pos = vec2(i, j),
			wall = {'solid', 'solid', 'solid', 'solid'},
		}
	end
end

local function getBlockAt(pos)
	local col = blocks[pos[1]]
	if not col then return nil end
	return col[pos[2]]
end


local class = require 'ext.class'
local Room = class()
function Room:init()
	rooms:insert(self)
	self.blocks = table()
end
function Room:addBlock(block)
	assert(not block.room)				-- assert no other room has it
	assert(not self.blocks:find(block))	-- assert we don't have it
	block.room = self					-- and link the two
	self.blocks:insert(block)
end

local function getNeighborOptions(rooms, criteria)
	local options = table()
	for _,room in ipairs(rooms) do
		for _,block in ipairs(room.blocks) do
			for offsetIndex,offset in ipairs(offsets) do
				local candidateblock = getBlockAt(block.pos + offset)
				if candidateblock and criteria(candidateblock, block, offset, offsetIndex) then
					options:insert{
						src = block,
						offset = vec2(offset),
						offsetIndex = offsetIndex,
						neighbor = candidateblock,
					}
				end
			end
		end
	end
	return options
end

local function getEmptyNeighborOptions(rooms)
	return getNeighborOptions(rooms, function(dstblock, srcblock, offset, offsetIndex)
		return not dstblock.room
	end)
end

--[[
builds a chain of rooms connected to 'startRoom' that is 'numRooms' long.
the first connecting door (and any other doors that connect outside of the chain) are connected with 'extDoorType'.
returns a table of all the new rooms created.
--]]
local function buildRoomChain(startRoom, startBlock, numRooms, extDoorType)
	local chainRooms = table()
	local lastRoom = startRoom
	local doorType = extDoorType or vec3(0,0,0)
	local lastOffsetIndex
	local lastBlock = startBlock
	
	-- metric
	local function f(a)
		-- l1-dist from the last block
		local roomDist = 0
		if lastBlock then
			roomDist = l1Length(lastBlock.pos - a.src.pos)
		end
		
		-- [0,1], 0 = matching last momentum dir, 1 = opposite dir
		local angleDist = 0
		if lastOffsetIndex then
		--[[
				1	2	3	4
			1	0	.5	1	.5
			2	.5	0	.5	1
			3	1	.5	0	.5
			4	.5	1	.5	0
		--]]
			angleDist = (2 - math.abs(2 - math.abs(a.offsetIndex - lastOffsetIndex))) * .5
		end
		return roomDist + angleDist * .5
	end
	-- comparator
	local function cmp(a,b) return f(a) < f(b) end
	
	for roomIndex=1,numRooms do
		-- TODO build the new room off of the last block, or at least weight it towards the last block?
		
		do	-- find a side from which to start a new room
			
			local emptyOptions = getEmptyNeighborOptions{lastRoom}
			if #emptyOptions == 0 then
				print("unable to find neighbor to spawn new room!")
				break
			end
			emptyOptions = emptyOptions:shuffle():sort(cmp)
			
			local optionIndex = 1	--math.floor(math.random() * math.random() * #emptyOptions) + 1
			local option = emptyOptions[optionIndex]
			local srcBlock = option.src
			local neighborBlock = option.neighbor
			local neighborOffsetIndex = option.offsetIndex
			--lastOffsetIndex = option.offsetIndex
			--lastOffsetIndex = math.random(4)
			
			srcBlock.wall[neighborOffsetIndex] = doorType
			neighborBlock.wall[oppositeOffsetIndex[neighborOffsetIndex]] = doorType
			-- only the first.  the rest are blue
			doorType = vec3(0,0,0)
			
			local nextRoom = Room()
			nextRoom:addBlock(neighborBlock)
			lastRoom = nextRoom
			chainRooms:insert(nextRoom)
		end
	
		--local momentumWeight = (1 - math.random() * math.random()) * 10	-- 0 means fair, 1 means squared prob distribution favoring last pick
		do -- build the room itself
			local roomSize = getGenRoomSize()
			print('new room roomSize',roomSize)
			for i=1,roomSize do
				
				local emptyOptions = getEmptyNeighborOptions{lastRoom}
				if #emptyOptions == 0 then
					print("unable to find neighbor to grow room!")
					break
				end
				
				-- sort so that those with offsetIndex matching lastOffsetIndex are first
				emptyOptions = emptyOptions:shuffle():sort(cmp)
				
				-- bias towards zero
				local optionIndex = 1
				--local optionIndex = math.floor(math.pow(math.random(), 1+momentumWeight) * #emptyOptions) + 1
				--local optionIndex = math.random(#emptyOptions)
				local option = emptyOptions[optionIndex]
				lastOffsetIndex = option.offsetIndex
				local srcBlock = option.src
				local neighborBlock = option.neighbor
				srcBlock.wall[option.offsetIndex] = nil
				neighborBlock.wall[oppositeOffsetIndex[option.offsetIndex]] = nil
				lastRoom:addBlock(neighborBlock)
				lastBlock = neighborBlock
			end
		end
	end
	-- maybe return the last block, so the new chain can build off of it?  that way there aren't so many straggling room parts veering off to nowhere?
	return chainRooms, lastBlock
end

-- stupid turrets and sawblades
game.session.defensesActive_Main = true

local goals = {
	{
		color = vec3(0,0,0),
		
		-- I think I need enemies per-room
		-- and then sets of enemies for each room to pick from per-chain
		enemies = {
			--'mario.script.obj.goomba',
			--'mario.script.obj.goomba-flying',
			--'mario.script.obj.koopa',
			--'mario.script.obj.koopa-flying',
			'zeta.script.obj.geemer',
		},
		hiddenItems = {
			{spawn='zeta.script.obj.healthitem', duration=1e+9},
			{spawn='zeta.script.obj.healthmaxitem'},
				
			{spawn='zeta.script.obj.attackbonus'},
			{spawn='zeta.script.obj.defensebonus'},
		},
		roomItems = {
			'zeta.script.obj.savepoint',
			'zeta.script.obj.energyrefill',
			'zeta.script.obj.skillsaw',
		},
	},
	-- [[
	{
		color = vec3(1,0,0),
		enemies = {
			--'mario.script.obj.ballnchain',
			--'mario.script.obj.thwomp',
			--'mario.script.obj.thwimp',
			
			'zeta.script.obj.sawblade',
			'zeta.script.obj.turret',
			'zeta.script.obj.geemer',	-- rename to 'jumper' ?
			'zeta.script.obj.zoomer',
		},
		hiddenItems = {
			{spawn='zeta.script.obj.grenadeitem'},
			{spawn='zeta.script.obj.grenademaxitem'},
		},
		roomItems = {
			'zeta.script.obj.savepoint',
			'zeta.script.obj.energyrefill',
			'zeta.script.obj.grenadelauncher',
		},
	},
	{
		color = vec3(0,1,0),
		enemies = {
			'zeta.script.obj.geemer',
			'zeta.script.obj.redgeemer',
			'zeta.script.obj.zoomer',
			'zeta.script.obj.bat',
		},
		hiddenItems = {
			{spawn='zeta.script.obj.missileitem'},
			{spawn='zeta.script.obj.missilemaxitem'},
		},
		roomItems = {
			'zeta.script.obj.savepoint',
			'zeta.script.obj.energyrefill',
			'zeta.script.obj.missilelauncher',
		},
	},
	{
		color = vec3(0,0,1),
		enemies = {
			'zeta.script.obj.geemer',
			'zeta.script.obj.redgeemer',
			'zeta.script.obj.zoomer',
			'zeta.script.obj.bat',
			'zeta.script.obj.teeth',
		},
		hiddenItems = {
			{spawn='zeta.script.obj.cellitem'},
			{spawn='zeta.script.obj.cellmaxitem'},
		},
		roomItems = {
			'zeta.script.obj.savepoint',
			'zeta.script.obj.energyrefill',
			'zeta.script.obj.plasmarifle',
			'zeta.script.obj.grapplinghook',
		},
	},
	--]]
	{
		color = vec3(1,1,1),
	},
}
for _,goal in ipairs(goals) do
	goals[tostring(goal.color)] = goal
end

local startRoom = Room()
local startRoomPos = vec2(math.random(0,blocksWide-1), math.random(0,blocksHigh-1))

local startBlock = assert(getBlockAt(startRoomPos))
startRoom:addBlock(startBlock)

local lastBlock = startBlock
for i=2,#goals do
	-- pick a new source room to start spawning the chain from
	local emptyOptions = getEmptyNeighborOptions(rooms)
	if #emptyOptions == 0 then
		print("!!! unable to find neighbor to grow new room chain (leaving some items out) !!!")
		break
	end
	local srcRoom = emptyOptions:pickRandom().src.room
	
	local goal = goals[i-1]
	
	-- draw out a new chain to a new item.  place it behind an old item's door (or a combination or any # of the last items ...)
	local roomChain
	roomChain, lastBlock = buildRoomChain(srcRoom, lastBlock, getGenNumRoomsInChain(), goal.color)
	goal.roomChain = roomChain

	local function makeItemRoom(option, item)
		local neighbor = assert(option.neighbor)
		print('making room at '..neighbor.pos)
		assert(not neighbor.room)
		local room = Room()
		roomChain:insert(room)
		room:addBlock(neighbor)
		local src = option.src
		
		local offset = option.offsetIndex
		local opposite = oppositeOffsetIndex[offset]
		
		assert(neighbor.wall[opposite] == 'solid')
		assert(src.wall[offset] == 'solid')
		neighbor.wall[opposite] = vec3(0,0,0)
		src.wall[offset] = vec3(0,0,0)
		
		room.noMonsters = true
		item.pos = {
			(neighbor.pos[1] + .5) * level.mapTileSize[1] + 1.5,
			(neighbor.pos[2] + .5) * level.mapTileSize[2],
		}
		spawnInfos:insert(item)
	end

	for _,spawn in ipairs(goal.roomItems) do
		local options = getEmptyNeighborOptions(roomChain)
		local option = options:pickRandom()
		if not option then
			error("couldn't find room to place item")
		else
			makeItemRoom(option, {spawn=spawn})
		end
	end

	-- TODO make a room out of this?
	spawnInfos:insert{
		pos = {
			(lastBlock.pos[1] + .5) * level.mapTileSize[1] + 1.5,
			(lastBlock.pos[2] + .5) * level.mapTileSize[2],
		},
		spawn = 'zeta.script.obj.keycard',
		color = table(goals[i].color):append{1},
	}



	--[=[
	local numExtraDoors = math.min(getGenMaxExtraDoors(), #otherOptions)
	for j=1,numExtraDoors do
		local option = otherOptions[j]
		option.src.wall[option.offsetIndex] = goal.color
		option.neighbor.wall[oppositeOffsetIndex[option.offsetIndex]] = goal.color
	end

	--]=]
end

-- [=[
print'merging neighbors...'
for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		for offsetIndex,offset in ipairs(offsets) do
			if block.wall[offsetIndex] == 'solid' then
				local nbhdblock = getBlockAt(block.pos + offset)
				if nbhdblock and nbhdblock.room == block.room then
					if math.random() < probToRemoveInterRoomWalls then
						block.wall[offsetIndex] = nil
						nbhdblock.wall[oppositeOffsetIndex[offsetIndex]] = nil
					end
				end
			end
		end
	end
end
--]=]

-- [=[
print'filling in tiles...'
for y=0,level.mapTileSize[2]*blocksHigh-1 do
	for x=0,level.mapTileSize[1]*blocksWide-1 do
		level.tileMap[x+level.size[1]*y] = solidTileType
		level.fgTileMap[x+level.size[1]*y] = solidFgTile
		level.bgTileMap[x+level.size[1]*y] = emptyFgTile
		level.backgroundMap[x+level.size[1]*y] = 1
	end
end
for y=0,blocksHigh-1 do
	for x=0,blocksWide-1 do
		level.roomMap[x+level.sizeInMapTiles[1]*y] = 0
	end
end
--]=]

--[=[
print'carving out start room...'
do
	local wallSize = 3
	for y=wallSize,level.mapTileSize[2]-1-wallSize do
		for x=wallSize,level.mapTileSize[1]-1-wallSize do
			local rx = x + level.mapTileSize[1] * startBlock.pos[1]
			local ry = y + level.mapTileSize[2] * startBlock.pos[2]
			level.tileMap[rx+level.size[1]*ry] = emptyTileType
			level.fgTileMap[rx+level.size[1]*ry] = emptyFgTile
		end
	end
end
--]=]

print'carving out rooms...'
for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		
		--[[ background noise
		for y=0,level.mapTileSize[2]-1 do
			for x=0,level.mapTileSize[1]-1 do
				local rx = x + level.mapTileSize[1] * block.pos[1]
				local ry = y + level.mapTileSize[2] * block.pos[2]

				if level.bgTileMap[rx+level.size[1]*ry] == emptyFgTile then
					local noise = simplexNoise(2*rx/level.mapTileSize[1], 2*ry/level.mapTileSize[2])
					if noise*noise > .1 then
						level.bgTileMap[rx+level.size[1]*ry] = 0x10f --solidFgTile
					else
						level.bgTileMap[rx+level.size[1]*ry] = emptyFgTile
					end
				end
			end
		end
		--]]

		for y=0,level.mapTileSize[2]-1 do
			for x=0,level.mapTileSize[1]-1 do
				local rx = x + level.mapTileSize[1] * block.pos[1]
				local ry = y + level.mapTileSize[2] * block.pos[2]
				
				--[[
				do
					local scale = 2
					local r = noise(scale*rx/(blocksWide*level.mapTileSize[1]), scale*ry/(blocksHigh*level.mapTileSize[2])) * .5 + .5
					local g = noise(scale*rx/(blocksWide*level.mapTileSize[1]) + 3.7, scale*ry/(blocksHigh*level.mapTileSize[2]) + 2.5) * .5 + .5
					local b = noise(scale*rx/(blocksWide*level.mapTileSize[1]) - 2.3, scale*ry/(blocksHigh*level.mapTileSize[2]) - 1.1) * .5 + .5
					local m = math.sqrt(r*r + g*g + b*b)
					r,g,b = r/m,g/m,b/m
					colorImg(rx,ry,r,g,b)
				end
				--]]
				
				local bv = vec2(x,y)
				
				-- [=[ simplex noise based
				local lenNorm = 0
				-- 1 for diamond, 2 for round, inf for square
				local normPower = 10
				
				-- single-influences
				for n=1,2 do
					local ofspos = vec2()
					ofspos[n] = 1
					if bv[n] >= level.mapTileSize[n]/2 then
						local ofsblock = getBlockAt(block.pos + ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[positiveOffsetIndexForAxis[n]] then
							local infl = (bv[n] - level.mapTileSize[n]/2) / (level.mapTileSize[n]/2)
							if n == 2 then infl = infl * 2 end
							infl = math.abs(infl)^normPower
							lenNorm = lenNorm + infl
						end
					else
						local ofsblock = getBlockAt(block.pos - ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[negativeOffsetIndexForAxis[n]] then
							local infl = (bv[n] - level.mapTileSize[n]/2) / (level.mapTileSize[n]/2)
							if n == 2 then infl = infl * 2 end
							infl = math.abs(infl)^normPower
							lenNorm = lenNorm + infl
						end
					end
				end
				local len = lenNorm^(1/normPower)

				local freq = 4
				local noise = simplexNoise(
					(vec2(rx / level.mapTileSize[1], ry / level.mapTileSize[2]) * freq)
					:unpack())
				noise = (noise + 1) * .5	-- from [-1,1] to [0,1]
				noise = noise / freq
				noise = noise * .7	-- .7 leaves a 3x3 in the middle of the walls
				len = len + noise

				-- len in [0, .1] is tiered jump platforms
				-- len in [.1, .9] is empty
				-- len in [.9, 1] is the wall
				if len < .9 then	-- non-wall region ...
					level.tileMap[rx+level.size[1]*ry] = emptyTileType
					level.fgTileMap[rx + level.size[1]*ry] = emptyFgTile
					
					if not block.wall[sideForName.up]
					or not block.wall[sideForName.down]
					then
						-- TODO pick different up/down methods: slopes, right-angles, platforms
						if true then	--block.wall[sideForName.left] and block.wall[sideForName.right] then
							-- TODO slopes or right-angles or something
							
						else
							-- platforms
							level.tileMap[rx + level.size[1]*ry] = solidTileType
							level.fgTileMap[rx + level.size[1]*ry] = solidFgTile
							do	--if len < .7 then	-- platform valid
								if y % 4 == 0 then	-- platform
									local xymod = (x + y) % 8
									if xymod >= 2 or x == level.mapTileSize[1]/2 then
										level.tileMap[rx+level.size[1]*ry] = emptyTileType
										level.fgTileMap[rx+level.size[1]*ry] = emptyFgTile
									end
								else
									level.tileMap[rx+level.size[1]*ry] = emptyTileType
									level.fgTileMap[rx+level.size[1]*ry] = emptyFgTile
								end
							end
						end
					end
				end
				--]=]
			end
		end
		for index,offset in ipairs(offsets) do
			local n = axisForOffsetIndex[index]
			local n2 = 3-n
			local doorType = block.wall[index]
			if doorType ~= 'solid'
			and doorType	-- simplex noise needs this
			then
				local left = vec2(-offset[2], offset[1])
				-- clear the whole column from center to edge
				print('clearing whole column from center to edge at '..block.pos)
				for i=0,level.mapTileSize[n]/2 do
					for j=-1,1 do
						local pos = vec2(level.mapTileSize[1]/2, level.mapTileSize[2]/2) + offset * i + left * j
						local x, y = level.mapTileSize[1] * block.pos[1] + pos[1], level.mapTileSize[2] * block.pos[2] + pos[2]
						assert(x >= 0 and y >= 0 and x < level.size[1] and y < level.size[2],
							'checking at '..x..','..y..' of size '..level.size..'...')
						if i >= level.mapTileSize[n]/2 - 1 then	-- at the end of the column make our
							level.tileMap[x+level.size[1]*y] = emptyTileType
							level.fgTileMap[x+level.size[1]*y] = emptyFgTile
							--seamImg(x, y, 1,1,1)	-- make shootable blocks stand out, so give them a different seam color
						else
							level.tileMap[x+level.size[1]*y] = emptyTileType	-- up to then, clear the way
							level.fgTileMap[x+level.size[1]*y] = emptyFgTile	-- up to then, clear the way
						end
					end
				end
				print'...done clearing whole column from center to edge'
				local goal = goals[tostring(doorType)]
				--[=[ TODO in the future - for shootable/breakable walls
				-- consider the door type ...
				--  if it's a legit door then set the clear color to 1,1,1 and the door spawn color to whatever
				--  if it's a secret door then set the clear color to the block type color and the door spawn color to nil
				if not goal then
					error("failed to find door type "..tostring(doorType))
				end
				-- TODO clearColor is being used to clear the whole column.
				-- we should have it clear the whole column as empty
				-- and then use clearColor for clearing the wall
				local constraintClearTileType = goal.clearColor or emptyTileType
				local constraintClearFgTile = goal.emptyFgTile or emptyFgTile
				--]=]
				-- and while we're at it,  make sure the rest of the wall is solid
				print('making sure wall is solid at '..block.pos)
				-- somewherein here oob tiles are written
				for i=level.mapTileSize[n]/2,level.mapTileSize[n]/2 do
					for j=2,level.mapTileSize[n2]/2-1 do
						local pos = vec2(level.mapTileSize[1]/2, level.mapTileSize[2]/2) + offset * i + left * j
						do --if pos[1] >= 0 and pos[2] >= 0 and pos[1] < level.mapTileSize[1] and pos[2] < level.mapTileSize[2] then
							local x = pos[1] + level.mapTileSize[1] * block.pos[1]
							local y = pos[2] + level.mapTileSize[2] * block.pos[2]
							do --if x >= 0 and y >= 0 and x < level.size[1] and y < level.size[2] then
								assert(x >= 0 and y >= 0 and x < level.size[1] and y < level.size[1],
									'solid check failed at '..x..','..y..' of '..level.size..'...')
								level.tileMap[x+level.size[1]*y] = solidTileType
								level.fgTileMap[x+level.size[1]*y] = solidFgTile
							end
						end
					end
				end
				print'...done making sure wall is solid'
				if goal
				--and goal.door
				then
					print('adding goal door at '..block.pos)
					local ofs = offset[n] == -1 and 0 or 1
					spawnInfos:insert{
						angle = n == 2 and 90 or nil,
						spawn = 'zeta.script.obj.door',
						color = goal.color ~= vec3(0,0,0)
							and table(goal.color):append{1}
							or nil,
						pos = vec2(
							level.mapTileSize[1]/2+.5 + offset[1] * (level.mapTileSize[n]/2 + ofs) + level.mapTileSize[1] * block.pos[1],
							level.mapTileSize[2]/2 + offset[2] * (level.mapTileSize[n]/2 + ofs) + level.mapTileSize[2] * block.pos[2]),
					}
				end
			end
		end
	
		if block.wall[sideForName.up] ~= 'solid'
		or block.wall[sideForName.down] ~= 'solid'
		then
			print('carving out ladder at '..block.pos)
			for y=0,level.mapTileSize[2]-1 do
				for x=0,level.mapTileSize[1]-1 do
					local rx = x + level.mapTileSize[1] * block.pos[1]
					local ry = y + level.mapTileSize[2] * block.pos[2]
					assert(rx >= 0 and ry >= 0 and rx < level.size[1] and ry < level.size[2],
						'if('..rx..','..ry..') of size '..level.size..'...')
					if x == level.mapTileSize[1]/2
					and level.tileMap[rx + level.size[1]*ry] == emptyTileType
					then
						level.tileMap[rx + level.size[1]*ry] = ladderTileType
						level.bgTileMap[rx + level.size[1]*ry] = ladderFgTile
					end
				end
			end
			print'...done carving out ladder'
		end
	end
end

-- start room spawn point
print'inserting start spawn point...'
spawnInfos:insert(1, {
	spawn = 'base.script.obj.start',
	pos = {
		level.mapTileSize[1] * (startRoomPos[1] + .5) + 1.5,
		level.mapTileSize[2] * (startRoomPos[2] + .5),
	},
})
spawnInfos:insert(2, {
	spawn = 'zeta.script.obj.blaster',
	pos = {
		level.mapTileSize[1] * (startRoomPos[1] + .5) + 2.5,
		level.mapTileSize[2] * (startRoomPos[2] + .5),
	},
})
spawnInfos:insert(2, {
	spawn = 'zeta.script.obj.walljump',
	pos = {
		level.mapTileSize[1] * (startRoomPos[1] + .5) + 0.5,
		level.mapTileSize[2] * (startRoomPos[2] + .5),
	},
})

-- these objects deserve a platform
-- TODO make sure the platform doesn't overwrite an object
local platformSpawns = table{
	'base.script.obj.start',
	'zeta.script.obj.keycard',
	'zeta.script.obj.savepoint',
	'zeta.script.obj.energyrefill',
	'zeta.script.obj.healthitem',
	'zeta.script.obj.healthmaxitem',
	'zeta.script.obj.attackbonus',
	'zeta.script.obj.defensebonus',
		
	'zeta.script.obj.skillsaw',
	'zeta.script.obj.grenadeitem',
	'zeta.script.obj.grenademaxitem',
	'zeta.script.obj.grenadelauncher',
	'zeta.script.obj.missileitem',
	'zeta.script.obj.missilemaxitem',
	'zeta.script.obj.missilelauncher',
	'zeta.script.obj.cellitem',
	'zeta.script.obj.blaster',
	'zeta.script.obj.cellmaxitem',
	'zeta.script.obj.plasmarifle',
	'zeta.script.obj.grapplinghook',
}:map(function(v,k) return true, v end)

print'putting platforms under spawns...'
for _,info in ipairs(spawnInfos) do
	if platformSpawns[info.spawn] then
		for j=0,1 do
			for i=1,5 do
				local x = info.pos[1]-4.5+i
				local y = info.pos[2]-2-j
				level.tileMap[x + level.size[1]*y] = solidTileType
				level.fgTileMap[x + level.size[1]*y] = solidFgTile
			end
		end
	end
end


-- [=[ placing monsters and hidden items

local function pickRandomTile(block)
	local safeBorder = 4
	local x = math.random(safeBorder,level.mapTileSize[1]-safeBorder-1) + block.pos[1] * level.mapTileSize[1]
	local y = math.random(safeBorder,level.mapTileSize[2]-safeBorder-1) + block.pos[2] * level.mapTileSize[2]
	return x, y
end


-- pick something on the floor
local function pickTileOnGround(block)
	local x,y
	local try = 0
	repeat
		try = try + 1
		if try == 100 then return end
		x,y = pickRandomTile(block)
	until level.tileMap[x+level.size[1]*y] == emptyTileType
	and level.tileMap[x+level.size[1]*(y-1)] == solidTileType
	return x,y
end

local function pickTileOnEdge(block)
	local x,y
	local try = 0
	repeat
		try = try + 1
		if try == 100 then return end
		x,y = pickRandomTile(block)
	until level.tileMap[x+level.size[1]*y] == emptyTileType
	and (level.tileMap[x+level.size[1]*(y-1)] == solidTileType
	or level.tileMap[x+level.size[1]*(y+1)] == solidTileType
	or level.tileMap[x-1+level.size[1]*y] == solidTileType
	or level.tileMap[x+1+level.size[1]*y] == solidTileType)
	return x,y
end

local function pickTileEmpty(block)
	local x,y
	local try = 0
	repeat
		try = try + 1
		if try == 100 then return end
		x,y = pickRandomTile(block)
	until level.tileMap[x+level.size[1]*y] == emptyTileType
	return x,y
end

local function pickTileSolidOnEdge(block)
	local x,y
	local try = 0
	repeat
		try = try + 1
		if try == 100 then return end
		x,y = pickRandomTile(block)
	until level.tileMap[x+level.size[1]*y] == solidTileType
	and (level.tileMap[x+level.size[1]*(y-1)] == emptyTileType
	or level.tileMap[x+level.size[1]*(y+1)] == emptyTileType
	or level.tileMap[x-1+level.size[1]*y] == emptyTileType
	or level.tileMap[x+1+level.size[1]*y] == emptyTileType)
	return x,y
end

-- add items
print'placing monsters and hidden items...'
local hiddenItemsSoFar = table()
for goalIndex,goal in ipairs(goals) do
	local roomChain = goal.roomChain
	if roomChain then
		local totalBlocks = table()
		for _,room in ipairs(roomChain) do totalBlocks:append(room.blocks) end
		print('goal #'..goalIndex..' #roomChain '..#roomChain..' #totalBlocks '..#totalBlocks)
		for _,itemArgs in ipairs(goal.hiddenItems or {}) do
			local block = totalBlocks:pickRandom()
			if block then
				local x,y = pickTileSolidOnEdge(block)
				if not x then
					print('failed to find tile to place item')
				else
					level.tileMap[x+level.size[1]*y] = blasterBreakTileType
					level.fgTileMap[x+level.size[1]*y] = 36
					print('placing goal '..goalIndex..' item '..itemArgs.spawn..' at '..vec2(x+1.5,y+1))
					spawnInfos:insert(table(itemArgs, {pos = vec2(x+1.5,y+1)}))
				end
			else
				print('unable to place hidden item '..itemArgs.spawn)
			end
		end
		if goal.enemies and #goal.enemies > 0  then
			for _,room in ipairs(roomChain) do
				if not room.noMonsters then
					for _,block in ipairs(room.blocks) do
						for i=1,5 do
							local spawnType = assert(table.pickRandom(goal.enemies))
							local x,y
							if ({
								['zeta.script.obj.teeth'] = 1,
								--['mario.script.obj.goomba'] = 1,
								--['mario.script.obj.koopa'] = 1,
							})[spawnType] then
								x,y = pickTileOnGround(block)
							elseif ({
								['zeta.script.obj.turret'] = 1,
								['zeta.script.obj.geemer'] = 1,
								['zeta.script.obj.redgeemer'] = 1,
							})[spawnType] then
								-- pick something on the wall
								x,y = pickTileOnEdge(block)
							else
								-- anywhere
								x,y = pickTileEmpty(block)
							end
							-- TODO thwomp goes on the top
							-- 'mario.script.obj.thwomp',
				
							if not x then
								print('failed to find tile to place enemy')
							else
								spawnInfos:insert{
									spawn = spawnType,
									pos = vec2(x+1.5,y+1),
								}
							end
						end
					end
				end
			end
		end
	end
end

--]=]

-- color blocks accordingly
print'coloring blocks accordingly...'
for i,goal in ipairs(goals) do
	for _,room in ipairs(goal.roomChain or {}) do
		for _,block in ipairs(room.blocks) do
			for y=0,level.mapTileSize[2]-1 do
				for x=0,level.mapTileSize[1]-1 do
					local rx = x + level.mapTileSize[1] * block.pos[1]
					local ry = y + level.mapTileSize[2] * block.pos[2]
					if level.fgTileMap[rx + level.size[1]*ry] == solidFgTile then
						level.fgTileMap[rx + level.size[1]*ry] = 1+256*i
					end
					level.backgroundMap[rx+level.size[1]*ry] = i
				end
			end
		end
	end
end

print'assigning rooms...'
for i,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		level.roomMap[block.pos[1]+block.pos[2]*level.sizeInMapTiles[1]] = i
	end
end

print'smoothing map...'
for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
	local editor = require 'base.script.singleton.editor'()
		local cx = (block.pos[1] + .5) * level.mapTileSize[1]
		local cy = (block.pos[2] + .5) * level.mapTileSize[2]
		editor.smoothDiagLevel = 0	--90'
		editor.paintingTileType = true
		editor.paintingFgTile = true
		editor.paintingBgTile = false
		editor.smoothBrush.paint(editor, cx, cy, math.max(level.mapTileSize:unpack())/2+1)

		editor.smoothDiagLevel = 2	--27'
		editor.paintingTileType = false
		editor.paintingFgTile = false
		editor.paintingBgTile = true
		editor.smoothBrush.paint(editor, cx, cy, math.max(level.mapTileSize:unpack())/2+1)
	end
end

print'processing spawnInfo args...'
level:processSpawnInfoArgs(spawnInfos)

print'writing modifications to original tiles...'
level:backupTiles()

print'saving map...'
editor:saveMap()

print'reporting used blocks...'
local usedBlocks = 0
for _,room in ipairs(rooms) do
	usedBlocks = usedBlocks + #room.blocks
end
