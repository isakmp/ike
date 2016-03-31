IKE
---

`common` contains utillities used by the other modules
 - Utils contains general useful utilities (no deps, everybody can use this)
 - Monad is the monadic control flow (no deps, used in parser and protocol handling)
 - C (the core definitions) contains high-level types (no deps)

`pfkey` contains the pfkeyv2 protocol (RFC2367 + policy extensions)
 - Pfkey_wire wire structs
 - Pfkey_coding decoding and encoding stuff
 - Pfkey_engine pfkey logic

`src` contains the IKEv2 (RFC7296) protocol
 - Packet contains enums from the standard (uses cstruct.ppx)
 - Decode contains stateless binary data to high-level type error (uses Packet, C, Control)
 - Encode contains stateless high-level type to binary data (uses Packet, C)
 - Crypto convenience functions for IKE crypto (uses nocrypto, C)
 - Config constructions for IKE configurations (uses C)
 - Control is the control socket (such as shutdown, more?) (uses C)
 - Engine the main processing pipeline (uses C, Decode, Encode, Crypto, Config) for a single IKE session
 - Dispatcher contains a set of IKE sessions (which influence each other, e.g. when `InitialContact is received by one) and coordinates what needs to be done for an incoming event (uses Engine)

`lwt` contains some side-effecting code

`helper` a C proxy of raw PF_KEY sockets to PF_INET SOCK_STREAM