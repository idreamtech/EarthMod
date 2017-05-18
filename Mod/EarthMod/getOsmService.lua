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
NPL.load("(gl)script/ide/timer.lua");

local getOsmService = commonlib.gettable("Mod.EarthMod.getOsmService");
local Encoding      = commonlib.gettable("System.Encoding");

getOsmService.osmHost   = "openstreetmap.org";
getOsmService.tryTimes  = 0;
getOsmService.worldName = GameLogic.GetWorldDirectory();
getOsmService.isUpdateMode = nil
getOsmService.isUpdateModeOSM = nil

function getOsmService:ctor()
end

function getOsmService:init()
end

function getOsmService.osmXMLUrl()
	return "http://api."  .. getOsmService.osmHost .. "/api/0.6/map?bbox={left},{bottom},{right},{top}";
end

function getOsmService.osmPNGUrl()
	if ComVar.usingMap == "BAIDU" then
		-- return "http://online2.map.bdimg.com/onlinelabel/?qt=tile&x={x}&y={y}&z={18}&styles=pl&scaler=1&p=0";
		if ComVar.tileFormat == ".png" then
			return "http://online2.map.bdimg.com/tile/?qt=tile&x={x}&y={y}&z=18&styles=pl&scaler=1";
		elseif ComVar.tileFormat == ".jpg" then
			return "http://api2.map.bdimg.com/customimage/tile?&x={x}&y={y}&z=18";
		end
	elseif ComVar.usingMap == "OSM" then
		return "http://tile." .. getOsmService.osmHost .. "/" .. getOsmService.zoom .. "/{x}/{y}.png";
	end
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

function getOsmService:getOsmXMLData(x,y,i,j,dleft,dbottom,dright,dtop,_callback)
	if ComVar.usingMap == "BAIDU" then
		_callback();
		return;
	end
	local osmXMLUrl = getOsmService.osmXMLUrl();

	osmXMLUrl = osmXMLUrl:gsub("{left}",dleft);
	osmXMLUrl = osmXMLUrl:gsub("{bottom}",dbottom);
	osmXMLUrl = osmXMLUrl:gsub("{right}",dright);
	osmXMLUrl = osmXMLUrl:gsub("{top}",dtop);

	if ComVar.Draw3DBuilding and ComVar.usingMap == "OSM" then
		echo("downloadOSMurl:" .. osmXMLUrl)
		-- 使用定时器,错开多次请求OSM节点数据的接口调用,避免出现短时间内请求达到100次峰值之后无法获取到OSM节点数据的情况
		local path = "xml_"..x.."_"..y..".osm"
		if getOsmService.isUpdateModeOSM then getOsmService.isUpdateModeOSM = nil
		else
			if ParaIO.DoesFileExist(path) then
				echo("downloadOSMurl: load local data")
				local vectorFile = ParaIO.open(path, "r");
				local vector = vectorFile:GetText(0, -1);
				vectorFile:close();
				_callback(vector);
				return
			end
		end
		-- download
		-- local downOsmXMLTimer = commonlib.Timer:new({callbackFunc = function(downOsmXMLTimer)
		self:GetUrl(osmXMLUrl,function(data,err)
			if(err == 200) then
				echo("downloadOSMurl: download server data")
				local fileExt = ParaIO.open(path, "w");
				LOG.std(nil,"debug","gisOsmService",path);
				local ret = fileExt:write(data,#data);
				fileExt:close();
				_callback(data);
			else
				echo("download failse" .. tostring(err))
				return nil;
			end
		end);
		-- end})
		-- -- start the timer after i milliseconds, and stop it immediately.
		-- downOsmXMLTimer:Change(i*3000, nil);
	else
		_callback();
	end
end

function getOsmService:getOsmPNGData(x,y,i,j,_callback)
	local osmPNGUrl = getOsmService.osmPNGUrl();
	osmPNGUrl = osmPNGUrl:gsub("{x}",tostring(x)); -- + 1 测试更新
	osmPNGUrl = osmPNGUrl:gsub("{y}",tostring(y));
	local path = "tile_"..x.."_"..y..ComVar.tileFormat
	if getOsmService.isUpdateMode then
		getOsmService.isUpdateMode = nil
	else
		if ParaIO.DoesFileExist(path) then
			echo("getOsmPNGData: load local data: " .. path)
			_callback();
			return
		end
	end
	echo("download url: " .. osmPNGUrl)
	-- 使用定时器,错开多次请求PNG图片的接口调用,避免出现短时间内请求达到100次峰值之后无法获取到PNG图片的情况
	-- local downLoadPngTimer = commonlib.Timer:new({callbackFunc = function(downLoadPngTimer)
	self:GetUrl(osmPNGUrl,function(data,err)
		if(err == 200) then
			echo("getOsmPNGData: download server data")
			local fileExt = ParaIO.open(path, "w");
			LOG.std(nil,"debug","gisOsmService",path);
			local ret = fileExt:write(data,#data);
			fileExt:close();
			_callback(data);
		else
			return nil;
		end
	end);
	-- end})

	-- -- start the timer after i milliseconds, and stop it immediately.
	-- downLoadPngTimer:Change(i*5000, nil);
end