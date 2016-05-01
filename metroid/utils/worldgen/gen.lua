local seed = os.time()
math.randomseed(seed)
print('seed',seed)

local Image = require 'image'
local simplexNoise = require 'simplexnoise.2d'
local vec2 = require 'vec.vec2'
require 'ext'


local offsets = {vec2(1,0), vec2(0,1), vec2(-1,0), vec2(0,-1)}
local sideForName={up=2, down=4, left=3, right=1}
local oppositeOffsetIndex = {3,4,1,2}
local axisForOffsetIndex = {1,2,1,2}
local positiveOffsetIndexForAxis = {1,2}
local negativeOffsetIndexForAxis = {3,4}

local blocksWide = 64
local blocksHigh = 64
local blockSize = vec2(16, 16)

local baseColor = 0x8f8f8f

local function getGenMaxExtraDoors() return math.random(25) end
local function getGenNumRoomsInChain() return math.random(100,200) end
local function getGenRoomSize() return math.ceil(math.random() * math.random() * 20) end
local probToRemoveInterRoomWalls = 0


local function square(x) return x*x end
function vec2.lInfLength(v) return math.max(math.abs(v[1]), math.abs(v[2])) end
function vec2.l1Length(v) return math.abs(v[1]) + math.abs(v[2]) end

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

local function hexToRGB(hex)
	return bit.band(bit.rshift(hex, 16), 0xff) / 0xff,
		bit.band(bit.rshift(hex, 8), 0xff) / 0xff,
		bit.band(hex, 0xff) / 0xff
end


local solid = 'solid'
local blocks = {}
local rooms = table()
for i=0,blocksWide-1 do
	blocks[i] = {}
	for j=0,blocksHigh-1 do
		blocks[i][j] = {pos=vec2(i,j), wall={solid, solid, solid, solid}, objs=table()}
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
	extDoorType = extDoorType or 'beam'
	local chainRooms = table()
	local lastRoom = startRoom
	local doorType = extDoorType
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
			doorType = 'beam'
			
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
	{name='beam', door=true},
	{name='missile', door=true},
	{name='bomb', door=true},
	{name='super_missile', door=true},
	{name='varia', door=true},
	{name='power_bomb', door=true},
	{name='wave_beam', door=true},
	{name='ice_beam', door=true},
	{name='speed_booster', door=true},
	{name='grappling_beam', door=true},
	{name='gravity', door=true},
	{name='space_jump', door=true},
	{name='screw_attack', door=true},
	{name='plasma', door=true},
}

-- map by name as well
for _,itemConstraint in ipairs(itemConstraints) do
	itemConstraints[itemConstraint.name] = itemConstraint
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
	roomChain, lastBlock = buildRoomChain(srcRoom, lastBlock, getGenNumRoomsInChain(), itemConstraint.name)
	
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
		option.src.wall[option.offsetIndex] = itemConstraint.name
		option.neighbor.wall[oppositeOffsetIndex[option.offsetIndex]] = itemConstraint.name
	end
	
	local lastRoom = pickLast(roomChain)
	--lastBlock = pickRandom(lastRoom.blocks)
	-- add the new item at the end of the chain
	lastBlock.objs:insert(itemConstraints[i])
end

-- merge neighbors 

