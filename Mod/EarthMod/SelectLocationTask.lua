--[[
Title: SelectLocation Task/Command
Author(s): big
Date: 2017/2/9
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
local task = SelectLocationTask:new();
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/main.lua");
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");

local SelectLocationTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask"));
local EarthMod           = commonlib.gettable("Mod.EarthMod");
local gisToBlocks = commonlib.gettable("MyCompany.Aries.Game.Tasks.gisToBlocks");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local DBS,SysDB

SelectLocationTask:Property({"LeftLongHoldToDelete", false, auto=true});

local curInstance;

SelectLocationTask.isFirstSelect = true;
-- this is always a top level task. 
SelectLocationTask.is_top_level  = true;
SelectLocationTask.getMoreTiles  = false;

-- 人物坐标对应经纬度
SelectLocationTask.playerLon  = nil;
SelectLocationTask.playerLat  = nil;
SelectLocationTask.player_curLon = nil;
SelectLocationTask.player_curLat = nil;
SelectLocationTask.player_curState = nil;
SelectLocationTask.isDownLoaded = nil
SelectLocationTask.schoolData = nil
SelectLocationTask.isShowInfo = nil
SelectLocationTask.playerInfo = {}

function SelectLocationTask:ctor()
end

function SelectLocationTask:SetItemStack(itemStack)
	self.itemStack = itemStack;
end

function SelectLocationTask:GetItemStack()
	return self.itemStack;
end

local page;
function SelectLocationTask.InitPage(Page)
	page = Page;
end

function SelectLocationTask:RefreshPage()
	if(page) then
		page:Refresh(0.01);
	end
end

-- get current instance
function SelectLocationTask.GetInstance()
	return curInstance;
end

function SelectLocationTask:GetItem()
	local itemStack = self:GetItemStack();
	if(itemStack) then
		return itemStack:GetItem();
	end
end

function SelectLocationTask.OnClickSelectLocationScript()
	_guihelper.MessageBox(L"点击后更新当前所在瓦片区域贴图信息", function(res)
		if(res and res == _guihelper.DialogResult.Yes and gisToBlocks) then
			if SelectLocationTask.isDownLoaded then
				gisToBlocks:downloadMap();
			else
				_guihelper.MessageBox(L"瓦片信息未初始化");
			end
		end
	end, _guihelper.MessageBoxButtons.YesNo);
end

function SelectLocationTask.OnClickGetMoreTiles()
	--[[_guihelper.MessageBox(L"是否确定生成此区域？", function(res)
		if(res and res == _guihelper.DialogResult.Yes) then
			local self = SelectLocationTask.GetInstance();
			local item = self:GetItem();
		
			if(item) then
				item:MoreScence();
			end
		end
	end, _guihelper.MessageBoxButtons.YesNo);]]
end

function SelectLocationTask.OnClickConfirm()
	page:CloseWindow();
end

function SelectLocationTask.OnClickCancel()
	local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();
	
	if(item) then
		item:Cancle();
	end

	page:CloseWindow();
end

function SelectLocationTask.setCoordinate(minlat,minlon,maxlat,maxlon,schoolName)
	local function doFunc()
		SelectLocationTask.isFirstSelect = false;
		if(minlat ~= SelectLocationTask.minlat or minlon ~=SelectLocationTask.minlon or maxlat ~= SelectLocationTask.maxlat or maxlon ~=SelectLocationTask.maxlon) then
			SelectLocationTask.isChange = true;
			SelectLocationTask.minlat   = minlat;
			SelectLocationTask.minlon   = minlon;
			SelectLocationTask.maxlat   = maxlat;
			SelectLocationTask.maxlon   = maxlon;
		end
		if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
		DBS:setValue(SysDB,"schoolName",schoolName);
		DBS:setValue(SysDB,"coordinate",{minlat=tostring(minlat),minlon=tostring(minlon),maxlat=tostring(maxlat),maxlon=tostring(maxlon)});
		DBS:flush(SysDB)
		-- EarthMod:SetWorldData("schoolName",schoolName);
		-- EarthMod:SetWorldData("coordinate",{minlat=tostring(minlat),minlon=tostring(minlon),maxlat=tostring(maxlat),maxlon=tostring(maxlon)});
		-- EarthMod:SaveWorldData();

	    local self = SelectLocationTask.GetInstance();
		local item = self:GetItem();
		
		if(item) then
			item:RefreshTask(self:GetItemStack());
		end
	end
	DBS:getValue(SysDB,"schoolName",function(name)
		if (not name) or name == schoolName then
			doFunc()
		else
			echo("学校已创建，取消操作")
		end
	end)
end

function SelectLocationTask:ShowPage()
	local window = self:CreateGetToolWindow();

	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/EarthMod/SelectLocationTask.html", 
		name = "SelectLocationTask", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_lt",
			x = 0,
			y = 60,
			width = 320,
			height = 120,
		cancelShowAnimation = true,
	});
