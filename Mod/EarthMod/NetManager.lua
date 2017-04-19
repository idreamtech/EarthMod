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


Commands["earthnet"] = {
	name="earthnet", 
	quick_ref="/net [-user] [name] [-k] [key] [-v] [value]",
	desc=[[
		
	]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		-- local lat,lon,minlat,minlon,maxlat,maxlon;
		-- -- 深圳大学区域信息
		-- -- local minlat,minlon,maxlat,maxlon=22.5308,113.9250,22.5424,113.9402;
		-- options, cmd_text = CmdParser.ParseOptions(cmd_text);
		-- --LOG.std(nil,"debug","options",options);
		-- if options.already then
		-- 	optionsType = "already";
		-- 	minlat, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	minlon, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	maxlat, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	maxlon, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	LOG.std(nil,"debug","minlat,minlon,maxlat,maxlon",{minlat,minlon,maxlat,maxlon});
		-- 	if(options.cache) then
		-- 		cache, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	else
		-- 		cache = 'false';
		-- 	end
		-- 	gisCommand.gis = Tasks.gisToBlocks:new({options=optionsType,minlat=minlat,minlon=minlon,maxlat=maxlat,maxlon=maxlon,cache=cache});
		-- 	return;
		-- elseif options.coordinate then
		-- 	minlat, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	minlon, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	maxlat, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	maxlon, cmd_text = CmdParser.ParseString(cmd_text);

		-- 	LOG.std(nil,"debug","minlat,minlon,maxlat,maxlon",{minlat,minlon,maxlat,maxlon});

		-- 	optionsType = "coordinate";

		-- 	options, cmd_text = CmdParser.ParseOptions(cmd_text);

		-- 	--echo(options);

		-- 	if(options.cache) then
		-- 		cache, cmd_text = CmdParser.ParseString(cmd_text);
		-- 	else
		-- 		cache = 'false';
		-- 	end

		-- 	gisCommand.gis = Tasks.gisToBlocks:new({options=optionsType,minlat=minlat,minlon=minlon,maxlat=maxlat,maxlon=maxlon,cache=cache});
		-- 	gisCommand.gis:Run();
		-- 	return;
		-- end

		-- if(options.undo) then
		-- 	if(gisCommand.gis) then
		-- 		gisCommand.gis:Undo();
		-- 	end
		-- 	return;
		-- end

		-- if(options.boundary) then
		-- 	if(gisCommand.gis) then
		-- 		gisCommand.getMoreTiles = gisCommand.gis:BoundaryCheck();
		-- 	end
		-- 	return;
		-- end

		-- if(options.more) then
		-- 	if(gisCommand.gis) then
		-- 		options, cmd_text = CmdParser.ParseOptions(cmd_text);

		-- 		if(options) then
		-- 			cache, cmd_text = CmdParser.ParseString(cmd_text);
		-- 		else
		-- 			cache = 'false';
		-- 		end

		-- 		gisCommand.gis.cache = cache;
		-- 		gisCommand.gis:MoreScene();
		-- 	end
		-- end
	end,
};