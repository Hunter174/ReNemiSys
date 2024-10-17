import os
from SCons.Script import Environment, Glob, ARGUMENTS

# Define the environment
env = Environment()

# Paths to godot-cpp and Godot engine headers
godot_cpp_path = "../godot-cpp/"
include_paths = [
    godot_cpp_path + "include/",                          # Main include path for godot-cpp
    godot_cpp_path + "include/godot_cpp/",                # Path for godot.hpp
    godot_cpp_path + "gen/include/",                      # Path for the 'gen/include' folder
    godot_cpp_path + "gen/include/godot_cpp/classes/",    # Path for generated classes like Node2D.hpp
    godot_cpp_path + "gen/include/godot_cpp/core/",       # Path for core classes like Variant.hpp
    godot_cpp_path + "gdextension/"                       # Path for gdextension_interface.h
]

lib_paths = [godot_cpp_path + "bin/"]

# Add include and library paths to the environment
env.Append(CPPPATH=include_paths)
env.Append(LIBPATH=lib_paths)

# Check if we're building in release or debug mode
debug_mode = ARGUMENTS.get('debug', '0') == '1'

if debug_mode:
    # Debug configuration
    env.Append(CPPFLAGS=['-std=c++17', '-g'])  # Add debugging symbols with `-g`
    env.Append(LIBS=['godot-cpp.windows.template_debug.x86_64'])  # Link with debug library
else:
    # Release configuration
    env.Append(CPPFLAGS=['-std=c++17', '-O3'])  # Add optimization flag for release
    env.Append(LIBS=['godot-cpp.windows.template_release.x86_64'])  # Link with release library

# Find all .cpp source files in the current directory
sources = Glob("*.cpp")

# Build the shared library (.dll on Windows)
env.SharedLibrary(target='random_movement', source=sources)
