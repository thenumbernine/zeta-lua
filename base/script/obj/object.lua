local ffi = require 'ffi'
local animsys = require 'base.script.singleton.animsys'
local game = require 'base.script.singleton.game'
local sounds = require 'base.script.singleton.sounds'
local threads = require 'base.script.singleton.threads'
local sandbox = require 'base.script.singleton.sandbox'

local Object = class()

Object.useGravity = true
Object.friction = 1		-- additive, not scalar
Object.seq = 'stand'
Object.drawMirror = false

-- used to evaluate whose touch function to run first
Object.touchPriority = 0

-- used to evaluate who gets priority when pushing
Object.pushPriority = 0

-- used to init the per-object bbox.  don't manip this plz
Object.bbox = box2(-.4, 0, .4, .8)

-- useful vars to have around that I should just put in util.lua
Object.touchEntFields = {'touchEntUp', 'touchEntDown', 'touchEntLeft', 'touchEntRight'}
Object.touchEntHorzFields = {'touchEntLeft', 'touchEntRight'}
Object.touchEntVertFields = {'touchEntUp', 'touchEntDown'}


-- my attempt to make the animation system more flexible:
Object.seqStartTime = 0	-- time offset at which the sequence starts
Object.seqNext = nil		-- this says what sequence comes next.  it means I need some return info from the animation update.


function Object:init(args)
	self.pos = vec2()
	self.lastpos = vec2()
	self.vel = vec2()
	self.lastvel = vec2()
	self.bbox = box2(self.bbox.min[1], self.bbox.min[2], self.bbox.max[1], self.bbox.max[2])

	for k,v in pairs(args) do
		local unknown
		local typev = type(v)
		if typev == 'number'
		or typev == 'boolean'
		or typev == 'string'
		or typev == 'function'
		then
			self[k] = v
		elseif typev == 'table' then
			if #v == 2 then
				self[k] = vec2(table.unpack(v))
			elseif #v == 4 then
				self[k] = vec4(table.unpack(v))
			elseif v.min then
				self[k] = box2(v)
			else
				self[k] = v
				-- complain about unknown?
			end
		else
			unknown = true
		end
		if unknown then
			print('got unknown spawninfo type',typev,'key',k,'value',v)
			self[k] = v
		end
	end

	--[[
	since i'm not holding individual tile objects anymore, 
	i'll have level allocate them only for tiles that have objects on them 
	--]]
	self.tiles = {}

	game:addObject(self)	-- only do this once per object.  don't reuse, or change the uid system

	if args.create then
		threads:add(function()
			-- wait for ctor to resolve
			coroutine.yield()
			sandbox(args.create, 'self', self)
		end)
	end

	self:link()
end

function Object:update(dt)

	self.lastpos[1], self.lastpos[2] = self.pos[1], self.pos[2]
	self.lastvel[1], self.lastvel[2] = self.vel[1], self.vel[2]

	if self.removeTime and self.removeTime < game.time then
		self.remove = true
		return
	end

	local level = game.level
	local gravity = game.gravity
	local maxVel = game.maxVel
	local maxFallVel = game.maxFallVel	-- optional
	
	-- speed limit
	if self.vel[1] < -maxVel then self.vel[1] = -maxVel end
	if self.vel[1] > maxVel then self.vel[1] = maxVel end
	if self.vel[2] < -maxVel then self.vel[2] = -maxVel end
	if self.vel[2] > maxVel then self.vel[2] = maxVel end

	local tile = level:getTile(self.pos[1], self.pos[2])
	if tile and tile.canSwim then
		gravity = gravity * .1
		maxFallVel = maxFallVel and maxFallVel * .1
		--self.vel[2] = self.vel[2] * .1
	end
	
	if self.useGravity then
		self.vel[2] = self.vel[2] + gravity * dt
	
		-- special falling speed
		if maxFallVel then
			if self.vel[2] < -maxFallVel then self.vel[2] = -maxFallVel end
		end
	end
	
	local moveX = self.vel[1] * dt
	local moveY = self.vel[2] * dt
	
	if self.touchEntDown then
		moveX = moveX + self.touchEntDown.pos[1] - self.touchEntDown.lastpos[1]
		moveY = moveY + self.touchEntDown.pos[2] - self.touchEntDown.lastpos[2]
	end

	self.ongroundLast = self.onground
	self.collidedUp = false
	self.collidedDown = false
	self.collidedLeft = false
	self.collidedRight = false
	self.onground = false
	self.touchEntUp = nil
	self.touchEntDown = nil
	self.touchEntLeft = nil
	self.touchEntRight = nil
	
	self:move(moveX, moveY)
	
	if self.onground then
		if self.vel[1] > 0 then
			self.vel[1] = self.vel[1] - self.friction
			if self.vel[1] < 0 then self.vel[1] = 0 end
		elseif self.vel[1] < 0 then
			self.vel[1] = self.vel[1] + self.friction
			if self.vel[1] > 0 then self.vel[1] = 0 end
		end
	end
	
	-- animation next cycle

	if self.sprite and self.seq then
		self.seqHasFinished = animsys:seqHasFinished(self.sprite, self.seq or 'stand', self.seqStartTime)
		if self.seqNext and self.seqHasFinished then
			self:setSeq(self.seqNext)
		end
	else
		self.seqHasFinished = nil
	end
end

function Object:setSeq(seq, seqNext)
	self.seqNext = seqNext
	if self.seq == seq then return end	-- don't reset it when continually setting it
	self.seq = seq
	self.seqStartTime = game.time
end

function Object:setPos(x,y)
	self:unlink()
	self.pos[1], self.pos[2] = x,y
	self:link()
end

