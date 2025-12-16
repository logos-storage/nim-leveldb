# leveldb.nim

A self-contained LevelDB wrapper for Nim in a Nim friendly way. Uses git-submodule and nimterop so that no external libraries have to be installed or linked.

Original nim LevelDB wrapper: [HERE](https://github.com/zielmicha/leveldb.nim)

Replacing of system library dependency with self-contained C/CPP interoperability by (Logos Storage)[https://codex.storage]

## Usage

Create a database:
```Nim
   import leveldbstatic
   import options

   var db = leveldb.open("/tmp/mydata")
```

Read or modify the database content:
```Nim
   assert db.getOrDefault("nothing", "") == ""

   db.put("hello", "world")
   db.put("bin", "GIF89a\1\0")
   echo db.get("hello")
   assert db.get("hello").isSome()

   var key, val = ""
   for key, val in db.iter():
     echo key, ": ", repr(val)

   db.delete("hello")
   assert db.get("hello").isNone()
```

Batch writes:
```Nim
   let batch = newBatch()
   for i in 1..10:
     batch.put("key" & $i, $i)
   batch.delete("bin")
   db.write(batch)
```

Iterate over subset of database content:
```Nim
   for key, val in db.iterPrefix(prefix = "key1"):
     echo key, ": ", val
   for key, val in db.iter(seek = "key3", reverse = true):
     echo key, ": ", val

   db.close()
```

## Compiling with optimizations

CMake is used during compilation to determine which of the following optimization options are enabled. You can set the following nim compiler flags to 0 or 1 to override them:
 - fdatasync from <unistd.h> `--passC:-DHAVE_FDATASYNC=1`
 - F_FULLSYNC from <fcntl.h> `--passC:-DHAVE_FULLFSYNC=1`
 - O_CLOEXEC from <fcntl.h> `--passC:-DHAVE_O_CLOEXEC=1`
 - crc32c from <crc32c/crc32c.h> `--passC:-DHAVE_CRC32C=1`
 - snappy from <snappy.h> `--passC:-DHAVE_SNAPPY=1`
 - zstd from <zstd.h> `--passC:-DHAVE_ZSTD=1`

## Updating

When you want to update this library to a new version of LevelDB, follow these steps:
- Update LevelDB submodule to new version.
- Run 'build.sh'.
- Run 'nimble build' and 'nimble test'.
- Make sure everything's working.
- Increment version of this library in 'leveldbstatic.nimble'.
- Commit the changes.
- Tag the commit with the new version number.
- Push.
