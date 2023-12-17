#!/usr/bin/env luajit
local path = require 'ext.path'
local Image = require 'image'
for dir in path:dir() do
	if dir:isdir() then	-- this will error if it fails ...
		for f in dir:dir() do
			if f.path:match'%.png$' then
				local fn = dir/f
				local image = Image(fn.path)
				local w, h = image:size()
				image = image:resize(w/2, h/2)
				image:save(fn.path)
				print(fn.path, image:size())
			end
		end
	end
end
