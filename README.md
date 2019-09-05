[![pipeline status](https://gitlab.com/tarantool/cartridge/badges/master/pipeline.svg)](https://gitlab.com/tarantool/cartridge/commits/master)

# Tarantool framework for distributed applications development

### Getting started

If you want to run an example you better take a look at [Cartridge CLI](https://github.com/tarantool/cartridge-сli)

### Installing

Prerequisites:

- tarantool, tarantool-dev ([instructions](https://www.tarantool.io/en/download/?v=1.10))
- git, gcc, cmake

```sh
tarantoolctl rocks install cartridge
```

### Building from source

To build and test cartridge locally you'll also need the following:

- nodejs >= 8 ([instructions](https://github.com/nodesource/distributions))
- npm >= 6
- python, pip

To build frontend, say:

```sh
tarantoolctl rocks make
```

If you also wish to build API documentation:

```sh
tarantoolctl rocks install ldoc --server=http://rocks.moonscript.org
export PATH=$PWD/.rocks/bin:$PATH
tarantoolctl rocks make BUILD_DOC=YES
```

### Running tests

First, install testing dependencies:

```sh
pip install -r test/integration/requirements.txt
tarantoolctl rocks install luacheck
tarantoolctl rocks install luacov
tarantoolctl rocks install luacov-console
tarantoolctl rocks install luatest
```

Then run tests:

```sh
pytest -v
./run-test.sh
```
