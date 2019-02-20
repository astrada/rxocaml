RxOcaml: Reactive Extensions in OCaml
=====================================

**RxOcaml** is a library for composing asynchronous and event-based programs
using observable sequences. This library is an OCaml implementation of [Rx
Observables](http://reactivex.io/).

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

* [OCaml](http://caml.inria.fr/ocaml/release.en.html) >= 4.02.0
* [dune](https://dune.build/) >= 1.1.0
* [Batteries](http://batteries.forge.ocamlcore.org/) >= 2.1.0
* [Lwt](http://ocsigen.org/lwt/) >= 2.4.2
* [OUnit](http://ounit.forge.ocamlcore.org/) >= 2.0.0 (to build and run the
  tests, optional)
* [odoc](https://github.com/ocaml/odoc) >= 1.0.0 (to build the documentation,
  optional)

### Configuration and installation

To build the library, run:

    $ make

To install the library, run (as root, if your user doesn't have enough
privileges):

    $ make install

To build and run the tests, run:

    $ make test

To generate the documentation, run:

    $ make doc

Then you can browse the HTML documentation starting from
`_build/default/_doc/_html/`, but it's not installed by default.

To uninstall anything that was previously installed, run:

    $ make uninstall

### Further information

* [Reactive Extensions](http://msdn.microsoft.com/en-us/library/hh242985.aspx)
  on MSDN
* [RxJava](https://github.com/Netflix/RxJava) on github
* [Introduction to Rx](http://www.introtorx.com/) (an online book)

