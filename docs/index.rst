Curassow
========

Curassow is a Swift Nest_ HTTP Server. It uses the pre-fork worker model
and it's similar to Python's Gunicorn and Ruby's Unicorn.

.. _Nest: https://github.com/nestproject/Nest

It exposes a Nest-compatible interface for your application, allowing
you to use Curassow with any Nest compatible web frameworks of your choice.

Quick Start
-----------

To use Curassow, you will need to install it via the Swift Package Manager,
you can add it to the list of dependencies in your `Package.swift`:

.. code-block:: swift

    import PackageDescription


    let package = Package(
      name: "HelloWorld",
      dependencies: [
        .Package(url: "https://github.com/kylef/Curassow.git", majorVersion: 0, minor: 4),
      ]
    )

Afterwards you can place your web application implementation in `Sources`
and add the runner inside `main.swift` which exposes a command line tool to
run your web application:

.. code-block:: swift

    import Curassow
    import Inquiline


    serve { request in
      return Response(.Ok, contentType: "text/plain", body: "Hello World")
    }

Then build and run your application:

.. code-block:: shell

    $ swift build --configuration release
    $ ./.build/release/HelloWorld

Check out the `Hello World example <https://github.com/kylef/Curassow-example-helloworld>`_ application.

Contents
--------

.. toctree::
   :maxdepth: 2

   configuration
   signal-handling
   deployment
   architecture
