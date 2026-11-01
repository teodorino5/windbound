--!strict
local RunService = game:GetService("RunService")
local remotesFolder = script.Parent:WaitForChild("Remotes")

local NetworkService = {}

local Remotes = {
	KiteAction = remotesFolder:WaitForChild("KiteAction") :: RemoteEvent,
	KiteState = remotesFolder:WaitForChild("KiteState") :: RemoteEvent,
	CaptureEvent = remotesFolder:WaitForChild("CaptureEvent") :: RemoteEvent,
}

NetworkService.Remotes = Remotes

function NetworkService.onKiteAction(callback: (player: Player, action: string, data: any) -> ())
	assert(RunService:IsServer(), "onKiteAction can only be registered on the server")
	return Remotes.KiteAction.OnServerEvent:Connect(callback)
end

function NetworkService.sendKiteAction(action: string, data: any)
	assert(RunService:IsClient(), "sendKiteAction can only be called on the client")
	Remotes.KiteAction:FireServer(action, data)
end

function NetworkService.onCaptureEvent(callback: (player: Player, eventType: string, data: any) -> ())
	assert(RunService:IsServer(), "onCaptureEvent can only be registered on the server")
	return Remotes.CaptureEvent.OnServerEvent:Connect(callback)
end

function NetworkService.sendCaptureEvent(eventType: string, data: any)
	assert(RunService:IsClient(), "sendCaptureEvent can only be called on the client")
	Remotes.CaptureEvent:FireServer(eventType, data)
end

return table.freeze(NetworkService)
