--[[
Title: getOsmService
Author(s):  big
Date:  2017.2.19
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/getOsmService.lua");
local getOsmService = commonlib.gettable("Mod.EarthMod.getOsmService");
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Encoding/base64.lua");
NPL.load("(gl)script/ide/Encoding.lua");
NPL.load("(gl)script/ide/Files.lua");

local getOsmService = commonlib.gettable("Mod.EarthMod.getOsmService");
local Encoding      = commonlib.gettable("System.Encoding");

getOsmService.osmHost   = "openstreetmap.org";
getOsmService.tryTimes  = 0;
getOsmService.worldName = GameLogic.GetWorldDirectory();

function getOsmService:ctor()
end

function getOsmService:init()
end

function getOsmService.osmXMLUrl()
	return "http://api."  .. getOsmService.osmHost .. "/api/0.6/map?bbox={left},{bottom},{right},{top}";
end

function getOsmService.osmPNGUrl()
	return "http://tile." .. getOsmService.osmHost .. "/" .. getOsmService.zoom .. "/{x}/{y}.png";
end

function getOsmService:GetUrl(_params,_callback)
	System.os.GetUrl(_params,function(err, msg, data)
		self:retry(err, msg, data, _params, _callback);
	end);
end

function getOsmService:retry(_err, _msg, _data, _params, _callback)
	--失败时可直接返回的代码
	if(_err == 422 or _err == 404 or _err == 409) then
		_callback(_data,_err);
		return;
	end

	if(self.tryTimes >= 3) then
		_callback(_data,_err);
		self.tryTimes = 0;
		return;
	end

	if(_err == 200 or _err == 201 or _err == 204 and _data ~= "") then
		_callback(_data,_err);
		self.tryTimes = 0;
	else
		self.tryTimes = self.tryTimes + 1;
		
		commonlib.TimerManager.SetTimeout(function()
			self:GetUrl(_params, _callback); -- 如果获取失败则递归获取数据
		end, 2100);
	end
end

function getOsmService:getOsmXMLData(x,y,_callback)
	local osmXMLUrl = getOsmService.osmXMLUrl();

	osmXMLUrl = osmXMLUrl:gsub("{left}",self.dleft);
	osmXMLUrl = osmXMLUrl:gsub("{bottom}",self.dbottom);
	osmXMLUrl = osmXMLUrl:gsub("{right}",self.dright);
	osmXMLUrl = osmXMLUrl:gsub("{top}",self.dtop);

	self:GetUrl(osmXMLUrl,function(data,err)
		if(err == 200) then
			--[[local file = ParaIO.open("/xml.osm", "w");
			file:write(data,#data);
			file:close();]]

			local fileExt = ParaIO.open("xml_"..x.."_"..y..".osm", "w");
			LOG.std(nil,"debug","gisOsmService","xml_"..x.."_"..y..".osm");
			local ret = fileExt:write(data,#data);
			fileExt:close();

			_callback(data);
		else
			return nil;
		end
	end);
end

function getOsmService:getOsmPNGData(x,y,_callback)
	local osmPNGUrl = getOsmService.osmPNGUrl();

	osmPNGUrl = osmPNGUrl:gsub("{x}",tostring(x));
	osmPNGUrl = osmPNGUrl:gsub("{y}",tostring(y));

	self:GetUrl(osmPNGUrl,function(data,err)
		if(err == 200) then
			--[[local file = ParaIO.open("/tile.png", "w");
			file:write(data,#data);
			file:close();]]

			local fileExt = ParaIO.open("tile_"..x.."_"..y..".png", "w");
			LOG.std(nil,"debug","gisOsmService","tile_"..x.."_"..y..".png");
			local ret = fileExt:write(data,#data);
			fileExt:close();

			_callback(data);
		else
			return nil;
		end
	end);
end