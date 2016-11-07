for _,obj in ipairs(game.objs) do obj.remove = true end
game.objs = table()
level.spawnInfos = table()
local modio = require 'base.script.singleton.modio'
local path = modio.search[1]..'/maps/'..modio.levelcfg.path
local seed = assert(tonumber(assert(path:match('gen(%d+)'))))

local blocksWide = level.size[1] / level.mapTileSize[1]
local blocksHigh = level.size[2] / level.mapTileSize[2]
local spawnInfos = table()

math.randomseed(seed)
print('seed',seed)

local Image = require 'image'
local simplexNoise = require 'simplexnoise.2d'
--require 'vec'
--require 'ext'
function vec2.lInfLength(v) return math.max(math.abs(v[1]), math.abs(v[2])) end
function vec2.l1Length(v) return math.abs(v[1]) + math.abs(v[2]) end


local clearTileType = 0	-- tileTypes.EMPTY
local clearFgTile = 0

local baseTileType = 1 -- tileTypes.SOLID
local baseFgTile = 0x000101

local ladderTileType = 15	-- tileTiles.LADDER
local ladderTile = 2



local offsets = {vec2(1,0), vec2(0,1), vec2(-1,0), vec2(0,-1)}
local sideForName={right=1, up=2, left=3, down=4}
local oppositeOffsetIndex = {3,4,1,2}
local axisForOffsetIndex = {1,2,1,2}
local positiveOffsetIndexForAxis = {1,2}
local negativeOffsetIndexForAxis = {3,4}


local function getGenMaxExtraDoors() return math.random(25) end
local function getGenNumRoomsInChain() return math.random(100,200) end
local function getGenRoomSize() return math.ceil(math.random() * math.random() * 20) end
local probToRemoveInterRoomWalls = 0


local function square(x) return x*x end

