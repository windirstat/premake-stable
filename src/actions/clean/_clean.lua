--
-- _clean.lua
-- The "clean" action: removes all generated files.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

	premake.clean = { }


--
-- Clean a solution or project specific file. Uses information in the project
-- object to build the target filename.
--
-- @param obj
--    A solution or project object.
-- @param pattern
--    A filename pattern to clean; see premake.project.getfilename() for
--    a description of the format.
--

	function premake.clean.file(obj, pattern)
		local fname = premake.project.getfilename(obj, pattern)
		os.remove(fname)
	end


--
-- Clean a solution or project specific file. Uses information in the project
-- object to build the target filename.
--
-- @param obj
--    A solution or project object.
-- @param pattern
--    A filename pattern to clean; see premake.project.getfilename() for
--    a description of the format.
--

	function premake.clean.file(obj, pattern)
		local fname = premake.project.getfilename(obj, pattern)
		os.remove(fname)
	end



--
-- Remove files created by an object's templates.
--

	local function cleantemplatefiles(this, templates)
		if (templates) then
			for _,tmpl in ipairs(templates) do
				local fname = premake.getoutputname(this, tmpl[1])
				os.remove(fname)
			end
		end
	end
	

--
-- Register the "clean" action.
--

	newaction {
		trigger     = "clean",
		description = "Remove all binaries and generated files",

		execute = function()
			local solutions = { }
			local projects = { }
			local targets = { }
			
			local cwd = os.getcwd()
			local function rebase(parent, dir)
				return path.getabsolute(path.rebase(dir, parent.location, cwd))
			end

			-- Walk the tree. Build a list of object names to pass to the cleaners,
			-- and delete any toolset agnostic files along the way.
			for _,sln in ipairs(_SOLUTIONS) do
				table.insert(solutions, path.join(sln.location, sln.name))
				
				-- build a list of supported target platforms that also includes a generic build
				local platforms = sln.platforms or { }
				if not table.contains(platforms, "Native") then
					platforms = table.join(platforms, { "Native" })
				end

				for prj in premake.eachproject(sln) do
					table.insert(projects, path.join(prj.location, prj.name))
					
					if (prj.objectsdir) then
						os.rmdir(rebase(prj, prj.objectsdir))
					end

					for _, platform in ipairs(platforms) do
						for cfg in premake.eachconfig(prj, platform) do
							table.insert(targets, path.join(rebase(cfg, cfg.buildtarget.directory), cfg.buildtarget.basename))

							-- remove all possible permutations of the target binary
							os.remove(rebase(cfg, premake.gettarget(cfg, "build", "posix", "windows", "windows").fullpath))
							os.remove(rebase(cfg, premake.gettarget(cfg, "build", "posix", "posix", "linux").fullpath))
							os.remove(rebase(cfg, premake.gettarget(cfg, "build", "posix", "posix", "macosx").fullpath))
							os.remove(rebase(cfg, premake.gettarget(cfg, "build", "posix", "PS3", "windows").fullpath))
							if (cfg.kind == "WindowedApp") then
								os.rmdir(rebase(cfg, premake.gettarget(cfg, "build", "posix", "posix", "linux").fullpath .. ".app"))
							end

							-- if there is an import library, remove that too
							os.remove(rebase(cfg, premake.gettarget(cfg, "link", "windows", "windows", "windows").fullpath))
							os.remove(rebase(cfg, premake.gettarget(cfg, "link", "posix", "posix", "linux").fullpath))

							-- remove the associated objects directory
							os.rmdir(rebase(cfg, cfg.objectsdir))
						end
					end
				end
			end

			-- Walk the tree again and let the actions clean up after themselves
			for action in premake.action.each() do
				for _, sln in ipairs(_SOLUTIONS) do
					if action.oncleansolution then
						action.oncleansolution(sln)
					end
					cleantemplatefiles(sln, action.solutiontemplates)

					for prj in premake.eachproject(sln) do
						if action.oncleanproject then
							action.oncleanproject(prj)
						end
						cleantemplatefiles(prj, action.projecttemplates)
					end
				end
				
				if (type(action.onclean) == "function") then
					action.onclean(solutions, projects, targets)
				end
			end
		end,		
	}
