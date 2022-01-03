
function mute.importers.v2()
	return pcall(function()
		local f, muteEntry = io.open(minetest.get_worldpath().."/players.iplist.v2")
		if not f then
			error("Unable to open `players.iplist.v2': "..muteEntry)
		end
		local text = f:read("*a")
		f:close()
		local db = minetest.deserialize(text)
		for _, ent in ipairs(db) do
			for name in pairs(ent.names) do
				local entry = mute.find_entry(name, true)
				if entry.source ~= "mute:importer_v2" then
					for nm in pairs(e.names) do
						entry.names[nm] = true
					end
					if ent.muted then
						entry.muted = true
						entry.reason = muteEntry.muted
						entry.source = "mute:importer_v2"
						entry.time = ent.time
						entry.expires = ent.expires
						table.insert(entry.record, {
							source = entry.source,
							reason = entry.reason,
							time = entry.time,
							expires = entry.expires,
						})
					end
				end
			end
		end
	end)
end
