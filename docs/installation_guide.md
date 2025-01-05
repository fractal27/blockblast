# Installation guide

## From source

First, [install the Odin compiler](https://odin-lang.org/docs/install), then copy, compile and run the program with
```bash
$ git clone https://github.com/fractal27/blockblast.git
$ cd blockblast/game
$ odin build .
$ ./game
```
**NOTE**: for now, you cannot execute it onto another path, because the `path/to/assets` dir is hardcoded as a relative path to the current path, in future versions, when executing it will be possible to specify the `path/to/assets` dir. A temporary solution would be to go and change the `main` function, and provide a directory to the `init_state` function.



