-- CONFIGURATION
local BLOCK_SIZE = 5
-- This block size is used for raycasting

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local BlockServicing = ServerScriptService["Block Servicing"]
local BlockPrices = BlockServicing.Configuration
local Components = BlockServicing.Components

local Events = ReplicatedStorage.Events
local UpdateOre = Events.UpdateOre

local MinedBlock = Components.MinedBlock

local ServerMinedBlocks = workspace.Mine.Blocks.Mined
local ServerUnminedBlocks = workspace.Mine.Blocks.Unmined

local Blocks = ReplicatedStorage.Blocks

local Ceiling = 10000

local SetChances = {} -- Chance values will be evaluated later, this allows for dynamic expansion of chance tables without need for configuration of table each time
local ChanceTable = {}
local ItemList = {}

local function RenewChanceTable()
	local lastChance = 0
	for i,v in pairs(BlockPrices:GetChildren()) do
		if v.Name == "BLOCK_Stone" then continue end
		local chance = v.Value
		local chanceApplicable = Ceiling * (chance / 100) -- Takes percentage and appraises it in comparison to ceiling, then inputs into chance table.
		table.insert(ItemList, v.Name)
		lastChance += chanceApplicable
		ChanceTable[v.Name] = lastChance
	end
	table.insert(ItemList, "BLOCK_Stone")
	ChanceTable["BLOCK_Stone"] = Ceiling
	print(ItemList)
end

local function NewBlock()
	local itemChosen = nil
	local roll = math.random(0, Ceiling) -- Rolls random number from 0 to ceiling and finds first number that is greater
	for i, v in ipairs(ItemList) do
		if roll <= ChanceTable[v] then	
			return Blocks[v]
		end
	end
end

local function GenerateNewBlocks(Block, Character)
	local results = {}
	local origin = Block.Position
	local blockCFrame = Block.CFrame
	local rayLength = BLOCK_SIZE
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Block, Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local faceDirections = { -- Dictionary of all 6 faces of a cube
		Front = blockCFrame.LookVector,
		Back = -blockCFrame.LookVector,
		Top = blockCFrame.UpVector,
		Bottom = -blockCFrame.UpVector,
		Right = blockCFrame.RightVector,
		Left = -blockCFrame.RightVector
	}
	for faceName, direction in faceDirections do -- For each face, raycast out the length of one block, if something is there, don't place a block, else generate a new block next to it.
		local rayDir = direction * rayLength
		local result = workspace:Raycast(origin, rayDir, raycastParams)
		if not result then	
			local newBlockPosition = origin + (direction * BLOCK_SIZE)
			local chosenBlock = BlockService.NewBlock()
			local newBlock = chosenBlock:Clone()
			newBlock:SetPrimaryPartCFrame(CFrame.new(newBlockPosition))
			newBlock.Parent = Block.Parent.Parent
			local Health = Instance.new("IntValue", newBlock)
			local MaxHealth = Instance.new("IntValue", newBlock)
			Health.Name = "Health"
			MaxHealth.Name = "MaxHealth"
			Health.Value = BlockPrices:FindFirstChild(newBlock.Name).Health.Value
			MaxHealth.Value = BlockPrices:FindFirstChild(newBlock.Name).Health.Value
		end
	end
end

local function ReplaceMinedBlock(Broken) -- Places an invisible placeholder block for raycasting so previously mined blocks are not replaced
	local savedCFrame = Broken.CFrame
	local minedBlock = MinedBlock:Clone()
	minedBlock.CFrame = savedCFrame
	minedBlock.Parent = ServerMinedBlocks
	minedBlock.Anchored = true
	Broken.Parent:Destroy()
end

local function DeterminePriceFromBlock(Player, BlockName) -- Evaluates a block name and applied player's coin multiplier to its value
	local CoinMulti = Player.PlayerStats.CoinsMultiplier
	if BlockPrices[BlockName] then
		return BlockPrices[BlockName].Value * CoinMulti.Value
	end
end

local function UpdateOreInventory(Player, BlockName, AmountAdded) -- Keeps track of the ores that the player has mined, either making a new record or updating a previously existing one
	local OreInventory = Player.OreInventory
	local Ore = OreInventory:FindFirstChild(BlockName)

	if Ore then	
		Ore.Value += AmountAdded
	else
		local newValue = Instance.new("IntValue", OreInventory)
		newValue.Name = BlockName
		newValue.Value = AmountAdded
	end
	UpdateOre:FireClient(Player, BlockName)
end

