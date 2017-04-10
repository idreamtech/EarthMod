--[[
Title: MapGeography
Author(s):  Bl.Chock
Date:  2017-4-7
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/MapGeography.lua");
local MapGeography = commonlib.gettable("Mod.EarthMod.MapGeography");
------------------------------------------------------------
]]
local MapGeography = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.MapGeography"))
local TILE_SIZE = 256 -- 默认瓦片大小
local ZOOM_LV = 17 	  -- OSM级数 百度为18

MapGeography.tileSize = nil
MapGeography.zoomLv = nil
MapGeography.zoomN = nil

function MapGeography:ctor(zoom,pixelSize)
	self.tileSize = pixelSize or TILE_SIZE
	self.zoomLv = zoom or 17
	self.zoomN = 2 ^ self.zoomLv
end

-- 计算瓦片位置(返回行列号和像素点坐标)
function TileManager:getTilePo(tx,ty)
	local Xt,Yt = math.floor(tx), math.floor(ty)
    local Xp,Yp = math.floor((tx - Xt) * self.tileSize), math.floor((ty - Yt) * self.tileSize)
    return Xt, Yt, Xp, Yp
end

function MapGeography:tile2deg(x, y, z)

end

local function tile2deg(x, y, z)
    local n = 2 ^ z
    local lon_deg = x / n * 360.0 - 180.0
    local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    local lat_deg = lat_rad * 180.0 / math.pi
    return lon_deg, lat_deg
end

local function deg2tile(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360))
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2)
    return xtile, ytile
end

local function deg2pixel(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360) * PngWidth % PngWidth + 0.5)
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2 * PngWidth % PngWidth + 0.5)
    return xtile, ytile
end

local function pixel2deg(tileX,tileY,pixelX,pixelY,zoom)
	local n = 2 ^ zoom;
	local lon_deg = (tileX + pixelX/PngWidth) / n * 360.0 - 180.0;
	local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * (tileY + pixelY/PngWidth) / n)))
	local lat_deg = lat_rad * 180.0 / math.pi
	return tostring(lon_deg), tostring(lat_deg)
end