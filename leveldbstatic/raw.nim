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

# Generated @ 2024-12-09T16:35:09+01:00
# Command line:
#   /home/arnaud/.nimble/pkgs2/nimterop-0.6.13-a93246b2ad5531db11e51de7b2d188c42d95576a/nimterop/toast --compile=./vendor/util/bloom.cc --compile=./vendor/util/arena.cc --compile=./vendor/util/env.cc --compile=./vendor/util/filter_policy.cc --compile=./vendor/util/histogram.cc --compile=./vendor/util/hash.cc --compile=./vendor/util/comparator.cc --compile=./vendor/util/options.cc --compile=./vendor/util/logging.cc --compile=./vendor/util/status.cc --compile=./vendor/util/coding.cc --compile=./vendor/util/cache.cc --compile=./vendor/util/crc32c.cc --compile=./vendor/table/table.cc --compile=./vendor/table/format.cc --compile=./vendor/table/table_builder.cc --compile=./vendor/table/block_builder.cc --compile=./vendor/table/merger.cc --compile=./vendor/table/block.cc --compile=./vendor/table/filter_block.cc --compile=./vendor/table/iterator.cc --compile=./vendor/table/two_level_iterator.cc --compile=./vendor/helpers/memenv/memenv.cc --compile=./vendor/db/filename.cc --compile=./vendor/db/dbformat.cc --compile=./vendor/db/c.cc --compile=./vendor/db/memtable.cc --compile=./vendor/db/version_set.cc --compile=./vendor/db/repair.cc --compile=./vendor/db/builder.cc --compile=./vendor/db/write_batch.cc --compile=./vendor/db/version_edit.cc --compile=./vendor/db/dumpfile.cc --compile=./vendor/db/db_impl.cc --compile=./vendor/db/log_reader.cc --compile=./vendor/db/table_cache.cc --compile=./vendor/db/db_iter.cc --compile=./vendor/db/log_writer.cc --pnim --preprocess --noHeader --includeDirs=./vendor --includeDirs=./vendor/helpers --includeDirs=./vendor/helpers/memenv --includeDirs=./vendor/port --includeDirs=./vendor/include ./vendor/include/leveldb/c.h

{.push hint[ConvFromXtoItselfNotNeeded]: off.}
import macros

macro defineEnum(typ: untyped): untyped =
  result = newNimNode(nnkStmtList)

  # Enum mapped to distinct cint
  result.add quote do:
    type `typ`* = distinct cint

  for i in ["+", "-", "*", "div", "mod", "shl", "shr", "or", "and", "xor", "<", "<=", "==", ">", ">="]:
    let
      ni = newIdentNode(i)
      typout = if i[0] in "<=>": newIdentNode("bool") else: typ # comparisons return bool
    if i[0] == '>': # cannot borrow `>` and `>=` from templates
      let
        nopp = if i.len == 2: newIdentNode("<=") else: newIdentNode("<")
      result.add quote do:
        proc `ni`*(x: `typ`, y: cint): `typout` = `nopp`(y, x)
        proc `ni`*(x: cint, y: `typ`): `typout` = `nopp`(y, x)
        proc `ni`*(x, y: `typ`): `typout` = `nopp`(y, x)
    else:
      result.add quote do:
        proc `ni`*(x: `typ`, y: cint): `typout` {.borrow.}
        proc `ni`*(x: cint, y: `typ`): `typout` {.borrow.}
        proc `ni`*(x, y: `typ`): `typout` {.borrow.}
    result.add quote do:
      proc `ni`*(x: `typ`, y: int): `typout` = `ni`(x, y.cint)
      proc `ni`*(x: int, y: `typ`): `typout` = `ni`(x.cint, y)

  let
    divop = newIdentNode("/")   # `/`()
    dlrop = newIdentNode("$")   # `$`()
    notop = newIdentNode("not") # `not`()
  result.add quote do:
    proc `divop`*(x, y: `typ`): `typ` = `typ`((x.float / y.float).cint)
    proc `divop`*(x: `typ`, y: cint): `typ` = `divop`(x, `typ`(y))
    proc `divop`*(x: cint, y: `typ`): `typ` = `divop`(`typ`(x), y)
    proc `divop`*(x: `typ`, y: int): `typ` = `divop`(x, y.cint)
    proc `divop`*(x: int, y: `typ`): `typ` = `divop`(x.cint, y)

    proc `dlrop`*(x: `typ`): string {.borrow.}
    proc `notop`*(x: `typ`): `typ` {.borrow.}


