
mute.importers = { }

dofile(mute.MP.."/importers/minetest.lua")
dofile(mute.MP.."/importers/v1.lua")
dofile(mute.MP.."/importers/v2.lua")

minetest.register_chatcommand("mute_dbi", {
	description = "Import old databases",
	params = "<importer>",
	privs = { server=true },
	func = function(name, params)
		if params == "--list" then
			local importers = { }
			for importer in pairs(mute.importers) do
				table.insert(importers, importer)
			end
			minetest.chat_send_player(name,
			  ("[mute] Known importers: %s"):format(
			  table.concat(importers, ", ")))
			return
		elseif not mute.importers[params] then
			minetest.chat_send_player(name,
			  ("[mute] Unknown importer `%s'"):format(params))
			minetest.chat_send_player(name, "[mute] Try `--list'")
			return
		end
		local f = mute.importers[params]
		local ok, err = f()
		if ok then
			minetest.chat_send_player(name,
			  "[mute] Import successfull")
		else
			minetest.chat_send_player(name,
			  ("[mute] Import failed: %s"):format(err))
		end
	end,
})
