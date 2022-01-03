
-- e changed to muteEntry

mute = { MP = minetest.get_modpath(minetest.get_current_modname()) }

dofile(mute.MP.."/serialize.lua")

local db = { }
local tempmutes = { }

local DEF_SAVE_INTERVAL = 300 -- 5 minutes
local DEF_DB_FILENAME = minetest.get_worldpath().."/mute.db"

local DB_FILENAME = minetest.settings:get("mute.db_filename")
local SAVE_INTERVAL = tonumber(
  minetest.settings:get("mute.db_save_interval")) or DEF_SAVE_INTERVAL

if (not DB_FILENAME) or (DB_FILENAME == "") then
	DB_FILENAME = DEF_DB_FILENAME
end

local function make_logger(level)
	return function(text, ...)
		minetest.log(level, "[mute] "..text:format(...))
	end
end

local ACTION = make_logger("action")
local WARNING = make_logger("warning")

local unit_to_secs = {
	s = 1, m = 60, h = 3600,
	D = 86400, W = 604800, M = 2592000, Y = 31104000,
	[""] = 1,
}

local function parse_time(t) --> secs
	local secs = 0
	for num, unit in t:gmatch("(%d+)([smhDWMY]?)") do
		secs = secs + (tonumber(num) * (unit_to_secs[unit] or 1))
	end
	return secs
end

local function concat_keys(t, sep)
	local keys = {}
	for k, _ in pairs(t) do
		keys[#keys + 1] = k
	end
	return table.concat(keys, sep)
end

function mute.find_entry(player, create) --> entry, index
	for index, muteEntry in ipairs(db) do
		for name in pairs(muteEntry.names) do
			if name == player then
				return muteEntry, index
			end
		end
	end
	if create then
		print(("Created new entry for `%s'"):format(player))
		local muteEntry = {
			names = { [player]=true },
			muted = false,
			record = { },
		}
		table.insert(db, muteEntry)
		return muteEntry, #db
	end
	return nil
end

function mute.get_info(player) --> ip_name_list, muted, last_record
	local muteEntry = mute.find_entry(player)
	if not muteEntry then
		return nil, "No such entry"
	end
	return muteEntry.names, muteEntry.muted, muteEntry.record[#muteEntry.record]
end

function mute.mute_player(player, source, expires, reason) --> bool, err
	if mute.get_whitelist(player) then
		return nil, "Player is whitelisted; remove from whitelist first"
	end
	local muteEntry = mute.find_entry(player, true)
	if muteEntry.muted then
		return nil, "Already muted"
	end
	local rec = {
		source = source,
		time = os.time(),
		expires = expires,
		reason = reason,
	}
	table.insert(muteEntry.record, rec)
	muteEntry.names[player] = true
	local pl = minetest.get_player_by_name(player)
	if pl then
		local ip = minetest.get_player_ip(player)
		if ip then
			muteEntry.names[ip] = true
		end
		muteEntry.last_pos = pl:getpos()
	end
	muteEntry.reason = reason
	muteEntry.time = rec.time
	muteEntry.expires = expires
	muteEntry.muted = true
	local msg
	local date = (expires and os.date("%c", expires)
	  or "the end of time")
	if expires then
		table.insert(tempmutes, muteEntry)
		msg = ("Muted: Expires: %s, Reason: %s"):format(date, reason)
	else
		msg = ("Muted: Reason: %s"):format(reason)
	end
--	for nm in pairs(muteEntry.names) do
--		minetest.kick_player(nm, msg)
--	end
	ACTION("%s mutess %s until %s for reason: %s", source, player,
	  date, reason)
	ACTION("Muted Names/IPs: %s", concat_keys(muteEntry.names, ", "))
	return true
end

function mute.unmute_player(player, source) --> bool, err
	local muteEntry = mute.find_entry(player)
	if not muteEntry then
		return nil, "No such entry"
	end
	local rec = {
		source = source,
		time = os.time(),
		reason = "Unmuted",
	}
	table.insert(muteEntry.record, rec)
	muteEntry.muted = false
	muteEntry.reason = nil
	muteEntry.expires = nil
	muteEntry.time = nil
	ACTION("%s unmutes %s", source, player)
	ACTION("Unmuted Names/IPs: %s", concat_keys(muteEntry.names, ", "))
	return true
end

function mute.get_whitelist(name_or_ip)
	return db.whitelist and db.whitelist[name_or_ip]
end

function mute.remove_whitelist(name_or_ip)
	if db.whitelist then
		db.whitelist[name_or_ip] = nil
	end
end

function mute.add_whitelist(name_or_ip, source)
	local wl = db.whitelist
	if not wl then
		wl = { }
		db.whitelist = wl
	end
	wl[name_or_ip] = {
		source=source,
	}
	return true
end

function mute.get_record(player)
	local muteEntry = mute.find_entry(player)
	if not muteEntry then
		return nil, ("No entry for `%s'"):format(player)
	elseif (not muteEntry.record) or (#muteEntry.record == 0) then
		return nil, ("`%s' has no mute records"):format(player)
	end
	local record = { }
	for _, rec in ipairs(muteEntry.record) do
		local msg = rec.reason or "No reason given."
		if rec.expires then
			msg = msg..(", Expires: %s"):format(os.date("%c", muteEntry.expires))
		end
		if rec.source then
			msg = msg..", Source: "..rec.source
		end
		table.insert(record, ("[%s]: %s"):format(os.date("%c", muteEntry.time), msg))
	end
	local last_pos
	if muteEntry.last_pos then
		last_pos = ("User was last seen at %s"):format(
		  minetest.pos_to_string(muteEntry.last_pos))
	end
	return record, last_pos
end
 
-- probably not needed, since it's used to check for bans when playes connect
--[[
minetest.register_on_prejoinplayer(function(name, ip)
	local wl = db.whitelist or { }
	if wl[name] or wl[ip] then return end
	local muteEntry = mute.find_entry(name) or mute.find_entry(ip)
	if not muteEntry then return end
	if muteEntry.muted then
		local date = (muteEntry.expires and os.date("%c", muteEntry.expires)
		  or "the end of time")
		return ("Muted: Expires: %s, Reason: %s"):format(
		  date, muteEntry.reason)
	end
end)
]]

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local muteEntry = mute.find_entry(name)
	local ip = minetest.get_player_ip(name)
	if not muteEntry then
		if ip then
			muteEntry = mute.find_entry(ip, true)
		else
			return
		end
	end
	muteEntry.names[name] = true
	if ip then
		muteEntry.names[ip] = true
	end
	muteEntry.last_seen = os.time()
end)

minetest.register_on_chat_message(function(name)
    local muteEntry = mute.find_entry(name) or mute.find_entry(ip)
    if not muteEntry then return end
	--if muted[name] == true then
    if muteEntry.muted then
		minetest.chat_send_player(name, "You're muted, you can't talk")
		return true
	end
end)

minetest.register_chatcommand("permamute", {
	description = "Mute a player",
	params = "<player> <reason>",
	privs = { mute=true },
	func = function(name, params)
		local plname, reason = params:match("(%S+)%s+(.+)")
		if not (plname and reason) then
			return false, "Usage: /permamute <player> <reason>"
		end
		local ok, muteEntry = mute.mute_player(plname, name, nil, reason)
		return ok, ok and ("Muted %s."):format(plname) or muteEntry
	end,
})

minetest.register_chatcommand("mute", {
	description = "Mute a player temporarily",
	params = "<player> <time> <reason>",
	privs = { mute=true },
	func = function(name, params)
		local plname, time, reason = params:match("(%S+)%s+(%S+)%s+(.+)")
		if not (plname and time and reason) then
			return false, "Usage: /mute <player> <time> <reason>"
		end
		time = parse_time(time)
		if time < 60 then
			return false, "You must mute for at least 60 seconds."
		end
		local expires = os.time() + time
		local ok, muteEntry = mute.mute_player(plname, name, expires, reason)
		return ok, (ok and ("Muted %s until %s."):format(
				plname, os.date("%c", expires)) or muteEntry)
	end,
})

minetest.register_chatcommand("unmute", {
	description = "Unmute a player",
	params = "<player_or_ip>",
	privs = { mute=true },
	func = function(name, params)
		local plname = params:match("%S+")
		if not plname then
			minetest.chat_send_player(name,
			  "Usage: /unmute <player_or_ip>")
			return
		end
		local ok, muteEntry = mute.unmute_player(plname, name)
		return ok, ok and ("Unmuted %s."):format(plname) or muteEntry
	end,
})

minetest.register_chatcommand("mute_record", {
	description = "Show the mute records of a player",
	params = "<player_or_ip>",
	privs = { mute=true },
	func = function(name, params)
		local plname = params:match("%S+")
		if not plname then
			return false, "Usage: /mute_record <player_or_ip>"
		end
		local record, last_pos = mute.get_record(plname)
		if not record then
			local err = last_pos
			minetest.chat_send_player(name, "[mute] "..err)
			return
		end
		for _, muteEntry in ipairs(record) do
			minetest.chat_send_player(name, "[mute] "..muteEntry)
		end
		if last_pos then
			minetest.chat_send_player(name, "[mute] "..last_pos)
		end
		return true, "Record listed."
	end,
})

minetest.register_chatcommand("mute_wl", {
	description = "Manages the whitelist",
	params = "(add|del|get) <name_or_ip>",
	privs = { mute=true },
	func = function(name, params)
		local cmd, plname = params:match("%s*(%S+)%s*(%S+)")
		if cmd == "add" then
			mute.add_whitelist(plname, name)
			ACTION("%s adds %s to whitelist", name, plname)
			return true, "Added to whitelist: "..plname
		elseif cmd == "del" then
			mute.remove_whitelist(plname)
			ACTION("%s removes %s to whitelist", name, plname)
			return true, "Removed from whitelist: "..plname
		elseif cmd == "get" then
			local muteEntry = mute.get_whitelist(plname)
			if muteEntry then
				return true, "Source: "..(muteEntry.source or "Unknown")
			else
				return true, "No whitelist for: "..plname
			end
		end
	end,
})


local function check_temp_mutes()
	minetest.after(60, check_temp_mutes)
	local to_rm = { }
	local now = os.time()
	for i, muteEntry in ipairs(tempmutes) do
		if muteEntry.expires and (muteEntry.expires <= now) then
			table.insert(to_rm, i)
			muteEntry.muted = false
			muteEntry.expires = nil
			muteEntry.reason = nil
			muteEntry.time = nil
		end
	end
	for _, i in ipairs(to_rm) do
		table.remove(tempmutes, i)
	end
end

local function save_db()
	minetest.after(SAVE_INTERVAL, save_db)
	local f, muteEntry = io.open(DB_FILENAME, "wt")
	db.timestamp = os.time()
	if f then
		local ok, err = f:write(mute.serialize(db))
		if not ok then
			WARNING("Unable to save database: %s", err)
		end
	else
		WARNING("Unable to save database: %s", muteEntry)
	end
	if f then f:close() end
	return
end

local function load_db()
	local f, muteEntry = io.open(DB_FILENAME, "rt")
	if not f then
		WARNING("Unable to load database: %s", muteEntry)
		return
	end
	local cont = f:read("*a")
	if not cont then
		WARNING("Unable to load database: %s", "Read failed")
		return
	end
	local t, muteEntry2 = minetest.deserialize(cont)
	if not t then
		WARNING("Unable to load database: %s",
		  "Deserialization failed: "..(muteEntry2 or "unknown error"))
		return
	end
	db = t
	tempmutes = { }
	for _, entry in ipairs(db) do
		if entry.muted and entry.expires then
			table.insert(tempmutes, entry)
		end
	end
end

minetest.register_chatcommand("mute_cleanup", {
	description = "Removes all non-muted entries from the mute db",
	privs = { server=true },
	func = function(name, params)
		local old_count = #db

		local i = 1
		while i <= #db do
			if not db[i].muted then
				-- not muted, remove from db
				table.remove(db, i)
			else
				-- muted, hold entry back
				i = i + 1
			end
		end

		-- save immediately
		save_db()

		return true, "Removed " .. (old_count - #db) .. " entries, new db entry-count: " .. #db
	end,
})

minetest.register_privilege("mute", "Players who have it, can mute players")

minetest.register_on_shutdown(save_db)
minetest.after(SAVE_INTERVAL, save_db)
load_db()
mute.db = db

minetest.after(1, check_temp_mutes)

dofile(mute.MP.."/dbimport.lua")
dofile(mute.MP.."/gui.lua")
