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
local TableDatabase = commonlib.gettable("System.Database.TableDatabase");
local DBStore = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.DBStore"));
local curInstance;
DBStore.worldName = nil
DBStore.worldPath = nil
DBStore.dbPath = nil
DBStore.db = nil -- database directory

function DBStore.GetInstance()
	if curInstance == nil then return DBStore:new() end
	return curInstance;
end

function DBStore:ctor()
	self.worldPath = ParaWorld.GetWorldDirectory() -- echo:"worlds/DesignHouse/ccc/"
	echo("world path:")
	echo(self.worldPath)
	self.worldName = string.sub(self.worldPath,20,-1)
	-- echo("加载世界：" .. self.worldName)
	self.dbPath = self.worldPath .. "EarthDB/"
	self.db = TableDatabase:new():connect(self.dbPath, function() end);
	curInstance = self
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

-- 将table数据转换为数据库格式数据 local json = commonlib.Json.Encode(tileData)
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
		-- echo("DBStore:save table ok")
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

-- @param object 要克隆的值
-- @return objectCopy 返回值的副本
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