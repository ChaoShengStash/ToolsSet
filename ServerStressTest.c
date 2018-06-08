#include <unistd.h>
#include <stdio.h>
#include <sys/socket.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define EV_NUM 100000
#define BUFFER_SIZE 2048

int setnonblocking(int fd)
{
    int old_option = fcntl(fd, F_GETFL);
    int new_option = old_option | O_NONBLOCK;
    fcntl(fd, F_SETFL, new_option);

    return old_option;
}

void addfd(int epoll_fd, int fd)
{
    struct epoll_event ev;
    ev.data.fd = fd;
    ev.events = EPOLLIN | EPOLLET | EPOLLERR;
    epoll_ctl(epoll_fd,EPOLL_CTL_ADD,fd,&ev);
    setnonblocking(fd);
}

int write_bytes(int fd, const char* buffer,int len)
{
    printf("%s() start\n",__FUNCTION__);
    int send_size = 0;
    while(send_size < len){
        int size = send(fd, (const void *)buffer + send_size, len - send_size, 0);
        if(size > 0){
            send_size += size;
        }else if(size == 0){
            printf(" send over \n");
        }else{
            printf(" send error;");
        }
    }
    printf("%s() end,write %d bytes into %d socket \n",__FUNCTION__,send_size,fd);
    return send_size == len;
}

int read_bytes(int fd, char *buffer,int len)
{
    printf("%s() start\n",__FUNCTION__);
    int ret = 1;
    memset(buffer,'\0',len);
    int size = recv(fd, buffer, len, 0);
    if(size == 0){
        ret = 0;
    }else if(size == -1){
        ret = 0;
    }else{
        ret = 1;
    }
    printf("%s() end,read %d bytes from %d socket \n",__FUNCTION__,size,fd);
    return ret;
}

void start_conn(int epoll_fd, int num, const char* ip, int port)
{
    printf("%s() start\n",__FUNCTION__);
    struct sockaddr_in addr;
    bzero(&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &addr.sin_addr);

    int i = 0;
    for (i = 0; i < num; i++){
        sleep(1);
        int socket_fd = socket(AF_INET, SOCK_STREAM, 0);
        if(socket_fd < 0){
            continue;
        }
        int ret = connect(socket_fd, (const struct sockaddr *)&addr, sizeof(addr));
        if(0 == ret){
            printf("connect successfully\n");
            addfd(epoll_fd, socket_fd);
        }
    }
    printf("%s() end\n",__FUNCTION__);
}

void close_conn(int epoll_fd, int fd)
{
    epoll_ctl(epoll_fd, EPOLL_CTL_DEL, fd, 0);
    close(fd);
}

int main(int argc, char *argv[])
{
    assert(argc == 4);

    char *ip = argv[1];
    int port = atoi(argv[2]);
    int num = atoi(argv[3]);

    int epoll_fd = epoll_create(EV_NUM);
    start_conn(epoll_fd, num, ip, port);
    struct epoll_event evs[EV_NUM];
    char buffer[BUFFER_SIZE];
    int i = 0;
    while(1){
        int nums = epoll_wait(epoll_fd, evs, EV_NUM, -1);
        for(i = 0; i < nums; i++){
            int sock_fd = evs[i].data.fd;
            if(evs[i].events & EPOLLIN){//read available
                int read_ret = read_bytes(sock_fd, buffer, BUFFER_SIZE);
                if(!read_ret){
                    close_conn(epoll_fd, sock_fd);
                }
                struct epoll_event ev;
                ev.events = EPOLLOUT|EPOLLET|EPOLLERR;
                ev.data.fd = sock_fd;
                epoll_ctl(epoll_fd, EPOLL_CTL_MOD, sock_fd, &ev);
            }else if(evs[i].events & EPOLLOUT){//write available
                int write_ret = write_bytes(sock_fd, buffer, strlen(buffer));
                if(!write_ret){
                    close_conn(epoll_fd, sock_fd);
                }
                struct epoll_event ev;
                ev.events = EPOLLIN|EPOLLET|EPOLLERR;
                ev.data.fd = sock_fd;
                epoll_ctl(epoll_fd, EPOLL_CTL_MOD, sock_fd, &ev);
            }else if (evs[i].events & EPOLLERR){//error
                printf(" error %d\n",sock_fd);
                close_conn(epoll_fd, sock_fd);
            }else{//default
                close_conn(epoll_fd, sock_fd);
            }
        }
    }
    return 0;
}