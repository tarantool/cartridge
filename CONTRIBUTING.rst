:orphan:

================================================================================
Contributing
================================================================================

The workflow for Cartridge contributors is different from that for Cartridge
users. It implies building the project from source (documentation, Web UI)
and running tests.

--------------------------------------------------------------------------------
Submitting a pull request
--------------------------------------------------------------------------------

1. `Fork <https://github.com/tarantool/cartridge/fork>`_ and clone the repository.
2. `Build <#building-from-source>`_ it and `run <#running-a-demo-cluster>`_ it.
3. Make a change, add `tests <#running-tests>`_, and make sure they still pass.
4. Commit the changes and push them to your fork.
5. `Submit <https://github.com/tarantool/cartridge/compare>`_ a pull request.

Here are a few things you can do that will increase the likelihood of your pull
request being accepted:

- Describe *what* you do in the pull request description, and *why* you do it.
- Add an auto-test that covers your changes.
- Keep your change as focused as possible. One scope |--| one pull request.
- Write a `good commit message <https://chris.beams.io/posts/git-commit/>`_.

See other related resources:

- `How to Contribute to Open Source <https://opensource.guide/how-to-contribute/>`_
- `Using Pull Requests <https://help.github.com/articles/about-pull-requests/>`_
- `GitHub Help <https://help.github.com>`_

--------------------------------------------------------------------------------
Building from source
--------------------------------------------------------------------------------

The fastest way to build the project is to skip building the Web UI:

.. code-block:: bash

    CMAKE_DUMMY_WEBUI=true tarantoolctl rocks make

But if you want to build the frontend too, you'll also need
``nodejs`` >= 12 and ``npm`` >= 6, see instructions
`here <https://nodejs.org/en/download/package-manager/>`_.

Documentation is generated from source code, but only if the ``ldoc``
and ``sphinx`` tools are installed:

.. code-block:: bash

    pip install -r rst/requirements.txt
    tarantoolctl rocks install ldoc --server=https://tarantool.github.io/LDoc/
    tarantoolctl rocks make

--------------------------------------------------------------------------------
Running a demo cluster
--------------------------------------------------------------------------------

There are several example entry points which are mostly used for testing,
but can also be useful for demo purposes or experiments:

.. code-block:: bash

    cartridge start
    cartridge replicasets setup --bootstrap-vshard

    # or select a specific entry point
    # cartridge start --script ./test/entrypoint/srv_vshardless.lua

It can be accessed through the Web UI (http://localhost:8081)
or via the binary protocol:

.. code-block:: bash

    tarantoolctl connect admin@localhost:3301

    # or via console socket
    # tarantoolctl connect unix/:./tmp/run/cartridge.srv-1.control

If you also need the stateful failover mode, launch an external state provider
|--| ``stateboard``:

.. code-block:: bash

    cartridge start --stateboard

And set failover parameters according to ``instances.yml``. The defaults are:

* State provider URI: ``localhost:4401``;
* Password: ``qwerty``.

For more details about ``cartridge-cli``, see its
`usage <https://github.com/tarantool/cartridge-cli#usage>`_.

--------------------------------------------------------------------------------
Running tests
--------------------------------------------------------------------------------

.. code-block:: bash

    # Backend
    tarantoolctl rocks install luacheck
    tarantoolctl rocks install luatest 0.5.7
    .rocks/bin/luacheck .
    .rocks/bin/luatest -v

    # Frontend
    npm install cypress@7.7.0
    ./frontend-test.sh
    ./cypress-test.sh

    # Collect coverage
    tarantoolctl rocks install luacov
    tarantoolctl rocks install luacov-console
    .rocks/bin/luatest -v --coverage
    .rocks/bin/luacov-console `pwd`
    .rocks/bin/luacov-console -s

Find more about testing tools here:

- `luacheck <https://github.com/tarantool/luacheck/#luacheck>`_
- `luatest <https://github.com/tarantool/luatest#overview>`_
- `cypress <https://docs.cypress.io>`_

--------------------------------------------------------------------------------
Updating auto-generated sources
--------------------------------------------------------------------------------

If the GraphQL API is changed, the ``doc/schema.graphql`` should be updated:

.. code-block:: bash

    npm install graphql-cli@3.0.14
    ./fetch-schema.sh

If you face some issues with script run, e.g.
``doc/schema.graphql: No such file or directory``, try next:

.. code-block:: bash

    npm audit fix --force

If the UML diagrams at ``rst/uml`` are changed, corresponding images
should be updated. Install `PlantUML <https://plantuml.com/download>`_:

.. code-block:: bash

    sudo apt install plantuml
    # OR
    sudo brew install plantuml

And then just run the script:

.. code-block:: bash

    cmake -P rst/BuildUML.cmake

Cypress tests imply snapshot testing. It compares WebUI images visually.
In order to update reference snapshots, run:

.. code-block:: bash

    ./cypress-test.sh --env failOnSnapshotDiff=false

.. |--| unicode:: U+2013   .. en dash
.. |---| unicode:: U+2014  .. em dash, trimming surrounding whitespace
   :trim:
