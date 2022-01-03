
function mute.importers.minetest()
	local f, muteEntry = io.open(minetest.get_worldpath().."/ipmute.txt")
	if not f then
		return false, "Unable to open `ipmute.txt': "..muteEntry
	end
	for line in f:lines() do
		local ip, name = line:match("([^|]+)%|(.+)")
		if ip and name then
			local entry
			entry = mute.find_entry(ip, true)
			entry.muted = true
			entry.reason = "Muted in `ipmute.txt'"
			entry.names[name] = true
			entry.names[ip] = true
			entry.time = os.time()
			entry.expires = nil
			entry.source = "mute:importer_minetest"
			table.insert(entry.record, {
				source = entry.source,
				reason = entry.reason,
				time = entry.time,
				expires = nil,
			})
		end
	end
	f:close()
	return true
end
