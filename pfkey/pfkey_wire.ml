let pf_key_v2 = 2
and pfkeyv2_revision = 199806L

[%%cenum
type message_type =
  | MSG_RESERVED [@id 0]
  | GETSPI       [@id 1]
  | UPDATE       [@id 2]
  | ADD          [@id 3]
  | DELETE       [@id 4]
  | GET          [@id 5]
  | ACQUIRE      [@id 6]
  | REGISTER     [@id 7]
  | EXPIRE       [@id 8]
  | FLUSH        [@id 9]
  | DUMP         [@id 10]
  | PROMISC      [@id 11]
  | PCHANGE      [@id 12]
  | SPDUPDATE    [@id 13]
  | SPDADD       [@id 14]
  | SPDDELETE    [@id 15] (* by policy index *)
  | SPDGET       [@id 16]
  | SPDACQUIRE   [@id 17]
  | SPDDUMP      [@id 18]
  | SPDFLUSH     [@id 19]
  | SPDSETIDX    [@id 20]
  | SPDEXPIRE    [@id 21]
  | SPDDELETE2   [@id 22] (* by policy id *)
  [@@uint8_t] [@@sexp]]

[%%cstruct
type message = {
  version : uint8_t ;
  msg_type : uint8_t ;
  errno : uint8_t ;
  satype : uint8_t ;
  len : uint16_t ;
  reserved : uint16_t ;
  seq : uint32_t ;
  pid : uint32_t ;
} [@@little_endian]]

[%%cstruct
type ext = {
  len : uint16_t ;
  ext_type : uint16_t ;
} [@@little_endian]]

[%%cstruct
type sa = {
  len : uint16_t ;
  ext_type : uint16_t ;
  spi : uint32_t ; (* big endian! *)
  replay : uint8_t ;
  state : uint8_t ;
  auth : uint8_t ;
  encrypt : uint8_t ;
  flags : uint32_t ;
} [@@little_endian]]

[%%cstruct
type lifetime = {
  len : uint16_t ;
  ext_type : uint16_t ;
  allocations : uint32_t ;
  bytes : uint64_t ;
  addtime : uint64_t ;
  usetime : uint64_t ;
} [@@little_endian]]

[%%cstruct
type address = {
  len : uint16_t ;
  ext_type : uint16_t ;
  proto : uint8_t ;
  prefixlen : uint8_t ;
  reserved : uint16_t ;
} [@@little_endian]]

[%%cstruct
type key = {
  len : uint16_t ;
  ext_type : uint16_t ;
  key_bits : uint16_t ;
  reserved : uint16_t ;
} [@@little_endian]]

[%%cstruct
type ident = {
  len : uint16_t ;
  ext_type : uint16_t ;
  ident_type : uint16_t ;
  reserved : uint16_t ;
  id : uint64_t ;
} [@@little_endian]]

[%%cstruct
type sens = {
  len : uint16_t ;
  ext_type : uint16_t ;
  dpd : uint32_t ;
  level : uint8_t ;
  sense_len : uint8_t ;
  integ_level : uint8_t ;
  integ_len : uint8_t ;
  reserved : uint32_t ;
} [@@little_endian]]

[%%cstruct
type prop = {
  len : uint16_t ;
  ext_type : uint16_t ;
  replay : uint8_t ;
  reserved : uint8_t [@len 3] ;
} [@@little_endian]]

[%%cstruct
type comb = {
  auth : uint8_t ;
  encrypt : uint8_t ;
  flags : uint16_t ;
  minbits : uint16_t ;
  maxbits : uint16_t ;
  encrypt_minbits : uint16_t ;
  encrypt_maxbits : uint16_t ;
  reserved : uint32_t ;
  soft_allocations : uint32_t ;
  hard_allocations : uint32_t ;
  soft_bytes : uint64_t ;
  hard_bytes : uint64_t ;
  soft_addtime : uint64_t ;
  hard_addtime : uint64_t ;
  soft_usetime : uint64_t ;
  hard_usetime : uint64_t ;
} [@@little_endian]]

[%%cstruct
type supported = {
  len : uint16_t ;
  ext_type : uint16_t ;
  reserved : uint32_t ;
} [@@little_endian]]

[%%cstruct
type alg = {
  id : uint8_t ;
  ivlen : uint8_t ;
  minbits : uint16_t ;
  maxbits : uint16_t ;
  reserved : uint16_t ;
} [@@little_endian]]

