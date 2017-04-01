--[[
Title: Earth Mod
Author(s):  big
Date: 2017/1/24
Desc: Earth Mod
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/EarthSceneContext.lua");
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");
NPL.load("(gl)Mod/EarthMod/ItemEarth.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)script/apps/WebServer/WebServer.lua");
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
NPL.load("(gl)Mod/EarthMod/MapBlock.lua");

local EarthMod       = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));
local gisCommand     = commonlib.gettable("Mod.EarthMod.gisCommand");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
local MapBlock = commonlib.gettable("Mod.EarthMod.MapBlock");
--LOG.SetLogLevel("DEBUG");
EarthMod:Property({"Name", "EarthMod"});

function EarthMod:ctor()
end

-- virtual function get mod name

function EarthMod:GetName()
	return "EarthMod"
end

-- virtual function get mod description 

function EarthMod:GetDesc()
	return "EarthMod is a plugin in paracraft"
end

function EarthMod:init()
	LOG.std(nil, "info", "EarthMod", "plugin initialized");

	-- register a new block item, id < 10513 is internal items, which is not recommended to modify. 
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot)
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");

		if(blocks) then
			blocks[#blocks+1] = {name="block", attr = {name="Earth",
				id = 10513, item_class="ItemEarth", text="NPL Earth",
				icon = "Mod/EarthMod/textures/icon.png",
			}}
			LOG.std(nil, "info", "Earth", "Earth block is registered");
		end

		return xmlRoot;
	end);

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot)
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool") then
				node[#node+1] = {name="block", attr={name="Earth"} };
			end
		end
		return xmlRoot;
	end)
	MapBlock:init()
end

function EarthMod:OnLogin()
end

-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
	LOG.std(nil, "info", "EarthMod", "OnNewWorld");

	CommandManager:RunCommand("/take 10513");

	if(EarthMod:GetWorldData("alreadyBlock")) then
		-- CommandManager:RunCommand("/take 10513");
	end
	
	MapBlock:OnWorldLoad();

	assert("TileManager new")
	TileManager:new() -- 初始化并加载数据
	TileManager.GetInstance():Load() -- 加载配置
	-- if not  then
	-- 	-- gisToBlocks:refrushPlayerInfo()
	-- end

end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
	if TileManager.GetInstance() then
		MapBlock:OnLeaveWorld()
	end
end

function EarthMod:OnDestroy()
end
