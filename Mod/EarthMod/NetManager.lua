--[[
Title: NetManager
Author(s):  Bl.Chock
Date: 2017年4月19日
Desc: net manager, conmmunication for client and server
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/NetManager.lua");
local NetManager = commonlib.gettable("Mod.EarthMod.NetManager");
------------------------------------------------------------
]]

local NetManager = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.NetManager"));
local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");

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
    	echo("NetManager connect: " .. self.name)
		if self.name == "default" then -- 刚刚启动
			self:onEnterWorld()
		elseif self.name == "__MP__admin" then -- 连上了服务器
			self:onServerLogin()
		else -- 连上了客户端
			self:onClientLogin()
		end
        return true;
    end);
	echo("onInit: NetManager")
end

-- 登录游戏
function NetManager:onEnterWorld()
	echo("NetManager onEnterWorld 登录游戏")

end
-- 服务器登入
function NetManager:onServerLogin()
	echo("NetManager onServerLogin 服务器登入")

end
-- 客户端登入
function NetManager:onClientLogin()
	echo("NetManager onClientLogin 客户端登入")
	-- GameLogic.RunCommand("/runat @admin /say ".. self.name .. " connected");
end


function NetManager:OnLeaveWorld()
	curInstance = nil;
end

-- 定义指令donet用于处理消息回调
Commands["donet"] = {
	name="donet", 
	quick_ref="/donet @name -key [value]",
	desc=[[receive data from dest player
@param @name: @all for all connected players. @p for last trigger entity. @name for given player name. `__MP__` can be ignored.
@param -key,value: key and value for send
Examples:
/donet @__MP__admin -k say -v hello
/donet @default -k del -v block1
]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		local playername, key, value
		playername, cmd_text = CmdParser.ParseFormated(cmd_text, "@%S+");
		if(playername) then
			playername = playername:gsub("^@", "");
		else playername = "default" end
		echo("donet name: " .. playername)
		cmd_text = cmd_text:gsub("^%s+", "");
		key, cmd_text = CmdParser.ParseOptions(cmd_text);
		if key then
			echo("donet key: ");echo(key)
			value, cmd_text = CmdParser.ParseString(cmd_text);
			echo("value:");echo(value)
		end
	end,
};