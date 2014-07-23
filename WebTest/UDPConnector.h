//
//  UDPConnector.h
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#define BUFSIZE 128


@interface UDPConnector : NSObject{
    struct sockaddr_in cliAddr;
    struct sockaddr_in servAddr;
    struct sockaddr_in partAddr;
    int       P2PSocket;
    int       flg;
    NSString* receiveBuf;
}

@property struct sockaddr_in cliAddr;
@property struct sockaddr_in servAddr;
@property struct sockaddr_in partAddr;
@property int       P2PSocket;
@property int       flg;
@property NSString* receiveBuf;

-(void)initServerSocketWithAddr:(NSString*)addr AndPort:(int)port;
-(void)initClientSocketWithPort:(int)port;
-(BOOL)findPartner;
-(BOOL)sendPartnerMessage:(NSString*)message;
-(BOOL)createP2PSocket;
-(void)closeP2PSocket;
-(BOOL)waitForPartner;

@end
