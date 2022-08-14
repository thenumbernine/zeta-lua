-- TODO use ffi vec2's with x and y fields?
local vec2 = require 'vec.vec2'
dirs = {
	up = vec2(0,1),
	down = vec2(0,-1),
	left = vec2(-1,0),
	right = vec2(1,0),
}

oppositeSide = {
	up = 'down',
	down = 'up',
	left = 'right',
	right = 'left',
}
