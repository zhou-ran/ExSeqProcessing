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
include examples/CMakeFiles/registerC.dir/depend.make

# Include the progress variables for this target.
include examples/CMakeFiles/registerC.dir/progress.make

# Include the compile flags for this target's objects.
include examples/CMakeFiles/registerC.dir/flags.make

examples/CMakeFiles/registerC.dir/registerC.c.o: examples/CMakeFiles/registerC.dir/flags.make
examples/CMakeFiles/registerC.dir/registerC.c.o: ../examples/registerC.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building C object examples/CMakeFiles/registerC.dir/registerC.c.o"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/examples && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/registerC.dir/registerC.c.o   -c /mp/nas1/fixstars/karl/SIFT3D/examples/registerC.c

examples/CMakeFiles/registerC.dir/registerC.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/registerC.dir/registerC.c.i"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/examples && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /mp/nas1/fixstars/karl/SIFT3D/examples/registerC.c > CMakeFiles/registerC.dir/registerC.c.i

examples/CMakeFiles/registerC.dir/registerC.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/registerC.dir/registerC.c.s"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/examples && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /mp/nas1/fixstars/karl/SIFT3D/examples/registerC.c -o CMakeFiles/registerC.dir/registerC.c.s

examples/CMakeFiles/registerC.dir/registerC.c.o.requires:

.PHONY : examples/CMakeFiles/registerC.dir/registerC.c.o.requires

examples/CMakeFiles/registerC.dir/registerC.c.o.provides: examples/CMakeFiles/registerC.dir/registerC.c.o.requires
	$(MAKE) -f examples/CMakeFiles/registerC.dir/build.make examples/CMakeFiles/registerC.dir/registerC.c.o.provides.build
.PHONY : examples/CMakeFiles/registerC.dir/registerC.c.o.provides

examples/CMakeFiles/registerC.dir/registerC.c.o.provides.build: examples/CMakeFiles/registerC.dir/registerC.c.o


# Object files for target registerC
registerC_OBJECTS = \
"CMakeFiles/registerC.dir/registerC.c.o"

# External object files for target registerC
registerC_EXTERNAL_OBJECTS =

examples/registerC: examples/CMakeFiles/registerC.dir/registerC.c.o
examples/registerC: examples/CMakeFiles/registerC.dir/build.make
examples/registerC: lib/libreg.so
examples/registerC: lib/libsift3D.so
examples/registerC: lib/libimutil.so
examples/registerC: examples/CMakeFiles/registerC.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking C executable registerC"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/examples && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/registerC.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
examples/CMakeFiles/registerC.dir/build: examples/registerC

.PHONY : examples/CMakeFiles/registerC.dir/build

examples/CMakeFiles/registerC.dir/requires: examples/CMakeFiles/registerC.dir/registerC.c.o.requires

.PHONY : examples/CMakeFiles/registerC.dir/requires

examples/CMakeFiles/registerC.dir/clean:
	cd /mp/nas1/fixstars/karl/SIFT3D/build/examples && $(CMAKE_COMMAND) -P CMakeFiles/registerC.dir/cmake_clean.cmake
.PHONY : examples/CMakeFiles/registerC.dir/clean

examples/CMakeFiles/registerC.dir/depend:
	cd /mp/nas1/fixstars/karl/SIFT3D/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mp/nas1/fixstars/karl/SIFT3D /mp/nas1/fixstars/karl/SIFT3D/examples /mp/nas1/fixstars/karl/SIFT3D/build /mp/nas1/fixstars/karl/SIFT3D/build/examples /mp/nas1/fixstars/karl/SIFT3D/build/examples/CMakeFiles/registerC.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : examples/CMakeFiles/registerC.dir/depend

