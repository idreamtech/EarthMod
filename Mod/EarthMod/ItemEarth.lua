--[[
Title: ItemEarth
Author(s): big
Date: 2017/2/8
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/ItemEarth.lua");
local ItemEarth = commonlib.gettable("MyCompany.Aries.Game.Items.ItemEarth");
-------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/main.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemBlockModel.lua");
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/OpenFileDialog.lua");
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");

local ItemBlockModel     = commonlib.gettable("MyCompany.Aries.Game.Items.ItemBlockModel");
local ItemEarth          = commonlib.inherit(ItemBlockModel, commonlib.gettable("MyCompany.Aries.Game.Items.ItemEarth"));

local EarthMod           = commonlib.gettable("Mod.EarthMod");
local gisCommand         = commonlib.gettable("Mod.EarthMod.gisCommand");
local block_types        = commonlib.gettable("MyCompany.Aries.Game.block_types")
local ItemStack          = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local OpenFileDialog     = commonlib.gettable("MyCompany.Aries.Game.GUI.OpenFileDialog");
local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
local CommandManager     = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local DBS,SysDB

block_types.RegisterItemClass("ItemEarth", ItemEarth);

function ItemEarth:ctor()
	self:SetOwnerDrawIcon(true);
end

local fromPort = 8081
function ItemEarth.checkPortRunWeb(port,func)
	System.os.GetUrl(
	{url = "http://localhost:" .. port .. "/ajax/console?action=getparams" },
	function(err, msg, data)
		if data and data.action == "getparams" then
			echo("find the next port:" .. (port + 1))
			ItemEarth.checkPortRunWeb(port + 1,func)
		else
			echo("got the port and start web:" .. port)
			ComVar.prot = port
			WebServer:Start("script/apps/WebServer/admin", "0.0.0.0", ComVar.prot);
			if func then func() end
		end
	end);
end

function ItemEarth.onInitWeb(func)
	echo("ItemEarth.onInitWeb : " .. tostring(WebServer:IsStarted()))
	if(not WebServer:IsStarted()) then
		ItemEarth.checkPortRunWeb(fromPort,func)
	else 
		func()
	end
end

function ItemEarth:OnSelect(itemStack)
	ItemEarth._super._super.OnSelect(self,itemStack);
	-- TipLog("startmap ItemEarth:protInited " .. tostring(ComVar.protInited))
	if ComVar.protInited == nil then
		ComVar.protInited = true
		ItemEarth.onInitWeb(function()
			echo("ItemEarth:OnSelect to SelectLocationTask:OnShowMap")
			SelectLocationTask.OnShowMap()
		end)
		echo("startmap ItemEarth:OnSelect")
		-- TipLog("startmap ItemEarth:OnSelect")
	end
	if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
	DBS:getValue(SysDB,"alreadyBlock",function(alreadyBlock) if alreadyBlock then
		DBS:getValue(SysDB,"coordinate",function(coordinate) if coordinate then
			CommandManager:RunCommand("/gis -already " .. coordinate.minlat .. " " .. coordinate.minlon.. " " .. coordinate.maxlat.. " " .. coordinate.maxlon);
			self:boundaryCheck();
		end end)
	end end)
end

function ItemEarth:TryCreate(itemStack, entityPlayer, x, y, z, side, data, side_region)
	if(SelectLocationTask.isFirstSelect) then
		_guihelper.MessageBox(L"您还没有选定待生成地理贴图信息的学校");
		return;
	end

	DBS:getValue(SysDB,"alreadyBlock",function(alreadyBlock) if alreadyBlock then
		-- _guihelper.MessageBox(L"地图已生成");
	else
		_guihelper.MessageBox(L"点击确认后开始地图绘制", function(res)
			if(res and res == _guihelper.DialogResult.Yes) then
				-- if(EarthMod:GetWorldData("alreadyBlock") == nil or EarthMod:GetWorldData("alreadyBlock") == false) then
				-- 	EarthMod:SetWorldData("alreadyBlock",true);
				-- end
				DBS:setValue(SysDB,"alreadyBlock",true);
				local gisCommandText = "/gis -coordinate " .. SelectLocationTask.minlat .. " " .. SelectLocationTask.minlon.." ".. SelectLocationTask.maxlat .. " " .. SelectLocationTask.maxlon;
		
				if(SelectLocationTask.isChange)then
					SelectLocationTask.isChange = false;
					gisCommandText = gisCommandText .. " -cache true";
				else
					gisCommandText = gisCommandText .. " -cache false";
				end

				CommandManager:RunCommand(gisCommandText);
				self:boundaryCheck();
			end
		end, _guihelper.MessageBoxButtons.YesNo);
	end end)
	-- if(EarthMod:GetWorldData("alreadyBlock")) then
	-- 	_guihelper.MessageBox(L"地图已生成");
	-- 	return;
	-- end
end

-- return true if items are the same. 
-- @param left, right: type of ItemStack or nil. 
function ItemEarth:CompareItems(left, right)
--	if(self._super.CompareItems(self, left, right)) then
--		if(left and right and left:GetTooltip() == right:GetTooltip()) then
--			return true;
--		end
--	end
end

function ItemEarth:boundaryCheck()
	ItemEarth.BoundaryTimer = ItemEarth.BoundaryTimer or commonlib.Timer:new({callbackFunc = function(timer)
			CommandManager:RunCommand("/gis -boundary");
			--echo(gisCommand.getMoreTiles);
			SelectLocationTask.getMoreTiles = gisCommand.getMoreTiles;
			SelectLocationTask.RefreshPage();
		end});

	ItemEarth.BoundaryTimer:Change(300, 300);
end

function ItemEarth:MoreScence()
	CommandManager:RunCommand("/gis -more -cache true");
end

function ItemEarth:OnDeSelect()
	ItemEarth._super.OnDeSelect(self);
	GameLogic.SetStatus(nil);
end

-- called whenever this item is clicked on the user interface when it is holding in hand of a given player (current player). 
function ItemEarth:OnClickInHand(itemStack, entityPlayer)
	-- if there is selected blocks, we will replace selection with current block in hand. 
	if(GameLogic.GameMode:IsEditor()) then
		
	end
end

function ItemEarth:GoToMap()
	-- self.alreadyBlock = false;
	-- CommandManager:RunCommand("/gis -undo");

	-- local url = "npl://earth";
	-- GameLogic.RunCommand("/open " .. url);
	-- call cefBrowser to open website
	-- echo("WebServer is Started : "..WebServer:IsStarted())
	-- if(not WebServer:IsStarted()) then
	-- 	GameLogic.SetStatus(L"GoToMap : Start Server");
	-- 	--start server
	-- 	WebServer:Start("script/apps/WebServer/admin", "127.0.0.1", 8099);

	-- 	NPL.load("(gl)Mod/NplCefBrowser/NplCefWindowManager.lua");
	-- 	local NplCefWindowManager = commonlib.gettable("Mod.NplCefWindowManager");
	-- 	-- Open a new window
	-- 	NplCefWindowManager:Open("my_window", "Select Location Window", "http://localhost:8099/earth", "_lt", 100, 100, 800, 560);
	-- else
	-- 	GameLogic.SetStatus(L"GoToMap : Show Browser");

	-- 	NPL.load("(gl)Mod/NplCefBrowser/NplCefWindowManager.lua");
	-- 	local NplCefWindowManager = commonlib.gettable("Mod.NplCefWindowManager");
	-- 	NplCefWindowManager:Show("my_window", true);
	-- end
end

function ItemEarth:Cancle()
	self.alreadyBlock = false;
	CommandManager:RunCommand("/gis -undo");
end

function ItemEarth:RefreshTask(itemStack)
	local task = self:GetTask();
	if(task) then
		task:SetItemStack(itemStack);
		task.RefreshPage();
	end
end

function ItemEarth:CreateTask(itemStack)
	local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
	local task = SelectLocationTask:new();
	task:SetItemStack(itemStack);
	return task;
end

function ItemEarth:OnLeaveWorld()
  	-- 离开当前世界时候重新初始化变量
  	self.alreadyBlock = false;
  	DBS = nil
  	SysDB = nil
  	if ItemEarth.BoundaryTimer then ItemEarth.BoundaryTimer:Change(); ItemEarth.BoundaryTimer = nil end
end