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
NPL.load("(gl)Mod/EarthMod/DBStore.lua");
NPL.load("(gl)Mod/EarthMod/NetManager.lua");
NPL.load("(gl)Mod/EarthMod/MapGeography.lua");
local PngWidth = 256
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
local NetManager = commonlib.gettable("Mod.EarthMod.NetManager");
local MapGeography = commonlib.gettable("Mod.EarthMod.MapGeography");
local DBStore = commonlib.gettable("Mod.EarthMod.DBStore");
local DBS,SysDB

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
gisToBlocks.crossPointLists = {};
gisToBlocks.isMapping = nil -- 是否正在绘制地图
gisToBlocks.isDrawedAllMap = nil

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
	if tile then
		if tile.needFill then isUpdate = "fill" else isUpdate = tile.isUpdated end
	end
	MapBlock:addBlock(spx,spy,spz,block_data,isUpdate)
end


function gisToBlocks:drawpixel(x, z, y, block_data)
	if TileManager.GetInstance():checkMarkArea(x,y,z) then -- 不绘制未加载的
		MapBlock:addBlock(x, y, z, block_data, "fill", true) -- 只要是空气就可以填补
	end
end

function gisToBlocks:floodFillScanline()
	
end

function gisToBlocks:drawline(x1, y1, x2, y2, z, block_data)
	--local x, y, dx, dy, s1, s2, p, temp, interchange, i;
	if math.abs(x2-x1) > math.abs(y2-y1) then  
        steps = math.abs(x2 - x1);  
    else
        steps = math.abs(y2 - y1);  
    end  
        increx = (x2 - x1)/steps;  
        increy = (y2 - y1)/steps;  
        x = x1;  
        y = y1;  
    for i = 0,steps do  
        self:drawpixel(x,y,z,block_data);  
        x = x + increx;
        y = y + increy;
    end  
end

