RxOcaml: Reactive Extensions in OCaml
=====================================

**RxOcaml** is a library for composing asynchronous and event-based programs
using observable sequences. This library is an OCaml implementation of [Rx
Observables](https://rx.codeplex.com/).

Building rxocaml
------------------

<!-- TODO
### Getting started

The reccomended way to install this library is using
[OPAM](http://opam.ocaml.org/).

    $ opam install rxocaml
-->

### Requirements

You will need the following libraries:

* [OCaml](http://caml.inria.fr/ocaml/release.en.html) >= 4.01.0
* [Findlib](http://projects.camlcity.org/projects/findlib.html/) >= 1.2.7
* [Batteries](http://batteries.forge.ocamlcore.org/) >= 2.1.0
* [Lwt](http://ocsigen.org/lwt/) >= 2.4.2
* [OUnit](http://ounit.forge.ocamlcore.org/) >= 2.0.0 (to build and run the
  tests, optional)

### Configuration and installation

To build the library, run

    $ ocaml setup.ml -configure
    $ ocaml setup.ml -build

To install the library, run (as root, if your user doesn't have enough
privileges)

    $ ocaml setup.ml -install

To build and run the tests, execute

    $ ocaml setup.ml -configure --enable-tests
    $ ocaml setup.ml -build
    $ ocaml setup.ml -test

To generate the documentation, run

    $ ocaml setup.ml -doc

Then you can browse the HTML documentation starting from
`rxocaml.docdir/index.html`, but is not installed by default.

To uninstall anything that was previously installed, execute

    $ ocaml setup.ml -uninstall

### Further information

* [Reactive Extensions](http://msdn.microsoft.com/en-us/library/hh242985.aspx)
  on MSDN
* [RxJava](https://github.com/Netflix/RxJava) on github
* [Introduction to Rx](http://www.introtorx.com/) (an online book)

