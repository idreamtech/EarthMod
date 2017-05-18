--[[
Title: MapGeography
Author(s):  Bl.Chock
Date:  2017-5-5
Desc: 地理信息类
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/MapGeography.lua");
local MapGeography = commonlib.gettable("Mod.EarthMod.MapGeography");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
local TileManager = commonlib.gettable("Mod.EarthMod.TileManager");
local MapGeography = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.MapGeography"))
local TILE_SIZE = 256 -- 默认瓦片大小
local curInstance;

MapGeography.tileSize = nil
MapGeography.zoomLv = nil
MapGeography.zoomN = nil

-- 初始化MapGeography，可以传入指定的图片尺寸和缩放比例，否则自动判断
function MapGeography:ctor(zoom)
  local ZOOM_LV -- OSM级数17 百度为18
  if ComVar.usingMap == "OSM" then ZOOM_LV = 17 elseif ComVar.usingMap == "BAIDU" then
    ZOOM_LV = 18
  end
  self.tileSize = math.ceil(TILE_SIZE * ComVar.factor)
	self.zoomLv = zoom or ZOOM_LV
	self.zoomN = 2 ^ self.zoomLv
    curInstance = self
end

-- 计算瓦片位置(返回行列号和像素点坐标)
function MapGeography:getTilePo(tx,ty)
    local Xt,Yt = math.floor(tx), math.floor(ty)
    local Xp,Yp = nil,nil
    if ComVar.usingMap == "OSM" then
      Xp,Yp = math.floor((tx - Xt) * self.tileSize), math.floor((ty - Yt) * self.tileSize)
    else Xp,Yp = math.floor((tx - Xt) * TILE_SIZE), math.floor((ty - Yt) * TILE_SIZE) end
    return Xt, Yt, Xp, Yp
end

-- osm
function MapGeography:deg2pixelOsm(lon, lat, isGis)
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = self.zoomN * ((lon_deg + 180) / 360)
    local ytile = self.zoomN * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2
    if isGis then
        return math.floor(xtile * self.tileSize % self.tileSize + 0.5),math.floor(ytile * self.tileSize % self.tileSize + 0.5)
    end
    return self:getTilePo(xtile, ytile)
end

function MapGeography:deg2tileOsm(lon, lat)
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(self.zoomN * ((lon_deg + 180) / 360))
    local ytile = math.floor(self.zoomN * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2)
    return xtile, ytile
end

-- 瓦片行列式转经纬度(参数：瓦片ID，瓦片中所在像素位置，缩放级数)
function MapGeography:pixel2degOsm(tileX, tileY, pixelX, pixelY, isGis)
    local lon_deg = (tileX + pixelX / self.tileSize) / self.zoomN * 360.0 - 180.0;
    local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * (tileY + pixelY/self.tileSize) / self.zoomN)))
    local lat_deg = lat_rad * 180.0 / math.pi
    if isGis then return tostring(lon_deg), tostring(lat_deg) end
    return {lon = lon_deg, lat = lat_deg}
end

-- baidu
 --百度坐标参数
local array1 ={ 75, 60, 45, 30, 15, 0 };

local array3 ={ 12890594.86, 8362377.87, 5591021, 3481989.83, 1678043.12, 0 };

local array2= {{-0.0015702102444, 111320.7020616939, 1704480524535203, -10338987376042340, 26112667856603880, -35149669176653700, 26595700718403920, -10725012454188240, 1800819912950474, 82.5}
                ,{0.0008277824516172526, 111320.7020463578, 647795574.6671607, -4082003173.641316, 10774905663.51142, -15171875531.51559, 12053065338.62167, -5124939663.577472, 913311935.9512032, 67.5}
                ,{0.00337398766765, 111320.7020202162, 4481351.045890365, -23393751.19931662, 79682215.47186455, -115964993.2797253, 97236711.15602145, -43661946.33752821, 8477230.501135234, 52.5}
                ,{0.00220636496208, 111320.7020209128, 51751.86112841131, 3796837.749470245, 992013.7397791013, -1221952.21711287, 1340652.697009075, -620943.6990984312, 144416.9293806241, 37.5}
                ,{-0.0003441963504368392, 111320.7020576856, 278.2353980772752, 2485758.690035394, 6070.750963243378, 54821.18345352118, 9540.606633304236, -2710.55326746645, 1405.483844121726, 22.5}
                ,{-0.0003218135878613132, 111320.7020701615, 0.00369383431289, 823725.6402795718, 0.46104986909093, 2351.343141331292, 1.58060784298199, 8.77738589078284, 0.37238884252424, 7.45}};

