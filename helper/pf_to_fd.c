#include <stdio.h>
#include <err.h>
#include <sysexits.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#ifdef __linux__
#include <linux/pfkeyv2.h>
#else
#include <net/pfkeyv2.h>
#endif

#define PERMISSION_BITS 0777

int send_fd(int sock, int fd) {
  struct msghdr msg;
  struct cmsghdr *cmsg= NULL;
  struct iovec iov = { .iov_base = "X", .iov_len = 1 };
  char buf[CMSG_SPACE(sizeof(fd))];

  memset(&msg, 0, sizeof(msg));
  memset(buf, 0, sizeof(buf));

  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = buf;
  msg.msg_controllen = CMSG_SPACE(sizeof(fd));

  cmsg = CMSG_FIRSTHDR(&msg);
  cmsg->cmsg_level = SOL_SOCKET;
  cmsg->cmsg_type = SCM_RIGHTS;
  cmsg->cmsg_len = CMSG_LEN(sizeof(fd));
  memcpy(CMSG_DATA(cmsg), (char*)&fd, sizeof(fd));

  return sendmsg(sock, &msg, 0);
}

void connection(int lsock) {
  int sock;
  int pf_sock;

  if (-1 == (sock = accept(lsock, NULL, NULL)))
    err (EX_OSERR, "accept?");

  if (0 > (pf_sock = socket(PF_KEY, SOCK_RAW, PF_KEY_V2)))
    err (EX_OSERR, "socket(PF_KEY, ...)?");

  if (1 != send_fd(sock, pf_sock))
    warn ("send_fd?");

  if (0 != close (sock))
    warn("close(sock)?");

  if (0 != close (pf_sock))
    warn("close(pf_sock)?");
}

int server (const char *path) {
  struct sockaddr_un addr;
  int sock;
  size_t path_len;
  socklen_t addrlen;

  /* UNIX-domain addresses are variable-length file system pathnames of at
     most 104 characters. */
  if (104 < (path_len = strlen(path)))
    errx(EX_USAGE, "UNIX_domain address is 104 characters max");

  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_LOCAL;
#ifndef __linux__
  addr.sun_len = path_len;
#endif
  (void)strncpy(addr.sun_path, path, 104);

  addrlen = sizeof(addr) - sizeof(addr.sun_path) + path_len;

  if (0 > (sock = socket(AF_LOCAL, SOCK_STREAM, 0)))
    err(EX_OSERR, "socket?");

  (void)unlink(path);

  if (0 != bind(sock, (struct sockaddr *) &addr, addrlen))
    err (EX_OSERR, "bind?");

  (void)chmod(path, PERMISSION_BITS);

  if (0 != listen(sock, 1))
    err (EX_OSERR, "listen?");


  for (;;) connection(sock);
  return 0;
}

int main (int argc, char **argv) {
  if (2 != argc)
    errx(EX_USAGE, "exactly one argument is required: UNIX_domain address");
  return server (argv[1]);
}