end

function SelectLocationTask:Run()
	curInstance = self;
	self.finished = false;
	SelectLocationTask.player_curLon = nil;
	SelectLocationTask.player_curLat = nil;
	SelectLocationTask.player_curState = nil
	if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
	DBS:getValue(SysDB,"coordinate",function(coordinate) if coordinate then
		SelectLocationTask.isFirstSelect = false;
		SelectLocationTask.isChage       = false;
		SelectLocationTask.minlat = coordinate.minlat or 0;
		SelectLocationTask.minlon = coordinate.minlon or 0;
		SelectLocationTask.maxlat = coordinate.maxlat or 0;
		SelectLocationTask.maxlon = coordinate.maxlon or 0;
	end end)
	-- local coordinate = EarthMod:GetWorldData("coordinate");
	-- if(coordinate) then
	-- end
	self:ShowPage();
end

function SelectLocationTask:setPlayerCoordinate(lon, lat)
	SelectLocationTask.player_lon = lon;
	SelectLocationTask.player_lat = lat;
end

function SelectLocationTask:getPlayerCoordinate()
	return SelectLocationTask.player_lon, SelectLocationTask.player_lat;
end

-- 设置并跳转人物
function SelectLocationTask:setPlayerLocation(lon, lat)
	if not SelectLocationTask.isDownLoaded then return end
	local str = "网页读取到人物跳转：lon:" .. lon .. ", lat:" .. lat
	GameLogic.AddBBS("statusBar", str, 15000, "223 81 145"); -- 显示提示条
	SelectLocationTask.player_curLon = lon;
	SelectLocationTask.player_curLat = lat;
	SelectLocationTask.player_curState = nil
	LOG.std(nil,"RunFunction","SelectLocationTask",str)
end

function SelectLocationTask:getSchoolAreaInfo()
	if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
	DBS:getValue(SysDB,"alreadyBlock",function(alreadyBlock) if alreadyBlock then
		DBS:getValue(SysDB,"coordinate",function(coordinate) if coordinate then
			DBS:getValue(SysDB,"schoolName",function(schoolName) if schoolName then
				self.schoolData = {status = 100, data = {minlon = coordinate.minlon, minlat = coordinate.minlat, maxlon = coordinate.maxlon, maxlat = coordinate.maxlat, schoolName = schoolName}}
			else
				self.schoolData = {status = 300, data = nil}
			end end)
		else
			self.schoolData = {status = 300, data = nil}
		end end)
	else
		self.schoolData = {status = 300, data = nil}
	end end)

	if self.schoolData then
		return self.schoolData
	else 
		return {status = 400, data = nil}
	end
	-- if EarthMod:GetWorldData("alreadyBlock") and EarthMod:GetWorldData("coordinate") then
	-- 	local coordinate = EarthMod:GetWorldData("coordinate");
	-- 	return {status = 100, data = {minlon = coordinate.minlon, minlat = coordinate.minlat, maxlon = coordinate.maxlon, maxlat = coordinate.maxlat}};
	-- else
	-- 	return {status = 300, data = nil};
	-- end
end

function SelectLocationTask:setInfor(para)
	SelectLocationTask.playerInfo = para
end

function SelectLocationTask:OnShowInfo()
	SelectLocationTask.isShowInfo = not SelectLocationTask.isShowInfo
end

function SelectLocationTask:OnShowMap()
	-- 切换地图显示
	NPL.load("(gl)Mod/NplCefBrowser/NplCefWindowManager.lua");
	local NplCefWindowManager = commonlib.gettable("Mod.NplCefWindowManager");
	-- Open a new window when window haven't been opened,otherwise it will call the show function to show the window
	NplCefWindowManager:Open("my_window", "Select Location Window", "http://localhost:8099/earth", "_rt", -400, 0, 400, 400);
end