local array4 ={{1.410526172116255e-8, 0.00000898305509648872, -1.9939833816331, 200.9824383106796, -187.2403703815547, 91.6087516669843, -23.38765649603339, 2.57121317296198, -0.03801003308653, 17337981.2}
                ,{-7.435856389565537e-9, 0.000008983055097726239, -0.78625201886289, 96.32687599759846, -1.85204757529826, -59.36935905485877, 47.40033549296737, -16.50741931063887, 2.28786674699375, 10260144.86}
                ,{-3.030883460898826e-8, 0.00000898305509983578, 0.30071316287616, 59.74293618442277, 7.357984074871, -25.38371002664745, 13.45380521110908, -3.29883767235584, 0.32710905363475, 6856817.37}
                ,{-1.981981304930552e-8, 0.000008983055099779535, 0.03278182852591, 40.31678527705744, 0.65659298677277, -4.44255534477492, 0.85341911805263, 0.12923347998204, -0.04625736007561, 4482777.06}
                ,{3.09191371068437e-9, 0.000008983055096812155, 0.00006995724062, 23.10934304144901, -0.00023663490511, -0.6321817810242, -0.00663494467273, 0.03430082397953, -0.00466043876332, 2555164.4}
                ,{2.890871144776878e-9, 0.000008983055095805407, -3.068298e-8, 7.47137025468032, -0.00000353937994, -0.02145144861037, -0.00001234426596, 0.00010322952773, -0.00000323890364, 826088.5}};

--坐标转换
function Convertor(lng,lat,param)
      local T = param[1] + param[2] * math.abs(lng);
      local cC =math.abs(lat) / param[10];
      local cF = param[3] + param[4] * cC + param[5] * cC * cC + param[6] * cC * cC * cC + param[7] * cC * cC * cC * cC + param[8] * cC * cC * cC * cC * cC + param[9] * cC * cC * cC * cC * cC * cC;
    if(lng<0) then
    T=T*-1
    else
    T=T*1
    end
    if(lat<0) then
    cF=cF*-1
    else
    cF=cF*1
    end
    return T,cF
end

--百度坐标转墨卡托
--即经纬度转直角坐标
function LatLng2Mercator(lon,lat)
   --if((lon or lon==0  or lon>180 or lon<-180) and ( lat or lat ==0 or lat>90 or lat<-90 )) then return 0,0 end
    local n_lat=lat
  local arr
  if(lat>74) then n_lat=74 end
  if(lat<-74) then n_lat=-74 end
   for  i = 1, table.getn(array1) do
        if (n_lat >= array1[i]) then
            arr = array2[i];
            break;
        end
    end
  if(not arr) then
     for i = table.getn(array1) - 1, 1, -1 do

            if (n_lat <= -array1[i]) then

                arr = array2[i];
                break;
            end

    end

  end

   return Convertor(lon, n_lat, arr)
end

--墨卡托坐标转百度经纬度坐标
--即平面坐标转经纬度坐标
function Mercator2LatLng(x,y)
  local arr
  local t_x,t_y=math.abs(x),math.abs(y)
  for  i = 1, table.getn(array3) do

        if (t_y >= array3[i]) then
            arr = array4[i];
            break;
        end
   end
   return Convertor(t_x,t_y,arr)
end

--百度经纬度转瓦片行列号
--lon:经度,lat:纬度，zoom:缩放级别
function MapGeography:bddeg2tile(lon, lat)
    local x,y=LatLng2Mercator(lon,lat)
    local xtile=math.floor((x*2^(self.zoomLv-18))/TILE_SIZE)
    local ytile=math.floor((y*2^(self.zoomLv-18))/TILE_SIZE)
    return xtile,ytile
end

--百度经纬度转瓦片像素点
--lon:经度,lat:纬度,self.zoomLv:缩放级别
function MapGeography:bdcoord2piexl(lon, lat, isGis)
    lon = tonumber(lon)
    lat = tonumber(lat)
    local x,y =LatLng2Mercator(lon,lat)
    local tile_X,tile_y=self:bddeg2tile(lon,lat)
    local piexl_x,piexl_y=0,0
    piexl_x=math.floor(x*2^(self.zoomLv-18)-tile_X*TILE_SIZE+0.5)
    piexl_y=math.floor(y*2^(self.zoomLv-18)-tile_y*TILE_SIZE+0.5)
    if isGis then return piexl_x,piexl_y end
    return tile_X, tile_y, piexl_x, piexl_y
end

