--[[
Title: Earth Position Locate
Author(s): bcc
Date: 2017-3-16
Desc: Earth Mod
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
local TileManager = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod.TileManager"));
-- local gisToBlocksTask = commonlib.gettable("Mod.EarthMod.gisToBlocksTask");
local curInstance;
local TILE_SIZE = 256 -- 默认瓦片大小
local zoom = 17 -- OSM级数
local locDt = {x = 0.08,z = -0.08} -- OSM与实际显示位置偏移
-- local CENPO = {x=19199,y=5,z=19200} -- paracraft中心点位置

TileManager.tileSize = nil -- 瓦片大小
TileManager.beginPo = nil
TileManager.endPo = nil
TileManager.gSize = nil
TileManager.size = nil
TileManager.row = nil -- 始终保持奇数
TileManager.col = nil -- 始终保持奇数
TileManager.count = 0
TileManager.oPo = nil -- 最左下角瓦片位置(paracraft坐标系)
TileManager.gCen = nil -- 地理位置校园中心点
TileManager.gPo = nil -- 地理位置校园左下点(gps系统经纬度)
TileManager.tiles = {} -- 瓦片合集
TileManager.blocks = {} -- 砖块合集
TileManager.mapStack = {} -- 瓦块下载数据
TileManager.popCount = 0
TileManager.zoomN = nil

function math.round(decimal)
	-- decimal = decimal * 100
    if decimal % 1 >= 0.5 then 
    	decimal = math.ceil(decimal)
    else
    	decimal = math.floor(decimal)
    end
    return decimal--  * 0.01
end

function handler(obj, method)
    return function(...)
       return method(obj,...)
    end
end

-- get current instance
function TileManager.GetInstance()
	return curInstance;
end

-- 传给你左下角的行列号坐标和右上角的行列号坐标，以及当前焦点坐标，然后你返回所有方块对应的几何中心坐标信息
-- firstPo:地图左下角经纬度 lastPo：地图右上角经纬度
function TileManager:ctor() -- 左下行列号，右上行列号，焦点坐标（左下点），瓦片大小
	self.tileSize = self.tileSize or TILE_SIZE
	self.oPo = {x = self.bx,y = self.by,z = self.bz}
	self.col = self.rid - self.lid + 1
	self.row = self.bid - self.tid + 1
	self.beginPo,self.endPo = {x = self.lid, y = self.bid},{x = self.rid,y = self.tid}
	-- 物理坐标（相对于瓦片,即实际地图）

	-- self.gSize = {height = self.lastPo.lat - self.firstPo.lat,width = self.lastPo.lon - self.firstPo.lon}
	-- self.gPo = {x = self.firstPo.lon, y = self.firstPo.lat}
	-- self.gCen = {x = self.gPo.x + self.gSize.width / 2,y = self.gPo.y + self.gSize.height / 2}
	-- echo(self.gSize);echo(self.gPo);echo(self.gCen)
	--
	self.size = {width = self.tileSize * self.col,height = self.tileSize * self.row}
	self.firstBlockPo = {x = math.floor(self.oPo.x - (self.tileSize - 1) / 2),y = self.by,z = math.floor(self.oPo.z - (self.tileSize - 1) / 2)}
	self.count = self.col * self.row
	self.tiles = {}
	self.blocks = {}
	self.mapStack = {}
	self.popCount = 0
	self.zoomN = 2 ^ zoom
	-- self:getDrawPosition(1,1)
	curInstance = self
end

-- 获取总需绘制行列数（返回列数，行数）
function TileManager:getIterSize()
	return self.col,self.row
end

-- 计算瓦片位置(返回行列号和像素点坐标)
function TileManager:getTilePo(tx,ty)
	local Xt,Yt = math.floor(tx), math.floor(ty)
    local Xp,Yp = math.floor((tx - Xt) * self.tileSize), math.floor((ty - Yt) * self.tileSize)
    return Xt, Yt, Xp, Yp
end

-- 经纬度转瓦片行列式
function TileManager:deg2pixel(lon, lat)
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = self.zoomN * ((lon_deg + 180) / 360) * self.tileSize % self.tileSize + 0.5
    local ytile = self.zoomN * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2 * self.tileSize % self.tileSize + 0.5
    return self:getTilePo(xtile, ytile)
end

-- 瓦片行列式转经纬度(参数：瓦片ID，瓦片中所在像素位置，缩放级数)
function TileManager:pixel2deg(tileX, tileY, pixelX, pixelY)
	local lon_deg = (tileX + pixelX / self.tileSize) / self.zoomN * 360.0 - 180.0;
	local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * (tileY + pixelY/self.tileSize) / self.zoomN)))
	local lat_deg = lat_rad * 180.0 / math.pi
	return {lon = lon_deg, lat = lat_deg}
