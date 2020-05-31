# Wobscale IRC Config

This is the home of configuration and documentation related to the running of
the Wobscale IRC Network

## Example configuration

IRC Servers in the network are run and configured using [NixOS](https://nixos.org/).

This repository contains a nixos module which provides a set of options that
vary between servers on the network.

The module includes tls certificate creation and rotation, among other goodies.

[example-configuration.nix](./example-configuration.nix) contains a complete
and somewhat commented example of a `configuration.nix` using the module
provided in this repository.
