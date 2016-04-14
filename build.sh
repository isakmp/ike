#!/bin/sh
# This script is only used for developement. It is removed by the
# distribution process.

set -e

OCAMLBUILD=${OCAMLBUILD:="ocamlbuild -tag debug -classic-display \
                          -use-ocamlfind" }
OCAMLDOCFLAGS=${OCAMLDOCFLAGS:="-docflags -colorize-code,-charset,utf-8"}
BUILDDIR=${BUILDDIR:="_build"}

action ()
{
    case $1 in
        default) action lwt ; action helper ;;
        helper) cc -Wall -Werror -std=c99 -O3 -o helper/pf_to_tcp helper/pf_to_tcp.c ;
                cc -Wall -Werror -std=c99 -O3 -o helper/pf_to_fd helper/pf_to_fd.c ;;
        lwt) action lib ; $OCAMLBUILD lwt/ike_lwt.native ;;
        lib) $OCAMLBUILD ike.cmx ike.cmxa ;;
        test) action lib ; $OCAMLBUILD rfctests.native ;;
        doc) shift
             $OCAMLBUILD -no-links $OCAMLDOCFLAGS doc/api.docdir/index.html
             cp doc/style.css $BUILDDIR/$DOCDIRFILE/style.css ;;
        clean) $OCAMLBUILD -clean ; rm -rf _tests ; rm -f helper/pf_to_tcp ; rm -f helper/pf_to_fd ;;
        *) $OCAMLBUILD $* ;;
    esac
}

if [ $# -eq 0 ];
then action default ;
else action $*; fi