end

-- 遍历绘制瓦片，函数func参数为瓦片中心点位置和瓦片对象，返回结果成功则表示绘制成功瓦片，如果该瓦片之前被绘制过则不执行func
function TileManager:foreach(func)
	for j=1,self.row do
		for i=1,self.col do
			local po,tile = self:getDrawPosition(i,j)
			if not tile.isDrawed then
				if func(po,tile) then tile.isDrawed = true end
			end
		end
	end
end

-- 获取瓦片应该绘制的位置
function TileManager:getDrawPosition(idx,idy)
	local po = {x = self.oPo.x + (idx - 1) * self.tileSize,y = self.oPo.y,z = self.oPo.z + (idy - 1) * self.tileSize}
	local curID = idx + (idy - 1) * self.col
	local ranksID = {x = self.beginPo.x + idx - 1,y = self.beginPo.y - idy + 1}
	if self.tiles[curID] then
		return self.tiles[curID].po,self.tiles[curID]
	else
		local tileInfo = {
			id = curID,
			x = idx,y = idy,
			po = po, -- 瓦片paracraft坐标
			ranksID = ranksID,
			isDrawed = false,
			rect = {l = po.x - self.tileSize / 2,b = po.z - self.tileSize / 2,r = po.x + self.tileSize / 2,t = po.z + self.tileSize / 2}
		}
		self.tiles[curID] = tileInfo
		return po,tileInfo
	end
end

-- 添加砖块数据
function TileManager:pushBlocksData(tile,data)
	if not tile or not data then assert("error set blocks on TileManager:pushBlocksData");return end
	local po = {x = (tile.x - 1) * self.tileSize,y = (tile.y - 1) * self.tileSize}
	for y=1,self.tileSize do
		self.blocks[y] = self.blocks[y] or {}
		for x=1,self.tileSize do
			self.blocks[y + po.y][x + po.x] = data[y][x]
		end
	end
end

-- 检查未绘制的方块并绘制
function TileManager:fillNullBlock(func)
	for y=1,self.size.height do
		for x=1,self.size.width do
			if not self.blocks[y][x] then
				local px,py,pz = x + self.oPo.x,self.oPo.y,y + self.oPo.z
				self.blocks[y][x] = func(self.blocks,x,y,px,py,pz)
			end
		end
	end
end

-- 获取该点处于哪个瓦片上
function TileManager:getInTile(x,y,z)
	if y == nil and z == nil and x and type(x) == "table" then
		z = x.z;y = x.y; x = x.x
	end
	for i,one in pairs(self.tiles) do
		if x >= one.rect.l and x <= one.rect.r and z <= one.rect.t and z >= one.rect.b then
			return one
		end
	end
end

-- para: anchor:百分比定位模式（左至右，下至上为0~1，默认为瓦片百分比，absolute为真则为地图定位）
-- idx idy 为瓦片定位模式对应瓦片的xy下标，id为瓦片总下标定位模式
--[[
 getMapPosition() -- 获取地图全瓦片中心点
 getMapPosition({anchor={x=0,y=0}}) 左下角瓦片中心点
 getMapPosition({anchor={x=1,y=1}}) 右上角瓦片中心点
 getMapPosition({anchor={x=0,y=0},absolute=true}) 最左下角block位置点 对于地图
 getMapPosition({anchor={x=1,y=1},absolute=true}) 最右上角block位置点
 getMapPosition({idx=2,idy=5}) 获取左下角开始 第2列 第5行的瓦片中心点
]]
function TileManager:getMapPosition(para)
	local anchor = {x = 0.5,y = 0.5}
	local po,idx,idy,curID = nil,nil,nil,nil
	local function getPo() if curID and self.tiles[curID] then po = self.tiles[curID].po end end
	local function getIDPo() curID = idx + (idy - 1) * self.col;getPo() end
	local function getPerPo()
		local absolute = para.absolute
		if absolute then
			po = {x = math.floor(self.firstBlockPo.x + anchor.x * self.size.width),y = self.firstBlockPo.y,z = math.floor(self.firstBlockPo.z + anchor.y * self.size.height)}
		else
			idx = math.ceil(self.col * anchor.x)
			idy = math.ceil(self.row * anchor.y)
			getIDPo()
		end
	end
	if not para then para = {absolute = false}; getPerPo() else
		if para.anchor then
			anchor = para.anchor
			getPerPo()
		elseif para.idx and para.idy then
			idx = para.idx;idy = para.idy
			getIDPo()
		elseif para.id then
			curID = para.id
			getPo()
		end
	end
	return po