local function ClearOreInventory(Player) -- Clears player's ore record
	local OreInventory = Player.OreInventory
	for _, Ore in pairs(OreInventory:GetChildren()) do
		if not Ore:IsA("IntValue") then continue end
		Ore:Destroy()
	end
end

local Events = ReplicatedStorage.Events
local BlockBreak = Events.BlockBreak
local CoinAdditionEvent = Events.CoinAddition

local Service = script.Parent
local Componenets = Service.Components
local Configuration = Service.Configuration

local Modules = ReplicatedStorage.Modules

BlockService.RenewChanceTable() -- generates chance table

local function blockDestroyed(Player, Block) -- Server event when a block is broken
	
	local BlockName = Block.Name
	local BlocksAdded = 1
	
	UpdateOreInventory(Player, BlockName, BlocksAdded)
	GenerateNewBlocks(Block.Core, Player.Character)
	ReplaceMinedBlock(Block.Core)

	local stats = Player.leaderstats
	stats.Coins.Value += DeterminePriceFromBlock(Player, BlockName)
	stats["Blocks Mined"].Value += 1
	
end

local TimeIntegrity = {}

local function VerifyPlayerBreakIntegrity(Player)
	local PlayerStats = Player.PlayerStats
	local MineSpeed = PlayerStats.MineSpeed
	if TimeIntegrity[Player.Name] then -- Keeps track of the last time a player broke a block and compares the difference in time to player's allowed mine speed
		local Last = TimeIntegrity[Player.Name]
		local Current = tick()
		if Current - Last < MineSpeed.Value then
			return false
		else
			TimeIntegrity[Player.Name] = Current
			return true
		end
	else
		TimeIntegrity[Player.Name] = tick()
		return true
	end
end

BlockBreak.OnServerInvoke = function(Player, Block) -- Function from fired client to mine a block
	if not VerifyPlayerBreakIntegrity(Player) then
		print(Player.Name .. " is breaking blocks to fast!")
		return false
	end
	
	local BlockMaxHealth = Block.MaxHealth.Value
	local BlockHealth = Block.Health
	BlockHealth.Value -= 1
	
	if BlockHealth.Value <= 0 then	
		blockDestroyed(Player, Block)	
	end
	
	return true
end

local miningData = DataStoreService:GetDataStore("MiningRNG")

Players.PlayerAdded:Connect(function(Player) -- Put all necessary values into player when they join
	local Leaderstats = Instance.new("Folder", Player)
	Leaderstats.Name = "leaderstats"
	local Coins = Instance.new("IntValue", Leaderstats)
	Coins.Name = "Coins"
	local BlocksMined = Instance.new("IntValue", Leaderstats)
	BlocksMined.Name = "Blocks Mined"
	local Rebirths = Instance.new("IntValue", Leaderstats)
	Rebirths.Name = "Rebirths"
	local PlayerStats = Instance.new("Folder", Player)
	PlayerStats.Name = "PlayerStats"
	local CoinsMultiplier = Instance.new("IntValue", PlayerStats)
	CoinsMultiplier.Name = "CoinsMultiplier"
	CoinsMultiplier.Value = 1
	local MineSpeed = Instance.new("IntValue", PlayerStats)
	MineSpeed.Name = "MineSpeed"
	MineSpeed.Value = 0.5
	local MineDamage = Instance.new("IntValue", PlayerStats)
	MineDamage.Name = "MineDamage"
	MineDamage.Value = 1
	local Storage = Instance.new("IntValue", PlayerStats)
	Storage.Name = "Storage"
	Storage.Value = 50
		
	-- loop through datastore and grab data
	local success, data = pcall(function()
		local playerData = {
			Coins = 0,
			BlocksMined = 0,
		}
		playerData.Coins = miningData:GetAsync(Player.UserId .. "_Coins")
		playerData.BlocksMined = miningData:GetAsync(Player.UserId .. "_BlocksMined")
		return playerData
	end)
	
	if success and data ~= {} then
		Coins.Value = data.Coins or 0
		BlocksMined.Value = data.BlocksMined or 0
	else	
		warn(data)	
	end
end)

Players.PlayerRemoving:Connect(function(Player)
	local playerData = {
		["Coins"] = 0,
		["BlocksMined"] = 0,
	}
	local leaderstats = Player.leaderstats
	playerData["Coins"] = leaderstats.Coins.Value
	playerData["BlocksMined"] = leaderstats["Blocks Mined"].Value
	
	for i, v in pairs(playerData) do
		miningData:SetAsync(Player.UserId .. "_" .. i, v)
	end
end)
