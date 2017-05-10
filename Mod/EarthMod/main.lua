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
NPL.load("(gl)Mod/EarthMod/NetManager.lua");
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
local NetManager = commonlib.gettable("Mod.EarthMod.NetManager");
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
	if ComVar.openNetwork then
		NetManager.init(handler(self,self.onGameEvent),handler(self,self.onReceiveMessage))
	end
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
	DBS = DBStore.GetInstance()
	SysDB = DBS:SystemDB()
	if not NetManager.isConnecting then -- 如果客户端连接则等待数据后启动页面
		self:initMap()
	end
end
-- called when a world is unloaded. 

-- 小地图网页窗口显示和销毁
function EarthMod.showWebPage(isShow)
	NPL.load("(gl)Mod/NplCefBrowser/NplCefWindowManager.lua");
	local NplCefWindowManager = commonlib.gettable("Mod.NplCefWindowManager");
	if not isShow then
		NplCefWindowManager:Destroy("my_window")
		echo("delete Cef web : my_window")
	else
		-- Open a new window when window haven't been opened,otherwise it will call the show function to show the window
		echo("open Cef web : " .. "http://127.0.0.1:" .. ComVar.prot .. "/earth")
		NplCefWindowManager:Open("my_window", "Select Location Window", "http://127.0.0.1:" .. ComVar.prot .. "/earth", "_lt", 5, 70, 400, 400);		
	end
end

function EarthMod:OnDestroy()
end

-- 游戏事件 local:本地登录，server:服务器连接成功，client:客户端连接成功
function EarthMod:onGameEvent(event)
	echo("游戏事件:" .. event)
	if event == "local" then
	elseif event == "client" then
		NetManager.sendMessage("admin","reqDb")
	elseif event == "server" then
		TipLog("开启了服务器")
	end
end

-- 消息处理 {name,key,value,delay}
function EarthMod:onReceiveMessage(data)
	-- common info
	if data.key == "leave" then
		SelectLocationTask.allPlayerPo[data.value] = nil
		echo("player leave: " .. data.value)
		NetManager.showMsg("玩家 " .. data.value .. " 离开了游戏")
	elseif data.key == "enter" then
		echo("player enter: " .. data.value)
		NetManager.showMsg("玩家 " .. data.value .. " 进入了游戏")
	end
	-- 
	if NetManager.connectState == "server" then -- 服务端
		if data.key == "reqDb" then
			echo("NetManager:服务器接收客户端的配置请求，发送配置信息")
			self:sendSysmDB(data,handler(self,self.sendConfigDB))
		elseif data.key == "cl_po" then
			-- 服务端接收到客户端的人物坐标信息之后,将其添加到全玩家坐标信息table中
			SelectLocationTask:setPlayerPoTableData(data.name, table.fromJson(data.value))			
		end
	elseif NetManager.connectState == "client" then -- 客户端
		if data.key == "sysData" then
			DBS:unpackDatabase(data.value,SysDB)
			echo("NetManager:客户端接收并拷贝服务器的系统数据库SysDB")
		elseif data.key == "cfgData" then
			DBS:unpackDatabase(data.value,DBS:ConfigDB())
			echo("NetManager:客户端接收并拷贝服务器的配置数据库ConfigDB")
			self:initMap()
			SelectLocationTask.OnClickConfirm()
			table.remove(SelectLocationTask.menus,3)
			SelectLocationTask:ShowPage()
			EarthMod.showWebPage(true)
			ItemEarth:boundaryCheck()
		elseif data.key == "all_po" then
			-- 接收到所有玩家的位置信息
			SelectLocationTask.allPlayerPo = table.fromJson(data.value)
		end
	end
end

-- 发送系统数据库给客户端
function EarthMod:sendSysmDB(data,func)
	local arr = {"alreadyBlock","schoolName","coordinate","boundary"}
	DBS:packDatabase(SysDB,arr,function(str)
		NetManager.sendMessage(data.name,"sysData",str)
		if func then func(data) end
	end)
end

-- 发送配置数据库给客户端
function EarthMod:sendConfigDB(data)
	local arr = {"alreadyBlock","schoolName","coordinate","boundary"}
	DBS:packDatabase(DBS:ConfigDB(),nil,function(str)
		NetManager.sendMessage(data.name,"cfgData",str)
	end)
end

function EarthMod:initMap(func)
	TileManager:new() -- 初始化并加载数据
	-- 检测是否是读取存档
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
				System.os.GetUrl({url = "http://119.23.36.48:8098/api/wiki/models/school/getSchoolByName", form = {name=schoolName,} }, function(err, msg, res)
<<<<<<< HEAD
				--System.os.GetUrl({url = "http://192.168.1.160:8098/api/wiki/models/school/getSchoolByName", form = {name=schoolName,} }, function(err, msg, res)
=======
>>>>>>> 4d3c9581e9bd9e6b63382b04deed741b0cd3f825
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
		                	if func then func() end
		                else
		                	echo("call initworld")
		                	gisToBlocks:initWorld()
		                	if func then func() end
		                end
		            else
		            	gisToBlocks:initWorld()
		                if func then func() end
		            end
				end);
			end end)
			-- 从文件读取学校名称,由于字符串数据自带双引号,所以需要替换掉
			-- local schoolName = EarthMod:GetWorldData("schoolName");
			-- echo("school name is : "..schoolName)
		end end)
	else
		if func then func() end
	end end)
end


function EarthMod:OnLeaveWorld()
	echo("On Leave World")
	if TileManager.GetInstance() then
		MapBlock:OnLeaveWorld()
		gisToBlocks:OnLeaveWorld()
		EarthMod.showWebPage()
		-- 离开当前世界时候初始化所有变量
		echo("sltInstance set nil")
		SelectLocationTask:OnLeaveWorld();
  		ItemEarth:OnLeaveWorld();
  		DBStore:OnLeaveWorld();
  		if ComVar.openNetwork then
			NetManager.OnLeaveWorld()
		end
		DBS = nil
		SysDB = nil
	end
end