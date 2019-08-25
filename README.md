# Tarantool framework for distributed applications development

### Building from source

To build and run cartridge you'll need development enviroment:

- Tarantool itself
- npm, nodejs
- python, pip (testing only)

To build frontend, say:

```sh
tarantoolctl rocks make
```

If you also wish to build API documentation:

```sh
tarantoolctl rocks install ldoc --server=http://rocks.moonscript.org
export PATH=.rocks/bin:$PATH
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
