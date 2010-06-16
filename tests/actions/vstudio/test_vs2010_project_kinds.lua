	T.vs2010_project_kinds= { }
	local vs10_project_kinds = T.vs2010_project_kinds
	local sln, prj

	function vs10_project_kinds.setup()
		_ACTION = "vs2010"

		sln = solution "MySolution"
		configurations { "Debug" }
		platforms {}
	
		prj = project "MyProject"
		language "C++"
	end
	
	local function get_buffer()
		io.capture()
		premake.buildconfigs()
		sln.vstudio_configs = premake.vstudio_buildconfigs(sln)
		premake.vs2010_vcxproj(prj)
		buffer = io.endcapture()
		return buffer
	end
	
	function vs10_project_kinds.staticLib_doesNotContainLinkSection()
		kind "StaticLib"
		local buffer = get_buffer()
		test.string_does_not_contain(buffer,'<Link>*.*</Link>')
	end
		
	function vs10_project_kinds.staticLib_containsLibSection()
		kind "StaticLib"
		local buffer = get_buffer()
		test.string_contains(buffer,'<ItemDefinitionGroup*.*<Lib>*.*</Lib>*.*</ItemDefinitionGroup>')
	end
	function vs10_project_kinds.staticLib_libSection_containsProjectNameDotLib()
		kind "StaticLib"
		local buffer = get_buffer()
		test.string_contains(buffer,'<Lib>*.*<OutputFile>*.*MyProject.lib*.*</OutputFile>*.*</Lib>')
	end
	
	function vs10_project_kinds.sharedLib_fail_asIDoNotKnowWhatItShouldLookLike_printsTheBufferSoICanCompare()
		kind "SharedLib"
		local buffer = get_buffer()
		test.string_contains(buffer,'youWillNotFindThis')
	end
		
				