{.experimental: "codeReordering".}
{.passc: "-I" & root & "/vendor".}
{.passc: "-I" & root & "/vendor/helpers".}
{.passc: "-I" & root & "/vendor/helpers/memenv".}
{.passc: "-I" & root & "/vendor/port".}
{.passc: "-I" & root & "/vendor/include".}
{.compile: root & "/vendor/util/bloom.cc".}
{.compile: root & "/vendor/util/arena.cc".}
{.compile: root & "/vendor/util/env.cc".}
{.compile: root & "/vendor/util/filter_policy.cc".}
{.compile: root & "/vendor/util/histogram.cc".}
{.compile: root & "/vendor/util/hash.cc".}
{.compile: root & "/vendor/util/comparator.cc".}
{.compile: root & "/vendor/util/options.cc".}
{.compile: root & "/vendor/util/logging.cc".}
{.compile: root & "/vendor/util/status.cc".}
{.compile: root & "/vendor/util/coding.cc".}
{.compile: root & "/vendor/util/cache.cc".}
{.compile: root & "/vendor/util/crc32c.cc".}
{.compile: root & "/vendor/table/table.cc".}
{.compile: root & "/vendor/table/format.cc".}
{.compile: root & "/vendor/table/table_builder.cc".}
{.compile: root & "/vendor/table/block_builder.cc".}
{.compile: root & "/vendor/table/merger.cc".}
{.compile: root & "/vendor/table/block.cc".}
{.compile: root & "/vendor/table/filter_block.cc".}
{.compile: root & "/vendor/table/iterator.cc".}
{.compile: root & "/vendor/table/two_level_iterator.cc".}
{.compile: root & "/vendor/helpers/memenv/memenv.cc".}
{.compile: root & "/vendor/db/filename.cc".}
{.compile: root & "/vendor/db/dbformat.cc".}
{.compile: root & "/vendor/db/c.cc".}
{.compile: root & "/vendor/db/memtable.cc".}
{.compile: root & "/vendor/db/version_set.cc".}
{.compile: root & "/vendor/db/repair.cc".}
{.compile: root & "/vendor/db/builder.cc".}
{.compile: root & "/vendor/db/write_batch.cc".}
{.compile: root & "/vendor/db/version_edit.cc".}
{.compile: root & "/vendor/db/dumpfile.cc".}
{.compile: root & "/vendor/db/db_impl.cc".}
{.compile: root & "/vendor/db/log_reader.cc".}
{.compile: root & "/vendor/db/table_cache.cc".}
{.compile: root & "/vendor/db/db_iter.cc".}
{.compile: root & "/vendor/db/log_writer.cc".}
defineEnum(Enum_ch1)
const
  leveldb_no_compression* = (0).cint
  leveldb_snappy_compression* = (1).cint
type
  leveldb_t* {.incompleteStruct.} = object
  leveldb_cache_t* {.incompleteStruct.} = object
  leveldb_comparator_t* {.incompleteStruct.} = object
  leveldb_env_t* {.incompleteStruct.} = object
  leveldb_filelock_t* {.incompleteStruct.} = object
  leveldb_filterpolicy_t* {.incompleteStruct.} = object
  leveldb_iterator_t* {.incompleteStruct.} = object
  leveldb_logger_t* {.incompleteStruct.} = object
  leveldb_options_t* {.incompleteStruct.} = object
  leveldb_randomfile_t* {.incompleteStruct.} = object
  leveldb_readoptions_t* {.incompleteStruct.} = object
  leveldb_seqfile_t* {.incompleteStruct.} = object
  leveldb_snapshot_t* {.incompleteStruct.} = object
  leveldb_writablefile_t* {.incompleteStruct.} = object
  leveldb_writebatch_t* {.incompleteStruct.} = object
  leveldb_writeoptions_t* {.incompleteStruct.} = object
