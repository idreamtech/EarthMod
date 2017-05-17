--[[
Title: Com
Author(s):  Bl.Chock
Date: 2017年4月20日
Desc: Common functions and varible
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/Com.lua");
------------------------------------------------------------
]]

-- 配置参数 --
ComVar = {
	CorrectMode = nil; -- 开启矫正模式  矫正地图定位偏差
	DrawAllMap = nil; -- 开启全部自动绘制
	Draw3DBuilding = nil; -- 是否绘制地上建筑
	-- gis
	factor = 1.19; -- 地图缩放比例（百度地图自动设置为1）
	FloorLevel = 5; -- 绘制地图层层高：草地层
	buildLevelMax = 60; -- 绘制地图层层高：草地层
    buildLevelHeight = 4; -- 每层建筑高度
	-- map
	fillAirMode = nil; -- 填充所有空气
	fillAll = nil; -- 填充所有方块
    usingMap = "BAIDU"; -- 使用的地图类型 OSM/BAIDU
    tileFormat = ".png";
	-- net
	openNetwork = true; -- 是否打开网络通讯
    prot = 8099; -- 小地图默认端口号
}



















--------------
-- common function
-- 克隆
function table.clone( object )
    local lookup_table = {}
    local function copyObj( object )
        if type( object ) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
       
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs( object ) do
            new_table[copyObj( key )] = copyObj( value )
        end
        return setmetatable( new_table, getmetatable( object ) )
    end
    return copyObj( object )
end
-- table转换为json(字符串)
function table.toJson(tb)
	return commonlib.Json.Encode(tb)
end
-- json(字符串)转换为table
function table.fromJson(str)
	return commonlib.Json.Decode(str)
end

function handler(obj, method)
    return function(...)
       return method(obj,...)
    end
end
-- 状态栏显示提示
function TipLog(str,delay,color)
    delay = delay or 5000
    color = color or "0 255 0"
    GameLogic.AddBBS("statusBar", str, delay, color)
end
-- 