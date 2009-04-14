--
-- make_csharp.lua
-- Generate a C# project makefile.
-- Copyright (c) 2002-2009 Jason Perkins and the Premake project
--

--
-- Given a .resx resource file, builds the path to corresponding .resource
-- file, matching the behavior and naming of Visual Studio.
--
		
	local function getresourcefilename(cfg, fname)
		if path.getextension(fname) == ".resx" then
		    local name = cfg.buildtarget.basename .. "."
		    local dir = path.getdirectory(fname)
		    if dir ~= "." then 
				name = name .. path.translate(dir, ".") .. "."
			end
			return "$(OBJDIR)/" .. name .. path.getbasename(fname) .. ".resources"
		else
			return fname
		end
	end


--
-- Main function
--
	
	function premake.make_csharp(prj)
		local csc = premake.csc

		-- Do some processing up front: build a list of configuration-dependent libraries.
		-- Libraries that are built to a location other than $(TARGETDIR) will need to
		-- be copied so they can be found at runtime.
		local cfglibs = { }
		local cfgpairs = { }
		local anycfg
		for cfg in premake.eachconfig(prj) do
			anycfg = cfg
			cfglibs[cfg] = premake.getlinks(cfg, "siblings", "fullpath")
			cfgpairs[cfg] = { }
			for _, fname in ipairs(cfglibs[cfg]) do
				if path.getdirectory(fname) ~= cfg.buildtarget.directory then
					cfgpairs[cfg]["$(TARGETDIR)/"..path.getname(fname)] = fname
				end
			end
		end
		
		-- sort the files into categories, based on their build action
		local sources = {}
		local embedded = { }
		local copypairs = { }
		
		for fcfg in premake.eachfile(prj) do
			local action = csc.getbuildaction(fcfg)
			if action == "Compile" then
				table.insert(sources, fcfg.name)
			elseif action == "EmbeddedResource" then			
				table.insert(embedded, fcfg.name)
			elseif action == "Content" then
				copypairs["$(TARGETDIR)/"..path.getname(fcfg.name)] = fcfg.name
			elseif path.getname(fcfg.name):lower() == "app.config" then
				copypairs["$(TARGET).config"] = fcfg.name	
			end
		end

		-- Any assemblies that are on the library search paths should be copied
		-- to $(TARGETDIR) so they can be found at runtime
		local paths = table.translate(prj.libdirs, function(v) return path.join(prj.basedir, v) end)
		paths = table.join({prj.basedir}, paths)
		for _, libname in ipairs(premake.getlinks(prj, "system", "fullpath")) do
			local libdir = os.pathsearch(libname..".dll", unpack(paths))
			if (libdir) then
				local target = "$(TARGETDIR)/"..path.getname(libname)
				local source = path.getrelative(prj.basedir, path.join(libdir, libname))..".dll"
				copypairs[target] = source
			end
		end
		
		-- end of preprocessing --


		-- set up the environment
		_p('# %s project makefile autogenerated by Premake', premake.actions[_ACTION].shortname)
		_p('')
		
		_p('ifndef config')
		_p('  config=%s', _MAKE.esc(prj.configurations[1]:lower()))
		_p('endif')
		_p('')
		
		_p('ifndef verbose')
		_p('  SILENT = @')
		_p('endif')
		_p('')
		
		_p('ifndef CSC')
		_p('  CSC=%s', csc.getcompilervar(prj))
		_p('endif')
		_p('')
		
		_p('ifndef RESGEN')
		_p('  RESGEN=resgen')
		_p('endif')
		_p('')

		-- Platforms aren't support for .NET projects, but I need the ability to match
		-- the buildcfg:platform identifiers with a block of settings. So enumerate the
		-- pairs the same way I do for C/C++ projects, but always use the generic settings
		local platforms = premake.filterplatforms(prj.solution, premake[_OPTIONS.cc].platforms)
		table.insert(platforms, 1, "")

		-- write the configuration blocks
		for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj) do
				_p('ifeq ($(config),%s)', table.concat({ _MAKE.esc(cfg.name:lower()), iif(platform ~= "", platform)}, ":"))
				_p('  TARGETDIR  := %s', _MAKE.esc(cfg.buildtarget.directory))
				_p('  OBJDIR     := %s', _MAKE.esc(cfg.objectsdir))
				_p('  DEPENDS    := %s', table.concat(_MAKE.esc(premake.getlinks(cfg, "dependencies", "fullpath")), " "))
				_p('  REFERENCES := %s', table.implode(_MAKE.esc(cfglibs[cfg]), "/r:", "", " "))
				_p('  FLAGS      += %s %s', table.concat(csc.getflags(cfg), " "), table.implode(cfg.defines, "/d:", "", " "))
				
				_p('  define PREBUILDCMDS')
				if #cfg.prebuildcommands > 0 then
					_p('\t@echo Running pre-build commands')
					_p('\t%s', table.implode(cfg.prebuildcommands, "", "", "\n\t"))
				end
				_p('  endef')
				
				_p('  define PRELINKCMDS')
				if #cfg.prelinkcommands > 0 then
					_p('\t@echo Running pre-link commands')
					_p('\t%s', table.implode(cfg.prelinkcommands, "", "", "\n\t"))
				end
				_p('  endef')
				
				_p('  define POSTBUILDCMDS')
				if #cfg.postbuildcommands > 0 then
					_p('\t@echo Running post-build commands')
					_p('\t%s', table.implode(cfg.postbuildcommands, "", "", "\n\t"))
				end
				_p('  endef')
				
				_p('endif')
				_p('')
			end
		end

		-- set project level values
		_p('# To maintain compatibility with VS.NET, these values must be set at the project level')
		_p('TARGET      = $(TARGETDIR)/%s', _MAKE.esc(prj.buildtarget.name))
		_p('FLAGS      += /t:%s %s', csc.getkind(prj):lower(), table.implode(_MAKE.esc(prj.libdirs), "/lib:", "", " "))
		_p('REFERENCES += %s', table.implode(_MAKE.esc(premake.getlinks(prj, "system", "basename")), "/r:", ".dll", " "))
		_p('')
		
		-- list source files
		_p('SOURCES := \\')
		for _, fname in ipairs(sources) do
			_p('\t%s \\', _MAKE.esc(path.translate(fname)))
		end
		_p('')
		
		_p('EMBEDFILES := \\')
		for _, fname in ipairs(embedded) do
			_p('\t%s \\', _MAKE.esc(getresourcefilename(prj, fname)))
		end
		_p('')

		_p('COPYFILES += \\')
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t%s \\', _MAKE.esc(target))
		end
		for target, source in pairs(copypairs) do
			_p('\t%s \\', _MAKE.esc(target))
		end
		_p('')

		-- set up support commands like mkdir, rmdir, etc. based on the shell
		_p('SHELLTYPE := msdos')
		_p('ifeq (,$(ComSpec)$(COMSPEC))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (/bin,$(findstring /bin,$(SHELL)))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('   define MKDIR_RULE')
		_p('\t@echo Creating $@')
		_p('\t$(SILENT) mkdir -p $@')
		_p('   endef')
		_p('  define COPY_RULE')
		_p('\t@echo Copying $(notdir $@)')
		_p('\t$(SILENT) cp -fR $^ $@')
		_p('  endef')
		_p('else')
		_p('   define MKDIR_RULE')
		_p('\t@echo Creating $@')
		_p('\t$(SILENT) mkdir $(subst /,\\\\,$@)')
		_p('   endef')
		_p('  define COPY_RULE')
		_p('\t@echo Copying $(notdir $@)')
		_p('\t$(SILENT) copy /Y $(subst /,\\\\,$^) $(subst /,\\\\,$@)')
		_p('  endef')
		_p('endif')

		-- main build rule(s)
		_p('.PHONY: clean prebuild prelink')
		_p('')
		
		_p('all: $(TARGETDIR) $(OBJDIR) prebuild $(EMBEDFILES) $(COPYFILES) prelink $(TARGET)')
		_p('')
		
		_p('$(TARGET): $(SOURCES) $(EMBEDFILES) $(DEPENDS)')
		_p('\t$(SILENT) $(CSC) /nologo /out:$@ $(FLAGS) $(REFERENCES) $(SOURCES) $(patsubst %%,/resource:%%,$(EMBEDFILES))')
		_p('\t$(POSTBUILDCMDS)')
		_p('')

		-- create destination directories
		_p('$(TARGETDIR):')
		_p('\t$(MKDIR_RULE)')
		_p('')
		
		_p('$(OBJDIR):')
		_p('\t$(MKDIR_RULE)')
		_p('')

		-- clean target
		_p('clean:')
		_p('\t@echo Cleaning %s', prj.name)
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) rm -f $(TARGETDIR)/%s.* $(COPYFILES)', prj.buildtarget.basename)
		_p('\t$(SILENT) rm -rf $(OBJDIR)')
		_p('else')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(TARGETDIR)/%s.*) del $(subst /,\\\\,$(TARGETDIR)/%s.*)', prj.buildtarget.basename, prj.buildtarget.basename)
		for target, source in pairs(cfgpairs[anycfg]) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		for target, source in pairs(copypairs) do
			_p('\t$(SILENT) if exist $(subst /,\\\\,%s) del $(subst /,\\\\,%s)', target, target)
		end
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(OBJDIR)) rmdir /s /q $(subst /,\\\\,$(OBJDIR))')
		_p('endif')
		_p('')

		-- custom build step targets
		_p('prebuild:')
		_p('\t$(PREBUILDCMDS)')
		_p('')
		
		_p('prelink:')
		_p('\t$(PRELINKCMDS)')
		_p('')

		-- per-file rules
		_p('# Per-configuration copied file rules')
		for cfg in premake.eachconfig(prj) do
			_p('ifeq ($(config),%s)', _MAKE.esc(cfg.name:lower()))
			for target, source in pairs(cfgpairs[cfg]) do
				_p('%s: %s', _MAKE.esc(target), _MAKE.esc(source))
				_p('\t$(COPY_RULE)')
			end
			_p('endif')
		end
		_p('')
		
		_p('# Copied file rules')
		for target, source in pairs(copypairs) do
			_p('%s: %s', _MAKE.esc(target), _MAKE.esc(source))
			_p('\t$(COPY_RULE)')
			_p('')
		end

		_p('# Embedded file rules')
		for _, fname in ipairs(embedded) do 
			if path.getextension(fname) == ".resx" then
				_p('%s: %s', _MAKE.esc(getresourcefilename(prj, fname)), _MAKE.esc(fname))
				_p('\t$(SILENT) $(RESGEN) $^ $@')
			end
			_p('')
		end
		
	end
