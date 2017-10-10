--[[
Title: TileManager
Author(s): bcc
Date: 2017-3-16
Desc: manager the tiles,a tile has more than 90000 blocks,all information will be saved in database
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/main.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
NPL.load("(gl)Mod/EarthMod/MapGeography.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
local TileManager = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.TileManager"));
local MapGeography = commonlib.gettable("Mod.EarthMod.MapGeography");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local curInstance;
local TILE_SIZE = 256 -- 默认瓦片大小
TileManager.tileSize = nil -- 瓦片大小
TileManager.beginPo = nil
TileManager.endPo = nil
TileManager.size = nil
TileManager.row = nil -- 始终保持奇数
TileManager.col = nil -- 始终保持奇数
TileManager.count = nil
TileManager.firstBlockPo = nil
TileManager.oPo = nil -- 最左下角瓦片位置(paracraft坐标系)
TileManager.tiles = {} -- 瓦片合集 以1,1为起点的瓦片合集
TileManager.blocks = {} -- 砖块合集 以1,1为起点的方块合集
TileManager.mapStack = {}
TileManager.popID = nil
TileManager.isLoaded = nil
TileManager.curTimes = 0
TileManager.passTimes = 0
TileManager.pushMapFlag = {} -- 瓦块下载数据 以1,1为起点的瓦片数据
TileManager.idHL = nil
TileManager.userRotate = 0

function math.round(decimal)
	-- decimal = decimal * 100
    if decimal % 1 >= 0.5 then 
    	decimal = math.ceil(decimal)
    else
    	decimal = math.floor(decimal)
    end
    return decimal--  * 0.01
end

-- get current instance
function TileManager.GetInstance()
	return curInstance;
end

function TileManager:ctor()
	self.tiles = {}
	self.blocks = {}
	self.mapStack = {}
	self.popID = {}
	self.isLoaded = nil
	self.curTimes = 0
	self.passTimes = 0
	self.pushMapFlag = {}
	self.idHL = nil
	self.userRotate = 0
	curInstance = self
end

-- lid = gisToBlocks.tile_MIN_X,bid = gisToBlocks.tile_MIN_Y,
-- rid = gisToBlocks.tile_MAX_X,tid = gisToBlocks.tile_MAX_Y, rotation: 顺时针转多少度
function TileManager:init(para) -- 左下行列号，右上行列号，焦点坐标（左下点），瓦片大小
	self.tileSize = para.tileSize or TILE_SIZE
	self.col = para.rid - para.lid + 1
	if ComVar.usingMap == "BAIDU" then self.row = para.tid - para.bid + 1
	else self.row = para.bid - para.tid + 1 end
	self.userRotate = para.rotation or 0
	self.oPo = {x = para.bx - (self.col - 1) * self.tileSize * 0.5,y = para.by,z = para.bz - (self.row - 1) * self.tileSize * 0.5}
	self.idHL = {col=para.lid,row=para.bid} -- 记录左下角行列式
	self.beginPo = {x = para.lid, y = para.bid}
	self.endPo = {x = para.rid,y = para.tid}
	self.size = {width = self.tileSize * self.col,height = self.tileSize * self.row}
	self.firstBlockPo = self.firstBlockPo or {x = math.floor(self.oPo.x - (self.tileSize - 1) / 2),y = para.by,z = math.floor(self.oPo.z - (self.tileSize - 1) / 2)}
	self.count = self.col * self.row
	self.firstGPo = para.firstPo -- 传入地理位置信息
	self.lastGPo = para.lastPo
	self.firstPo = MapGeography.GetInstance():getParaPo(self.firstGPo.lon,self.firstGPo.lat) -- 计算出标注左下角坐标
	self.lastPo = MapGeography.GetInstance():getParaPo(self.lastGPo.lon,self.lastGPo.lat) -- 计算出标注右上角坐标
	self.cenPo = {x=math.ceil((self.firstPo.x + self.lastPo.x) * 0.5),y=self.firstPo.y,z=math.ceil((self.firstPo.z + self.lastPo.z) * 0.5)}
end

-- 扩充校园；传入新的 firstPo,lastPo,lid,bid,rid,tid 调整瓦片数据, rotation: 顺时针转多少度
function TileManager:reInit(para)
	self.col = para.rid - para.lid + 1
	-- self.row = para.bid - para.tid + 1
	if ComVar.usingMap == "BAIDU" then self.row = para.tid - para.bid + 1
	else self.row = para.bid - para.tid + 1 end
	self.count = self.col * self.row
	self.userRotate = para.rotation or 0
	self.size = {width = self.tileSize * self.col,height = self.tileSize * self.row}
	self.firstGPo = para.firstPo -- 传入地理位置信息
	self.lastGPo = para.lastPo
	self.beginPo,self.endPo = {x = para.lid, y = para.bid},{x = para.rid,y = para.tid}
	-- 计算偏移
	if ComVar.usingMap == "BAIDU" then self.deltaHL = {col=para.lid - self.idHL.col,row=para.bid - self.idHL.row}
	else self.deltaHL = {col=para.lid - self.idHL.col,row=self.idHL.row - para.bid} end
	self.idHL = {col=para.lid,row=para.bid}
	local fbPo = {x = self.firstBlockPo.x + self.deltaHL.col * self.tileSize,y = self.firstBlockPo.y,z = self.firstBlockPo.z + self.deltaHL.row * self.tileSize}
	self.deltaPo = self:pSub(fbPo,self.firstBlockPo) -- 点差
	self.firstBlockPo = fbPo
	self.firstPo = MapGeography.GetInstance():getParaPo(self.firstGPo.lon,self.firstGPo.lat)
	self.lastPo = MapGeography.GetInstance():getParaPo(self.lastGPo.lon,self.lastGPo.lat)
	--
	self.cenPo = {x=math.ceil((self.firstPo.x + self.lastPo.x) * 0.5),y=self.firstPo.y,z=math.ceil((self.firstPo.z + self.lastPo.z) * 0.5)}
	self.oPo = self:pAdd(self.oPo,self.deltaPo)
	-- TileManager.tiles = {} -- 瓦片合集 以1,1为起点的瓦片合集
	if self.tiles and self.tiles ~= {} then
		local tileNew = {}
		for id,tile in pairs(self.tiles) do
			if type(tile) == "table" then
				local idx, idy = tile.x - self.deltaHL.col,tile.y - self.deltaHL.row
				local curID = idx + (idy - 1) * self.col
				tile.id = curID
				tile.x = idx
				tile.y = idy -- po,ranksID不变，因为瓦片实际上并未移动
				tile.isUpdated = nil
				tile.isDrawed = nil
				tile.needFill = nil
				tileNew[curID] = table.clone(tile)
			end
		end
		self.tiles = tileNew
	end
	self.blocks = self:tMov(self.blocks,-self.deltaPo.z,-self.deltaPo.x)
	self.pushMapFlag = self:tMov(self.pushMapFlag,-self.deltaHL.col,-self.deltaHL.row,1)
	self.curTimes = 0
end

-- 水平面paracraft坐标减法
function TileManager:pSub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
function TileManager:pAdd(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
function TileManager:pMul(a,c) return {x=a.x * c,y=a.y * c,z=a.z * c} end
function TileManager:pDiv(a,c) return {x=a.x / c,y=a.y / c,z=a.z / c} end
function TileManager:tMov(tb,dx,dy,dtSet,func) -- 移动表格下标
	if (not tb) or tb == {} then return tb end
	local tbNew = {}
	for i,dtLine in pairs(tb) do
		if type(i) == "number" then
			tbNew[i] = tbNew[i] or {}
			for j,data in pairs(dtLine) do
				if type(j) == "number" then
					local a,b = i + dx,j + dy
					tbNew[a] = tbNew[a] or {}
					tbNew[a][b] = dtSet or table.clone(data)
					if func then
						func(tbNew[a][b],a,b)
					end
				end
			end
		end
	end
	return tbNew
end

function TileManager:db()
	return DBStore.GetInstance():ConfigDB()
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
	if idx < 1 or idx > self.col or idy < 1 or idy > self.row then return nil end
	local po = {x = self.oPo.x + (idx - 1) * self.tileSize,y = self.oPo.y,z = self.oPo.z + (idy - 1) * self.tileSize}
	local curID = idx + (idy - 1) * self.col
	local ranksID = nil -- 行列号
	if ComVar.usingMap == "BAIDU" then ranksID = {x = self.beginPo.x + idx - 1,y = self.beginPo.y + idy - 1}
	else ranksID = {x = self.beginPo.x + idx - 1,y = self.beginPo.y - idy + 1} end
	if self.tiles[curID] then
		return self.tiles[curID].po,self.tiles[curID]
	else
		local tileInfo = {
			id = curID,
			x = idx,y = idy,
			po = po, -- 瓦片paracraft坐标
			ranksID = ranksID,
			isDrawed = false,
			isUpdated = false,
			rect = {l = po.x - self.tileSize / 2,b = po.z - self.tileSize / 2,r = po.x + self.tileSize / 2,t = po.z + self.tileSize / 2}
		}
		self.tiles[curID] = tileInfo
		return po,tileInfo
	end
end

-- 添加砖块数据
function TileManager:pushBlocksData(tile,data)
	if not tile then assert("error set blocks on TileManager:pushBlocksData");return end
	local po = {x = (tile.x - 1) * self.tileSize,y = (tile.y - 1) * self.tileSize}
	for y=1,self.tileSize do
		for x=1,self.tileSize do
			self.blocks[y + po.y] = self.blocks[y + po.y] or {}
			self.blocks[y + po.y][x + po.x] = data[y][x]
		end
	end
end

-- -- 检查未绘制的方块并绘制
function TileManager:fillNullBlock(func)
	if not self.blocks then return end
	for y=1,self.size.height do
		for x=1,self.size.width do
			if self.blocks[y] and self.blocks[y][x] then
				local px,py,pz = x + self.firstBlockPo.x,self.firstBlockPo.y,y + self.firstBlockPo.z
				func(self.blocks[y][x],x,y,px,py,pz)
			end
		end
	end
end

function TileManager:clearFill()
	self.blocks = {}
end

-- 获取该点处于哪个瓦片上
function TileManager:getInTile(x,y,z)
	if y == nil and z == nil and x and type(x) == "table" then
		z = x.z;y = x.y; x = x.x
	end
	for i,one in pairs(self.tiles) do
		if one and type(one) == "table" then
			if (not one.rect) then
				assert(1)
			end
			if x >= one.rect.l and x <= one.rect.r and z <= one.rect.t and z >= one.rect.b then
				return one
			end
		end
	end
	local idx = math.ceil((x - self.firstBlockPo.x) / self.tileSize)
	local idy = math.ceil((z - self.firstBlockPo.z) / self.tileSize)
	return idx,idy
end

-- 获取瓦片对象
function TileManager:getTile(idx,idy)
	if idx < 1 or idx > self.col or idy < 1 or idy > self.row then return nil end
	local curID = idx + (idy - 1) * self.col
	return self.tiles[curID]
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
	if data.id then
		for k,v in pairs(self.popID) do
			if v == data.id then return false end
		end
		for k,v in pairs(self.mapStack) do
			if v and v.id == data.id then return false end
		end
	end
	table.insert(self.mapStack,data)
	return true
end

function TileManager:onFinishPop(id)
	for k,v in pairs(self.popID) do
		if v == id then
			table.remove(self.popID,k)
			return
		end
	end
end

function TileManager:pop()
	local len = #self.mapStack
	if len < 1 then return nil end
	local endData = self.mapStack[len]
	table.remove(self.mapStack, len)
	for k,v in pairs(self.popID) do
		if v == endData.id then
			return endData
		end
	end
	table.insert(self.popID,endData.id)
	return endData
end

-- 坐标系矫正函数
function TileManager:correctPositionSystem(x,y,z,lon,lat)
	local pSys = MapGeography.GetInstance():getParaPo(lon,lat) -- 系统中的位置
	local pCur = {x=x,y=self.firstBlockPo.y,z=z} -- 当前实际位置
	local mov = self:pSub(pCur,pSys)
	echo("矫正 oraPo:");echo(self.firstBlockPo)
	self.firstBlockPo = self:pAdd(self.firstBlockPo,mov)
	self.oPo = self:pAdd(self.oPo,mov)
	echo("toPo:");echo(self.firstBlockPo)
	self.firstPo = MapGeography.GetInstance():getParaPo(self.firstGPo.lon,self.firstGPo.lat) -- 计算出标注左下角坐标
	self.lastPo = MapGeography.GetInstance():getParaPo(self.lastGPo.lon,self.lastGPo.lat) -- 计算出标注右上角坐标
	self.cenPo = {x=math.ceil((self.firstPo.x + self.lastPo.x) * 0.5),y=self.firstPo.y,z=math.ceil((self.firstPo.z + self.lastPo.z) * 0.5)}
	self:Save()
end
-- 坐标系手动微调
function TileManager:correctPo(poDt)
	echo("correctPo oraPo:");echo(self.firstBlockPo)
	self.firstBlockPo = self:pAdd(self.firstBlockPo,poDt)
	self.oPo = self:pAdd(self.oPo,poDt)
	echo("矫正位置 toPo:");echo(self.firstBlockPo)
	self.firstPo = MapGeography.GetInstance():getParaPo(self.firstGPo.lon,self.firstGPo.lat) -- 计算出标注左下角坐标
	self.lastPo = MapGeography.GetInstance():getParaPo(self.lastGPo.lon,self.lastGPo.lat) -- 计算出标注右上角坐标
	self.cenPo = {x=math.ceil((self.firstPo.x + self.lastPo.x) * 0.5),y=self.firstPo.y,z=math.ceil((self.firstPo.z + self.lastPo.z) * 0.5)}
	self:Save()
end

-- 获取人物面向朝向
function TileManager:getForward(needStr) -- 正北为0度，东南西为90 180 270
	local player = ParaScene.GetPlayer()
	local facing = player:GetFacing() + 3 -- 0 ~ 6 0 指向西
	local ro = (facing * 60 + 270) % 360 -- 转换为指向旋转度 --  + self.userRotate
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
		if s == "北东" then s = "东北" elseif s == "南东" then s = "东南"
		elseif s == "南西" then s = "西南" elseif s == "北西" then s = "西北" end
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

-- 存储参数
function TileManager:Save()
	local tileData = {}
	-- set data default:commonlib.Json.Null()
	tileData.tiles = self.tiles
	tileData.tileSize = self.tileSize
	tileData.oPo = self.oPo
	tileData.col = self.col
	tileData.row = self.row
	tileData.beginPo = self.beginPo
	tileData.endPo = self.endPo
	tileData.size = self.size
	tileData.firstBlockPo = self.firstBlockPo
	tileData.count = self.count
	tileData.curTimes = self.curTimes
	tileData.passTimes = self.passTimes
	tileData.pushMapFlag = self.pushMapFlag
	tileData.firstGPo = self.firstGPo -- 传入地理位置信息
	tileData.lastGPo = self.lastGPo
	tileData.idHL = self.idHL
	tileData.userRotate = self.userRotate
	DBStore.GetInstance():saveTable(self:db(),tileData)
end
-- 读取参数
function TileManager:Load()
	DBStore.GetInstance():loadTable(self:db(),function(tileData)
		self.tiles = tileData.tiles
		self.tileSize = tileData.tileSize
		self.oPo = tileData.oPo
		self.col = tileData.col
		self.row = tileData.row
		self.beginPo = tileData.beginPo
		self.endPo = tileData.endPo
		self.size = tileData.size
		self.firstBlockPo = tileData.firstBlockPo
		self.count = tileData.count
		self.curTimes = tileData.curTimes
		self.passTimes = tileData.passTimes
		self.pushMapFlag = tileData.pushMapFlag
		self.firstGPo = tileData.firstGPo -- 传入地理位置信息
		self.lastGPo = tileData.lastGPo
		self.idHL = tileData.idHL
		self.userRotate = tileData.userRotate
		self.firstPo = MapGeography.GetInstance():getParaPo(self.firstGPo.lon,self.firstGPo.lat) -- 计算出标注左下角坐标
		self.lastPo = MapGeography.GetInstance():getParaPo(self.lastGPo.lon,self.lastGPo.lat) -- 计算出标注右上角坐标
		self.cenPo = {x=math.ceil((self.firstPo.x + self.lastPo.x) * 0.5),y=self.firstPo.y,z=math.ceil((self.firstPo.z + self.lastPo.z) * 0.5)}
		self.isLoaded = true
	end)
	echo("onInit: TileManager")
end

-- 检查坐标点是否在标记区域内
function TileManager:checkMarkArea(x, y, z)
	-- return true
	if x >= self.firstPo.x and x <= self.lastPo.x and z >= self.firstPo.z and z <= self.lastPo.z then return true end
	return false
end

-- 二维图形旋转公式（传入原点坐标x0y0 起点坐标x1y1 旋转角度ro 计算返回终点坐标x2y2）
function TileManager:twoDimensionRotate(x0,y0,x1,y1,ro)
	local x2,y2 = nil,nil
	local cos,sin = math.cos(math.rad(ro)),math.sin(math.rad(ro))
	x2 = (x1 - x0) * cos - (y1 - y0) * sin + x0
	y2 = (x1 - x0) * sin + (y1 - y0) * cos + y0
	return x2,y2
end

-- 坐标转换 http://blog.csdn.net/zhouxuguang236/article/details/31820095
function TileManager:coordTransform(x,y,z)
	if (not self.userRotate) or (self.userRotate == 0) or (not self.cenPo) then return x,y,z end
	local x2,z2 = self:twoDimensionRotate(self.cenPo.x,self.cenPo.z,x,z,-self.userRotate)
	return math.floor(x2),y,math.floor(z2)
end

-- 坐标逆向转换
function TileManager:coordReverseTransform(x,y,z)
	if (not self.userRotate) or (self.userRotate == 0) or (not self.cenPo) then return x,y,z end
	local x2,z2 = self:twoDimensionRotate(self.cenPo.x,self.cenPo.z,x,z,self.userRotate)
	return math.floor(x2),y,math.floor(z2)
end

--[[
-- Object Browsser: CSceneObject->CTerrainTileRoot->listSolidObj->0 下面的Properties标签页
local player = ParaScene.GetPlayer()
local facing = player:GetFacing()
-- echo(facing)
player:SetFacing(1)
]]