--[[
Title: NetManager
Author(s):  Bl.Chock
Date: 2017年4月19日
Desc: net manager, conmmunication for client and server
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/NetManager.lua");
local NetManager = commonlib.gettable("Mod.EarthMod.NetManager");
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/timer.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/ServerManager.lua");
local NetManager = commonlib.inherit(nil,commonlib.gettable("Mod.EarthMod.NetManager"));
local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");
local ServerManager = commonlib.gettable("MyCompany.Aries.Game.Network.ServerManager");

NetManager.name = nil
NetManager.msgTimer = nil -- 心跳
NetManager.netReceiveFunc = nil -- 消息监听函数
NetManager.gameEventFunc = nil -- 游戏事件监听
NetManager.netMessageQueue = {}
NetManager.connectState = nil -- local:本地，server:服务器，client:客户端
NetManager.isConnecting = nil
NetManager.clients = nil
local heartBeat = 1000
local nolog = true -- 日志开关

-- 初始化网络管理器
function NetManager.init(eventFunc,receiveFunc)
	NetManager.name = nil
	NetManager.connectState = nil
	NetManager.netMessageQueue = {}
	NetManager.netReceiveFunc = receiveFunc -- 消息监听函数
	NetManager.gameEventFunc = eventFunc -- 游戏事件监听
    GameLogic.GetFilters():add_filter("PlayerHasLoginPosition", function()
		NetManager.name = GameLogic.GetPlayer():GetName()
    	echo("NetManager connect user: " .. NetManager.name)
		if NetManager.name == "default" then -- 刚刚启动
			echo("NetManager local 登录游戏/断开连接")
			NetManager.connectState = "local"
		else -- 连上了客户端
			echo("NetManager client 客户端登入")
			NetManager.connectState = "client"
			NetManager.isConnecting = nil
		end
		if NetManager.gameEventFunc then NetManager.gameEventFunc(NetManager.connectState) end
        return true;
    end);

	NetManager.msgTimer = commonlib.Timer:new({callbackFunc = function(timer)
		if NetManager.netReceiveFunc then
			local data = NetManager.pop()
			if data then
				NetManager.netReceiveFunc(data)
				if data.delay > 0 then
					timer:Change(data.delay,heartBeat)
				end
			end
			if NetManager.connectState == "server" then
				NetManager.checkPlayerLeave() -- 检查客户端心跳
			end
		end
	end})
	NetManager.msgTimer:Change(heartBeat,heartBeat) -- 一秒一个心跳
	echo("onInit: NetManager")
end

-- 检查客户端离线上线
function NetManager.checkPlayerLeave()
	for i=1, #(ServerManager.GetSingleton().playerEntityList) do
		local entity = ServerManager.GetSingleton().playerEntityList[i];
		local gname = "__MP__" .. entity:GetUserName()
		if NetManager.clients[gname] == nil then
			NetManager.clients[gname] = true
			NetManager.onPlayerEnter(gname)
		end
    end
    for uname,v in pairs(NetManager.clients) do
    	local find = nil
		for i=1, #(ServerManager.GetSingleton().playerEntityList) do
			local entity = ServerManager.GetSingleton().playerEntityList[i];
			if uname == "__MP__" .. entity:GetUserName() then find = true; break end
	    end
	    if not find then
	    	-- leave
	    	NetManager.onPlayerLeave(uname)
	    	NetManager.clients[uname] = nil
	    end
    end
end

function NetManager.onPlayerEnter(name)
	echo("welcome " .. name)
	NetManager.sendMessage("all","enter",name,-1)
end

-- 将离开的玩家作为value以管理员的身份告诉所有人leave消息
--[[处理参考：
if data.key == "leave" then
	echo("player leave: " .. data.value)
	NetManager.showMsg("玩家 " .. data.value .. " 离开了游戏")
	-- to do other code
end
]]
function NetManager.onPlayerLeave(name)
	echo("on leave:" .. name)
	NetManager.sendMessage("all","leave",name,-1)
end

-- 启动服务器
function NetManager.startServer(ip, port, psw)
	port = port or (ComVar and ComVar.prot) or 8081
	if psw then
		if port == "0" then port = 8081 end
		log("Cmd: " .. "/startserver -tunnel " .. psw .. " " .. ip .. " " .. port)
		GameLogic.RunCommand("/startserver -tunnel " .. psw .. " " .. ip .. " " .. port); -- 此时port为密码
	else
		GameLogic.RunCommand("/startserver 0 " .. port);
	end
	NetManager.name = "__MP__admin"
	NetManager.connectState = "server"
	-- set
    NetManager.clients = {}
	for i=1, #(ServerManager.GetSingleton().playerEntityList) do
		local entity = ServerManager.GetSingleton().playerEntityList[i];
		NetManager.clients["__MP__" .. entity:GetUserName()] = true
    end
	echo("NetManager server 服务器登入")
	if NetManager.gameEventFunc then NetManager.gameEventFunc(NetManager.connectState) end

end

-- 启动客户端
function NetManager.connectServer(ip, port, psw)
	port = port or 8081
	ip = ip or "127.0.0.1"
	if psw then
		if port == "0" then port = 8081 end
		log("Cmd: " .. "/connect -tunnel " .. psw .. " " .. ip .. " " .. port)
		GameLogic.RunCommand("/connect -tunnel " .. psw .. " " .. ip .. " " .. port);
	else
		GameLogic.RunCommand("/connect " .. ip .. " " .. port);
	end
	NetManager.isConnecting = true
end

-- 检测网络状态
function NetManager.isOnline()
	if NetManager.connectState == nil or NetManager.connectState == "local" then return false end
	return true
end

-- 设置消息接收监听器
function NetManager.setHandler(eventFunc,receiveFunc)
	NetManager.gameEventFunc = eventFunc -- 游戏事件监听
	NetManager.netReceiveFunc = receiveFunc -- 消息监听函数
end

-- 世界离开的时候关闭网络通讯(同时向服务器发送NetDisConn指令)
function NetManager.OnLeaveWorld()
	if NetManager.isConnecting then return end
	NetManager.clients = nil
	if NetManager.msgTimer then NetManager.msgTimer:Change(); NetManager.msgTimer = nil end
	NetManager.netReceiveFunc = nil
	NetManager.netMessageQueue = {}
	NetManager.gameEventFunc = nil
	NetManager.name = nil
	NetManager.connectState = nil
	echo("onDestroy: NetManager")
end

-- 清空消息队列
function NetManager.clearMessageQueue()
	NetManager.netMessageQueue = {}
end

-- 发送消息（对象名字，键值对，执行后阻塞延时(单位毫秒),为0不阻塞,为-1则立即执行不加入消息队列）
function NetManager.sendMessage(toPlayerName,key,value,delay)
	if (not NetManager.isOnline()) then echo("sendMessage need connection");return end
	delay = delay or 0
	if not nolog then echo("[" .. NetManager.connectState .. "] Message Send:{ " .. key .. " } to " .. toPlayerName);echo(value);echo("] end Message") end
	if value then
		GameLogic.RunCommand("/runat @" .. toPlayerName .. " /donet @".. NetManager.name .. " " .. delay .. " -" .. key .. " " .. tostring(value));
	else
		GameLogic.RunCommand("/runat @" .. toPlayerName .. " /donet @".. NetManager.name .. " " .. delay .. " -" .. key);
	end
end

-- 接收消息
function NetManager.addMessage(senderName,key,value,delay)
	if (not nolog) then echo("[" .. NetManager.connectState .. "] Message Receive:{ " .. key .. " } from " .. senderName);echo(value);echo("] end Message") end
	local data = {name = senderName,key = key,value = value,delay = delay}
	if key == "msg" then
		delay = -1;NetManager.showMsg(data.value,data.delay)
	end
	if delay == -1 then
		if NetManager.netReceiveFunc then NetManager.netReceiveFunc(data) end
	else
		NetManager.push(data)
	end
end

-- 添加消息到队列
function NetManager.push(data)
	table.insert(NetManager.netMessageQueue,data)
end

-- 读取下一条消息
function NetManager.pop()
	local len = #NetManager.netMessageQueue
	if len < 1 then return nil end
	local endData = NetManager.netMessageQueue[1]
	table.remove(NetManager.netMessageQueue, 1)
	return endData
end

-- 广播消息
function NetManager.sendMsg(msg,toPlayer)
	toPlayer = toPlayer or "all"
	NetManager.sendMessage(toPlayer,"msg",msg)
end

-- 显示广播信息
function NetManager.showMsg(str,delay,color)
	delay = delay or 5000
	color = color or "0 255 0"
	GameLogic.AddBBS("statusBar", str, delay, color)
end

-- 定义指令donet用于处理消息回调 发送：runat @admin /donet @selfname 0 -reqDb
Commands["donet"] = {
	name="donet", 
	quick_ref="/donet @name [delay] -key [value]",
	desc=[[receive data from dest player
@param @name: sender`s name @all for all connected players. @p for last trigger entity. @name for given player name. `__MP__` can be ignored.
@param delay: delay before message do,default 0
@param -key,value: key and value for send
Examples:
/donet @__MP__admin -k say -v hello
/donet @default -k del -v block1
]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		if not ComVar.openNetwork then NetManager.showMsg("该版本不支持联网协作(openNetwork=nil)");return end
		local senderName, key, value, delay
		senderName, cmd_text = CmdParser.ParseFormated(cmd_text, "@%S+");
		if (not NetManager.isOnline()) then echo("donet need network");return end
		if(senderName) then
			senderName = senderName:gsub("^@", "");
		else senderName = "default" end
		cmd_text = cmd_text:gsub("^%s+", "");
		delay, cmd_text = CmdParser.ParseString(cmd_text);
		key, cmd_text = CmdParser.ParseOptions(cmd_text);
		if key then
			value, cmd_text = CmdParser.ParseString(cmd_text);
			local keyName = nil
			for kName,isKey in pairs(key) do
				if isKey then keyName = kName end
			end
			NetManager.addMessage(senderName,keyName,value,tonumber(delay))
		end
	end,
};

Commands["net"] = {
	name="net", 
	quick_ref="/net -mode [ip] [port]",
	desc=[[start earth mode with client and server
@param mode: c/client,s/server
@param ip: client connect ip
@param port: client connect port default 8081(和左上角小地图地址栏端口号一致)
Examples:
/net -server
/net -s 8081
/net -client 192.168.0.1 8081
/net -c 192.168.0.1
/net -s [ip] [port] [psw] 使用tunnelserver创建服务器
/net -c [ip] [port] [psw] 连接tunnelserver服务器
]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		if not ComVar.openNetwork then NetManager.showMsg("该版本不支持联网协作(openNetwork=nil)");return end
		local mode, ip, port, psw
		mode, cmd_text = CmdParser.ParseOptions(cmd_text);
		if mode.client or mode.c then
			ip, cmd_text = CmdParser.ParseString(cmd_text);
			port, cmd_text = CmdParser.ParseString(cmd_text);
			psw, cmd_text = CmdParser.ParseString(cmd_text);
			NetManager.connectServer(ip,port,psw)
		elseif mode.server or mode.s then
			ip, cmd_text = CmdParser.ParseString(cmd_text);
			port, cmd_text = CmdParser.ParseString(cmd_text);
			psw, cmd_text = CmdParser.ParseString(cmd_text);
			if ip and (not port) then port = ip;ip = "127.0.0.1" end
			NetManager.startServer(ip,port,psw)
		end
	end,
};