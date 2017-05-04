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
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)script/apps/WebServer/WebServer.lua");
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
NPL.load("(gl)Mod/EarthMod/MapBlock.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
NPL.load("(gl)Mod/EarthMod/Com.lua"); -- 导入全局函数变量
require("Mod/EarthMod/Com.lua")

local EarthMod       = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));
local gisCommand     = commonlib.gettable("Mod.EarthMod.gisCommand");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
local MapBlock = commonlib.gettable("Mod.EarthMod.MapBlock");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local DBS,SysDB
local gisToBlocks = commonlib.gettable("MyCompany.Aries.Game.Tasks.gisToBlocks");
local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
local ItemEarth = commonlib.gettable("MyCompany.Aries.Game.Items.ItemEarth");
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
				id = 10513, item_class="ItemEarth", text="虚拟校园贴图",
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
	-- add net Filter
	MapBlock:init()
end

function EarthMod:OnLogin()
end

-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
	LOG.std(nil, "info", "EarthMod", "OnNewWorld");
	CommandManager:RunCommand("/take 10513");
	-- if(EarthMod:GetWorldData("alreadyBlock")) then
	-- 	-- CommandManager:RunCommand("/take 10513");
	-- end
	MapBlock:OnWorldLoad();

	TileManager:new() -- 初始化并加载数据
	-- 检测是否是读取存档
	DBS = DBStore.GetInstance()
	SysDB = DBS:SystemDB()
	DBS:getValue(SysDB,"alreadyBlock",function(alreadyBlock) if alreadyBlock then
		DBS:getValue(SysDB,"coordinate",function(coordinate) if coordinate then
			TileManager.GetInstance():Load() -- 加载配置
			-- local coordinate = EarthMod:GetWorldData("coordinate");
			gisToBlocks.minlat = coordinate.minlat
			gisToBlocks.minlon = coordinate.minlon
			gisToBlocks.maxlat = coordinate.maxlat
			gisToBlocks.maxlon = coordinate.maxlon
			DBS:getValue(SysDB,"schoolName",function(schoolName) if schoolName then
				schoolName = string.gsub(schoolName, "\"", "");
				-- 根据学校名称调用getSchoolByName接口,请求最新的经纬度范围信息,如果信息不一致,则更新文件中已有数据
				System.os.GetUrl({url = "http://192.168.1.160:8098/api/wiki/models/school/getSchoolByName", form = {name=schoolName,} }, function(err, msg, res)
					if(res and res.error and res.data and res.data ~= {} and res.error.id == 0) then
		                -- 获取经纬度信息,如果获取到的经纬度信息不存在,需要提示用户
		                -- echo("getSchoolByName by name : ")
		                -- echo(res.data)
		                local areaInfo = res.data[1];
		                -- 如果查询到的最新的经纬度范围不等于原有的范围,则更新已有tileManager信息
		                -- echo(areaInfo.southWestLng .. " , " .. areaInfo.southWestLat .. " , " .. areaInfo.northEastLng .. " , " .. areaInfo.northEastLat)
		                -- echo(tostring(tonumber(areaInfo.southWestLng) ~= tonumber(coordinate.minlon)) .. " , " .. tostring(tonumber(areaInfo.southWestLat) ~= tonumber(coordinate.minlat)) .. " , " .. tostring(tonumber(areaInfo.northEastLng) ~= tonumber(coordinate.maxlon)) .. " , " .. tostring(tonumber(areaInfo.northEastLat) ~= tonumber(coordinate.maxlat)))
		                if areaInfo and areaInfo.southWestLng and areaInfo.southWestLat and areaInfo.northEastLng and areaInfo.northEastLat 
		                	and (tonumber(areaInfo.southWestLng) ~= tonumber(coordinate.minlon) or tonumber(areaInfo.southWestLat) ~= tonumber(coordinate.minlat) 
		                	or tonumber(areaInfo.northEastLng) ~= tonumber(coordinate.maxlon) or tonumber(areaInfo.northEastLat) ~= tonumber(coordinate.maxlat)) then
		                	gisToBlocks.minlat = areaInfo.southWestLat
							gisToBlocks.minlon = areaInfo.southWestLng
							gisToBlocks.maxlat = areaInfo.northEastLat
							gisToBlocks.maxlon = areaInfo.northEastLng
							echo("call reInitWorld")
							-- 更新原有坐标信息
							DBS:setValue(SysDB,"coordinate",{minlat=tostring(gisToBlocks.minlat),minlon=tostring(gisToBlocks.minlon),maxlat=tostring(gisToBlocks.maxlat),maxlon=tostring(gisToBlocks.maxlon)});
							DBS:flush(SysDB)
							-- EarthMod:SetWorldData("coordinate",{minlat=tostring(gisToBlocks.minlat),minlon=tostring(gisToBlocks.minlon),maxlat=tostring(gisToBlocks.maxlat),maxlon=tostring(gisToBlocks.maxlon)});
							-- EarthMod:SaveWorldData();
		                	gisToBlocks:reInitWorld()
		                else
		                	echo("call initworld")
		                	gisToBlocks:initWorld()
		                end
		            else
		            	gisToBlocks:initWorld()
		            end
				end);
			end end)
			-- 从文件读取学校名称,由于字符串数据自带双引号,所以需要替换掉
			-- local schoolName = EarthMod:GetWorldData("schoolName");
			-- echo("school name is : "..schoolName)
		end end)
	end end)
	-- if EarthMod:GetWorldData("alreadyBlock") and EarthMod:GetWorldData("coordinate") then
	-- end
end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
	echo("On Leave World")
	if TileManager.GetInstance() then
		MapBlock:OnLeaveWorld()
		gisToBlocks:OnLeaveWorld()
		NPL.load("(gl)Mod/NplCefBrowser/NplCefWindowManager.lua");
		local NplCefWindowManager = commonlib.gettable("Mod.NplCefWindowManager");
		NplCefWindowManager:Destroy("my_window");
		-- 离开当前世界时候初始化所有变量
		echo("sltInstance set nil")
		SelectLocationTask:OnLeaveWorld();
  		ItemEarth:OnLeaveWorld();
  		DBStore:OnLeaveWorld();
		DBS = nil
		SysDB = nil
	end
end

function EarthMod:OnDestroy()
end
