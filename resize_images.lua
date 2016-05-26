#!/usr/bin/env luajit
-- dragonbones adds transparent padding, 
-- and if I output it to a smaller res, messes with it
-- so I'll resize it here
require 'ext'
local box2 = require 'vec.box2'
local Image = require 'image'

local dir = assert(arg[1], "expected dir")
print('dir:',dir)

local targetSize = tostring(arg[2]) or 32
print('target size:',targetSize)

local files = table()
for f in file[dir]() do
	if f:match('%.png$') then
		files:insert(f)
	end
end
print('files',files:concat(' '))

os.execute('mkdir resized')

for _,file in ipairs(files) do
	local image = Image(dir..'/'..file)
	assert(image.channels == 4)	
	
	-- trim whitespace
	local b = box2{min={math.huge,math.huge},max={-math.huge,-math.huge}} 
	for y=0,image.height-1 do
		for x=0,image.width-1 do
			local alpha = image.buffer[3+4*(x+image.width*y)]
			if alpha > 127 then
				if x < b.min[1] then b.min[1] = x end 
				if x > b.max[1] then b.max[1] = x end 
				if y < b.min[2] then b.min[2] = y end 
				if y > b.max[2] then b.max[2] = y end 
			end
		end
	end
	print('bbox',b)
print('copying')
	image = image:copy{x=b.min[1], y=b.min[2], width=b.max[1]-b.min[1]+1, height=b.max[2]-b.min[2]+1}
print('resizing')
	local w,h = image:size()
	image = image:resize(w/h*targetSize,targetSize)
print('saving')	
	image:save('resized/'..file)
end
