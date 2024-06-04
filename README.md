# xchain-helpers

This repository three tools for use with multi-chain development. Domains refer to blockchains which are connected by bridges. Domains may have multiple bridges connecting them, for example both the Optimism Native Bridge and Circle CCTP connect Ethereum and Optimism domains.

## Forwarders

These libraries provide standardized syntax for sending a message to a bridge.

## Receivers

The most common pattern is to have an authorized contract forward a message to another "business logic" contract to abstract away bridge dependencies. Receivers are contracts which perform this generic translation - decoding the bridge-specific message and forwarding to another `target` contract. The `target` contract should have logic to restrict who can call it and permission this to one or more bridge receivers.

TODO diagram

## E2E Testing Infrastructure

Provides tooling to record messages sent to supported bridges and relay them on the other side simulating a real message going across.

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*
