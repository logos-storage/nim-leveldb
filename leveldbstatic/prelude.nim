import os, strutils

const
  # Use explicit `/` for cross-compilation compatibility with Nix.
  # This should be safe on Windows as well.
  root = currentSourcePath.parentDir.parentDir.replace('\\', '/')
  envWindows = root & "/vendor/util/env_windows.cc"
  envPosix = root & "/vendor/util/env_posix.cc"

  LevelDbCMakeFlags {.strdefine.} =
    when defined(macosx):
      "-DCMAKE_BUILD_TYPE=Release -DLEVELDB_BUILD_BENCHMARKS=OFF"
    elif defined(windows):
      "-G\"MSYS Makefiles\" -DCMAKE_BUILD_TYPE=Release -DLEVELDB_BUILD_BENCHMARKS=OFF"
    else:
      "-DCMAKE_BUILD_TYPE=Release -DLEVELDB_BUILD_BENCHMARKS=OFF"

  LevelDbCMakeCommonFlags = " -DCMAKE_POLICY_VERSION_MINIMUM=3.31"

  LevelDbDir {.strdefine.} = root & "/vendor"
  buildDir = root & "/build"

proc buildLevelDb() =
  if fileExists(buildDir & "/Makefile"):
    echo "LevelDB already build. Delete '" & buildDir & "' to force rebuild."
    return

  echo "Initializing submodule..."
  discard gorge "git submodule deinit -f \"" & root & "\""
  discard gorge "git submodule update --init --recursive --checkout \"" & root & "\""

  echo "\nClean dir: \"" & buildDir & "\""
  discard gorge "rm -rf " & buildDir
  discard gorge "mkdir -p " & buildDir

  let cmd = "cmake -S \"" & LevelDbDir & "\" -B \"" & buildDir & "\" " & LevelDbCMakeFlags & LevelDbCMakeCommonFlags
  echo "\nBuilding LevelDB: " & cmd
  let (output, exitCode) = gorgeEx cmd
  if exitCode != 0:
    discard gorge "rm -rf " & buildDir
    echo output
    raise (ref Defect)(msg: "Failed to build LevelDB")

static:
  buildLevelDb()

when defined(windows):
  {.compile: envWindows.}
  {.passc: "-DLEVELDB_PLATFORM_WINDOWS".}
  {.passc: "-D_UNICODE".}
  {.passc: "-DUNICODE".}

when defined(posix):
  {.compile: envPosix.}
  {.passc: "-DLEVELDB_PLATFORM_POSIX".}
