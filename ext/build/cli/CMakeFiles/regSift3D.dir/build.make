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
include cli/CMakeFiles/regSift3D.dir/depend.make

# Include the progress variables for this target.
include cli/CMakeFiles/regSift3D.dir/progress.make

# Include the compile flags for this target's objects.
include cli/CMakeFiles/regSift3D.dir/flags.make

cli/CMakeFiles/regSift3D.dir/regSift3D.c.o: cli/CMakeFiles/regSift3D.dir/flags.make
cli/CMakeFiles/regSift3D.dir/regSift3D.c.o: ../cli/regSift3D.c
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building C object cli/CMakeFiles/regSift3D.dir/regSift3D.c.o"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/cli && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -o CMakeFiles/regSift3D.dir/regSift3D.c.o   -c /mp/nas1/fixstars/karl/SIFT3D/cli/regSift3D.c

cli/CMakeFiles/regSift3D.dir/regSift3D.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/regSift3D.dir/regSift3D.c.i"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/cli && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -E /mp/nas1/fixstars/karl/SIFT3D/cli/regSift3D.c > CMakeFiles/regSift3D.dir/regSift3D.c.i

cli/CMakeFiles/regSift3D.dir/regSift3D.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/regSift3D.dir/regSift3D.c.s"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/cli && /bin/cc  $(C_DEFINES) $(C_INCLUDES) $(C_FLAGS) -S /mp/nas1/fixstars/karl/SIFT3D/cli/regSift3D.c -o CMakeFiles/regSift3D.dir/regSift3D.c.s

cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.requires:

.PHONY : cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.requires

cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.provides: cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.requires
	$(MAKE) -f cli/CMakeFiles/regSift3D.dir/build.make cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.provides.build
.PHONY : cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.provides

cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.provides.build: cli/CMakeFiles/regSift3D.dir/regSift3D.c.o


# Object files for target regSift3D
regSift3D_OBJECTS = \
"CMakeFiles/regSift3D.dir/regSift3D.c.o"

# External object files for target regSift3D
regSift3D_EXTERNAL_OBJECTS =

bin/regSift3D: cli/CMakeFiles/regSift3D.dir/regSift3D.c.o
bin/regSift3D: cli/CMakeFiles/regSift3D.dir/build.make
bin/regSift3D: lib/libreg.so
bin/regSift3D: lib/libsift3D.so
bin/regSift3D: lib/libimutil.so
bin/regSift3D: cli/CMakeFiles/regSift3D.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/mp/nas1/fixstars/karl/SIFT3D/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking C executable ../bin/regSift3D"
	cd /mp/nas1/fixstars/karl/SIFT3D/build/cli && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/regSift3D.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
cli/CMakeFiles/regSift3D.dir/build: bin/regSift3D

.PHONY : cli/CMakeFiles/regSift3D.dir/build

cli/CMakeFiles/regSift3D.dir/requires: cli/CMakeFiles/regSift3D.dir/regSift3D.c.o.requires

.PHONY : cli/CMakeFiles/regSift3D.dir/requires

cli/CMakeFiles/regSift3D.dir/clean:
	cd /mp/nas1/fixstars/karl/SIFT3D/build/cli && $(CMAKE_COMMAND) -P CMakeFiles/regSift3D.dir/cmake_clean.cmake
.PHONY : cli/CMakeFiles/regSift3D.dir/clean

cli/CMakeFiles/regSift3D.dir/depend:
	cd /mp/nas1/fixstars/karl/SIFT3D/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mp/nas1/fixstars/karl/SIFT3D /mp/nas1/fixstars/karl/SIFT3D/cli /mp/nas1/fixstars/karl/SIFT3D/build /mp/nas1/fixstars/karl/SIFT3D/build/cli /mp/nas1/fixstars/karl/SIFT3D/build/cli/CMakeFiles/regSift3D.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : cli/CMakeFiles/regSift3D.dir/depend