function gisToBlocks:OSMToBlock(vector, px, py, pz, tile)
	if not vector then return end
	local xmlRoot = ParaXML.LuaXML_ParseString(vector);
	local tileX,tileY = tile.ranksID.x,tile.ranksID.y;
	MapBlock:deleteArea({x = tile.rect.l,y = ComVar.FloorLevel + 1,z = tile.rect.b},{x = tile.rect.r,y = ComVar.FloorLevel + ComVar.buildLevelMax + 1,z = tile.rect.t})
	LOG.std(nil,"debug","tileX,tileY",{tileX,tileY});

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

	local function draw2Point(self,PointList,block_data,type)
		local PNGSize = math.ceil(PngWidth*ComVar.factor);
		local pointA,pointB;

		if (PointList) then
			local length = #PointList;

			if (length > 3) then
				for i = 1, length - 1 do
					pointA = PointList[i];
					pointB = PointList[i + 1];

					if(type ~= "buildingMore" and type ~= "waterMore") then
						pointA.cx = px + math.ceil(pointA.x*ComVar.factor) - PNGSize/2;
						pointA.cy = pz - math.ceil(pointA.y*ComVar.factor) + PNGSize - PNGSize/2;

						pointB.cx = px + math.ceil(pointB.x*ComVar.factor) - PNGSize/2;
						pointB.cy = pz - math.ceil(pointB.y*ComVar.factor) + PNGSize - PNGSize/2;
					end

					pointA.cz = pointA.z;
					pointB.cz = pointB.z;

					local function floor(self)
						if (pointA.cx < pointB.cx) then
							self:drawline(pointA.cx, pointA.cy, pointB.cx, pointB.cy, pointA.cz, block_data);
						else
							self:drawline(pointB.cx, pointB.cy, pointA.cx, pointA.cy, pointB.cz, block_data);
						end
					end

					if(type == "building" or type == "buildingMore") then
						--echo(pointA.level);
						for i = 1, ComVar.buildLevelHeight * pointA.level do
							floor(self);
							--echo(pointA.cz);
							pointA.cz = pointA.cz + 1;
							pointB.cz = pointB.cz + 1;
						end
					else
						floor(self);
					end
				end
			end
		end
	end

	local function draw2area(self,PointList,blockId,type)
		if (PointList) then
			local point = {left = PointList[1].cx, right = PointList[1].cx, top = PointList[1].cy, bottom = PointList[1].cy};
			local currentPoint;

			if(type == "building" or type == "buildingMore") then
				point.level = PointList[1].level;
			end

			local length = #PointList;

			if (length > 3) then
				for k,v in pairs(PointList) do
					currentPoint = PointList[k];

					--get right point
					if(currentPoint.cx < point.left) then
						point.left  = currentPoint.cx;
					end

					--get left point
					if(currentPoint.cx > point.right) then
						point.right = currentPoint.cx;
					end

					--get top point
					if(currentPoint.cy > point.top) then
						point.top    = currentPoint.cy;
					end

					--get bottom point
					if(currentPoint.cy < point.bottom) then
						point.bottom = currentPoint.cy;
					end

					--echo({k,v});
				end
			end

			local startPoint = {cx = point.left, cy = point.bottom};
			local endPoint   = {cx = point.right, cy = point.top};
			
			if(type == "building" or type == "buildingMore") then
				startPoint.cz    = 5 + point.level * ComVar.buildLevelHeight;
				endPoint.cz      = 5 + point.level * ComVar.buildLevelHeight;
			else
				startPoint.cz = 6;
				endPoint.cz   = 6;
			end

			currentPoint = {};
			currentPoint = commonlib.copy(startPoint);

			local linePoint = {};

			if(currentPoint.cy)then
				while(currentPoint.cx <= endPoint.cx) do
					local loopY = commonlib.copy(currentPoint.cy);
					local currentblockId;
					local lastblockId

					while(loopY <= endPoint.cy) do
						local currentBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,loopY);
						local count = 0;

						if(currentBlockId == 0) then
							local judgeX = commonlib.copy(currentPoint.cx);
							while(judgeX <= endPoint.cx) do
								local judgeXBlockId = BlockEngine:GetBlockId(judgeX,currentPoint.cz,loopY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeX = judgeX + 1;
							end

							local judgeX = commonlib.copy(currentPoint.cx);
							while(judgeX >= startPoint.cx) do
								local judgeXBlockId = BlockEngine:GetBlockId(judgeX,currentPoint.cz,loopY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeX = judgeX - 1;
							end

							local judgeY = commonlib.copy(loopY);
							while(judgeY <= endPoint.cy) do
								local judgeXBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,judgeY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeY = judgeY + 1;
							end

							local judgeY = commonlib.copy(loopY);
							while(judgeY >= startPoint.cy) do
								local judgeXBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,judgeY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeY = judgeY - 1;
							end

							if(count == 4) then
								local height;
								height = currentPoint.cz;

								if(type == "waterMore") then
									for i=1,4 do
										height = height - 1;
										self:drawpixel(currentPoint.cx,loopY,height,blockId)
										-- BlockEngine:SetBlock(currentPoint.cx,height,loopY,blockId,0);
									end
								else
									self:drawpixel(currentPoint.cx,loopY,height,blockId)
									-- BlockEngine:SetBlock(currentPoint.cx,height,loopY,blockId,0);
								end
							end
						end

						loopY = loopY + 1;
					end
					currentPoint.cx = currentPoint.cx + 1;
				end
			end
		end
	end

	local osmBuildingList  = {}
	local osmBuildingCount = 0;

	local osmHighWayList   = {};
	local osmHighWayCount  = 0;

	local osmWaterList     = {};
	local osmWaterCount    = 0;

	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
		local buildingLevel = 1;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if(tagnode.attr.k == "building:levels") then
				buildingLevel = commonlib.copy(tagnode.attr.v);
			end

			--LOG.std(nil,"debug","buildingLevel",buildingLevel);
		end

		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			---------building start----------
			if(tagnode.attr.k == "building") then
				local buildingPoint;
				local buildingPointList  = {};
				local buildingPointCount = 0;

				local isNew = true;
				if(#gisToBlocks.crossPointLists ~= 0) then
					for key,crossBuildingList in pairs(gisToBlocks.crossPointLists) do
						if(crossBuildingList.id == waynode.attr.id) then
							isNew = false;
							for crossKey,point in pairs(crossBuildingList.points) do
								if(point.draw == "false") then
									for i=1, #osmNodeList do
										local item = osmNodeList[i];
										if (item.id == point.id) then
											cur_tilex, cur_tiley = MapGeography.GetInstance():deg2tile(item.lon, item.lat);
											if (cur_tilex == tileX) and (cur_tiley == tileY) then
												xpos, ypos = MapGeography.GetInstance():deg2pixel(item.lon, item.lat);
												point.cx = px + xpos - PngWidth/2;
												point.cy = pz - ypos + PngWidth - PngWidth/2;
												point.draw = "true";
											end
										end
									end
								end
							end
							--LOG.std(nil,"debug","crossBuildingList.points",crossBuildingList.points);
							isDraw = true;
							for drawKey,point in pairs(crossBuildingList.points) do
								if(point.draw == "false") then
									isDraw = false;
								end
							end

							if(isDraw) then
								draw2Point(self,crossBuildingList.points,2335,"buildingMore");
								draw2area(self,crossBuildingList.points,2335,"buildingMore");
								crossBuildingList = false;
							end
						end
					end
				end
				
				if(isNew) then
					local curNd        = {};
					local curNdCount   = 0;
					local drawNdcount  = 0;
					for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do
						curNdCount             = curNdCount + 1;
						curNd[curNdCount]      = ndnode;
						curNd[curNdCount].draw = "false";

						for i=1, #osmNodeList do
							local item = osmNodeList[i];
							if (item.id == ndnode.attr.ref) then
								cur_tilex, cur_tiley = MapGeography.GetInstance():deg2tile(item.lon, item.lat);
								if (cur_tilex == tileX) and (cur_tiley == tileY) then
									xpos, ypos = MapGeography.GetInstance():deg2pixel(item.lon, item.lat);

									buildingPoint      = {id = item.id, x = xpos, y = ypos, z = 6, level = buildingLevel};
									buildingPointCount = buildingPointCount + 1;

									buildingPointList[buildingPointCount] = buildingPoint;

									drawNdcount       = drawNdcount + 1;
									curNd[curNdCount] = buildingPoint;
									curNd[curNdCount].draw = "true";
								else
									buildingPoint     = {id = item.id, z = 6, level = buildingLevel};
									curNd[curNdCount] = buildingPoint;
									curNd[curNdCount].draw = "false";
								end	
							end
						end
					end

					local osmBuilding;

					if(drawNdcount == curNdCount) then
						osmBuilding = {id = waynode.attr.id, points = buildingPointList};
						osmBuildingCount = osmBuildingCount + 1;
						osmBuildingList[osmBuildingCount] = osmBuilding;

						--echo(osmBuildingList);
					else
						for key,point in pairs(curNd) do
							if(point.x) then
								point.cx = px + math.ceil(point.x) - PngWidth/2;
							end

							if(point.y) then
								point.cy = pz - math.ceil(point.y) + PngWidth - PngWidth/2;
							end

							point.cz = point.z;
						end

						osmBuilding = {id = waynode.attr.id, points = curNd};

						gisToBlocks.crossPointLists[#gisToBlocks.crossPointLists + 1] = osmBuilding;
					end
				end
			end
			---------building  end----------

			---------highway start----------
			if (tagnode.attr.k == "highway") then
				local highWayPoint;
				local highWayPointList  = {};
				local highWayPointCount = 0;

				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 			
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							cur_tilex, cur_tiley = MapGeography.GetInstance():deg2tile(item.lon, item.lat);
							if (cur_tilex == tileX) and (cur_tiley == tileY) then
								xpos, ypos = MapGeography.GetInstance():deg2pixel(item.lon, item.lat);

								highWayPoint	   = {id = item.id, x = xpos, y = ypos , z = 6};
								highWayPointCount  = highWayPointCount + 1;

								highWayPointList[highWayPointCount] = highWayPoint;
							end
						end
				    end
			    end

				local osmHighWay;

				osmHighWay      = {id = waynode.attr.id, points = highWayPointList};
				osmHighWayCount = osmHighWayCount + 1;
				osmHighWayList[osmHighWayCount] = osmHighWay;
			end
			--------highway end----------

			--------water start----------
			if (tagnode.attr.k == "natural" and tagnode.attr.v == "water") then
				local waterPoint;
				local waterPointList  = {};
				local waterPointCount = 0;

				local isNew = true;
				--LOG.std(nil,"debug","gisToBlocks.crossPointLists",gisToBlocks.crossPointLists);
				if(#gisToBlocks.crossPointLists ~= 0) then
					for key,crossWaterList in pairs(gisToBlocks.crossPointLists) do
						if(crossWaterList.id == waynode.attr.id) then
							isNew = false;
							for crossKey,point in pairs(crossWaterList.points) do
								if(point.draw == "false") then
									for i=1, #osmNodeList do
										local item = osmNodeList[i];
										if (item.id == point.id) then
											cur_tilex, cur_tiley = MapGeography.GetInstance():deg2tile(item.lon, item.lat);
											if (cur_tilex == tileX) and (cur_tiley == tileY) then
												xpos, ypos = MapGeography.GetInstance():deg2pixel(item.lon, item.lat);
												point.cx = px + xpos - PngWidth/2;
												point.cy = pz - ypos + PngWidth - PngWidth/2;
												point.draw = "true";
											end
										end
									end
								end
							end
							--LOG.std(nil,"debug","crossWaterList.points",crossWaterList.points);
							isDraw = true;
							for drawKey,point in pairs(crossWaterList.points) do
								if(point.draw == "false") then
									isDraw = false;
								end
							end

							if(isDraw) then
								draw2Point(self,crossWaterList.points,2337,"waterMore");
								draw2area(self,crossWaterList.points,2334,"waterMore");
								crossWaterList = false;
							end
						end
					end
				end

				if(isNew) then
					local curNd        = {};
					local curNdCount   = 0;
					local drawNdcount  = 0;
					for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do
						curNdCount             = curNdCount + 1;
						curNd[curNdCount]      = ndnode;
						curNd[curNdCount].draw = "false";

						for i=1, #osmNodeList do
							local item = osmNodeList[i];
							if (item.id == ndnode.attr.ref) then
								cur_tilex, cur_tiley = MapGeography.GetInstance():deg2tile(item.lon, item.lat);
								if (cur_tilex == tileX) and (cur_tiley == tileY) then
									xpos, ypos = MapGeography.GetInstance():deg2pixel(item.lon, item.lat);

									waterPoint	     = {id = item.id, x = xpos, y = ypos , z = 6};
									waterPointCount  = waterPointCount + 1;

									waterPointList[waterPointCount] = waterPoint;

									drawNdcount       = drawNdcount + 1;
									curNd[curNdCount] = waterPoint;
									curNd[curNdCount].draw = "true";
								else
									waterPoint        = {id = item.id, z = 6};
									curNd[curNdCount] = waterPoint;
									curNd[curNdCount].draw = "false";
								end	
							end
						end
					end

					local osmWater;
					
					if(drawNdcount == curNdCount) then
						osmWater      = {id = waynode.attr.id, points = waterPointList};
						osmWaterCount = osmWaterCount + 1;
						osmWaterList[osmWaterCount] = osmWater;
					else
						for key,point in pairs(curNd) do
							if(point.x) then
								point.cx = px + math.ceil(point.x) - PngWidth/2;
							end

							if(point.y) then
								point.cy = pz - math.ceil(point.y) + PngWidth - PngWidth/2;
							end

							point.cz = point.z;
						end

						osmWater = {id = waynode.attr.id, points = curNd};

						gisToBlocks.crossPointLists[#gisToBlocks.crossPointLists + 1] = osmWater;
					end
				end
			end
			--------water end----------
		end
	end

	local buildingPointList;
	for k,v in pairs(osmBuildingList) do
		buildingPointList = v.points;
		
		draw2Point(self,buildingPointList,2335,"building");
		draw2area(self,buildingPointList,2335,"buildingMore");
	end

	local waterPointList;
	if(osmWaterList) then
		for k,v in pairs(osmWaterList) do
			waterPointList = v.points;
		
			draw2Point(self,waterPointList,2337,"water");
			draw2area(self,waterPointList,2334,"waterMore");
		end
	end

	local highWayPointList;
	for k,v in pairs(osmHighWayList) do
		highWayPointList = v.points;

		draw2Point(self,highWayPointList,2336,"highWay");

		local makemore = commonlib.copy(highWayPointList);

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");

		-----

		local makemore = commonlib.copy(highWayPointList);

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,2336,"highWay");
	end
end

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
	local function onFinish()
		TileManager.GetInstance():onFinishPop(tile.id) -- 清空标志可以继续下载
		if gisToBlocks.isMapping and #TileManager.GetInstance().popID < 1 then
			gisToBlocks.isMapping = nil
			self:onMappingEnd()
		end
	end
	if(raster:IsValid()) then
		local ver           = raster:ReadInt();
		local width         = raster:ReadInt();
		local height        = raster:ReadInt();
		local bytesPerPixel = raster:ReadInt();-- how many bytes per pixel, usually 1, 3 or 4
		LOG.std(nil, "info", "PNGToBlockScale", {ver, width, height, bytesPerPixel});
		local block_world = GameLogic.GetBlockWorld();
		local function CreateBlock_(ix, iy, block_id, block_data)
			local spx, spy, spz = px+ix-(PngWidth/2 * ComVar.factor), py, pz+iy-(PngWidth/2 * ComVar.factor);
			if TileManager.GetInstance():checkMarkArea(spx,spy,spz) then
				ParaBlockWorld.LoadRegion(block_world, spx, spy, spz);
				self:AddBlock(spx, spy, spz, block_id, block_data, tile);
			-- else
			-- 	echo("跳过绘制 " .. spx .. "," .. spz)
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
						local x,y = math.round(ix * ComVar.factor), math.round(iy * ComVar.factor)
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
				LOG.std(nil,"info","PNGToBlockScale map size: ",maxx .. "," .. maxy)
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
								-- if x == 1 and y == 1 then LOG.std(nil,"info","draw",x .. "," .. y);echo(block_data) end
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
					if not tile.isUpdated then
						tile.isUpdated = true
						self:fillingGap()
					end
					TileManager.GetInstance().curTimes = TileManager.GetInstance().curTimes + 1
					-- if TileManager.GetInstance().curTimes > TileManager.GetInstance().count then TileManager.GetInstance().curTimes = TileManager.GetInstance().count end
					LOG.std(nil, "info", "PNGToBlockScale", "finished with %d process: %d / %d ", count, TileManager.GetInstance().curTimes + TileManager.GetInstance().passTimes, TileManager.GetInstance().count);
					self:saveOnFinish()
					onFinish()
				end
			end})
			timer:Change(30,30);
			UndoManager.PushCommand(self);
		else
			LOG.std(nil, "error", "PNGToBlockScale", "format not supported process: %d / %d", TileManager.GetInstance().curTimes + TileManager.GetInstance().passTimes, TileManager.GetInstance().count);
			raster:close();
			TileManager.GetInstance().passTimes = TileManager.GetInstance().passTimes + 1
			onFinish()
			-- if TileManager.GetInstance().curTimes > TileManager.GetInstance().count then TileManager.GetInstance().curTimes = TileManager.GetInstance().count end
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

function gisToBlocks:LoadToScene(raster,vector,px,py,pz,tile)
	local colors = self.colors;
	if(not px) then
		return;
	end
	gisToBlocks.ptop    = pz + 128;
	gisToBlocks.pbottom = pz - 128;
	gisToBlocks.pleft   = px - 128;
	gisToBlocks.pright  = px + 128;

	DBS:setValue(SysDB,"boundary",{ptop    = gisToBlocks.ptop,
									  pbottom = gisToBlocks.pbottom,
									  pleft   = gisToBlocks.pleft,
									  pright  = gisToBlocks.pright})
	DBS:flush(SysDB)

	-- EarthMod:SetWorldData("boundary",{ptop    = gisToBlocks.ptop,
	-- 								  pbottom = gisToBlocks.pbottom,
	-- 								  pleft   = gisToBlocks.pleft,
	-- 								  pright  = gisToBlocks.pright});
	-- EarthMod:SaveWorldData();
	
	LOG.std(nil,"debug","gisToBlocks","加载方块和贴图");
	self:PNGToBlockScale(raster, px, py, pz, tile);
	self:OSMToBlock(vector, px, py, pz, tile);
end

-- 人物起飞（开始绘制地图了）
function gisToBlocks:fly()
	local entityPlayer = EntityManager.GetFocus();
	if entityPlayer and (not entityPlayer:IsFlying()) then
		GameLogic.ToggleFly();
		local x, y, z = EntityManager.GetFocus():GetBlockPos();
		GameLogic.GetPlayer():SetBlockPos(x,y + 1,z)
	end
end

function gisToBlocks:GetData(x,y,i,j,_callback)
	local raster;
	local tileX,tileY = x,y
	local dtop,dbottom,dleft,dright;
	gisToBlocks.dleft , gisToBlocks.dtop    = MapGeography.GetInstance():pixel2deg(tileX,tileY,0,0);
	gisToBlocks.dright, gisToBlocks.dbottom = MapGeography.GetInstance():pixel2deg(tileX,tileY,255,255);
	dtop    = gisToBlocks.dtop;
	dbottom = gisToBlocks.dbottom;
	dleft   = gisToBlocks.dleft;
	dright  = gisToBlocks.dright;
	LOG.std(nil,"debug","gisToBlocks","下载数据中");
	GameLogic.AddBBS("statusBar","下载数据中", 2000, "0 0 0")
	getOsmService:getOsmPNGData(x,y,i,j,function(raster)
		getOsmService:getOsmXMLData(x,y,i,j,dleft,dbottom,dright,dtop,function(vector)
			raster = ParaIO.open("tile_"..x.."_"..y..ComVar.tileFormat, "image");
			LOG.std(nil,"debug","gisToBlocks","下载成功");
			GameLogic.AddBBS("statusBar","下载成功", 3000, "0 0 0")
			_callback(raster,vector);
		end);
	end);
	
	-- if(self.options == "already") then
	-- 	tileX = gisToBlocks.mTileX;
	-- 	tileY = gisToBlocks.mTileY;
	-- 	gisToBlocks.mdleft , gisToBlocks.mdtop    = MapGeography.GetInstance():pixel2deg(tileX,tileY,0,0);
	-- 	gisToBlocks.mdright, gisToBlocks.mdbottom = MapGeography.GetInstance():pixel2deg(tileX,tileY,255,255);
	-- 	dtop    = gisToBlocks.mdtop;
	-- 	dbottom = gisToBlocks.mdbottom;
	-- 	dleft   = gisToBlocks.mdleft;
	-- 	dright  = gisToBlocks.mdright;

	-- 	--LOG.std(nil,"debug","tileX,tileY,dtop,dbottom,dleft,dright",{tileX,tileY,dtop,dbottom,dleft,dright});
	-- end

	-- if(self.options == "coordinate") then
	-- end

	-- self.cache = 'true';
	-- if(self.cache == 'true') then
			-- ...
			-- local vectorFile = ParaIO.open("xml_"..x.."_"..y..".osm", "r");
			-- local vector = vectorFile:GetText(0, -1);
			-- vectorFile:close();
			-- ...
	-- else
	-- 	local vectorFile;

	-- 	raster     = ParaIO.open("tile.png", "image");
	-- 	vectorFile = ParaIO.open("xml.osm", "r");
	-- 	vector     = vectorFile:GetText(0, -1);
	-- 	vectorFile:close();

	-- 	_callback(raster,vector);
	-- end
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
function gisToBlocks:BoundaryCheck(px, py, pz)
	if NetManager.connectState == "client" then return end
	-- if self.isDrawing then return false end
	if ComVar.DrawAllMap and (not self.isDrawedAllMap) then -- 自动全部绘制
		self.isDrawedAllMap = true
		self.cols, self.rows = TileManager.GetInstance():getIterSize();
		for x = 1,self.cols do
			for y=1,self.rows do
				self:downloadMap(x,y)
			end
		end
		return
	end
	if px == nil and py == nil and pz == nil then
		px, py, pz = EntityManager.GetFocus():GetBlockPos();
	end
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
	if NetManager.connectState == "client" then return end
	if ComVar.CorrectMode then return end
	local po,tile,isUpdate = nil,nil,nil
	if (not i) and (not j) then
		isUpdate = true
		local px, py, pz = EntityManager.GetFocus():GetBlockPos();
		i, j = TileManager.GetInstance():getInTile(px, py, pz)
		if type(i) == "table" then j = i.y; i = i.x end
		po,tile = TileManager.GetInstance():getDrawPosition(i,j);
		if tile then
			tile.isDrawed = nil
			TileManager.GetInstance().pushMapFlag[i] = TileManager.GetInstance().pushMapFlag[i] or {}
			TileManager.GetInstance().pushMapFlag[i][j] = nil
			getOsmService.isUpdateMode = true
			getOsmService.isUpdateModeOSM = true
		end
	end
	TileManager.GetInstance().pushMapFlag[i] = TileManager.GetInstance().pushMapFlag[i] or {}
	if TileManager.GetInstance().pushMapFlag[i][j] ~= true then
		if not tile then po,tile = TileManager.GetInstance():getDrawPosition(i,j); end
		if tile and (not tile.isDrawed) then
			if TileManager.GetInstance().pushMapFlag[i][j] == 1 then tile.needFill = true end -- 填补模式
			if TileManager.GetInstance():push(tile) then
				if not gisToBlocks.isMapping then
					gisToBlocks.isMapping = true
					self:onMappingBegin()
				end
				LOG.std(nil,"debug","gosToBlocks","添加绘制任务 " .. tile.x .. "," .. tile.y);
				TileManager.GetInstance().pushMapFlag[i][j] = true
				if isUpdate then
					TileManager.GetInstance().curTimes = TileManager.GetInstance().curTimes - 1
					if TileManager.GetInstance().curTimes < 0 then TileManager.GetInstance().curTimes = 0 end
				else
					self:fly()
				end
			end
		end
	end
end

function gisToBlocks:startDrawTiles()
	if NetManager.connectState == "client" then return end
	local function onDraw(tile)
		LOG.std(nil,"debug","gosToBlocks","绘制地图： " .. tile.x .. "," .. tile.y);
		tile.isDrawed = true
		local po = tile.po
		getOsmService.tileX = tile.ranksID.x;
		getOsmService.tileY = tile.ranksID.y;
		self:GetData(tile.ranksID.x,tile.ranksID.y,tile.x,tile.y,function(raster,vector)
			LOG.std(nil,"gosToBlocks","gosToBlocks","getData");
			self:LoadToScene(raster,vector,po.x,po.y,po.z,tile);
		end);
		LOG.std(nil,"debug","gosToBlocks","一张下载完成，开始绘制..");
	end
	gisToBlocks.timerGet = commonlib.Timer:new({callbackFunc = function(timer)
		tile = TileManager.GetInstance():pop()
		if tile and (not tile.isDrawed) then
			onDraw(tile)
		end
	end})
	gisToBlocks.timerGet:Change(2000,2000); -- 每秒获取一次图片状态
end

function gisToBlocks:Run()
	self.finished = true;
	if(self.options == "already") then
		self:initWorld()
		DBS:getValue(SysDB,"boundary",function(boundary) if boundary then
			gisToBlocks.ptop    = boundary.ptop;
			gisToBlocks.pbottom = boundary.pbottom;
			gisToBlocks.pleft   = boundary.pleft;
			gisToBlocks.pright  = boundary.pright;
		end end)

	elseif(self.options == "coordinate") then
		if(GameLogic.GameMode:CanAddToHistory()) then
			self.add_to_history = false;
		end
		self:initWorld()
		if ComVar.openNetwork and NetManager.connectState == "server" then
			NetManager.sendMessage("all","nowFly",nil,-1)
		end
	end
end

function gisToBlocks:reInitWorld()
	if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
	if self.minlon and self.minlat and self.maxlon and self.maxlat and (not SelectLocationTask.isDownLoaded) then
		-- 初始化osm信息
		gisToBlocks.tileX , gisToBlocks.tileY   = MapGeography.GetInstance():deg2tile(self.minlon,self.minlat);
		gisToBlocks.dleft , gisToBlocks.dtop    = MapGeography.GetInstance():pixel2deg(self.tileX,self.tileY,0,0);
		gisToBlocks.dright, gisToBlocks.dbottom = MapGeography.GetInstance():pixel2deg(self.tileX,self.tileY,255,255);
		getOsmService.dleft   = gisToBlocks.dleft;
		getOsmService.dtop    = gisToBlocks.dtop;
		getOsmService.dright  = gisToBlocks.dright;
		getOsmService.dbottom = gisToBlocks.dbottom;
		getOsmService.zoom = self.zoom;
		-- 根据minlat和minlon计算出左下角的瓦片行列号坐标
		gisToBlocks.tile_MIN_X , gisToBlocks.tile_MIN_Y   = MapGeography.GetInstance():deg2tile(self.minlon,self.minlat);
		-- 根据maxlat和maxlon计算出右上角的瓦片行列号坐标
		gisToBlocks.tile_MAX_X , gisToBlocks.tile_MAX_Y   = MapGeography.GetInstance():deg2tile(self.maxlon,self.maxlat);
		LOG.std(nil,"debug","gisToBlocks","tile_MIN_X : "..gisToBlocks.tile_MIN_X.." tile_MIN_Y : "..gisToBlocks.tile_MIN_Y);
		LOG.std(nil,"debug","gisToBlocks","tile_MAX_X : "..gisToBlocks.tile_MAX_X.." tile_MAX_Y : "..gisToBlocks.tile_MAX_Y);
		-- 重新初始化地图数据
		local tileManager = TileManager.GetInstance():reInit({
			lid = gisToBlocks.tile_MIN_X,bid = gisToBlocks.tile_MIN_Y,
			rid = gisToBlocks.tile_MAX_X,tid = gisToBlocks.tile_MAX_Y,
			firstPo = {lat=self.minlat,lon=self.minlon},lastPo = {lat=self.maxlat,lon=self.maxlon}, -- 传入地理位置信息
		})
		self.cols, self.rows = TileManager.GetInstance():getIterSize();
		LOG.std(nil,"debug","gisToBlocks","cols : "..self.cols.." rows : ".. self.rows);
		self:startDrawTiles()

		local roleGPo = MapGeography.GetInstance():getGPo(EntityManager.GetFocus():GetBlockPos()) --  这个获取的不能实时更新
		LOG.std(nil,"RunFunction 获取到人物的地理坐标","经度：" .. roleGPo.lon,"纬度：" .. roleGPo.lat)
		LOG.std(nil,EntityManager.GetFocus():GetBlockPos())
		-- 更新SelectLocationTask.player_lon和SelectLocationTask.player_lat(人物当前所处经纬度)信息
		SelectLocationTask.setPlayerCoordinate(roleGPo.lon, roleGPo.lat);
		-- timer定时更新人物坐标信息
		self:refreshPlayerInfo()
		SelectLocationTask.isDownLoaded = true
	end
end

function gisToBlocks:initWorld()
	if not DBS then DBS = DBStore.GetInstance();SysDB = DBS:SystemDB() end
	if self.minlon and self.minlat and self.maxlon and self.maxlat and (not SelectLocationTask.isDownLoaded) then
		-- 初始化osm信息
		gisToBlocks.tileX , gisToBlocks.tileY   = MapGeography.GetInstance():deg2tile(self.minlon,self.minlat);
		gisToBlocks.dleft , gisToBlocks.dtop    = MapGeography.GetInstance():pixel2deg(self.tileX,self.tileY,0,0);
		gisToBlocks.dright, gisToBlocks.dbottom = MapGeography.GetInstance():pixel2deg(self.tileX,self.tileY,255,255);
		getOsmService.dleft   = gisToBlocks.dleft;
		getOsmService.dtop    = gisToBlocks.dtop;
		getOsmService.dright  = gisToBlocks.dright;
		getOsmService.dbottom = gisToBlocks.dbottom;
		getOsmService.zoom = self.zoom;
		-- 根据minlat和minlon计算出左下角的瓦片行列号坐标
		echo("initWorld: ")
		gisToBlocks.tile_MIN_X , gisToBlocks.tile_MIN_Y   = MapGeography.GetInstance():deg2tile(self.minlon,self.minlat);
		-- 根据maxlat和maxlon计算出右上角的瓦片行列号坐标
		gisToBlocks.tile_MAX_X , gisToBlocks.tile_MAX_Y   = MapGeography.GetInstance():deg2tile(self.maxlon,self.maxlat);
		LOG.std(nil,"debug","gisToBlocks","tile_MIN_X : "..gisToBlocks.tile_MIN_X.." tile_MIN_Y : "..gisToBlocks.tile_MIN_Y);
		LOG.std(nil,"debug","gisToBlocks","tile_MAX_X : "..gisToBlocks.tile_MAX_X.." tile_MAX_Y : "..gisToBlocks.tile_MAX_Y);
		-- 初始化地图数据
		local px, py, pz = EntityManager.GetFocus():GetBlockPos();
		local tileManager = TileManager.GetInstance():init({
			lid = gisToBlocks.tile_MIN_X,bid = gisToBlocks.tile_MIN_Y,
			rid = gisToBlocks.tile_MAX_X,tid = gisToBlocks.tile_MAX_Y,
			bx = px,by = ComVar.FloorLevel,bz = pz,tileSize = math.ceil(PngWidth * ComVar.factor),
			firstPo = {lat=self.minlat,lon=self.minlon},lastPo = {lat=self.maxlat,lon=self.maxlon}, -- 传入地理位置信息
		})
		self.cols, self.rows = TileManager.GetInstance():getIterSize();
		LOG.std(nil,"debug","gisToBlocks","cols : "..self.cols.." rows : ".. self.rows);
		self:startDrawTiles()

		local roleGPo = MapGeography.GetInstance():getGPo(EntityManager.GetFocus():GetBlockPos()) --  这个获取的不能实时更新
		LOG.std(nil,"RunFunction 获取到人物的地理坐标","经度：" .. roleGPo.lon,"纬度：" .. roleGPo.lat)
		LOG.std(nil,EntityManager.GetFocus():GetBlockPos())
		SelectLocationTask.setPlayerCoordinate(roleGPo.lon, roleGPo.lat);
		self:refreshPlayerInfo()
		SelectLocationTask.isDownLoaded = true
	end
end

-- 更新人物信息
function gisToBlocks:refreshPlayerInfo()
	gisToBlocks.playerLocationTimer = gisToBlocks.playerLocationTimer or commonlib.Timer:new({callbackFunc = function(playerLocationTimer)
			-- 获取人物坐标信息
			local x,y,z = EntityManager.GetFocus():GetBlockPos()
			if SelectLocationTask.player_curLon and SelectLocationTask.player_curLat then
				local curLon,curLat = SelectLocationTask.player_curLon,SelectLocationTask.player_curLat
				SelectLocationTask.player_lon = curLon
				SelectLocationTask.player_lat = curLat
				if ComVar.CorrectMode then -- 矫正模式
					TileManager.GetInstance():correctPositionSystem(x,y,z,curLon,curLat)
				else -- 跳转模式
					local po = MapGeography.GetInstance():getParaPo(curLon,curLat) -- self:getRoleFloor()
					-- GameLogic.GetPlayer():TeleportToBlockPos(po.x,po.y,po.z)
					-- GameLogic.GetPlayer():AddToSendQueue(
					-- 	GameLogic.Packets.PacketClientCommand:new():Init(format("/goto %d %d %d"
					-- 			, po.x
					-- 			, po.y
					-- 			, po.z)));
					if NetManager.connectState == "server" then
						GameLogic.GetPlayer():TeleportToBlockPos(po.x,po.y,po.z)
					else
						CommandManager:RunCommand("/goto " .. po.x .. " " .. po.y .. " " .. po.z);
					end
					x,y,z = po.x,po.y,po.z
				end
				SelectLocationTask.player_curLon = nil
				SelectLocationTask.player_curLat = nil
			end
			local player_latLon = MapGeography.GetInstance():getGPo(x, y, z);
			local ro,str = TileManager.GetInstance():getForward(true)
			local lon,lat,ron = math.floor(player_latLon.lon * 10000) / 10000,math.floor(player_latLon.lat * 10000) / 10000,math.floor(ro * 100) / 100
			-- echo("set map loc: ");echo(player_latLon)
			SelectLocationTask.setPlayerCoordinate(player_latLon.lon, player_latLon.lat);
			if NetManager.connectState == "client" then 
				-- 如果当前运行的是客户端,则将人物位置信息发送给服务器
				if player_latLon and player_latLon.lon and player_latLon.lat then
					local po_tb = {lon = player_latLon.lon, lat = player_latLon.lat}
					NetManager.sendMessage("admin","cl_po",table.toJson(po_tb),-1)
				end
			elseif NetManager.connectState == "server" then
				if player_latLon and player_latLon.lon and player_latLon.lat then
					local po_tb = {lon = player_latLon.lon, lat = player_latLon.lat}
					SelectLocationTask:setPlayerPoTableData("admin", po_tb)
					-- 广播全玩家坐标信息
					NetManager.sendMessage("all","all_po",table.toJson(SelectLocationTask.allPlayerPo),-1)
				end
			end
			local sltInstance = SelectLocationTask.GetInstance();
			if sltInstance then
				sltInstance:setInfor({-- lon = lon,lat = lat, 经纬度
					pos = "(" .. x .. "," .. y .. "," .. z .. ")",
					loading = TileManager.GetInstance().curTimes .. "/" .. TileManager.GetInstance().count,
					forward = str .. " " .. ron .. "°"
				});
			end
	end});
	gisToBlocks.playerLocationTimer:Change(1000,1000);
	if not SelectLocationTask.isShowInfo then SelectLocationTask.isShowInfo = true end
end

-- 存储一次数据
function gisToBlocks:saveOnFinish()
	TileManager.GetInstance():Save()
	CommandManager:RunCommand("/save");
end

function gisToBlocks:OnLeaveWorld()
	echo("gisToBlocks:OnLeaveWorld");
	DBS = nil
	SysDB = nil
	if gisToBlocks.timerGet then gisToBlocks.timerGet:Change();gisToBlocks.timerGet = nil end
	if gisToBlocks.playerLocationTimer then echo("on leave timer");gisToBlocks.playerLocationTimer:Change();gisToBlocks.playerLocationTimer = nil end
end

-- 获取地面上能容纳一个人（两格）的位置
function gisToBlocks:getRoleFloor(po)
	local function checkRoleCanSit(p)
		local id1,id2 = BlockEngine:GetBlockId(p.x,p.y + 1,p.z),BlockEngine:GetBlockId(p.x,p.y + 2,p.z)
		if id1 and id2 and id1 == 0 and id2 == 0 then -- 检测草地(id:62) 空气0
			return true
		end
		return false
	end
	while (not checkRoleCanSit(po)) do
		po.y = po.y + 1
	end
	return po
end

-- 下载开始
function gisToBlocks:onMappingBegin()
	echo("onMappingBegin 下载开始")
	GameLogic.AddBBS("statusBar","开始地图绘制..", 10000, "223 81 145")
end
-- 绘制结束
function gisToBlocks:onMappingEnd()
	echo("onMappingEnd 绘制结束")
	GameLogic.AddBBS("statusBar","地图绘制完成。", 5000, "223 81 145")
	if NetManager.connectState == "server" then
		NetManager.sendMessage("all","tileNum",TileManager.GetInstance().curTimes,-1)
	end
end