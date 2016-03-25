IKE
---

Utils contains general useful utilities (no deps, everybody can use this)

Control is the monadic control flow (no deps)

C (the core definitions) contains high-level types (no deps)

Packet contains enums from the standard (cstruct.ppx)

Decode contains stateless binary data to high-level type error (Packet, C, Control)
Encode contains stateless high-level type to binary data (Packet, C)

Crypto convenience functions for IKE crypto (nocrypto, C)

Config (programmatic) constructions for IKE configurations (C)

Engine the main processing pipeline (C, Decode, Encode, Crypto, Config)
