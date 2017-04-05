--[[
Title: MapBlock
Author(s):  Bl.Chock
Date: 2017年4月1日
Desc: map block item
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/MapBlock.lua");
local MapBlock = commonlib.gettable("Mod.EarthMod.MapBlock");
------------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/blocks/block_types.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types");
local MapBlock = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.MapBlock"));
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
local CommandManager  = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");

MapBlock.ID = 2333

function MapBlock:ctor()
end

function MapBlock:init()
	LOG.std(nil, "info", "MapBlock", "init");
	-- customblocks desc="ID must be in range:2000-5000"
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot) 
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");
		if(blocks) then
			blocks[#blocks+1] = {name="block", attr={
				singleSideTex="true",
				name="MapBlock",
				id=MapBlock.ID,
				item_class="ItemColorBlock", -- 这个决定了颜色方块显示(来自彩色方块10)
				text="地图方块",
				searchkey="地图方块",
				disable_gen_icon="true",
				icon="Texture/blocks/items/color_block.png",
				texture="Texture/blocks/colorblock.png",
				color_data="true",
				obstruction="true",
				solid="true",
				cubeMode="true",
				-- 这个决定了是否能存储entity(来自物理模型22)
				-- class="BlockModel",
				-- entity_class="EntityBlockModel",
				-- hasAction="false",

				-- class="BlockCommandBlock",
				-- entity_class="EntityCommandBlock",
			}}
			LOG.std(nil, "info", "MapBlock", "a new block is registered");
		end
		return xmlRoot;
	end)

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot) 
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool") then
				node[#node+1] = {name="block", attr={name="MapBlock"}};
			end
		end
		return xmlRoot;
	end)
end

function MapBlock:OnWorldLoad()
	if(self.isInited) then
		return 
	end
	self.isInited = true;
end

function MapBlock:DB()
	return DBStore.GetInstance():MapDB()
end

function MapBlock:OnLeaveWorld()
	self:DB():flush({})
end

-- 添加地图模块
function MapBlock:addBlock(spx,spy,spz,color,isUpdate)
	local function insertBlock()
		BlockEngine:SetBlock(spx,spy,spz, MapBlock.ID, color) -- , nil, data
		self:DB():insertOne(nil, {world=DBStore.GetInstance().worldName,x=spx,y=spy,z=spz,type="map"})
	end
	if isUpdate then -- 为假时将不进入更新模式，而是全部重新绘制，为真时更新地图元素，不覆盖非地图元素
		self:isMap(spx,spy,spz,function()
			self:delete(spx,spy,spz)
			insertBlock()
		end)
		return
	end
	insertBlock()
	-- local data = {attr={},{name="cmd","m"}} -- filename="Mod/EarthMod/textures/nil.fbx"
end

-- {attr={filename="Mod/EarthMod/textures/nil.fbx"},{name="cmd","map"}}
-- 检测是否是地图
function MapBlock:isMap(spx,spy,spz,func)
	self:DB():find({world=DBStore.GetInstance().worldName,x=spx,y=spy,z=spz}, function(err, data)  
		if data.type == "map" then
			func()
		end
	end);
	-- local entityData = BlockEngine:GetBlockEntityData(spx,spy,spz);
	-- if entityData == nil then return end
	-- local ism = false
	-- if entityData[1][1] == "m" then ism = true end
	-- return ism,entityData
end

function MapBlock:cmd(str)
	CommandManager:RunCommand("/" .. str)
end

-- self:cmd("setblock " .. x .. " " .. y .. " " .. z .. " 0")
function MapBlock:delete(x,y,z)
	BlockEngine:SetBlockToAir(x,y,z)
end