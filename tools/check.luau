--[[
	Smoke test for the room: builds it, then runs its two game scripts (ThroneRoomServer and
	ThroneRoomFX) in Lune with small stand-ins for the engine features Lune lacks (signals,
	pivots, players, the sun). Every property the scripts set is checked against Roblox's API
	database, so a typo or a wrong type fails here instead of in Studio.

	From roblox/asgore-throne-room:
	    lune run tools/check
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Instance, Vector3 = roblox.Instance, roblox.Vector3

local DATATYPES = {
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
}

local failures = 0
local function check(ok, message)
	print((ok and "  ok   " or "  FAIL ") .. message)
	if not ok then
		failures += 1
	end
end

-- stand-ins ---------------------------------------------------------------------------------

local signals = {}
local function signalFor(instance, name)
	local key = instance:GetFullName() .. "." .. name
	if not signals[key] then
		local handlers = {}
		signals[key] = {
			Connect = function(_, fn)
				table.insert(handlers, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_, ...)
				for _, fn in handlers do
					fn(...)
				end
			end,
		}
	end
	return signals[key]
end

local pivots = 0
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild would wait forever for " .. self:GetFullName() .. "." .. name)
	return child
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	return if self.PrimaryPart then self.PrimaryPart.CFrame else self.WorldPivot
end)
roblox.implementMethod("Model", "PivotTo", function()
	pivots += 1
end)
roblox.implementProperty("ProximityPrompt", "Triggered", function(self)
	return signalFor(self, "Triggered")
end)
roblox.implementProperty("RunService", "RenderStepped", function(self)
	return signalFor(self, "RenderStepped")
end)
roblox.implementMethod("Sound", "Play", function() end)
local fills = 0
roblox.implementMethod("Terrain", "FillBlock", function(_, cframe, size, material)
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "terrain strip has no size")
	assert(material == roblox.Enum.Material.Grass, "terrain strip isn't grass")
	fills += 1
end)
roblox.implementMethod("Terrain", "SetMaterialColor", function() end)
-- Any smooth sun path will do: what matters is that aimSun can steer it.
roblox.implementMethod("Lighting", "GetSunDirection", function(self)
	local t = (self.ClockTime - 6) / 12 * math.pi
	local lat = math.rad(self.GeographicLatitude)
	return Vector3.new(math.cos(t), math.sin(t) * math.cos(lat), math.sin(t) * math.sin(lat)).Unit
end)

local player = Instance.new("Player")
player.Name = "Frisk"
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
local character = Instance.new("Model")
character.Name = "Frisk"
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
player.Character = character

-- build ----------------------------------------------------------------------------------------

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
player.Parent = players
players.LocalPlayer = player
Instance.new("Terrain").Parent = workspace
local function environment(extra)
	local env = { game = game, workspace = workspace }
	for _, name in DATATYPES do
		env[name] = roblox[name]
	end
	for k, v in extra or {} do
		env[k] = v
	end
	return env
end

print("Building the room")
local source = fs.readFile("src/ThroneRoomBuilder.luau")
local room = luau.load(source, { debugName = "ThroneRoomBuilder", environment = environment({ __LUNE = true }) })()
local lighting = game:GetService("Lighting")
local preset = room:FindFirstChild("LightingPreset")

check(lighting.Technology == roblox.Enum.Technology.Future, "Lighting.Technology is Future")
check(lighting:FindFirstChildOfClass("Atmosphere") ~= nil, "post effects copied into Lighting")
local toward = preset:GetAttribute("SunToward")
check(lighting:GetSunDirection():Dot(toward) > 0.97, "builder aimed the sun through the window")
check(room:FindFirstChild("SavePrompt", true) ~= nil, "save point has its prompt")
check(#game:GetService("MaterialService"):GetChildren() == 0, "no textures uploaded: built-in materials only")
local plan = room:FindFirstChild("TerrainPlan")
check(plan ~= nil and #plan.Value > 100, "terrain grass plan saved for the server")

-- scripts --------------------------------------------------------------------------------------

local guiSeen = false
local fakeTask = {
	wait = function() -- the dialog box is on screen whenever the script waits
		local gui = playerGui:FindFirstChild("SaveDialog")
		guiSeen = guiSeen or (gui ~= nil and gui:FindFirstChildOfClass("Frame") ~= nil)
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
}
local function run(name)
	local s = room:FindFirstChild(name)
	assert(s, name .. " is missing")
	luau.load(s.Source, { debugName = name, environment = environment({ script = s, task = fakeTask }) })()
	return s
end

print("Running ThroneRoomServer")
lighting.ClockTime, lighting.GeographicLatitude = 12, 0
lighting:ClearAllChildren()
local server = run("ThroneRoomServer")
check(server.RunContext == roblox.Enum.RunContext.Server, "server script runs on the server")
check(lighting:FindFirstChildOfClass("BloomEffect") ~= nil, "server applied the post effects")
check(lighting:GetSunDirection():Dot(toward) > 0.97, "server aimed the sun through the window")
check(fills > 50 and room:GetAttribute("TerrainBuilt") == true, "server grew the terrain grass (" .. fills .. " strips)")

print("Running ThroneRoomFX")
room:SetAttribute("MusicId", "1234567890")
local fx = run("ThroneRoomFX")
local music = game:GetService("SoundService"):FindFirstChild("ThroneRoomMusic")
check(music ~= nil and music.SoundId == "rbxassetid://1234567890", "MusicId starts the music")
check(fx.RunContext == roblox.Enum.RunContext.Client, "FX script runs on clients")
signalFor(game:GetService("RunService"), "RenderStepped"):Fire(1 / 60)
check(pivots == 1, "save point moves each frame")

humanoid.Health = 10
local prompt = room:FindFirstChild("SavePrompt", true)
signalFor(prompt, "Triggered"):Fire(player)
check(guiSeen, "saving shows the dialog box")
check(playerGui:FindFirstChild("SaveDialog") == nil, "the dialog box closes afterwards")
check(humanoid.Health == humanoid.MaxHealth, "saving restores health")

-- with textures --------------------------------------------------------------------------------

print("Building with every texture uploaded")
local ids = {}
for i, file in fs.readDir("textures") do
	local name = file:match("^(.+)%.png$")
	if name then
		ids[name] = "rbxassetid://" .. (1000 + i)
	end
end
local game2 = Instance.new("DataModel")
local env2 = environment({ __LUNE = true, __PREVIEW_TEXTURES = ids })
env2.game, env2.workspace = game2, game2:GetService("Workspace")
local room2 = luau.load(source, { debugName = "ThroneRoomBuilder", environment = env2 })()
local variants = game2:GetService("MaterialService"):GetChildren()
check(#variants == 12, "12 MaterialVariants made (" .. #variants .. ")")
local textured, decals, textures = 0, 0, 0
for _, d in room2:GetDescendants() do
	if d:IsA("BasePart") and d.MaterialVariant ~= "" then
		textured += 1
	elseif d.ClassName == "Decal" then
		decals += 1
	elseif d.ClassName == "Texture" then
		textures += 1
	end
end
check(textured > 1500, "parts use the textured materials (" .. textured .. ")")
check(decals > 1000, "ivy and grass cut-outs placed (" .. decals .. " decals)")
check(textures > 50, "grime and glass textures placed (" .. textures .. ")")
local wall = room2.Architecture.Walls:FindFirstChildWhichIsA("BasePart")
check(wall.MaterialVariant == "ThroneRoom_plaster", "walls are plaster")

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("All checks passed")
