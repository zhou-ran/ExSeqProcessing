# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.6

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake3

# The command to remove a file.
RM = /usr/bin/cmake3 -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /mp/nas1/fixstars/karl/SIFT3D

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mp/nas1/fixstars/karl/SIFT3D/build

# Include any dependencies generated for this target.
include reg/CMakeFiles/reg.dir/depend.make

# Include the progress variables for this target.
include reg/CMakeFiles/reg.dir/progress.make

# Include the compile flags for this target's objects.
include reg/CMakeFiles/reg.dir/flags.make

reg/CMakeFiles/reg.dir/reg.c.o: reg/CMakeFiles/reg.dir/flags.make
reg/CMakeFiles/reg.dir/reg.c.o: ../reg/reg.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building C object reg/CMakeFiles/reg.dir/reg.c.o"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/reg && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/reg.dir/reg.c.o   -c /mp/nas1/fixstars/karl/SIFT3D/reg/reg.c

reg/CMakeFiles/reg.dir/reg.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/reg.dir/reg.c.i"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/reg && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /mp/nas1/fixstars/karl/SIFT3D/reg/reg.c > CMakeFiles/reg.dir/reg.c.i

reg/CMakeFiles/reg.dir/reg.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/reg.dir/reg.c.s"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/reg && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /mp/nas1/fixstars/karl/SIFT3D/reg/reg.c -o CMakeFiles/reg.dir/reg.c.s

reg/CMakeFiles/reg.dir/reg.c.o.requires:

.PHONY : reg/CMakeFiles/reg.dir/reg.c.o.requires

reg/CMakeFiles/reg.dir/reg.c.o.provides: reg/CMakeFiles/reg.dir/reg.c.o.requires
	$(MAKE) -f reg/CMakeFiles/reg.dir/build.make reg/CMakeFiles/reg.dir/reg.c.o.provides.build
.PHONY : reg/CMakeFiles/reg.dir/reg.c.o.provides

reg/CMakeFiles/reg.dir/reg.c.o.provides.build: reg/CMakeFiles/reg.dir/reg.c.o


# Object files for target reg
reg_OBJECTS = \
"CMakeFiles/reg.dir/reg.c.o"

# External object files for target reg
reg_EXTERNAL_OBJECTS =

lib/libreg.so: reg/CMakeFiles/reg.dir/reg.c.o
lib/libreg.so: reg/CMakeFiles/reg.dir/build.make
lib/libreg.so: lib/libsift3D.so
lib/libreg.so: lib/libimutil.so
lib/libreg.so: /usr/lib64/libm.so
lib/libreg.so: reg/CMakeFiles/reg.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking C shared library ../lib/libreg.so"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/reg && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/reg.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
reg/CMakeFiles/reg.dir/build: lib/libreg.so

.PHONY : reg/CMakeFiles/reg.dir/build

reg/CMakeFiles/reg.dir/requires: reg/CMakeFiles/reg.dir/reg.c.o.requires

.PHONY : reg/CMakeFiles/reg.dir/requires

reg/CMakeFiles/reg.dir/clean:
	cd /mp/nas1/fixstars/karl/SIFT3D/build/reg && $(CMAKE_COMMAND) -P CMakeFiles/reg.dir/cmake_clean.cmake
.PHONY : reg/CMakeFiles/reg.dir/clean

reg/CMakeFiles/reg.dir/depend:
	cd /mp/nas1/fixstars/karl/SIFT3D/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mp/nas1/fixstars/karl/SIFT3D /mp/nas1/fixstars/karl/SIFT3D/reg /mp/nas1/fixstars/karl/SIFT3D/build /mp/nas1/fixstars/karl/SIFT3D/build/reg /mp/nas1/fixstars/karl/SIFT3D/build/reg/CMakeFiles/reg.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : reg/CMakeFiles/reg.dir/depend

