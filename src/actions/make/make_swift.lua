--
-- make_swift.lua
-- Generate a Swift project makefile.
--

local make = premake.make
local swift = { }

function premake.make_swift(prj)
	local tool = premake.gettool(prj)

	-- build a list of supported target platforms that also includes a generic build
	local platforms = premake.filterplatforms(prj.solution, tool.platforms, "Native")

	_p('# %s project makefile autogenerated by GENie', premake.action.current().shortname)

-- set up the environment
	_p('ifndef config')
	_p(1, 'config=%s', _MAKE.esc(premake.getconfigname(prj.solution.configurations[1], platforms[1], true)))
	_p('endif')
	_p('')

	_p('ifndef verbose')
	_p(1, 'SILENT = @')
	_p('endif')
	_p('')

	-- identify the shell type
	_p('SHELLTYPE := msdos')
	_p('ifeq (,$(ComSpec)$(COMSPEC))')
	_p(1, 'SHELLTYPE := posix')
	_p('endif')
	_p('ifeq (/bin,$(findstring /bin,$(SHELL)))')
	_p(1, 'SHELLTYPE := posix')
	_p('endif')
	_p('ifeq (/bin,$(findstring /bin,$(MAKESHELL)))')
	_p(1, 'SHELLTYPE := posix')
	_p('endif')
	_p('')

	_p('ifeq (posix,$(SHELLTYPE))')
	_p(1, 'MKDIR = $(SILENT) mkdir -p "$(1)"')
	_p(1, 'COPY  = $(SILENT) cp -fR "$(1)" "$(2)"')
	_p(1, 'RM    = $(SILENT) rm -f "$(1)"')
	_p('else')
	_p(1, 'MKDIR = $(SILENT) mkdir "$(subst /,\\\\,$(1))" 2> nul || exit 0')
	_p(1, 'COPY  = $(SILENT) copy /Y "$(subst /,\\\\,$(1))" "$(subst /,\\\\,$(2))"')
	_p(1, 'RM    = $(SILENT) del /F "$(subst /,\\\\,$(1))" 2> nul || exit 0')
	_p('endif')
	_p('')

	_p('SWIFTC = %s', tool.swift)
	_p('SWIFTLINK = %s', tool.swiftc)
	_p('AR = %s', tool.ar)
	_p('')

	-- write configuration blocks
	for _, platform in ipairs(platforms) do
		for cfg in premake.eachconfig(prj, platform) do
			swift.generate_config(prj, cfg, tool)
		end
	end
	
	_p('.PHONY: objects')
	
	_p('all: $(WORK_DIRS) $(TARGET)')
	_p('')

	_p('$(WORK_DIRS):')
	_p(1, '$(SILENT) $(call MKDIR,$@)')
	_p('')

	_p('SOURCES := \\')
	for _, file in ipairs(prj.files) do
		if path.isswiftfile(file) then
			_p(1, '%s \\', _MAKE.esc(file))
		end
	end
	_p('')

	local objfiles = {}
	_p('OBJECTS := \\')
	for _, file in ipairs(prj.files) do
		if path.isswiftfile(file) then
			local objname = _MAKE.esc(swift.objectname(file))
			table.insert(objfiles, objname)
			_p(1, '%s \\', objname)
		end
	end
	_p('')
	swift.file_rules(prj, objfiles)

	_p('')
	swift.linker(prj, tool)
	_p('')
end

function swift.objectname(file)
	return path.join("$(obj_dir)", path.getname(file)..".o")
end

function swift.file_rules(prj, objfiles)
	_p("objects: $(SOURCES) $(WORK_DIRS)")
	_p(1, "$(SILENT) $(SWIFTC) -frontend -c $(SOURCES) -enable-objc-interop $(sdk) -I $(out_dir) $(swiftc_flags) -module-cache-path $(out_dir)/ModuleCache -D SWIFT_PACKAGE $(module_maps) -emit-module-doc-path $(out_dir)/$(module_name).swiftdoc -module-name $(module_name) -emit-module-path $(out_dir)/$(module_name).swiftmodule -num-threads 8 %s", table.arglist("-o", objfiles))
end

function swift.linker(prj, ctool)
	local lddeps = make.list(premake.getlinks(prj, "siblings", "fullpath")) 

	if prj.kind == "StaticLib" then
		_p("$(TARGET): objects %s ", lddeps)
		_p(1, "$(SILENT) $(AR) cr $(ar_flags) $@ $(OBJECTS) %s", (os.is("MacOSX") and " 2>&1 > /dev/null | sed -e '/.o) has no symbols$$/d'" or ""))
	else
		_p("$(TARGET): objects $(LDDEPS)", lddeps)
		_p(1, "$(SILENT) $(SWIFTLINK) $(sdk) -L $(out_dir) -o $@ $(swiftlink_flags) $(OBJECTS)")
	end
end

function swift.generate_config(prj, cfg, tool)
	_p('ifeq ($(config),%s)', _MAKE.esc(cfg.shortname))

	_p(1, "out_dir = %s", cfg.buildtarget.directory)
	_p(1, "TARGET = $(out_dir)/%s", _MAKE.esc(cfg.buildtarget.name))
	local objdir = path.join(cfg.objectsdir, prj.name .. ".build")
	_p(1, "obj_dir = %s", objdir)
	_p(1, "module_name = %s", prj.name)
	_p(1, "module_maps = %s", make.list(tool.getmodulemaps(cfg)))
	_p(1, "swiftc_flags = %s", make.list(tool.getswiftcflags(cfg)))
	_p(1, "swiftlink_flags = %s", make.list(tool.getswiftlinkflags(cfg)))
	_p(1, "ar_flags = %s", make.list(tool.getarchiveflags(cfg, cfg, false)))
	_p(1, "LDDEPS = %s", make.list(premake.getlinks(cfg, "siblings", "fullpath")))

	local sdk = tool.get_sdk_path(cfg)
	if sdk then
		_p(1, "toolchain_path = %s", tool.get_toolchain_path(cfg))
		_p(1, "sdk_path = %s", sdk)
		_p(1, "platform_path = %s", tool.get_sdk_platform_path(cfg))
		_p(1, "sdk = -sdk $(sdk_path)")
	else
		_p(1, "sdk_path =")
		_p(1, "sdk =")
	end

	_p(1,'WORK_DIRS = $(out_dir) $(obj_dir)')

	_p('endif')
	_p('')
end