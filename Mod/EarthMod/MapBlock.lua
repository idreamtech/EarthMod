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
	-- self:DB():flush({})
end

-- 添加地图模块
function MapBlock:addBlock(spx,spy,spz,color,isUpdate)
	local function insertBlock()
		BlockEngine:SetBlock(spx,spy,spz, MapBlock.ID, color) -- , nil, data
		-- self:DB():insertOne(nil, {world=DBStore.GetInstance().worldName,x=spx,y=spy,z=spz,type="map"})
	end
	if isUpdate then -- 为假时将不进入更新模式，而是全部重新绘制，为真时更新地图元素，不覆盖非地图元素
		if isUpdate == "fill" then -- 填充模式 填充非地图的草地模块
			if self:isMap(spx,spy,spz,true) then
				self:delete(spx,spy,spz)
				insertBlock()
				return true
			end
		else -- 更新模式
			if self:isMap(spx,spy,spz) then
				self:delete(spx,spy,spz)
				insertBlock()
				return true
			end
		end
		return false
	end
	insertBlock()
	-- local data = {attr={},{name="cmd","m"}} -- filename="Mod/EarthMod/textures/nil.fbx"
end

-- {attr={filename="Mod/EarthMod/textures/nil.fbx"},{name="cmd","map"}}
-- 检测是否是地图块
function MapBlock:isMap(spx,spy,spz,checkAir) -- ,func
	local from_id = BlockEngine:GetBlockId(spx,spy,spz);
	if from_id then
		if checkAir then
			if tonumber(from_id) == 0 then return true end -- 检测草地(id:62) 空气0
		else
			if tonumber(from_id) == MapBlock.ID then return true end
		end
	end
	return false
end

function MapBlock:cmd(str)
	CommandManager:RunCommand("/" .. str)
end

-- self:cmd("setblock " .. x .. " " .. y .. " " .. z .. " 0")
function MapBlock:delete(x,y,z)
	BlockEngine:SetBlockToAir(x,y,z)
end

-- 删除某区域内的地图元素 高,横向,竖向顺序：y,x,z
function MapBlock:deleteArea(po1,po2,blockID)
	po1 = {x=math.ceil(po1.x),y=math.ceil(po1.y),z=math.ceil(po1.z)}
	po2 = {x=math.ceil(po2.x),y=math.ceil(po2.y),z=math.ceil(po2.z)}
	blockID = blockID or MapBlock.ID
	for y = po1.y,po2.y do -- 垂直
		for x = po1.x,po2.x do -- 水平x
			for z = po1.z,po2.z do -- 水平y
				local id = BlockEngine:GetBlockId(x,y,z)
				if id and id == blockID then
					BlockEngine:SetBlockToAir(x,y,z)
				end
			end
		end
	end
end

-- self:DB():find({world=DBStore.GetInstance().worldName,x=spx,y=spy,z=spz}, function(err, data)  
-- 	if data.type == "map" then
-- 		func()
-- 	end
-- end);