-- if we're loading from a save point then return
-- .. but the code that calls this is wrapped in a block:
-- "don't do this if game.savePoint exists"
-- so why's it getting this far?
local math = require 'ext.math'
local table = require 'ext.table'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
if game.savePoint then return end

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

local simplexNoise = require 'simplexnoise.2d'
local function lInfLength(v) return math.max(math.abs(v[1]), math.abs(v[2])) end
local function l1Length(v) return math.abs(v[1]) + math.abs(v[2]) end
local function square(x) return x*x end

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

local emptyTileType = 0
local solidTileType = game:findTileType'base.script.tile.solid'
local ladderTileType = game:findTileType'base.script.tile.ladder'
local blasterBreakTileType = game:findTileType'zeta.script.tile.blasterbreak'

local emptyFgTile = 0
local solidFgTile = 0x000101
local ladderTile = 2

for y=0,level.size[2]-1 do
	for x=0,level.size[1]-1 do
		level.tileMap[x+level.size[1]*y] = solidTileType
		level.fgTileMap[x+level.size[1]*y] = solidFgTile
		level.bgTileMap[x+level.size[1]*y] = emptyFgTile
		level.backgroundMap[x+level.size[1]*y] = 1
	end
end


local offsets = {vec2(1,0), vec2(0,1), vec2(-1,0), vec2(0,-1)}
local sideForName={right=1, up=2, left=3, down=4}
local oppositeOffsetIndex = {3,4,1,2}
local axisForOffsetIndex = {1,2,1,2}
local positiveOffsetIndexForAxis = {1,2}
local negativeOffsetIndexForAxis = {3,4}


local editor = require 'base.script.singleton.editor'()
editor.smoothDiagLevel[0] = 2	--27'


local wallBuffer = 3


local class = require 'ext.class'
local Room = class()
function Room:init(args)
	self.bbox = box2(args.bbox)
end

local rooms = table()



local Node = class()
Node.radius = 3
Node.tileType = emptyTileType
Node.fgTile = emptyFgTile

function Node:init(args)
	self.pt = args and vec2(table.unpack(args.pt)) or vec2()
	self.radius = args and args.radius or nil 
end

function Node:paint()
	editor.paintingTileType[0] = true
	editor.paintingFgTile[0] = true
	editor.paintingBgTile[0] = true
	editor.paintingBackground[0] = false
	editor.selectedTileTypeIndex[0] = self.tileType
	editor.selectedFgTileIndex = self.fgTile
	editor.brushTileWidth[0] = self.radius
	editor.brushTileHeight[0] = self.radius
	editor.smoothWhilePainting[0] = true
	editor.smoothBorder[0] = 2
	
	editor.paintBrush.paint(editor, math.floor(self.pt[1])+1, math.floor(self.pt[2])+1)
end

local Path = class(table)

function Path:init(args)
	if args then
		for i=1,#args do
			self[i] = Node(args[i])
		end
	end
end

-- static
function Path:fromLine(a,b)
	return Path{{pt=a}, {pt=b}}
end

-- arclen parameterize -- split up any sections longer than 1 unit
function Path:arcparam()
	for i=#self-1,1,-1 do
		local r1 = self[i].pt
		local r2 = self[i+1].pt
		local l = math.ceil((r1 - r2):length())
		for j=l-1,1,-1 do
			local f = j/l
			local r = (r2 - r1) * f + r1
			self:insert(i+1,Node{
				pt = vec2(math.floor(r[1]), math.floor(r[2]))
			})
		end
	end
	return self
end

function Path:arclen()
	local d = 0
	for i=1,#self-1 do
		d = d + (self[i+1].pt - self[i].pt):length()
	end
	return d
end

local function constrainToMap(p, border)
	border = border or wallBuffer
	return vec2(
		math.clamp(p[1], wallBuffer, level.size[1]-wallBuffer-1),
		math.clamp(p[2], wallBuffer, level.size[2]-wallBuffer-1))
end

function Path:lightning(scale)
	scale = scale or .5
	local l = self:arclen()
	local function apply(i1,i2)
		local mid = math.floor((i1+i2)/2)
		if i1==mid or mid==i2 then return end
		local howfar = l * scale * (i2 - i1) / #self
		self[mid].pt = constrainToMap( (self[i2].pt + self[i1].pt) * .5 + vec2(math.random()*2-1, math.random()*2-1) * howfar )
		apply(i1,mid)
		apply(mid,i2)
	end
	apply(1,#self)
	return self
end

function Path:paint()
	for _,node in ipairs(self) do
		node:paint()
	end
end

function Path:buildPlatforms()
	local path = Path(self):arcparam()
	for i=1,#path,4 do
		-- fill in a point here, only if the path is up/down?
		path[i].radius = 1
		path[i].tileType = solidTileType
		path[i].fgTile = solidFgTile
		path[i]:paint()
	end
end



local startPos
local startRoom
local startRoomSize = 13	-- view width minus a few
do
	
	local l = startRoomSize + wallBuffer
	startPos = vec2(math.random(l, level.size[1]-l-1), math.random(l, level.size[2]-l-1))

	spawnInfos:insert{
		spawn = 'base.script.obj.start',
		pos = startPos + vec2(1.5, 1),
	}

	local bbox = box2{
		min = startPos - vec2(startRoomSize, startRoomSize),
		max = startPos + vec2(startRoomSize, startRoomSize)}
	for y=bbox.min[2],bbox.max[2] do
		for x=bbox.min[1],bbox.max[1] do
			local l = (vec2(x,y)-startPos):length()
			if l < startRoomSize then
				if y < startPos[2] and l < startRoomSize/2 then
				else
					level.tileMap[x+level.size[1]*y] = emptyTileType
					level.fgTileMap[x+level.size[1]*y] = emptyFgTile
				end
			end
		end
	end

	startRoom = Room{
		bbox = bbox,
	}
	rooms:insert(startRoom)
end




-- ok now that we've got our start room
-- pick a point on the surface
-- and start digging
do
	--local theta = math.random() * 2 * math.pi
	local theta = math.random(0,1) * math.pi
	local r1 = constrainToMap(vec2(math.cos(theta), math.sin(theta)) * startRoomSize + startPos)
		
	if r1[2] > startPos[2] then
		-- put some platforms leading up to the path
		Path:fromLine(startPos, r1):buildPlatforms()
	end

	local corridorDist = 100
	local corridorSpreadAngle = 0
	theta = theta + math.random() * math.rad(corridorSpreadAngle )
	local r2 = constrainToMap(r1 + vec2(math.cos(theta), math.sin(theta)) * corridorDist)

	local path = Path:fromLine(r1,r2):arcparam()
	path:lightning(.1):arcparam()

	-- TODO path:dontCrossYourself, path:keepInSolid

	path:paint()

	-- and draw another room
	
end



editor.smoothBrush.paint(editor, level.size[1]/2, level.size[2]/2, math.max(level.size:unpack())+10)

level:processSpawnInfoArgs(spawnInfos)
level:backupTiles()
editor:saveMap()
