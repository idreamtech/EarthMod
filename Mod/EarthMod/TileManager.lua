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
-- local CENPO = {x=19199,y=5,z=19200} -- paracraft中心点位置

TileManager.tileSize = nil -- 瓦片大小
TileManager.beginPo = nil
TileManager.endPo = nil
-- TileManager.gSize = nil
TileManager.size = nil
TileManager.row = nil -- 始终保持奇数
TileManager.col = nil -- 始终保持奇数
TileManager.oPo = nil -- 最左下角瓦片位置(paracraft坐标系)
-- TileManager.gCen = nil -- 地理位置校园中心点
-- TileManager.gPo = nil -- 地理位置校园左下点(gps系统经纬度)
TileManager.tiles = {}

-- get current instance
function TileManager.GetInstance()
	return curInstance;
end

-- 传给你左下角的行列号坐标和右上角的行列号坐标，以及当前焦点坐标，然后你返回所有方块对应的几何中心坐标信息
function TileManager:ctor() -- 左下行列号，右上行列号，焦点坐标（左下点），瓦片大小

	self.tileSize = tileSize or TILE_SIZE
	self.oPo = {x = self.bx,y = self.by,z = self.bz}
	self.col = self.rid - self.lid + 1
	self.row = self.bid - self.tid + 1
	self.beginPo,self.endPo = {x = self.lid, y = self.bid},{x = self.rid,y = self.tid}
	self.size = {width = self.tileSize * self.col,height = self.tileSize * self.row}
	self.tiles = {}
	-- self:getDrawPosition(1,1)
	curInstance = self
end

-- 获取总需绘制行列数（返回列数，行数）
function TileManager:getIterSize()
	return self.col,self.row
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
			rect = {l = po.x - self.tileSize / 2,b = po.y - self.tileSize / 2,r = po.x + self.tileSize / 2,t = po.y + self.tileSize / 2}
		}
		self.tiles[curID] = tileInfo
		return po,tileInfo
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


-- -- parancraft坐标系转gps经纬度
-- function TileManager:getGPo(x,y,z)
-- 	if y == nil and z == nil and x and type(x) == "table" then
-- 		z = x.z;y = x.y; x = x.x
-- 	end
-- 	x = (x - self.oPo.x) / self.size.width * self.gSize.width + self.gPo.x
-- 	z = (z - self.oPo.z) / self.size.height * self.gSize.height + self.gPo.y
-- 	return {lon = x,lat = z}
-- end

-- -- gps经纬度转parancraft坐标系
-- function TileManager:getPo(lon,lat)
-- 	if lat == nil and lon and type(lon) == "table" then
-- 		lat = lon.lat;lon = lon.lon
-- 	end
-- 	local x = (lon - self.gPo.x) / self.gSize.width * self.size.width + self.oPo.x
-- 	local z = (lat - self.gPo.y) / self.gSize.height * self.size.height + self.oPo.z
-- 	return {x = x,y = 5,z = z}
-- end

--[[

NPL.load("(gl)Mod/EarthMod/TileManager.lua");
local TileManager = commonlib.gettable("Mod.EarthMod.TileManager");


function gisToBlocks:LoadToScene(raster,vector)
	local colors = self.colors;
	-- local px, py, pz = EntityManager.GetFocus():GetBlockPos();
	-- py = 5
	-- 获取应该绘制的瓦片位置
	local po = TileManager.curInstance:getDrawPosition({"瓦片对象"},self.tileX,self.tileY)
	local px, py, pz = po.x,po.y,po.z
	EntityManager.GetFocus():setBlockPos(px, py, pz)
	-- 

	 -- _guihelper.MessageBox("人物坐标：" .. px .. "," .. py .. "," .. pz);
	gisToBlocks.ptop    = pz + 128;
	gisToBlocks.pbottom = pz - 128;
	gisToBlocks.pleft   = px - 128;
	gisToBlocks.pright  = px + 128;
	...
end



function gisToBlocks:Run()
	...
	-- 初始化瓦片管理器
	if TileManager.GetInstance() == nil then
		TileManager:new(nil,nil,gisToBlocks.dright - gisToBlocks.dleft,gisToBlocks.dtop - gisToBlocks.dbottom)
	end
	-- 
	...
end




-- -- paracraft: o(512,5,16)  center(19199,5,19200) 地图大小 256 * 256
-- -- 深大：（左下）纬度：22.5308 | 经度：113.9250 ~ （右上）纬度：22.5423 | 经度：113.9395
-- -- 湖南大学：（左下）纬度：28.1742 | 经度：112.9331 ~ （右上）纬度lat：28.1864 | 经度lon：112.9446  大约 5 * 7 = 35块瓦片
-- function TileManager:ctor(beginPo,endPo,tileW,tileH)
-- 	self.beginPo = beginPo or {lat = 28.1742,lon = 112.9331}
-- 	self.endPo = endPo or {lat = 28.1864,lon = 112.9446}
-- 	self.gSize = {height = self.endPo.lat - self.beginPo.lat,width = self.endPo.lon - self.beginPo.lon}
-- 	self.row = math.ceil(self.gSize.height / tileH)
-- 	self.col = math.ceil(self.gSize.width / tileW)
-- 	if self.col % 2 == 0 then self.col = self.col + 1 end
-- 	if self.row % 2 == 0 then self.row = self.row + 1 end
-- 	self.size = {width = TILE_SIZE * self.col,height = TILE_SIZE * self.row}
-- 	self.oPo = {x = math.floor(CENPO.x - self.size.width / 2), y = CENPO.y, z = math.floor(CENPO.z - self.size.height / 2)}
-- 	self.tiles = {}
-- 	self.gPo = {x = self.beginPo.lon, y = self.beginPo.lat}
-- 	self.gCen = {x = self.gPo.x + self.gSize.width / 2,y = self.gPo.y + self.gSize.height / 2}
-- 	-- local curID = math.floor(self.row / 2) * self.col + math.ceil(self.col / 2)
-- 	self:getDrawPosition(math.ceil(self.col / 2), math.ceil(self.row / 2))
-- 	curInstance = self
-- end
]]