function Object:moveToPos(x,y)
	self:move(x - self.pos[1], y - self.pos[2])
end

function Object:unlink()
	local level = game.level
	local numtiles = #self.tiles
	for i=1,numtiles do
		local tile = self.tiles[i]
		assert(tile.objs:removeObject(self))
		if #tile.objs == 0 then
			local x, y = tile.pos:unpack()
			local col = level.objsAtTile[x]
			assert(col[y] == tile)
			col[y] = nil
			if not next(col) then
				level.objsAtTile[x] = nil
			end
		end
		-- clear as we go. safe because #self.tiles is stored upon iteration init		
		self.tiles[i] = nil
	end
end

function Object:link()
	local level = game.level
	local minx = self.pos[1] + self.bbox.min[1] - level.pos[1]
	local miny = self.pos[2] + self.bbox.min[2] - level.pos[2]
	local maxx = self.pos[1] + self.bbox.max[1] - level.pos[1]
	local maxy = self.pos[2] + self.bbox.max[2] - level.pos[2]

	if minx > level.size[1]
	or miny > level.size[2]
	or maxx < 1
	or maxy < 1
	then return end	-- no tiles to link to

	if minx < 1 then minx = 1 end
	if miny < 1 then miny = 1 end
	if maxx > level.size[1] then maxx = level.size[1] end
	if maxy > level.size[2] then maxy = level.size[2] end

	local numtiles=1
	for x=math.floor(minx),math.floor(maxx) do
		local col = level.objsAtTile[x]
		if not col then
			col = table()
			level.objsAtTile[x] = col
		end
		for y=math.floor(miny),math.floor(maxy) do
			local tile = col[y]
			if not tile then
				tile = {objs=table(),pos=vec2(x,y)}
				col[y] = tile
			end
			tile.objs:insertUnique(self)
			self.tiles[numtiles] = tile
			numtiles = numtiles + 1
		end
	end
end


--[[
move is always run by all objects on update, even if dx,dy == 0,0
for any useGravity objects it'll be 0,-gravity

this means non-solid objects will potentially be starting inside other objects
but they don't collide with other objects anyways, do they?
--]]
Object.SOLID_WORLD = 1
-- TODO all this is mod-specific.  move it to zeta.
Object.SOLID_YES = 2
Object.SOLID_SHOT = 4
Object.SOLID_ITEM = 8
Object.SOLID_NO = 16
Object.SOLID_GRENADE = 32

-- what you are.  used as a reference for others.
Object.solidFlags = Object.SOLID_YES	-- have 'yes'-flags react to you

-- what you can touch.  
-- if your touch flag matches their solid flag (or vice versa) 
-- then both yours and their touch functions will trigger,
-- in order according to each of your touchPriority
Object.touchFlags = -1					-- call touch for everything

-- what blocks you
-- notice if you want something's block to pass thru then have your touch function to return true 
Object.blockFlags = Object.SOLID_WORLD + Object.SOLID_YES

local collisionEpsilon = 1e-4
Object.collisionEpsilon = collisionEpsilon 

local function testBoxBox(self, testStuck, bxmin, bymin, bxmax, bymax, dt, dx, dy)
	if dt == 0 then return dt end
	
	local side

--local print = require 'zeta.script.obj.hero':isa(self) and print or function() end

--print('  ========================')
--print('  == BEGIN BOX/BOX TEST ==')
--print('  ========================')
--print('testing bbox',box2(bxmin,bymin,bxmax,bymax),'dt',dt,'dx',dx,'dy',dy)	

	-- see if we're touching at our current time
	if testStuck
	and self.pos[1]+self.bbox.min[1] < bxmax
	and self.pos[1]+self.bbox.max[1] > bxmin
	and self.pos[2]+self.bbox.min[2] < bymax
	and self.pos[2]+self.bbox.max[2] > bymin
	then
		dt = 0
		-- side is the smallest penetrating side
		local depthXMin = bxmax - self.pos[1] - self.bbox.min[1]
		local depthXMax = self.pos[1] + self.bbox.max[1] - bxmin
		local depthYMin = bymax - self.pos[2] - self.bbox.min[2]
		local depthYMax = self.pos[2] + self.bbox.max[2] - bymin
		local sideX, depthX
		if depthXMin > depthXMax then
			sideX = 'Left'
			depthX = depthXMin
		else
			sideX = 'Right'
			depthX = depthXMax
		end
		local sideY, depthY
		if depthYMin > depthYMax then
			sideY = 'Down'
			depthY = depthYMin
		else
			sideY = 'Up'
			depthY = depthYMax
		end
		-- TODO push back as well?
		if depthX > depthY then
			side = sideX
		else
			side = sideY
		end
--print('stuck with box:',box2(bxmin,bymin,bxmax,bymax))
	
	else
	
		-- not yet touching, see if our step is touching
		local dtx = dt	-- time to x collision
		local sideX
		if dx > 0 then
--print('dtx',dtx,' > 0 so testing right side')
			--self.pos[1] + self.bbox.max[1] + dtx*dx = bxmin 
			dtx = (bxmin - self.pos[1] - self.bbox.max[1]) / dx
			sideX = 'Right'
		elseif dx < 0 then
--print('dtx',dtx,' < 0 so testing left side')
			--self.pos[1] + self.bbox.min[1] + dtx*dx = bxmax 
			dtx = (bxmax - self.pos[1] - self.bbox.min[1]) / dx
			sideX = 'Left'
		end
		if dtx then
			if math.abs(dtx) < collisionEpsilon then dtx = 0 end
--print('found x movement collision',dtx)
			-- if, at that time, we will not be colliding on the other axis, then clear it
			-- because a clear dtx means a full step
