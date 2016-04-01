IKEv2
=====

![Screenshot](http://berlin.ccc.de/~hannes/ike0.png)

The Internet Key Exchange is the protocol to setup security associations.  Those
are used by the kernel to sign and encrypt (depending on policy) IP frames to
peers (in transport or tunnel mode).  The IKE daemon supplies keying material
for the ESP/AH connections.

IKE communicates with the kernel via a raw PF_KEY socket (exchanging information
about security policies, traffic selectors, and security associations (SA) - the
kernel can ask the IKE daemon to establish SAs if there's a policy but no SA).
Also, the kernel signals soft and hard resource limits (time, bytes) on a SA,
the IKE daemon then needs to do rekeying on that SA.  NAT traversal is handled
somehow as well.

IKE also communicates via UDP (port 500) to remote IKE daemons to establish IKE
sessions and negotiate SAs.

Two more communication channels are a control interface (for the user) to
dynamically adjust selectors (not entirely sure about this!?), and a timer
(mainly for retransmissions).


This package will provide at some point in the future IKEv2 and PFKEY_V2, using
the coarse structure (see `_tags` for up-to-date information):

`common` contains utillities used by the other modules (compiles)
 - Utils contains general useful utilities
 - Monad is the monadic control flow
 - C (the core definitions) contains high-level types

`pfkey` contains the PFKEYv2 protocol (RFC2367 + policy extensions) (compiles)
 - Pfkey_wire wire structs
 - Pfkey_coding decoding and encoding stuff
 - Pfkey_engine pfkey logic

`src` contains the IKEv2 (RFC7296) protocol (Dispatcher compiles, rest needs work, likely redesign)
 - Packet contains enums from the standard (uses cstruct.ppx)
 - Decode contains stateless binary data to high-level type error (uses Packet, C, Control)
 - Encode contains stateless high-level type to binary data (uses Packet, C)
 - Crypto convenience functions for IKE crypto (uses nocrypto, C)
 - Config constructions for IKE configurations (uses C)
 - Control is the control socket (such as shutdown, more?) (uses C)
 - Engine the main processing pipeline (uses C, Decode, Encode, Crypto, Config) for a single IKE session
 - Dispatcher contains a set of IKE sessions (which influence each other, e.g. when `InitialContact is received by one) and coordinates what needs to be done for an incoming event (uses Engine)

`lwt` contains some side-effecting code (currently compiles some testing code for PF_KEY)

`helper` a C proxy of raw PF_KEY sockets to PF_INET SOCK_STREAM (compiles, is finished)

`tests` should be there at some point
