local class = require 'ext.class'

local function stateMachineBehavior(parentClass)
	local StateMachineTemplate = class(parentClass)

	--StateMachineTemplate.initialState = nil
	StateMachineTemplate.states = {}
	
	function StateMachineTemplate:init(args, ...)
		StateMachineTemplate.super.init(self, args, ...)
		self:setState(self.initialState)
	end

	function StateMachineTemplate:setState(state)
		if state and not self.states[state] then
			error("failed to find state named "..tostring(state))
		end
		
		local oldState = self.states[self.state]
		if oldState and oldState.exit then oldState.exit(self) end
		self.state = state
		local newState = self.states[state]
		if newState and newState.enter then newState.enter(self) end
	end

	function StateMachineTemplate:update(...)
		StateMachineTemplate.super.update(self, ...)
		if self.state then
			local state = self.states[self.state]
			if state and state.update then
				state.update(self, ...)
			end
		end
	end
	
	return StateMachineTemplate 
end

return stateMachineBehavior
