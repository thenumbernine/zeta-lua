#!/usr/bin/env luajit
local os = require 'ext.os'
local table = require 'ext.table'

local cmd = [[find . -name "*.png" -print0 | xargs -0 pngcrush -c 6 -ow -rem allb -reduce]]
assert(os.execute(cmd))

local cmd = [[find . -name "*.png" -print0 | xargs -0 pngcrush -c 6 -srgb 3 -ow -rem cHRM -rem gAMA -rem iCCP -rem sRGB]]
assert(os.execute(cmd))

local cmd = [[find . -name "*.png" -print0 | xargs -0 mogrify -strip -define png:color-type=6]]
assert(os.execute(cmd))

local Image = require 'image'
local image = Image'mario/maps/mine/tile.png'
local w,h,chs = image:size()
local x,y = 7,10
local px = table()
for ch=0,2 do
	px:insert(image.buffer[ch+chs*(x+w*y)])
end
print(('%2x %2x %2x'):format(px:unpack()))
