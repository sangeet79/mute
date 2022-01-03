
function mute.importers.v1()
	local f, muteEntry = io.open(minetest.get_worldpath().."/players.iplist")
	if not f then
		return false, "Unable to open `players.iplist': "..muteEntry
	end
	for line in f:lines() do
		local list = line:split("|")
		if #list >= 2 then
			local muted = (list[1]:sub(1, 1) == "!")
			local entry
			entry = mute.find_entry(list[1], true)
			entry.muted = muted
			for _, name in ipairs(list) do
				entry.names[name] = true
			end
			if muted then
				entry.reason = "Muted in `players.iplist'"
				entry.time = os.time()
				entry.expires = nil
				entry.source = "mute:importer_v1"
				table.insert(entry.record, {
					source = entry.source,
					reason = entry.reason,
					time = entry.time,
					expires = nil,
				})
			end
		end
	end
	f:close()
	return true
end
