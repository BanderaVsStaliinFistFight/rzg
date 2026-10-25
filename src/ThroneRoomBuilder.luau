--!nocheck
--[[
	Asgore's Throne Room (Undertale), built from Roblox parts.

	Ways to use it:
	  * Open dist/AsgoreThroneRoom.rbxl in Roblox Studio. It was made by running this file
	    through tools/build.luau, so everything below is already built.
	  * Studio command bar: paste this whole file and press Enter. It builds the room in
	    Workspace (about 25k parts, a few seconds), sets up the lighting and moves the
	    camera to the entrance.
	  * As a Script in ServerScriptService: the room is built when the server starts. The
	    save point's spin and dialog box need the place file or the command bar, because a
	    running game can't create scripts.

	Room space (studs): the inside face of the back wall is z = 0 and +z runs toward the
	entrance corridor. x = 0 is the room's centre line, y = 0 is the floor.

	    back wall:   ivy | doorway | save star | window | covered throne | ivy      z = 0
	                 golden flower bed, Asgore's throne in a clearing near the top
	                 round bushes                                                  z = 124
	                 the hall narrows in three steps to the entrance corridor      z = 140
	                 corridor, spawn point                                         z = 190
]]

local CONFIG = {
	Origin = CFrame.new(0, 0, 0), -- where room space (0, 0, 0) sits in the world
	Seed = 915, -- change it for a different flower and ivy layout
	FlowerSpacing = 1.45, -- smaller means more flowers (and more parts)
	ApplyLighting = true, -- set Lighting and post effects for the room
	MoveCamera = true, -- command bar only: frame the room after building
	ReplaceExisting = true, -- delete an earlier AsgoreThroneRoom in Workspace first
	MusicId = "", -- optional: the numeric id of an audio asset you are allowed to use
}

local IS_LUNE = __LUNE == true -- set by tools/build.luau

local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local ANG = CFrame.Angles
local PI, TAU = math.pi, math.pi * 2
local sin, cos, sqrt, abs, floor = math.sin, math.cos, math.sqrt, math.abs, math.floor
local max, min, atan2, acos, rad = math.max, math.min, math.atan2, math.acos, math.rad
local M = Enum.Material
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local ORIGIN = CONFIG.Origin

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local H = 48 -- wall height up to the ceiling
local T = 4 -- wall thickness
local W = 42 -- half width of the main hall
local STEPS = { -- the hall narrows toward the corridor in three steps
	{ z = 124, hw = 35 },
	{ z = 132, hw = 21 },
	{ z = 140, hw = 7 },
}
local CORRIDOR = { z0 = 140, z1 = 190, hw = 7, h = 22 }
local DOOR = { x0 = -27, x1 = -9, h = 26, depth = 22 }
local WIN = { x = 9, y0 = 8, a = 10, spring = 16, R = 18 } -- pointed-arch window
WIN.cx = WIN.R - WIN.a
WIN.h = sqrt(WIN.R ^ 2 - WIN.cx ^ 2)
WIN.top = WIN.y0 + WIN.spring + WIN.h
local PILASTERS = { 14, 38, 62, 86, 110 }
local BED = { cx = 0, cz = 56, rx = 37.5, rz = 49.5 }
local CLEARING = { cx = -1, cz = 28.5, rx = 12.5, rz = 9.5 }
local THRONE_POS = V3(-1, 0.4, 27.5) -- standing on the dirt
local COVERED_POS = V3(22, 0, 7)
local SAVE_POS = V3(2.5, 3.4, 4.5)
local SPAWN_POS = V3(0, 0, 181)
-- From the room toward the sun: behind the back wall, high up and a little to the right,
-- so its light falls through the window, across the flowers and onto the throne.
local SUN_TOWARD = V3(0.28, 0.8, -1).Unit
local LIGHT_DIR = -SUN_TOWARD