--百度瓦片像素点转经纬度
--tile_x:瓦片X，tile_y:瓦片Y，piexl_x:像素X，piexl_y:像素Y，self.zoomLv: 缩放级别
--百度地图中，像素坐标（pixelX, pixelY）的起点为左下角
function MapGeography:bdtilepiexl2coord(tile_x, tile_y, piexl_x, piexl_y, isGis)
    local x=(tile_x*TILE_SIZE+piexl_x)/(2^(self.zoomLv-18))
    local y=(tile_y*TILE_SIZE+piexl_y)/(2^(self.zoomLv-18))
    local lon_deg,lat_deg = Mercator2LatLng(x,y)
    if isGis then return tostring(lon_deg), tostring(lat_deg) end
    return {lon = lon_deg, lat = lat_deg}
end

-- 百度偏移纠正
local x_PI = 3.14159265358979324 * 3000.0 / 180.0;
local PI = 3.1415926535897932384626;
local a = 6378245.0;
local ee = 0.00669342162296594323;

--非中国区域或者其他传入的是平面坐标，则不进行转换
function MapGeography.out_china(lng,lat)
 return not(lng > 73.66 and lng < 135.05 and lat > 3.86 and lat < 53.55);
end

function MapGeography.transformlat(lng, lat)

  ret = -100.0 + 2.0 * lng + 3.0 * lat + 0.2 * lat * lat + 0.1 * lng * lat + 0.2 * math.sqrt(math.abs(lng));
    ret =ret+ (20.0 * math.sin(6.0 * lng * PI) + 20.0 * math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
    ret =ret+ (20.0 * math.sin(lat * PI) + 40.0 * math.sin(lat / 3.0 * PI)) * 2.0 / 3.0;
    ret =ret+ (160.0 * math.sin(lat / 12.0 * PI) + 320 * math.sin(lat * PI / 30.0)) * 2.0 / 3.0;
    return ret
  end

function MapGeography.transformlng(lng, lat)

  ret = 300.0 + lng + 2.0 * lat + 0.1 * lng * lng + 0.1 * lng * lat + 0.1 * math.sqrt(math.abs(lng));
    ret =ret+ (20.0 * math.sin(6.0 * lng * PI) + 20.0 * math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
    ret =ret+ (20.0 * math.sin(lng * PI) + 40.0 * math.sin(lng / 3.0 * PI)) * 2.0 / 3.0;
    ret =ret+ (150.0 * math.sin(lng / 12.0 * PI) + 300.0 * math.sin(lng / 30.0 * PI)) * 2.0 / 3.0;
    return ret
  end
--火星转WGS84坐标
 function MapGeography.gcj02towgs84(lng, lat)

    if (MapGeography.out_china(lng, lat)) then
      return lng, lat
     else
       dlat = MapGeography.transformlat(lng - 105.0, lat - 35.0);
       dlng = MapGeography.transformlng(lng - 105.0, lat - 35.0);
       radlat = lat / 180.0 * PI;
       magic = math.sin(radlat);
      magic = 1 - ee * magic * magic;
    sqrtmagic = math.sqrt(magic);
      dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtmagic) * PI);
      dlng = (dlng * 180.0) / (a / sqrtmagic * math.cos(radlat) * PI);
       mglat = lat + dlat;
       mglng = lng + dlng;
      return lng * 2 - mglng, lat * 2 - mglat
    end
  end
--WGS 84 转火星坐标
function MapGeography.wgs84togcj02(lng, lat)
    if (MapGeography.out_china(lng, lat)) then
      return lng, lat
     else
       dlat = MapGeography.transformlat(lng - 105.0, lat - 35.0);
       dlng = MapGeography.transformlng(lng - 105.0, lat - 35.0);
       radlat = lat / 180.0 * PI;
       magic = math.sin(radlat);
      magic = 1 - ee * magic * magic;
       sqrtmagic = math.sqrt(magic);
      dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtmagic) * PI);
      dlng = (dlng * 180.0) / (a / sqrtmagic * math.cos(radlat) * PI);
       mglat = lat + dlat;
       mglng = lng + dlng;
      return mglng, mglat
    end
  end
--火星坐标转百度
  function MapGeography.gcj02tobd09(lng, lat)
     z = math.sqrt(lng * lng + lat * lat) + 0.00002 * math.sin(lat * x_PI);
     theta = math.atan2(lat, lng) + 0.000003 * math.cos(lng * x_PI);
     bd_lng = z * math.cos(theta) + 0.0065;
     bd_lat = z * math.sin(theta) + 0.006;
    return bd_lng, bd_lat
  end