-- [=[
for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		for offsetIndex,offset in ipairs(offsets) do
			if block.wall[offsetIndex] == solid then
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

-- fill in the tiles ...

local tileImg = Image(blocksWide * blockSize[1], blocksHigh * blockSize[2])
local seamImg = Image(blocksWide * blockSize[1], blocksHigh * blockSize[2])
local colorImg = Image(blocksWide * blockSize[1], blocksHigh * blockSize[2])
local spawnInfos = table()
do
	local color = {hexToRGB(baseColor)}
	for y=0,blockSize[2]*blocksHigh-1 do
		for x=0,blockSize[1]*blocksWide-1 do
			tileImg(x,y,unpack(color))
		end
	end
end

for _,room in ipairs(rooms) do
	for _,block in ipairs(room.blocks) do
		for y=0,blockSize[2]-1 do
			for x=0,blockSize[1]-1 do
			
				local rx = blockSize[1] * block.pos[1] + x
				local ry = blockSize[2] * block.pos[2] + y
				do
					local scale = 2
					local r = noise(scale*rx/(blocksWide*blockSize[1]), scale*ry/(blocksHigh*blockSize[2])) * .5 + .5
					local g = noise(scale*rx/(blocksWide*blockSize[1]) + 3.7, scale*ry/(blocksHigh*blockSize[2]) + 2.5) * .5 + .5
					local b = noise(scale*rx/(blocksWide*blockSize[1]) - 2.3, scale*ry/(blocksHigh*blockSize[2]) - 1.1) * .5 + .5
					local m = math.sqrt(r*r + g*g + b*b)
					r,g,b = r/m,g/m,b/m
					colorImg(rx,ry,r,g,b)
				end
					
				
				local bv = vec2(x,y)
				
				local lensq = 0
				
				-- single-influences
				for n=1,2 do
					local ofspos = vec2()
					ofspos[n] = 1
					if bv[n] >= blockSize[n]/2 then
						local ofsblock = getBlockAt(block.pos + ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[positiveOffsetIndexForAxis[n]] then
							local infl = square((bv[n] - blockSize[n]/2) / (blockSize[n]/2))
							lensq = lensq + infl
						end
					else
						local ofsblock = getBlockAt(block.pos - ofspos)
						if not ofsblock or ofsblock.room ~= room or block.wall[negativeOffsetIndexForAxis[n]] then
							local infl = square((bv[n] - blockSize[n]/2) / (blockSize[n]/2))
							lensq = lensq + infl
						end
					end
				end
				local len = math.sqrt(lensq)
				
				local noise = simplexNoise(rx/blockSize[1], ry/blockSize[2])
				noise = (noise + 1) * .5	-- [0,1]
				noise = noise * .7	-- .7 leaves a 3x3 in the middle
				len = len + noise

				-- len in [0, .1] is tiered jump platforms
				-- len in [.1, .9] is empty
				-- len in [.9, 1] is the wall
				if len < .9 then	-- non-wall region ...
					tileImg(rx, ry, 1,1,1)
					
					if not block.wall[sideForName.up] or not block.wall[sideForName.down] then
						-- TODO pick different up/down methods: slopes, right-angles, platforms
						if false then	--block.wall[sideForName.left] and block.wall[sideForName.right] then
							-- TODO slopes or right-angles or something
							
						else
							-- platforms
							tileImg(rx, ry, hexToRGB(baseColor))
							do	--if len < .7 then	-- platform valid
								if y % 8 == 0 then	-- platform 
									local xymod = (x + y) % 16
									if xymod >= 4 then
										tileImg(rx, ry, 1,1,1)
									end
								else
									tileImg(rx, ry, 1,1,1)
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
				local itemConstraint = itemConstraints[doorType]
				if not itemConstraint then
					error("failed to find door type "..tostring(doorType))
				end
				-- TODO clearColor is being used to clear the whole column.
				-- we should have it clear the whole column as empty
				-- and then use clearColor for clearing the wall
				local clearColor = itemConstraint.clearColor or 0xffffff
				local doorSpawnColor = itemConstraint.doorSpawnColor
			
				local left = vec2(-offset[2], offset[1])
				-- clear the whole column from center to edge
				for i=0,blockSize[n]/2 do
					for j=-1,1 do
						local pos = vec2(blockSize[1]/2, blockSize[2]/2) + offset * i + left * j
						local x, y = blockSize[1] * block.pos[1] + pos[1], blockSize[2] * block.pos[2] + pos[2]
						if i >= blockSize[n]/2 - 1 then	-- at the end of the column make our 
							tileImg(x, y, hexToRGB(clearColor))
							seamImg(x, y, 1,1,1)	-- make shootable blocks stand out, so give them a different seam color
						else
							tileImg(x, y, 1,1,1)	-- up to then, clear the way
						end
					end
				end
				-- and while we're at it,  make sure the rest of the wall is solid
				local fillColor = baseColor
				if doorSpawnColor then fillColor = 0xffffff end
				for i=blockSize[n]/2,blockSize[n]/2 do
					for j=2,blockSize[n2]/2 do
						local pos = vec2(blockSize[1]/2, blockSize[2]/2) + offset * i + left * j
						local x, y = blockSize[1] * block.pos[1] + pos[1], blockSize[2] * block.pos[2] + pos[2]
						tileImg(x,y, hexToRGB(baseColor))
					end
				end
				if doorSpawnColor then -- draw a doortype
					local pos = vec2(blockSize[1]/2, blockSize[2]/2) + offset * (blockSize[n]/2)
					local x, y = blockSize[1] * block.pos[1] + pos[1], blockSize[2] * block.pos[2] + pos[2]
					tileImg(x, y, hexToRGB(doorSpawnColor))
				end
				if itemConstraint.door then
					local sargs = {
						spawn='metroid.script.obj.door', 
						shottype=itemConstraint.name,
					}
					local pos = vec2(blockSize[1]/2, blockSize[2]/2) + offset * (blockSize[n]/2)
					local x, y = blockSize[1] * block.pos[1] + pos[1], blockSize[2] * block.pos[2] + pos[2]
					sargs.pos = vec2(x,y)
					-- direction?
					spawnInfos:insert(sargs)
				end
			end
		end
		-- now if there's any items ...
		if block.objs then
			for _,obj in ipairs(block.objs) do
			end
		end
	end
end

-- start room spawn point
tileImg(blockSize[1] * startRoomPos[1] + blockSize[1]/2, blockSize[2] * startRoomPos[2] + blockSize[2]/2, 0,1,0)

os.execute('mkdir ../../maps/gen')
tileImg:save('../../maps/gen/tile.png')
seamImg:save('../../maps/gen/seam.png')
io.writefile('../../maps/gen/spawn.lua', toLua(spawnInfos))	-- TODO pretty up vec2's
--colorImg:save('../../maps/gen/color.png')

local usedBlocks = 0
for _,room in ipairs(rooms) do
	usedBlocks = usedBlocks + #room.blocks
end
print('usedBlocks',usedBlocks)

