--
-- Embed the Lua scripts into src/host/scripts.c as static data buffers.
-- I embed the actual scripts, rather than Lua bytecodes, because the 
-- bytecodes are not portable to different architectures, which causes 
-- issues in Mac OS X Universal builds.
--

	local function stripfile(fname)
		dofile("scripts/luasrcdiet/LuaSrcDiet.lua")
		-- Let LuaSrcDiet do its job
		local s,l = get_slim_luasrc(fname)
		-- Now do some cleanup so we can write these out as C strings
		-- strip any CRs
		s = s:gsub("[\r]", "")

		print("\ttrimmed size: ", s:len(), " down from: ", l:len()) -- we report the "raw" length

		-- escape backslashes
		s = s:gsub("\\", "\\\\")

		-- escape line feeds
		s = s:gsub("\n", "\\n")
		
		-- escape double quote marks
		s = s:gsub("\"", "\\\"")
		return s
	end


	local function writeline(out, s, continues)
		out:write("\t\"")
		out:write(s)
		out:write(iif(continues, "\"\n", "\",\n"))
	end
	
	
	local function writefile(out, fname, contents)
		local max = 1024

		out:write("\t/* " .. fname .. " */\n")
		
		-- break up large strings to fit in Visual Studio's string length limit		
		local start = 1
		local len = contents:len()
		while start <= len do
			local n = len - start
			if n > max then n = max end
			local finish = start + n

			-- make sure I don't cut an escape sequence
			while contents:sub(finish, finish) == "\\" do
				finish = finish - 1
			end			

			writeline(out, contents:sub(start, finish), finish < len)
			start = finish + 1
		end		

		out:write("\n")
	end


	function doembed()
		-- load the manifest of script files
		scripts = dofile("src/_manifest.lua")
		
		-- main script always goes at the end
		table.insert(scripts, "_premake_main.lua")
		
		-- open scripts.c and write the file header
		local out = io.open("src/host/scripts.c", "w+b")
		out:write("/* Premake's Lua scripts, as static data buffers for release mode builds */\n")
		out:write("/* DO NOT EDIT - this file is autogenerated - see BUILD.txt */\n")
		out:write("/* To regenerate this file, run: premake4 embed */ \n\n")
		out:write("const char* builtin_scripts[] = {\n")
		
		for i,fn in ipairs(scripts) do
			print(fn)
			local s = stripfile("src/" .. fn)
			writefile(out, fn, s)
		end
		
		out:write("\t0\n};\n");		
		out:close()
	end
