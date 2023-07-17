#!/usr/bin/env luajit
local path = require 'ext.path'
local Image = require 'image'
for dir in path:dir() do
	if path(dir):isdir() then	-- this will error if it fails ...
		for f in path(dir):dir() do
			if f:match'%.png$' then
				local fn = dir..'/'..f
				local image = Image(fn)
				local w, h = image:size()
				image = image:resize(w/2, h/2)
				image:save(fn)
				print(fn, image:size())
			end
		end
	end
end
