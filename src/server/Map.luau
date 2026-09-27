-- Map generation module for Steal a Kaiju.
-- Procedurally constructs the map: ground, central conveyor, 8 bases, central lobby, perimeter walls, and decor.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type BaseInfo = {
	Index: number,
	Model: Model,
	Pads: { BasePart },
	CollectPlate: BasePart,
	LockButton: BasePart,
	Barrier: BasePart,
	Zone: BasePart,
	Sign: BasePart,
	Spawn: CFrame,
}

export type BeltInfo = {
	Start: Vector3,
	Finish: Vector3,
	Part: BasePart,
}

local Map = {
	Bases = {} :: { BaseInfo },
	Belt = (nil :: any) :: BeltInfo,
	Lobby = (nil :: any) :: CFrame,
}

-- Base theme colors for 8 bases
local BASE_COLORS: { Color3 } = {
	Color3.fromRGB(0, 162, 255), -- Base 1: Electric Blue
	Color3.fromRGB(255, 130, 0), -- Base 2: Vivid Orange
	Color3.fromRGB(46, 204, 113), -- Base 3: Emerald Green
	Color3.fromRGB(160, 64, 240), -- Base 4: Royal Purple
	Color3.fromRGB(235, 50, 50), -- Base 5: Crimson Red
	Color3.fromRGB(245, 200, 25), -- Base 6: Sunny Gold
	Color3.fromRGB(240, 60, 150), -- Base 7: Hot Magenta
	Color3.fromRGB(0, 215, 215), -- Base 8: Radiant Cyan
}

-- Geometry constants
local GROUND_WIDTH = 420
local GROUND_DEPTH = 280
local BELT_WIDTH = 10
local BELT_HEIGHT = 1.2
local BELT_Y = 1.4 -- top surface at Y = 2.0
local BASE_WIDTH = 48
local BASE_DEPTH = 50
local BASE_WALL_HEIGHT = 14

-- Helper to create and configure a BasePart
local function createPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		(part :: any)[key] = value
	end

	return part
end

-- Helper to create a WedgePart
local function createWedge(props: { [string]: any }): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		(wedge :: any)[key] = value
	end

	return wedge
end

-- Builds ground terrain and central walkway streets
local function buildGround(parent: Instance)
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "Ground"
	groundFolder.Parent = parent

	-- Main grass surface
	createPart({
		Name = "MainTerrain",
		Size = Vector3.new(GROUND_WIDTH, 4, GROUND_DEPTH),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(65, 145, 60),
		Material = Enum.Material.Grass,
		Parent = groundFolder,
	})

	-- North walkway (between belt and North bases)
	createPart({
		Name = "NorthWalkway",
		Size = Vector3.new(Config.BeltLength + 40, 0.4, 23),
		Position = Vector3.new(0, 0.2, 16.5),
		Color = Color3.fromRGB(150, 155, 162),
		Material = Enum.Material.Concrete,
		Parent = groundFolder,
	})

	-- South walkway (between belt and South bases)
	createPart({
		Name = "SouthWalkway",
		Size = Vector3.new(Config.BeltLength + 40, 0.4, 23),
		Position = Vector3.new(0, 0.2, -16.5),
		Color = Color3.fromRGB(150, 155, 162),
		Material = Enum.Material.Concrete,
		Parent = groundFolder,
	})

	-- Central Plaza Hub connecting North and South around the lobby
	createPart({
		Name = "CenterPlaza",
		Size = Vector3.new(44, 0.45, 60),
		Position = Vector3.new(0, 0.22, 0),
		Color = Color3.fromRGB(135, 140, 148),
		Material = Enum.Material.Concrete,
		Parent = groundFolder,
	})

	-- Walkway border curbs (dark trims along the street edges)
	local curbZOffsets = { 5.2, 27.8, -5.2, -27.8 }
	for i, z in curbZOffsets do
		createPart({
			Name = "WalkwayCurb_" .. i,
			Size = Vector3.new(Config.BeltLength + 40, 0.6, 0.8),
			Position = Vector3.new(0, 0.3, z),
			Color = Color3.fromRGB(80, 85, 92),
			Material = Enum.Material.SmoothPlastic,
			Parent = groundFolder,
		})
	end
end

