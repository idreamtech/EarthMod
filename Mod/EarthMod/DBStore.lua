--[[
Title: DBStore
Author(s):  Bl.Chock
Date: 2017年4月1日
Desc: using tableDatabase to save game`s config data
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
------------------------------------------------------------
]]

NPL.load("(gl)script/ide/System/Database/TableDatabase.lua");
NPL.load("(gl)script/ide/Json.lua");
NPL.load("(gl)Mod/EarthMod/main.lua");
local TableDatabase = commonlib.gettable("System.Database.TableDatabase");
local DBStore = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.DBStore"));
local EarthMod = commonlib.gettable("Mod.EarthMod");
local curInstance;
DBStore.worldName = nil
DBStore.worldPath = nil
DBStore.dbPath = nil
DBStore.db = nil -- database directory
local XML_MODE = 1 -- xml
local TDB_MODE = 0 -- table database

-- 配置参数 --
local saveMode = XML_MODE -- 存储模式

--------------

function DBStore.GetInstance()
	if curInstance == nil then return DBStore:new() end
	return curInstance;
end

function DBStore:ctor()
	self.worldPath = ParaWorld.GetWorldDirectory() -- echo:"worlds/DesignHouse/ccc/"
	self.worldName = string.sub(self.worldPath,20,-1)
	self.dbPath = self.worldPath .. "EarthDB/"
	echo("connect to:" .. self.dbPath)
	self.db = TableDatabase:new():connect(self.dbPath, function() end);
	curInstance = self
	echo("onInit: DBStore")
end


function DBStore:ConfigDB()
	return self.db.Config
end

function DBStore:MapDB()
	return self.db.Map
end

function DBStore:SystemDB()
	return self.db.Sysm
end

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
-- 

-- 将table数据转换为数据库格式数据
function DBStore:genTable(k,dt)
	if type(dt) == "table" then
		dt.key = k
		return dt
	end
	return {key = k, dbData = dt}
end
-- 将数据库格式数据转换为table数据
function DBStore:getTableValue(tb)
	if tb and type(tb) == "table" then
		if tb.dbData then return tb.dbData end
		tb.key = nil
		return tb
	end
	return nil
end

-- 将表存储到数据库
function DBStore:saveTable(db,tb)
	if db and tb and type(tb) == "table" then
		local data = table.clone(tb)
		-- echo("DBStore:save table")
		local keyTable = {}
		for k,v in pairs(data) do
			self:setValue(db,k,v)
			table.insert(keyTable,k)
		end
		self:setValue(db,"keyTable",keyTable,true)
		self:flush(db)
		echo("DBStore:save table ok")
	end
end

-- 从数据库中读取表 keyTable 不填写读取哪些键则默认将save时所有键读取出来
function DBStore:loadTable(db,func,keyTable)
	local function readFromTable(db,func,kTable)
		self.readData = {}
		self.readCount = #kTable
		for k,key in pairs(kTable) do
			self:getValue(db,key,function(data)
				if data then
					self.readData[key] = data
				end
				self.readCount = self.readCount - 1
				if self.readCount == 0 then
					func(self.readData) -- 读取完所有表数据
				end
			end)
		end
	end
	if keyTable then
		readFromTable(db,func,keyTable)
	else
		self:getOraValue(db,"keyTable",function(err,data)
			if data then
				readFromTable(db,func,data)
			end
		end)
	end
end

function DBStore:packDatabase(db,keys,func)
	if not db then return end
	local function doPack(index)
		self.readData = {}
		self.readCount = #index
		for k,key in pairs(index) do
			self:getValue(db,key,function(data)
				if data then
					self.readData[key] = data
				end
				self.readCount = self.readCount - 1
				if self.readCount == 0 then
					local str = table.toJson(self.readData)
					func(str) -- 读取完所有表数据
				end
			end)
		end
	end
	if keys then
		doPack(keys)
	else
		self:getOraValue(db,"keyTable",function(err,index)
			if index then
				doPack(index)
			end
		end)
	end
end

function DBStore:unpackDatabase(str,db)
	if not str then return end
	local tb = table.fromJson(str)
	if not db then return tb end
	self:saveTable(db,tb)
end

-- 获取数据库中某键的值(如果没有值则err和data都为nil)
function DBStore:getValue(db,k,func)
	db:findOne({key = k}, function(err, data) func(self:getTableValue(data)) end)
end

function DBStore:getOraValue(db,k,func)
	db:findOne({key = k}, function(err, data) func(err, data) end)
end

-- 添加/更新数据库中某键的值,onlyAdd:只添加不修改，存在键则不操作
function DBStore:setValue(db,k,v,onlyAdd)
	self:getValue(db,k,function(data)
		if not data then
			-- echo("DBStore:setValue")
			-- echo(err) -- 打印报错日志
			db:insertOne({key=k},self:genTable(k,v))
		else
			if not onlyAdd then
				-- echo("DBStore:setValue update")
				db:updateOne({key=k}, self:genTable(k,v))
			end
		end
	end)
end
--  保存数据库数据
function DBStore:flush(db,isNow)
	if isNow then
		db:flush({})
	else
		db:waitflush({})
	end
end

-- 将WorldData xml存档转换为数据库数据存储起来
function DBStore:transXmlDataToDB(toDb,keys)
	for k,value in pairs(keys) do
		local xmlData,key
		if type(k) == "string" then key = k else key = value end
		xmlData = EarthMod:GetWorldData(value)
		echo("xmlData " .. key .. " :");echo(xmlData)
		if xmlData and xmlData ~= "" then
			self:setValue(toDb,key,xmlData)
		else
			if type(k) == "string" then
				self:setValue(toDb,k,value)
			end
		end
	end
	self:saveTable(toDb)
end
--[[ using for transfer code
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
-- echo(TileManager.GetInstance().popID)
local dbs = DBStore.GetInstance()
local sys = dbs:SystemDB()
local arr = {"alreadyBlock",schoolName="中国财经大学","coordinate","boundary"}
local func = function(str)
    echo("____db____")
    echo(str)
    echo("____tb____")
    echo(dbs:unpackDatabase(str))
end
dbs:transXmlDataToDB(sys,arr)
dbs:packDatabase(sys,arr,func)

1.设置gisToBlocks中CorrectMode为true 开启测试模式
1.跑transXmlDataToDB
2.packDatabase
3.配置xml位置到服务器校园位置
3.重启。
4.定点校准，重启,关闭CorrectMode模式,开启DrawAllMap
5.绘制完后重启，关闭DrawAllMap
5.后期删除多余建筑


-- 坐标换算：
-- northEastLng <=> maxlon <=> southEastLng
-- southWestLng <=> minlon <=> norhtWestLng
-- northEastLat <=> maxlat <=> northWestLat
-- southWestLat <=> minlat <=> southEastLat
-- 删除建筑代码
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
po1 = {x=21637,y=34,z=20351}
po2 = {x=23315,y=34,z=21681}
for y = po1.y,po2.y do -- 垂直
	for x = po1.x,po2.x do -- 水平x
		for z = po1.z,po2.z do -- 水平y
			BlockEngine:SetBlockToAir(x,y,z)
		end
	end
end
]]

function DBStore:OnLeaveWorld()
	if self.db then
		self.db = nil
	end
	curInstance = nil;
end
