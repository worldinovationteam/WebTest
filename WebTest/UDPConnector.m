//
//  UDPConnector.m
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "UDPConnector.h"

@implementation UDPConnector

@synthesize cliAddr, servAddr, partAddr, P2PSocket, flg, receiveBuf;

-(void)initServerSocketWithAddr:(NSString *)addr AndPort:(int)port{
    //サーバのアドレスを設定
    bzero((char*) &servAddr, sizeof(servAddr));
    servAddr.sin_family=AF_INET;
    servAddr.sin_addr.s_addr=inet_addr([addr UTF8String]);
    servAddr.sin_port=htons(port);
}

-(void)initClientSocketWithPort:(int)port{
    //ローカルアドレスを設定
    bzero((char*)&cliAddr, sizeof(cliAddr));
    cliAddr.sin_family=AF_INET;
    cliAddr.sin_addr.s_addr=htonl(INADDR_ANY);
    cliAddr.sin_port=htons(port);
}

-(BOOL)findPartner{

    char buf[BUFSIZE];
    char senderstr[6];
    char* msg="test";
    int sockfd;

    //UDPソケットをオープン
    sockfd=socket(AF_INET,SOCK_DGRAM,0);
    if(sockfd<0){
        NSLog(@"can't open datagram socket");
        return NO;
    }
    NSLog(@"sokcet opened");
    
    //ローカルアドレスのbind
    if(bind(sockfd,(struct sockaddr*)&cliAddr,sizeof(cliAddr))<0){
        NSLog(@"can't bind local address");
        close(sockfd);
        return NO;
    }
    
    //パケット送出
    NSLog(@"sending to server...");
    if(sendto(sockfd, msg, strlen(msg), 0, (struct sockaddr*)&servAddr, sizeof(servAddr))<0){
        NSLog(@"failed");
        close(sockfd);
    }else{
        NSLog(@"ok");
    }
    
    //データを受信
    socklen_t addrlen = sizeof(servAddr);
    recvfrom(sockfd, buf, sizeof(buf), 0,
                 (struct sockaddr *)&servAddr, &addrlen);
    
    // 送信元に関する情報を表示、パートナーのIPアドレスとポート番号を取得
    inet_ntop(AF_INET, &servAddr.sin_addr, senderstr, sizeof(senderstr));
    NSLog(@"%@",[NSString stringWithFormat:@"from server : %s", buf]);
    close(sockfd);
    
    NSString* bufStr=[NSString stringWithUTF8String:buf];
    NSRange range1 = [bufStr rangeOfString:@"__"];
    NSString* partIP;
    if (range1.location != NSNotFound) {
        partIP=[bufStr substringToIndex:range1.location];
    } else {
        NSLog(@"cannot get partner's IP address");
        return NO;
    }
    
    NSRange range2 = [bufStr rangeOfString:@"--"];
    if (range2.location==NSNotFound){
        NSLog(@"cannot get partner's port number");
        return NO;
    }
    NSRange range3 = NSMakeRange(range1.location+range1.length, range2.location-range1.location);
    int partPort=[[bufStr substringWithRange:range3] intValue];

    flg=[[bufStr substringFromIndex:range2.location+range2.length] intValue];
    
    //パートナーのアドレスを設定
    bzero((char*) &partAddr, sizeof(partAddr));
    partAddr.sin_family=AF_INET;
    partAddr.sin_addr.s_addr=inet_addr([partIP UTF8String]);
    partAddr.sin_port=htons(partPort);

    return YES;
}

-(BOOL)createP2PSocket{
    
    //UDPソケットをオープン
    P2PSocket=socket(AF_INET,SOCK_DGRAM,0);
    if(P2PSocket<0){
        NSLog(@"can't open datagram P2P socket");
        return NO;
    }
    NSLog(@"P2P sokcet opened");
    
    //ローカルアドレスのbind
    if(bind(P2PSocket,(struct sockaddr*)&cliAddr,sizeof(cliAddr))<0){
        NSLog(@"can't bind local address");
        close(P2PSocket);
        return NO;
    }
    return YES;
}

-(void)closeP2PSocket{
    close(P2PSocket);
}

-(BOOL)sendPartnerMessage:(NSString *)message{
    char* msg=(char*)[message UTF8String];
    const char* msg2=strcat(msg,"\0");
    //パケット送出
    NSLog(@"sending to partner...");
    if(sendto(P2PSocket, msg2, strlen(msg2)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
        NSLog(@"failed");
        return NO;
    }
    NSLog(@"ok");
    return YES;
}

-(BOOL)waitForPartner{
    //データを受信
    char buf[BUFSIZE];
    socklen_t addrlen = sizeof(partAddr);
    while (1) {
        NSLog(@"waiting from partner");
        recvfrom(P2PSocket, buf, sizeof(buf) - 1, 0,
                 (struct sockaddr *)&partAddr, &addrlen);
        receiveBuf=[NSString stringWithUTF8String:buf];
        NSLog(@"received message:%@",receiveBuf);
    }
    return YES;
}

@end
