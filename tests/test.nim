import unittest, options, os, osproc, sequtils, strutils
import leveldbstatic as leveldb
import leveldbstatic/raw

const
  tmpDir = getTempDir() / "testleveldb"
  tmpNimbleDir = tmpDir / "nimble"
  tmpDbDir = tmpDir / "testdb"

template cd*(dir: string, body: untyped) =
  ## Sets the current dir to ``dir``, executes ``body`` and restores the
  ## previous working dir.
  block:
    let lastDir = getCurrentDir()
    setCurrentDir(dir)
    body
    setCurrentDir(lastDir)

proc execNimble(args: varargs[string]): tuple[output: string, exitCode: int] =
  var quotedArgs = @args
  quotedArgs.insert("-y")
  quotedArgs.insert("--nimbleDir:" & tmpNimbleDir)
  quotedArgs.insert("nimble")
  quotedArgs = quotedArgs.map(proc (x: string): string = "\"" & x & "\"")

  let cmd = quotedArgs.join(" ")
  result = execCmdEx(cmd)
  checkpoint(cmd)
  checkpoint(result.output)

proc execTool(args: varargs[string]): tuple[output: string, exitCode: int] =
  var quotedArgs = @args
  quotedArgs.insert(tmpDbDir)
  quotedArgs.insert("--database")
  quotedArgs.insert(findExe(tmpNimbleDir / "bin" / "leveldbtool"))
  quotedArgs = quotedArgs.map(proc (x: string): string = "\"" & x & "\"")

  if not dirExists(tmpDbDir):
    createDir(tmpDbDir)

  let cmd = quotedArgs.join(" ")
  result = execCmdEx(cmd)
  checkpoint(cmd)
  checkpoint(result.output)

suite "leveldb":
  setup:
    let env = leveldb_create_default_env()
    let dbName = $(leveldb_env_get_test_directory(env))
    let db = leveldb.open(dbName)

  teardown:
    db.close()
    removeDb(dbName)

  test "version":
    let (major, minor) = getLibVersion()
    check(major > 0)
    check(minor > 0)

  test "get nothing":
    check(db.get("nothing") == none(string))

  test "put and get":
    db.put("hello", "world")
    check(db.get("hello") == some("world"))

  test "get or default":
    check(db.getOrDefault("nothing", "yes") == "yes")

  test "delete":
    db.put("hello", "world")
    db.delete("hello")
    check(db.get("hello") == none(string))

  test "get value with 0x00":
    db.put("\0key", "\0ff")
    check(db.get("\0key") == some("\0ff"))

  test "get empty value":
    db.put("a", "")
    check(db.get("a") == some(""))

  test "get empty key":
    db.put("", "a")
    check(db.get("") == some("a"))

  proc initData(db: LevelDb) =
    db.put("aa", "1")
    db.put("ba", "2")
    db.put("bb", "3")

  test "iter":
    initData(db)
    check(toSeq(db.iter()) == @[("aa", "1"), ("ba", "2"), ("bb", "3")])

  test "iter reverse":
    initData(db)
    check(toSeq(db.iter(reverse = true)) ==
          @[("bb", "3"), ("ba", "2"), ("aa", "1")])

  test "iter seek":
    initData(db)
    check(toSeq(db.iter(seek = "ab")) ==
          @[("ba", "2"), ("bb", "3")])

  test "iter seek reverse":
    initData(db)
    check(toSeq(db.iter(seek = "ab", reverse = true)) ==
          @[("ba", "2"), ("aa", "1")])

  test "iter prefix":
    initData(db)
    check(toSeq(db.iterPrefix(prefix = "b")) ==
          @[("ba", "2"), ("bb", "3")])

  test "iter range":
    initData(db)
    check(toSeq(db.iterRange(start = "a", limit = "ba")) ==
          @[("aa", "1"), ("ba", "2")])

  test "iter range reverse":
    initData(db)
    check(toSeq(db.iterRange(start = "bb", limit = "b")) ==
          @[("bb", "3"), ("ba", "2")])

  test "iter with 0x00":
    db.put("\0z1", "\0ff")
    db.put("z2\0", "ff\0")
    check(toSeq(db.iter()) == @[("\0z1", "\0ff"), ("z2\0", "ff\0")])

  test "iter empty value":
    db.put("a", "")
    check(toSeq(db.iter()) == @[("a", "")])

  test "iter empty key":
    db.put("", "a")
    check(toSeq(db.iter()) == @[("", "a")])

  test "repair database":
    initData(db)
    db.close()
    repairDb(dbName)

  test "batch":
    db.put("a", "1")
    db.put("b", "2")
    let batch = newBatch()
    batch.put("a", "10")
    batch.put("c", "30")
    batch.delete("b")
    db.write(batch)
    check(toSeq(db.iter()) == @[("a", "10"), ("c", "30")])

  test "batch append":
    let batch = newBatch()
    let batch2 = newBatch()
    batch.put("a", "1")
    batch2.put("b", "2")
    batch2.delete("a")
    batch.append(batch2)
    db.write(batch)
    check(toSeq(db.iter()) == @[("b", "2")])

  test "batch clear":
    let batch = newBatch()
    batch.put("a", "1")
    batch.clear()
    batch.put("b", "2")
    db.write(batch)
    check(toSeq(db.iter()) == @[("b", "2")])

  test "open with cache":
    let ldb = leveldb.open(dbName & "-cache", cacheCapacity = 100000)
    defer:
      ldb.close()
      removeDb(ldb.path)
    ldb.put("a", "1")
    check(toSeq(ldb.iter()) == @[("a", "1")])

  test "open but no create":
    expect LevelDbException:
      let failed = leveldb.open(dbName & "-nocreate", create = false)
      defer:
        failed.close()
        removeDb(failed.path)

  test "open but no reuse":
    let old = leveldb.open(dbName & "-noreuse", reuse = true)
    defer:
      old.close()
      removeDb(old.path)

    expect LevelDbException:
      let failed = leveldb.open(old.path, reuse = false)
      defer:
        failed.close()
        removeDb(failed.path)

  test "no compress":
    db.close()
    let nc = leveldb.open(dbName, compressionType = ctNoCompression)
    defer: nc.close()
    nc.put("a", "1")
    check(toSeq(nc.iter()) == @[("a", "1")])