local function pickRandom(ar)
	return ar[math.random(#ar)]
end

local function pickLast(ar)
	return ar[#ar]
end

local function shuffle(ar)
	local tmp = table()
	for i=1,#ar do
		tmp:insert( math.random(#tmp+1), ar[i] )
	end
	for i=1,#tmp do
		ar[i] = tmp:remove(math.random(#tmp))
	end
	return ar
end

local blocks = {}
local rooms = table()
for i=0,blocksWide-1 do
	blocks[i] = {}
	for j=0,blocksHigh-1 do
		blocks[i][j] = {pos=vec2(i,j), wall={'solid', 'solid', 'solid', 'solid'}}
	end
end

local function getBlockAt(pos)
	local col = blocks[pos[1]]
	if not col then return nil end
	return col[pos[2]]
end


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
					options:insert{src=block, offset=vec2(offset), offsetIndex=offsetIndex, neighbor=candidateblock}
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
			roomDist = (lastBlock.pos - a.src.pos):l1Length()
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
			shuffle(emptyOptions)
			emptyOptions:sort(cmp)
			
			local optionIndex = 1	--math.floor(math.random() * math.random() * #emptyOptions) + 1
			local option = emptyOptions[optionIndex]
			local srcBlock = option.src
			local neighborBlock = option.neighbor
			local neighborOffsetIndex = option.offsetIndex
			--lastOffsetIndex = option.offsetIndex
			lastOffsetIndex = math.random(4)
			
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
				shuffle(emptyOptions)
				emptyOptions:sort(cmp)
				
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

local itemConstraints = {
	{
		color = vec3(0,0,0),
		enemies = {
			'zeta.script.obj.geemer',
		},
	},
	{
		color = vec3(1,0,0),
		enemies = {
			'zeta.script.obj.geemer',
			'zeta.script.obj.geemer',
			'zeta.script.obj.redgeemer',
		},
	},
	{
		color = vec3(0,1,0),
		enemies = {
			'zeta.script.obj.geemer',
			'zeta.script.obj.redgeemer',
			'zeta.script.obj.redgeemer',
		},
	},
	{
		color = vec3(0,0,1),
		enemies = {
			'zeta.script.obj.geemer',
			'zeta.script.obj.redgeemer',
			'zeta.script.obj.teeth',
		},
	},
}
for _,itemConstraint in ipairs(itemConstraints) do
	itemConstraints[tostring(itemConstraint.color)] = itemConstraint
end

local startRoom = Room()
local startRoomPos = vec2(math.random(0,blocksWide-1), math.random(0,blocksHigh-1))

local startBlock = assert(getBlockAt(startRoomPos))
startRoom:addBlock(startBlock)

local lastBlock = startBlock
for i=2,#itemConstraints do
	-- pick a new source room to start spawning the chain from
	local emptyOptions = getEmptyNeighborOptions(rooms)
	if #emptyOptions == 0 then
		print("!!! unable to find neighbor to grow new room chain (leaving some items out) !!!")
		break
	end
	local srcRoom = pickRandom(emptyOptions).src.room
	
	local itemConstraint = itemConstraints[i-1]
	
	-- draw out a new chain to a new item.  place it behind an old item's door (or a combination or any # of the last items ...)
	local roomChain
	roomChain, lastBlock = buildRoomChain(srcRoom, lastBlock, getGenNumRoomsInChain(), itemConstraint.color)
	itemConstraint.roomChain = roomChain

	local otherOptions = getNeighborOptions(roomChain, function(dstblock, srcblock, offset, offsetIndex)
		if not dstblock.room then return false end	-- make sure there's a room
		--if not table.find(roomChain, dstblock.room) then return false end	-- make sure it's not part of this chain ... ?  not necessary.
		if srcblock.wall[offsetIndex] then	-- make sure there's no door here
			assert(dstblock.wall[oppositeOffsetIndex[offsetIndex]])	-- that means there shouldn't be a door on the opposite side too
			return false
		end
		return true
	end)
	shuffle(otherOptions)
	local numExtraDoors = 0	--math.min(getGenMaxExtraDoors(), #otherOptions)
	for j=1,numExtraDoors do
		local option = otherOptions[j]
		option.src.wall[option.offsetIndex] = itemConstraint.color
		option.neighbor.wall[oppositeOffsetIndex[option.offsetIndex]] = itemConstraint.color
	end
	
	spawnInfos:insert{
		pos={(lastBlock.pos[1] + .5) * level.mapTileSize[1] + 1.5, (lastBlock.pos[2] + .5) * level.mapTileSize[2]},
		spawn='zeta.script.obj.keycard',
		color = table(itemConstraints[i].color):append{1},
	}
end

-- merge neighbors 
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

-- fill in the tiles ...

local function setpixel(img, x, y, hex)
	x = math.floor(x)
	if x < 0 or x >= img.width then print("got bad x value "..x) return end
	y = math.floor(y)
	if y < 0 or y >= img.height then print("got bad y value "..y) return end
	y = img.height-y-1
	for ch=0,2 do
		img.buffer[ch + img.channels * (x + img.width * y)] = bit.rshift(hex, 8*ch)
	end
end

local function getpixel(img, x, y)
	x = math.floor(x)
	if x < 0 or x >= img.width then print("got bad x value "..x) return end
	y = math.floor(y)
	if y < 0 or y >= img.height then print("got bad y value "..y) return end
	y = img.height-y-1
	local hex = 0
	for ch=0,2 do
		hex = bit.bor(hex, bit.lshift(img.buffer[ch + img.channels * (x + img.width * y)], 8*ch))
	end
	return hex
end



for y=0,level.mapTileSize[2]*blocksHigh-1 do
	for x=0,level.mapTileSize[1]*blocksWide-1 do
		level.tileMap[x+level.size[1]*y] = baseTileType
		level.fgTileMap[x+level.size[1]*y] = baseFgTile
		level.bgTileMap[x+level.size[1]*y] = clearFgTile
		level.backgroundMap[x+level.size[1]*y] = 1
	end
end
for y=0,blocksHigh-1 do
	for x=0,blocksWide-1 do
		level.roomMap[x+level.sizeInMapTiles[1]*y] = 0
	end
end


for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
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
				
				local lensq = 0
				
				-- single-influences
				for n=1,2 do
					local ofspos = vec2()
					ofspos[n] = 1
					if bv[n] >= level.mapTileSize[n]/2 then
						local ofsblock = getBlockAt(block.pos + ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[positiveOffsetIndexForAxis[n]] then
							local infl = square((bv[n] - level.mapTileSize[n]/2) / (level.mapTileSize[n]/2))
							lensq = lensq + infl
						end
					else
						local ofsblock = getBlockAt(block.pos - ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[negativeOffsetIndexForAxis[n]] then
							local infl = square((bv[n] - level.mapTileSize[n]/2) / (level.mapTileSize[n]/2))
							lensq = lensq + infl
						end
					end
				end
				local len = math.sqrt(lensq)
				
				local noise = simplexNoise(rx/level.mapTileSize[1], ry/level.mapTileSize[2])
				noise = (noise + 1) * .5	-- [0,1]
				noise = noise * .7	-- .7 leaves a 3x3 in the middle
				len = len + noise

				-- len in [0, .1] is tiered jump platforms
				-- len in [.1, .9] is empty
				-- len in [.9, 1] is the wall
				if len < .9 then	-- non-wall region ...
					level.tileMap[rx+level.size[1]*ry] = clearTileType
					level.fgTileMap[rx + level.size[1]*ry] = clearFgTile
					
					if not block.wall[sideForName.up]
					or not block.wall[sideForName.down]
					then
						-- TODO pick different up/down methods: slopes, right-angles, platforms
						if true then	--block.wall[sideForName.left] and block.wall[sideForName.right] then
							-- TODO slopes or right-angles or something
							
						else
							-- platforms
							level.tileMap[rx + level.size[1]*ry] = baseTileType
							level.fgTileMap[rx + level.size[1]*ry] = baseFgTile
							do	--if len < .7 then	-- platform valid
								if y % 4 == 0 then	-- platform 
									local xymod = (x + y) % 8
									if xymod >= 2 or x == level.mapTileSize[1]/2 then
										level.tileMap[rx+level.size[1]*ry] = clearTileType
										level.fgTileMap[rx+level.size[1]*ry] = clearFgTile
									end
								else
									level.tileMap[rx+level.size[1]*ry] = clearTileType
									level.fgTileMap[rx+level.size[1]*ry] = clearFgTile
								end
							end
						end
					end
				end	
			end
		end
		for index,offset in ipairs(offsets) do
			local n = axisForOffsetIndex[index]
			local n2 = 3-n
			local doorType = block.wall[index]
			if doorType and doorType ~= 'solid' then
			
				-- consider the door type ...
				--  if it's a legit door then set the clear color to 1,1,1 and the door spawn color to whatever
				--  if it's a secret door then set the clear color to the block type color and the door spawn color to nil
				local itemConstraint = itemConstraints[tostring(doorType)]
				if not itemConstraint then
					error("failed to find door type "..tostring(doorType))
				end
				-- TODO clearColor is being used to clear the whole column.
				-- we should have it clear the whole column as empty
				-- and then use clearColor for clearing the wall
				local constraintClearTileType = itemConstraint.clearColor or clearTileType
				local constraintClearFgTile = itemConstraint.clearFgTile or clearFgTile
			
				local left = vec2(-offset[2], offset[1])
				-- clear the whole column from center to edge
				for i=0,level.mapTileSize[n]/2 do
					for j=-1,1 do
						local pos = vec2(level.mapTileSize[1]/2, level.mapTileSize[2]/2) + offset * i + left * j
						local x, y = level.mapTileSize[1] * block.pos[1] + pos[1], level.mapTileSize[2] * block.pos[2] + pos[2]
						if i >= level.mapTileSize[n]/2 - 1 then	-- at the end of the column make our 
							level.tileMap[x+level.size[1]*y] = constraintClearTileType
							level.fgTileMap[x+level.size[1]*y] = constraintClearFgTile
							--seamImg(x, y, 1,1,1)	-- make shootable blocks stand out, so give them a different seam color
						else
							level.tileMap[x+level.size[1]*y] = clearTileType	-- up to then, clear the way
							level.fgTileMap[x+level.size[1]*y] = clearFgTile	-- up to then, clear the way
						end
					end
				end
				-- and while we're at it,  make sure the rest of the wall is solid
				for i=level.mapTileSize[n]/2,level.mapTileSize[n]/2 do
					for j=2,level.mapTileSize[n2]/2 do
						local pos = vec2(level.mapTileSize[1]/2, level.mapTileSize[2]/2) + offset * i + left * j
						local x, y = level.mapTileSize[1] * block.pos[1] + pos[1], level.mapTileSize[2] * block.pos[2] + pos[2]
						level.tileMap[x+level.size[1]*y] = baseTileType
						level.fgTileMap[x+level.size[1]*y] = baseFgTile
					end
				end
				if true --itemConstraint.door 
				then
					local ofs = offset[n] == -1 and 0 or 1
					spawnInfos:insert{
						angle = n == 2 and 90 or nil,
						spawn = 'zeta.script.obj.door', 
						color = itemConstraint.color ~= vec3(0,0,0) 
							and table(itemConstraint.color):append{1} 
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
			for y=0,level.mapTileSize[2]-1 do
				for x=0,level.mapTileSize[1]-1 do
					local rx = x + level.mapTileSize[1] * block.pos[1]
					local ry = y + level.mapTileSize[2] * block.pos[2]
					if x == level.mapTileSize[1]/2
					and level.tileMap[rx + level.size[1]*ry] == clearTileType
					then
						level.tileMap[rx + level.size[1]*ry] = ladderTileType
						level.bgTileMap[rx + level.size[1]*ry] = ladderTile
					end
				end
			end
		end
	end
end

-- add monsters
for _,itemConstraint in ipairs(itemConstraints) do
	if #itemConstraint.enemies > 0  then
		for _,room in ipairs(itemConstraint.roomChain or {}) do
			for _,block in ipairs(room.blocks) do
				for i=1,5 do
					local spawnType = assert(pickRandom(itemConstraint.enemies))
					local x,y
					if ({
						['zeta.script.obj.teeth'] = 1,
					})[spawnType] then
						-- pick something on the floor
						x = math.random(0,level.mapTileSize[1]-1) + block.pos[1] * level.mapTileSize[1]
						y = math.random(0,level.mapTileSize[2]-1) + block.pos[2] * level.mapTileSize[2]
					elseif ({
						['zeta.script.obj.turret'] = 1,
						['zeta.script.obj.geemer'] = 1,
						['zeta.script.obj.redgeemer'] = 1,
					})[spawnType] then
						-- pick something on the wall
						x = math.random(0,level.mapTileSize[1]-1) + block.pos[1] * level.mapTileSize[1]
						y = math.random(0,level.mapTileSize[2]-1) + block.pos[2] * level.mapTileSize[2]
					else
						-- anywhere
						x = math.random(0,level.mapTileSize[1]-1) + block.pos[1] * level.mapTileSize[1]
						y = math.random(0,level.mapTileSize[2]-1) + block.pos[2] * level.mapTileSize[2]
					end
					
					spawnInfos:insert{
						spawn = spawnType,
						pos = vec2(x+.5,y),
					}
				end
			end
		end
	end
end

-- start room spawn point
spawnInfos:insert(1, {
	spawn='base.script.obj.start',
	pos={
		level.mapTileSize[1] * (startRoomPos[1] + .5) + 1.5,
		level.mapTileSize[2] * (startRoomPos[2] + .5),
	},
})
spawnInfos:insert(2, {
	spawn='zeta.script.obj.blaster',
	pos={
		level.mapTileSize[1] * (startRoomPos[1] + .5) + 2.5,
		level.mapTileSize[2] * (startRoomPos[2] + .5),
	},
})

for _,info in ipairs(spawnInfos) do
	if info.spawn == 'base.script.obj.start'
	or info.spawn == 'zeta.script.obj.keycard'
	then
		for ofs=1,5 do
			local x = info.pos[1]-4.5+ofs
			local y = info.pos[2]-2
			level.tileMap[x + level.size[1]*y] = baseTileType
			level.fgTileMap[x + level.size[1]*y] = baseFgTile 
		end
	end
end

-- color blocks accordingly
for i,itemConstraint in ipairs(itemConstraints) do
	for _,room in ipairs(itemConstraint.roomChain or {}) do
		for _,block in ipairs(room.blocks) do
			for y=0,level.mapTileSize[2]-1 do
				for x=0,level.mapTileSize[1]-1 do
					local rx = x + level.mapTileSize[1] * block.pos[1]
					local ry = y + level.mapTileSize[2] * block.pos[2]
					if level.fgTileMap[rx + level.size[1]*ry] == baseFgTile then
						level.fgTileMap[rx + level.size[1]*ry] = 1+256*i
					end
					level.backgroundMap[rx+level.size[1]*ry] = i
				end
			end
		end
	end
end

for i,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		level.roomMap[block.pos[1]+block.pos[2]*level.sizeInMapTiles[1]] = i
	end
end

local editor = require 'base.script.singleton.editor'()
editor.smoothBrush.paint(editor, level.size[1]/2, level.size[2]/2, math.max(level.size:unpack())+10)

level:processSpawnInfoArgs(spawnInfos)
level:backupTiles()
editor:saveMap()

local usedBlocks = 0
for _,room in ipairs(rooms) do
	usedBlocks = usedBlocks + #room.blocks
end
