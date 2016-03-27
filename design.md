IKE
---

Utils contains general useful utilities (no deps, everybody can use this)

Monad is the monadic control flow (no deps, used in parser and protocol handling)

C (the core definitions) contains high-level types (no deps)

Packet contains enums from the standard (uses cstruct.ppx)

Decode contains stateless binary data to high-level type error (uses Packet, C, Control)
Encode contains stateless high-level type to binary data (uses Packet, C)

Crypto convenience functions for IKE crypto (uses nocrypto, C)

Config constructions for IKE configurations (uses C)

Control is the control socket (such as shutdown, more?) (uses C)

Engine the main processing pipeline (uses C, Decode, Encode, Crypto, Config) for a single IKE session

Dispatcher contains a set of IKE sessions (which influence each other, e.g. when `InitialContact is received by one) and coordinates what needs to be done for an incoming event (uses Engine)

Pfkey contains the pfkey protocol (RFC 2367 + SPD) (uses C)
