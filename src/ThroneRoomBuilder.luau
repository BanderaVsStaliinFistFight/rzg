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

	Textures: the PBR textures in textures/ make the room look far more realistic, but
	Roblox only shows images that have been uploaded. Run tools/upload_textures.py once (it
	fills in TEXTURE_IDS below), or paste ids from Studio's Asset Manager by hand. Until
	then every surface uses Roblox's built-in materials.

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
	FlowerSpacing = 1.55, -- smaller means more flowers (and more parts)
	ApplyLighting = true, -- set Lighting and post effects for the room
	MoveCamera = true, -- command bar only: frame the room after building
	ReplaceExisting = true, -- delete an earlier AsgoreThroneRoom in Workspace first
	MusicId = "", -- optional: the numeric id of an audio asset you are allowed to use
	TerrainGrass = true, -- grow terrain grass on the green floor (Studio and live games)
}

-- Uploaded texture ids (numbers or rbxassetid:// links). tools/upload_textures.py writes
-- them between the BEGIN and END lines. Empty ones fall back to built-in materials.
-- BEGIN TEXTURE IDS
local TEXTURE_IDS = {
	glass_card = "",
	gold_color = "",
	gold_metalness = "",
	gold_normal = "",
	gold_roughness = "",
	grass_card = "",
	grass_color = "",
	grass_normal = "",
	grass_roughness = "",
	grime_card = "",
	ivy_card = "",
	leaves_color = "",
	leaves_normal = "",
	leaves_roughness = "",
	limestone_color = "",
	limestone_normal = "",
	limestone_roughness = "",
	linen_color = "",
	linen_normal = "",
	linen_roughness = "",
	plaster_color = "",
	plaster_normal = "",
	plaster_roughness = "",
	sandstone_color = "",
	sandstone_normal = "",
	sandstone_roughness = "",
	soil_color = "",
	soil_normal = "",
	soil_roughness = "",
	tallgrass_card = "",
	terracotta_color = "",
	terracotta_normal = "",
	terracotta_roughness = "",
	velvet_color = "",
	velvet_normal = "",
	velvet_roughness = "",
	wood_color = "",
	wood_normal = "",
	wood_roughness = "",
	woodplanks_color = "",
	woodplanks_normal = "",
	woodplanks_roughness = "",
}
-- END TEXTURE IDS

local IS_LUNE = __LUNE == true -- set by tools/build.luau
if __PREVIEW_TEXTURES then -- tools/build.luau --preview: stand-in ids for the preview renderer
	for name, id in __PREVIEW_TEXTURES do
		TEXTURE_IDS[name] = id
	end
end

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
	center = RGB(214, 178, 34), -- a small boss of yellow stamens
	centerDim = RGB(170, 140, 28),
	stem = RGB(70, 108, 34),
	leaf = RGB(62, 112, 40),
	pistil = RGB(150, 166, 44), -- the green knot at the heart of a buttercup
	blade = { RGB(58, 104, 40), RGB(74, 120, 46), RGB(46, 88, 36), RGB(92, 132, 52), RGB(128, 134, 66) },
	ivy = { RGB(30, 76, 46), RGB(38, 92, 52), RGB(26, 62, 40), RGB(50, 104, 56), RGB(42, 84, 38) },
	ivyLeaf = { RGB(52, 112, 58), RGB(66, 126, 62), RGB(44, 98, 50), RGB(78, 134, 60) },
	berry = RGB(234, 152, 38),
	bush = RGB(70, 140, 76),
	bushDark = RGB(40, 98, 56),
	gold = RGB(222, 172, 58),
	goldDeep = RGB(186, 136, 46),
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

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------

-- Each texture set in textures/ becomes a MaterialVariant of a built-in material.
-- `tile` is how many studs one copy of the texture covers.
local MATERIAL_SETS = {
	plaster = { base = M.Plaster, tile = 14, organic = true },
	sandstone = { base = M.Sandstone, tile = 6, organic = true },
	woodplanks = { base = M.WoodPlanks, tile = 10 },
	wood = { base = M.Wood, tile = 8 },
	gold = { base = M.Metal, tile = 5, organic = true },
	velvet = { base = M.Fabric, tile = 3, organic = true },
	linen = { base = M.Fabric, tile = 3 },
	terracotta = { base = M.Slate, tile = 3.5, organic = true },
	limestone = { base = M.Slate, tile = 6, organic = true },
	soil = { base = M.Ground, tile = 6, organic = true },
	grass = { base = M.LeafyGrass, tile = 8, organic = true },
	leaves = { base = M.LeafyGrass, tile = 3, organic = true },
}
local VARIANT = {} -- set name -> MaterialVariant name, for the sets that were created
local hasVariants = false

local resolvedIds = {}
-- A texture's id, ready for a Content property, or nil if it hasn't been uploaded.
local function texture(name)
	local raw = TEXTURE_IDS[name]
	if raw == nil or raw == "" then
		return nil
	end
	if resolvedIds[name] == nil then
		raw = tostring(raw)
		local digits = raw:match("^%s*(%d+)%s*$")
		local id = digits and ("rbxassetid://" .. digits) or raw
		if digits and not IS_LUNE then
			-- A bare number may be a Decal (Open Cloud uploads return those); the image
			-- inside it is what textures need. Studio can look it up.
			pcall(function()
				local asset = game:GetService("InsertService"):LoadAsset(tonumber(digits))
				local decal = asset:FindFirstChildWhichIsA("Decal", true)
				local image = decal and decal.Texture:match("(%d+)$")
				if image then
					id = "rbxassetid://" .. image
				end
				asset:Destroy()
			end)
		end
		resolvedIds[name] = id
	end
	return resolvedIds[name]
end

local function buildMaterialVariants()
	local service = game:GetService("MaterialService")
	for key, set in MATERIAL_SETS do
		local colorMap = texture(key .. "_color")
		if colorMap then
			local name = "ThroneRoom_" .. key
			local ok, err = pcall(function()
				local old = service:FindFirstChild(name)
				if old then
					old:Destroy()
				end
				local variant = Instance.new("MaterialVariant")
				variant.Name = name
				variant.BaseMaterial = set.base
				variant.ColorMap = colorMap
				variant.NormalMap = texture(key .. "_normal") or ""
				variant.RoughnessMap = texture(key .. "_roughness") or ""
				variant.MetalnessMap = texture(key .. "_metalness") or ""
				variant.StudsPerTile = set.tile
				variant.MaterialPattern = if set.organic then Enum.MaterialPattern.Organic else Enum.MaterialPattern.Regular
				variant.Parent = service
			end)
			if ok then
				VARIANT[key] = name
				hasVariants = true
			else
				print("[ThroneRoom] Couldn't make the " .. key .. " material: " .. tostring(err))
			end
		end
	end
end

-- Which texture set a part gets, from its material (and, where two sets share a
-- material, its colour).
local DEFAULT_SET = {
	Plaster = "plaster",
	Sandstone = "sandstone",
	WoodPlanks = "woodplanks",
	Wood = "wood",
	Metal = "gold",
	Ground = "soil",
	LeafyGrass = "leaves",
}
local function setFor(material, color)
	if material == M.Fabric then
		return if color.R > 0.8 and color.G > 0.8 then "linen" else "velvet"
	elseif material == M.Slate then
		return if color.R > color.B + 0.12 then "terracotta" else "limestone"
	end
	return DEFAULT_SET[material.Name]
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
			if k ~= "Class" and k ~= "Shape" and k ~= "Variant" then
				p[k] = v
			end
		end
	end
	if hasVariants then
		local variant = VARIANT[props and props.Variant or setFor(p.Material, color)]
		if variant then
			p.MaterialVariant = variant
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

-- Cut-out images (ivy, grass, grime, glass) go on invisible parts. These hold their ids
-- once build() knows which textures were uploaded.
local CARDS = {}
local CARD_P = { Transparency = 1 }
local function decal(parent, id, face, tint)
	local d = Instance.new("Decal")
	d.Texture = id
	d.Face = face
	if tint then
		d.Color3 = tint
	end
	d.Parent = parent
	return d
end
local function tiled(parent, id, face, studsU, studsV, transparency)
	local t = Instance.new("Texture")
	t.Texture = id
	t.Face = face
	t.StudsPerTileU = studsU
	t.StudsPerTileV = studsV
	t.Transparency = transparency or 0
	t.Parent = parent
	return t
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
	local GRASS_FLOOR = merge(SOLID, { Variant = "grass" })
	block(floor, -W - T, -3, -T, W + T, 0, STEPS[1].z, C.grass, M.LeafyGrass, GRASS_FLOOR)
	block(floor, -STEPS[1].hw, -3, STEPS[1].z, STEPS[1].hw, 0, STEPS[2].z, C.grass, M.LeafyGrass, GRASS_FLOOR)
	block(floor, -STEPS[2].hw, -3, STEPS[2].z, STEPS[2].hw, 0, STEPS[3].z + 2, C.grass, M.LeafyGrass, GRASS_FLOOR)

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

	-- glass, with streaks and seed bubbles over it when that texture is uploaded
	local function streaky(pane)
		if CARDS.glass then
			tiled(pane, CARDS.glass, Enum.NormalId.Back, 5, 5, 0.1)
		end
		return pane
	end
	local glass = streaky(part(win, pf * CF(0, spring / 2, -2), V3(2 * a, spring, 0.2), C.glass, M.Neon, merge(GLASS_P, { Name = "Glass" })))
	local yy = 0
	while yy < WIN.h - 1e-3 do
		local y1 = min(yy + 0.3, WIN.h)
		local hw = archHalfWidth(R, WIN.cx, yy)
		streaky(part(win, pf * CF(0, spring + (yy + y1) / 2, -2), V3(2 * max(0.05, hw), y1 - yy, 0.2), C.glass, M.Neon, GLASS_P))
		yy = y1
	end
	-- the narrow outer lights are a warmer tint
	for side = -1, 1, 2 do
		streaky(part(win, pf * CF(side * (a + 6.2) / 2, 7.25, -1.84), V3(a - 6.2, 14.5, 0.12), C.glassWarm, M.Neon, GLASS_P))
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
	local h = (0.3 + 0.3 * edge) + 0.7 * mound * edge + 0.25 * noise2(x * 0.35, z * 0.35)
	h *= 0.45 + 0.55 * clamp01((clearingEdge(x, z) - 1) / 0.4)
	return SOIL_TOP + h, bright
end

local function leaf(parent, base, yaw, len, lift)
	local cf = CF(base) * ANG(0, yaw, 0) * ANG(lift or rr(0.35, 0.7), 0, 0) * CF(0, 0, -len / 2)
	ellipsoid(parent, cf, V3(len * 0.38, 0.06, len), jitter(C.leaf, 0.12))
end

-- A buttercup: five glossy petals cupped around a ring of stamens and a green knot of
-- pistils, on a stem of its own. Petals vary a little, as real ones do.
local PETAL_P = { Reflectance = 0.08 } -- buttercup petals are famously glossy
local function flower(parent, pos, headR, petalColor, centerColor, stemFrom)
	local tiltX, tiltZ = rr(-0.3, 0.3), rr(-0.3, 0.3)
	local cup = rr(0.4, 0.7)
	local petals = 5
	local kind = rand()
	if kind < 0.07 then -- a bud, nearly closed
		cup = rr(1.15, 1.35)
		headR *= 0.62
	elseif kind < 0.2 then -- turned toward the light
		tiltX = rr(0.45, 0.8) * (if rand() < 0.5 then -1 else 1)
	elseif kind < 0.24 then -- going over, with a petal gone
		petals = 4
	end
	local fcf = CF(pos) * ANG(tiltX, rand() * TAU, tiltZ)
	local turn = rand() * TAU
	for i = 0, petals - 1 do
		local len, wid = headR * rr(0.95, 1.08), headR * rr(0.82, 0.95)
		local pcf = fcf * ANG(0, turn + i * TAU / 5 + rr(-0.08, 0.08), 0) * ANG(cup + rr(-0.12, 0.12), 0, 0) * CF(0, 0, -len * 0.5 - headR * 0.08)
		ellipsoid(parent, pcf, V3(wid, headR * 0.09, len), jitter(petalColor, 0.05), PETAL_P)
	end
	disc(parent, fcf * CF(0, 0.03, 0), headR * 0.46, headR * 0.14, centerColor, M.SmoothPlastic, {})
	local knot = headR * 0.24
	part(parent, fcf * CF(0, headR * 0.09, 0), V3(knot, knot, knot), jitter(C.pistil, 0.08), M.SmoothPlastic, BALL_P)
	if stemFrom then
		local top = (fcf * CF(0, -headR * 0.12, 0)).Position
		cylBetween(parent, stemFrom, top, rr(0.09, 0.13), jitter(C.stem, 0.1), M.SmoothPlastic)
		if rand() < 0.2 then -- a leaf partway up the stem
			leaf(parent, stemFrom:Lerp(top, rr(0.35, 0.6)), rand() * TAU, headR * rr(1.0, 1.4), rr(0.7, 1.0))
		end
	end
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
		local size = rr(0.5, 0.75)
		ellipsoid(flowers, CF(px, 0.47, pz) * ANG(rr(-0.15, 0.15), rand() * TAU, rr(-0.15, 0.15)), V3(size * 0.85, 0.06, size), jitter(C.petalDim, 0.08), PETAL_P)
	end

	-- low leafy mounds under the flowers (the terrain grass grows up through them)
	for x = -BED.rx, BED.rx, 2.6 do
		for z = BED.cz - BED.rz, BED.cz + BED.rz, 2.6 do
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
					local pos = V3(px, top + rr(0.15, 0.7) + 0.35 * bright, pz)
					flower(flowers, pos, headR, petal, center, V3(px + rr(-0.3, 0.3), SOIL_TOP, pz + rr(-0.3, 0.3)))
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

-- With the ivy texture uploaded: a cut-out of ivy sprigs standing just off the wall,
-- sometimes with a leafy mound behind it for depth.
local function ivyCard(parent, pf, x, y, scale)
	local size = rr(3.0, 4.0) * scale
	local cf = pf * CF(x, y, rr(0.5, 1.0) * scale) * ANG(rr(-0.2, 0.2), rr(-0.2, 0.2), rr(-0.4, 0.4))
	local card = part(parent, cf, V3(size, size, 0.05), C.ivy[1], M.SmoothPlastic, CARD_P)
	local g = rr(0.78, 1.0)
	decal(card, CARDS.ivy, Enum.NormalId.Back, Color3.new(g, g, g))
	if rand() < 0.3 then
		local r = rr(0.5, 0.8) * scale
		part(parent, pf * CF(x + rr(-0.6, 0.6), y + rr(-0.6, 0.6), -r * 0.2), V3(2 * r, 2 * r, 2 * r), jitter(pick(C.ivy), 0.08), M.LeafyGrass, BALL_P)
	end
end

-- A low leafy mound pressed into the wall, with a leaf or two standing off it.
local function ivyLeaf(parent, pf, x, y, scale)
	scale = scale or 1
	if CARDS.ivy then
		return ivyCard(parent, pf, x, y, scale)
	end
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
	local step = if CARDS.ivy then 2.7 else 2.0
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
		if rand() < (if CARDS.ivy then 0.3 else 0.6) then
			ivyLeaf(parent, pf, cx + rr(-1.3, 1.3), y - rr(0, 0.6), taper * 0.8)
		end
		y -= if CARDS.ivy then rr(1.8, 2.3) else rr(1.1, 1.5)
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
-- Weathering and grass
--------------------------------------------------------------------------------

-- The interior wall faces, each with the room on its left (as in buildTrim).
local function wallRuns()
	local runs = {
		{ -W, 0, DOOR.x0 - 1.1, 0 },
		{ DOOR.x1 + 1.1, 0, W, 0 },
		{ -W, STEPS[1].z, -W, 0 },
		{ -STEPS[1].hw, STEPS[1].z, -W, STEPS[1].z },
		{ -STEPS[1].hw, STEPS[2].z, -STEPS[1].hw, STEPS[1].z },
		{ -STEPS[2].hw, STEPS[2].z, -STEPS[1].hw, STEPS[2].z },
		{ -STEPS[2].hw, STEPS[3].z, -STEPS[2].hw, STEPS[2].z },
		{ -CORRIDOR.hw, STEPS[3].z, -STEPS[2].hw, STEPS[3].z },
	}
	for i = 3, #runs do -- the same walls on the right
		local r = runs[i]
		table.insert(runs, { -r[3], r[4], -r[1], r[2] })
	end
	return runs
end

-- Dust and soot: a band of grime above the wainscot, and a darker one under the cornice
-- (turned upside down), since light never quite reaches the corners of a room.
local function buildGrime(room)
	local grime = model("Grime", room, "Folder")
	local function band(x0, z0, x1, z1, y0, y1, flip)
		local pf, len = wallPlane(x0, z0, x1, z1)
		local cf = pf * CF(len / 2, (y0 + y1) / 2, 0.14)
		if flip then
			cf *= ANG(0, 0, PI)
		end
		local p = part(grime, cf, V3(len, y1 - y0, 0.04), C.wall, M.SmoothPlastic, CARD_P)
		tiled(p, CARDS.grime, Enum.NormalId.Back, 20, y1 - y0, 0.15)
	end
	for _, r in wallRuns() do
		band(r[1], r[2], r[3], r[4], 3.15, 7, false)
	end
	for _, r in wallRuns() do
		if r[2] ~= 0 or r[4] ~= 0 then
			band(r[1], r[2], r[3], r[4], 37.5, H - 2.4, true)
		end
	end
	-- under the cornice of the back wall, leaving the window clear
	band(-W, 0, WIN.x - WIN.a - 2.3, 0, 37.5, H - 2.4, true)
	band(WIN.x + WIN.a + 2.3, 0, W, 0, 37.5, H - 2.4, true)
	for _, r in { { -CORRIDOR.hw, CORRIDOR.z1, -CORRIDOR.hw, STEPS[3].z + 1 }, { CORRIDOR.hw, STEPS[3].z + 1, CORRIDOR.hw, CORRIDOR.z1 } } do
		band(r[1], r[2], r[3], r[4], 3.15, 6.5, false)
		band(r[1], r[2], r[3], r[4], CORRIDOR.h - 6.5, CORRIDOR.h - 2.4, true)
	end
end

-- A tuft of grass. With the grass textures uploaded: three crossed cut-outs that show
-- from both sides (`tall` picks the wispy, seeding kind). Without them: a few blades,
-- each a thin wedge leaning out from the root.
local function grassTuft(parent, pos, h, tall)
	local id = if tall then CARDS.tallGrass or CARDS.grass else CARDS.grass
	local yaw = rand() * PI
	if id then
		local g = rr(0.75, 1.0)
		for i = 0, 2 do
			local cf = CF(pos + V3(0, h / 2 - 0.15, 0)) * ANG(0, yaw + i * PI / 3, 0)
			local p = part(parent, cf, V3(h * 1.1, h, 0.05), C.grass, M.SmoothPlastic, CARD_P)
			decal(p, id, Enum.NormalId.Front, Color3.new(g, g, g))
			decal(p, id, Enum.NormalId.Back, Color3.new(g, g, g))
		end
		return
	end
	for i = 1, 5 do
		local bh = h * rr(0.55, 1.0)
		local cf = CF(pos + V3(rr(-0.25, 0.25), -0.1, rr(-0.25, 0.25))) * ANG(0, yaw + i * 1.3 + rr(-0.3, 0.3), 0) * ANG(rr(-0.45, 0.15), 0, 0) * CF(0, bh / 2, 0)
		part(parent, cf, V3(0.05, bh, rr(0.16, 0.26)), jitter(pick(C.blade), 0.08), M.SmoothPlastic, { Class = "WedgePart" })
	end
end

local function hallHalfWidth(z)
	if z < STEPS[1].z then
		return W
	elseif z < STEPS[2].z then
		return STEPS[1].hw
	end
	return STEPS[2].hw
end

local function buildGrassTufts(room, bushes)
	local tufts = model("GrassTufts", room, "Folder")
	local cut = CARDS.grass ~= nil
	-- along the foot of the side walls
	for z = 12, STEPS[3].z - 2, 2.2 do
		local hw = hallHalfWidth(z)
		for _, side in { -1, 1 } do
			if rand() < 0.7 then
				grassTuft(tufts, V3(side * (hw - rr(0.9, 2.2)), 0, z + rr(-0.8, 0.8)), rr(1.2, 2.6))
			end
		end
	end
	-- around the flower bed
	local placed, tries = 0, 0
	while placed < 140 and tries < 4000 do
		tries += 1
		local ang = rand() * TAU
		local r = rr(1.0, 1.14)
		local x, z = BED.cx + cos(ang) * BED.rx * r, BED.cz + sin(ang) * BED.rz * r
		local e = bedEdge(x, z)
		if e > 1.01 and e < 1.12 and z > 11 then
			placed += 1
			grassTuft(tufts, V3(x, 0, z), rr(1.0, 2.2))
		end
	end
	-- around the bushes
	for _, b in bushes do
		for i = 1, 14 do
			local ang = i / 14 * TAU + rr(-0.2, 0.2)
			local r = rr(0.95, 1.1)
			grassTuft(tufts, V3(b.x + cos(ang) * b.rx * r, 0, b.z + sin(ang) * b.rz * r), rr(1.2, 2.4), rand() < 0.4)
		end
	end
	if not cut then
		return -- the terrain grass covers the rest; blades made of parts would be too many
	end
	-- clumps across the open grass, and tall seeding grass among the flowers
	placed, tries = 0, 0
	while placed < 120 and tries < 4000 do
		tries += 1
		local z = rr(12, STEPS[3].z - 2)
		local hw = hallHalfWidth(z) - 1.5
		local x = rr(-hw, hw)
		if bedEdge(x, z) > 1.12 then
			placed += 1
			grassTuft(tufts, V3(x, 0, z), rr(0.9, 2.0), rand() < 0.3)
		end
	end
	placed, tries = 0, 0
	while placed < 90 and tries < 4000 do
		tries += 1
		local x, z = rr(-BED.rx, BED.rx), rr(BED.cz - BED.rz, BED.cz + BED.rz)
		if bedEdge(x, z) < 0.95 and clearingEdge(x, z) > 1.2 then
			placed += 1
			local top = foliageTop(x, z)
			grassTuft(tufts, V3(x, top - 0.6, z), rr(1.8, 3.0), true)
		end
	end
end

-- Terrain grass for the whole floor of the hall, flower bed included, but not the dirt
-- round the throne: strips {x0, x1, z} two studs deep. Terrain isn't in the place file
-- Lune writes, so the plan is saved and ThroneRoomServer grows it there.
local TERRAIN_GRASS = RGB(74, 106, 48)
local function terrainStrips()
	local strips = {}
	for z = 12, STEPS[3].z - 1, 2 do
		local hw = hallHalfWidth(z) - 1
		local start = nil
		local x = -hw
		while x <= hw + 1e-6 do
			local open = clearingEdge(x, z) > 1.15
			if open and not start then
				start = x
			end
			local last = x + 2 > hw + 1e-6
			if start and (not open or last) then
				local stop = if open then x else x - 2
				if stop >= start then
					table.insert(strips, { start - 1, stop + 1, z })
				end
				start = nil
			end
			x += 2
		end
	end
	return strips
end

local function growTerrain(strips)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return false
	end
	local ok = pcall(function()
		if CONFIG.ReplaceExisting then
			terrain:FillBlock(ORIGIN * CF(0, -1.6, (STEPS[3].z - 4) / 2), V3(2 * W + 2, 6, STEPS[3].z + 6), Enum.Material.Air)
		end
		for _, s in strips do
			terrain:FillBlock(ORIGIN * CF((s[1] + s[2]) / 2, -1.6, s[3]), V3(s[2] - s[1], 4.8, 2), Enum.Material.Grass)
		end
		terrain:SetMaterialColor(Enum.Material.Grass, TERRAIN_GRASS)
	end)
	trySet(terrain, "Decoration", true)
	trySet(terrain, "GrassLength", 1)
	return ok
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
	local G, GD, GM = C.gold, C.goldDeep, M.Metal
	local GOLD_P = { CastShadow = true, Reflectance = 0.08 } -- polished highlights
	local GOLD_S = merge(SOLID, { Reflectance = 0.05 }) -- the gilded frame itself
	local VELVET = M.Fabric

	-- A round molding: cylinders through room-space points, with balls at the bends.
	local function bead(pts, d, color, props)
		for i = 1, #pts - 1 do
			cylBetween(m, pts[i], pts[i + 1], d, color or G, GM, props or GOLD_P)
		end
		for i = 2, #pts - 1 do
			ball(m, pts[i], d, color or G, GM, props or GOLD_P)
		end
	end
	-- A carved leaf or shell rib: a gilded ellipsoid.
	local function carving(cf, size)
		local p = part(m, cf, size, G, GM, GOLD_P)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	-- A flat spiral (a carved volute) in the XY plane of `pf`.
	local function volute(pf, r0, r1, turns, start, d)
		local pts = {}
		local n = floor(turns * 9)
		for i = 0, n do
			local t = i / n
			local a = start + t * turns * TAU
			local r = r0 + (r1 - r0) * t
			table.insert(pts, pf * V3(cos(a) * r, sin(a) * r, 0))
		end
		bead(pts, d)
	end
	-- A turned part on a vertical axis: { y0, y1, diameter } from the bottom up.
	local function turned(cf, profile, color, props)
		for _, s in profile do
			part(m, cf * CF(0, (s[1] + s[2]) / 2, 0) * ANG(0, 0, PI / 2), V3(s[2] - s[1], s[3], s[3]), color, GM, merge(props, CYL_P))
		end
	end

	-- legs: turned, on bun feet, each under a square die with a rosette
	local LEG = { { 0, 0.25, 1.55 }, { 1.42, 1.62, 1.15 }, { 1.62, 2.05, 0.85 }, { 2.05, 2.45, 0.72 }, { 2.45, 2.62, 1.02 }, { 2.62, 2.95, 1.22 } }
	for _, sx in { -1, 1 } do
		for _, z in { 4.42, -3.8 } do
			local x = sx * 5.4
			turned(base * CF(x, 0, z), LEG, G, GOLD_S)
			ball(m, P(x, 0.85, z), 1.4, G, GM, GOLD_S)
			part(m, base * CF(x, 3.62, z), V3(1.4, 1.35, 1.4), GD, GM, GOLD_S)
			for _, face in { V3(0, 0, if z > 0 then 1 else -1), V3(sx, 0, 0) } do
				local c = V3(x, 3.62, z) + face * 0.7
				plate(m, base * CFrame.lookAt(c, c + face), 0.85, 0.12, G, GM, GOLD_P)
				ball(m, P(c.X, c.Y, c.Z) + base:VectorToWorldSpace(face * 0.08), 0.36, G, GM, GOLD_P)
			end
		end
	end

	-- seat rails between the dies, beaded along both edges
	for _, r in {
		{ V3(-4.7, 3.62, 4.42), V3(4.7, 3.62, 4.42), V3(0, 0, 1) },
		{ V3(-4.7, 3.62, -3.8), V3(4.7, 3.62, -3.8), V3(0, 0, -1) },
		{ V3(-5.4, 3.62, -3.1), V3(-5.4, 3.62, 3.72), V3(-1, 0, 0) },
		{ V3(5.4, 3.62, -3.1), V3(5.4, 3.62, 3.72), V3(1, 0, 0) },
	} do
		local a, b, out = r[1], r[2], r[3]
		part(m, base * frameX((a + b) / 2, b - a), V3((b - a).Magnitude, 1.25, 0.85), GD, GM, GOLD_S)
		for _, dy in { 0.55, -0.55 } do
			local o = out * 0.43 + V3(0, dy, 0)
			bead({ P(a.X + o.X, a.Y + o.Y, a.Z + o.Z), P(b.X + o.X, b.Y + o.Y, b.Z + o.Z) }, 0.3)
		end
	end
	-- a carved shell hanging from the front rail, between two scrolls, under a medallion
	local shell = V3(0, 3.1, 4.75)
	for i = -3, 3 do
		local a = i * 0.36
		local len = 1.75 - abs(i) * 0.15
		local mid = shell + V3(sin(a), -cos(a), 0) * (len / 2)
		carving(base * CF(mid) * ANG(0, 0, a), V3(0.42, len, 0.32))
	end
	ball(m, P(shell.X, shell.Y, shell.Z + 0.05), 0.5, G, GM, GOLD_P)
	for _, sx in { -1, 1 } do
		volute(base * CF(sx * 1.85, 2.75, 4.85) * ANG(0, if sx < 0 then PI else 0, 0), 0.7, 0.18, 1.25, PI * 0.5, 0.2)
	end
	plate(m, base * CF(0, 3.62, 4.9), 1.15, 0.12, G, GM, GOLD_P)
	plate(m, base * CF(0, 3.62, 4.97), 0.72, 0.1, C.purple, VELVET, {})

	-- the seat: a velvet cushion with rounded edges, gold piping and nailheads
	local cx, cz0, cz1, y0, y1, r = 5.2, -3.75, 4.5, 4.3, 5.95, 0.42
	part(m, base * CF(0, (y0 + y1 - r) / 2, (cz0 + cz1) / 2), V3(2 * cx, y1 - r - y0, cz1 - cz0), C.lavender, VELVET, SOLID)
	part(m, base * CF(0, y1 - r / 2, (cz0 + cz1 - r) / 2), V3(2 * (cx - r), r, cz1 - cz0 - r), C.lavender, VELVET, SOLID)
	cylBetween(m, P(-cx + r, y1 - r, cz1 - r), P(cx - r, y1 - r, cz1 - r), 2 * r, C.lavender, VELVET, SHADOW)
	for _, sx in { -1, 1 } do
		cylBetween(m, P(sx * (cx - r), y1 - r, cz0), P(sx * (cx - r), y1 - r, cz1 - r), 2 * r, C.lavender, VELVET, SHADOW)
		ball(m, P(sx * (cx - r), y1 - r, cz1 - r), 2 * r, C.lavender, VELVET, SHADOW)
	end
	local k, q = r * 0.71, r * 0.58
	local ex, ey, ez = cx - r, y1 - r, cz1 - r -- the axes of the rounded edges
	bead({
		P(-ex - k, ey + k, cz0 + 0.2),
		P(-ex - k, ey + k, ez),
		P(-ex - q, ey + q, ez + q),
		P(-ex, ey + k, ez + k),
		P(ex, ey + k, ez + k),
		P(ex + q, ey + q, ez + q),
		P(ex + k, ey + k, ez),
		P(ex + k, ey + k, cz0 + 0.2),
	}, 0.14)
	for x = -cx + 0.35, cx - 0.3, 0.42 do
		ball(m, P(x, y0 + 0.22, cz1 + 0.02), 0.2, G, GM, {})
	end
	for _, sx in { -1, 1 } do
		for z = cz0 + 0.5, cz1 - 0.3, 0.42 do
			ball(m, P(sx * (cx + 0.02), y0 + 0.22, z), 0.2, G, GM, {})
		end
	end

	-- the back, leaning back 10 degrees: gilded stiles and an arched crest rail framing
	-- buttoned velvet. B/BC place things in the back's own frame (x across, v up, w out).
	local BF = base * CF(0, 4.3, -3.8) * ANG(rad(-10), 0, 0)
	local function B(x, v, w)
		return BF * V3(x, v, w)
	end
	local function BC(x, v, w)
		return BF * CF(x, v, w)
	end
	local SX, TOP, APEX = 5.45, 13.5, 17.6
	local ac = (APEX ^ 2 - TOP ^ 2 - SX ^ 2) / (2 * (APEX - TOP)) -- the arch's centre
	local AR = APEX - ac
	local function arch(radius, xLimit, n)
		local a0, a1 = acos(-xLimit / radius), acos(xLimit / radius)
		local pts = {}
		for i = 0, n do
			local a = a0 + (a1 - a0) * i / n
			table.insert(pts, { cos(a) * radius, ac + sin(a) * radius })
		end
		return pts
	end
	for _, sx in { -1, 1 } do
		part(m, BC(sx * SX, TOP / 2, 0), V3(1.2, TOP, 1.25), GD, GM, GOLD_S)
		for _, dx in { -0.28, 0.28 } do -- reeding down the face of the stile
			cylBetween(m, B(sx * SX + dx, 0.4, 0.64), B(sx * SX + dx, TOP - 0.3, 0.64), 0.22, G, GM, GOLD_P)
		end
		-- an urn finial on each stile
		local fv = TOP + 0.45
		turned(BC(sx * SX, fv, 0), { { 0, 0.3, 1.5 }, { 1.45, 1.6, 0.7 }, { 2.2, 2.7, 0.16 } }, G, GOLD_P)
		ball(m, B(sx * SX, fv + 0.9, 0), 1.15, G, GM, GOLD_P)
		ball(m, B(sx * SX, fv + 1.95, 0), 0.6, G, GM, GOLD_P)
		ball(m, B(sx * SX, fv + 2.75, 0), 0.28, G, GM, GOLD_P)
	end
	part(m, BC(0, 0.4, 0), V3(2 * SX, 0.8, 1.25), GD, GM, GOLD_S)
	polyline(m, BF, arch(AR, SX, 16), 1.1, 1.25, GD, GM, GOLD_S, 0)
	local outer = {}
	for i, q2 in arch(AR + 0.55, SX + 0.3, 18) do
		outer[i] = B(q2[1], q2[2], 0.3)
	end
	bead(outer, 0.34)

	-- the velvet: a deep purple panel (with the arch filled in slices) and a raised,
	-- buttoned centre with pleats running between the buttons
	part(m, BC(0, (0.8 + TOP) / 2, -0.3), V3(2 * SX - 1.1, TOP - 0.8, 0.9), C.purpleDeep, VELVET, SOLID)
	local inR = AR - 0.5
	local v = TOP
	while v < ac + inR - 0.05 do
		local v1 = min(v + 0.35, ac + inR)
		local hw = sqrt(max(0, inR * inR - (v1 - ac) ^ 2))
		part(m, BC(0, (v + v1) / 2, -0.3), V3(2 * max(0.05, hw), v1 - v, 0.9), C.purpleDeep, VELVET, {})
		v = v1
	end
	part(m, BC(0, 7.0, 0.3), V3(8.6, 11.6, 0.3), C.purple, VELVET, SHADOW)
	local normal = BF:VectorToWorldSpace(V3(0, 0, 1))
	local buttons = {}
	for row = 0, 7 do
		for col = -3, 3 do
			local x = col * 1.7 + (row % 2) * 0.85
			if abs(x) <= 3.6 then
				local bv = 1.9 + row * 1.45
				buttons[row .. ":" .. col] = { x, bv }
				ball(m, B(x, bv, 0.5), 0.3, G, GM, {})
				local px, pv = x + 0.85, bv + 0.725
				if abs(px) <= 3.4 and row < 7 then
					ball(m, B(px, pv, 0.0), 1.45, C.purple, VELVET, {})
				end
			end
		end
	end
	for row = 0, 6 do -- pleats from each button to the ones diagonally above it
		for col = -3, 3 do
			local b0 = buttons[row .. ":" .. col]
			if b0 then
				for _, dc in { 0, if row % 2 == 0 then -1 else 1 } do
					local b1 = buttons[(row + 1) .. ":" .. (col + dc)]
					if b1 then
						local a, b = B(b0[1], b0[2], 0.47), B(b1[1], b1[2], 0.47)
						part(m, frameX((a + b) / 2, b - a, normal), V3((b - a).Magnitude, 0.06, 0.09), shade(C.purple, 0.62), VELVET, {})
					end
				end
			end
		end
	end
	-- gilded beads round the velvet
	local inner = { B(-4.72, 0.85, 0.6) }
	for _, q2 in arch(AR - 0.62, 4.72, 14) do
		table.insert(inner, B(q2[1], q2[2], 0.6))
	end
	table.insert(inner, B(4.72, 0.85, 0.6))
	table.insert(inner, B(-4.72, 0.85, 0.6))
	bead(inner, 0.3)

	-- a small golden Delta Rune in the arch
	local ew, ev = 0.22, ac + 2.7
	plate(m, BC(0, ev + 0.35, ew), 1.5, 0.14, G, GM, GOLD_P)
	for _, side in { -1, 1 } do
		triangle(m, B(side * 0.7, ev + 0.7, ew), B(side * 0.75, ev + 0.1, ew), B(side * 2.6, ev + 0.9, ew), G, GM, 0.14, {})
		triangle(m, B(side * 0.7, ev + 0.05, ew), B(side * 0.45, ev - 0.3, ew), B(side * 2.2, ev - 0.55, ew), G, GM, 0.14, {})
	end
	local ts, th = 1.1, 1.1 * 0.866
	for _, tx in { -0.72, 0.72 } do
		triangle(m, B(tx - ts / 2, ev - 1.55, ew), B(tx + ts / 2, ev - 1.55, ew), B(tx, ev - 1.55 + th, ew), G, GM, 0.14, {})
	end
	triangle(m, B(-ts / 2, ev - 1.8, ew), B(ts / 2, ev - 1.8, ew), B(0, ev - 1.8 - th, ew), G, GM, 0.14, {})

	-- the crown on the crest, with acanthus leaves and scrolls running down the arch
	local cv = APEX + 0.95
	part(m, BC(0, cv, 0), V3(4.6, 1.0, 1.0), GD, GM, GOLD_P)
	bead({ B(-2.3, cv - 0.5, 0.5), B(2.3, cv - 0.5, 0.5) }, 0.2)
	bead({ B(-2.3, cv + 0.5, 0.5), B(2.3, cv + 0.5, 0.5) }, 0.2)
	for _, pt in {
		{ { -2.25, cv + 0.5 }, { -0.95, cv + 0.5 }, { -1.75, cv + 2.4 } },
		{ { -0.8, cv + 0.5 }, { 0.8, cv + 0.5 }, { 0, cv + 3.2 } },
		{ { 0.95, cv + 0.5 }, { 2.25, cv + 0.5 }, { 1.75, cv + 2.4 } },
	} do
		triangle(m, B(pt[1][1], pt[1][2], 0), B(pt[2][1], pt[2][2], 0), B(pt[3][1], pt[3][2], 0), G, GM, 0.7, GOLD_P)
		ball(m, B(pt[3][1], pt[3][2], 0), 0.6, G, GM, GOLD_P)
	end
	for i, gx in { -1.4, 0, 1.4 } do
		ball(m, B(gx, cv, 0.5), 0.5, if i == 2 then C.lavender else C.purple, M.Glass, {})
	end
	for _, sx in { -1, 1 } do
		volute(BC(sx * 3.2, cv - 0.6, 0.2) * ANG(0, if sx < 0 then PI else 0, 0), 0.85, 0.2, 1.2, PI * 0.6, 0.28)
		for _, t in { 0.32, 0.5, 0.68 } do -- leaves along the shoulders of the arch
			local a = acos(-SX / AR) + (PI / 2 - acos(-SX / AR)) * t
			if sx > 0 then
				a = PI - a
			end
			local pos = BC(cos(a) * (AR + 0.65), ac + sin(a) * (AR + 0.65), 0.15)
			carving(pos * ANG(0, 0, a - PI / 2 + sx * 0.35), V3(0.55, 1.45, 0.32))
		end
	end

	-- open arms: a gilded rail with a velvet pad, carried on an S-curved support that rises
	-- from the front leg and ends in a scroll
	for _, sx in { -1, 1 } do
		local x = sx * 5.75
		local back, front = V3(x, 8.75, -4.2), V3(x, 8.45, 4.0)
		local dir = front - back
		part(m, base * frameX((back + front) / 2, dir), V3(dir.Magnitude, 0.6, 0.95), GD, GM, GOLD_S)
		local function railAt(z, lift)
			local t = (z - back.Z) / dir.Z
			return back + dir * t + V3(0, lift, 0)
		end
		local p0, p1 = railAt(-3.0, 0.52), railAt(3.2, 0.52)
		local padCf = base * frameX((p0 + p1) / 2, p1 - p0)
		part(m, padCf, V3((p1 - p0).Magnitude, 0.44, 0.62), C.lavender, VELVET, SHADOW)
		for _, side in { -0.31, 0.31 } do
			local o = padCf:VectorToWorldSpace(V3(0, 0, side))
			cylBetween(m, base * p0 + o, base * p1 + o, 0.44, C.lavender, VELVET, SHADOW)
			local low = padCf:VectorToWorldSpace(V3(0, -0.2, side * 1.5))
			bead({ base * p0 + low, base * p1 + low }, 0.12)
		end
		bead({ P(sx * 5.4, 4.3, 4.42), P(sx * 5.62, 5.3, 4.8), P(sx * 5.78, 6.4, 4.66), P(sx * 5.78, 7.4, 4.28), P(sx * 5.75, 8.2, 4.05) }, 0.8, GD, GOLD_S)
		carving(base * CF(sx * 5.66, 5.75, 5.12) * ANG(-0.35, 0, 0), V3(0.55, 1.5, 0.28))
		part(m, base * CF(x, 8.55, 4.25), V3(1.15, 1.35, 1.35), G, GM, merge(GOLD_P, CYL_P))
		part(m, base * CF(x + sx * 0.6, 8.55, 4.25), V3(0.1, 0.95, 0.95), C.purple, VELVET, CYL_P)
		ball(m, P(x + sx * 0.66, 8.55, 4.25), 0.4, G, GM, GOLD_P)
		ball(m, P(x, 7.85, 4.5), 0.6, G, GM, GOLD_P)
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

-- Terrain grass, from the plan the builder left when it couldn't grow it itself
local plan = room:FindFirstChild("TerrainPlan")
if plan and room:GetAttribute("TerrainGrass") and not room:GetAttribute("TerrainBuilt") then
	local terrain = workspace.Terrain
	local pivot = room.WorldPivot
	for a, b, z in plan.Value:gmatch("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		a, b, z = tonumber(a), tonumber(b), tonumber(z)
		terrain:FillBlock(pivot * CFrame.new((a + b) / 2, -1.6, z), Vector3.new(b - a, 4.8, 2), Enum.Material.Grass)
	end
	local color = plan:GetAttribute("GrassColor")
	if typeof(color) == "Color3" then
		terrain:SetMaterialColor(Enum.Material.Grass, color)
	end
	pcall(function()
		terrain.Decoration = true
	end)
	room:SetAttribute("TerrainBuilt", true)
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

	buildMaterialVariants()
	CARDS.ivy = texture("ivy_card")
	CARDS.grass = texture("grass_card")
	CARDS.tallGrass = texture("tallgrass_card")
	CARDS.grime = texture("grime_card")
	CARDS.glass = texture("glass_card")

	local room = Instance.new("Model")
	room.Name = "AsgoreThroneRoom"
	room:SetAttribute("ApplyLighting", CONFIG.ApplyLighting)
	room:SetAttribute("MusicId", CONFIG.MusicId)
	room:SetAttribute("TerrainGrass", CONFIG.TerrainGrass)

	local shell = buildShell(room)
	buildTrim(shell)
	buildTiles(room)
	local _, glass = buildWindow(room)
	buildFlowerBed(room)
	buildIvy(room)
	local bushes = model("Bushes", room)
	local BUSHES = {
		{ x = -28, z = 116.5, rx = 8.5, rz = 7.5, h = 4.2 },
		{ x = 27, z = 116.5, rx = 8.5, rz = 7.5, h = 4.2 },
		{ x = 0, z = 128, rx = 11.5, rz = 8.5, h = 5 },
	}
	for _, b in BUSHES do
		bush(bushes, b.x, b.z, b.rx, b.rz, b.h)
	end
	if CARDS.grime then
		buildGrime(room)
	end
	buildGrassTufts(room, BUSHES)
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

	if CONFIG.TerrainGrass then
		local strips = terrainStrips()
		local encoded = {}
		for i, s in strips do
			encoded[i] = string.format("%g,%g,%g", s[1], s[2], s[3])
		end
		local plan = Instance.new("StringValue")
		plan.Name = "TerrainPlan"
		plan.Value = table.concat(encoded, ";")
		plan:SetAttribute("GrassColor", TERRAIN_GRASS)
		plan.Parent = room
		if not IS_LUNE and growTerrain(strips) then
			room:SetAttribute("TerrainBuilt", true)
		end
	end

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

	local textured = 0
	for _ in VARIANT do
		textured += 1
	end
	print(string.format("[ThroneRoom] Built Asgore's throne room: %d parts, %d textured materials, in %.1fs.", partCount, textured, os.clock() - startClock))
	return room
end

return build()
