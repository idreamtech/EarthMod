--[[
Title: NetManager
Author(s):  Bl.Chock
Date: 2017年4月19日
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/NetManager.lua");
local NetManager = commonlib.gettable("Mod.EarthMod.NetManager");
------------------------------------------------------------
]]

local NetManager = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.NetManager"));

local curInstance;
NetManager.name = nil

function NetManager.GetInstance()
	if curInstance == nil then return NetManager:new() end
	return curInstance;
end

function NetManager:ctor()
	self.name = nil
    GameLogic.GetFilters():add_filter("PlayerHasLoginPosition", function()
		self.name = GameLogic.GetPlayer():GetName()
    	echo("connect: " .. self.name)
		if self.name == "default" then -- 刚刚启动
			-- 
		elseif self.name == "__MP__admin" then -- 连上了服务器
			
		else -- 连上了客户端
			GameLogic.RunCommand("/runat @admin /say ".. self.name .. " connected");
		end
        return true;
    end);
	echo("onInit: NetManager")
end


function NetManager:OnLeaveWorld()
	if self.db then
		self.db = nil
	end
	curInstance = nil;
end
