--!strict
-- Assembly of modular Kaiju 3D models and information tags.
-- Builds 5 distinct shapes: Dino, Blob, Crab, Bird, Tall.
-- Handles scaling, mutations (Radioactive, Golden, Rainbow, Galaxy), and welds.

local Kaiju = require(script.Parent.Kaiju)
local Format = require(script.Parent.Format)

type KaijuDef = Kaiju.KaijuDef

local KaijuModel = {}

-- Normalize mutation string to standard capitalized English name
local function normalizeMutation(mut: string?): string?
	if not mut or mut == "" then
		return nil
	end
	local lower = string.lower(mut)
	if lower == "radioactive" or lower == "радиоактивный" then
		return "Radioactive"
	elseif lower == "golden" or lower == "золотой" then
		return "Golden"
	elseif lower == "rainbow" or lower == "радужный" then
		return "Rainbow"
	elseif lower == "galaxy" or lower == "галактический" then
		return "Galaxy"
	end
	return mut
end

-- Resolve color and material for a specific part given the mutation
local function resolvePartStyle(
	baseColor: Color3,
	isAccent: boolean,
	mutation: string?,
	partIndex: number,
	defaultMaterial: Enum.Material?
): (Color3, Enum.Material)
	if not mutation then
		return baseColor, defaultMaterial or Enum.Material.SmoothPlastic
	end

	if mutation == "Radioactive" then
		if isAccent then
			return Color3.fromRGB(45, 255, 65), Enum.Material.Neon
		else
			return Color3.fromRGB(70, 210, 50), defaultMaterial or Enum.Material.SmoothPlastic
		end
	elseif mutation == "Golden" then
		if isAccent then
			return Color3.fromRGB(255, 175, 10), Enum.Material.Metal
		else
			return Color3.fromRGB(255, 215, 25), Enum.Material.Metal
		end
	elseif mutation == "Rainbow" then
		local hue = ((partIndex * 0.13) + (if isAccent then 0.5 else 0)) % 1
		local color = Color3.fromHSV(hue, 0.85, 1)
		local mat = if isAccent then Enum.Material.Neon else (defaultMaterial or Enum.Material.SmoothPlastic)
		return color, mat
	elseif mutation == "Galaxy" then
		if isAccent then
			local neonColor = if partIndex % 2 == 0
				then Color3.fromRGB(0, 240, 255)
				else Color3.fromRGB(215, 55, 255)
			return neonColor, Enum.Material.Neon
		else
			return Color3.fromRGB(25, 14, 42), defaultMaterial or Enum.Material.SmoothPlastic
		end
	end

	return baseColor, defaultMaterial or Enum.Material.SmoothPlastic
end

