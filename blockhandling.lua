
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ServerModules = ServerScriptService.Modules
local BlockService = require(ServerModules.BlockService)
local Anticheat = require(ServerModules.Anticheat)

local Events = ReplicatedStorage.Events
local BlockBreak = Events.BlockBreak
local CoinAdditionEvent = Events.CoinAddition

local Service = script.Parent
local Componenets = Service.Components
local Configuration = Service.Configuration

local Modules = ReplicatedStorage.Modules

BlockService.RenewChanceTable()

local function blockDestroyed(Player, Block)
	
	local BlockName = Block.Name
	local BlocksAdded = 1 -- will be conciled with duplicated blocks later
	
	BlockService.UpdateOreInventory(Player, BlockName, BlocksAdded)
	BlockService.GenerateNewBlocks(Block.Core, Player.Character)
	BlockService.ReplaceMinedBlock(Block.Core)

	local stats = Player.leaderstats
	stats["Blocks Mined"].Value += 1
	
end

BlockBreak.OnServerInvoke = function(Player, Block)
	
	if not Anticheat:VerifyPlayerBreakIntegrity(Player) then
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