[%%cstruct
type spirange = {
  len : uint16_t ;
  ext_type : uint16_t ;
  min : uint32_t ;
  max : uint32_t ;
  reserved : uint32_t ;
} [@@little_endian]]

[%%cstruct
type kmprivate = {
  len : uint16_t ;
  ext_type : uint16_t ;
  reserved : uint32_t ;
} [@@little_endian]]

(*
 * XXX Additional SA Extension.
 * mode: tunnel or transport
 * reqid: to make SA unique nevertheless the address pair of SA are same.
 *        Mainly it's for VPN.
 *)
[%%cstruct
type sa2 = {
  len : uint16_t ;
  ext_type : uint16_t ;
  mode : uint8_t ;
  reserved : uint8_t [@len 3] ;
  sequence : uint32_t ; (* lowermost 32bit of sequence number *)
  reqid : uint32_t ;
} [@@little_endian]]

(* XXX Policy Extension *)
[%%cstruct
type policy = {
  len : uint16_t ;
  ext_type : uint16_t ;
  policy_type : uint16_t ; (* See policy type of ipsec.h *)
  direction : uint8_t ;    (* See ipsec.h *)
  reserved : uint8_t ;
  id : uint32_t ;
  priority : uint32_t ;
} [@@little_endian]]

(*
 * When policy_type == IPSEC, it is followed by some of
 * the ipsec policy request.
 * [total length of ipsec policy requests]
 *	= (sadb_x_policy_len * sizeof(uint64_t) - sizeof(struct sadb_x_policy))
 *)

(* XXX IPsec Policy Request Extension *)
[%%cstruct
type ipsecrequest = {
  len : uint16_t ;
  proto : uint16_t ; (* See ipsec.h *)
  mode : uint8_t ;   (* See IPSEC_MODE_XX in ipsec.h. *)
  level : uint8_t ;  (* See IPSEC_LEVEL_XX in ipsec.h *)
  reqid : uint16_t ; (* See ipsec.h *)

  (*
   * followed by source IP address of SA, and immediately followed by
   * destination IP address of SA.  These encoded into two of sockaddr
   * structure without any padding.  Must set each sa_len exactly.
   * Each of length of the sockaddr structure are not aligned to 64bits,
   * but sum of x_request and addresses is aligned to 64bits.
   *)
} [@@little_endian]]

(* NAT-Traversal type, see RFC 3948 (and drafts). *)
[%%cstruct
type nat_t_type = {
  len : uint16_t ;
  ext_type : uint16_t ;
  nat_type : uint8_t ;
  reserved : uint8_t [@len 3] ;
} [@@little_endian]]

(* NAT-Traversal source or destination port. *)
[%%cstruct
type nat_t_port = {
  len : uint16_t ;
  ext_type : uint16_t ;
  port : uint16_t ;
  reserved : uint16_t ;
} [@@little_endian]]

(* ESP fragmentation size. *)
[%%cstruct
type nat_t_frag = {
  len : uint16_t ;
  ext_type : uint16_t ;
  fraglen : uint16_t ;
  reserved : uint16_t ;
} [@@little_endian]]