suite "leveldb queryIter":
  setup:
    let env = leveldb_create_default_env()
    let dbName = $(leveldb_env_get_test_directory(env))
    let db = leveldb.open(dbName)
    let
      k1 = "k1"
      k2 = "k2"
      k3 = "l3"
      v1 = "v1"
      v2 = "v2"
      v3 = "v3"
      empty = ("", "")

    db.put(k1, v1)
    db.put(k2, v2)
    db.put(k3, v3)

  teardown:
    db.close()
    removeDb(dbName)

  test "iterates all keys and values":
    let iter = db.queryIter()
    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
      iter.next() == (k3, v3)
      not iter.finished
      iter.next() == empty
      iter.finished
    
  test "iterate until disposed":
    let iter = db.queryIter()
    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
    
    iter.dispose()

    check:
      iter.finished
      iter.next() == empty
      iter.finished

  test "iterator is disposed when it goes out of scope":
    when defined(gcOrc) or defined(gcArc):
      block:
        let iter = db.queryIter()
        discard iter.next()
      db.close() # crashes if iterator not disposed
    else:
      skip()

  test "skip":
    let iter = db.queryIter(skip = 1)
    check:
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
      iter.next() == (k3, v3)
      not iter.finished
      iter.next() == empty
      iter.finished

  test "limit":
    let iter = db.queryIter(limit = 2)
    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
      iter.next() == empty
      iter.finished

  test "iterates only keys":
    let iter = db.queryIter(keysOnly = true)
    check:
      not iter.finished
      iter.next() == (k1, "")
      not iter.finished
      iter.next() == (k2, "")
      not iter.finished
      iter.next() == (k3, "")
      not iter.finished
      iter.next() == empty
      iter.finished

  test "iterates only 'k', both keys and values":
    let iter = db.queryIter(prefix = "k")
    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
      iter.next() == empty
      iter.finished

  test "iterates only 'k', skip":
    let iter = db.queryIter(prefix = "k", skip = 1)
    check:
      not iter.finished
      iter.next() == (k2, v2)
      not iter.finished
      iter.next() == empty
      iter.finished

  test "iterate only 'k', limit":
    let iter = db.queryIter(prefix = "k", limit = 1)
    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == empty
      iter.finished

  test "iterates only 'k', only keys":
    let iter = db.queryIter(prefix = "k", keysOnly = true)
    check:
      not iter.finished
      iter.next() == (k1, "")
      not iter.finished
      iter.next() == (k2, "")
      not iter.finished
      iter.next() == empty
      iter.finished

  test "concurrent iterators - 1":
    let
      iter1 = db.queryIter()
      iter2 = db.queryIter()

    check:
      # 1, then 2
      not iter1.finished
      iter1.next() == (k1, v1)

      not iter2.finished
      iter2.next() == (k1, v1)

      # 1, 1, then 2, 2
      not iter1.finished
      iter1.next() == (k2, v2)
      not iter1.finished
      iter1.next() == (k3, v3)

      not iter2.finished
      iter2.next() == (k2, v2)
      not iter2.finished
      iter2.next() == (k3, v3)

      # finish 1, then finish 2
      not iter1.finished
      iter1.next() == empty

      not iter2.finished
      iter2.next() == empty

      iter1.finished
      iter2.finished

  test "concurrent iterators - 2":
    let
      iter1 = db.queryIter()
      iter2 = db.queryIter()

    check:
      # 1, then 2
      not iter1.finished
      iter1.next() == (k1, v1)

      not iter2.finished
      iter2.next() == (k1, v1)

      # finish 1
      not iter1.finished
      iter1.next() == (k2, v2)
      not iter1.finished
      iter1.next() == (k3, v3)
      not iter1.finished
      iter1.next() == empty
      iter1.finished

      # finish 2
      not iter2.finished
      iter2.next() == (k2, v2)
      not iter2.finished
      iter2.next() == (k3, v3)
      not iter2.finished
      iter2.next() == empty
      iter2.finished

  test "concurrent iterators - dispose":
    let
      iter1 = db.queryIter()
      iter2 = db.queryIter()

    check:
      # 1, then 2
      not iter1.finished
      iter1.next() == (k1, v1)

      not iter2.finished
      iter2.next() == (k1, v1)

    # dispose 1
    iter1.dispose()

    check:
      iter1.finished
      iter1.next() == empty
      iter1.finished

      # finish 2
      not iter2.finished
      iter2.next() == (k2, v2)
      not iter2.finished
      iter2.next() == (k3, v3)
      not iter2.finished
      iter2.next() == empty
      iter2.finished

  test "modify while iterating":
    let
      iter = db.queryIter()

    check:
      not iter.finished
      iter.next() == (k1, v1)
      not iter.finished
      iter.next() == (k2, v2)

    # insert
    let
      k4 = "k4"
      v4 = "v4"
    db.put(k4, v4)

    check:
      not iter.finished
      iter.next() == (k3, v3)
      not iter.finished
      iter.next() == empty
      iter.finished

