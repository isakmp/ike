#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#include <strings.h>

#include <sys/types.h>
#include <sys/socket.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>

#ifdef __linux__
#include <linux/pfkeyv2.h>
#else
#include <net/pfkeyv2.h>
#endif

#include <sys/select.h>

#define bsize 8192
char buffer[bsize];
ssize_t n;

#define DEBUG 0

int read_write (int source, int sink) {
  n = read(source, buffer, bsize);
  if (n < 0) {
    perror("error while reading from socket");
    return -1;
  }

#if DEBUG
  printf("read/write (%d->%d) ", source, sink);
  for (int i = 0; i < n; i++) {
    printf("%02X ", buffer[i]);
  }
  printf("\n");
#endif

  if (write(sink, buffer, n) != n) {
    perror("error while writing to sink\n");
    return -1;
  }

  return 0;
}

int main (int argc, char* argv[]) {
  fd_set readset;
  int pf_s, tcp, tcp_c = 0;
  int res = 0;
  struct sockaddr_in serv_addr, cli_addr;
  socklen_t cli_len;
  int on = 1;
  int port = 1234;
  int max;

  if (argc == 2) {
    port = atoi(argv[1]);
  }

  pf_s = socket(PF_KEY, SOCK_RAW, PF_KEY_V2);
  if (pf_s < 0) {
    perror("error while creating PF_KEY socket");
    exit(-1);
  }

  printf("[%d] is the PF_KEY socket\n", pf_s);

  tcp = socket(AF_INET, SOCK_STREAM, 0);
  if (tcp < 0) {
    perror("error while creating SOCK_STREAM socket");
    goto fail;
  }

  if (setsockopt(tcp, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0) {
    perror("error while setsockopt");
    goto fail;
  }

  bzero((char *) &serv_addr, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
  serv_addr.sin_port = htons(port);

  printf("attempt bind to %s:%d\n",
         inet_ntoa(serv_addr.sin_addr),
         ntohs(serv_addr.sin_port));

  if (bind(tcp, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) {
    perror("error while binding");
    goto fail;
  }

  if (listen(tcp, 1) < 0) {
    perror("error while listening");
    goto fail;
  }

  printf("[%d] is listening on %s:%d\n",
         tcp,
         inet_ntoa(serv_addr.sin_addr),
         ntohs(serv_addr.sin_port));

  cli_len = sizeof(cli_addr);
  tcp_c = accept(tcp, (struct sockaddr *)&cli_addr, &cli_len);

  if (tcp_c < 0) {
    perror("error on accept");
    goto fail;
  }

  if (setsockopt(tcp_c, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on)) < 0) {
    perror("error while setsockopt on client socket");
    goto fail;
  }

  printf("[%d] accepted connection from %s:%d\n",
         tcp_c,
         inet_ntoa(cli_addr.sin_addr),
         ntohs(cli_addr.sin_port));

  if (close(tcp) < 0) {
    perror("error on close");
    goto fail;
  }
  tcp = 0;

  max = tcp_c > pf_s ? 1 + tcp_c : 1 + pf_s;

  printf("entering read/write loop\n");
  while (1) {
    FD_ZERO(&readset);
    FD_SET(pf_s, &readset);
    FD_SET(tcp_c, &readset);
    res = select(max, &readset, NULL, NULL, NULL);
    if (res < 0) {
      perror("error in select");
      goto fail;
    } else {
      if (FD_ISSET(pf_s, &readset)) {
        if (read_write(pf_s, tcp_c) < 0) {
          goto fail;
        }
      }
      if (FD_ISSET(tcp_c, &readset)) {
        if (read_write(tcp_c, pf_s) < 0) {
          goto fail;
        }
      }
    }
  }
  printf("this is never printed\n");
  if (pf_s > 0) { close(pf_s); }
  if (tcp_c > 0) { close(tcp_c); }
  return 0;

 fail:
  if (pf_s > 0) { close(pf_s); }
  if (tcp > 0) { close(tcp); }
  if (tcp_c > 0) { close(tcp_c); }
  exit(-1);
}