proc leveldb_open*(options: ptr leveldb_options_t; name: cstring;
                   errptr: ptr cstring): ptr leveldb_t {.importc, cdecl.}
proc leveldb_close*(db: ptr leveldb_t) {.importc, cdecl.}
proc leveldb_put*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t;
                  key: cstring; keylen: uint; val: cstring; vallen: uint;
                  errptr: ptr cstring) {.importc, cdecl.}
proc leveldb_delete*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t;
                     key: cstring; keylen: uint; errptr: ptr cstring) {.importc,
    cdecl.}
proc leveldb_write*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t;
                    batch: ptr leveldb_writebatch_t; errptr: ptr cstring) {.
    importc, cdecl.}
proc leveldb_get*(db: ptr leveldb_t; options: ptr leveldb_readoptions_t;
                  key: cstring; keylen: uint; vallen: ptr uint;
                  errptr: ptr cstring): cstring {.importc, cdecl.}
  ## ```
                                                                  ##   Returns NULL if not found.  A malloc()ed array otherwise.
                                                                  ##      Stores the length of the array invallen.
                                                                  ## ```
proc leveldb_create_iterator*(db: ptr leveldb_t;
                              options: ptr leveldb_readoptions_t): ptr leveldb_iterator_t {.
    importc, cdecl.}
proc leveldb_create_snapshot*(db: ptr leveldb_t): ptr leveldb_snapshot_t {.
    importc, cdecl.}
proc leveldb_release_snapshot*(db: ptr leveldb_t;
                               snapshot: ptr leveldb_snapshot_t) {.importc,
    cdecl.}
proc leveldb_property_value*(db: ptr leveldb_t; propname: cstring): cstring {.
    importc, cdecl.}
  ## ```
                    ##   Returns NULL if property name is unknown.
                    ##      Else returns a pointer to a malloc()-ed null-terminated value.
                    ## ```
proc leveldb_approximate_sizes*(db: ptr leveldb_t; num_ranges: cint;
                                range_start_key: ptr cstring;
                                range_start_key_len: ptr uint;
                                range_limit_key: ptr cstring;
                                range_limit_key_len: ptr uint; sizes: ptr uint64) {.
    importc, cdecl.}
proc leveldb_compact_range*(db: ptr leveldb_t; start_key: cstring;
                            start_key_len: uint; limit_key: cstring;
                            limit_key_len: uint) {.importc, cdecl.}
proc leveldb_destroy_db*(options: ptr leveldb_options_t; name: cstring;
                         errptr: ptr cstring) {.importc, cdecl.}
proc leveldb_repair_db*(options: ptr leveldb_options_t; name: cstring;
                        errptr: ptr cstring) {.importc, cdecl.}
proc leveldb_iter_destroy*(a1: ptr leveldb_iterator_t) {.importc, cdecl.}
proc leveldb_iter_valid*(a1: ptr leveldb_iterator_t): uint8 {.importc, cdecl.}
proc leveldb_iter_seek_to_first*(a1: ptr leveldb_iterator_t) {.importc, cdecl.}
proc leveldb_iter_seek_to_last*(a1: ptr leveldb_iterator_t) {.importc, cdecl.}
proc leveldb_iter_seek*(a1: ptr leveldb_iterator_t; k: cstring; klen: uint) {.
    importc, cdecl.}
