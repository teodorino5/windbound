--!strict
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WorldGeneratorService = {}

export type IslandSpec = {
	Name: string,
	Region: string,
	Center: Vector3,
	RadiusX: number,
	RadiusZ: number,
	Height: number,
	KeelDepth: number,
	TopMaterial: Enum.Material,
	TopColor: Color3,
	CliffMaterial: Enum.Material,
	CliffColor: Color3,
	KeelMaterial: Enum.Material,
	KeelColor: Color3,
	HasOverlook: boolean,
	OverlookHeading: number?,
	TierCount: number?,
}

-- Root world folder
local WORLD_CONTAINER_NAME = "World_WindboundArchipelago"

function WorldGeneratorService.getOrCreateWorldFolder(): Folder
	local existing = Workspace:FindFirstChild(WORLD_CONTAINER_NAME) :: Folder?
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = WORLD_CONTAINER_NAME
		existing.Parent = Workspace
	end
	return existing
end

function WorldGeneratorService.getOrCreateRegionFolder(regionName: string): Folder
	local world = WorldGeneratorService.getOrCreateWorldFolder()
	local regName = "Region_" .. regionName
	local existing = world:FindFirstChild(regName) :: Folder?
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = regName
		existing.Parent = world
	end
	return existing
end

function WorldGeneratorService.clearRegion(regionName: string)
	local world = Workspace:FindFirstChild(WORLD_CONTAINER_NAME)
	if world then
		local reg = world:FindFirstChild("Region_" .. regionName)
		if reg then
			reg:Destroy()
			print("[WorldGeneratorService] Cleared region: " .. regionName)
		end
	end
end

function WorldGeneratorService.clearAll()
	local world = Workspace:FindFirstChild(WORLD_CONTAINER_NAME)
	if world then
		world:Destroy()
		print("[WorldGeneratorService] Cleared entire archipelago world container.")
	end
end