--print('blocking y axis info:',tolua({dy = dy,dtx = dtx,self_ymin = self.pos[2] + self.bbox.min[2] + dtx * dy,self_ymax = self.pos[2] + self.bbox.max[2] + dtx * dy,box_ymin = bymin,box_ymax = bymax},{indent=true}))
			-- use < > instead of <= >= to let objects slide across the sides of others
			if not (self.pos[2] + self.bbox.min[2] + dtx * dy < bymax 
				and self.pos[2] + self.bbox.max[2] + dtx * dy > bymin)
			then
--print('recalled x movement collision -- not being blocked on y axis')
				sideX = nil
				dtx = dt 
			end
		end

		local dty = dt	-- time to y collision
		local sideY
		if dy > 0 then
--print('dty',dty,' > 0 so testing up side')
			--self.pos[2] + self.bbox.max[2] + dty*dy = bymin 
			dty = (bymin - self.pos[2] - self.bbox.max[2]) / dy
			sideY = 'Up'
		elseif dy < 0 then
--print('dty',dty,' < 0 so testing down side')
			--self.pos[2] + self.bbox.min[2] + dty*dy = bymax 
			dty = (bymax - self.pos[2] - self.bbox.min[2]) / dy
			sideY = 'Down'
		end
		if dty then
			if math.abs(dty) < collisionEpsilon then dty = 0 end
--print('found y movement collision',dty)			
--print('blocking x axis info:',tolua({dx = dx,dty = dty,self_xmin = self.pos[1] + self.bbox.min[1] + dty * dx,self_xmax = self.pos[1] + self.bbox.max[1] + dty * dx,box_xmin = bxmin, box_xmax = bxmax},{indent=true}))
			if not (self.pos[1] + self.bbox.min[1] + dty * dx < bxmax
				and self.pos[1] + self.bbox.max[1] + dty * dx > bxmin)
			then
--print('recalled y movement collision - not being blocked on x axis')					
				dty = dt
				sideY = nil
			end
		end

		-- if our collision will happen in positive time then find when that is 
--print('checking x collision time',dtx,'to current step time',dt)			
		if 0 <= dtx and dtx < dt then
--print('found it is better - using it')				
			dt = dtx
			side = sideX
		end
--print('checking y collision time',dty,'to current step time',dt)
		if 0 <= dty and dty < dt then
--print('found it is better - using it')
			dt = dty
			side = sideY
		end
--print('returning dt',dt,'side',side)
	end
--print('  ======================')
--print('  == END BOX/BOX TEST ==')
--print('  ======================')
	return dt, side
end