end

function TileManager:push(data)
	table.insert(self.mapStack,data)
end

function TileManager:pop()
	local len = #self.mapStack
	if len < 1 then return nil,self.popCount end
	local endData = self.mapStack[len]
	table.remove(self.mapStack, len)
	self.popCount = self.popCount + 1
	return endData,self.popCount
end

-- parancraft坐标系转gps经纬度
function TileManager:getGPo(x,y,z)
	if y == nil and z == nil and x and type(x) == "table" then
		z = x.z;y = x.y; x = x.x
	end
	local dx = (x - self.firstBlockPo.x) / self.tileSize + self.beginPo.x
	local dz = self.beginPo.y - (z - self.firstBlockPo.z) / self.tileSize + 1
	return self:pixel2deg(self:getTilePo(dx - locDt.x,dz - locDt.z))
	-- x = (x - self.firstBlockPo.x) / self.size.width * self.gSize.width + self.gPo.x
	-- z = (z - self.firstBlockPo.z) / self.size.height * self.gSize.height + self.gPo.y
	-- {lon = x,lat = z}
end

-- gps经纬度转parancraft坐标系(不传参数为中心点)
function TileManager:getParaPo(lon,lat)
	if lat == nil and lon and type(lon) == "table" then
		lat = lon.lat;lon = lon.lon
	end
	if lon == nil and lat == nil then
		lon = self.gCen.x;lat = self.gCen.y
	end
	local tileX,tileZ,x,z = self:deg2pixel(lon,lat)
	local dx = (tileX - self.beginPo.x + locDt.x) * self.tileSize + x + self.firstBlockPo.x
	local dz = (self.beginPo.y - tileZ - 1 + locDt.z) * self.tileSize + z + self.firstBlockPo.z
	return {x = dx,y = self.firstBlockPo.y,z = dz}
	-- local x = (lon - self.gPo.x) / self.gSize.width * self.size.width + self.firstBlockPo.x
	-- local z = (lat - self.gPo.y) / self.gSize.height * self.size.height + self.firstBlockPo.z
	-- return {x = math.floor(x),y = self.firstBlockPo.y,z = math.floor(z)}
end

-- 获取人物面向朝向
function TileManager:getForward(needStr) -- 正北为0度，东南西为90 180 270
	local player = ParaScene.GetPlayer()
	local facing = player:GetFacing() + 3 -- 0 ~ 6 0 指向西
	local ro = (facing * 60 + 270) % 360 -- 转换为指向旋转度
	if needStr then
		local dt = 10 -- 定位精度（方向的夹角差）
		local tb = {{"北","东"},{"东","南"},{"南","西"},{"西","北"}}
		local a = ro / 90
		local id = math.ceil(a)
		local b = ro - math.floor(a) * 90
		local s1,s2,s = tb[id][1],tb[id][2],nil
		if b <= dt then s = s1
		elseif b >= 90 - dt then s = s2
		else s = s1 .. s2 end
		return ro,s
	end
	return ro
end
-- 设置人物面向朝向
function TileManager:setForward(degree)
	local player = ParaScene.GetPlayer()
	local r = (degree - 270) / 60
	player:SetFacing(r)
end

--[[
-- Object Browsser: CSceneObject->CTerrainTileRoot->listSolidObj->0 下面的Properties标签页
local player = ParaScene.GetPlayer()
local facing = player:GetFacing()
echo(facing)
player:SetFacing(1)
]]