-- ============================================================================
-- PROCEDURAL ISLAND SCULPTOR
-- Creates believable floating islands with top plateaus, sheer cliffs, 
-- and deep inverted hanging keels.
-- ============================================================================
function WorldGeneratorService.buildIsland(spec: IslandSpec, parentFolder: Instance): Model
	local islandModel = Instance.new("Model")
	islandModel.Name = spec.Name
	
	local center = spec.Center
	local rx = spec.RadiusX
	local rz = spec.RadiusZ
	local h = spec.Height
	local keelDepth = spec.KeelDepth
	local tiers = spec.TierCount or 2
	
	-- 1. Island Root & Anchor Point
	local root = Instance.new("Part")
	root.Name = "IslandRoot"
	root.Size = Vector3.new(4, 4, 4)
	root.CFrame = CFrame.new(center)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Anchored = true
	root.Parent = islandModel
	islandModel.PrimaryPart = root
	
	-- 2. Upper Playable Crown (Organic Overlapping Plateau Blocks)
	local numSegments = 8
	for i = 1, numSegments do
		local angle = ((i - 1) / numSegments) * math.pi * 2
		local segDist = 0.35 + (math.sin(angle * 3) * 0.12)
		local offsetX = math.cos(angle) * (rx * segDist)
		local offsetZ = math.sin(angle) * (rz * segDist)
		
		local segW = rx * (0.65 + math.cos(angle * 2) * 0.15)
		local segD = rz * (0.65 + math.sin(angle * 2) * 0.15)
		local segH = h * 0.45
		
		local plateau = Instance.new("Part")
		plateau.Name = string.format("CrownPlateau_%d", i)
		plateau.Size = Vector3.new(segW, segH, segD)
		local yOffset = (i % 2 == 0) and 2 or -2
		plateau.CFrame = CFrame.new(center + Vector3.new(offsetX, yOffset, offsetZ))
			* CFrame.Angles(0, angle + math.rad(15), 0)
		plateau.Material = spec.TopMaterial
		plateau.Color = spec.TopColor
		plateau.TopSurface = Enum.SurfaceType.Smooth
		plateau.BottomSurface = Enum.SurfaceType.Smooth
		plateau.Anchored = true
		plateau.CanCollide = true
		plateau.CastShadow = true
		plateau.Parent = islandModel
	end
	
	-- Main central core plateau
	local coreCrown = Instance.new("Part")
	coreCrown.Name = "MainCrownSurface"
	coreCrown.Size = Vector3.new(rx * 1.35, h * 0.5, rz * 1.35)
	coreCrown.CFrame = CFrame.new(center + Vector3.new(0, h * 0.15, 0))
	coreCrown.Material = spec.TopMaterial
	coreCrown.Color = spec.TopColor
	coreCrown.TopSurface = Enum.SurfaceType.Smooth
	coreCrown.BottomSurface = Enum.SurfaceType.Smooth
	coreCrown.Anchored = true
	coreCrown.CanCollide = true
	coreCrown.CastShadow = true
	coreCrown.Parent = islandModel
	
	-- 3. Cliff Strata & Side Silhouettes
	local numCliffs = 10
	for i = 1, numCliffs do
		local angle = ((i - 0.5) / numCliffs) * math.pi * 2
		local cliffRadiusX = rx * 0.88
		local cliffRadiusZ = rz * 0.88
		local cx = math.cos(angle) * cliffRadiusX
		local cz = math.sin(angle) * cliffRadiusZ
		
		local cliffW = (rx / numCliffs) * 2.8
		local cliffH = h * 0.85
		local cliffD = (rz / numCliffs) * 2.8
		
		-- Angled Cliff Wedge / Block
		local cliff = Instance.new("WedgePart")
		cliff.Name = string.format("CliffStrata_%d", i)
		cliff.Size = Vector3.new(cliffW, cliffH, cliffD)
		-- Point wedge downward/outward to form cliff overhang
		local lookOut = Vector3.new(math.cos(angle), 0, math.sin(angle))
		cliff.CFrame = CFrame.lookAt(
			center + Vector3.new(cx, -h * 0.25, cz),
			center + Vector3.new(cx, -h * 0.25, cz) + lookOut
		) * CFrame.Angles(0, math.rad(180), math.rad(15))
		
		cliff.Material = spec.CliffMaterial
		cliff.Color = spec.CliffColor
		cliff.Anchored = true
		cliff.CanCollide = true
		cliff.CastShadow = true
		cliff.Parent = islandModel
	end
	
	-- 4. Inverted Hanging Underside Keel (Deep Tapering Stalactite Roots)
	local keelSteps = 4
	for k = 1, keelSteps do
		local progress = k / keelSteps
		local kw = rx * (1.0 - (progress * 0.82))
		local kd = rz * (1.0 - (progress * 0.82))
		local kh = keelDepth / keelSteps
		local ky = center.Y - (h * 0.35) - ((k - 0.5) * kh)
		
		local keelBlock = Instance.new("Part")
		keelBlock.Name = string.format("KeelStep_%d", k)
		keelBlock.Size = Vector3.new(kw, kh + 2, kd)
		keelBlock.CFrame = CFrame.new(center.X, ky, center.Z) * CFrame.Angles(0, math.rad(k * 25), 0)
		keelBlock.Material = spec.KeelMaterial
		keelBlock.Color = spec.KeelColor
		keelBlock.Anchored = true
		keelBlock.CanCollide = true
		keelBlock.CastShadow = true
		keelBlock.Parent = islandModel
	end
	
	-- Sharp Stalactite Keel Tip at bottom
	local tipWedge = Instance.new("WedgePart")
	tipWedge.Name = "KeelTip"
	tipWedge.Size = Vector3.new(rx * 0.25, keelDepth * 0.35, rz * 0.25)
	tipWedge.CFrame = CFrame.new(center.X, center.Y - (h * 0.35) - keelDepth, center.Z)
		* CFrame.Angles(math.rad(180), 0, 0)
	tipWedge.Material = spec.KeelMaterial
	tipWedge.Color = spec.KeelColor
	tipWedge.Anchored = true
	tipWedge.CanCollide = true
	tipWedge.CastShadow = true
	tipWedge.Parent = islandModel
	
	-- 5. Cantilevered Launch Overlook (Specifically for Kites & Hang-Gliders)
	if spec.HasOverlook then
		local hHeading = spec.OverlookHeading or 0
		local ovDir = Vector3.new(math.cos(hHeading), 0, math.sin(hHeading))
		local ovPos = center + (ovDir * (math.max(rx, rz) * 0.95)) + Vector3.new(0, h * 0.2, 0)
		
		local overlook = Instance.new("Part")
		overlook.Name = "LaunchLedge_Overlook"
		overlook.Size = Vector3.new(32, 6, 52)
		overlook.CFrame = CFrame.lookAt(ovPos, ovPos + ovDir)
		overlook.Material = Enum.Material.SmoothPlastic
		overlook.Color = Color3.fromRGB(180, 195, 175)
		overlook.Anchored = true
		overlook.CanCollide = true
		overlook.CastShadow = true
		overlook.Parent = islandModel
		
		-- Overlook Runway Marker
		local runway = Instance.new("Part")
		runway.Name = "RunwayPlank"
		runway.Size = Vector3.new(16, 1.2, 44)
		runway.CFrame = overlook.CFrame * CFrame.new(0, 3.2, 0)
		runway.Material = Enum.Material.WoodPlanks
		runway.Color = Color3.fromRGB(165, 120, 75)
		runway.Anchored = true
		runway.CanCollide = true
		runway.CastShadow = true
		runway.Parent = islandModel
		
		CollectionService:AddTag(overlook, "LaunchLedge")
	end
	
	CollectionService:AddTag(islandModel, "FloatingIsland")
	islandModel.Parent = parentFolder
	return islandModel