local function buildTileTypePoly(tileType)

	local clipPlane = assert(tileType.plane)

	-- build poly based on clip plane orientation	
	-- TODO cache poly based on planes
	-- or pass the tiletype itself, and cache the poly based on / within the tile type
	local vtxs = table()
	local planes = table()
		
	-- find what bbox vtxs are inside the plane
	local bll = clipPlane[3] <= 0
	local blr = clipPlane[1] + clipPlane[3] <= 0
	local bul = clipPlane[2] + clipPlane[3] <= 0
	local bur = clipPlane[1] + clipPlane[2] + clipPlane[3] <= 0
	local boxVtxsInPlane = (bll and 1 or 0) + (blr and 1 or 0) + (bul and 1 or 0) + (bur and 1 or 0)
	if boxVtxsInPlane == 4 then
		error("this isn't a poly, it's a box!")
	end

	-- intersections of each edge of the box	
	-- plane a x + b y + c = 0
	-- y = -(ax+c)/b
	-- for x=0: y=-c/b
	-- for x=1: y=-(a+c)/b
	-- x = -(by+c)/a
	-- for y=0: x=-c/a
	-- for y=1: x=-(b+c)/a
	
	local fracleft = -clipPlane[3] / clipPlane[2]	-- x=0
	local fracright = -(clipPlane[1] + clipPlane[3]) / clipPlane[2]	-- x=1
	local fracdown = -clipPlane[3] / clipPlane[1]	-- y=0
	local fracup = -(clipPlane[2] + clipPlane[3]) / clipPlane[1]	-- y=1

	if boxVtxsInPlane == 3 then
		if not bll then
			-- 1---2
			-- |   |
			-- b   |
			--  \  |
			--   a-3
			vtxs:insert{0,1}	--1
			planes:insert{0,1,-1}
			vtxs:insert{1,1}	--2
			planes:insert{1,0,-1}
			vtxs:insert{1,0}	--3
			assert(fracdown > 0)	-- or that vtx would be there
			if fracdown < 1 then	-- a is needed
				planes:insert{0,-1,0}
				vtxs:insert{fracdown,0}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracleft > 0)	-- or that vtx would be there
			if fracleft < 1 then	-- b is needed
				vtxs:insert{0,fracleft}
				planes:insert{-1,0,0}
			end
		elseif not blr then
			-- 2---3
			-- |   |
			-- |   a
			-- |  /
			-- 1-b
			vtxs:insert{0,0}	--1
			planes:insert{-1,0,0}
			vtxs:insert{0,1}	--2
			planes:insert{0,1,-1}
			vtxs:insert{1,1}
			assert(fracright > 0)
			if fracright < 1 then
				planes:insert{1,0,-1}
				vtxs:insert{1,fracright} --a
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracleft < 1)
			if fracleft > 0 then
				vtxs:insert{fracleft,0}	-- b
				planes:insert{0,-1,0}
			end
		elseif not bul then
			--   b-1
			--  /  |
			-- a   |
			-- |   |
			-- 3---2
			vtxs:insert{1,1}
			planes:insert{1,0,-1}
			vtxs:insert{1,0}
			planes:insert{0,-1,0}
			vtxs:insert{0,0}
			assert(fracleft < 1)
			if fracleft > 0 then
				planes:insert{-1,0,0}
				vtxs:insert{0,fracleft}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracup > 0)
			if fracup < 1 then
				vtxs:insert{fracleft,1}
				planes:insert{0,1,-1}
			end
		elseif not bur then
			-- 3-a
			-- |  \
			-- |   b
			-- |   |
			-- 2---1
			vtxs:insert{1,0}
			planes:insert{0,-1,0}
			vtxs:insert{0,0}
			planes:insert{-1,0,0}
			vtxs:insert{0,1}
			assert(fracup < 1)
			if fracup > 0 then
				planes:insert{0,1,-1}
				vtxs:insert{fracup,1}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracright < 1)
			if fracright > 0 then
				vtxs:insert{1,fracright}
				planes:insert{1,0,-1}
			end
		end
	elseif boxVtxsInPlane == 2 then
		if not bll and not blr then
			-- 1---2
			-- |   |
			-- b_  |
			--   \_a
			--
			vtxs:insert{1,0}
			planes:insert{0,1,-1}
			vtxs:insert{1,1}
			assert(fracright > 0)
			if fracright < 1 then
				planes:insert{1,0,-1}
				vtxs:insert{1,fracright}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracleft > 0)
			if fracleft < 1 then
				vtxs:insert{0,fracleft}
				planes:insert{-1,0,0}
			end
		elseif not bul and not bur then
			--
			--   __b
			-- a/  |
			-- |   |
			-- 2---1
			vtxs:insert{1,0}
			planes:insert{0,-1,0}
			vtxs:insert{0,0}
			assert(fracleft < 1)
			if fracleft > 0 then
				planes:insert{-1,0,0}
				vtxs:insert{0,fracleft}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracright < 1)
			if fracright > 0 then
				vtxs:insert{1,fracright}
				planes:insert{1,0,-1}
			end
		elseif not bll and not bul then
			--  b--1
			--  |  |
			--  |  |
			--  \  |
			--   a-2
			vtxs:insert{1,1}
			planes:insert{1,0,-1}
			vtxs:insert{1,0}
			assert(fracdown > 0)
			if fracdown < 1 then
				planes:insert{0,-1,0}
				vtxs:insert{fracdown,0}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracup > 0)
			if fracup < 1 then
				vtxs:insert{fracup,1}
				planes:insert{0,1,-1}
			end
		elseif not blr and not bur then
			-- 2--a
			-- |  |
			-- |  |
			-- |  /
			-- 1-b 
			vtxs:insert{0,0}
			planes:insert{-1,0,0}
			vtxs:insert{0,1}
			assert(fracup < 1)
			if fracup > 0 then
				planes:insert{0,1,-1}
				vtxs:insert{fracup,1}
			end
			planes:insert{clipPlane[1],clipPlane[2],clipPlane[3]}
			assert(fracdown < 1)
			if fracdown > 0 then
				vtxs:insert{fracdown,0}
				planes:insert{0,-1,0}
			end
		else
			error("how did one plane chop out diagonal vertices?")
		end
	else
		error("no support for only one vertex in bbox polys")
	end
	assert(#vtxs == #planes)

	return {vtxs=vtxs, planes=planes}
end

--[[
self has pos and bbox
x is the 1x1 bbox lower left coordinate
plane is the plane that chops the box
	assumes the plane normal is unit
--]]
local function testBoxSlope(self, testStuck, x, y, tileType, dt, dx, dy)
	-- we only handle dt==0 collisions if we're testing interpenetration, i.e. non-blocking touch callbacks 
	-- and at the moment there are no non-blocking tiles, nor tile touch callbacks
	if dt == 0 then return dt end

--local print = require 'zeta.script.obj.hero':isa(self) and print or function() end

--print('  ==========================')
--print('  == BEGIN BOX/SLOPE TEST ==')
--print('  ==========================')
--print('testing sloped box at',x,y,'with plane',table.concat(clipPlane,','),'dt',dt,'dx',dx,'dy',dy)

	if not tileType.poly then
		tileType.poly = buildTileTypePoly(tileType)
	end

	local vtxs = tileType.poly.vtxs
	local planes = tileType.poly.planes

--print('vtxs:',table.map(vtxs,function(vtx) return '['..table.concat(vtx,',')..']' end):concat(' '))
--print('planes:',table.map(planes,function(vtx) return '['..table.concat(vtx,',')..']' end):concat(' '))

	local bestNormal	-- pointing towards self, so when self tests obj, bestNormal is negative of the plane normal

	-- 1) find separating plane greatest depth (positive means we're separating) (plane depth is min of depths of all vtxs, intersection depth is max plane depth)
	if testStuck then
		-- test self bbox to obj vtxs
			-- right
		local bestPlaneDepth = -math.huge
		local planeDepth = math.huge
		for _,vtx in ipairs(vtxs) do
			planeDepth = math.min(planeDepth, (x + vtx[1]) - (self.pos[1] + self.bbox.max[1]))
		end
		if planeDepth > bestPlaneDepth then
			bestPlaneDepth = planeDepth
			bestNormal = {-1, 0}
		end
				-- left	
		local planeDepth = math.huge
		for _,vtx in ipairs(vtxs) do
			planeDepth = math.min(planeDepth, (self.pos[1] + self.bbox.min[1]) - (x + vtx[1]))
		end
		if planeDepth > bestPlaneDepth then
			bestPlaneDepth = planeDepth
			bestNormal = {1, 0}
		end
				-- up
		local planeDepth = math.huge
		for _,vtx in ipairs(vtxs) do
			planeDepth = math.min(planeDepth, (y + vtx[2]) - (self.pos[2] + self.bbox.max[2]))
		end
		if planeDepth > bestPlaneDepth then
			bestPlaneDepth = planeDepth
			bestNormal = {0, -1}
		end	
				-- down
		local planeDepth = math.huge
		for _,vtx in ipairs(vtxs) do
			planeDepth = math.min(planeDepth, (self.pos[2] + self.bbox.min[2]) - (y + vtx[2]))
		end
		if planeDepth > bestPlaneDepth then
			bestPlaneDepth = planeDepth
			bestNormal = {0, 1}
		end

			-- test obj planes to self bbox corners
		for _,plane in ipairs(planes) do
			local planeDepth = math.huge
			for xminmax=1,2 do
				for yminmax=1,2 do
					local vx = self.pos[1] + (xminmax == 1 and self.bbox.min[1] or self.bbox.max[1])
					local vy = self.pos[2] + (yminmax == 1 and self.bbox.min[2] or self.bbox.max[2])
					planeDepth = math.min(planeDepth, plane[1] * (vx - x) + plane[2] * (vy - y) + plane[3])
				end
			end
			if planeDepth > bestPlaneDepth then
				bestPlaneDepth = planeDepth
				bestNormal = plane
			end
		end
--print('bestPlaneDepth',bestPlaneDepth,'bestNormal',table.unpack(bestNormal))
		if bestPlaneDepth < 0 then
--print("bestPlaneDepth < 0 means we're stuck")		
			dt = 0		-- stuck
		end
	end
		
	-- if dt == 0 then -- all our dtv tests are dtv < dt -- so we can't hit anything else
	if dt > 0 then
		-- not moving?
		bestNormal = nil	-- will this cause problems?
		if dx ~= 0 or dy ~= 0 then

			-- 2) find intersection of movement along dx,dy
			-- trace all 'self' vtxs forward on dx,dy, test with intersection against normals within vtxs
			-- then do the same with vtxs backward on dx,dy, test with self sides.

			-- move 4 vtxs of self.pos+self.bbox

