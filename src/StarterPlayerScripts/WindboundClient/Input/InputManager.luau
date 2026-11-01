--!strict
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local InputManager = {}

local dashCallbacks: { () -> () } = {}
local toggleLaunchCallbacks: { () -> () } = {}
local spaceCallbacks: { () -> () } = {}
local captureCallbacks: { () -> () } = {}

function InputManager.init()
	-- 1. PC Keyboard & Mouse Input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.E then
			for _, cb in toggleLaunchCallbacks do cb() end
		elseif input.KeyCode == Enum.KeyCode.Space then
			for _, cb in spaceCallbacks do cb() end
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q then
			for _, cb in dashCallbacks do cb() end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.C then
			for _, cb in captureCallbacks do cb() end
		end
	end)
	
	-- 2. Console Gamepad Action Bindings
	ContextActionService:BindAction("Windbound_Dash", function(actionName, inputState)
		if inputState == Enum.UserInputState.Begin then
			for _, cb in dashCallbacks do cb() end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonA)
	
	ContextActionService:BindAction("Windbound_Recall", function(actionName, inputState)
		if inputState == Enum.UserInputState.Begin then
			for _, cb in toggleLaunchCallbacks do cb() end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)
	
	ContextActionService:BindAction("Windbound_Capture", function(actionName, inputState)
		if inputState == Enum.UserInputState.Begin then
			for _, cb in captureCallbacks do cb() end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonR2)
	
	-- 3. Mobile Touch Action Buttons (via ContextActionService with touch buttons)
	if UserInputService.TouchEnabled then
		ContextActionService:BindAction("Windbound_MobileLaunch", function(actionName, inputState)
			if inputState == Enum.UserInputState.Begin then
				for _, cb in toggleLaunchCallbacks do cb() end
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.Unknown)
		ContextActionService:SetTitle("Windbound_MobileLaunch", "Glider")
		ContextActionService:SetPosition("Windbound_MobileLaunch", UDim2.new(1, -90, 1, -180))
		
		ContextActionService:BindAction("Windbound_MobileDash", function(actionName, inputState)
			if inputState == Enum.UserInputState.Begin then
				for _, cb in dashCallbacks do cb() end
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.Unknown)
		ContextActionService:SetTitle("Windbound_MobileDash", "Dash")
		ContextActionService:SetPosition("Windbound_MobileDash", UDim2.new(1, -90, 1, -100))
		
		ContextActionService:BindAction("Windbound_MobileCapture", function(actionName, inputState)
			if inputState == Enum.UserInputState.Begin then
				for _, cb in captureCallbacks do cb() end
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.Unknown)
		ContextActionService:SetTitle("Windbound_MobileCapture", "Catch")
		ContextActionService:SetPosition("Windbound_MobileCapture", UDim2.new(1, -170, 1, -100))
	end
end

function InputManager.getSteering(): (number, number)
	local yaw = 0
	local pitch = 0
	
	-- Keyboard (WASD & Arrows)
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		yaw -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		yaw += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		pitch -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		pitch += 1
	end
	
	-- Gamepad Left Thumbstick
	local gamepads = UserInputService:GetConnectedGamepads()
	if #gamepads > 0 then
		local state = UserInputService:GetGamepadState(gamepads[1])
		for _, s in state do
			if s.KeyCode == Enum.KeyCode.Thumbstick1 then
				local pos = s.Position
				if math.abs(pos.X) > 0.15 then
					yaw = pos.X
				end
				if math.abs(pos.Y) > 0.15 then
					pitch = -pos.Y
				end
			end
		end
	end
	
	return math.clamp(yaw, -1, 1), math.clamp(pitch, -1, 1)
end

function InputManager.onDash(callback: () -> ())
	table.insert(dashCallbacks, callback)
end

function InputManager.onSpaceAction(callback: () -> ())
	table.insert(spaceCallbacks, callback)
end

function InputManager.onToggleLaunch(callback: () -> ())
	table.insert(toggleLaunchCallbacks, callback)
end

function InputManager.onCapture(callback: () -> ())
	table.insert(captureCallbacks, callback)
end

return InputManager
