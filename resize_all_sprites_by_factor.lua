#!/usr/bin/env luajit
require 'ext'
local Image = require 'image'
for dir in file['.']() do
	if file[dir].path then	-- this will error if it fails ...
		for f in file[dir]() do
			if f:match('%.png$') then
				local fn = dir..'/'..f
				local image = Image(fn)
				local w, h = image:size()
				image = image:resize(w*2, h*2)
				image:save(fn)
				print(fn, image:size())
			end
		end
	end
end
