//
//  itachIP2IR.m
//  itachIP2IR
//
//  Created by colossus on 4/19/14.
//  Copyright (c) 2014 colossus. All rights reserved.
//

#import "itachIP2IR.h"
#import <arpa/inet.h>
#import <sys/socket.h>
#include <netdb.h>
#include <errno.h>

#ifdef DEBUG
#   define DLog(...) NSLog(__VA_ARGS__)
#else
#   define DLog(...)
#endif

@implementation itachIP2IR

+(id)sharedInstance
{
    static itachIP2IR *sharedItach = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedItach = [[self alloc] init];
        [sharedItach setItachPort:@"4998"];
    });
    return sharedItach;
}


- (void)sendCommand: (NSString *)request {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        struct addrinfo *servInfo;

        struct addrinfo hints;
        memset(&hints, 0, sizeof hints);
        hints.ai_family = PF_INET;
        hints.ai_socktype = SOCK_STREAM;
        int res = getaddrinfo([_itachIP UTF8String], [_itachPort UTF8String], &hints, &servInfo);
        
        if (res != 0) {
            //                EAI_ADDRFAMILY
            NSLog(@"WARN: Could not connect to host.  Please assign a delegate to the network controller to avoid this log message in the future");
            return;
        }
        struct sockaddr *addr = servInfo->ai_addr;
        
        if(!my_socket)
            my_socket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
        
        if (my_socket < 0) {
            DLog(@"[itachIP2IR] could not create socket");
            return;
        }
        
        int yes = 1;
        if(setsockopt(my_socket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
            perror("setsockopt");
            exit(1);
        }
        
        
        res = connect(my_socket, addr, sizeof(struct sockaddr));
        if (res < 0) {
            NSLog(@"error no %d",errno);
            return;
        }
        
        NSError *error;
        
        NSString *requestStrFrmt = request;
        
        NSData *requestData = [requestStrFrmt dataUsingEncoding:NSUTF8StringEncoding];
        
        
        NSData *jsonData = requestData;
        if (error) {
            NSLog(@"could not decode data from host");
            return;
        }
        send(my_socket, [jsonData bytes], [jsonData length], 0);
        

        DLog(@"[itachIP2IR] sent %lu byte message",(unsigned long)[jsonData length]);

        //Get data back
        char buffer[5000];
        int numBytes = 0;
        char *ptr = buffer;
        
        struct timeval tv;
        
        tv.tv_sec = 2;  /* 30 Secs Timeout */
        tv.tv_usec = 0;  // Not init'ing this can cause strange errors
        setsockopt(my_socket, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv,sizeof(struct timeval));
        
        int nRecv = recv(my_socket, ptr, sizeof(buffer), 0);
        
        DLog(@"[itachIP2IR] Received : %@",[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]);
        
        close(my_socket);
    });
}



-(void)cleanup
{
    close(my_socket);
}
@end