-- Helper to create and weld a standard Part
local function makePart(
	model: Model,
	root: Part,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root

	return part
end

-- Helper to create and weld a WedgePart
local function makeWedge(
	model: Model,
	root: Part,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cf
	wedge.Color = color
	wedge.Material = material
	wedge.Anchored = false
	wedge.CanCollide = false
	wedge.Massless = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = wedge
	weld.Parent = root

	return wedge
end

-- Helper to create cute expressive anime/chibi eyes (sclera + pupil + specular glint)
local function makeCuteEye(
	model: any,
	root: any,
	centerPos: any,
	lookDir: any,
	eyeSize: number,
	scale: number
)
	local rot = CFrame.lookAt(centerPos, centerPos + lookDir)

	-- 1. Sclera (White eyeball)
	local sclera = Instance.new("Part")
	sclera.Name = "EyeSclera"
	sclera.Size = Vector3.new(eyeSize, eyeSize, eyeSize * 0.7) * scale
	sclera.CFrame = rot
	sclera.Shape = Enum.PartType.Ball
	sclera.Color = Color3.fromRGB(255, 255, 255)
	sclera.Material = Enum.Material.SmoothPlastic
	sclera.Anchored = false
	sclera.CanCollide = false
	sclera.Massless = true
	sclera.Parent = model

	local weld1 = Instance.new("WeldConstraint")
	weld1.Part0 = root
	weld1.Part1 = sclera
	weld1.Parent = root

	-- 2. Pupil (Dark black circle)
	local pupilOffset = rot * CFrame.new(0, 0, -eyeSize * 0.28 * scale)
	local pupil = Instance.new("Part")
	pupil.Name = "EyePupil"
	pupil.Size = Vector3.new(eyeSize * 0.6, eyeSize * 0.6, eyeSize * 0.25) * scale
	pupil.CFrame = pupilOffset
	pupil.Shape = Enum.PartType.Ball
	pupil.Color = Color3.fromRGB(22, 22, 28)
	pupil.Material = Enum.Material.SmoothPlastic
	pupil.Anchored = false
	pupil.CanCollide = false
	pupil.Massless = true
	pupil.Parent = model

	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = root
	weld2.Part1 = pupil
	weld2.Parent = root

	-- 3. Specular reflection glint (Cute shiny white dot)
	local glintOffset = pupilOffset * CFrame.new(eyeSize * 0.14 * scale, eyeSize * 0.14 * scale, -eyeSize * 0.1 * scale)
	local glint = Instance.new("Part")
	glint.Name = "EyeGlint"
	glint.Size = Vector3.new(eyeSize * 0.22, eyeSize * 0.22, eyeSize * 0.15) * scale
	glint.CFrame = glintOffset
	glint.Shape = Enum.PartType.Ball
	glint.Color = Color3.fromRGB(255, 255, 255)
	glint.Material = Enum.Material.SmoothPlastic
	glint.Anchored = false
	glint.CanCollide = false
	glint.Massless = true
	glint.Parent = model

	local weld3 = Instance.new("WeldConstraint")
	weld3.Part0 = root
	weld3.Part1 = glint
	weld3.Parent = root
end

-- =============================================================================
-- SHAPE BUILDERS (Dino, Blob, Crab, Bird, Tall)
-- All coordinates are built relative to ground Y = 0.
-- =============================================================================

-- 1. DINO SHAPE
local function buildDino(model: Model, root: Part, def: KaijuDef, scale: number, mutation: string?)
	local bodyColor = def.Body
	local accentColor = def.Accent
	local idx = 1

	local function style(c: Color3, isAcc: boolean, mat: Enum.Material?)
		idx += 1
		return resolvePartStyle(c, isAcc, mutation, idx, mat)
	end

	-- Feet (2)
	local footCol, footMat = style(bodyColor, false, nil)
	makePart(model, root, "FootL", Vector3.new(0.6, 0.5, 0.85) * scale, CFrame.new(-0.6 * scale, 0.25 * scale, 0.2 * scale), footCol, footMat, Enum.PartType.Block)
	makePart(model, root, "FootR", Vector3.new(0.6, 0.5, 0.85) * scale, CFrame.new(0.6 * scale, 0.25 * scale, 0.2 * scale), footCol, footMat, Enum.PartType.Block)

	-- Toes (Accent)
	local toeCol, toeMat = style(accentColor, true, nil)
	makePart(model, root, "ToeL1", Vector3.new(0.2, 0.25, 0.25) * scale, CFrame.new(-0.75 * scale, 0.13 * scale, 0.65 * scale), toeCol, toeMat, Enum.PartType.Block)
	makePart(model, root, "ToeL2", Vector3.new(0.2, 0.25, 0.25) * scale, CFrame.new(-0.45 * scale, 0.13 * scale, 0.65 * scale), toeCol, toeMat, Enum.PartType.Block)
	makePart(model, root, "ToeR1", Vector3.new(0.2, 0.25, 0.25) * scale, CFrame.new(0.45 * scale, 0.13 * scale, 0.65 * scale), toeCol, toeMat, Enum.PartType.Block)
	makePart(model, root, "ToeR2", Vector3.new(0.2, 0.25, 0.25) * scale, CFrame.new(0.75 * scale, 0.13 * scale, 0.65 * scale), toeCol, toeMat, Enum.PartType.Block)

	-- Legs (2)
	local legCol, legMat = style(bodyColor, false, nil)
	makePart(model, root, "LegL", Vector3.new(0.55, 0.8, 0.65) * scale, CFrame.new(-0.6 * scale, 0.85 * scale, 0), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "LegR", Vector3.new(0.55, 0.8, 0.65) * scale, CFrame.new(0.6 * scale, 0.85 * scale, 0), legCol, legMat, Enum.PartType.Block)

	-- Torso
	local torsoCol, torsoMat = style(bodyColor, false, nil)
	makePart(model, root, "Torso", Vector3.new(1.8, 1.8, 1.8) * scale, CFrame.new(0, 1.7 * scale, 0), torsoCol, torsoMat, Enum.PartType.Block)

	-- Belly patch
	local bellyCol, bellyMat = style(accentColor, true, nil)
	makePart(model, root, "Belly", Vector3.new(1.2, 1.3, 0.35) * scale, CFrame.new(0, 1.6 * scale, 0.75 * scale), bellyCol, bellyMat, Enum.PartType.Block)

	-- Arms (2 cute tiny arms)
	local armCol, armMat = style(bodyColor, false, nil)
	local armCfL = CFrame.new(-0.95 * scale, 1.7 * scale, 0.65 * scale) * CFrame.Angles(math.rad(20), 0, math.rad(-15))
	local armCfR = CFrame.new(0.95 * scale, 1.7 * scale, 0.65 * scale) * CFrame.Angles(math.rad(20), 0, math.rad(15))
	makePart(model, root, "ArmL", Vector3.new(0.3, 0.45, 0.45) * scale, armCfL, armCol, armMat, Enum.PartType.Block)
	makePart(model, root, "ArmR", Vector3.new(0.3, 0.45, 0.45) * scale, armCfR, armCol, armMat, Enum.PartType.Block)

	-- Head
	local headCol, headMat = style(bodyColor, false, nil)
	makePart(model, root, "Head", Vector3.new(1.6, 1.3, 1.6) * scale, CFrame.new(0, 2.7 * scale, 0.45 * scale), headCol, headMat, Enum.PartType.Block)

	-- Snout
	local snoutCol, snoutMat = style(bodyColor, false, nil)
	makePart(model, root, "Snout", Vector3.new(1.2, 0.75, 0.85) * scale, CFrame.new(0, 2.45 * scale, 1.45 * scale), snoutCol, snoutMat, Enum.PartType.Block)

	-- Eyes
	makeCuteEye(model, root, Vector3.new(-0.82 * scale, 2.8 * scale, 0.95 * scale), Vector3.new(-0.35, 0, 0.93), 0.44, scale)
	makeCuteEye(model, root, Vector3.new(0.82 * scale, 2.8 * scale, 0.95 * scale), Vector3.new(0.35, 0, 0.93), 0.44, scale)

	-- Tail (3 segments tapering back and up)
	local tailCol, tailMat = style(bodyColor, false, nil)
	makePart(model, root, "Tail1", Vector3.new(1.1, 1.1, 1.0) * scale, CFrame.new(0, 1.45 * scale, -1.15 * scale), tailCol, tailMat, Enum.PartType.Block)
	makePart(model, root, "Tail2", Vector3.new(0.8, 0.8, 0.9) * scale, CFrame.new(0, 1.65 * scale, -1.95 * scale), tailCol, tailMat, Enum.PartType.Block)
	makePart(model, root, "Tail3", Vector3.new(0.5, 0.5, 0.8) * scale, CFrame.new(0, 1.95 * scale, -2.65 * scale), tailCol, tailMat, Enum.PartType.Block)

	-- Dorsal Spikes (Wedges in Accent color along the spine)
	local spCol, spMat = style(accentColor, true, nil)
	local sp1Cf = CFrame.new(0, 3.48 * scale, 0.25 * scale) * CFrame.Angles(0, math.rad(180), 0)
	local sp2Cf = CFrame.new(0, 2.75 * scale, -0.4 * scale) * CFrame.Angles(0, math.rad(180), 0)
	local sp3Cf = CFrame.new(0, 2.15 * scale, -1.1 * scale) * CFrame.Angles(0, math.rad(180), 0)
	local sp4Cf = CFrame.new(0, 2.22 * scale, -1.85 * scale) * CFrame.Angles(0, math.rad(180), 0)
	makeWedge(model, root, "Spike1", Vector3.new(0.28, 0.45, 0.55) * scale, sp1Cf, spCol, spMat)
	makeWedge(model, root, "Spike2", Vector3.new(0.28, 0.55, 0.55) * scale, sp2Cf, spCol, spMat)
	makeWedge(model, root, "Spike3", Vector3.new(0.25, 0.45, 0.5) * scale, sp3Cf, spCol, spMat)
	makeWedge(model, root, "Spike4", Vector3.new(0.2, 0.35, 0.45) * scale, sp4Cf, spCol, spMat)
end

-- 2. BLOB SHAPE
local function buildBlob(model: Model, root: Part, def: KaijuDef, scale: number, mutation: string?)
	local bodyColor = def.Body
	local accentColor = def.Accent
	local idx = 1

	local function style(c: Color3, isAcc: boolean, mat: Enum.Material?)
		idx += 1
		return resolvePartStyle(c, isAcc, mutation, idx, mat)
	end

	-- Squish base skirt
	local baseCol, baseMat = style(bodyColor, false, nil)
	local skirtCf = CFrame.new(0, 0.3 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
	makePart(model, root, "Skirt", Vector3.new(0.6, 2.5, 2.5) * scale, skirtCf, baseCol, baseMat, Enum.PartType.Cylinder)

	-- Main bouncy sphere body
	local bodyCol, bodyMat = style(bodyColor, false, nil)
	makePart(model, root, "Body", Vector3.new(2.4, 2.2, 2.3) * scale, CFrame.new(0, 1.5 * scale, 0), bodyCol, bodyMat, Enum.PartType.Ball)

	-- Cheeks (Blushing pink discs)
	local blushCol, blushMat = style(accentColor, true, nil)
	local blushCfL = CFrame.new(-0.75 * scale, 1.25 * scale, 1.05 * scale) * CFrame.Angles(math.rad(90), 0, 0)
	local blushCfR = CFrame.new(0.75 * scale, 1.25 * scale, 1.05 * scale) * CFrame.Angles(math.rad(90), 0, 0)
	makePart(model, root, "BlushL", Vector3.new(0.12, 0.4, 0.4) * scale, blushCfL, blushCol, blushMat, Enum.PartType.Cylinder)
	makePart(model, root, "BlushR", Vector3.new(0.12, 0.4, 0.4) * scale, blushCfR, blushCol, blushMat, Enum.PartType.Cylinder)

	-- Cute little smile
	local smileCol, smileMat = style(Color3.fromRGB(30, 25, 35), true, nil)
	makePart(model, root, "Smile", Vector3.new(0.24, 0.12, 0.12) * scale, CFrame.new(0, 1.2 * scale, 1.12 * scale), smileCol, smileMat, Enum.PartType.Block)

	-- Eyes (Large cute anime eyes)
	makeCuteEye(model, root, Vector3.new(-0.52 * scale, 1.6 * scale, 1.08 * scale), Vector3.new(0, 0, 1), 0.54, scale)
	makeCuteEye(model, root, Vector3.new(0.52 * scale, 1.6 * scale, 1.08 * scale), Vector3.new(0, 0, 1), 0.54, scale)

	-- Flippers / Nub paws (2)
	local pawCol, pawMat = style(bodyColor, false, nil)
	makePart(model, root, "FlipperL", Vector3.new(0.45, 0.4, 0.55) * scale, CFrame.new(-1.3 * scale, 1.2 * scale, 0.15 * scale), pawCol, pawMat, Enum.PartType.Block)
	makePart(model, root, "FlipperR", Vector3.new(0.45, 0.4, 0.55) * scale, CFrame.new(1.3 * scale, 1.2 * scale, 0.15 * scale), pawCol, pawMat, Enum.PartType.Block)

	-- Top Antenna / Sprout
	local stemCol, stemMat = style(accentColor, true, nil)
	makePart(model, root, "SproutStem", Vector3.new(0.2, 0.55, 0.2) * scale, CFrame.new(0, 2.7 * scale, 0), stemCol, stemMat, Enum.PartType.Block)

	local bobbleCol, bobbleMat = style(accentColor, true, Enum.Material.Neon)
	makePart(model, root, "SproutBobble", Vector3.new(0.6, 0.6, 0.6) * scale, CFrame.new(0, 3.1 * scale, 0), bobbleCol, bobbleMat, Enum.PartType.Ball)

	-- Back tail nub
	local tailCol, tailMat = style(bodyColor, false, nil)
	makePart(model, root, "TailNub", Vector3.new(0.4, 0.4, 0.4) * scale, CFrame.new(0, 0.9 * scale, -1.2 * scale), tailCol, tailMat, Enum.PartType.Ball)
end

-- 3. CRAB SHAPE
local function buildCrab(model: Model, root: Part, def: KaijuDef, scale: number, mutation: string?)
	local bodyColor = def.Body
	local accentColor = def.Accent
	local idx = 1

	local function style(c: Color3, isAcc: boolean, mat: Enum.Material?)
		idx += 1
		return resolvePartStyle(c, isAcc, mutation, idx, mat)
	end

	-- Walking Legs (4)
	local legCol, legMat = style(bodyColor, false, nil)
	makePart(model, root, "FootFL", Vector3.new(0.35, 0.4, 0.35) * scale, CFrame.new(-1.4 * scale, 0.2 * scale, 0.45 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "FootFR", Vector3.new(0.35, 0.4, 0.35) * scale, CFrame.new(1.4 * scale, 0.2 * scale, 0.45 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "FootBL", Vector3.new(0.35, 0.4, 0.35) * scale, CFrame.new(-1.4 * scale, 0.2 * scale, -0.45 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "FootBR", Vector3.new(0.35, 0.4, 0.35) * scale, CFrame.new(1.4 * scale, 0.2 * scale, -0.45 * scale), legCol, legMat, Enum.PartType.Block)

	-- Upper legs angled
	local upLegCfFL = CFrame.new(-1.15 * scale, 0.55 * scale, 0.35 * scale) * CFrame.Angles(0, 0, math.rad(-30))
	local upLegCfFR = CFrame.new(1.15 * scale, 0.55 * scale, 0.35 * scale) * CFrame.Angles(0, 0, math.rad(30))
	local upLegCfBL = CFrame.new(-1.15 * scale, 0.55 * scale, -0.35 * scale) * CFrame.Angles(0, 0, math.rad(-30))
	local upLegCfBR = CFrame.new(1.15 * scale, 0.55 * scale, -0.35 * scale) * CFrame.Angles(0, 0, math.rad(30))
	makePart(model, root, "UpLegFL", Vector3.new(0.3, 0.7, 0.3) * scale, upLegCfFL, legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "UpLegFR", Vector3.new(0.3, 0.7, 0.3) * scale, upLegCfFR, legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "UpLegBL", Vector3.new(0.3, 0.7, 0.3) * scale, upLegCfBL, legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "UpLegBR", Vector3.new(0.3, 0.7, 0.3) * scale, upLegCfBR, legCol, legMat, Enum.PartType.Block)

	-- Carapace (Main body)
	local shellCol, shellMat = style(bodyColor, false, nil)
	makePart(model, root, "Carapace", Vector3.new(2.5, 1.0, 1.9) * scale, CFrame.new(0, 0.95 * scale, 0), shellCol, shellMat, Enum.PartType.Block)

	-- Top shell shield (Accent)
	local plateCol, plateMat = style(accentColor, true, nil)
	makePart(model, root, "ShellPlate", Vector3.new(2.1, 0.35, 1.5) * scale, CFrame.new(0, 1.45 * scale, 0), plateCol, plateMat, Enum.PartType.Block)

	-- Eye Stalks and Eyes
	local stalkCol, stalkMat = style(bodyColor, false, nil)
	makePart(model, root, "StalkL", Vector3.new(0.18, 0.55, 0.18) * scale, CFrame.new(-0.45 * scale, 1.6 * scale, 0.85 * scale), stalkCol, stalkMat, Enum.PartType.Block)
	makePart(model, root, "StalkR", Vector3.new(0.18, 0.55, 0.18) * scale, CFrame.new(0.45 * scale, 1.6 * scale, 0.85 * scale), stalkCol, stalkMat, Enum.PartType.Block)

	makeCuteEye(model, root, Vector3.new(-0.45 * scale, 2.0 * scale, 0.85 * scale), Vector3.new(0, 0, 1), 0.44, scale)
	makeCuteEye(model, root, Vector3.new(0.45 * scale, 2.0 * scale, 0.85 * scale), Vector3.new(0, 0, 1), 0.44, scale)

	-- Big Pincer Claws (Left and Right)
	local clawArmCol, clawArmMat = style(bodyColor, false, nil)
	local armCfL = CFrame.new(-1.45 * scale, 1.0 * scale, 0.75 * scale) * CFrame.Angles(0, math.rad(-25), 0)
	local armCfR = CFrame.new(1.45 * scale, 1.0 * scale, 0.75 * scale) * CFrame.Angles(0, math.rad(25), 0)
	makePart(model, root, "ClawArmL", Vector3.new(0.4, 0.4, 0.8) * scale, armCfL, clawArmCol, clawArmMat, Enum.PartType.Block)
	makePart(model, root, "ClawArmR", Vector3.new(0.4, 0.4, 0.8) * scale, armCfR, clawArmCol, clawArmMat, Enum.PartType.Block)

	-- Claw Bases
	local clawCol, clawMat = style(accentColor, true, nil)
	makePart(model, root, "ClawBaseL", Vector3.new(0.7, 0.7, 0.8) * scale, CFrame.new(-1.8 * scale, 1.05 * scale, 1.35 * scale), clawCol, clawMat, Enum.PartType.Block)
	makePart(model, root, "ClawBaseR", Vector3.new(0.7, 0.7, 0.8) * scale, CFrame.new(1.8 * scale, 1.05 * scale, 1.35 * scale), clawCol, clawMat, Enum.PartType.Block)

	-- Pincer jaws (Wedges)
	local upPincerCfL = CFrame.new(-1.8 * scale, 1.35 * scale, 1.9 * scale) * CFrame.Angles(0, math.rad(180), 0)
	local dnPincerCfL = CFrame.new(-1.8 * scale, 0.75 * scale, 1.9 * scale) * CFrame.Angles(math.rad(180), 0, 0)
	local upPincerCfR = CFrame.new(1.8 * scale, 1.35 * scale, 1.9 * scale) * CFrame.Angles(0, math.rad(180), 0)
	local dnPincerCfR = CFrame.new(1.8 * scale, 0.75 * scale, 1.9 * scale) * CFrame.Angles(math.rad(180), 0, 0)
	makeWedge(model, root, "PincerUpL", Vector3.new(0.28, 0.4, 0.65) * scale, upPincerCfL, clawCol, clawMat)
	makeWedge(model, root, "PincerDnL", Vector3.new(0.28, 0.4, 0.65) * scale, dnPincerCfL, clawCol, clawMat)
	makeWedge(model, root, "PincerUpR", Vector3.new(0.28, 0.4, 0.65) * scale, upPincerCfR, clawCol, clawMat)
	makeWedge(model, root, "PincerDnR", Vector3.new(0.28, 0.4, 0.65) * scale, dnPincerCfR, clawCol, clawMat)
end

-- 4. BIRD SHAPE
local function buildBird(model: Model, root: Part, def: KaijuDef, scale: number, mutation: string?)
	local bodyColor = def.Body
	local accentColor = def.Accent
	local idx = 1

	local function style(c: Color3, isAcc: boolean, mat: Enum.Material?)
		idx += 1
		return resolvePartStyle(c, isAcc, mutation, idx, mat)
	end

	-- Feet (Talons in Accent color)
	local footCol, footMat = style(accentColor, true, nil)
	makePart(model, root, "FootL", Vector3.new(0.4, 0.25, 0.6) * scale, CFrame.new(-0.45 * scale, 0.13 * scale, 0.15 * scale), footCol, footMat, Enum.PartType.Block)
	makePart(model, root, "FootR", Vector3.new(0.4, 0.25, 0.6) * scale, CFrame.new(0.45 * scale, 0.13 * scale, 0.15 * scale), footCol, footMat, Enum.PartType.Block)

	-- Legs
	local legCol, legMat = style(bodyColor, false, nil)
	makePart(model, root, "LegL", Vector3.new(0.2, 0.5, 0.2) * scale, CFrame.new(-0.45 * scale, 0.45 * scale, 0), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "LegR", Vector3.new(0.2, 0.5, 0.2) * scale, CFrame.new(0.45 * scale, 0.45 * scale, 0), legCol, legMat, Enum.PartType.Block)

	-- Torso (Plump egg-like body)
	local bodyCol, bodyMat = style(bodyColor, false, nil)
	makePart(model, root, "Torso", Vector3.new(1.8, 1.6, 1.8) * scale, CFrame.new(0, 1.35 * scale, 0), bodyCol, bodyMat, Enum.PartType.Ball)

	-- Belly patch
	local bellyCol, bellyMat = style(accentColor, true, nil)
	makePart(model, root, "Belly", Vector3.new(1.2, 1.2, 0.35) * scale, CFrame.new(0, 1.25 * scale, 0.75 * scale), bellyCol, bellyMat, Enum.PartType.Block)

	-- Head
	local headCol, headMat = style(bodyColor, false, nil)
	makePart(model, root, "Head", Vector3.new(1.4, 1.3, 1.4) * scale, CFrame.new(0, 2.35 * scale, 0.3 * scale), headCol, headMat, Enum.PartType.Ball)

	-- Beak (Wedge in Accent color)
	local beakCol, beakMat = style(accentColor, true, nil)
	local beakCf = CFrame.new(0, 2.25 * scale, 1.15 * scale) * CFrame.Angles(0, math.rad(180), 0)
	makeWedge(model, root, "Beak", Vector3.new(0.45, 0.35, 0.6) * scale, beakCf, beakCol, beakMat)

	-- Eyes
	makeCuteEye(model, root, Vector3.new(-0.6 * scale, 2.45 * scale, 0.82 * scale), Vector3.new(-0.35, 0, 0.93), 0.42, scale)
	makeCuteEye(model, root, Vector3.new(0.6 * scale, 2.45 * scale, 0.82 * scale), Vector3.new(0.35, 0, 0.93), 0.42, scale)

	-- Head Crest / Tuft Feathers (Accent)
	local crestCol, crestMat = style(accentColor, true, nil)
	makePart(model, root, "CrestMid", Vector3.new(0.2, 0.65, 0.4) * scale, CFrame.new(0, 3.15 * scale, 0.15 * scale), crestCol, crestMat, Enum.PartType.Block)
	local crestCfL = CFrame.new(-0.25 * scale, 3.05 * scale, 0.1 * scale) * CFrame.Angles(0, 0, math.rad(15))
	local crestCfR = CFrame.new(0.25 * scale, 3.05 * scale, 0.1 * scale) * CFrame.Angles(0, 0, math.rad(-15))
	makePart(model, root, "CrestL", Vector3.new(0.18, 0.5, 0.35) * scale, crestCfL, crestCol, crestMat, Enum.PartType.Block)
	makePart(model, root, "CrestR", Vector3.new(0.18, 0.5, 0.35) * scale, crestCfR, crestCol, crestMat, Enum.PartType.Block)

	-- Wings (2)
	local wingCol, wingMat = style(bodyColor, false, nil)
	local wingCfL = CFrame.new(-1.05 * scale, 1.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(-15))
	local wingCfR = CFrame.new(1.05 * scale, 1.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(15))
	makePart(model, root, "WingL", Vector3.new(0.35, 1.1, 1.3) * scale, wingCfL, wingCol, wingMat, Enum.PartType.Block)
	makePart(model, root, "WingR", Vector3.new(0.35, 1.1, 1.3) * scale, wingCfR, wingCol, wingMat, Enum.PartType.Block)

	-- Tail feathers
	local tailCol, tailMat = style(accentColor, true, nil)
	makePart(model, root, "TailFan", Vector3.new(1.0, 0.25, 0.8) * scale, CFrame.new(0, 1.35 * scale, -1.15 * scale), tailCol, tailMat, Enum.PartType.Block)
end

-- 5. TALL SHAPE
local function buildTall(model: Model, root: Part, def: KaijuDef, scale: number, mutation: string?)
	local bodyColor = def.Body
	local accentColor = def.Accent
	local idx = 1

	local function style(c: Color3, isAcc: boolean, mat: Enum.Material?)
		idx += 1
		return resolvePartStyle(c, isAcc, mutation, idx, mat)
	end

	-- 4 Columnar Stilt Legs
	local legCol, legMat = style(bodyColor, false, nil)
	makePart(model, root, "LegFL", Vector3.new(0.4, 2.0, 0.4) * scale, CFrame.new(-0.55 * scale, 1.0 * scale, 0.55 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "LegFR", Vector3.new(0.4, 2.0, 0.4) * scale, CFrame.new(0.55 * scale, 1.0 * scale, 0.55 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "LegBL", Vector3.new(0.4, 2.0, 0.4) * scale, CFrame.new(-0.55 * scale, 1.0 * scale, -0.55 * scale), legCol, legMat, Enum.PartType.Block)
	makePart(model, root, "LegBR", Vector3.new(0.4, 2.0, 0.4) * scale, CFrame.new(0.55 * scale, 1.0 * scale, -0.55 * scale), legCol, legMat, Enum.PartType.Block)

	-- Hooves (Accent)
	local hoofCol, hoofMat = style(accentColor, true, nil)
	makePart(model, root, "HoofFL", Vector3.new(0.46, 0.3, 0.46) * scale, CFrame.new(-0.55 * scale, 0.15 * scale, 0.55 * scale), hoofCol, hoofMat, Enum.PartType.Block)
	makePart(model, root, "HoofFR", Vector3.new(0.46, 0.3, 0.46) * scale, CFrame.new(0.55 * scale, 0.15 * scale, 0.55 * scale), hoofCol, hoofMat, Enum.PartType.Block)
	makePart(model, root, "HoofBL", Vector3.new(0.46, 0.3, 0.46) * scale, CFrame.new(-0.55 * scale, 0.15 * scale, -0.55 * scale), hoofCol, hoofMat, Enum.PartType.Block)
	makePart(model, root, "HoofBR", Vector3.new(0.46, 0.3, 0.46) * scale, CFrame.new(0.55 * scale, 0.15 * scale, -0.55 * scale), hoofCol, hoofMat, Enum.PartType.Block)

	-- Lower Torso
	local bodyCol, bodyMat = style(bodyColor, false, nil)
	makePart(model, root, "Torso", Vector3.new(1.6, 1.2, 1.8) * scale, CFrame.new(0, 2.3 * scale, 0), bodyCol, bodyMat, Enum.PartType.Block)

	-- Tail with puff
	local tailCol, tailMat = style(bodyColor, false, nil)
	makePart(model, root, "TailStem", Vector3.new(0.25, 0.7, 0.5) * scale, CFrame.new(0, 2.2 * scale, -1.1 * scale), tailCol, tailMat, Enum.PartType.Block)
	local puffCol, puffMat = style(accentColor, true, nil)
	makePart(model, root, "TailPuff", Vector3.new(0.45, 0.45, 0.45) * scale, CFrame.new(0, 1.9 * scale, -1.45 * scale), puffCol, puffMat, Enum.PartType.Ball)

	-- Long Neck (3 ascending segments)
	local neckCol, neckMat = style(bodyColor, false, nil)
	makePart(model, root, "Neck1", Vector3.new(0.7, 1.3, 0.7) * scale, CFrame.new(0, 3.2 * scale, 0.35 * scale), neckCol, neckMat, Enum.PartType.Block)
	makePart(model, root, "Neck2", Vector3.new(0.6, 1.3, 0.6) * scale, CFrame.new(0, 4.3 * scale, 0.65 * scale), neckCol, neckMat, Enum.PartType.Block)
	makePart(model, root, "Neck3", Vector3.new(0.55, 1.2, 0.55) * scale, CFrame.new(0, 5.3 * scale, 0.95 * scale), neckCol, neckMat, Enum.PartType.Block)

	-- Neck Accent Pattern / Rings
	local ringCol, ringMat = style(accentColor, true, nil)
	makePart(model, root, "NeckRing1", Vector3.new(0.76, 0.25, 0.76) * scale, CFrame.new(0, 3.6 * scale, 0.45 * scale), ringCol, ringMat, Enum.PartType.Block)
	makePart(model, root, "NeckRing2", Vector3.new(0.66, 0.25, 0.66) * scale, CFrame.new(0, 4.7 * scale, 0.78 * scale), ringCol, ringMat, Enum.PartType.Block)

	-- Head
	local headCol, headMat = style(bodyColor, false, nil)
	makePart(model, root, "Head", Vector3.new(1.0, 0.9, 1.25) * scale, CFrame.new(0, 6.1 * scale, 1.15 * scale), headCol, headMat, Enum.PartType.Block)

	-- Snout
	local snoutCol, snoutMat = style(bodyColor, false, nil)
	makePart(model, root, "Snout", Vector3.new(0.7, 0.6, 0.65) * scale, CFrame.new(0, 5.9 * scale, 1.8 * scale), snoutCol, snoutMat, Enum.PartType.Block)

	-- Eyes
	makeCuteEye(model, root, Vector3.new(-0.55 * scale, 6.25 * scale, 1.45 * scale), Vector3.new(-0.35, 0, 0.93), 0.38, scale)
	makeCuteEye(model, root, Vector3.new(0.55 * scale, 6.25 * scale, 1.45 * scale), Vector3.new(0.35, 0, 0.93), 0.38, scale)

	-- Horns / Antennae with cute bobble spheres
	local hornCol, hornMat = style(accentColor, true, nil)
	makePart(model, root, "HornStalkL", Vector3.new(0.16, 0.55, 0.16) * scale, CFrame.new(-0.3 * scale, 6.75 * scale, 1.0 * scale), hornCol, hornMat, Enum.PartType.Block)
	makePart(model, root, "HornStalkR", Vector3.new(0.16, 0.55, 0.16) * scale, CFrame.new(0.3 * scale, 6.75 * scale, 1.0 * scale), hornCol, hornMat, Enum.PartType.Block)

	local tipCol, tipMat = style(accentColor, true, Enum.Material.Neon)
	makePart(model, root, "HornTipL", Vector3.new(0.35, 0.35, 0.35) * scale, CFrame.new(-0.3 * scale, 7.1 * scale, 1.0 * scale), tipCol, tipMat, Enum.PartType.Ball)
	makePart(model, root, "HornTipR", Vector3.new(0.35, 0.35, 0.35) * scale, CFrame.new(0.3 * scale, 7.1 * scale, 1.0 * scale), tipCol, tipMat, Enum.PartType.Ball)

	-- Back Mane (Accent ridge along the neck)
	local maneCol, maneMat = style(accentColor, true, nil)
	makePart(model, root, "Mane1", Vector3.new(0.2, 0.8, 0.35) * scale, CFrame.new(0, 3.3 * scale, -0.05 * scale), maneCol, maneMat, Enum.PartType.Block)
	makePart(model, root, "Mane2", Vector3.new(0.2, 0.8, 0.35) * scale, CFrame.new(0, 4.4 * scale, 0.3 * scale), maneCol, maneMat, Enum.PartType.Block)
	makePart(model, root, "Mane3", Vector3.new(0.2, 0.8, 0.35) * scale, CFrame.new(0, 5.5 * scale, 0.65 * scale), maneCol, maneMat, Enum.PartType.Block)
end

-- =============================================================================
-- BILLBOARD GUI "TAG" BUILDER
-- =============================================================================

local function createTag(
	root: Part,
	def: KaijuDef,
	scale: number,
	totalHeight: number,
	normMutation: string?
): BillboardGui
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Adornee = root
	tag.Size = UDim2.new(0, 150, 0, 72)
	-- Offset floats 1.2 studs above the highest point of the model
	tag.StudsOffset = Vector3.new(0, (totalHeight / 2) + 1.2 * math.clamp(scale, 0.8, 2.5), 0)
	tag.AlwaysOnTop = false -- labels must not show through base walls
	tag.MaxDistance = 80
	tag.ResetOnSpawn = false
	tag.Parent = root

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(24, 25, 30)
	card.BackgroundTransparency = 0.25
	card.BorderSizePixel = 0
	card.Parent = tag

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Kaiju.RarityColor[def.Rarity] or Color3.fromRGB(160, 160, 160)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = card

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 1)
	list.Parent = card

	-- 1. Name label (memetic Russian name, plus mutation tag if present)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.LayoutOrder = 1
	nameLabel.Size = UDim2.new(1, -8, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = if normMutation
		then def.Name .. " [" .. (normMutation :: string) .. "]"
		else def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 13
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	-- 2. Rarity label (colored by RarityColor)
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.LayoutOrder = 2
	rarityLabel.Size = UDim2.new(1, -8, 0, 14)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.Text = string.upper(def.Rarity)
	rarityLabel.TextColor3 = Kaiju.RarityColor[def.Rarity] or Color3.fromRGB(200, 200, 200)
	rarityLabel.TextSize = 11
	rarityLabel.Parent = card

	-- 3. Income label (contract: Label "Income")
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.LayoutOrder = 3
	incomeLabel.Size = UDim2.new(1, -8, 0, 16)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.Text = Format.rate(def.Income)
	incomeLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
	incomeLabel.TextSize = 12
	incomeLabel.Parent = card

	-- 4. Stage label (contract: Label "Stage")
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "Stage"
	stageLabel.LayoutOrder = 4
	stageLabel.Size = UDim2.new(1, -8, 0, 14)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Font = Enum.Font.GothamMedium
	stageLabel.Text = "Stage S"
	stageLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	stageLabel.TextSize = 11
	stageLabel.Parent = card

	return tag
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

-- Builds a complete Kaiju model from part primitives.
-- PrimaryPart "Root" (Anchored=false, CanCollide=false, Massless), all parts welded to Root.
-- Bottom of the model is exactly at Root.Position.Y - Root.Size.Y / 2.
-- BillboardGui "Tag" over head: Name, Rarity, Income, Stage.
function KaijuModel.build(def: KaijuDef, scale: number, mutation: string?): Model
	scale = math.max(0.2, scale or 1)
	local normMutation = normalizeMutation(mutation)

	local model = Instance.new("Model")
	model.Name = def.Id

	-- Determine model bounding dimensions by Shape
	local shapeName = string.lower(def.Shape or "blob")
	local baseWidth = 2.4
	local baseHeight = 3.6
	local baseDepth = 2.6

	if shapeName == "dino" then
		baseWidth, baseHeight, baseDepth = 2.4, 3.7, 3.6
	elseif shapeName == "blob" then
		baseWidth, baseHeight, baseDepth = 2.8, 3.4, 2.6
	elseif shapeName == "crab" then
		baseWidth, baseHeight, baseDepth = 3.8, 2.5, 2.8
	elseif shapeName == "bird" then
		baseWidth, baseHeight, baseDepth = 2.6, 3.5, 2.6
	elseif shapeName == "tall" then
		baseWidth, baseHeight, baseDepth = 2.0, 7.3, 2.8
	end

	local totalWidth = baseWidth * scale
	local totalHeight = baseHeight * scale
	local totalDepth = baseDepth * scale

	-- PrimaryPart "Root": centered at Y = totalHeight / 2 so that
	-- Root.Position.Y - Root.Size.Y / 2 == 0, exactly aligning with the model's bottom.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(totalWidth, totalHeight, totalDepth)
	root.CFrame = CFrame.new(0, totalHeight / 2, 0)
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = false
	root.Massless = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	-- Build parts based on Shape
	if shapeName == "dino" then
		buildDino(model, root, def, scale, normMutation)
	elseif shapeName == "blob" then
		buildBlob(model, root, def, scale, normMutation)
	elseif shapeName == "crab" then
		buildCrab(model, root, def, scale, normMutation)
	elseif shapeName == "bird" then
		buildBird(model, root, def, scale, normMutation)
	elseif shapeName == "tall" then
		buildTall(model, root, def, scale, normMutation)
	else
		buildBlob(model, root, def, scale, normMutation)
	end

	-- Apply mutation effects (lights and sparkles; no Highlight, the client caps them at 31)
	if normMutation == "Radioactive" then
		local light = Instance.new("PointLight")
		light.Name = "RadioactiveLight"
		light.Color = Color3.fromRGB(80, 255, 60)
		light.Brightness = 2.5
		light.Range = 14 * scale
		light.Parent = root

	elseif normMutation == "Golden" then
		local light = Instance.new("PointLight")
		light.Name = "GoldenLight"
		light.Color = Color3.fromRGB(255, 215, 80)
		light.Brightness = 2.0
		light.Range = 12 * scale
		light.Parent = root

		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "GoldenSparkles"
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 100)
		sparkles.Parent = root

	elseif normMutation == "Rainbow" then
		local light = Instance.new("PointLight")
		light.Name = "RainbowLight"
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Brightness = 2.0
		light.Range = 12 * scale
		light.Parent = root

	elseif normMutation == "Galaxy" then
		local light = Instance.new("PointLight")
		light.Name = "GalaxyLight"
		light.Color = Color3.fromRGB(180, 60, 255)
		light.Brightness = 2.5
		light.Range = 14 * scale
		light.Parent = root

		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "GalaxySparkles"
		sparkles.SparkleColor = Color3.fromRGB(210, 120, 255)
		sparkles.Parent = root

	end

	-- Create BillboardGui "Tag"
	createTag(root, def, scale, totalHeight, normMutation)

	return model
end

-- Updates the Income and Stage text labels on the model's "Tag" BillboardGui
function KaijuModel.setInfo(model: Model, incomeText: string, stageText: string)
	local tag = model:FindFirstChild("Tag", true)
	if not tag then
		return
	end
	local incomeLabel = tag:FindFirstChild("Income", true) :: TextLabel?
	if incomeLabel then
		incomeLabel.Text = incomeText
	end
	local stageLabel = tag:FindFirstChild("Stage", true) :: TextLabel?
	if stageLabel then
		stageLabel.Text = stageText
	end
end

return KaijuModel
