# checksum.sh

Checksum files and directories.

Script util to check files integrity per folders.


### How does it works

When started with option   **-U**   **--update**   
it will create -or- update a table of contents.
```
./checksum.sh -U -T trivial,tpce,trv0,trv1 ./MyFolder
```

It can also be used for incremental update with sub-folders.
```
./checksum.sh -U ./MyFolder/SubFolder
```

When started with option   **-C**   **--check**   
it does a whole -or- incremental files integrity check.
```
./checksum.sh -C "./MyFolder/Yet * Another * Sub * Folder"
```

Generated hash table file is CommaSeparatedValue
with entries relative to the base folder path (eg. /drive/MyFolder/), in a format like this:

* _relative path, file name, last modified time ISO-8601, MD5 hash_

  _./SubFolder,file.trivial,1970-01-01T00:00:01+0000,7f138a09169b250e9dcb378140907378_


```
./checksum.sh -C -H checksum_File_CSV.check -B MyFolder ./MyFolder/SubFolder
```

### Usage
```
./checksum.sh [-U | -C] [-H [...]] [-B [...]] [-T (,[...])] [--log] [-V] [folder]

./checksum.sh [--update | --check] [--hash-file [...]] [--base-folder [...]] [--file-types (,[...])] [--log] [--verbose] [folder]

```
 

**bash checksum.sh [OPTIONS]... [FOLDER]**

| Option                      | Description                                         |
| --------------------------- | --------------------------------------------------- |
| **-U**   **--update**       | Update the hash table, entire -or- per folder.      |
| **-C**   **--check**        | Integrity check, entire -or- per folder.            |
| **-H**   **--hash-file**    | Hash table file to use.                             |
|                             | Default: checksum.check                             |
| **-B**   **--base-folder**  | Base folder.                                        |
|                             | Default: .                                          |
| **-T**   **--file-types**   | What file types to check, by their file extension.  |
|                             | Default: *   (accepts comma separated values)       |
| **--force**                 | Force update without diff -or- check using diff.    |
| **--log**                   | Write to a log file.                                |
| **-V**   **--verbose**      | Output more information.                            |
| **-v**   **--version**      | Output version information.                         |
| **-h**   **--help**         | Display this help and exit.                         |

 

###### The script should has right execution permission ”#$ chmod +x checksum.sh”

> To use with a reasonable amount of data: external drive, SD card and folders.

> In a case use with a huge amount of data, this is might not be the right approach, 
> because this script could lead to high memory consumption and it not supports 
> parallelization out of the box, nor threading, resulting too slow.
> For example with an entire hard disk as base folder, it can create big CSV file 
> and will be read line by line, doing multiple replacement or large strings comparison, 
> and finally written, make sure you have enough memory before operating.

> Also write to log is disabled by default, for less file I/O concurrency to disk.

Tested in bash, on darwin and linux environments with around 30 GB of data in nearest 1 ☕️ time.


## License

[MIT License](LICENSE).