end

-- ============================================================================
-- SKY BRIDGE BUILDER
-- Connects adjacent islands with suspended natural stone causeways
-- ============================================================================
function WorldGeneratorService.buildSkyBridge(
	startPos: Vector3,
	endPos: Vector3,
	width: number,
	thickness: number,
	name: string,
	mat: Enum.Material,
	color: Color3,
	parentFolder: Instance
): Model
	local bridgeModel = Instance.new("Model")
	bridgeModel.Name = name
	
	local delta = (endPos - startPos)
	local dist = delta.Magnitude
	local segments = math.clamp(math.floor(dist / 40), 3, 12)
	
	for s = 1, segments do
		local frac1 = (s - 1) / segments
		local frac2 = s / segments
		local midFrac = (frac1 + frac2) * 0.5
		
		-- Catenary / Arch sag
		local sag = math.sin(midFrac * math.pi) * -12.0
		local p1 = startPos:Lerp(endPos, frac1) + Vector3.new(0, math.sin(frac1 * math.pi) * -12.0, 0)
		local p2 = startPos:Lerp(endPos, frac2) + Vector3.new(0, math.sin(frac2 * math.pi) * -12.0, 0)
		
		local segDist = (p2 - p1).Magnitude
		local segCenter = (p1 + p2) * 0.5
		
		local archPart = Instance.new("Part")
		archPart.Name = string.format("BridgeSpan_%d", s)
		archPart.Size = Vector3.new(width, thickness, segDist + 1)
		archPart.CFrame = CFrame.lookAt(segCenter, p2)
		archPart.Material = mat
		archPart.Color = color
		archPart.Anchored = true
		archPart.CanCollide = true
		archPart.CastShadow = true
		archPart.Parent = bridgeModel
	end
	
	CollectionService:AddTag(bridgeModel, "SkyBridge")
	bridgeModel.Parent = parentFolder
	return bridgeModel
end

return WorldGeneratorService
