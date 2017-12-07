# commandline-tools

A little repo for any commandline tools we wish to share with each other.
Please feel free to add.
On a mac, you can install the tools using homebrew...see [github.com/ndlib/homebrew-dlt](https://github.com/ndlib/homebrew-dlt).

## To Install

These commands are made available via homebrew:

```console
$ brew install ndlib/dlt/commandline-tools
```

Or clone the repository and include the `./bin/` in your `$PATH`.

## Shell Commands

* [tag-build.sh](./bin/tag-build.sh) - using next-build-identifier.sh, create a tag and push that tag upstream.
* [next-build-identifier.sh](./bin/next-build-identifier.sh) - determine the next build identifier. This is an idempotent script.
* [build-pull-request-message](./bin/build-pull-request-message) - leverage your commit messages to build your pull request message.
* [search_in_bundle](./bin/search_in_bundle) - search (via ag or grep) your current directory and associated bundle path