proc leveldb_iter_next*(a1: ptr leveldb_iterator_t) {.importc, cdecl.}
proc leveldb_iter_prev*(a1: ptr leveldb_iterator_t) {.importc, cdecl.}
proc leveldb_iter_key*(a1: ptr leveldb_iterator_t; klen: ptr uint): cstring {.
    importc, cdecl.}
proc leveldb_iter_value*(a1: ptr leveldb_iterator_t; vlen: ptr uint): cstring {.
    importc, cdecl.}
proc leveldb_iter_get_error*(a1: ptr leveldb_iterator_t; errptr: ptr cstring) {.
    importc, cdecl.}
proc leveldb_writebatch_create*(): ptr leveldb_writebatch_t {.importc, cdecl.}
proc leveldb_writebatch_destroy*(a1: ptr leveldb_writebatch_t) {.importc, cdecl.}
proc leveldb_writebatch_clear*(a1: ptr leveldb_writebatch_t) {.importc, cdecl.}
proc leveldb_writebatch_put*(a1: ptr leveldb_writebatch_t; key: cstring;
                             klen: uint; val: cstring; vlen: uint) {.importc,
    cdecl.}
proc leveldb_writebatch_delete*(a1: ptr leveldb_writebatch_t; key: cstring;
                                klen: uint) {.importc, cdecl.}
proc leveldb_writebatch_iterate*(a1: ptr leveldb_writebatch_t; state: pointer;
    put: proc (a1: pointer; k: cstring; klen: uint; v: cstring; vlen: uint) {.
    cdecl.}; deleted: proc (a1: pointer; k: cstring; klen: uint) {.cdecl.}) {.
    importc, cdecl.}
proc leveldb_writebatch_append*(destination: ptr leveldb_writebatch_t;
                                source: ptr leveldb_writebatch_t) {.importc,
    cdecl.}
proc leveldb_options_create*(): ptr leveldb_options_t {.importc, cdecl.}
proc leveldb_options_destroy*(a1: ptr leveldb_options_t) {.importc, cdecl.}
proc leveldb_options_set_comparator*(a1: ptr leveldb_options_t;
                                     a2: ptr leveldb_comparator_t) {.importc,
    cdecl.}
proc leveldb_options_set_filter_policy*(a1: ptr leveldb_options_t;
                                        a2: ptr leveldb_filterpolicy_t) {.
    importc, cdecl.}
proc leveldb_options_set_create_if_missing*(a1: ptr leveldb_options_t; a2: uint8) {.
    importc, cdecl.}
proc leveldb_options_set_error_if_exists*(a1: ptr leveldb_options_t; a2: uint8) {.
    importc, cdecl.}
proc leveldb_options_set_paranoid_checks*(a1: ptr leveldb_options_t; a2: uint8) {.
    importc, cdecl.}
proc leveldb_options_set_env*(a1: ptr leveldb_options_t; a2: ptr leveldb_env_t) {.
    importc, cdecl.}
proc leveldb_options_set_info_log*(a1: ptr leveldb_options_t;
                                   a2: ptr leveldb_logger_t) {.importc, cdecl.}
proc leveldb_options_set_write_buffer_size*(a1: ptr leveldb_options_t; a2: uint) {.
    importc, cdecl.}
proc leveldb_options_set_max_open_files*(a1: ptr leveldb_options_t; a2: cint) {.
    importc, cdecl.}
proc leveldb_options_set_cache*(a1: ptr leveldb_options_t;
                                a2: ptr leveldb_cache_t) {.importc, cdecl.}
proc leveldb_options_set_block_size*(a1: ptr leveldb_options_t; a2: uint) {.
    importc, cdecl.}
proc leveldb_options_set_block_restart_interval*(a1: ptr leveldb_options_t;
    a2: cint) {.importc, cdecl.}
proc leveldb_options_set_max_file_size*(a1: ptr leveldb_options_t; a2: uint) {.
    importc, cdecl.}
proc leveldb_options_set_compression*(a1: ptr leveldb_options_t; a2: cint) {.
    importc, cdecl.}