-- Builds the central conveyor belt along the X axis
local function buildBelt(parent: Instance): BeltInfo
	local beltFolder = Instance.new("Folder")
	beltFolder.Name = "Belt"
	beltFolder.Parent = parent

	local beltLength = Config.BeltLength

	-- Substructure bed under the belt
	createPart({
		Name = "BeltBed",
		Size = Vector3.new(beltLength, 0.8, BELT_WIDTH + 1.6),
		Position = Vector3.new(0, 0.4, 0),
		Color = Color3.fromRGB(48, 50, 56),
		Material = Enum.Material.DiamondPlate,
		Parent = beltFolder,
	})

	-- Main moving belt surface
	local mainBeltPart = createPart({
		Name = "BeltMain",
		Size = Vector3.new(beltLength, BELT_HEIGHT, BELT_WIDTH),
		Position = Vector3.new(0, BELT_Y, 0),
		Color = Color3.fromRGB(36, 38, 42),
		Material = Enum.Material.SmoothPlastic,
		Parent = beltFolder,
	})

	-- Side rails (borders/guards) along the full length of the conveyor
	local northRail = createPart({
		Name = "NorthRail",
		Size = Vector3.new(beltLength, 1.8, 0.8),
		Position = Vector3.new(0, BELT_Y + 0.9, (BELT_WIDTH / 2) + 0.4),
		Color = Color3.fromRGB(60, 64, 72),
		Material = Enum.Material.SmoothPlastic,
		Parent = beltFolder,
	})

	local southRail = createPart({
		Name = "SouthRail",
		Size = Vector3.new(beltLength, 1.8, 0.8),
		Position = Vector3.new(0, BELT_Y + 0.9, -(BELT_WIDTH / 2) - 0.4),
		Color = Color3.fromRGB(60, 64, 72),
		Material = Enum.Material.SmoothPlastic,
		Parent = beltFolder,
	})

	-- Glowing neon hazard strips atop side rails
	createPart({
		Name = "NorthRailTrim",
		Size = Vector3.new(beltLength, 0.2, 0.4),
		Position = Vector3.new(0, BELT_Y + 1.85, (BELT_WIDTH / 2) + 0.4),
		Color = Color3.fromRGB(255, 175, 20),
		Material = Enum.Material.Neon,
		Parent = northRail,
	})

	createPart({
		Name = "SouthRailTrim",
		Size = Vector3.new(beltLength, 0.2, 0.4),
		Position = Vector3.new(0, BELT_Y + 1.85, -(BELT_WIDTH / 2) - 0.4),
		Color = Color3.fromRGB(255, 175, 20),
		Material = Enum.Material.Neon,
		Parent = southRail,
	})

	-- Yellow directional hazard stripes along the belt surface
	local stripeSpacing = 12
	local halfLength = beltLength / 2
	local numStripes = math.floor(beltLength / stripeSpacing)
	for i = 1, numStripes - 1 do
		local stripeX = -halfLength + (i * stripeSpacing)
		createPart({
			Name = "BeltStripe_" .. i,
			Size = Vector3.new(1.2, 0.05, BELT_WIDTH - 2),
			Position = Vector3.new(stripeX, BELT_Y + (BELT_HEIGHT / 2) + 0.03, 0),
			Color = Color3.fromRGB(245, 200, 30),
			Material = Enum.Material.SmoothPlastic,
			Parent = beltFolder,
		})
	end

	-- Structural support stanchions under the conveyor every 25 studs
	local stanchionSpacing = 25
	local numStanchions = math.floor(beltLength / stanchionSpacing)
	for i = 1, numStanchions - 1 do
		local stanchionX = -halfLength + (i * stanchionSpacing)
		-- Avoid placing right at the center hub crossing (between -10 and +10)
		if math.abs(stanchionX) > 8 then
			createPart({
				Name = "BeltLeg_" .. i,
				Size = Vector3.new(1.8, BELT_Y, BELT_WIDTH + 1),
				Position = Vector3.new(stanchionX, BELT_Y / 2, 0),
				Color = Color3.fromRGB(50, 52, 58),
				Material = Enum.Material.Metal,
				Parent = beltFolder,
			})
		end
	end

	-- Intake Spawner Tunnel at start (X = -halfLength)
	local startX = -halfLength
	local startChute = createPart({
		Name = "IntakeChute",
		Size = Vector3.new(8, 12, BELT_WIDTH + 4),
		Position = Vector3.new(startX - 2, 6, 0),
		Color = Color3.fromRGB(40, 44, 52),
		Material = Enum.Material.DiamondPlate,
		Parent = beltFolder,
	})
	-- Glowing portal opening
	createPart({
		Name = "IntakePortal",
		Size = Vector3.new(0.5, 8, BELT_WIDTH),
		Position = Vector3.new(startX + 1.8, 6, 0),
		Color = Color3.fromRGB(0, 200, 255),
		Material = Enum.Material.Neon,
		Parent = startChute,
	})

	-- Recycler Outlet Tunnel at finish (X = +halfLength)
	local finishX = halfLength
	local finishChute = createPart({
		Name = "OutletChute",
		Size = Vector3.new(8, 12, BELT_WIDTH + 4),
		Position = Vector3.new(finishX + 2, 6, 0),
		Color = Color3.fromRGB(40, 44, 52),
		Material = Enum.Material.DiamondPlate,
		Parent = beltFolder,
	})
	-- Glowing portal opening
	createPart({
		Name = "OutletPortal",
		Size = Vector3.new(0.5, 8, BELT_WIDTH),
		Position = Vector3.new(finishX - 1.8, 6, 0),
		Color = Color3.fromRGB(255, 90, 30),
		Material = Enum.Material.Neon,
		Parent = finishChute,
	})

	local topSurfaceY = BELT_Y + (BELT_HEIGHT / 2)
	return {
		Start = Vector3.new(startX, topSurfaceY, 0),
		Finish = Vector3.new(finishX, topSurfaceY, 0),
		Part = mainBeltPart,
	}
