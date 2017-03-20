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

local SelectLocationTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask"));
local EarthMod           = commonlib.gettable("Mod.EarthMod");

SelectLocationTask:Property({"LeftLongHoldToDelete", false, auto=true});

local curInstance;

SelectLocationTask.isFirstSelect = true;
-- this is always a top level task. 
SelectLocationTask.is_top_level  = true;
SelectLocationTask.getMoreTiles  = false;

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
	_guihelper.MessageBox(L"点击后打开内嵌浏览器，输入学校名称，选择学校后，显示学校设定区域信息。", function(res)
		if(res and res == _guihelper.DialogResult.Yes) then
			local self = SelectLocationTask.GetInstance();
			local item = self:GetItem();
		
			if(item) then
				item:GoToMap();
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

function SelectLocationTask.setCoordinate(minlat,minlon,maxlat,maxlon)
	SelectLocationTask.isFirstSelect = false;

	if(minlat ~= SelectLocationTask.minlat or minlon ~=SelectLocationTask.minlon or maxlat ~= SelectLocationTask.maxlat or maxlon ~=SelectLocationTask.maxlon) then
		SelectLocationTask.isChange = true;
		SelectLocationTask.minlat   = minlat;
		SelectLocationTask.minlon   = minlon;
		SelectLocationTask.maxlat   = maxlat;
		SelectLocationTask.maxlon   = maxlon;
	end

	EarthMod:SetWorldData("coordinate",{minlat=tostring(minlat),minlon=tostring(minlon),maxlat=tostring(maxlat),maxlon=tostring(maxlon)});
	--EarthMod:SaveWorldData();

    local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();
	
	if(item) then
		item:RefreshTask(self:GetItemStack());
	end
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
			align = "_ctb",
			x = 0,
			y = -55,
			width = 470,
			height = 100,
		cancelShowAnimation = true,
	});
end

function SelectLocationTask:Run()
	curInstance = self;
	self.finished = false;

	local coordinate = EarthMod:GetWorldData("coordinate");

	if(coordinate) then
		SelectLocationTask.isFirstSelect = false;
		SelectLocationTask.isChage       = false;

		SelectLocationTask.minlat = coordinate.minlat or 0;
		SelectLocationTask.minlon = coordinate.minlon or 0;
		SelectLocationTask.maxlat = coordinate.maxlat or 0;
		SelectLocationTask.maxlon = coordinate.maxlon or 0;
	end

	self:ShowPage();
end