local C = {
	wall = RGB(228, 178, 42),
	wallShade = RGB(212, 160, 34),
	trim = RGB(188, 130, 36),
	trimDark = RGB(142, 94, 26),
	wood = RGB(92, 56, 28),
	woodDark = RGB(62, 38, 20),
	ceiling = RGB(116, 80, 38),
	tileA = RGB(168, 96, 48),
	tileB = RGB(138, 74, 38),
	grout = RGB(70, 42, 24),
	grass = RGB(36, 82, 50),
	soil = RGB(74, 60, 28),
	dirt = RGB(112, 76, 42),
	foliage = RGB(80, 98, 28),
	foliageBright = RGB(108, 126, 36),
	petalDeep = RGB(176, 140, 8),
	petalDim = RGB(214, 176, 10),
	petal = RGB(255, 220, 0),
	petalBright = RGB(255, 238, 60),
	center = RGB(226, 150, 12),
	centerDim = RGB(180, 118, 10),
	stem = RGB(70, 108, 34),
	leaf = RGB(62, 112, 40),
	ivy = { RGB(30, 76, 46), RGB(38, 92, 52), RGB(26, 62, 40), RGB(50, 104, 56), RGB(42, 84, 38) },
	ivyLeaf = { RGB(52, 112, 58), RGB(66, 126, 62), RGB(44, 98, 50), RGB(78, 134, 60) },
	berry = RGB(234, 152, 38),
	bush = RGB(70, 140, 76),
	bushDark = RGB(40, 98, 56),
	gold = RGB(222, 172, 58),
	purple = RGB(104, 60, 150),
	purpleDeep = RGB(72, 40, 108),
	lavender = RGB(148, 106, 198),
	sheet = RGB(236, 236, 240),
	sheetShade = RGB(222, 222, 230),
	glass = RGB(255, 234, 178),
	glassWarm = RGB(255, 214, 140),
	amber = RGB(255, 160, 36),
	amberCore = RGB(255, 196, 72),
	lead = RGB(66, 48, 30),
	frame = RGB(156, 108, 32),
	star = RGB(255, 228, 66),
	path = RGB(112, 112, 118),
	pathEdge = RGB(84, 84, 90),
	void = RGB(14, 11, 9),
	light = RGB(255, 206, 140),
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- xorshift32, so the layout is the same in Studio and in Lune
local rngState = max(1, floor(CONFIG.Seed))
local function rand()
	local x = rngState
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	rngState = x
	return x / 4294967296
end
local function rr(a, b)
	return a + (b - a) * rand()
end
local function pick(list)
	return list[floor(rand() * #list) + 1]
end

local function clamp01(t)
	return min(1, max(0, t))
end
local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end
local function hash2(ix, iz)
	local s = sin(ix * 127.1 + iz * 311.7 + CONFIG.Seed * 0.0137) * 43758.5453
	return s - floor(s)
end
local function noise2(x, z) -- smooth value noise in [0, 1]
	local ix, iz = floor(x), floor(z)
	local fx, fz = smooth(x - ix), smooth(z - iz)
	local a, b = hash2(ix, iz), hash2(ix + 1, iz)
	local c, d = hash2(ix, iz + 1), hash2(ix + 1, iz + 1)
	local top = a + (b - a) * fx
	return top + ((c + (d - c) * fx) - top) * fz
end

local function mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local function shade(c, f)
	return Color3.new(min(1, c.R * f), min(1, c.G * f), min(1, c.B * f))
end
local function jitter(c, amount)
	return shade(c, 1 + (rand() - 0.5) * 2 * amount)
end

local function merge(a, b)
	local t = {}
	if a then
		for k, v in a do
			t[k] = v
		end
	end
	if b then
		for k, v in b do
			t[k] = v
		end
	end
	return t
end

local function trySet(instance, property, value)
	pcall(function()
		instance[property] = value
	end)
end

-- Decorative parts are anchored and skip collisions, touches, queries and shadows.
-- Walls, floors and furniture pass SOLID to turn those back on.
local SOLID = { CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true }
local SHADOW = { CastShadow = true }
local BALL_P = { Shape = BALL }
local CYL_P = { Shape = CYL }

local templates = {}
local function getTemplate(className, shape)
	local key = className .. ":" .. (shape and shape.Name or "")
	local t = templates[key]
	if not t then
		t = Instance.new(className)
		t.Anchored = true
		t.CanCollide = false
		t.CanTouch = false
		t.CanQuery = false
		t.CastShadow = false
		t.TopSurface = Enum.SurfaceType.Smooth
		t.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			t.Shape = shape
		end
		templates[key] = t
	end
	return t
end

local canYield = false
if not IS_LUNE then
	pcall(function()
		canYield = game:GetService("RunService"):IsRunning()
	end)
end
local partCount = 0

-- Every part goes through here. `cf` is in room space; CONFIG.Origin is applied here.
local function part(parent, cf, size, color, material, props)
	local p = getTemplate(props and props.Class or "Part", props and props.Shape):Clone()
	p.Size = size
	p.CFrame = ORIGIN * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	if props then
		for k, v in props do
			if k ~= "Class" and k ~= "Shape" then
				p[k] = v
			end
		end
	end
	p.Parent = parent
	partCount += 1
	if canYield and partCount % 1500 == 0 then
		task.wait()
	end
	return p
end

local function block(parent, x0, y0, z0, x1, y1, z1, color, material, props)
	return part(
		parent,
		CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		V3(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)),
		color,
		material,
		props
	)
end

local function ball(parent, pos, d, color, material, props)
	return part(parent, CF(pos), V3(d, d, d), color, material, merge(props, BALL_P))
end

-- A frame whose X axis points along `xAxis`.
local function frameX(pos, xAxis, upHint)
	xAxis = xAxis.Unit
	local up = upHint or V3(0, 1, 0)
	if abs(xAxis:Dot(up)) > 0.98 then
		up = V3(0, 0, 1)
	end
	local z = xAxis:Cross(up).Unit
	local y = z:Cross(xAxis).Unit
	return CFrame.fromMatrix(pos, xAxis, y, z)
end

local function cylBetween(parent, a, b, d, color, material, props)
	return part(parent, frameX((a + b) / 2, b - a), V3((b - a).Magnitude, d, d), color, material, merge(props, CYL_P))
end

-- A flat disc lying in the XZ plane of `cf` (its face points along cf.UpVector).
local function disc(parent, cf, d, thick, color, material, props)
	return part(parent, cf * ANG(0, 0, PI / 2), V3(thick, d, d), color, material, merge(props, CYL_P))
end

-- A disc standing upright, facing +z of `cf`.
local function plate(parent, cf, d, thick, color, material, props)
	return part(parent, cf * ANG(0, PI / 2, 0), V3(thick, d, d), color, material, merge(props, CYL_P))
end

local function ellipsoid(parent, cf, size, color, props)
	local p = part(parent, cf, size, color, M.SmoothPlastic, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Any triangle, from two wedges (EgoMoose's method). Points are in room space.
local WEDGE_P = { Class = "WedgePart" }
local function triangle(parent, a, b, c, color, material, thickness, props)
	thickness = thickness or 0.2
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = abs(ab:Dot(up))
	local wp = merge(props, WEDGE_P)
	part(parent, CFrame.fromMatrix((a + b) / 2, right, up, back), V3(thickness, height, abs(ab:Dot(back))), color, material, wp)
	part(parent, CFrame.fromMatrix((a + c) / 2, -right, up, -back), V3(thickness, height, abs(ac:Dot(back))), color, material, wp)
end

-- Boxes joining 2D points {x, y} in the plane of `pf` (x right, y up, z out of the plane).
local function polyline(parent, pf, pts, width, depth, color, material, props, zOffset)
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local dx, dy = p1[1] - p0[1], p1[2] - p0[2]
		local len = sqrt(dx * dx + dy * dy)
		if len > 1e-4 then
			local ux, uy = dx / len, dy / len
			local mid = V3((p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2, zOffset or 0)
			local cf = pf * CFrame.fromMatrix(mid, V3(ux, uy, 0), V3(-uy, ux, 0), V3(0, 0, 1))
			part(parent, cf, V3(len + width * 0.5, width, depth), color, material, props)
		end
	end
end

-- Points along a pointed (gothic) arch, from the left springing point over the apex to the
-- right one. The two arcs have radius R and the opening is 2 * a wide.
local function pointedArch(a, R, springY, segments)
	local cx = R - a
	local apexAngle = acos(-cx / R)
	local left = {}
	for i = 0, segments do
		local phi = PI + (apexAngle - PI) * (i / segments)
		table.insert(left, { cx + R * cos(phi), springY + R * sin(phi) })
	end
	local pts = table.clone(left)
	for i = #left - 1, 1, -1 do
		table.insert(pts, { -left[i][1], left[i][2] })
	end
	return pts
end

local function archHalfWidth(R, cx, y)
	return sqrt(max(0, R * R - y * y)) - cx
end

-- A frame on a wall's inside face: origin at (x0, 0, z0), x runs toward (x1, z1), y is up
-- and z points into the room. Walls are always given so the room is on their left.
local function wallPlane(x0, z0, x1, z1)
	local u = V3(x1 - x0, 0, z1 - z0).Unit
	return CFrame.fromMatrix(V3(x0, 0, z0), u, V3(0, 1, 0), V3(-u.Z, 0, u.X)), V3(x1 - x0, 0, z1 - z0).Magnitude
end

local function model(name, parent, className)
	local m = Instance.new(className or "Model")
	m.Name = name
	m.Parent = parent
	return m
end

--------------------------------------------------------------------------------
-- Walls, floor, ceiling
--------------------------------------------------------------------------------

local WAINSCOT = {
	{ y = 0, h = 0.7, d = 0.75, color = C.woodDark, mat = M.Wood },
	{ y = 0.7, h = 2.0, d = 0.45, color = C.wood, mat = M.WoodPlanks },
	{ y = 2.7, h = 0.45, d = 0.85, color = C.trim, mat = M.Sandstone },
}
local function cornice(top)
	return {
		{ y = top - 0.7, h = 0.7, d = 1.9, color = C.trim, mat = M.Sandstone },
		{ y = top - 1.9, h = 1.2, d = 1.2, color = C.trim, mat = M.Sandstone },
		{ y = top - 2.4, h = 0.5, d = 0.6, color = C.trimDark, mat = M.Sandstone },
	}
end

-- Moldings along one wall. e0/e1 say what happens at each end, per layer depth:
-- -1 stops short of a corner another run covers, 0 ends at the corner, +1 wraps an
-- outside corner.
local function trimRun(parent, x0, z0, x1, z1, e0, e1, layers)
	local pf, len = wallPlane(x0, z0, x1, z1)
	for _, layer in layers do
		local s0 = -e0 * layer.d
		local s1 = len + e1 * layer.d
		part(
			parent,
			pf * CF((s0 + s1) / 2, layer.y + layer.h / 2, layer.d / 2),
			V3(s1 - s0, layer.h, layer.d),
			layer.color,
			layer.mat,
			SHADOW
		)
	end
end

-- The same run on the other side of the room.
local function mirrorRun(parent, x0, z0, x1, z1, e0, e1, layers)
	trimRun(parent, -x1, z1, -x0, z0, e1, e0, layers)
end

local function buildShell(room)
	local shell = model("Architecture", room)
	local walls = model("Walls", shell)

	local floor = model("Floor", shell)
	block(floor, -W - T, -3, -T, W + T, 0, STEPS[1].z, C.grass, M.LeafyGrass, SOLID)
	block(floor, -STEPS[1].hw, -3, STEPS[1].z, STEPS[1].hw, 0, STEPS[2].z, C.grass, M.LeafyGrass, SOLID)
	block(floor, -STEPS[2].hw, -3, STEPS[2].z, STEPS[2].hw, 0, STEPS[3].z + 2, C.grass, M.LeafyGrass, SOLID)

	-- side walls, and the solid blocks that make the steps toward the corridor
	for side = -1, 1, 2 do
		local function sx(a, b)
			if side < 0 then
				return a, b
			end
			return -b, -a
		end
		local a, b = sx(-W - T, -W)
		block(walls, a, -1, -T, b, H + 1, STEPS[1].z, C.wall, M.Plaster, SOLID)
		a, b = sx(-W - T, -STEPS[1].hw)
		block(walls, a, -1, STEPS[1].z, b, H + 1, STEPS[2].z, C.wall, M.Plaster, SOLID)
		a, b = sx(-W - T, -STEPS[2].hw)
		block(walls, a, -1, STEPS[2].z, b, H + 1, STEPS[3].z, C.wall, M.Plaster, SOLID)
		a, b = sx(-W - T, -CORRIDOR.hw)
		block(walls, a, -1, STEPS[3].z, b, H + 1, STEPS[3].z + T, C.wall, M.Plaster, SOLID)
		a, b = sx(-CORRIDOR.hw - T, -CORRIDOR.hw)
		block(walls, a, -1, STEPS[3].z + T, b, CORRIDOR.h + 1, CORRIDOR.z1 + T, C.wall, M.Plaster, SOLID)
	end
	block(walls, -CORRIDOR.hw, CORRIDOR.h, STEPS[3].z, CORRIDOR.hw, H + 1, STEPS[3].z + T, C.wall, M.Plaster, SOLID)
	block(walls, -CORRIDOR.hw - T, -1, CORRIDOR.z1, CORRIDOR.hw + T, CORRIDOR.h + 1, CORRIDOR.z1 + T, C.wall, M.Plaster, SOLID)

	-- back wall, with the doorway and the window cut out
	local wx0, wx1 = WIN.x - WIN.a, WIN.x + WIN.a
	block(walls, -W - T, -1, -T, DOOR.x0, H + 1, 0, C.wall, M.Plaster, SOLID)
	block(walls, DOOR.x0, DOOR.h, -T, DOOR.x1, H + 1, 0, C.wall, M.Plaster, SOLID)
	block(walls, DOOR.x1, -1, -T, wx0, H + 1, 0, C.wall, M.Plaster, SOLID)
	block(walls, wx1, -1, -T, W + T, H + 1, 0, C.wall, M.Plaster, SOLID)
	block(walls, wx0, -1, -T, wx1, WIN.y0, 0, C.wall, M.Plaster, SOLID)
	block(walls, wx0, WIN.top, -T, wx1, H + 1, 0, C.wall, M.Plaster, SOLID)
	-- the wall beside the pointed arch, in thin slices; each slice uses the narrower width
	-- at its top edge so no light leaks past the window frame
	local y = 0
	while y < WIN.h - 1e-3 do
		local y1 = min(y + 0.3, WIN.h)
		local hw = archHalfWidth(WIN.R, WIN.cx, y1)
		local yy0, yy1 = WIN.y0 + WIN.spring + y, WIN.y0 + WIN.spring + y1
		block(walls, wx0, yy0, -T, WIN.x - hw, yy1, 0, C.wall, M.Plaster, SOLID)
		block(walls, WIN.x + hw, yy0, -T, wx1, yy1, 0, C.wall, M.Plaster, SOLID)
		y = y1
	end

	-- the dark passage behind the doorway
	local pz = -T - DOOR.depth
	local passage = model("Doorway", shell)
	block(passage, DOOR.x0 - T, -3, pz - T, DOOR.x1 + T, 0, -T, C.void, M.Slate, SOLID)
	block(passage, DOOR.x0 - T, -1, pz, DOOR.x0, DOOR.h + 1, -T, C.void, M.Slate, SOLID)
	block(passage, DOOR.x1, -1, pz, DOOR.x1 + T, DOOR.h + 1, -T, C.void, M.Slate, SOLID)
	block(passage, DOOR.x0 - T, -1, pz - T, DOOR.x1 + T, DOOR.h + 1, pz, C.void, M.Slate, SOLID)
	block(passage, DOOR.x0 - T, DOOR.h, pz - T, DOOR.x1 + T, DOOR.h + 3, -T, C.void, M.Slate, SOLID)
	-- threshold and frame
	block(passage, DOOR.x0, 0, -T, DOOR.x1, 0.25, 0.6, C.trim, M.Sandstone, SOLID)
	for _, x in { DOOR.x0, DOOR.x1 } do
		block(passage, x - 0.8, 0, -0.6, x + 0.8, DOOR.h, 0.6, C.trim, M.Sandstone, SHADOW)
		block(passage, x - 1.1, 0, -0.4, x + 1.1, 1.6, 0.8, C.trimDark, M.Sandstone, SHADOW)
	end
	block(passage, DOOR.x0 - 1.4, DOOR.h - 0.6, -0.6, DOOR.x1 + 1.4, DOOR.h + 1.4, 0.7, C.trim, M.Sandstone, SHADOW)
	block(passage, DOOR.x0 - 1.8, DOOR.h + 1.4, -0.4, DOOR.x1 + 1.8, DOOR.h + 2.0, 1.0, C.trimDark, M.Sandstone, SHADOW)

	-- ceiling, with dark beams over the pilasters
	local ceiling = model("Ceiling", shell)
	block(ceiling, -W - T, H, -T - 1, W + T, H + 3, STEPS[3].z + T, C.ceiling, M.WoodPlanks, SOLID)
	block(ceiling, -CORRIDOR.hw - T, CORRIDOR.h, STEPS[3].z, CORRIDOR.hw + T, CORRIDOR.h + 3, CORRIDOR.z1 + T, C.ceiling, M.WoodPlanks, SOLID)
	for _, z in PILASTERS do
		block(ceiling, -W, H - 2.4, z - 1.2, W, H, z + 1.2, C.woodDark, M.Wood, SHADOW)
	end

	-- corridor: a path of grey stone slabs, pilasters, beams and wall lamps
	local corridor = model("Corridor", shell)
	local cz0 = STEPS[3].z + 2
	block(corridor, -CORRIDOR.hw, -3, cz0, CORRIDOR.hw, 0.08, CORRIDOR.z1, C.pathEdge, M.Slate, SOLID)
	local slabW, slabD, row = 10 / 3, 3, 0
	for z = cz0, CORRIDOR.z1 - 0.5, slabD do
		for x = -5 - (row % 2) * slabW / 2, 5, slabW do
			local xa, xb = max(x, -5), min(x + slabW, 5)
			if xb - xa > 0.4 then
				block(corridor, xa + 0.07, 0.08, z + 0.07, xb - 0.07, 0.22, min(z + slabD, CORRIDOR.z1) - 0.07, jitter(C.path, 0.06), M.Slate, SOLID)
			end
		end
		row += 1
	end
	for side = -1, 1, 2 do
		block(corridor, side * 5, 0.08, cz0, side * CORRIDOR.hw, 0.3, CORRIDOR.z1, C.pathEdge, M.Slate, SOLID)
	end
	local corridorBays = { 152, 166, 180 }
	for side = -1, 1, 2 do
		local pf = side < 0 and wallPlane(-CORRIDOR.hw, CORRIDOR.z1, -CORRIDOR.hw, STEPS[3].z)
			or wallPlane(CORRIDOR.hw, STEPS[3].z, CORRIDOR.hw, CORRIDOR.z1)
		local function s(z)
			return side < 0 and (CORRIDOR.z1 - z) or (z - STEPS[3].z)
		end
		for _, z in corridorBays do
			local capital = CORRIDOR.h - 3.6
			part(corridor, pf * CF(s(z), 1.5, 0.6), V3(3.2, 3.0, 1.2), C.trimDark, M.Sandstone, SHADOW)
			part(corridor, pf * CF(s(z), (3 + capital) / 2, 0.4), V3(2.4, capital - 3, 0.8), C.trim, M.Sandstone, SHADOW)
			part(corridor, pf * CF(s(z), capital + 0.6, 0.65), V3(3.2, 1.2, 1.3), C.trimDark, M.Sandstone, SHADOW)
		end
		for i = 1, #corridorBays - 1 do -- a wall lamp in each bay
			local lamp = pf * CF(s((corridorBays[i] + corridorBays[i + 1]) / 2), 10, 0)
			part(corridor, lamp * CF(0, 0, 0.15), V3(1.0, 1.8, 0.3), C.gold, M.Metal, SHADOW)
			cylBetween(corridor, lamp * V3(0, -0.2, 0.2), lamp * V3(0, -0.2, 1.1), 0.3, C.gold, M.Metal)
			disc(corridor, lamp * CF(0, 0.05, 1.2), 0.9, 0.5, C.gold, M.Metal, SHADOW)
			local flame = ball(corridor, (lamp * CF(0, 0.55, 1.2)).Position, 0.6, RGB(255, 214, 140), M.Neon, { Name = "LampFlame" })
			local light = Instance.new("PointLight")
			light.Color = RGB(255, 198, 120)
			light.Brightness = 1.4
			light.Range = 16
			light.Parent = flame
		end
	end
	for _, z in corridorBays do
		block(corridor, -CORRIDOR.hw, CORRIDOR.h - 1.6, z - 0.9, CORRIDOR.hw, CORRIDOR.h, z + 0.9, C.woodDark, M.Wood, SHADOW)
	end
	-- a dark arch at the far end
	local endPf = CF(0, 0, CORRIDOR.z1 - 0.05) * ANG(0, PI, 0)
	part(corridor, endPf * CF(0, 6.5, 0), V3(9.2, 13, 0.1), C.void, M.SmoothPlastic, {})
	polyline(corridor, endPf, pointedArch(4.6, 7, 13, 8), 0.9, 0.6, C.trim, M.Sandstone, SHADOW, 0.3)
	for _, x in { -4.6, 4.6 } do
		part(corridor, endPf * CF(x, 6.5, 0.3), V3(0.9, 13, 0.6), C.trim, M.Sandstone, SHADOW)
	end
	local endApex = sqrt(7 ^ 2 - (7 - 4.6) ^ 2)
	local ey = 0
	while ey < endApex - 1e-3 do -- the dark arch head above the panel
		local ey1 = min(ey + 0.5, endApex)
		local hw = archHalfWidth(7, 7 - 4.6, (ey + ey1) / 2)
		part(corridor, endPf * CF(0, 13 + (ey + ey1) / 2, 0), V3(2 * max(0.05, hw), ey1 - ey, 0.1), C.void, M.SmoothPlastic, {})
		ey = ey1
	end

	return shell
end

local function buildTrim(shell)
	local trim = model("Trim", shell)
	local CORN = cornice(H)
	-- back wall
	trimRun(trim, -W, 0, W, 0, 0, 0, CORN)
	trimRun(trim, -W, 0, DOOR.x0 - 1.1, 0, 0, 0, WAINSCOT)
	trimRun(trim, DOOR.x1 + 1.1, 0, W, 0, 0, 0, WAINSCOT)
	-- side walls and steps (left side, then mirrored)
	local runs = {
		{ -W, STEPS[1].z, -W, 0, 0, -1 },
		{ -STEPS[1].hw, STEPS[1].z, -W, STEPS[1].z, 1, -1 },
		{ -STEPS[1].hw, STEPS[2].z, -STEPS[1].hw, STEPS[1].z, 0, 0 },
		{ -STEPS[2].hw, STEPS[2].z, -STEPS[1].hw, STEPS[2].z, 1, -1 },
		{ -STEPS[2].hw, STEPS[3].z, -STEPS[2].hw, STEPS[2].z, 0, 0 },
	}
	for _, r in runs do
		trimRun(trim, r[1], r[2], r[3], r[4], r[5], r[6], WAINSCOT)
		trimRun(trim, r[1], r[2], r[3], r[4], r[5], r[6], CORN)
		mirrorRun(trim, r[1], r[2], r[3], r[4], r[5], r[6], WAINSCOT)
		mirrorRun(trim, r[1], r[2], r[3], r[4], r[5], r[6], CORN)
	end
	-- the wall the corridor opens from
	trimRun(trim, STEPS[2].hw, STEPS[3].z, -STEPS[2].hw, STEPS[3].z, -1, -1, CORN)
	trimRun(trim, -CORRIDOR.hw, STEPS[3].z, -STEPS[2].hw, STEPS[3].z, 1, -1, WAINSCOT)
	mirrorRun(trim, -CORRIDOR.hw, STEPS[3].z, -STEPS[2].hw, STEPS[3].z, 1, -1, WAINSCOT)
	-- corridor
	local CCORN = cornice(CORRIDOR.h)
	for _, layers in { WAINSCOT, CCORN } do
		trimRun(trim, -CORRIDOR.hw, CORRIDOR.z1, -CORRIDOR.hw, STEPS[3].z, 0, 0, layers)
		mirrorRun(trim, -CORRIDOR.hw, CORRIDOR.z1, -CORRIDOR.hw, STEPS[3].z, 0, 0, layers)
		trimRun(trim, CORRIDOR.hw, CORRIDOR.z1, -CORRIDOR.hw, CORRIDOR.z1, -1, -1, layers)
	end
	-- pointed arch around the corridor mouth
	local mouth = CF(0, 0, STEPS[3].z) * ANG(0, PI, 0)
	local ma, mR, mSpring = CORRIDOR.hw + 0.6, 12, CORRIDOR.h - 6
	local mcx = mR - ma
	polyline(trim, mouth, pointedArch(ma, mR, mSpring, 10), 1.2, 1.0, C.trim, M.Sandstone, SHADOW, 0.5)
	for _, x in { -ma, ma } do
		part(trim, mouth * CF(x, mSpring / 2, 0.5), V3(1.2, mSpring, 1.0), C.trim, M.Sandstone, SHADOW)
	end
	local my, mApex = CORRIDOR.h - mSpring, sqrt(mR * mR - mcx * mcx)
	while my < mApex - 1e-3 do -- a darker panel in the arch head, above the opening
		local my1 = min(my + 0.5, mApex)
		local hw = archHalfWidth(mR, mcx, (my + my1) / 2)
		part(trim, mouth * CF(0, mSpring + (my + my1) / 2, 0.06), V3(2 * max(0.05, hw), my1 - my, 0.12), C.wallShade, M.Plaster, {})
		my = my1
	end

	-- pilasters with blind pointed arches between them on the long side walls
	for side = -1, 1, 2 do
		local pf = side < 0 and wallPlane(-W, STEPS[1].z, -W, 0) or wallPlane(W, 0, W, STEPS[1].z)
		local function s(z) -- distance along the wall for a room z
			return side < 0 and (STEPS[1].z - z) or z
		end
		for _, z in PILASTERS do
			part(trim, pf * CF(s(z), 0 + 1.6, 0.7), V3(4.2, 3.2, 1.4), C.trimDark, M.Sandstone, SHADOW)
			part(trim, pf * CF(s(z), (3.2 + H - 4) / 2, 0.5), V3(3.2, H - 4 - 3.2, 1.0), C.trim, M.Sandstone, SHADOW)
			part(trim, pf * CF(s(z), H - 4 + 0.8, 0.75), V3(4.2, 1.6, 1.5), C.trimDark, M.Sandstone, SHADOW)
		end
		for i = 1, #PILASTERS - 1 do
			local zc = (PILASTERS[i] + PILASTERS[i + 1]) / 2
			local apf = pf * CF(s(zc), 0, 0)
			local a, R, springY = 8.2, 14, 27
			local cx = R - a
			-- a slightly darker recessed panel
			part(trim, apf * CF(0, (3.15 + springY) / 2, 0.06), V3(2 * a, springY - 3.15, 0.12), C.wallShade, M.Plaster, {})
			local ah = sqrt(R * R - cx * cx)
			local yy = 0
			while yy < ah - 1e-3 do
				local y1 = min(yy + 0.5, ah)
				local hw = archHalfWidth(R, cx, (yy + y1) / 2)
				part(trim, apf * CF(0, springY + (yy + y1) / 2, 0.06), V3(2 * max(0.05, hw), y1 - yy, 0.12), C.wallShade, M.Plaster, {})
				yy = y1
			end
			polyline(trim, apf, pointedArch(a, R, springY, 10), 0.7, 0.5, C.trim, M.Sandstone, {}, 0.25)
			for _, x in { -a, a } do
				part(trim, apf * CF(x, (3.15 + springY) / 2, 0.25), V3(0.7, springY - 3.15, 0.5), C.trim, M.Sandstone, {})
			end
		end
	end
end

local function buildTiles(room)
	local tiles = model("TileFloor", room)
	block(tiles, -W, 0, 0, W, 0.12, 10.5, C.grout, M.Slate, SOLID)
	local size, gap = 3.5, 0.14
	for ix = 0, 23 do
		for iz = 0, 2 do
			local col = ((ix + iz) % 2 == 0) and C.tileA or C.tileB
			part(tiles, CF(-W + (ix + 0.5) * size, 0.17, (iz + 0.5) * size), V3(size - gap, 0.12, size - gap), jitter(col, 0.05), M.Slate, {})
		end
	end
end

--------------------------------------------------------------------------------
-- The window: a pointed arch of pale glass with the Delta Rune in amber
--------------------------------------------------------------------------------

local function buildWindow(room)
	local win = model("Window", room)
	local pf = CF(WIN.x, WIN.y0, 0) -- x across the window, y up from the sill, z into the room
	local a, R, spring = WIN.a, WIN.R, WIN.spring
	local GLASS_P = {}
	local LEAD_P = { CastShadow = true }

	-- glass
	local glass = part(win, pf * CF(0, spring / 2, -2), V3(2 * a, spring, 0.2), C.glass, M.Neon, merge(GLASS_P, { Name = "Glass" }))
	local yy = 0
	while yy < WIN.h - 1e-3 do
		local y1 = min(yy + 0.3, WIN.h)
		local hw = archHalfWidth(R, WIN.cx, yy)
		part(win, pf * CF(0, spring + (yy + y1) / 2, -2), V3(2 * max(0.05, hw), y1 - yy, 0.2), C.glass, M.Neon, GLASS_P)
		yy = y1
	end
	-- the narrow outer lights are a warmer tint
	for side = -1, 1, 2 do
		part(win, pf * CF(side * (a + 6.2) / 2, 7.25, -1.84), V3(a - 6.2, 14.5, 0.12), C.glassWarm, M.Neon, GLASS_P)
	end

	-- frame and hood molding
	local arch = pointedArch(a, R, spring, 16)
	polyline(win, pf, arch, 1.5, T + 0.6, C.frame, M.Sandstone, SHADOW, -T / 2 + 0.3)
	for _, x in { -a, a } do
		part(win, pf * CF(x, spring / 2, -T / 2 + 0.3), V3(1.5, spring, T + 0.6), C.frame, M.Sandstone, SHADOW)
	end
	polyline(win, pf, pointedArch(a + 1.5, R + 1.5, spring, 16), 0.8, 0.7, C.trim, M.Sandstone, SHADOW, 0.35)
	for _, x in { -a - 1.5, a + 1.5 } do
		part(win, pf * CF(x, spring - 1, 0.35), V3(1.4, 1.6, 0.9), C.trimDark, M.Sandstone, SHADOW)
	end
	part(win, pf * CF(0, -0.35, -0.5), V3(2 * a + 3.2, 0.9, 3.6), C.trim, M.Sandstone, SOLID)
	part(win, pf * CF(0, -1.1, 0.2), V3(2 * a + 2.4, 0.7, 1.2), C.trimDark, M.Sandstone, SHADOW)

	-- lead lines (these cast the window's pattern onto the floor)
	local LZ = -1.75
	local function lead(x0, y0, x1, y1)
		polyline(win, pf, { { x0, y0 }, { x1, y1 } }, 0.32, 0.3, C.lead, M.Metal, LEAD_P, LZ)
	end
	lead(-a, 14.5, a, 14.5) -- transom
	for _, x in { -6.2, 6.2 } do
		lead(x, 0, x, 14.5)
	end
	for _, yb in { 3.6, 7.2, 10.8 } do
		lead(-a, yb, -6.2, yb)
		lead(6.2, yb, a, yb)
	end

	-- Delta Rune: a winged circle above three triangles
	local function amberTri(p1, p2, p3, color)
		triangle(win, pf * V3(p1[1], p1[2], -1.86), pf * V3(p2[1], p2[2], -1.86), pf * V3(p3[1], p3[2], -1.86), color or C.amber, M.Neon, 0.12, {})
		lead(p1[1], p1[2], p2[1], p2[2])
		lead(p2[1], p2[2], p3[1], p3[2])
		lead(p3[1], p3[2], p1[1], p1[2])
	end
	local s, hgt = 4.2, 4.2 * 0.866
	for _, cx in { -2.6, 2.6 } do
		local cy = 9.4
		amberTri({ cx - s / 2, cy - hgt / 3 }, { cx + s / 2, cy - hgt / 3 }, { cx, cy + hgt * 2 / 3 })
	end
	amberTri({ -s / 2, 5.4 + hgt / 3 }, { s / 2, 5.4 + hgt / 3 }, { 0, 5.4 - hgt * 2 / 3 })

	local cy = 21.5
	plate(win, pf * CF(0, cy, -1.87), 5.0, 0.12, C.amberCore, M.Neon, {})
	local ring = {}
	for i = 0, 20 do
		local t = i / 20 * TAU
		table.insert(ring, { cos(t) * 2.6, cy + sin(t) * 2.6 })
	end
	polyline(win, pf, ring, 0.34, 0.3, C.lead, M.Metal, LEAD_P, LZ)
	-- each wing: an arched top edge, then four feather tips back toward the circle
	-- left wing outline (the right one is mirrored): top edge, tip, then three notches between
	-- four feathers, back to the circle
	local wing = {
		{ -2.4, 22.3 }, { -4.2, 23.1 }, { -6.2, 23.0 }, { -7.9, 21.9 }, { -6.6, 20.9 }, { -7.4, 19.4 },
		{ -5.6, 19.3 }, { -6.0, 17.6 }, { -4.3, 18.3 }, { -4.0, 16.6 }, { -2.1, 19.8 },
	}
	local hub = { -3.6, 20.6 } -- every edge of the outline is visible from here, so it can be a fan
	for _, side in { 1, -1 } do
		local outline = {}
		for i, q in wing do
			outline[i] = { q[1] * side, q[2] }
		end
		for i = 1, #outline - 1 do
			local q0, q1 = outline[i], outline[i + 1]
			triangle(win, pf * V3(hub[1] * side, hub[2], -1.86), pf * V3(q0[1], q0[2], -1.86), pf * V3(q1[1], q1[2], -1.86), C.amber, M.Neon, 0.12, {})
		end
		polyline(win, pf, outline, 0.3, 0.3, C.lead, M.Metal, LEAD_P, LZ)
		for _, notch in { 5, 7, 9 } do -- lines between the feathers
			local y0 = 20.6 - (notch - 7) * 0.25 -- start on the circle's edge
			lead(-side * sqrt(2.6 ^ 2 - (y0 - cy) ^ 2), y0, outline[notch][1], outline[notch][2])
		end
	end
	lead(0, cy + 2.6, 0, WIN.h + spring - 0.3)
	lead(0, cy - 2.6, 0, 14.5)

	return win, glass
end

--------------------------------------------------------------------------------
-- Golden flowers
--------------------------------------------------------------------------------

local CLUSTERS = { -- bright, mounded bunches of flowers (from the original sprite)
	{ x = -15, z = 12, r = 7.5, h = 1.2 },
	{ x = 2, z = 10.5, r = 7, h = 1.1 },
	{ x = 18, z = 14, r = 7, h = 1.1 },
	{ x = 24, z = 28, r = 9.5, h = 1.6 },
	{ x = -26, z = 31, r = 7, h = 0.9 },
	{ x = -30, z = 56, r = 9.5, h = 1.5 },
	{ x = -1, z = 61, r = 14.5, h = 2.2 },
	{ x = 28, z = 54, r = 9, h = 1.5 },
	{ x = -23, z = 84, r = 10, h = 1.6 },
	{ x = 23, z = 86, r = 10, h = 1.6 },
	{ x = -1, z = 97, r = 11, h = 1.7 },
}

local function bedEdge(x, z) -- 1 at the edge of the flower bed, less inside
	local dx, dz = (x - BED.cx) / BED.rx, (z - BED.cz) / BED.rz
	local ang = atan2(dz, dx)
	local wobble = 1 + 0.05 * sin(ang * 5 + 1.3) + 0.035 * sin(ang * 9 + 0.4) + 0.08 * (noise2(x * 0.12 + 40, z * 0.12) - 0.5)
	return sqrt(dx * dx + dz * dz) / wobble
end

local function clearingEdge(x, z) -- 1 at the edge of the dirt clearing around the throne
	local dx, dz = (x - CLEARING.cx) / CLEARING.rx, (z - CLEARING.cz) / CLEARING.rz
	local ang = atan2(dz, dx)
	return sqrt(dx * dx + dz * dz) / (1 + 0.08 * sin(ang * 4 + 2) + 0.12 * (noise2(x * 0.3, z * 0.3 + 17) - 0.5))
end

local function clusterAt(x, z) -- brightness 0..1 and mound height
	local bright, mound = 0, 0
	for _, c in CLUSTERS do
		local d = sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r
		if d < 1 then
			bright = max(bright, smooth((1 - d) / 0.25))
			mound = max(mound, c.h * sqrt(1 - d * d))
		end
	end
	return bright, mound
end

local SOIL_TOP = 0.35
local function foliageTop(x, z)
	local e = bedEdge(x, z)
	local bright, mound = clusterAt(x, z)
	local edge = clamp01((1 - e) / 0.18)
	local h = (0.55 + 0.45 * edge) + mound * edge + 0.3 * noise2(x * 0.35, z * 0.35)
	h *= 0.45 + 0.55 * clamp01((clearingEdge(x, z) - 1) / 0.4)
	return SOIL_TOP + h, bright
end

local PETAL_P = { Shape = CYL }
local function flower(parent, pos, headR, petalColor, centerColor, stemFrom)
	local fcf = CF(pos) * ANG(rr(-0.28, 0.28), rand() * TAU, rr(-0.28, 0.28))
	local d = headR * 1.15
	local cup = rr(0.35, 0.62)
	for i = 0, 4 do
		local pcf = fcf * ANG(0, i * TAU / 5, 0) * CF(0, 0, -headR * 0.5) * ANG(cup, 0, 0) * ANG(0, 0, PI / 2)
		part(parent, pcf, V3(0.07, d, d), jitter(petalColor, 0.04), M.SmoothPlastic, PETAL_P)
	end
	part(parent, fcf * CF(0, 0.05, 0), V3(headR * 0.5, headR * 0.5, headR * 0.5), centerColor, M.SmoothPlastic, BALL_P)
	if stemFrom then
		cylBetween(parent, stemFrom, pos - fcf.UpVector * 0.1, 0.14, C.stem, M.SmoothPlastic)
	end
end

local function leaf(parent, base, yaw, len)
	local cf = CF(base) * ANG(0, yaw, 0) * ANG(rr(0.35, 0.7), 0, 0) * CF(0, 0, -len / 2)
	ellipsoid(parent, cf, V3(len * 0.42, 0.08, len), jitter(C.leaf, 0.1))
end

local function buildFlowerBed(room)
	local bed = model("FlowerBed", room)
	local ground = model("Ground", bed, "Folder")
	local foliage = model("Foliage", bed, "Folder")
	local flowers = model("Flowers", bed, "Folder")

	-- soil: overlapping discs give the bed a soft, uneven outline
	for x = -BED.rx, BED.rx, 5.5 do
		for z = BED.cz - BED.rz, BED.cz + BED.rz, 5.5 do
			local px, pz = x + rr(-1.5, 1.5), z + rr(-1.5, 1.5)
			if bedEdge(px, pz) < 0.9 and clearingEdge(px, pz) > 0.8 then
				disc(ground, CF(px, SOIL_TOP - 0.25 + rr(-0.04, 0.04), pz), rr(8, 10.5), 0.5, jitter(C.soil, 0.06), M.Ground, {})
			end
		end
	end
	for i = 0, 89 do
		local ang = i / 90 * TAU
		local px, pz = BED.cx + cos(ang) * BED.rx, BED.cz + sin(ang) * BED.rz
		local e = bedEdge(px, pz)
		px, pz = BED.cx + cos(ang) * BED.rx * 0.95 / e, BED.cz + sin(ang) * BED.rz * 0.95 / e
		disc(ground, CF(px, SOIL_TOP - 0.27, pz), rr(3.5, 5), 0.5, jitter(C.soil, 0.06), M.Ground, {})
	end

	-- the dirt clearing the throne stands in
	for x = CLEARING.cx - CLEARING.rx, CLEARING.cx + CLEARING.rx, 3.2 do
		for z = CLEARING.cz - CLEARING.rz, CLEARING.cz + CLEARING.rz, 3.2 do
			local px, pz = x + rr(-0.8, 0.8), z + rr(-0.8, 0.8)
			if clearingEdge(px, pz) < 1.0 then
				disc(ground, CF(px, 0.2 + rr(-0.04, 0.04), pz), rr(4.5, 6), 0.5, jitter(C.dirt, 0.06), M.Ground, SOLID)
			end
		end
	end
	for _ = 1, 45 do -- fallen petals on the dirt
		local ang, r = rand() * TAU, sqrt(rand())
		local px, pz = CLEARING.cx + cos(ang) * r * CLEARING.rx * 0.9, CLEARING.cz + sin(ang) * r * CLEARING.rz * 0.9
		disc(flowers, CF(px, 0.47, pz) * ANG(rr(-0.15, 0.15), rand() * TAU, rr(-0.15, 0.15)), rr(0.45, 0.7), 0.05, jitter(C.petalDim, 0.08), M.SmoothPlastic, {})
	end

	-- leafy mounds under the flowers
	for x = -BED.rx, BED.rx, 2.3 do
		for z = BED.cz - BED.rz, BED.cz + BED.rz, 2.3 do
			local px, pz = x + rr(-0.8, 0.8), z + rr(-0.8, 0.8)
			if bedEdge(px, pz) < 0.98 and clearingEdge(px, pz) > 0.97 then
				local top, bright = foliageTop(px, pz)
				local r = rr(1.2, 1.9)
				ball(foliage, V3(px, top - 0.1 - r, pz), 2 * r, jitter(mix(C.foliage, C.foliageBright, bright), 0.1), M.LeafyGrass, {})
			end
		end
	end

	-- flowers on a jittered hex grid; bright clusters are denser, taller and lighter
	local s = CONFIG.FlowerSpacing
	local row = 0
	for z = BED.cz - BED.rz, BED.cz + BED.rz, s * 0.866 do
		row += 1
		for x = -BED.rx + (row % 2) * s * 0.5, BED.rx, s do
			local px, pz = x + rr(-0.3, 0.3) * s, z + rr(-0.3, 0.3) * s
			local e, ce = bedEdge(px, pz), clearingEdge(px, pz)
			if e < 1 and ce > 1.04 then
				local top, bright = foliageTop(px, pz)
				local keep = 0.7 + 0.3 * bright
				if e > 0.9 then
					keep *= 0.75
				end
				if rand() < keep then
					local headR = rr(0.55, 0.72) + (rr(0.66, 0.9) - 0.62) * bright
					local lit = bright
					if rand() < 0.12 then
						lit = min(1, lit + 0.6)
					end
					local petal = mix(mix(C.petalDeep, C.petalDim, rand()), mix(C.petal, C.petalBright, rand()), lit)
					local center = mix(C.centerDim, C.center, lit)
					local pos = V3(px, top + rr(0.05, 0.45), pz)
					local stem = nil
					if e > 0.82 or ce < 1.35 then
						stem = V3(px, SOIL_TOP, pz)
					end
					flower(flowers, pos, headR, petal, center, stem)
				end
			end
		end
	end

	-- a few strays on the grass just outside the bed
	local strays = 0
	local tries = 0
	while strays < 70 and tries < 2000 do
		tries += 1
		local ang = rand() * TAU
		local r = rr(1.0, 1.16)
		local px, pz = BED.cx + cos(ang) * BED.rx * r, BED.cz + sin(ang) * BED.rz * r
		local e = bedEdge(px, pz)
		if e > 1.02 and e < 1.2 and clearingEdge(px, pz) > 1.3 and pz > 11 then
			strays += 1
			local pos = V3(px, rr(0.8, 1.5), pz)
			flower(flowers, pos, rr(0.5, 0.65), mix(C.petalDim, C.petal, rand()), C.center, V3(px, 0, pz))
			leaf(flowers, V3(px, 0.15, pz), rand() * TAU, rr(0.9, 1.3))
			leaf(flowers, V3(px, 0.25, pz), rand() * TAU, rr(0.8, 1.2))
		end
	end

	return bed
end

--------------------------------------------------------------------------------
-- Ivy and bushes
--------------------------------------------------------------------------------

-- A low leafy mound pressed into the wall, with a leaf or two standing off it.
local function ivyLeaf(parent, pf, x, y, scale)
	scale = scale or 1
	local r = rr(0.7, 1.15) * scale
	local z0 = r * rr(-0.25, 0.1)
	local cf = pf * CF(x, y, z0)
	part(parent, cf, V3(2 * r, 2 * r, 2 * r), jitter(pick(C.ivy), 0.08), M.LeafyGrass, BALL_P)
	local leaves = rand() < 0.25 and 2 or 1
	for _ = 1, leaves do
		local lx, ly = rr(-0.6, 0.6) * r, rr(-0.6, 0.6) * r
		local lz = sqrt(max(0, r * r - lx * lx - ly * ly)) - 0.05
		local lcf = cf * CF(lx, ly, lz) * ANG(rr(-0.8, 0.8), rr(-0.8, 0.8), 0)
		plate(parent, lcf, rr(0.9, 1.4) * scale, 0.08, jitter(pick(C.ivyLeaf), 0.1), M.LeafyGrass, {})
	end
	if rand() < 0.06 then
		part(parent, cf * CF(rr(-0.4, 0.4) * r, rr(-0.4, 0.4) * r, r * 0.9), V3(0.4, 0.4, 0.4), C.berry, M.SmoothPlastic, BALL_P)
	end
end

-- Ivy over a rectangle of wall. Denser patches use bigger mounds so they close up.
local function ivyPatch(parent, pf, x0, x1, y0, y1, density)
	local step = 2.0
	local scale = 0.9 + max(0, density - 0.5) * 1.4
	for y = y0 + step * 0.5, y1, step do
		for x = x0 + step * 0.5, x1, step do
			local fx, fy = x + rr(-0.45, 0.45) * step, y + rr(-0.45, 0.45) * step
			if noise2(fx * 0.2 + 7, fy * 0.2) * 0.6 + rand() * 0.4 < density then
				ivyLeaf(parent, pf, fx, fy, scale * rr(0.85, 1.1))
			end
		end
	end
end

local function ivyVine(parent, pf, x, yTop, length)
	local y, cx = yTop, x
	while y > yTop - length and y > 0.6 do
		local taper = 1 - (yTop - y) / length * 0.45
		cx += rr(-0.4, 0.4)
		ivyLeaf(parent, pf, cx, y, taper)
		if rand() < 0.6 then
			ivyLeaf(parent, pf, cx + rr(-1.3, 1.3), y - rr(0, 0.6), taper * 0.8)
		end
		y -= rr(1.1, 1.5)
	end
end

-- Hanging vines along the top of a wall, `every` studs apart on average.
local function ivyFringe(parent, pf, x0, x1, top, every, minLen, maxLen, chance)
	for x = x0, x1, every do
		if rand() < chance then
			local len = minLen + (maxLen - minLen) * noise2(x * 0.15 + 3, top) ^ 1.5
			ivyVine(parent, pf, x + rr(-0.6, 0.6), top - rr(0.4, 1.4), len * rr(0.7, 1.15))
		end
	end
end

local function buildIvy(room)
	local ivy = model("Ivy", room, "Folder")
	local top = H - 2.6

	-- back wall: thick in both corners and over the doorway, like the sprite
	local back = wallPlane(-W, 0, W, 0) -- x here is room x + W
	ivyPatch(ivy, back, 0, 10, 0, top, 0.82)
	ivyPatch(ivy, back, W + 30, 2 * W, 0, top, 0.82)
	ivyPatch(ivy, back, W + DOOR.x0 - 4, W + DOOR.x1 + 3, DOOR.h + 2.2, DOOR.h + 10, 0.78)
	ivyVine(ivy, back, W + DOOR.x0 - 2.6, DOOR.h + 3, DOOR.h + 2)
	ivyVine(ivy, back, W + DOOR.x1 + 2.2, DOOR.h + 4, 18)
	ivyFringe(ivy, back, 10, W + DOOR.x0 - 4, top, 2.4, 4, 18, 0.8)
	ivyFringe(ivy, back, W + DOOR.x1 + 3, W + WIN.x - WIN.a - 3, top, 2.6, 3, 9, 0.7)
	ivyFringe(ivy, back, W + WIN.x + WIN.a + 3, W + 30, top, 2.4, 3, 14, 0.75)

	-- long side walls: heavy at both ends, vines hanging between
	for side = -1, 1, 2 do
		local pf = side < 0 and wallPlane(-W, STEPS[1].z, -W, 0) or wallPlane(W, 0, W, STEPS[1].z)
		local len = STEPS[1].z
		local nearBack0, nearBack1 = side < 0 and len - 10 or 0, side < 0 and len or 10
		local nearFront0, nearFront1 = side < 0 and 0 or len - 11, side < 0 and 11 or len
		ivyPatch(ivy, pf, nearBack0, nearBack1, 0, top, 0.8)
		ivyPatch(ivy, pf, nearFront0, nearFront1, 0, top, 0.62)
		ivyFringe(ivy, pf, 11, len - 11, top, 2.8, 4, 28, 0.62)
		-- ivy creeping up from the floor here and there
		local x = 14
		while x < len - 16 do
			local w = rr(4, 9)
			if rand() < 0.55 then
				ivyPatch(ivy, pf, x, x + w, 0, rr(3, 8), 0.7)
			end
			x += w + rr(5, 12)
		end
	end

	-- the stepped walls by the corridor are mostly green
	local steps = {
		{ -STEPS[1].hw, STEPS[1].z, -W, STEPS[1].z },
		{ -STEPS[1].hw, STEPS[2].z, -STEPS[1].hw, STEPS[1].z },
		{ -STEPS[2].hw, STEPS[2].z, -STEPS[1].hw, STEPS[2].z },
		{ -STEPS[2].hw, STEPS[3].z, -STEPS[2].hw, STEPS[2].z },
		{ -CORRIDOR.hw, STEPS[3].z, -STEPS[2].hw, STEPS[3].z },
	}
	for _, r in steps do
		for side = -1, 1, 2 do
			local pf, len
			if side < 0 then
				pf, len = wallPlane(r[1], r[2], r[3], r[4])
			else
				pf, len = wallPlane(-r[3], r[4], -r[1], r[2])
			end
			ivyPatch(ivy, pf, 0, len, 0, top, 0.8)
			ivyFringe(ivy, pf, 1, len - 1, top, 2.6, 6, 18, 0.7)
		end
	end
	-- over the corridor mouth
	local mouth = wallPlane(CORRIDOR.hw, STEPS[3].z, -CORRIDOR.hw, STEPS[3].z)
	ivyPatch(ivy, mouth, 0, 2 * CORRIDOR.hw, CORRIDOR.h + 5, top, 0.45)
	ivyFringe(ivy, mouth, 1, 2 * CORRIDOR.hw - 1, top, 2.4, 3, 12, 0.7)
	return ivy
end

local function bush(parent, cx, cz, rx, rz, height)
	local b = model("Bush", parent)
	ellipsoid(b, CF(cx, height * 0.35, cz), V3(rx * 1.8, height * 1.4, rz * 1.8), C.bushDark, SHADOW)
	local n = floor(rx * rz * 0.6)
	for _ = 1, n do
		local ang, r = rand() * TAU, sqrt(rand())
		local px, pz = cx + cos(ang) * r * rx, cz + sin(ang) * r * rz
		local top = height * sqrt(max(0, 1 - r * r)) + 0.7
		local br = rr(1.4, 2.3)
		local col = jitter(mix(C.bushDark, C.bush, 0.35 + 0.65 * (1 - r * 0.7)), 0.08)
		ball(b, V3(px, top - br * 0.85, pz), 2 * br, col, M.LeafyGrass, SHADOW)
	end
	return b
end

--------------------------------------------------------------------------------
-- Thrones
--------------------------------------------------------------------------------

local function buildAsgoreThrone(parent)
	local m = model("AsgoreThrone", parent)
	local base = CF(THRONE_POS)
	local function P(x, y, z)
		return base * V3(x, y, z)
	end
	local function tb(x, y, z, sx, sy, sz, color, mat, props)
		return part(m, base * CF(x, y, z), V3(sx, sy, sz), color, mat, props)
	end
	local G, GM = C.gold, M.Metal
	local GOLD_P = { CastShadow = true, Reflectance = 0.06 }
	local GOLD_S = merge(SOLID, { Reflectance = 0.06 })

	-- legs and the posts of the backrest
	for _, sx in { -1, 1 } do
		for _, lz in { -3.9, 3.9 } do
			ball(m, P(sx * 5.55, 0.75, lz), 1.6, G, GM, GOLD_P)
		end
		cylBetween(m, P(sx * 5.55, 0.9, 3.9), P(sx * 5.55, 3.1, 3.9), 1.1, G, GM, GOLD_S)
		disc(m, base * CF(sx * 5.55, 2.0, 3.9), 1.5, 0.35, C.gold, GM, GOLD_P)
		tb(sx * 5.6, 8.6, -3.9, 1.3, 15.8, 1.3, G, GM, GOLD_S)
		ball(m, P(sx * 5.6, 17.1, -3.9), 1.8, G, GM, GOLD_P)
	end
	-- seat
	tb(0, 3.65, 0.2, 12.2, 1.5, 9.2, G, GM, GOLD_S)
	for i = -3, 3 do -- scalloped apron
		plate(m, base * CF(i * 1.55, 2.9, 4.62), 1.3, 0.35, G, GM, GOLD_P)
	end
	plate(m, base * CF(0, 3.65, 4.86), 1.9, 0.2, G, GM, GOLD_P)
	plate(m, base * CF(0, 3.65, 4.98), 1.35, 0.12, C.purple, M.Fabric, {})
	tb(0, 5.15, 0.3, 11.2, 1.5, 8.6, C.lavender, M.Fabric, SOLID)
	cylBetween(m, P(-5.6, 5.1, 4.55), P(5.6, 5.1, 4.55), 1.6, C.lavender, M.Fabric, SHADOW)

	-- backrest: deep purple, tufted, under a golden arch and crown
	tb(0, 11.2, -3.75, 10, 10.6, 0.9, C.purpleDeep, M.Fabric, SOLID)
	plate(m, base * CF(0, 16.5, -3.85), 10.4, 0.8, C.purpleDeep, M.Fabric, SHADOW)
	local arc = {}
	for i = 0, 14 do
		local t = i / 14 * PI
		table.insert(arc, { cos(t) * 5.6, 16.5 + sin(t) * 5.6 })
	end
	polyline(m, base * CF(0, 0, -3.85), arc, 1.1, 1.4, G, GM, GOLD_P)
	tb(0, 6.2, -3.6, 10.4, 0.7, 1.2, G, GM, GOLD_P)
	tb(0, 11.2, -4.35, 10.2, 10.6, 0.3, G, GM, GOLD_P) -- the back of the backrest
	plate(m, base * CF(0, 16.5, -4.35), 10.6, 0.3, G, GM, GOLD_P)

	for row = 0, 2 do -- tufting: buttons with quilted puffs between them
		local y = 7.3 + row * 1.85
		for col = -2, 2 do
			local x = col * 2.0 + (row % 2) * 1.0
			if abs(x) < 4.3 then
				ball(m, P(x, y, -3.22), 0.38, G, GM, {})
			end
			local px, py = x + 1.0, y + 0.92
			if abs(px) < 4.0 and py < 11.6 then
				ellipsoid(m, base * CF(px, py, -3.3), V3(1.9, 1.6, 0.42), C.purple, {})
			end
		end
	end
	-- a small golden Delta Rune on the backrest
	local ez = -3.22
	plate(m, base * CF(0, 14.8, ez), 1.5, 0.14, G, GM, {})
	for _, side in { -1, 1 } do
		triangle(m, P(side * 0.7, 15.15, ez), P(side * 0.75, 14.55, ez), P(side * 2.6, 15.35, ez), G, GM, 0.14, {})
		triangle(m, P(side * 0.7, 14.5, ez), P(side * 0.45, 14.15, ez), P(side * 2.2, 13.9, ez), G, GM, 0.14, {})
	end
	local ts, th = 1.1, 1.1 * 0.866
	for _, cx in { -0.72, 0.72 } do
		triangle(m, P(cx - ts / 2, 12.9, ez), P(cx + ts / 2, 12.9, ez), P(cx, 12.9 + th, ez), G, GM, 0.14, {})
	end
	triangle(m, P(-ts / 2, 12.65, ez), P(ts / 2, 12.65, ez), P(0, 12.65 - th, ez), G, GM, 0.14, {})

	-- crown on top
	tb(0, 22.9, -3.85, 4.4, 1.1, 1.2, G, GM, GOLD_P)
	local cz = -3.85
	local points = {
		{ { -2.2, 23.4 }, { -0.9, 23.4 }, { -1.75, 25.3 } },
		{ { -0.8, 23.4 }, { 0.8, 23.4 }, { 0, 26.1 } },
		{ { 0.9, 23.4 }, { 2.2, 23.4 }, { 1.75, 25.3 } },
	}
	for _, p in points do
		triangle(m, P(p[1][1], p[1][2], cz), P(p[2][1], p[2][2], cz), P(p[3][1], p[3][2], cz), G, GM, 0.7, GOLD_P)
		ball(m, P(p[3][1], p[3][2], cz), 0.6, G, GM, {})
	end
	ball(m, P(0, 22.9, -3.2), 0.6, C.lavender, M.Glass, {})

	-- armrests
	for _, sx in { -1, 1 } do
		tb(sx * 5.75, 8.7, 0.15, 1.1, 0.9, 8.3, G, GM, GOLD_S)
		tb(sx * 5.75, 9.35, 0.4, 1.3, 0.45, 6.6, C.lavender, M.Fabric, SHADOW)
		cylBetween(m, P(sx * 5.75, 5.9, 3.95), P(sx * 5.75, 8.3, 3.95), 1.0, G, GM, GOLD_P)
		part(m, base * CF(sx * 5.75, 8.7, 4.4), V3(1.3, 1.5, 1.5), G, GM, merge(GOLD_P, CYL_P))
		part(m, base * CF(sx * 6.42, 8.7, 4.4), V3(0.12, 0.9, 0.9), C.purple, M.Fabric, CYL_P)
		tb(sx * 5.85, 7.1, 0.1, 0.35, 2.4, 7.4, C.purpleDeep, M.Fabric, SHADOW)
	end
	return m
end

local function buildCoveredThrone(parent)
	local m = model("CoveredThrone", parent)
	local base = CF(COVERED_POS) * ANG(0, rad(-8), 0)
	local function P(x, y, z)
		return base * V3(x, y, z)
	end
	local function sb(x, y, z, sx, sy, sz, props)
		return part(m, base * CF(x, y, z), V3(sx, sy, sz), C.sheet, M.Fabric, props or SOLID)
	end

	-- golden feet showing under the dust sheet
	for _, sx in { -1, 1 } do
		for _, lz in { -3.3, 3.3 } do
			cylBetween(m, P(sx * 4.5, 0.6, lz), P(sx * 4.5, 1.7, lz), 0.8, C.gold, M.Metal, SHADOW)
			ball(m, P(sx * 4.5, 0.45, lz), 1.1, C.gold, M.Metal, SHADOW)
		end
	end
	-- the sheet over the seat, flaring out a little toward the floor
	sb(0, 3.5, 0.3, 10.6, 4.2, 8.4)
	part(m, base * CF(0, 3.25, 4.6) * ANG(rad(-6), 0, 0), V3(11.2, 4.3, 0.3), C.sheet, M.Fabric, SHADOW)
	for _, sx in { -1, 1 } do
		part(m, base * CF(sx * 5.45, 3.25, 0.3) * ANG(0, 0, sx * rad(6)), V3(0.3, 4.3, 9.0), C.sheet, M.Fabric, SHADOW)
	end
	-- the backrest, its top and finials softened by the cloth
	sb(0, 11.6, -3.0, 10.2, 12.4, 2.4)
	for _, sx in { -1, 1 } do
		ball(m, P(sx * 4.9, 17.6, -3.0), 2.6, C.sheet, M.Fabric, SHADOW)
	end
	cylBetween(m, P(-4.9, 17.9, -3.0), P(4.9, 17.9, -3.0), 2.2, C.sheet, M.Fabric, SHADOW)
	part(m, base * CF(0, 9.3, -4.45) * ANG(rad(3), 0, 0), V3(11.0, 17.6, 0.3), C.sheet, M.Fabric, SHADOW)
	for _, sx in { -1, 1 } do
		triangle(m, P(sx * 5.3, 18.2, -2.9), P(sx * 5.5, 5.6, -4.3), P(sx * 5.6, 5.6, 3.8), C.sheet, M.Fabric, 0.3, SHADOW)
	end
	-- creases
	for i = 1, 5 do -- soft folds hanging down the front of the backrest
		local x = -4 + (i - 1) * 2 + rr(-0.4, 0.4)
		ellipsoid(m, base * CF(x, rr(10, 12.5), -1.8) * ANG(0, 0, rr(-0.15, 0.15)), V3(1.1, rr(6, 9), 0.4), C.sheetShade)
	end
	for i = 1, 6 do
		local x = -4.6 + (i - 1) * 1.84 + rr(-0.3, 0.3)
		ellipsoid(m, base * CF(x, 3.1, 4.7) * ANG(rad(-6), 0, rr(-0.12, 0.12)), V3(0.9, rr(3.4, 4.2), 0.4), C.sheetShade)
	end
	for _ = 1, 4 do
		ellipsoid(m, base * CF(rr(-3.5, 3.5), 5.62, rr(-0.5, 3.5)) * ANG(0, rand() * PI, 0), V3(rr(3, 6), 0.3, 0.5), C.sheetShade)
	end
	for _, sx in { -1, 1 } do
		for _ = 1, 3 do
			ellipsoid(m, base * CF(sx * 5.6, 3.2, rr(-3.5, 4)) * ANG(0, 0, sx * rad(6)), V3(0.4, rr(3.4, 4.2), 0.9), C.sheetShade)
		end
	end
	return m
end

--------------------------------------------------------------------------------
-- Save point
--------------------------------------------------------------------------------

local function buildSavePoint(parent)
	local m = model("SavePoint", parent)
	local core = part(m, CF(SAVE_POS), V3(1, 1, 1), C.star, M.Neon, { Name = "Core", Transparency = 1 })
	m.PrimaryPart = core

	for _, yaw in { 0, PI / 2 } do
		local pf = CF(SAVE_POS) * ANG(0, yaw, 0)
		local pts = {}
		for i = 0, 7 do
			local ang = i * PI / 4
			local r
			if i % 2 == 1 then
				r = 0.34
			elseif i % 4 == 0 then
				r = 1.05
			else
				r = 1.45
			end
			table.insert(pts, pf * V3(cos(ang) * r, sin(ang) * r, 0))
		end
		local center = pf * V3(0, 0, 0)
		for i = 1, 8 do
			triangle(m, center, pts[i], pts[i % 8 + 1], C.star, M.Neon, 0.16, {})
		end
	end

	local light = Instance.new("PointLight")
	light.Color = RGB(255, 222, 110)
	light.Range = 10
	light.Brightness = 2.2
	light.Parent = core

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(RGB(255, 236, 120))
	sparkle.LightEmission = 1
	sparkle.Rate = 3
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Speed = NumberRange.new(0.4, 1.1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SavePrompt"
	prompt.ActionText = "Save"
	prompt.ObjectText = "SAVE"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	return m
end

--------------------------------------------------------------------------------
-- Lights, light shafts, dust
--------------------------------------------------------------------------------

local function lightPart(parent, name, cf)
	return part(parent, cf, V3(0.4, 0.4, 0.4), C.light, M.SmoothPlastic, { Name = name, Transparency = 1 })
end

local function buildLights(room, glass)
	local rig = model("LightRig", room)

	-- sunlight through the window, as spotlights just outside the glass
	for i, y in { 12, 24 } do
		local pos = V3(WIN.x, WIN.y0 + y, -3.2)
		local holder = lightPart(rig, "WindowSun" .. i, CFrame.lookAt(pos, pos + LIGHT_DIR))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Color = RGB(255, 196, 120)
		spot.Brightness = 7
		spot.Range = 60
		spot.Angle = 55
		spot.Shadows = true
		spot.Parent = holder
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color = RGB(255, 214, 150)
	glow.Brightness = 2.2
	glow.Range = 40
	glow.Angle = 80
	glow.Shadows = true
	glow.Parent = glass

	-- warm fill from the ceiling, standing in for light bouncing off the gold walls
	for _, z in { 22, 62, 102 } do
		local holder = part(rig, CF(0, H - 2.7, z), V3(70, 0.2, 36), C.light, M.SmoothPlastic, { Name = "CeilingFill", Transparency = 1 })
		local fill = Instance.new("SurfaceLight")
		fill.Face = Enum.NormalId.Bottom
		fill.Color = RGB(255, 210, 150)
		fill.Brightness = 0.75
		fill.Range = 56
		fill.Angle = 90
		fill.Shadows = false
		fill.Parent = holder
	end

	-- soft light shafts: camera-facing beams from the window to where its light lands
	local shafts = lightPart(rig, "LightShafts", CF(0, 0, 0))
	local function shaft(x, y, w0, w1, alpha)
		local from = V3(WIN.x + x, WIN.y0 + y, -1.2)
		local to = from + LIGHT_DIR * ((from.Y - 0.5) / -LIGHT_DIR.Y)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = from, to
		a0.Parent, a1.Parent = shafts, shafts
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.FaceCamera = true
		beam.Width0, beam.Width1 = w0, w1
		beam.Color = ColorSequence.new(RGB(255, 222, 156))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 4
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - alpha * 0.6),
			NumberSequenceKeypoint.new(0.15, 1 - alpha),
			NumberSequenceKeypoint.new(0.75, 1 - alpha * 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = shafts
	end
	shaft(0, 16, 18, 26, 0.07)
	shaft(-3, 10, 8, 12, 0.08)
	shaft(3, 20, 8, 12, 0.08)
	shaft(0, 26, 6, 10, 0.07)
	shaft(-4, 22, 4, 7, 0.06)
	shaft(4, 6, 4, 7, 0.06)

	-- dust drifting in the light
	local mid = V3(WIN.x, WIN.y0 + 16, 0) + LIGHT_DIR * 22
	local dustBox = part(rig, CF(mid), V3(18, 22, 30), C.light, M.SmoothPlastic, { Name = "Dust", Transparency = 1 })
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "DustMotes"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = ColorSequence.new(RGB(255, 236, 190))
	dust.LightEmission = 1
	dust.Rate = 14
	dust.Lifetime = NumberRange.new(7, 12)
	dust.Speed = NumberRange.new(0.1, 0.35)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = V3(0, -0.02, 0)
	dust.Size = NumberSequence.new(0.12)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trySet(dust, "Shape", Enum.ParticleEmitterShape.Box)
	trySet(dust, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Volume)
	dust.Parent = dustBox
	return rig
end

--------------------------------------------------------------------------------
-- Lighting preset and scripts
--------------------------------------------------------------------------------

local LIGHTING = {
	Ambient = RGB(92, 72, 50),
	OutdoorAmbient = RGB(150, 118, 82),
	Brightness = 2.8,
	ColorShift_Top = RGB(255, 206, 140),
	ColorShift_Bottom = RGB(70, 46, 24),
	EnvironmentDiffuseScale = 0.55,
	EnvironmentSpecularScale = 0.45,
	ExposureCompensation = 0.15,
	ShadowSoftness = 0.25,
	GlobalShadows = true,
	ClockTime = 16.6,
	GeographicLatitude = 28,
}

local function buildLightingPreset(room)
	local preset = Instance.new("Folder")
	preset.Name = "LightingPreset"
	for name, value in LIGHTING do
		preset:SetAttribute(name, value)
	end
	preset:SetAttribute("SunToward", ORIGIN:VectorToWorldSpace(SUN_TOWARD))

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = RGB(255, 214, 156)
	atmosphere.Decay = RGB(196, 136, 76)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.4
	atmosphere.Parent = preset

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.3
	bloom.Parent = preset

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Brightness = 0.02
	grade.Contrast = 0.1
	grade.Saturation = 0.12
	grade.TintColor = RGB(255, 245, 228)
	grade.Parent = preset

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.55
	rays.Parent = preset

	preset.Parent = room
	return preset
end

-- Pick ClockTime and GeographicLatitude so the sun shines from `toward`. Only works where
-- Lighting:GetSunDirection exists (Studio and live games).
local function aimSun(lighting, toward)
	local ok = pcall(function()
		return lighting:GetSunDirection()
	end)
	if not ok then
		return false
	end
	local t0, l0 = lighting.ClockTime, lighting.GeographicLatitude
	lighting.GeographicLatitude = 0
	lighting.ClockTime = 12
	local noon = lighting:GetSunDirection()
	lighting.ClockTime = 9
	if (lighting:GetSunDirection() - noon).Magnitude < 1e-3 then
		lighting.ClockTime, lighting.GeographicLatitude = t0, l0
		return false
	end
	local sign = noon.Y >= 0 and 1 or -1
	local best, bestT, bestL = -2, t0, l0
	local function try(t, l)
		lighting.ClockTime, lighting.GeographicLatitude = t, l
		local score = (lighting:GetSunDirection() * sign):Dot(toward)
		if score > best then
			best, bestT, bestL = score, t, l
		end
	end
	for l = -85, 85, 5 do
		for t = 4, 20, 0.25 do
			try(t, l)
		end
	end
	local ct, cl = bestT, bestL
	for l = cl - 5, cl + 5, 0.5 do
		for t = ct - 0.25, ct + 0.25, 0.02 do
			try(t, l)
		end
	end
	lighting.ClockTime, lighting.GeographicLatitude = bestT, bestL
	return true
end

local function applyLighting(preset)
	local lighting = game:GetService("Lighting")
	for name, value in preset:GetAttributes() do
		if name ~= "SunToward" then
			trySet(lighting, name, value)
		end
	end
	for _, effect in preset:GetChildren() do
		for _, old in lighting:GetChildren() do
			if old.ClassName == effect.ClassName then
				old:Destroy()
			end
		end
		effect:Clone().Parent = lighting
	end
	local futureOk = pcall(function()
		lighting.Technology = Enum.Technology.Future
	end)
	if not futureOk then
		print("[ThroneRoom] Set Lighting.Technology to Future in the Properties window for the full look.")
	end
	aimSun(lighting, preset:GetAttribute("SunToward"))
end

local SERVER_SOURCE = [==[
-- ThroneRoomServer: applies the room's lighting when the game starts (so the model also
-- looks right when inserted into another place), aims the sun through the window, and
-- makes the save point restore health.
local Lighting = game:GetService("Lighting")
local room = script.Parent

local function aimSun(toward)
	local t0, l0 = Lighting.ClockTime, Lighting.GeographicLatitude
	Lighting.GeographicLatitude = 0
	Lighting.ClockTime = 12
	local noon = Lighting:GetSunDirection()
	Lighting.ClockTime = 9
	if (Lighting:GetSunDirection() - noon).Magnitude < 1e-3 then
		Lighting.ClockTime, Lighting.GeographicLatitude = t0, l0
		return
	end
	local sign = noon.Y >= 0 and 1 or -1
	local best, bestT, bestL = -2, t0, l0
	local function try(t, l)
		Lighting.ClockTime, Lighting.GeographicLatitude = t, l
		local score = (Lighting:GetSunDirection() * sign):Dot(toward)
		if score > best then
			best, bestT, bestL = score, t, l
		end
	end
	for l = -85, 85, 5 do
		for t = 4, 20, 0.25 do
			try(t, l)
		end
	end
	local ct, cl = bestT, bestL
	for l = cl - 5, cl + 5, 0.5 do
		for t = ct - 0.25, ct + 0.25, 0.02 do
			try(t, l)
		end
	end
	Lighting.ClockTime, Lighting.GeographicLatitude = bestT, bestL
end

local preset = room:FindFirstChild("LightingPreset")
if preset and room:GetAttribute("ApplyLighting") ~= false then
	for name, value in preset:GetAttributes() do
		if name ~= "SunToward" then
			pcall(function()
				Lighting[name] = value
			end)
		end
	end
	for _, effect in preset:GetChildren() do
		for _, old in Lighting:GetChildren() do
			if old.ClassName == effect.ClassName then
				old:Destroy()
			end
		end
		effect:Clone().Parent = Lighting
	end
	local toward = preset:GetAttribute("SunToward")
	if typeof(toward) == "Vector3" then
		pcall(aimSun, toward.Unit)
	end
end

local prompt = room:FindFirstChild("SavePrompt", true)
if prompt then
	prompt.Triggered:Connect(function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end
]==]

local CLIENT_SOURCE = [==[
-- ThroneRoomFX (runs on each player's client): spins the save point and shows an
-- Undertale-style text box when the player saves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local room = script.Parent
local savePoint = room:WaitForChild("SavePoint")
local core = savePoint:WaitForChild("Core")
local prompt = core:WaitForChild("SavePrompt")
local glow = core:FindFirstChildOfClass("PointLight")
local player = Players.LocalPlayer

local rest = savePoint:GetPivot()
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	savePoint:PivotTo(rest * CFrame.new(0, math.sin(clock * 1.7) * 0.25, 0) * CFrame.Angles(0, clock * 1.3, 0))
	if glow then
		glow.Brightness = 2.2 + math.sin(clock * 3.1) * 0.5
	end
end)

local LINES = {
	"* (The golden flowers sway in the light from the window.)",
	"* (You are filled with DETERMINATION.)",
	"* HP fully restored.",
}

local talking = false
local function say(lines)
	if talking then
		return
	end
	talking = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaveDialog"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -28)
	box.Size = UDim2.new(0.92, 0, 0, 140)
	box.BackgroundColor3 = Color3.new(0, 0, 0)
	box.BorderSizePixel = 0
	box.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(820, 140)
	limit.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(26, 20)
	label.Size = UDim2.new(1, -52, 1, -40)
	label.Font = Enum.Font.Arcade
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 28
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = box

	gui.Parent = player:WaitForChild("PlayerGui")
	for _, line in lines do
		label.Text = line
		label.MaxVisibleGraphemes = 0
		for i = 1, utf8.len(line) or #line do
			label.MaxVisibleGraphemes = i
			task.wait(0.03)
		end
		task.wait(1.6)
	end
	gui:Destroy()
	talking = false
end

prompt.Triggered:Connect(function(who)
	if who == player then
		task.spawn(say, LINES)
	end
end)

-- Optional music: set the AsgoreThroneRoom model's MusicId attribute to an audio id.
local musicId = room:GetAttribute("MusicId")
local digits = typeof(musicId) == "string" and musicId:match("%d+")
if digits then
	local music = Instance.new("Sound")
	music.Name = "ThroneRoomMusic"
	music.SoundId = "rbxassetid://" .. digits
	music.Looped = true
	music.Volume = 0.5
	music.Parent = SoundService
	music:Play()
end
]==]

local function addScript(room, name, source, runContext)
	local s = Instance.new("Script")
	s.Name = name
	local ok = pcall(function()
		s.Source = source
		s.RunContext = runContext
	end)
	if not ok then
		s:Destroy()
		return nil
	end
	s.Parent = room
	return s
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function build()
	local startClock = os.clock()
	if CONFIG.ReplaceExisting then
		local old = workspace:FindFirstChild("AsgoreThroneRoom")
		if old then
			old:Destroy()
		end
	end

	local room = Instance.new("Model")
	room.Name = "AsgoreThroneRoom"
	room:SetAttribute("ApplyLighting", CONFIG.ApplyLighting)
	room:SetAttribute("MusicId", CONFIG.MusicId)

	local shell = buildShell(room)
	buildTrim(shell)
	buildTiles(room)
	local _, glass = buildWindow(room)
	buildFlowerBed(room)
	buildIvy(room)
	local bushes = model("Bushes", room)
	bush(bushes, -28, 116.5, 8.5, 7.5, 4.2)
	bush(bushes, 27, 116.5, 8.5, 7.5, 4.2)
	bush(bushes, 0, 128, 11.5, 8.5, 5)
	local thrones = model("Thrones", room)
	buildAsgoreThrone(thrones)
	buildCoveredThrone(thrones)
	buildSavePoint(room)
	buildLights(room, glass)
	local preset = buildLightingPreset(room)

	local spawn = part(room, CF(SPAWN_POS + V3(0, -0.45, 0)), V3(8, 1, 8), C.path, M.Slate, {
		Class = "SpawnLocation",
		Name = "SpawnLocation",
		Transparency = 1,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		Neutral = true,
		Duration = 0,
	})
	spawn.Enabled = true

	local serverScript = addScript(room, "ThroneRoomServer", SERVER_SOURCE, Enum.RunContext.Server)
	local clientScript = addScript(room, "ThroneRoomFX", CLIENT_SOURCE, Enum.RunContext.Client)
	if not (serverScript and clientScript) then
		print("[ThroneRoom] Couldn't add the save point scripts from here (a running game can't).")
	end

	room.WorldPivot = ORIGIN
	room.Parent = workspace

	if CONFIG.ApplyLighting then
		applyLighting(preset)
	end
	if not serverScript and canYield then
		-- running as a server Script: the save point still restores health
		local prompt = room:FindFirstChild("SavePrompt", true)
		prompt.Triggered:Connect(function(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end

	local camera = workspace.CurrentCamera
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = workspace
		workspace.CurrentCamera = camera
	end
	if IS_LUNE or (CONFIG.MoveCamera and not canYield) then
		local eye = ORIGIN * V3(-6, 20, 132)
		camera.CFrame = CFrame.lookAt(eye, ORIGIN * V3(2, 9, 24))
		trySet(camera, "Focus", CFrame.new(ORIGIN * V3(0, 6, 30)))
	end

	print(string.format("[ThroneRoom] Built Asgore's throne room: %d parts in %.1fs.", partCount, os.clock() - startClock))
	return room
end

return build()