end

-- Builds the elevated central lobby observation deck and spawn location
local function buildLobby(parent: Instance): CFrame
	local lobbyModel = Instance.new("Model")
	lobbyModel.Name = "Lobby"
	lobbyModel.Parent = parent

	local deckY = 11.0
	local deckThickness = 1.0
	local deckSize = 26

	-- Elevated observation platform floor
	local platform = createPart({
		Name = "Platform",
		Size = Vector3.new(deckSize, deckThickness, deckSize),
		Position = Vector3.new(0, deckY, 0),
		Color = Color3.fromRGB(52, 56, 64),
		Material = Enum.Material.Concrete,
		Parent = lobbyModel,
	})
	lobbyModel.PrimaryPart = platform

	-- Deck edge trim
	createPart({
		Name = "PlatformTrim",
		Size = Vector3.new(deckSize + 1, 0.4, deckSize + 1),
		Position = Vector3.new(0, deckY + 0.6, 0),
		Color = Color3.fromRGB(245, 200, 30),
		Material = Enum.Material.Neon,
		Parent = lobbyModel,
	})

	-- SpawnLocation on the center of the platform
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(12, 0.4, 12)
	spawnLocation.Position = Vector3.new(0, deckY + 0.7, 0)
	spawnLocation.Color = Color3.fromRGB(255, 215, 60)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.BottomSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = lobbyModel

	-- Four corner support pillars rising from ground Y = 0 to platform
	local pillarPositions = {
		Vector3.new(11, deckY / 2, 11),
		Vector3.new(-11, deckY / 2, 11),
		Vector3.new(11, deckY / 2, -11),
		Vector3.new(-11, deckY / 2, -11),
	}
	for i, pos in pillarPositions do
		createPart({
			Name = "Pillar_" .. i,
			Size = Vector3.new(2.4, deckY, 2.4),
			Position = pos,
			Color = Color3.fromRGB(40, 44, 50),
			Material = Enum.Material.Metal,
			Parent = lobbyModel,
		})
	end

	-- Safety railings on West and East sides of the platform
	createPart({
		Name = "WestRail",
		Size = Vector3.new(0.6, 3.5, deckSize),
		Position = Vector3.new(-deckSize / 2, deckY + 2.2, 0),
		Color = Color3.fromRGB(70, 75, 85),
		Material = Enum.Material.SmoothPlastic,
		Parent = lobbyModel,
	})
	createPart({
		Name = "EastRail",
		Size = Vector3.new(0.6, 3.5, deckSize),
		Position = Vector3.new(deckSize / 2, deckY + 2.2, 0),
		Color = Color3.fromRGB(70, 75, 85),
		Material = Enum.Material.SmoothPlastic,
		Parent = lobbyModel,
	})

	-- Partial railings on North and South leaving a 12-stud wide doorway for the ramps
	local halfSideRailingWidth = (deckSize - 12) / 2
	local northSouthXOffsets = { -(deckSize / 2) + (halfSideRailingWidth / 2), (deckSize / 2) - (halfSideRailingWidth / 2) }
	for _, xOff in northSouthXOffsets do
		createPart({
			Name = "NorthRailPartial",
			Size = Vector3.new(halfSideRailingWidth, 3.5, 0.6),
			Position = Vector3.new(xOff, deckY + 2.2, deckSize / 2),
			Color = Color3.fromRGB(70, 75, 85),
			Material = Enum.Material.SmoothPlastic,
			Parent = lobbyModel,
		})
		createPart({
			Name = "SouthRailPartial",
			Size = Vector3.new(halfSideRailingWidth, 3.5, 0.6),
			Position = Vector3.new(xOff, deckY + 2.2, -deckSize / 2),
			Color = Color3.fromRGB(70, 75, 85),
			Material = Enum.Material.SmoothPlastic,
			Parent = lobbyModel,
		})
	end

	-- Wide pedestrian ramps connecting the lobby platform down to North and South walkways
	local rampLength = 16
	local rampWidth = 10
	local rampHeight = deckY - 0.2

	-- North Ramp (slopes from Z = 13 down to Z = 29 at walkway level)
	createWedge({
		Name = "NorthRamp",
		Size = Vector3.new(rampWidth, rampHeight, rampLength),
		CFrame = CFrame.new(0, (deckY + 0.2) / 2, (deckSize / 2) + (rampLength / 2))
			* CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(130, 135, 142),
		Material = Enum.Material.Concrete,
		Parent = lobbyModel,
	})

	-- South Ramp (slopes from Z = -13 down to Z = -29 at walkway level)
	createWedge({
		Name = "SouthRamp",
		Size = Vector3.new(rampWidth, rampHeight, rampLength),
		CFrame = CFrame.new(0, (deckY + 0.2) / 2, -(deckSize / 2) - (rampLength / 2)),
		Color = Color3.fromRGB(130, 135, 142),
		Material = Enum.Material.Concrete,
		Parent = lobbyModel,
	})

	-- Canopy / Pergola overhead arches with glowing central logo
	local canopyY = deckY + 11
	createPart({
		Name = "CanopyRoof",
		Size = Vector3.new(deckSize + 2, 0.8, deckSize + 2),
		Position = Vector3.new(0, canopyY, 0),
		Color = Color3.fromRGB(44, 48, 56),
		Material = Enum.Material.Metal,
		Parent = lobbyModel,
	})

	-- Glowing central sign under canopy
	local signBoard = createPart({
		Name = "LobbySign",
		Size = Vector3.new(16, 3, 0.8),
		Position = Vector3.new(0, canopyY - 2.5, 0),
		Color = Color3.fromRGB(25, 28, 34),
		Material = Enum.Material.SmoothPlastic,
		Parent = lobbyModel,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 25
	signGui.LightInfluence = 0
	signGui.Parent = signBoard

	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "Title"
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "STEAL A KAIJU"
	signLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.Parent = signGui

	-- Spawn CFrame atop SpawnLocation
	return spawnLocation.CFrame + Vector3.new(0, 3, 0)
end

-- Builds a single base according to contract requirements
local function buildBase(
	parent: Instance,
	index: number,
	baseCenter: Vector3,
	dirZ: number,
	themeColor: Color3
): BaseInfo
	local baseModel = Instance.new("Model")
	baseModel.Name = "Base" .. index
	baseModel.Parent = parent

	local baseX = baseCenter.X
	local baseZ = baseCenter.Z
	local halfW = BASE_WIDTH / 2
	local halfD = BASE_DEPTH / 2

	local frontZ = baseZ - (dirZ * halfD)
	local backZ = baseZ + (dirZ * halfD)

	-- 1. Base floor platform
	local floor = createPart({
		Name = "Floor",
		Size = Vector3.new(BASE_WIDTH, 1.0, BASE_DEPTH),
		Position = Vector3.new(baseX, 0.5, baseZ),
		Color = Color3.fromRGB(44, 46, 52),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})
	baseModel.PrimaryPart = floor

	-- Floor perimeter accent trim in base color
	createPart({
		Name = "FloorTrim",
		Size = Vector3.new(BASE_WIDTH + 0.6, 0.25, BASE_DEPTH + 0.6),
		Position = Vector3.new(baseX, 1.05, baseZ),
		Color = themeColor,
		Material = Enum.Material.Neon,
		Parent = baseModel,
	})

	-- 2. Outer walls
	local wallHeight = BASE_WALL_HEIGHT
	local wallY = 1.0 + (wallHeight / 2)
	local wallThickness = 1.6

	-- Back wall
	createPart({
		Name = "BackWall",
		Size = Vector3.new(BASE_WIDTH, wallHeight, wallThickness),
		Position = Vector3.new(baseX, wallY, backZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	-- Left wall
	createPart({
		Name = "LeftWall",
		Size = Vector3.new(wallThickness, wallHeight, BASE_DEPTH),
		Position = Vector3.new(baseX - halfW, wallY, baseZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	-- Right wall
	createPart({
		Name = "RightWall",
		Size = Vector3.new(wallThickness, wallHeight, BASE_DEPTH),
		Position = Vector3.new(baseX + halfW, wallY, baseZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	-- Front wall with entrance opening (width 16 studs)
	local entranceWidth = 16
	local frontWallSegmentWidth = (BASE_WIDTH - entranceWidth) / 2
	local leftFrontCenterX = baseX - halfW + (frontWallSegmentWidth / 2)
	local rightFrontCenterX = baseX + halfW - (frontWallSegmentWidth / 2)

	createPart({
		Name = "FrontWallLeft",
		Size = Vector3.new(frontWallSegmentWidth, wallHeight, wallThickness),
		Position = Vector3.new(leftFrontCenterX, wallY, frontZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	createPart({
		Name = "FrontWallRight",
		Size = Vector3.new(frontWallSegmentWidth, wallHeight, wallThickness),
		Position = Vector3.new(rightFrontCenterX, wallY, frontZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	-- Arch header above entrance
	local archHeaderHeight = 3.5
	local archHeaderY = (1.0 + wallHeight) - (archHeaderHeight / 2)
	createPart({
		Name = "EntranceHeader",
		Size = Vector3.new(entranceWidth, archHeaderHeight, wallThickness),
		Position = Vector3.new(baseX, archHeaderY, frontZ),
		Color = Color3.fromRGB(38, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	-- Entrance arch neon frame
	createPart({
		Name = "EntranceTrim",
		Size = Vector3.new(entranceWidth + 0.6, 0.4, wallThickness + 0.4),
		Position = Vector3.new(baseX, (1.0 + wallHeight) - archHeaderHeight, frontZ),
		Color = themeColor,
		Material = Enum.Material.Neon,
		Parent = baseModel,
	})

	-- Top wall neon crown
	createPart({
		Name = "WallCrownTrim",
		Size = Vector3.new(BASE_WIDTH + 0.8, 0.4, BASE_DEPTH + 0.8),
		Position = Vector3.new(baseX, 1.0 + wallHeight + 0.2, baseZ),
		Color = themeColor,
		Material = Enum.Material.Neon,
		Parent = baseModel,
	})

	-- Open roof pergola beams (keeps sky visible and camera collision smooth)
	local beamSpacing = 10
	for b = 1, 4 do
		local beamZ = (baseZ - halfD + 5) + (b * beamSpacing)
		createPart({
			Name = "RoofBeam_" .. b,
			Size = Vector3.new(BASE_WIDTH, 0.8, 1.2),
			Position = Vector3.new(baseX, 1.0 + wallHeight, beamZ),
			Color = Color3.fromRGB(48, 52, 60),
			Material = Enum.Material.Metal,
			Parent = baseModel,
		})
	end

	-- 3. Barrier: transparent wall at base entrance, CanCollide = false
	local entranceOpeningHeight = wallHeight - archHeaderHeight
	local barrierY = 1.0 + (entranceOpeningHeight / 2)
	local barrierPart = createPart({
		Name = "Barrier",
		Size = Vector3.new(entranceWidth - 0.2, entranceOpeningHeight, 0.8),
		Position = Vector3.new(baseX, barrierY, frontZ),
		Color = themeColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.8,
		CanCollide = false,
		CastShadow = false,
		Parent = baseModel,
	})

	-- 4. Zone: invisible base interior volume
	local zoneHeight = 22
	local zonePart = createPart({
		Name = "Zone",
		Size = Vector3.new(BASE_WIDTH - 2, zoneHeight, BASE_DEPTH - 2),
		Position = Vector3.new(baseX, 1.0 + (zoneHeight / 2), baseZ),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = baseModel,
	})

	-- 5. Sign: mounted on exterior front header above entrance facing the street
	local signCFrame = CFrame.lookAt(
		Vector3.new(baseX, archHeaderY, frontZ - (dirZ * (wallThickness / 2 + 0.4))),
		Vector3.new(baseX, archHeaderY, frontZ - (dirZ * 10))
	)
	local signPart = createPart({
		Name = "Sign",
		Size = Vector3.new(14, 2.6, 0.6),
		CFrame = signCFrame,
		Color = Color3.fromRGB(24, 26, 32),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = baseModel,
	})

	-- SurfaceGui with TextLabel "Owner"
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SurfaceGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 25
	signGui.LightInfluence = 0
	signGui.Parent = signPart

	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "Owner"
	ownerLabel.Size = UDim2.new(1, -12, 1, -6)
	ownerLabel.Position = UDim2.new(0, 6, 0, 3)
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.Text = "Owner"
	ownerLabel.TextColor3 = themeColor
	ownerLabel.Font = Enum.Font.GothamBold
	ownerLabel.TextScaled = true
	ownerLabel.Parent = signGui

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 2
	labelStroke.Color = Color3.fromRGB(10, 10, 12)
	labelStroke.Parent = ownerLabel

	-- 6. CollectPlate: green neon collection pad inside base near front-left
	local collectPlatePos = Vector3.new(baseX - 13, 1.25, frontZ + (dirZ * 8))
	-- Outer pedestal ring
	createPart({
		Name = "CollectBase",
		Size = Vector3.new(7.2, 0.25, 7.2),
		Position = Vector3.new(collectPlatePos.X, 1.12, collectPlatePos.Z),
		Color = Color3.fromRGB(30, 34, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	local collectPlate = createPart({
		Name = "CollectPlate",
		Size = Vector3.new(6.2, 0.4, 6.2),
		Position = collectPlatePos,
		Color = Color3.fromRGB(46, 204, 113),
		Material = Enum.Material.Neon,
		CanCollide = true,
		Parent = baseModel,
	})

	-- Billboard tag above CollectPlate
	local collectBillboard = Instance.new("BillboardGui")
	collectBillboard.Name = "Tag"
	collectBillboard.Size = UDim2.new(0, 100, 0, 32)
	collectBillboard.StudsOffset = Vector3.new(0, 2.8, 0)
	collectBillboard.MaxDistance = 60
	collectBillboard.AlwaysOnTop = false
	collectBillboard.Parent = collectPlate

	local collectTag = Instance.new("TextLabel")
	collectTag.Name = "Label"
	collectTag.Size = UDim2.new(1, 0, 1, 0)
	collectTag.BackgroundTransparency = 1
	collectTag.Text = "💰 COLLECT"
	collectTag.TextColor3 = Color3.fromRGB(120, 255, 150)
	collectTag.Font = Enum.Font.GothamBold
	collectTag.TextScaled = true
	collectTag.Parent = collectBillboard

	local collectStroke = Instance.new("UIStroke")
	collectStroke.Thickness = 2
	collectStroke.Color = Color3.fromRGB(15, 50, 20)
	collectStroke.Parent = collectTag

	-- 7. LockButton: red button inside base near front-right
	local lockButtonPos = Vector3.new(baseX + 13, 1.25, frontZ + (dirZ * 8))
	createPart({
		Name = "LockBase",
		Size = Vector3.new(5.4, 0.25, 5.4),
		Position = Vector3.new(lockButtonPos.X, 1.12, lockButtonPos.Z),
		Color = Color3.fromRGB(30, 34, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = baseModel,
	})

	local lockButton = createPart({
		Name = "LockButton",
		Size = Vector3.new(4.4, 0.45, 4.4),
		Position = lockButtonPos,
		Color = Color3.fromRGB(235, 45, 45),
		Material = Enum.Material.Neon,
		CanCollide = true,
		Parent = baseModel,
	})

	-- Billboard tag above LockButton
	local lockBillboard = Instance.new("BillboardGui")
	lockBillboard.Name = "Tag"
	lockBillboard.Size = UDim2.new(0, 100, 0, 32)
	lockBillboard.StudsOffset = Vector3.new(0, 2.8, 0)
	lockBillboard.MaxDistance = 60
	lockBillboard.AlwaysOnTop = false
	lockBillboard.Parent = lockButton

	local lockTag = Instance.new("TextLabel")
	lockTag.Name = "Label"
	lockTag.Size = UDim2.new(1, 0, 1, 0)
	lockTag.BackgroundTransparency = 1
	lockTag.Text = "🔒 LOCK"
	lockTag.TextColor3 = Color3.fromRGB(255, 120, 120)
	lockTag.Font = Enum.Font.GothamBold
	lockTag.TextScaled = true
	lockTag.Parent = lockBillboard

	local lockStroke = Instance.new("UIStroke")
	lockStroke.Thickness = 2
	lockStroke.Color = Color3.fromRGB(50, 15, 15)
	lockStroke.Parent = lockTag

	-- 8. Spawn: inside base between CollectPlate and LockButton facing the pads
	local spawnPos = Vector3.new(baseX, 3.5, frontZ + (dirZ * 7.5))
	local spawnLookTarget = Vector3.new(baseX, 3.5, frontZ + (dirZ * 20))
	local baseSpawnCFrame = CFrame.lookAt(spawnPos, spawnLookTarget)

	-- Floor welcome mat marker under spawn
	createPart({
		Name = "SpawnMat",
		Size = Vector3.new(5.0, 0.1, 5.0),
		Position = Vector3.new(baseX, 1.05, frontZ + (dirZ * 7.5)),
		Color = themeColor,
		Material = Enum.Material.Neon,
		Parent = baseModel,
	})

	-- 9. Pads: Config.MaxSlots (12) arranged in a neat 3x4 grid
	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "Pads"
	padsFolder.Parent = baseModel

	local padsList: { BasePart } = {}
	local maxSlots = Config.MaxSlots or 12

	local colOffsets = { -13, 0, 13 }
	local rowDepths = { 16.5, 25.0, 33.5, 42.0 }
	local padSize = Vector3.new(7.6, 0.4, 7.6)

	for slotIndex = 1, maxSlots do
		local col = ((slotIndex - 1) % 3) + 1
		local row = math.floor((slotIndex - 1) / 3) + 1

		local padX = baseX + colOffsets[col]
		local padZ = frontZ + (dirZ * rowDepths[row])
		local padY = 1.0 + (padSize.Y / 2)

		-- Outer pad rim
		createPart({
			Name = "PadRim_" .. slotIndex,
			Size = Vector3.new(padSize.X + 0.6, 0.2, padSize.Z + 0.6),
			Position = Vector3.new(padX, 1.1, padZ),
			Color = Color3.fromRGB(34, 38, 44),
			Material = Enum.Material.SmoothPlastic,
			Parent = padsFolder,
		})

		-- Main pad part
		local padPart = createPart({
			Name = "Pad_" .. slotIndex,
			Size = padSize,
			Position = Vector3.new(padX, padY, padZ),
			Color = Color3.fromRGB(54, 58, 66),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = true,
			Parent = padsFolder,
		})

		-- SurfaceGui on top showing slot number
		local padGui = Instance.new("SurfaceGui")
		padGui.Name = "PadGui"
		padGui.Face = Enum.NormalId.Top
		padGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		padGui.PixelsPerStud = 20
		padGui.LightInfluence = 0
		padGui.Parent = padPart

		local padNumberLabel = Instance.new("TextLabel")
		padNumberLabel.Name = "SlotNumber"
		padNumberLabel.Size = UDim2.new(1, 0, 1, 0)
		padNumberLabel.BackgroundTransparency = 1
		padNumberLabel.Text = "#" .. slotIndex
		padNumberLabel.TextColor3 = themeColor
		padNumberLabel.Font = Enum.Font.FredokaOne
		padNumberLabel.TextScaled = true
		padNumberLabel.Parent = padGui

		padsList[slotIndex] = padPart
	end

	return {
		Index = index,
		Model = baseModel,
		Pads = padsList,
		CollectPlate = collectPlate,
		LockButton = lockButton,
		Barrier = barrierPart,
		Zone = zonePart,
		Sign = signPart,
		Spawn = baseSpawnCFrame,
	}
end

-- Procedural low-poly tree builder
local function createTree(parent: Instance, position: Vector3, scale: number)
	local treeModel = Instance.new("Model")
	treeModel.Name = "Tree"
	treeModel.Parent = parent

	local trunkHeight = 9 * scale
	local trunkRadius = 1.4 * scale

	-- Trunk
	createPart({
		Name = "Trunk",
		Size = Vector3.new(trunkRadius, trunkHeight, trunkRadius),
		Position = position + Vector3.new(0, trunkHeight / 2, 0),
		Color = Color3.fromRGB(105, 72, 42),
		Material = Enum.Material.Wood,
		Parent = treeModel,
	})

	-- Lower foliage block
	local lowerFoliageSize = 8 * scale
	createPart({
		Name = "Foliage1",
		Size = Vector3.new(lowerFoliageSize, 4 * scale, lowerFoliageSize),
		Position = position + Vector3.new(0, trunkHeight + (1.8 * scale), 0),
		Color = Color3.fromRGB(46, 140, 52),
		Material = Enum.Material.Grass,
		Parent = treeModel,
	})

	-- Upper foliage block
	local upperFoliageSize = 5.5 * scale
	createPart({
		Name = "Foliage2",
		Size = Vector3.new(upperFoliageSize, 3.5 * scale, upperFoliageSize),
		Position = position + Vector3.new(0, trunkHeight + (5 * scale), 0),
		Color = Color3.fromRGB(56, 160, 62),
		Material = Enum.Material.Grass,
		Parent = treeModel,
	})
end

-- Procedural low-poly rock builder
local function createRock(parent: Instance, position: Vector3, scale: number)
	local rockModel = Instance.new("Model")
	rockModel.Name = "Rock"
	rockModel.Parent = parent

	-- Main boulder
	createPart({
		Name = "MainBoulder",
		Size = Vector3.new(6 * scale, 4.5 * scale, 5.5 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 2 * scale, 0))
			* CFrame.Angles(math.rad(12), math.rad(35), math.rad(-8)),
		Color = Color3.fromRGB(115, 120, 128),
		Material = Enum.Material.Slate,
		Parent = rockModel,
	})

	-- Secondary accent stone
	createPart({
		Name = "AccentStone",
		Size = Vector3.new(3.8 * scale, 2.8 * scale, 3.8 * scale),
		CFrame = CFrame.new(position + Vector3.new(2.5 * scale, 1.2 * scale, 1.5 * scale))
			* CFrame.Angles(math.rad(-15), math.rad(70), math.rad(20)),
		Color = Color3.fromRGB(95, 100, 108),
		Material = Enum.Material.Slate,
		Parent = rockModel,
	})
end

-- Builds environment decor: trees and rocks around the perimeter
local function buildDecor(parent: Instance)
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = parent

	-- Trees along North boundary (behind North bases)
	local treeNorthX = { -150, -115, -75, -20, 20, 75, 115, 150 }
	for _, x in treeNorthX do
		createTree(decorFolder, Vector3.new(x, 0, 95), 1.1)
		createTree(decorFolder, Vector3.new(x + 12, 0, 110), 1.3)
	end

	-- Trees along South boundary (behind South bases)
	for _, x in treeNorthX do
		createTree(decorFolder, Vector3.new(x, 0, -95), 1.1)
		createTree(decorFolder, Vector3.new(x + 12, 0, -110), 1.3)
	end

	-- Trees along West and East edges (around conveyor terminals)
	local edgeZ = { -60, -35, -15, 15, 35, 60 }
	for _, z in edgeZ do
		createTree(decorFolder, Vector3.new(-180, 0, z), 1.2)
		createTree(decorFolder, Vector3.new(180, 0, z), 1.2)
	end

	-- Rock clusters in corners and near perimeter
	local rockPositions = {
		Vector3.new(-165, 0, 85),
		Vector3.new(165, 0, 85),
		Vector3.new(-165, 0, -85),
		Vector3.new(165, 0, -85),
		Vector3.new(-185, 0, 0),
		Vector3.new(185, 0, 0),
		Vector3.new(-75, 0, 32),
		Vector3.new(75, 0, 32),
		Vector3.new(-75, 0, -32),
		Vector3.new(75, 0, -32),
	}
	for _, pos in rockPositions do
		createRock(decorFolder, pos, 1.2)
	end

	-- Street lamp posts along the walkway curbs
	local lampX = { -125, -85, -45, 45, 85, 125 }
	for _, x in lampX do
		-- North walkway lamp
		createPart({
			Name = "LampPost_N",
			Size = Vector3.new(0.8, 10, 0.8),
			Position = Vector3.new(x, 5, 27.5),
			Color = Color3.fromRGB(45, 48, 54),
			Material = Enum.Material.Metal,
			Parent = decorFolder,
		})
		createPart({
			Name = "LampBulb_N",
			Size = Vector3.new(1.6, 1.2, 1.6),
			Position = Vector3.new(x, 10.2, 27.5),
			Color = Color3.fromRGB(255, 240, 180),
			Material = Enum.Material.Neon,
			Parent = decorFolder,
		})

		-- South walkway lamp
		createPart({
			Name = "LampPost_S",
			Size = Vector3.new(0.8, 10, 0.8),
			Position = Vector3.new(x, 5, -27.5),
			Color = Color3.fromRGB(45, 48, 54),
			Material = Enum.Material.Metal,
			Parent = decorFolder,
		})
		createPart({
			Name = "LampBulb_S",
			Size = Vector3.new(1.6, 1.2, 1.6),
			Position = Vector3.new(x, 10.2, -27.5),
			Color = Color3.fromRGB(255, 240, 180),
			Material = Enum.Material.Neon,
			Parent = decorFolder,
		})
	end
end

-- Builds tall invisible perimeter boundary walls so players cannot leave the arena
local function buildPerimeterWalls(parent: Instance)
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "PerimeterWalls"
	wallFolder.Parent = parent

	local wallHeight = 50
	local halfW = (GROUND_WIDTH / 2) - 4
	local halfD = (GROUND_DEPTH / 2) - 4

	local walls = {
		{ Name = "NorthWall", Size = Vector3.new(GROUND_WIDTH, wallHeight, 2), Pos = Vector3.new(0, wallHeight / 2, halfD) },
		{ Name = "SouthWall", Size = Vector3.new(GROUND_WIDTH, wallHeight, 2), Pos = Vector3.new(0, wallHeight / 2, -halfD) },
		{ Name = "WestWall", Size = Vector3.new(2, wallHeight, GROUND_DEPTH), Pos = Vector3.new(-halfW, wallHeight / 2, 0) },
		{ Name = "EastWall", Size = Vector3.new(2, wallHeight, GROUND_DEPTH), Pos = Vector3.new(halfW, wallHeight / 2, 0) },
	}

	for _, w in walls do
		createPart({
			Name = w.Name,
			Size = w.Size,
			Position = w.Pos,
			Transparency = 1,
			CanCollide = true,
			CastShadow = false,
			Parent = wallFolder,
		})
	end
end

-- Public API: builds the map procedurally in Workspace.Map and populates Map.Bases, Map.Belt, Map.Lobby
function Map.build()
	-- Clean up existing Map if present
	local existingMap = Workspace:FindFirstChild("Map")
	if existingMap then
		existingMap:Destroy()
	end

	table.clear(Map.Bases)

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	-- 1. Build ground and walkways
	buildGround(mapFolder)

	-- 2. Build central conveyor belt
	Map.Belt = buildBelt(mapFolder)

	-- 3. Build central lobby observation hub
	Map.Lobby = buildLobby(mapFolder)

	-- 4. Build 8 bases (4 North, 4 South)
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = mapFolder

	-- Base center X coordinates: 2 left of center plaza, 2 right of center plaza
	local basePositionsX = { -102, -44, 44, 102 }

	-- North bases (1..4): Z = 53, entrance facing South (dirZ = 1)
	for i = 1, 4 do
		local center = Vector3.new(basePositionsX[i], 0, 53)
		local baseInfo = buildBase(basesFolder, i, center, 1, BASE_COLORS[i])
		table.insert(Map.Bases, baseInfo)
	end

	-- South bases (5..8): Z = -53, entrance facing North (dirZ = -1)
	for i = 1, 4 do
		local baseIndex = i + 4
		local center = Vector3.new(basePositionsX[i], 0, -53)
		local baseInfo = buildBase(basesFolder, baseIndex, center, -1, BASE_COLORS[baseIndex])
		table.insert(Map.Bases, baseInfo)
	end

	-- 5. Build environment decor (trees, rocks, lamps)
	buildDecor(mapFolder)

	-- 6. Build invisible boundary walls
	buildPerimeterWalls(mapFolder)

	-- Safety pass: guarantee every single BasePart is Anchored
	for _, descendant in mapFolder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	return Map
end

return Map