[%%cenum
type extension_type =
  | EXT_RESERVED       [@id 0]
  | SA                 [@id 1]
  | LIFETIME_CURRENT   [@id 2]
  | LIFETIME_HARD      [@id 3]
  | LIFETIME_SOFT      [@id 4]
  | ADDRESS_SRC        [@id 5]
  | ADDRESS_DST        [@id 6]
  | ADDRESS_PROXY      [@id 7]
  | KEY_AUTH           [@id 8]
  | KEY_ENCRYPT        [@id 9]
  | IDENTITY_SRC       [@id 10]
  | IDENTITY_DST       [@id 11]
  | SENSITIVITY        [@id 12]
  | PROPOSAL           [@id 13]
  | SUPPORTED_AUTH     [@id 14]
  | SUPPORTED_ENCRYPT  [@id 15]
  | SPIRANGE           [@id 16]
  | KMPRIVATE          [@id 17]
  | POLICY             [@id 18]
  | SA2                [@id 19]
  | NAT_T_TYPE         [@id 20]
  | NAT_T_SPORT        [@id 21]
  | NAT_T_DPORT        [@id 22]
(*  | NAT_T_OA           [@id 23] Deprecated. *)
  | NAT_T_OAI          [@id 23] (* Peer's NAT_OA for src of SA. *)
  | NAT_T_OAR          [@id 24] (* Peer's NAT_OA for dst of SA. *)
  | NAT_T_FRAG         [@id 25] (* Manual MTU override. *)
  [@@uint16_t] [@@sexp]]

[%%cenum
type satype =
  | UNSPEC              [@id 0]
  | AH                  [@id 2]
  | ESP                 [@id 3]
  | RSVP                [@id 5]
  | OSPFV2              [@id 6]
  | RIPV2               [@id 7]
  | MIP                 [@id 8]
  | IPCOMP              [@id 9]
  | OBSOLETE_POLICY     [@id 10] (* obsolete, do not reuse *)
  | TCPSIGNATURE        [@id 11]
  [@@uint8_t] [@@sexp]]

[%%cenum
type sastate =
  | LARVAL   [@id 0]
  | MATURE   [@id 1]
  | DYING    [@id 2]
  | DEAD     [@id 3]
  [@@uint8_t] [@@sexp]]


[%%cenum
type saflags =
  | SAFLAGS_PFS      [@id 1]
  [@@uint8_t] [@@sexp]]

(*
 * Though some of these numbers (both _AALG and _EALG) appear to be
 * IKEv2 numbers and others original IKE numbers, they have no meaning.
 * These are constants that the various IKE daemons use to tell the kernel
 * what cipher to use.
 *
 * Do not use these constants directly to decide which Transformation ID
 * to send.  You are responsible for mapping them yourself.
 *)
[%%cenum
type aalg =
  | AALG_NONE            [@id 0]
  | AALG_MD5HMAC         [@id 2]
  | AALG_SHA1HMAC        [@id 3]
  | AALG_SHA2_256        [@id 5]
  | AALG_SHA2_384        [@id 6]
  | AALG_SHA2_512        [@id 7]
  | AALG_RIPEMD160HMAC   [@id 8]
  | AALG_AES_XCBC_MAC    [@id 9] (* RFC3566 *)
  | AALG_AES128GMAC      [@id 11] (* RFC4543 + Errata1821 *)
  | AALG_AES192GMAC      [@id 12]
  | AALG_AES256GMAC      [@id 13]
  | AALG_MD5             [@id 249] (* Keyed MD5 *)
  | AALG_SHA             [@id 250] (* Keyed SHA *)
  | AALG_NULL            [@id 251] (* null authentication *)
  | AALG_TCP_MD5         [@id 252] (* Keyed TCP-MD5 (RFC2385) *)
  [@@uint8_t] [@@sexp]]

[%%cenum
type ealg =
  | EALG_NONE            [@id 0]
  | EALG_DESCBC          [@id 2]
  | EALG_3DESCBC         [@id 3]
  | EALG_CAST128CBC      [@id 6]
  | EALG_BLOWFISHCBC     [@id 7]
  | EALG_NULL            [@id 11]
  (*  | EALG_RIJNDAELCBC     [@id 12] *)
  | EALG_AESCBC          [@id 12]
  | EALG_AESCTR          [@id 13]
  | EALG_AESGCM8         [@id 18] (* RFC4106 *)
  | EALG_AESGCM12        [@id 19]
  | EALG_AESGCM16        [@id 20]
  | EALG_CAMELLIACBC     [@id 22]
  | EALG_AESGMAC         [@id 23] (* RFC4543 + Errata1821 *)
  [@@uint8_t] [@@sexp]]

(* private allocations - based on RFC2407/IANA assignment *)
[%%cenum
type calg =
  | CALG_NONE            [@id 0]
  | CALG_OUI             [@id 1]
  | CALG_DEFLATE         [@id 2]
  | CALG_LZS             [@id 3]
  [@@uint8_t] [@@sexp]]

[%%cenum
type ident_type =
  | IDENTTYPE_RESERVED   [@id 0]
  | IDENTTYPE_PREFIX     [@id 1]
  | IDENTTYPE_FQDN       [@id 2]
  | IDENTTYPE_USERFQDN   [@id 3]
  | IDENTTYPE_ADDR       [@id 4]
  [@@uint8_t] [@@sexp]]

(* `flags' in sadb_sa structure holds followings *)
let flag_none = 0x0000 (* i.e. new format. *)
and flag_old = 0x0001 (* old format. *)
and flag_iv4b = 0x0010 (* IV length of 4 bytes in use *)
and flag_deriv = 0x0020 (* DES derived *)
and flag_cycseq = 0x0040 (* allowing to cyclic sequence. *)
  (* three of followings are exclusive flags each them *)
and flag_pseq = 0x0000 (* sequencial padding for ESP *)
and flag_prand = 0x0100 (* random padding for ESP *)
and flag_pzero = 0x0200 (* zero padding for ESP *)
and flag_pmask = 0x0300 (* mask for padding flag *)
and flag_rawcpi = 0x0080 (* use well known CPI (IPComp) *)

(* SPI size for PF_KEYv2 *)
(* #define PFKEY_SPI_SIZE   sizeof(u_int32_t) *)

(* Identifier for menber of lifetime structure *)
[%%cenum
type lifetime_type =
  | LIFETIME_ALLOCATIONS         [@id 0]
  | LIFETIME_BYTES               [@id 1]
  | LIFETIME_ADDTIME             [@id 2]
  | LIFETIME_USETIME             [@id 3]
  [@@uint8_t] [@@sexp]]

(* The rate for SOFT lifetime against HARD one. *)
let soft_lifetime_rate = 80

(* Utilities *)
(*
#define PFKEY_ALIGN8(a) (1 + (((a) - 1) | (8 - 1)))
#define	PFKEY_EXTLEN(msg) \
        PFKEY_UNUNIT64(((struct sadb_ext * )(msg))->sadb_ext_len)
#define PFKEY_ADDR_PREFIX(ext) \
        (((struct sadb_address * )(ext))->sadb_address_prefixlen)
#define PFKEY_ADDR_PROTO(ext) \
        (((struct sadb_address * )(ext))->sadb_address_proto)
#define PFKEY_ADDR_SADDR(ext) \
        ((struct sockaddr * )((caddr_t)(ext) + sizeof(struct sadb_address)))

(* in 64bits *)
#define	PFKEY_UNUNIT64(a)	((a) << 3)
#define	PFKEY_UNIT64(a)		((a) >> 3)
*)

(* from netipsec/ipsec.h *)
(* mode of security protocol *)
(* NOTE: DON'T use IPSEC_MODE_ANY at SPD.  It's only use in SAD *)
[%%cenum
type mode =
  | MODE_ANY       [@id 0] (* i.e. wildcard. *)
  | MODE_TRANSPORT [@id 1]
  | MODE_TUNNEL    [@id 2]
  | MODE_TCPMD5    [@id 3] (* TCP MD5 mode *)
  [@@uint8_t] [@@sexp]]

(*
 * Direction of security policy.
 * NOTE: Since INVALID is used just as flag.
 * The other are used for loop counter too.
 *)
[%%cenum
type direction =
  | DIR_ANY      [@id 0]
  | DIR_INBOUND  [@id 1]
  | DIR_OUTBOUND [@id 2]
  | DIR_MAX      [@id 3]
  | DIR_INVALID  [@id 4]
  [@@uint8_t] [@@sexp]]

(* Policy level *)
(*
 * IPSEC, ENTRUST and BYPASS are allowed for setsockopt() in PCB,
 * DISCARD, IPSEC and NONE are allowed for setkey() in SPD.
 * DISCARD and NONE are allowed for system default.
 *)
[%%cenum
type policy_type =
  | POLICY_DISCARD  [@id 0] (* discarding packet *)
  | POLICY_NONE     [@id 1] (* through IPsec engine *)
  | POLICY_IPSEC    [@id 2] (* do IPsec *)
  | POLICY_ENTRUST  [@id 3] (* consulting SPD if present. *)
  | POLICY_BYPASS   [@id 4] (* only for privileged socket. *)
  [@@uint16_t] [@@sexp]]

(* Security protocol level *)
[%%cenum
type level =
  | LEVEL_DEFAULT  [@id 0] (* reference to system default *)
  | LEVEL_USE      [@id 1] (* use SA if present. *)
  | LEVEL_REQUIRE  [@id 2] (* require SA. *)
  | LEVEL_UNIQUE   [@id 3] (* unique SA. *)
  [@@uint8_t] [@@sexp]]

(*
#define IPSEC_MANUAL_REQID_MAX	0x3fff
				/*
				 * if security policy level == unique, this id
				 * indicate to a relative SA for use, else is
				 * zero.
				 * 1 - 0x3fff are reserved for manual keying.
				 * 0 are reserved for above reason.  Others is
				 * for kernel use.
				 * Note that this id doesn't identify SA
				 * by only itself.
				 */
#define IPSEC_REPLAYWSIZE  32
*)