--print('testing self vtxs against slopebox planes') 
			-- normal[i] is the normal of the edge between vtxs[i] and vtxs[i+1]
			-- but really just use -y,x and normalize it ...
			for i=1,#vtxs do
				local va = vtxs[i]
				local vb = vtxs[i%#vtxs+1]
				local plane = planes[i]

				-- current problem:
				-- moving diagonal right up
				-- hitting lower right corner on the bottom plane
				-- plane dot delta says it should be hitting
				-- but the corner ... technically can't hti that
			
				-- testing plane normal to move delta is a good idea
				local planeDotDelta = plane[1] * dx + plane[2] * dy

--print('plane dot delta',planeDotDelta)				
				if planeDotDelta < 0 then	-- moving into the plane?
--print('testing slopebox edge ['..va[1]..','..va[2]..'] -> ['..vb[1]..','..vb[2]..']')
					for xminmax=1,2 do
						for yminmax=1,2 do
							-- also test plane normal to both planes that the vertex lies on
							-- if it is within 90 of both then use this vertex
							local planeDotVtxPlane1 = plane[1] * (xminmax == 1 and -1 or 1)
							local planeDotVtxPlane2 = plane[2] * (yminmax == 1 and -1 or 1)
							if planeDotVtxPlane1 < 0 or planeDotVtxPlane2 < 0 then
								local vx = self.pos[1] + (xminmax == 1 and self.bbox.min[1] or self.bbox.max[1])
								local vy = self.pos[2] + (yminmax == 1 and self.bbox.min[2] or self.bbox.max[2])
--print('testing self vtx ['..vx..','..vy..']')
						
								local vabx = vb[1] - va[1]
								local vaby = vb[2] - va[2]
								-- vx + dtv * dx = va[1] + s * vabx
								-- vy + dtv * dy = va[2] + s * vaby
								--
								-- [dx -vabx][dtv] = x + va[1] - vx = v_va_x
								-- [dy -vaby][ s ] = y + va[2] - vy = v_va_y
								-- [dtv] = [-vaby vabx] v_va_x
								-- [ s ] = [ -dy   dx ] v_va_y
								local v_va_x = (x + va[1]) - vx
								local v_va_y = (y + va[2]) - vy

								local det = -dx * vaby + dy * vabx
								if det ~= 0 then	-- 0 means perpendicular
									local s = (-dy * v_va_x + dx * v_va_y) / det
									-- use >= <= to hit corners 
									if s >= 0 and s <= 1 then
										local dtv = (-vaby * v_va_x + vabx * v_va_y) / det
										-- getting toe-stumping midway up slopes ...
										-- either restrict timestep or push back from normal or both
										dtv = dtv / (1 + collisionEpsilon)
										if math.abs(dtv) < collisionEpsilon then dtv = 0 end
										if dtv >= 0 and dtv < dt then
											dt = dtv
											bestNormal = planes[i]
--print('found collision at dt',dt,'normal',table.unpack(bestNormal))
										end
									end
								end
							end
						end
					end
				end
			end

--print('testing slopebox vtxs against self planes') 
			-- move poly by -dx, -dy against bbox
			for _,vtx in ipairs(vtxs) do
--print('testing vtx',table.unpack(vtx))				

				local dtx
				if dx < 0 then
					-- left of self
					-- (x + vtx[1]) - dx * dtu = self.pos[1] + self.bbox.max[1]
					dtx = ((self.pos[1] + self.bbox.min[1]) - (x + vtx[1])) / -dx
				elseif dx > 0 then
					-- right of self
					-- (x + vtx[1]) - dx * dtx = self.pos[1] + self.bbox.max[1]
					dtx = ((self.pos[1] + self.bbox.max[1]) - (x + vtx[1])) / -dx
				end
				if dtx then
					if math.abs(dtx) < collisionEpsilon then dtx = 0 end
					-- make sure our collision time 
					if 0 <= dtx and dtx < dt 
					-- make sure we're colliding on the self at that point
					and self.pos[2] + self.bbox.min[2] < y + vtx[2] - dtx * dy
					and self.pos[2] + self.bbox.max[2] > y + vtx[2] - dtx * dy
					then
						dt = dtx
						bestNormal = dx < 0 and {1,0} or {-1,0}
--print('found x collision at dt',dt,'normal',table.unpack(bestNormal))									
					end
				end
				
				local dty
				if dy < 0 then
					-- bottom of self 
					-- (y + vtx[2]) - dy * dtu = self.pos[2] + self.bbox.max[2]
					dty = ((self.pos[2] + self.bbox.min[2]) - (y + vtx[2])) / -dy
				elseif dy > 0 then
					-- top of self 
					-- (y + vtx[2]) - dy * dty = self.pos[2] + self.bbox.max[2]
					dty = ((self.pos[2] + self.bbox.max[2]) - (y + vtx[2])) / -dy
				end
				if dty then
					if math.abs(dty) < collisionEpsilon then dty = 0 end
					if 0 <= dty and dty < dt 
					-- make sure we're colliding on the self at that point
					and self.pos[1] + self.bbox.min[1] < x + vtx[1] - dty * dx
					and self.pos[1] + self.bbox.max[1] > x + vtx[1] - dty * dx
					then
						dt = dty
						bestNormal = dy < 0 and {0,1} or {0,-1}
--print('found y collision at dt',dt,'normal',table.unpack(bestNormal))									
					end
				end		
			end
		end
	end

--print('returning dt',dt,'bestNormal',table.concat(bestNormal or {}, ','))
--print('  ========================')
--print('  == END BOX/SLOPE TEST ==')
--print('  ========================')

	return dt, bestNormal
end


--[[
local numObjsTested = 0
local avgNumTestsPerObj = 0
function Object.debugUpdate()
print(numObjsTested..' objs tested, '..avgNumTestsPerObj / numObjsTested..' avg objs per test')
avgNumTestsPerObj = 0 
numObjsTested = 0
end
--]]

function Object:move_sub(dx,dy)

--local print = require 'zeta.script.obj.hero':isa(self) and print or function() end
	
	-- make sure you can't hit an object twice in the same movement
	-- needed for movements that start inside non-solid objects
	-- TODO less allocations here
	local objsTested
	local tilesTested

--print()
--print('================')
--print('== BEGIN MOVE ==')
--print('================')

	local level = game.level

	local t = 0
	local dt = 1
	-- assume self.pos is the position at time 't'
	-- if we're not letting passthru objects then up to 2 tries
	--for tries=1,2 do	-- up to 2 tries before all axii are blocked completely
	-- if we are then ... #game.objs ...
	local maxTries = 100
	for tries=1,maxTries+1 do
		if tries == maxTries+1 then
			print("too many collision tries")
		end
--print(' =================')
--print(' == BEGIN TRACE ==')
--print(' =================')
--print('obj pos',self.pos,'box',self.bbox+self.pos,'moving',vec2(dx,dy))
--print('dx,dy before epsilon test:',vec2(dx,dy))
	  if math.abs(dx) < collisionEpsilon then dx = 0 end
	  if math.abs(dy) < collisionEpsilon then dy = 0 end
--print('dx,dy after epsilon test:',vec2(dx,dy))
		
		local side
		local normal
		local touchedObj
		local touchedTileType
		local touchedTileX, touchedTileY
		
		-- get combined bbox of current bbox and destination bbox
		local cxmin = self.pos[1] + self.bbox.min[1] + math.min(dt * dx,0)
		local cymin = self.pos[2] + self.bbox.min[2] + math.min(dt * dy,0)
		local cxmax = self.pos[1] + self.bbox.max[1] + math.max(dt * dx,0)
		local cymax = self.pos[2] + self.bbox.max[2] + math.max(dt * dy,0)
--print('testing entire bbox',box2(cxmin,cymin,cxmax,cymax)) 
		
		local xmin = math.floor(cxmin)-1
		local ymin = math.floor(cymin)-1
		local xmax = math.floor(cxmax)+1
		local ymax = math.floor(cymax)+1
--print('testing tile bounds',box2(xmin,ymin,xmax,ymax))
		-- test oob
		if xmax < 1 or ymax < 1 or xmin > level.size[1] or ymin > level.size[2] then
--print('movement off the tile map')
		else
			-- clamp size
			if xmin < 1 then xmin = 1 end
			if xmax > level.size[1] then xmax = level.size[1] end
			if ymin < 1 then ymin = 1 end
			if ymax > level.size[2] then ymax = level.size[2] end	
			
			-- if we can collide with the world
			-- I'm not checking touchFlags because allowing touching non-blocking tiles 
			--  would mean rechecking tiles with certain tiles (previously checked, touched, and non-blocked) excluded
			-- which I don't have support for, nor see a use for
			-- I'm thinking of getting rid of tile.touch anyways.
			if bit.band(self.blockFlags, Object.SOLID_WORLD) ~= 0 then

			-- test world
--print('clamped tile bounds to',box2(xmin,ymin,xmax,ymax))			
				for y=ymin,ymax do
					for x=xmin,xmax do
						local tileType = level:getTile(x,y)
						if tileType
						and tileType.solid
						and (not tilesTested or not table.find(tilesTested, vec2(x,y)))
						then
							if not tileType.plane then
								local newSide
								dt, newSide = testBoxBox(self, false, x,y,x+1,y+1, dt, dx, dy)
								if newSide then
									side = newSide
									normal = dirs[oppositeSide[side:lower()]]
									touchedObj = nil
									touchedTileType = tileType
									touchedTileX = x
									touchedTileY = y
								end
							else
--[[ real-deal poly intersection								
								local newNormal
								dt, newNormal = testBoxSlope(self, false, x, y, tileType, dt, dx, dy)
								if newNormal then
									normal = newNormal
									local adx = math.abs(normal[1])
									local ady = math.abs(normal[2])
									if adx > ady then
										side = normal[1] < 0 and 'Right' or 'Left'
									else
										side = normal[2] < 0 and 'Up' or 'Down'
									end
									touchedObj = nil
									touchedTileType = tileType
									touchedTileX = x
									touchedTileY = y
								end
--]]
-- [=[ poor-man's chop it up into tiny pieces							
								local udivs = 16
								local vdivs = 16
								local plane = tileType.plane
								for v=0,vdivs-1 do
									for u=0,udivs-1 do
										local inside = plane[1] * (u+.5)/udivs + plane[2] * (v+.5)/vdivs + plane[3] <= 0
										if inside then
											local newSide
											dt, newSide = testBoxBox(self, false, x + u/udivs, y + v/vdivs, x + (u+1)/udivs,y + (v+1)/vdivs, dt, dx, dy)
											if newSide then
												side = newSide
												normal = dirs[oppositeSide[side:lower()]]	-- plane 
												touchedObj = nil
												touchedTileType = tileType
												touchedTileX = x
												touchedTileY = y
											end
										end
									end
								end
--]=]
							end
						end
					end
				end
			end
				
			-- test objs	
			for x=xmin,xmax do
				local col = level.objsAtTile[x]
				if col then
					for y=ymin,ymax do
						local tile = col[y]
						if tile then
							
							for _,obj in ipairs(tile.objs) do
								-- don't collide self with self
								if not obj.remove
								and obj ~= self 
								-- only collide if we will can touch or be blocked by them
								and (bit.band(self.touchFlags, obj.solidFlags) ~= 0
									or bit.band(obj.touchFlags, self.solidFlags) ~= 0
									or bit.band(self.blockFlags, obj.solidFlags) ~= 0
									--or bit.band(obj.blockFlags, self.solidFlags) ~= 0
								)
								-- only collide objects touching the combined bbox
								and cxmin <= obj.pos[1] + obj.bbox.max[1]
								and cxmax >= obj.pos[1] + obj.bbox.min[1]
								and cymin <= obj.pos[2] + obj.bbox.max[2]
								and cymax >= obj.pos[2] + obj.bbox.min[2]
								-- don't check objects twice
								and (not objsTested or not table.find(objsTested, obj))
								then
					--avgNumTestsPerObj = avgNumTestsPerObj + 1 
									
									local newSide
									dt, newSide = testBoxBox(
										self,
										true,	-- testStuck.  only needs to be true if self isn't blocked by this object. 
										obj.pos[1]+obj.bbox.min[1],
										obj.pos[2]+obj.bbox.min[2],
										obj.pos[1]+obj.bbox.max[1],
										obj.pos[2]+obj.bbox.max[2],
										dt,
										dx,
										dy)
									if newSide then
										side = newSide
										normal = dirs[oppositeSide[side:lower()]]
										touchedObj = obj
										touchedTileType = nil
										touchedTileX = nil
										touchedTileY = nil
									end
								end
							end
						end
					end
				end
			end
		end

		if math.abs(dt) < collisionEpsilon then dt = 0 end
		assert(dt >= 0)

		-- move up to the point of collision
--print('starttime is t=',t)
--print('stepping by timestep dt=',dt)
		t = t + dt
		self.pos[1] = self.pos[1] + dt * dx
		self.pos[2] = self.pos[2] + dt * dy

		if t < 1 then
			dt = 1 - t
			if math.abs(dt) < collisionEpsilon then 
				t = 1
				dt = 0 
			end
		end

		-- are these two exclusive?
		-- so long as I'm using newDT < dt tests to register new collisions, they should be
		assert(t == 1 or side)

--print('collided on side',side)
		if side then
			local lside = side:lower()
			assert(normal, "got side set without normal")

			-- run 'touch' after velocity clipping
			-- pass collision velocity as a separate parameter?
			local dontblock
			if touchedTileType then
--print('calling self.touchTile',self.touchTile,touchedTileType,lside,normal)
				if self.touchTile then dontblock = self:touchTile(touchedTileType, lside, normal, touchedTileX, touchedTileY) or dontblock end
				if self.remove then return end
				-- TODO tile touch callbacks?
			end
			
--print('touchedObj is',touchedObj)			
			if touchedObj then
--print('checking self.touchFlags',self.touchFlags,'vs touchedObj.solidFlags',touchedObj.solidFlags)
				if bit.band(self.touchFlags, touchedObj.solidFlags) ~= 0 
				or bit.band(touchedObj.touchFlags, self.solidFlags) ~= 0
				then
--print('running touches based on priority. self.touchPriority=',self.touchPriority,'touchedObj.touchPriority=',touchedObj.touchPriority)					
					local opposite = oppositeSide[lside] or error("can't find opposite side for side "..tostring(side))
					if self.touchPriority >= touchedObj.touchPriority then
						if self.touch then dontblock = self:touch(touchedObj, lside) or dontblock end
						if not touchedObj.remove and touchedObj.touch then dontblock = touchedObj:touch(self, opposite) or dontblock end
					else
						if touchedObj.touch then dontblock = touchedObj:touch(self, opposite) or dontblock end
						if not touchedObj.remove and self.touch then dontblock = self:touch(touchedObj, lside) or dontblock end
					end
					if self.remove then return end
--print('after calling touch, dontblock=',dontblock)				
				end
			end
			
			-- flags of who we're touching.  or WORLD if we're touching the world.
			local touchedSolidFlags = touchedObj and touchedObj.solidFlags or Object.SOLID_WORLD
			local touchedBlockFlags = touchedObj and touchedObj.blockFlags or 0
--print('checking self.blockFlags=',self.blockFlags,' vs touchedSolidFlags=',touchedSolidFlags,' and not dontblock=',dontblock)
			-- if the touch didn't override the blocking
			if not dontblock
			-- if we're supposed to be blocked by this entity
			and (bit.band(self.blockFlags, touchedSolidFlags) ~= 0
				--or bit.band(touchedBlockFlags, self.solidFlags) ~= 0
			)
			then
				-- TODO push objects out of the way
--print('setting collision flags for side',side,'for obj',touchedObj)
				self['collided'..side] = true
				self['touchEnt'..side] = touchedObj

--print('normal',table.unpack(normal))
				-- clip velocity and movement on the collided axis and try again
				local vDotN = self.vel:dot(normal)
--print('self.vel',self.vel[1],self.vel[2])
--print('velocity dot normal',vDotN)				
				if vDotN < 0 then
--print('zeroing velocity against normal')
					self.vel[1] = self.vel[1] - normal[1] * vDotN
					self.vel[2] = self.vel[2] - normal[2] * vDotN
--print('self.vel is now',self.vel[1],self.vel[2])
				end
			
--print('delta',dx,dy)
				local deltaDotN = dx * normal[1] + dy * normal[2]
--print('delta dot normal',deltaDotN)
				if deltaDotN < 0 then
--print('zeroing delta against normal')					
					dx = dx - normal[1] * deltaDotN
					dy = dy - normal[2] * deltaDotN
--print('delta is now',dx,dy)				
				end
			end
			
			-- don't check this object/tile again
			-- that way if it can be passed through
			-- then the next traceline won't check it
			if touchedObj then
--print('adding obj',touchedObj,'to the already-checked list')				
				if not objsTested then objsTested = {} end
				table.insert(objsTested, touchedObj)
			end
			if touchedTileType and not touchedTileType.plane then
				if not tilesTested then tilesTested = {} end
				table.insert(tilesTested, vec2(touchedTileX, touchedTileY))
			end
		end

--print(' ===============')
--print(' == END TRACE ==')
--print(' ===============')

		if t == 1 then
--print('completely whole timestep -- breaking')
			break
		end
		if dx == 0 and dy == 0 then
--print('movement stuck -- breaking')
			break
		end
	end

	-- TODO onground = collidedDown only if collision was with a solid object
	self.onground = self.collidedDown
--print('onground',self.onground)

--print('==============')
--print('== END MOVE ==')
--print('==============')
end

--[[ physics!
Object.move = Object.move_sub
--]]
-- [[ poor-man's way to do collision: move up, move across, move down (for steps)
function Object:move(dx,dy)
	self:unlink()

	-- if moving left/right then try stepping up as well
	if self.ongroundLast
	and dx ~= 0
	then
		local stepHeight = .3
		self:move_sub(0,stepHeight)
		self:move_sub(dx,dy)
		self:move_sub(0,-1.5*stepHeight)
	else
		self:move_sub(dx,dy)
	end

--numObjsTested = numObjsTested + 1
	self:link()
end
--]]

-- new system
Object.touch = nil -- function(other, side) 

function Object:draw(R, viewBBox, holdOverride)
	if not self.sprite then return end
	
	-- heldby means re-rendering the obj to keep it in frame sync with the player	
	if self.heldby and not holdOverride then return end
	
	local tex
	if self.tex then
		tex = self.tex
	elseif self.sprite then
		tex = animsys:getTex(self.sprite, self.seq or 'stand', self.seqStartTime)
	end
	if tex then tex:bind() end
	local cr,cg,cb,ca
	if self.color then
		cr,cg,cb,ca = unpack(self.color)
	else
		cr,cg,cb,ca = 1,1,1,1
	end

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

	R:quad(
		self.pos[1] - cx,
		self.pos[2] - cy,
		sx, sy,
		uBias, vBias,
		uScale, vScale,
		self.angle,
		cr,cg,cb,ca,
		self.shader,
		self.uniforms,
		rcx, rcy)
end

function Object:playSound(name, volume, pitch)
	-- openal supports only one listener
	-- rather than reposition the listener according to what player is closest ... position the sound!
	-- and don't bother with listener velocity
	local closestPlayer, closestDistSq
	-- TODO only cycle through local connections
	for _,player in ipairs(game.players) do
		local dx, dy = player.pos[1] - self.pos[1], player.pos[2] - self.pos[2]
		local distSq = dx * dx + dy * dy
		if not closestDistSq or closestDistSq > distSq then
			closestDistSq = distSq
			closestPlayer = player
		end
	end
	if closestDistSq > game.maxAudioDist * game.maxAudioDist then return end

	-- clientside ...
	local source = game:getNextAudioSource()
	if not source then
		print('all audio sources used')
		return
	end

	local sound = sounds:load(name..'.wav')
	source:setBuffer(sound)
	source:setGain((volume or 1) * game.volume)
	source:setPitch(pitch or 1)
	source:setPosition(self.pos[1] - closestPlayer.pos[1], self.pos[2] - closestPlayer.pos[2], 0)
	source:setVelocity(self.vel[1] - closestPlayer.vel[1], self.vel[2] - closestPlayer.vel[2], 0)
	source:play()

	return source
end

return Object
