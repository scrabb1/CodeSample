local BlockService = {}

-- CONFIGURATION
local BLOCK_SIZE = 5
--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

local SetChances = {}
local ChanceTable = {}
local ItemList = {}

function BlockService.RenewChanceTable()
	
	local lastChance = 0
	
	for i,v in pairs(BlockPrices:GetChildren()) do
		
		if v.Name == "BLOCK_Stone" then continue end
		
		local chance = v.Value

		local chanceApplicable = Ceiling * (chance / 100)
		
		table.insert(ItemList, v.Name)
		lastChance += chanceApplicable
		ChanceTable[v.Name] = lastChance

	end
	
	table.insert(ItemList, "BLOCK_Stone")
	ChanceTable["BLOCK_Stone"] = Ceiling
	
	print(ItemList)
	
end

function BlockService.NewBlock()

	local itemChosen = nil
	local roll = math.random(0, Ceiling)

	for i, v in ipairs(ItemList) do

		if roll <= ChanceTable[v] then
			
			return Blocks[v]

		end

	end

end

function BlockService.GenerateNewBlocks(Block, Character)

	local results = {}
	local origin = Block.Position
	local blockCFrame = Block.CFrame
	local rayLength = BLOCK_SIZE

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Block, Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local faceDirections = {
		Front = blockCFrame.LookVector,
		Back = -blockCFrame.LookVector,
		Top = blockCFrame.UpVector,
		Bottom = -blockCFrame.UpVector,
		Right = blockCFrame.RightVector,
		Left = -blockCFrame.RightVector
	}

	for faceName, direction in faceDirections do
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

function BlockService.ReplaceMinedBlock(Broken)
	
	local savedCFrame = Broken.CFrame
	local minedBlock = MinedBlock:Clone()
	minedBlock.CFrame = savedCFrame
	minedBlock.Parent = ServerMinedBlocks
	minedBlock.Anchored = true
	
	Broken.Parent:Destroy()
	
end

function BlockService.DeterminePriceFromBlock(Player, BlockName)

	local CoinMulti = Player.PlayerStats.CoinsMultiplier

	if BlockPrices[BlockName] then

		return BlockPrices[BlockName].Value * CoinMulti.Value

	end

end

function BlockService.UpdateOreInventory(Player, BlockName, AmountAdded)
	
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

function BlockService.ClearOreInventory(Player)
	
	local OreInventory = Player.OreInventory
	
	for _, Ore in pairs(OreInventory:GetChildren()) do
		
		if not Ore:IsA("IntValue") then continue end
		
		Ore:Destroy()
		
	end
	
end


return BlockService

