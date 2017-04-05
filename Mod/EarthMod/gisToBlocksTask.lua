--[[
Title: convert any gis to blocks
Author(s): big
Date: 2017/1/24
Desc: transparent pixel is mapped to air. creating in any plane one likes. 
TODO: support depth texture in future. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");
local Tasks = commonlib.gettable("MyCompany.Aries.Game.Tasks");
local task = Tasks.gisToBlocks:new({options="coordinate",lat=lat,lon=lon,cache=cache})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/timer.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
NPL.load("(gl)Mod/EarthMod/main.lua");
NPL.load("(gl)Mod/EarthMod/TileManager.lua");
NPL.load("(gl)Mod/EarthMod/getOsmService.lua");
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemColorBlock.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)Mod/EarthMod/MapBlock.lua");

local Color           = commonlib.gettable("System.Core.Color");
local ItemColorBlock  = commonlib.gettable("MyCompany.Aries.Game.Items.ItemColorBlock");
local UndoManager     = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic       = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local BlockEngine     = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
-- local block_types     = commonlib.gettable("MyCompany.Aries.Game.block_types");
-- local names           = commonlib.gettable("MyCompany.Aries.Game.block_types.names");
local TaskManager     = commonlib.gettable("MyCompany.Aries.Game.TaskManager");
local getOsmService   = commonlib.gettable("Mod.EarthMod.getOsmService");
local EntityManager   = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local CommandManager  = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local EarthMod        = commonlib.gettable("Mod.EarthMod");
local TileManager 	  = commonlib.gettable("Mod.EarthMod.TileManager");
local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
local MapBlock = commonlib.gettable("Mod.EarthMod.MapBlock");

local gisToBlocks = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.gisToBlocks"));

-- operations enumerations
gisToBlocks.Operations = {
	-- load to scene
	Load  = 1,
	-- only load into memory
	InMem = 2,
}
-- current operation
gisToBlocks.operation = gisToBlocks.Operations.Load;
-- how many concurrent creation point allowed: currently this must be 1
gisToBlocks.concurrent_creation_point_count = 1;
-- the color schema. can be 1, 2, 16. where 1 is only a single color. 
gisToBlocks.colors = 32;
gisToBlocks.zoom   = 17;
local factor = 1.19 -- 地图缩放比例
local PngWidth = 256

--RGB, block_id
-- local block_colors = {
-- 	{221, 221, 221,	block_types.names.White_Wool},
-- 	{219,125,62,	block_types.names.Orange_Wool},
-- 	{179,80, 188,	block_types.names.Magenta_Wool},
-- 	{107, 138, 201,	block_types.names.Light_Blue_Wool},
-- 	{177,166,39,	block_types.names.Yellow_Wool},
-- 	{65, 174, 56,	block_types.names.Lime_Wool},
-- 	{208, 132, 153,	block_types.names.Pink_Wool},
-- 	{64, 64, 64,	block_types.names.Gray_Wool},
-- 	{154, 161, 161,	block_types.names.Light_Gray_Wool},
-- 	{46, 110, 137,	block_types.names.Cyan_Wool},
-- 	{126,61,181,	block_types.names.Purple_Wool},
-- 	{46,56,141,		block_types.names.Blue_Wool},
-- 	{79,50,31,		block_types.names.Brown_Wool},
-- 	{53,70,27,		block_types.names.Green_Wool},
-- 	{150, 52, 48,	block_types.names.Red_Wool},
-- 	{25, 22, 22,	block_types.names.Black_Wool},
-- }

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

-- Calculates distance between two RGB colors
local function GetColorDist(colorRGB, blockRGB)
	return math.max(math.abs(colorRGB[1]-blockRGB[1]), math.abs(colorRGB[2]-blockRGB[2]), math.abs(colorRGB[3]-blockRGB[3]));
end

local function GetColorDistBGR(colorBGR, blockRGB)
	return math.max(math.abs(colorBGR[3]-blockRGB[1]), math.abs(colorBGR[2]-blockRGB[2]), math.abs(colorBGR[1]-blockRGB[3]));
end

-- square distance
local function GetColorDist2(colorRGB, blockRGB)
	return ((colorRGB[1]-blockRGB[1])^2) + ((colorRGB[2]-blockRGB[2])^2) + ((colorRGB[3]-blockRGB[3])^2);
end

-- square distance
local function GetColorDist2BGR(colorRGB, blockRGB)
	return ((colorRGB[3]-blockRGB[1])^2) + ((colorRGB[2]-blockRGB[2])^2) + ((colorRGB[1]-blockRGB[3])^2);
end

-- -- find the closest color
-- local function FindClosetBlockColor(pixelRGB)
-- 	local closest_block_color;
-- 	local smallestDist = 100000;
-- 	local smallestDistIndex = -1;
-- 	for i = 1, #block_colors do
-- 		local curDist = GetColorDistBGR(pixelRGB, block_colors[i]);
-- 		-- local curDist = GetColorDist2BGR(pixelRGB, block_colors[i]);

-- 		if (curDist < smallestDist) then
-- 			smallestDist = curDist
-- 			smallestDistIndex = i;
-- 		end
-- 	end
-- 	return block_colors[smallestDistIndex];
-- end

-- @param pixel: {r,g,b,a}
-- @param colors: 1, 2, 3, 16
local function GetBlockIdFromPixel(pixel, colors)
	return "2333", ItemColorBlock:ColorToData(Color.RGBA_TO_DWORD(pixel[3],pixel[2],pixel[1], 0));
	-- if(colors == 1) then
	-- 	return block_types.names.White_Wool;
	-- elseif(colors == 2) then
	-- 	if((pixel[1]+pixel[2]+pixel[3]) > 128) then
	-- 		return block_types.names.White_Wool;
	-- 	else
	-- 		return block_types.names.Black_Wool;
	-- 	end
	-- elseif(colors == 3) then
	-- 	local total = pixel[1]+pixel[2]+pixel[3];
	-- 	if(total > 400) then
	-- 		return block_types.names.White_Wool;
	-- 	elseif(total > 128) then
	-- 		return block_types.names.Brown_Wool;
	-- 	else
	-- 		return block_types.names.Black_Wool;
	-- 	end
	-- elseif(colors == 4) then
	-- 	local total = pixel[1]+pixel[2]+pixel[3];
	-- 	if(total > 500) then
	-- 		return block_types.names.White_Wool;
	-- 	elseif(total > 400) then
	-- 		return block_types.names.Light_Gray_Wool;
	-- 	elseif(total > 128) then
	-- 		return block_types.names.Brown_Wool;
	-- 	elseif(total > 64) then
	-- 		return block_types.names.Gray_Wool;
	-- 	else
	-- 		return block_types.names.Black_Wool;
	-- 	end
	-- elseif(colors <= 16) then
	-- 	local block_color = FindClosetBlockColor(pixel);
	-- 	return block_color[4];
	-- else  -- for 65535 colors, use color block -- block_types.names.ColorBlock 替换为自定义的MapBlock
	-- end
end

function gisToBlocks:ctor()
	self.step = 1;
	self.history = {};
end

function gisToBlocks:AddBlock(spx, spy, spz, block_id, block_data, tile)
	local px, py, pz = EntityManager.GetFocus():GetBlockPos();
	if spx == px and spy == py and spz == pz then
		CommandManager:RunCommand("/goto " .. px .. " " .. py .. " " .. pz) -- 当画到脚下那块时人物跳起来
	end
	if(self.add_to_history) then
		local from_id = BlockEngine:GetBlockId(spx,spy,spz);
		local from_data, from_entity_data;

		if(from_id and from_id>0) then
			from_data = BlockEngine:GetBlockData(spx,spy,spz);
			from_entity_data = BlockEngine:GetBlockEntityData(spx,spy,spz);
		end

		from_id = 0;
		--LOG.std(nil,"debug","AddBlock",{x,y,z,block_id,from_id,from_data,from_entity_data});
		self.history[#(self.history)+1] = {spx,spy,spz, block_id, from_id, from_data, from_entity_data};
	end
	local isUpdate = nil
	if tile then isUpdate = tile.isUpdated end
	MapBlock:addBlock(spx,spy,spz,block_data,isUpdate)
end

function gisToBlocks:drawpixel(cx, cy, cz)
	self:AddBlock(cx,cz,cy,28,0);
end

function gisToBlocks:drawline(cx1, cy1, cx2, cy2, cz)
	--local x, y, dx, dy, s1, s2, p, temp, interchange, i;
	cx=cx1;
	cy=cy1;
	dcx=math.abs(cx2-cx1);
	dcy=math.abs(cy2-cy1);

	if(cx2>cx1) then
		s1=1;
	else
		s1=-1;
	end

	if(cy2 > cy1) then
		s2 = 1;
	else
		s2 = -1;
	end

	if(dcy > dcx) then
		temp = dcx;
		dcx   = dcy;
		dcy   = temp;
	    interchange = 1;
	else
	    interchange = 0;
	end

	p = 2*dcy - dcx;

	for i=1,dcx do
		self:drawpixel(cx,cy,cz);

		if(p>=0) then
			if(interchange==0) then
				cy = cy+s2;
			else
				cx = cx+s1;
			end
			p = p-2*dcx;
		end

		if(interchange == 0) then
			cx = cx+s1; 
		else
			cy = cy+s2;
		end

		p = p+2*dcy;
	end
end

function gisToBlocks:OSMToBlock(vector, px, py, pz)
	local xmlRoot = ParaXML.LuaXML_ParseString(vector);

	if (not xmlRoot) then
		LOG.std(nil, "info", "ParseOSM", "Failed loading OSM");
		_guihelper.MessageBox("Failed loading OSM");
		return;
	end

	local osmnode = commonlib.XPath.selectNodes(xmlRoot, "/osm")[1];

	local osmNodeList = {};
	local count = 1;

	for osmnode in commonlib.XPath.eachNode(osmnode, "/node") do
		osmNodeItem = { id = osmnode.attr.id; lat = osmnode.attr.lat; lon = osmnode.attr.lon; }
		osmNodeList[count] = osmNodeItem;
		count = count + 1;
	end

	local osmBuildingList = {}
	local osmBuildingCount = 0;

	local waynode;
	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
	    local found = false; --only find one building nodes

		local tagnode;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if (tagnode.attr.k == "building") then

				local buildingPointList = {};
				local buildingPointCount = 0;

				--find node belong to building tag way <nd ref="1765621163"/>
				local ndnode;
				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 			
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, 17);
							if (cur_tilex == self.tileX) and (cur_tiley == self.tileY) then
								
								--local str = item.id..","..item.lat..","..item.lon.." -> "..tostring(xpos)..","..tostring(ypos);
								--LOG.std(nil, "info", "found building node:", str);

								--buildingPoint = {id = item.id; x = item.lon; y = item.lat; z = 1; }
								xpos, ypos = deg2pixel(item.lon, item.lat, 17);
								
								buildingPoint = {id = item.id; x = xpos; y = ypos; z = 1; }
								buildingPointCount = buildingPointCount + 1;
								buildingPointList[buildingPointCount] = buildingPoint;
							end					
						end
				    end
			    end

				osmBuilding = {id = waynode.id, points = buildingPointList};
				--LOG.std(nil, "info", "osmBuilding", osmBuilding);
				osmBuildingCount = osmBuildingCount + 1;
				osmBuildingList[osmBuildingCount] = osmBuilding;
				
				found = true;
			end
		end

	    if (found) then
	        --break;
	    end
	end

	local PNGSize = math.ceil(PngWidth * factor);

	for k,v in pairs(osmBuildingList) do
		buildingPointList = v.points;

		if (buildingPointList) then
			local length = #buildingPointList;
			if (length > 3) then
				for i = 1, length - 1 do
					local buildingA = buildingPointList[i];
					buildingA.cx    = px + math.ceil(buildingA.x * factor) - (PngWidth/2);
					buildingA.cy    = pz - math.ceil(buildingA.y * factor) + PNGSize - (PngWidth/2);
					buildingA.cz    = py+1;

					local buildingB = buildingPointList[i + 1];
					buildingB.cx    = px + math.ceil(buildingB.x * factor) - (PngWidth/2);
					buildingB.cy    = pz - math.ceil(buildingB.y * factor) + PNGSize - (PngWidth/2);
					buildingB.cz    = py+1;

					if (buildingA.x < buildingB.x) then
						self:drawline(buildingA.cx , buildingA.cy , buildingB.cx , buildingB.cy , buildingA.cz);
					else
						self:drawline(buildingB.cx , buildingB.cy , buildingA.cx , buildingA.cy , buildingB.cz);
					end
				end
			end
		end
	end
end

-- function gisToBlocks:PNGToBlock(raster, px, py, pz)
-- 	local colors = self.colors;

-- 	if(raster:IsValid()) then
-- 		local ver           = raster:ReadInt();
-- 		local width         = raster:ReadInt();
-- 		local height        = raster:ReadInt();
-- 		local bytesPerPixel = raster:ReadInt();-- how many bytes per pixel, usually 1, 3 or 4

-- 		-- if bytesPerPixel == 0 then bytesPerPixel = 4 end

-- 		LOG.std(nil, "info", "gisToBlocks", {ver, width, height, bytesPerPixel});

-- 		local block_world = GameLogic.GetBlockWorld();

-- 		local function CreateBlock_(ix, iy, block_id, block_data)
-- 			local z;
-- 			spx, spy, spz = px+ix-(PngWidth/2), py, pz+iy-(PngWidth/2);
-- 			ParaBlockWorld.LoadRegion(block_world, spx, spy, spz);

-- 			self:AddBlock(spx, spy, spz, block_id, block_data);
-- 		end
-- 		--array of {r,g,b,a}
-- 		local pixel = {};

-- 		if(bytesPerPixel >= 3) then
-- 			local block_per_tick = 100;
-- 			local count = 0;
-- 			local row_padding_bytes = (bytesPerPixel*width)%4;

-- 			if(row_padding_bytes > 0) then
-- 				row_padding_bytes = 4-row_padding_bytes;
-- 			end
-- 			local worker_thread_co = coroutine.create(function ()
-- 				for iy=1, width do
-- 					for ix=1, height do
-- 						local x,y = math.round(ix * factor), math.round(iy * factor)
-- 						pixel = raster:ReadBytes(bytesPerPixel, pixel);

-- 						if(pixel[4]~=0) then
-- 							-- transparent pixel does not show up. 
-- 							local block_id, block_data = GetBlockIdFromPixel(pixel, colors);
-- 							if(block_id) then
-- 								-- LOG.std(nil,"debug","x,y,block_id,block_data",{x,y,block_id,block_data});
-- 								-- if(x>= 10 and x <= 128 and y >= 10 and y <= 128) then
-- 								CreateBlock_(x, y, block_id, block_data);
-- 								-- end
-- 								if((count%block_per_tick) == 0) then
-- 									coroutine.yield(true);
-- 								end
-- 								count = count + 1;
-- 							end
-- 						end
-- 					end
-- 					if(row_padding_bytes > 0) then
-- 						file:ReadBytes(row_padding_bytes, pixel);
-- 					end
-- 				end
-- 			end)

-- 			local timer = commonlib.Timer:new({callbackFunc = function(timer)
-- 				local status, result = coroutine.resume(worker_thread_co);
-- 				if not status then
-- 					LOG.std(nil, "info", "PNGToBlocks", "finished with %d blocks: %s ", count, tostring(result));
-- 					timer:Change();
-- 					raster:close();
-- 					self:saveOnFinish()
-- 				end
-- 			end})
-- 			timer:Change(30,30);

-- 			UndoManager.PushCommand(self);
-- 		else
-- 			LOG.std(nil, "error", "PNGToBlocks", "format not supported");
-- 			-- for iy=1, width do
-- 			-- 	for ix=1, height do
-- 			-- 		local x,y = math.round(ix / factor), math.round(iy / factor)
-- 			-- 		pixel = raster:ReadBytes(bytesPerPixel, pixel);
-- 			-- 		echo(pixel)
-- 			-- 		-- LOG.std(nil, "error", "bytesPerPixel", pixel[4]);
-- 			-- 	end
-- 			-- end
-- 			raster:close();
-- 		end
-- 	end
-- end

function gisToBlocks:mixColor(cs) -- rgb
	-- 取最深颜色 <   取最浅颜色 >
	table.sort(cs,function(a,b)
		if a[1] + a[2] + a[3] > b[1] + b[2] + b[3] then return true end
		return false
	end)
	return cs[1]
	-- 取平均颜色
	-- local r,g,b,len = 0,0,0,#cs
	-- for i,c in pairs(cs) do
	-- 	r = r + c[1]
	-- 	g = g + c[2]
	-- 	b = b + c[3]
	-- end
	-- return {r / len ,g / len , b / len}
end

function gisToBlocks:genMixColor(tb,x,y)
	if tb[y][x] == nil then
		if tb[y] and tb[y][x - 1] and tb[y][x + 1] then -- 横缺一
			return self:mixColor({tb[y][x - 1],tb[y][x + 1]})
		elseif tb[y - 1] and tb[y + 1] and tb[y - 1][x] and tb[y + 1][x] then -- 竖缺一
			return self:mixColor({tb[y - 1][x],tb[y + 1][x]})
		elseif tb[y - 1] and tb[y + 1] and tb[y - 1][x - 1] and tb[y - 1][x + 1] and tb[y + 1][x - 1] and tb[y + 1][x + 1] then -- 中间缺一
			return self:mixColor({tb[y - 1][x - 1], tb[y - 1][x + 1], tb[y + 1][x - 1], tb[y + 1][x + 1]})
		else
			for i = y - 1,y + 1 do
				if tb[i] and tb[i][x] then return tb[i][x] end
			end
			for j = x - 1,x + 1 do
				if tb[y] and tb[y][j] then return tb[y][j] end
			end
		end
	end
	return tb[y][x]
end

-- 扩大地图到1:1 需修改factor为1.19
function gisToBlocks:PNGToBlockScale(raster, px, py, pz, tile)
	local colors = self.colors;
	if(raster:IsValid()) then
		local ver           = raster:ReadInt();
		local width         = raster:ReadInt();
		local height        = raster:ReadInt();
		local bytesPerPixel = raster:ReadInt();-- how many bytes per pixel, usually 1, 3 or 4
		LOG.std(nil, "info", "PNGToBlockScale", {ver, width, height, bytesPerPixel});
		local block_world = GameLogic.GetBlockWorld();

		local function CreateBlock_(ix, iy, block_id, block_data)
			local spx, spy, spz = px+ix-(PngWidth/2), py, pz+iy-(PngWidth/2);
			if TileManager.GetInstance():checkMarkArea(spx,spy,spz) then
				ParaBlockWorld.LoadRegion(block_world, spx, spy, spz);
				self:AddBlock(spx, spy, spz, block_id, block_data, tile);
			else
				echo("跳过绘制 " .. spx .. "," .. spz)
			end
		end

		local pixel = {};

		if(bytesPerPixel >= 3) then
			local block_per_tick = 300;
			local count = 0;
			local row_padding_bytes = (bytesPerPixel*width)%4;

			if(row_padding_bytes > 0) then
				row_padding_bytes = 4-row_padding_bytes;
			end
			local blocksHistory = {}
			local maxx,maxy = 0,0
			local worker_thread_co = coroutine.create(function ()
				for iy=1, width do
					for ix=1, height do
						local x,y = math.round(ix * factor), math.round(iy * factor)
						pixel = raster:ReadBytes(bytesPerPixel, pixel);
						blocksHistory[y] = blocksHistory[y] or {}
						blocksHistory[y][x] = {pixel[1],pixel[2],pixel[3],pixel[4]}
						if x > maxx then maxx = x end
						if y > maxy then maxy = y end
					end
					if(row_padding_bytes > 0) then
						file:ReadBytes(row_padding_bytes, pixel);
					end
				end
				-- LOG.std(nil,"info","PNGToBlockScale map size: ",maxx .. "," .. maxy)
				for x = 1,maxx do
					for y=1,maxy do
						blocksHistory[y] = blocksHistory[y] or {}
						-- fill gap 补色代码
						if blocksHistory[y][x] == nil then
							local color = self:genMixColor(blocksHistory,x,y)
							if color then
								blocksHistory[y][x] = color
							else
								LOG.std(nil,"info","bug","nil block " .. x .. "," .. y)
							end
						end
						-- 绘制代码
						if blocksHistory[y][x] then
							local block_id, block_data = GetBlockIdFromPixel(blocksHistory[y][x], colors);
							if(block_id) then
								if x == 1 and y == 1 then LOG.std(nil,"info","draw",x .. "," .. y);echo(block_data) end
								CreateBlock_(x, y, block_id, block_data);
								count = count + 1;
								if((count%block_per_tick) == 0) then
									coroutine.yield(true);
								end
							end
						end
						--
					end
				end
				TileManager.GetInstance():pushBlocksData(tile, blocksHistory)
			end)

			local timer = commonlib.Timer:new({callbackFunc = function(timer)
				local status, result = coroutine.resume(worker_thread_co);
				if (not status) then
					timer:Change();
					raster:close();
					tile.isUpdated = true
					TileManager.GetInstance().curTimes = TileManager.GetInstance().curTimes + 1
					LOG.std(nil, "info", "PNGToBlockScale", "finished with %d process: %d / %d ", count, TileManager.GetInstance().curTimes + TileManager.GetInstance().passTimes, TileManager.GetInstance().count);
					self:fillingGap()
					self:saveOnFinish()
				end
			end})
			timer:Change(30,30);

			UndoManager.PushCommand(self);
		else
			LOG.std(nil, "error", "PNGToBlockScale", "format not supported process: %d / %d", TileManager.GetInstance().curTimes + TileManager.GetInstance().passTimes, TileManager.GetInstance().count);
			raster:close();
			TileManager.GetInstance().passTimes = TileManager.GetInstance().passTimes + 1
		end
	end
end

-- 填充所有块
function gisToBlocks:fillingGap()
	local ct = 0
	TileManager.GetInstance():fillNullBlock(function(block,x,y,px,py,pz)
		local data = BlockEngine:GetBlockData(px,py,pz)
		if data == 0 and TileManager.GetInstance():checkMarkArea(px, py, pz) then
			-- LOG.std(nil, "info", "PNGToBlockScale", "filling gap %d,%d .. (%d,%d,%d)",x,y,px,py,pz);
			ct = ct + 1
			local block_id, block_data = GetBlockIdFromPixel(block, self.colors);
			self:AddBlock(px, py, pz, block_id, block_data);
		end
	end)
	echo("填补色块：" .. ct)
	-- end
end

-- function gisToBlocks:MoreScene()
-- 	LOG.std(nil,"debug","direction",gisToBlocks.direction);
-- 	LOG.std(nil,"debug","{dleft,dtop,dright.dbottom}",{gisToBlocks.dleft,gisToBlocks.dtop,gisToBlocks.dright,gisToBlocks.dbottom});

-- 	self.options = "already";
-- 	echo(self.options);

-- 	local abslat = math.abs(gisToBlocks.dleft - gisToBlocks.dright)/2;
-- 	local abslon = math.abs(gisToBlocks.dtop  - gisToBlocks.dbottom)/2;

-- 	echo(tostring(abslat));
-- 	echo(tostring(abslon));

-- 	local direction = gisToBlocks.direction;

-- 	if(direction == "top") then
-- 		px, py, pz = gisToBlocks.pleft + 128, 5 , gisToBlocks.ptop + 128;
-- 		gisToBlocks.morelat = gisToBlocks.dright - abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dtop + abslon;
-- 	end

-- 	if(direction == "bottom") then
-- 		px, py, pz = gisToBlocks.pleft + 128 , 5 , gisToBlocks.pbottom - 128;
-- 		gisToBlocks.morelat = gisToBlocks.dright - abslat;   
-- 		gisToBlocks.morelon = gisToBlocks.dbottom - abslon;
-- 	end

-- 	if(direction == "left") then
-- 		px, py, pz = gisToBlocks.pleft - 128, 5 , gisToBlocks.ptop - 128;
-- 		gisToBlocks.morelat = gisToBlocks.dleft - abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dtop - abslon;
-- 	end

-- 	if(direction == "right") then
-- 		px, py, pz = gisToBlocks.pright + 128, 5 , gisToBlocks.ptop - 128;
-- 		gisToBlocks.morelat = gisToBlocks.dright + abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dtop - abslon;
-- 	end

-- 	if(direction == "lefttop") then
-- 		px, py, pz = gisToBlocks.pleft - 128, 5 , gisToBlocks.ptop + 128;
-- 		gisToBlocks.morelat = gisToBlocks.dleft - abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dtop + abslat;
-- 	end

-- 	if(direction == "righttop") then
-- 		px, py, pz = gisToBlocks.pright + 128, 5 , gisToBlocks.ptop + 128;
-- 		gisToBlocks.morelat = gisToBlocks.dright + abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dtop + abslon;
-- 	end

-- 	if(direction == "leftbottom") then
-- 		px, py, pz = gisToBlocks.pleft - 128, 5 , gisToBlocks.pbottom - 128;
-- 		gisToBlocks.morelat = gisToBlocks.dleft - abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dbottom - abslon;
-- 	end

-- 	if(direction == "rightbottom") then
-- 		px, py, pz = gisToBlocks.pright + 128, 5 , gisToBlocks.pbottom - 128;
-- 		gisToBlocks.morelat = gisToBlocks.dright + abslat;
-- 		gisToBlocks.morelon = gisToBlocks.dbottom - abslon;
-- 	end

-- 	gisToBlocks.mTileX,gisToBlocks.mTileY = deg2tile(gisToBlocks.morelat,gisToBlocks.morelon,self.zoom);

-- 	gisToBlocks.mdleft , gisToBlocks.mdtop    = pixel2deg(gisToBlocks.mTileX,gisToBlocks.mTileY,0,0,self.zoom);
-- 	gisToBlocks.mdright, gisToBlocks.mdbottom = pixel2deg(gisToBlocks.mTileX,gisToBlocks.mTileY,255,255,self.zoom);

-- 	echo({px,py,pz});
-- 	LOG.std(nil,"debug","morelat,morelon",{gisToBlocks.morelat,gisToBlocks.morelon});

-- 	-- self:GetData(function(raster,vector)
-- 	-- 	if factor > 1 then
-- 	-- 		self:PNGToBlockScale(raster, px, py, pz);
-- 	-- 	else
-- 	-- 		self:PNGToBlock(raster, px, py, pz);
-- 	-- 	end
-- 	-- 	-- self:OSMToBlock(vector, px, py, pz);
-- 	-- end);
-- end

function gisToBlocks:LoadToScene(raster,vector,px,py,pz,tile)
	local colors = self.colors;

	-- local px, py, pz = EntityManager.GetFocus():GetBlockPos();

	LOG.std(nil, "info", "gisToBlocks", "方块生成位置: px : "..px.." py : "..py.." pz : "..pz);

	if(not px) then
		return;
	end

	gisToBlocks.ptop    = pz + 128;
	gisToBlocks.pbottom = pz - 128;
	gisToBlocks.pleft   = px - 128;
	gisToBlocks.pright  = px + 128;

	EarthMod:SetWorldData("boundary",{ptop    = gisToBlocks.ptop,
									  pbottom = gisToBlocks.pbottom,
									  pleft   = gisToBlocks.pleft,
									  pright  = gisToBlocks.pright});
	EarthMod:SaveWorldData();
	
	LOG.std(nil,"debug","gisToBlocks","加载方块和贴图");
	-- if factor > 1 then
	self:PNGToBlockScale(raster, px, py, pz, tile);
	-- else
	-- 	self:PNGToBlock(raster, px, py, pz, tile);
	-- end
	-- self:OSMToBlock(vector, px, py, pz);

	-- self.isDrawing = false
end

function gisToBlocks:GetData(x,y,i,j,_callback)
	local raster,vector;
	local tileX,tileY;
	local dtop,dbottom,dleft,dright;
	
	if(self.options == "already") then
		tileX = gisToBlocks.mTileX;
		tileY = gisToBlocks.mTileY;
		
		dtop    = gisToBlocks.mdtop;
		dbottom = gisToBlocks.mdbottom;
		dleft   = gisToBlocks.mdleft;
		dright  = gisToBlocks.mdright;

		--LOG.std(nil,"debug","tileX,tileY,dtop,dbottom,dleft,dright",{tileX,tileY,dtop,dbottom,dleft,dright});
	end

	if(self.options == "coordinate") then
		tileX = gisToBlocks.tileX;
		tileY = gisToBlocks.tileY;

		dtop    = gisToBlocks.dtop;
		dbottom = gisToBlocks.dbottom;
		dleft   = gisToBlocks.dleft;
		dright  = gisToBlocks.dright;
	end

	self.cache = 'true';
	if(self.cache == 'true') then
		GameLogic.SetStatus(L"下载数据中");
		LOG.std(nil,"debug","gisToBlocks","下载数据中");
		getOsmService:getOsmPNGData(x,y,i,j,function(raster)
			getOsmService:getOsmXMLData(x,y,i,j,function(vector)
				raster = ParaIO.open("tile_"..x.."_"..y..".png", "image");
				-- local vectorFile = ParaIO.open("xml_"..x.."_"..y..".osm", "r");
				-- local vector = vectorFile:GetText(0, -1);
				-- vectorFile:close();
				GameLogic.SetStatus(L"下载成功");
				LOG.std(nil,"debug","gisToBlocks","下载成功");
				_callback(raster,vector);
			end);
		end);
	else
		local vectorFile;

		raster     = ParaIO.open("tile.png", "image");
		vectorFile = ParaIO.open("xml.osm", "r");
		vector     = vectorFile:GetText(0, -1);
		vectorFile:close();

		_callback(raster,vector);
	end
end

function gisToBlocks:FrameMove()
	self.finished = true;
end

function gisToBlocks:Redo()
	if((#self.history)>0) then
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], b[4]);
		end
	end
end

function gisToBlocks:Undo()
	if((#self.history)>0) then
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], b[5] or 0, b[6], b[7]);
		end
	end
end

-- 绘制玩家周围一圈地图
function gisToBlocks:BoundaryCheck()
	-- if self.isDrawing then return false end
	local px, py, pz = EntityManager.GetFocus():GetBlockPos();
	local cx,cy = TileManager.GetInstance():getInTile(px, py, pz) -- self.gx,self.gy
	if type(cx) == "table" then cy = cx.y;cx = cx.x end
	local function checkAddMap(x,y)
		local tile = TileManager.GetInstance():getTile(x,y)
		if (not tile) or (not tile.isDrawed) then
			self:downloadMap(x,y)
		end
	end
	for x = cx - 1,cx + 1 do -- 九宫格绘制
		for y = cy - 1,cy + 1 do
			checkAddMap(x,y)
		end
	end
	return true
end

-- 申请下载地图
function gisToBlocks:downloadMap(i,j)
	TileManager.GetInstance().pushMapFlag[i] = TileManager.GetInstance().pushMapFlag[i] or {}
	if not TileManager.GetInstance().pushMapFlag[i][j] then
		local po,tile = TileManager.GetInstance():getDrawPosition(i,j);
		if tile and (not tile.isDrawed) then
			LOG.std(nil,"debug","gosToBlocks","添加绘制任务 " .. tile.x .. "," .. tile.y);
			TileManager.GetInstance():push(tile)
			TileManager.GetInstance().pushMapFlag[i][j] = true
		end
	end
end

function gisToBlocks:startDrawTiles()
	local function onDraw(tile)
		LOG.std(nil,"debug","gosToBlocks","绘制地图： " .. tile.x .. "," .. tile.y);
		tile.isDrawed = true
		local po = tile.po
		getOsmService.tileX = tile.ranksID.x;
		getOsmService.tileY = tile.ranksID.y;
		self:GetData(tile.ranksID.x,tile.ranksID.y,tile.x,tile.y,function(raster,vector)
			LOG.std(nil,"debug","gosToBlocks","getData");
			self:LoadToScene(raster,vector,po.x,po.y,po.z,tile);
		end);
		LOG.std(nil,"debug","gosToBlocks","绘制完成一张");
	end
	local timerGet = commonlib.Timer:new({callbackFunc = function(timer)
		tile,popCount = TileManager.GetInstance():pop()
		if tile and (not tile.isDrawed) then
			onDraw(tile)
		-- else
			-- LOG.std(nil,"nextRaster","等待绘制地图" .. popCount .. ".. " .. timer.lastTick, timer.id .. "," .. timer.delta)
		end
		if popCount >= TileManager.GetInstance().count then
			LOG.std(nil,"nextRaster","绘制完成所有地图，绘制次数",popCount)
			timer:Change()
		end
	end})
	timerGet:Change(2000,2000); -- 每秒获取一次图片状态
end

function gisToBlocks:Run()
	self.finished = true;
	-- echo("读取方块数据")
	-- echo(BlockEngine:GetBlockData(19213,100,19799));
	-- echo(BlockEngine:GetBlockEntityData(19213,100,19799))

	if(self.options == "already" or self.options == "coordinate") then
		-- LOG.std(nil,"debug","self.lon,self.lat",{self.lon,self.lon});
		gisToBlocks.tileX , gisToBlocks.tileY   = deg2tile(self.minlon,self.minlat,self.zoom);
		gisToBlocks.dleft , gisToBlocks.dtop    = pixel2deg(self.tileX,self.tileY,0,0,self.zoom);
		gisToBlocks.dright, gisToBlocks.dbottom = pixel2deg(self.tileX,self.tileY,255,255,self.zoom);
		
		getOsmService.dleft   = gisToBlocks.dleft;
		getOsmService.dtop    = gisToBlocks.dtop;
		getOsmService.dright  = gisToBlocks.dright;
		getOsmService.dbottom = gisToBlocks.dbottom;
		getOsmService.zoom = self.zoom;
		
		if(self.options == "already") then
			local boundary = EarthMod:GetWorldData("boundary");
			gisToBlocks.ptop    = boundary.ptop;
			gisToBlocks.pbottom = boundary.pbottom;
			gisToBlocks.pleft   = boundary.pleft;
			gisToBlocks.pright  = boundary.pright;
			self:initWorld()
		end
	end

	if(self.options == "coordinate") then
		if(GameLogic.GameMode:CanAddToHistory()) then
			self.add_to_history = false;
		end
		self:initWorld()
		self:BoundaryCheck() -- 绘制人物周围9块
		local po = TileManager.GetInstance():getParaPo()
		-- 跳转到地图中间
		CommandManager:RunCommand("/goto " .. po.x .. " " .. po.y .. " " .. po.z)
		echo("传送 " .. po.x .. "," ..  po.y .. "," ..  po.z .. ",")
		--

		-- local firstLon, firstLat = pixel2deg(gisToBlocks.tile_MIN_X,gisToBlocks.tile_MIN_Y,0,0,self.zoom);
		-- local lastLon, lastLat = pixel2deg(gisToBlocks.tile_MAX_X,gisToBlocks.tile_MAX_Y,255,255,self.zoom);
		-- local firstPo, lastPo = {lat = firstLat,lon = firstLon},{lat = lastLat,lon = lastLon};
		-- LOG.std(nil,"debug","gisToBlocks","获取到的地图经纬度");
		-- echo(firstPo);echo(lastPo)
		-- echo(self.minlon .. "," .. self.minlat);echo(self.maxlon .. "," .. self.maxlat)
		
		--
		-- 获取区域范围瓦片的列数和行数


		-- 计算,测试需要,最多只加载指定区域范围内的4个瓦片
		-- local count = 0;
		-- for j=1,rows do
		-- 	for i=1,cols do
		-- 		local po,tile = TileManager.GetInstance():getDrawPosition(i,j);
		-- 		getOsmService.tileX = tile.ranksID.x;
		-- 		getOsmService.tileY = tile.ranksID.y;
		-- 		LOG.std(nil,"debug","gisToBlocks","待获取瓦片的XY坐标: "..tile.ranksID.x.."-"..tile.ranksID.y .." po:"..po.x..","..po.y..","..po.z);
		-- 		self:GetData(tile.ranksID.x,tile.ranksID.y,i,j,function(raster,vector)
		-- 			count = count + 1;
		-- 			self:LoadToScene(raster,vector,po.x,po.y,po.z, tile);
		-- 		end);
		-- 		LOG.std(nil,"debug","gisToBlocks","after getData");
		-- 	end
		-- end
		-- SelectLocationTask.isDownLoaded = nil
		-- -- timer定时检查图片是否下载完成,count值等于rows*cols乘积时候才执行生成方块操作
		-- local loadToSceneTimer = commonlib.Timer:new({callbackFunc = function(loadToSceneTimer)
		-- 	if (count == (cols * rows)) then
		-- 		LOG.std(nil,"debug","gisToBlocks","即将加载方块和贴图信息");
		-- 		for j=1,rows do
		-- 			for i=1,cols do
		-- 				local po,tile = TileManager.GetInstance():getDrawPosition(i,j);
		-- 				local raster = ParaIO.open("tile_"..tile.ranksID.x.."_"..tile.ranksID.y..".png", "image");
		-- 				self:LoadToScene(raster,vector,po.x,po.y,po.z,tile);
		-- 			end
		-- 		end
		-- 		loadToSceneTimer:Change();
		-- 		SelectLocationTask.isDownLoaded = true
		-- 	end
		-- end});
		-- loadToSceneTimer:Change(10000,10000);
	end
end

function gisToBlocks:initWorld()
	if self.minlon and self.minlat and self.maxlon and self.maxlat and (not SelectLocationTask.isDownLoaded) then
		-- 根据minlat和minlon计算出左下角的瓦片行列号坐标
		gisToBlocks.tile_MIN_X , gisToBlocks.tile_MIN_Y   = deg2tile(self.minlon,self.minlat,self.zoom);
		-- 根据maxlat和maxlon计算出右上角的瓦片行列号坐标
		gisToBlocks.tile_MAX_X , gisToBlocks.tile_MAX_Y   = deg2tile(self.maxlon,self.maxlat,self.zoom);
		LOG.std(nil,"debug","gisToBlocks","tile_MIN_X : "..gisToBlocks.tile_MIN_X.." tile_MIN_Y : "..gisToBlocks.tile_MIN_Y);
		LOG.std(nil,"debug","gisToBlocks","tile_MAX_X : "..gisToBlocks.tile_MAX_X.." tile_MAX_Y : "..gisToBlocks.tile_MAX_Y);
		-- 初始化地图数据
		local px, py, pz = EntityManager.GetFocus():GetBlockPos();
		local tileManager = TileManager.GetInstance():init({
			lid = gisToBlocks.tile_MIN_X,bid = gisToBlocks.tile_MIN_Y,
			rid = gisToBlocks.tile_MAX_X,tid = gisToBlocks.tile_MAX_Y,
			bx = px,by = py,bz = pz,tileSize = math.ceil(PngWidth * factor),
			firstPo = {lat=self.minlat,lon=self.minlon},lastPo = {lat=self.maxlat,lon=self.maxlon}, -- 传入地理位置信息
		})
		self.cols, self.rows = TileManager.GetInstance():getIterSize();
		LOG.std(nil,"debug","gisToBlocks","cols : "..self.cols.." rows : ".. self.rows);
		self:startDrawTiles()

		local roleGPo = TileManager.GetInstance():getGPo(EntityManager.GetFocus():GetBlockPos()) --  这个获取的不能实时更新
		LOG.std(nil,"RunFunction 获取到人物的地理坐标","经度：" .. roleGPo.lon,"纬度：" .. roleGPo.lat)
		LOG.std(nil,EntityManager.GetFocus():GetBlockPos())
		-- 更新SelectLocationTask.player_lon和SelectLocationTask.player_lat(人物当前所处经纬度)信息
		local sltInstance = SelectLocationTask.GetInstance();
		sltInstance:setPlayerCoordinate(roleGPo.lon, roleGPo.lat);
		-- timer定时更新人物坐标信息
		self:refreshPlayerInfo()
		SelectLocationTask.isDownLoaded = true
	end
end

-- 更新人物信息
function gisToBlocks:refreshPlayerInfo()
	local sltInstance = SelectLocationTask.GetInstance();
	local playerLocationTimer = playerLocationTimer or commonlib.Timer:new({callbackFunc = function(playerLocationTimer)
			-- 获取人物坐标信息
			if SelectLocationTask.player_curLon and SelectLocationTask.player_curLat then
				local curLon,curLat = SelectLocationTask.player_curLon,SelectLocationTask.player_curLat
				SelectLocationTask.player_lon = curLon
				SelectLocationTask.player_lat = curLat
				local po = TileManager.GetInstance():getParaPo(curLon,curLat)
				CommandManager:RunCommand("/goto " .. po.x .. " " .. po.y .. " " .. po.z)
				echo("人物跳转开始");echo(po)
				SelectLocationTask.player_curLon = nil
				SelectLocationTask.player_curLat = nil
				SelectLocationTask.player_curState = po
			else
				local x, y, z = EntityManager.GetFocus():GetBlockPos();
				if SelectLocationTask.player_curState then
					if SelectLocationTask.player_curState.x == x and SelectLocationTask.player_curState.z == z then
						SelectLocationTask.player_curState = nil
					else
						x,y,z = SelectLocationTask.player_curState.x,SelectLocationTask.player_curState.y,SelectLocationTask.player_curState.z
					end
				end
				local player_latLon = TileManager.GetInstance():getGPo(x, y, z);
				local ro,str = TileManager.GetInstance():getForward(true)
				local lon,lat,ron = math.floor(player_latLon.lon * 10000) / 10000,math.floor(player_latLon.lat * 10000) / 10000,math.floor(ro * 100) / 100
				local poInfo = "经度:" .. lon .. " 纬度:" .. lat
				local foInfo = "人物朝向: " .. ron .. "° " .. str
				local fiInfo = "已加载:" .. TileManager.GetInstance().curTimes .. "/" .. TileManager.GetInstance().count
				GameLogic.AddBBS("statusBar", poInfo .. " " .. foInfo .. " " .. fiInfo, 15000, "223 81 145"); -- 显示提示条
				sltInstance:setPlayerCoordinate(player_latLon.lon, player_latLon.lat);
			end
	end});
	playerLocationTimer:Change(1000,1000);
end

-- 存储一次数据
function gisToBlocks:saveOnFinish()
	TileManager.GetInstance():Save()
	CommandManager:RunCommand("/save");
end