proc leveldb_comparator_create*(state: pointer;
                                destructor: proc (a1: pointer) {.cdecl.};
    compare: proc (a1: pointer; a: cstring; alen: uint; b: cstring; blen: uint): cint {.
    cdecl.}; name: proc (a1: pointer): cstring {.cdecl.}): ptr leveldb_comparator_t {.
    importc, cdecl.}
proc leveldb_comparator_destroy*(a1: ptr leveldb_comparator_t) {.importc, cdecl.}
proc leveldb_filterpolicy_create*(state: pointer;
                                  destructor: proc (a1: pointer) {.cdecl.};
    create_filter: proc (a1: pointer; key_array: ptr cstring;
                         key_length_array: ptr uint; num_keys: cint;
                         filter_length: ptr uint): cstring {.cdecl.};
    key_may_match: proc (a1: pointer; key: cstring; length: uint;
                         filter: cstring; filter_length: uint): uint8 {.cdecl.};
                                  name: proc (a1: pointer): cstring {.cdecl.}): ptr leveldb_filterpolicy_t {.
    importc, cdecl.}
proc leveldb_filterpolicy_destroy*(a1: ptr leveldb_filterpolicy_t) {.importc,
    cdecl.}
proc leveldb_filterpolicy_create_bloom*(bits_per_key: cint): ptr leveldb_filterpolicy_t {.
    importc, cdecl.}
proc leveldb_readoptions_create*(): ptr leveldb_readoptions_t {.importc, cdecl.}
proc leveldb_readoptions_destroy*(a1: ptr leveldb_readoptions_t) {.importc,
    cdecl.}
proc leveldb_readoptions_set_verify_checksums*(a1: ptr leveldb_readoptions_t;
    a2: uint8) {.importc, cdecl.}
proc leveldb_readoptions_set_fill_cache*(a1: ptr leveldb_readoptions_t;
    a2: uint8) {.importc, cdecl.}
proc leveldb_readoptions_set_snapshot*(a1: ptr leveldb_readoptions_t;
                                       a2: ptr leveldb_snapshot_t) {.importc,
    cdecl.}
proc leveldb_writeoptions_create*(): ptr leveldb_writeoptions_t {.importc, cdecl.}
proc leveldb_writeoptions_destroy*(a1: ptr leveldb_writeoptions_t) {.importc,
    cdecl.}
proc leveldb_writeoptions_set_sync*(a1: ptr leveldb_writeoptions_t; a2: uint8) {.
    importc, cdecl.}
proc leveldb_cache_create_lru*(capacity: uint): ptr leveldb_cache_t {.importc,
    cdecl.}
proc leveldb_cache_destroy*(cache: ptr leveldb_cache_t) {.importc, cdecl.}
proc leveldb_create_default_env*(): ptr leveldb_env_t {.importc, cdecl.}
proc leveldb_env_destroy*(a1: ptr leveldb_env_t) {.importc, cdecl.}
proc leveldb_env_get_test_directory*(a1: ptr leveldb_env_t): cstring {.importc,
    cdecl.}
  ## ```
           ##   If not NULL, the returned buffer must be released using leveldb_free().
           ## ```
proc leveldb_free*(`ptr`: pointer) {.importc, cdecl.}
  ## ```
                                                     ##   Utility
                                                     ##      Calls free(ptr).
                                                     ##      REQUIRES: ptr was malloc()-ed and returned by one of the routines
                                                     ##      in this file.  Note that in certain cases (typically on Windows), you
                                                     ##      may need to call this routine instead of free(ptr) to dispose of
                                                     ##      malloc()-ed memory returned by this library.
                                                     ## ```
proc leveldb_major_version*(): cint {.importc, cdecl.}
  ## ```
                                                      ##   Return the major version number for this release.
                                                      ## ```
proc leveldb_minor_version*(): cint {.importc, cdecl.}
  ## ```
                                                      ##   Return the minor version number for this release.
                                                      ## ```
{.pop.}