suite "package":
  setup:
    removeDir(tmpDir)

  test "import as package":
    let (output, exitCode) = execNimble("install")
    check exitCode == QuitSuccess

    cd "tests"/"packagetest":
      var (output, exitCode) = execNimble("build")
      check exitCode == QuitSuccess

      (output, exitCode) = execCmdEx("./packagetest")
      checkpoint output
      check exitCode == QuitSuccess
      check output.contains("leveldb works.")

suite "tool":
  setup:
    removeDir(tmpDir)

  test "leveldb tool":
    var (output, exitCode) = execNimble("install")
    check exitCode == QuitSuccess
    check output.contains("Building")

    check execTool("-v").exitCode == QuitSuccess
    check execTool("create").exitCode == QuitSuccess
    check execTool("list").exitCode == QuitSuccess

    check execTool("put", "hello", "world").exitCode == QuitSuccess
    (output, exitCode) = execTool("get", "hello")
    check exitCode == QuitSuccess
    check output == "world\L"
    (output, exitCode) = execTool("list")
    check exitCode == QuitSuccess
    check output == "hello world\L"

    check execTool("delete", "hello").exitCode == QuitSuccess
    (output, exitCode) = execTool("get", "hello")
    check exitCode == QuitSuccess
    check output == ""
    (output, exitCode) = execTool("list")
    check exitCode == QuitSuccess
    check output == ""

    check execTool("put", "hello", "6130", "-x").exitCode == QuitSuccess
    check execTool("get", "hello", "-x").output == "6130\L"
    check execTool("get", "hello").output == "a0\L"
    check execTool("list", "-x").output == "hello 6130\L"
    check execTool("put", "hello", "0061", "-x").exitCode == QuitSuccess
    check execTool("get", "hello", "-x").output == "0061\L"
    check execTool("delete", "hello").exitCode == QuitSuccess