--百度转火星
function MapGeography.bd09togcj02(bd_lon, bd_lat)
     x = bd_lon - 0.0065;
     y = bd_lat - 0.006;
     z = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * x_PI);
     theta = math.atan2(y, x) - 0.000003 * math.cos(x * x_PI);
     gg_lng = z * math.cos(theta);
     gg_lat = z * math.sin(theta);
    return gg_lng, gg_lat
  end

-----百度坐标转OSM坐标（GPS）-------
-- osm_lon,osm_lat=MapGeography.gcj02towgs84(MapGeography.bd09togcj02(t_lon,t_lat))
-- GPS转百度：local lon,lat = MapGeography.gcj02tobd09(MapGeography.wgs84togcj02(t_lon,t_lat))
--

-- 单例模式
function MapGeography.GetInstance()
    if curInstance == nil then return MapGeography:new() end
    return curInstance;
end
function MapGeography:OnLeaveWorld()
    curInstance = nil;
end
-- 

-- 经纬度转像素点
function MapGeography:deg2pixel(lon, lat, isTile)
    if ComVar.usingMap == "OSM" then
        return self:deg2pixelOsm(lon, lat, not isTile)
    elseif ComVar.usingMap == "BAIDU" then
        return self:bdcoord2piexl(lon, lat, not isTile)
    end
end
-- 经纬度转瓦片行列号
function MapGeography:deg2tile(lon, lat)
    if ComVar.usingMap == "OSM" then
        return self:deg2tileOsm(lon, lat)
    elseif ComVar.usingMap == "BAIDU" then
        lon = tonumber(lon)
        lat = tonumber(lat)
        return self:bddeg2tile(lon, lat)
    end
end
-- 像素点转经纬度
function MapGeography:pixel2deg(tileX, tileY, pixelX, pixelY, isTile)
    if ComVar.usingMap == "OSM" then
        return self:pixel2degOsm(tileX, tileY, pixelX, pixelY, not isTile)
    elseif ComVar.usingMap == "BAIDU" then
        return self:bdtilepiexl2coord(tileX, tileY, pixelX, pixelY, not isTile)
    end
end

-- parancraft坐标系转gps经纬度
function MapGeography:getGPo(x,y,z)
    if y == nil and z == nil and x and type(x) == "table" then
        z = x.z;y = x.y; x = x.x
    end
    local tpack = TileManager.GetInstance()
    local dx = (x - tpack.firstBlockPo.x) / self.tileSize + tpack.beginPo.x
    local dz = nil
    if ComVar.usingMap == "BAIDU" then dz = (z - tpack.firstBlockPo.z) / self.tileSize + tpack.beginPo.y
    else dz = tpack.beginPo.y - (z - tpack.firstBlockPo.z) / self.tileSize + 1 end
    local a,b,c,d = self:getTilePo(dx,dz)
    echo({x=x,y=y,z=z})
    return self:pixel2deg(a,b,c,d,true)
end


-- gps经纬度转parancraft坐标系 -32907218 5 15222780
function MapGeography:getParaPo(lon,lat)
    local tpack = TileManager.GetInstance()
    if (not lat) and (not lon) then return tpack.cenPo end
    if lat == nil and lon and type(lon) == "table" then
        lat = lon.lat;lon = lon.lon
    end
    local tileX,tileZ,x,z = self:deg2pixel(lon,lat,true)
    local dx = (tileX - tpack.beginPo.x) * self.tileSize + x + tpack.firstBlockPo.x
    local dz = nil
    if ComVar.usingMap == "BAIDU" then dz = (tileZ - tpack.beginPo.y) * self.tileSize + z + tpack.firstBlockPo.z
    else dz = (tpack.beginPo.y - tileZ + 1) * self.tileSize - z + tpack.firstBlockPo.z end
    echo({x = math.round(dx),y = tpack.firstBlockPo.y,z = math.round(dz)})
    return {x = math.round(dx),y = tpack.firstBlockPo.y,z = math.round(dz)}
end

-- GPS偏移纠正到百度
function MapGeography:gpsToBaidu(gps_lon,gps_lat)
    local lon,lat = MapGeography.gcj02tobd09(MapGeography.wgs84togcj02(gps_lon,gps_lat))
    return lon,lat
end

-- 百度经纬度转GPS经纬度（一般用不上）
function MapGeography:baiduToGps(gps_lon,gps_lat)
    local lon,lat = MapGeography.gcj02towgs84(MapGeography.bd09togcj02(gps_lon,gps_lat))
    return lon,lat
end