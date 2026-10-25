--[[
	Builds dist/AsgoreThroneRoom.rbxl (a place) and dist/AsgoreThroneRoom.rbxm (the room as a
	model) by running src/ThroneRoomBuilder.luau in Lune (https://lune-org.github.io/docs).

	From the repository root:
	    lune run tools/build
	    lune run tools/build -- --parts tools/preview/parts.json   (also dump parts for a preview)
	    lune run tools/build -- --preview   (only the dump, as if every texture were uploaded)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")

local args = {}
for i, arg in process.args do
	args[arg] = process.args[i + 1] or true
end
local preview = args["--preview"] ~= nil
local partsPath = args["--parts"]
if preview and type(partsPath) ~= "string" then
	partsPath = "tools/preview/parts.json"
end

local env = { __LUNE = true, game = game, workspace = workspace }
if preview then
	-- stand-in ids that the preview renderer maps back to textures/<name>.png
	env.__PREVIEW_TEXTURES = {}
	for _, file in fs.readDir("textures") do
		local name = file:match("^(.+)%.png$")
		if name then
			env.__PREVIEW_TEXTURES[name] = "preview://" .. name
		end
	end
end
for _, name in {
	"Instance",
	"Vector2",
	"Vector3",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"NumberRange",
	"Enum",
	"UDim",
	"UDim2",
	"BrickColor",
	"Font",
	"PhysicalProperties",
} do
	env[name] = roblox[name]
end

local source = fs.readFile("src/ThroneRoomBuilder.luau")
local room = luau.load(source, { debugName = "ThroneRoomBuilder", environment = env })()

-- The services a fresh Studio place has, so the file opens like one.
for _, service in {
	"Players",
	"Lighting",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"SoundService",
	"Teams",
} do
	game:GetService(service)
end
local starterPlayer = game:GetService("StarterPlayer")
for _, className in { "StarterPlayerScripts", "StarterCharacterScripts" } do
	local folder = Instance.new(className)
	folder.Name = className
	folder.Parent = starterPlayer
end

if not preview then
	if not fs.isDir("dist") then
		fs.writeDir("dist")
	end
	fs.writeFile("dist/AsgoreThroneRoom.rbxl", roblox.serializePlace(game))
	fs.writeFile("dist/AsgoreThroneRoom.rbxm", roblox.serializeModel({ room }))
	print("Wrote dist/AsgoreThroneRoom.rbxl and dist/AsgoreThroneRoom.rbxm")
end

-- Optional: dump every part (and the lights) as JSON, for previews outside Roblox.
if partsPath then
	local function color(c)
		return { c.R, c.G, c.B }
	end
	local parts, lights, beams, variants = {}, {}, {}, {}
	for _, v in game:GetService("MaterialService"):GetChildren() do
		if v:IsA("MaterialVariant") then
			variants[v.Name] = {
				color = v.ColorMap,
				normal = v.NormalMap,
				roughness = v.RoughnessMap,
				metalness = v.MetalnessMap,
				tile = v.StudsPerTile,
			}
		end
	end
	for _, d in room:GetDescendants() do
		if d:IsA("BasePart") then
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			local shape = nil
			if d.ClassName == "Part" then
				shape = d.Shape.Name
			end
			local images = nil
			for _, c in d:GetChildren() do
				if c:IsA("Decal") then -- Texture is a kind of Decal
					images = images or {}
					table.insert(images, {
						kind = c.ClassName,
						texture = c.Texture,
						face = c.Face.Name,
						color = color(c.Color3),
						transparency = c.Transparency,
						u = if c:IsA("Texture") then c.StudsPerTileU else nil,
						v = if c:IsA("Texture") then c.StudsPerTileV else nil,
					})
				end
			end
			table.insert(parts, {
				class = d.ClassName,
				shape = shape,
				mesh = mesh and mesh.MeshType.Name or nil,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { d.CFrame:GetComponents() },
				color = color(d.Color),
				material = d.Material.Name,
				transparency = d.Transparency,
				shadow = d.CastShadow,
				name = d.Name,
				variant = if d.MaterialVariant ~= "" then d.MaterialVariant else nil,
				images = images,
			})
		elseif d:IsA("Light") then
			local holder = d.Parent
			table.insert(lights, {
				class = d.ClassName,
				cf = { holder.CFrame:GetComponents() },
				size = { holder.Size.X, holder.Size.Y, holder.Size.Z },
				face = if d:IsA("PointLight") then nil else d.Face.Name,
				color = color(d.Color),
				brightness = d.Brightness,
				range = d.Range,
				angle = if d:IsA("PointLight") then nil else d.Angle,
				shadows = d.Shadows,
			})
		elseif d:IsA("Beam") then
			local holder = d.Attachment0.Parent
			local a = holder.CFrame * d.Attachment0.Position
			local b = holder.CFrame * d.Attachment1.Position
			table.insert(beams, {
				a = { a.X, a.Y, a.Z },
				b = { b.X, b.Y, b.Z },
				w0 = d.Width0,
				w1 = d.Width1,
				color = color(d.Color.Keypoints[1].Value),
				alpha = 1 - d.Transparency.Keypoints[2].Value,
			})
		end
	end
	local camera = workspace.CurrentCamera
	fs.writeFile(
		partsPath,
		serde.encode("json", {
			parts = parts,
			lights = lights,
			beams = beams,
			variants = variants,
			camera = { camera.CFrame:GetComponents() },
		})
	)
	print(string.format("Wrote %s (%d parts, %d lights, %d beams)", partsPath, #parts, #lights, #beams))
end
