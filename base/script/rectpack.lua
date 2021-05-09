-- from https://www.david-colson.com/2020/03/10/exploring-rect-packing.html

local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'

local DynamicGrid = class()

-- what's this?
DynamicGrid.gridSize = 512

function DynamicGrid:init(width, height, gridSize)
	assert(width)
	assert(height)
	assert(gridSize)

	self.gridSize = gridSize

	-- 1-based
	self.rows = table{
		{size = width, index = 0},
	}

	-- 1-based
	self.columns = table{
		{size = height, index = 0},
	}

	-- 1-based
	self.data = range(self.gridSize * self.gridSize):mapi(function()
		return false
	end)
end

function DynamicGrid:Get(x, y)
	local rowIndex = self.rows[1 + y].index
	local columnIndex = self.columns[1 + x].index
	return self.data[1 + self:GetDataLocation(columnIndex, rowIndex)]
end

function DynamicGrid:Set(x, y, val)
	local rowIndex = self.rows[1 + y].index
	local columnIndex = self.columns[1 + x].index
	self.data[1 + self:GetDataLocation(columnIndex, rowIndex)] = val
end

function DynamicGrid:GetDataLocation(x, y)
	return self.gridSize * y + x;
end

function DynamicGrid:GetRowHeight(y)
	return self.rows[1 + y].size
end

function DynamicGrid:GetColumnWidth(x)
	return self.columns[1 + x].size
end

function DynamicGrid:InsertRow(atY, oldRowHeight)
	local rowIndex = self.rows[1 + atY].index
	for i=0,#self.columns-1 do
		self.data[1 + self:GetDataLocation(i, #self.rows)] = self.data[1 + self:GetDataLocation(i, rowIndex)]
	end

	local old = self.rows[1 + atY]

	self.rows:insert(1 + atY, {
		size = old.size - oldRowHeight,
		index = #self.rows,
	})

	self.rows[1 + atY+1].size = oldRowHeight
end

function DynamicGrid:InsertColumn(atX, oldRowWidth)
	local columnIndex = self.columns[1 + atX].index
	for i=0,#self.rows-1 do
		self.data[1 + self:GetDataLocation(#self.columns, i)] = self.data[1 + self:GetDataLocation(columnIndex, i)]
	end

	local old = self.columns[1 + atX]

	self.columns:insert(1 + atX, {
		size = old.size - oldRowWidth,
		index = #self.columns,
	})

	self.columns[1 + atX+1].size = oldRowWidth
end

function DynamicGrid:CanBePlaced(desiredNode, desiredRectSize, outRequiredNodes, outRemainingSize)
	local foundWidth = 0
	local foundHeight = 0
	local trialX = desiredNode.x
	local trialY = desiredNode.y

	while foundHeight < desiredRectSize.y do
		trialX = desiredNode.x
		foundWidth = 0

		if trialY >= #self.rows then
			return false
		end

		foundHeight = foundHeight + self:GetRowHeight(trialY)
		
		while foundWidth < desiredRectSize.x do
			if trialX >= #self.columns then
				return false
			end

			if self:Get(trialX, trialY) then
				return false
			end

			foundWidth = foundWidth + self:GetColumnWidth(trialX)
			trialX = trialX + 1
		end
		trialY = trialY + 1
	end

	if trialX - desiredNode.x <= 0 
	or trialY - desiredNode.y <= 0 
	then
		return false
	end

	outRequiredNodes.x = trialX - desiredNode.x
	outRequiredNodes.y = trialY - desiredNode.y
	outRemainingSize.x = foundWidth - desiredRectSize.x
	outRemainingSize.y = foundHeight - desiredRectSize.y

	return true
end

--[[
struct Rect
{
	int x, y;
	int w, h;
};
--]]

function PackRectsGridSplitter(rects, width, height, gridSize)
 	table.sort(rects, function(a,b)
		if a.h < b.h then return true end
		if a.h > b.h then return false end
		if a.w < b.w then return true end
		if a.w > b.w then return false end
		return false
	end)

	local grid = DynamicGrid(width, height, gridSize)
	
	for _,rect in ipairs(rects) do
		local done = false
		local yPos = 0
		for y = 0,#grid.rows-1 do
			if done then break end
			
			local xPos = 0
			for x = 0,#grid.columns-1 do
				if done then break end

				local leftOverSize = {x=0, y=0}
				local requiredNodes = {x=0, y=0}
				if grid:CanBePlaced({x=x, y=y}, {x=rect.w, y=rect.h}, requiredNodes, leftOverSize) then
					done = true
					rect.x = xPos
					rect.y = yPos

					local xFarRightColumn = x + requiredNodes.x - 1
					grid:InsertColumn(xFarRightColumn, leftOverSize.x)

					local yFarBottomRow = y + requiredNodes.y - 1
					grid:InsertRow(yFarBottomRow, leftOverSize.y)

					for i = x + requiredNodes.x - 1, x, -1 do
						for j = y + requiredNodes.y - 1, y, -1 do
							grid:Set(i, j, true)
						end
					end
				end
				xPos = xPos + grid:GetColumnWidth(x)
			end
			yPos = yPos + grid:GetRowHeight(y)
		end

		if not done then
			rect.failedToPack = true
		end
	end

	return grid
end

return PackRectsGridSplitter
