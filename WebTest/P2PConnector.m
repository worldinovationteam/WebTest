//
//  P2PConnector.m
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "P2PConnector.h"

@implementation P2PConnector

struct sockaddr_in expartAddr;
int exP2PSocket;
char receivedData[P2PBUF];
AudioQueueRef inQueue,outQueue;

@synthesize cliAddr, servAddr, partAddr, P2PSocket, flg, receiveBuf, isTalking;

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

    char buf[SERVBUF];
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
        return NO;
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
    
    expartAddr=partAddr;

    return YES;
}

-(BOOL)createP2PSocket{
    
    //UDPソケットをオープン
    P2PSocket=socket(AF_INET,SOCK_DGRAM,0);
    exP2PSocket=P2PSocket;
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

-(BOOL)closeP2PSocket{
    close(P2PSocket);
    return YES;
}

-(BOOL)sendPartnerMessage:(NSString *)message{
    //メッセージのパケットであることを明示するため、先頭に#msg#をつける
    NSString* message2=[@"#msg#" stringByAppendingString:message];
    char* msg=(char*)[message2 UTF8String];
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
    socklen_t addrlen = sizeof(partAddr);
    while (1) {
        recvfrom(P2PSocket, receivedData, sizeof(receivedData) - 1, 0,
                 (struct sockaddr *)&partAddr, &addrlen);
        //データの種類を識別
        if( receivedData[0]=='#' && receivedData[1]=='m' && receivedData[2]=='s' && receivedData[3]=='g' && receivedData[4]=='#' ){
            receiveBuf = [[NSString stringWithUTF8String:receivedData] substringFromIndex:5];
            NSLog(@"received message: %@",receiveBuf);
        }else if( receivedData[0]=='#' && receivedData[1]=='h' && receivedData[2]=='u' && receivedData[3]=='p' && receivedData[4]=='#' ){
            AudioQueueStop(inQueue, true);
            AudioQueueStop(outQueue, true);
            AudioQueueDispose(inQueue, true);
            AudioQueueDispose(outQueue, true);
            isTalking=NO;
            NSLog(@"partner has hung up");
        }
    }
    return YES;
}

-(BOOL)startSendingVoice{
    if( isTalking ){
        NSLog(@"already talking");
        return NO;
    }
    
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef inBuffer[3];
    AudioQueueBufferRef outBuffer[3];
    
    dataFormat.mSampleRate = 44100.0f;
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    dataFormat.mBytesPerPacket = 2;
    dataFormat.mFramesPerPacket = 1;
    dataFormat.mBytesPerFrame = 2;
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 16;
    dataFormat.mReserved = 0;
    OSStatus stat;
    
    //スピーカ用バッファのクリア
    for(int i=0; i<P2PBUF; i++){
        receivedData[i]=0;
    }
    
    //スピーカ用キューの開始
    stat=AudioQueueNewOutput(&dataFormat, AudioOutputCallback, NULL, NULL, NULL, 0, &outQueue);
    if( stat ){
        printf("failed to make output queue %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<3; i++){
        stat=AudioQueueAllocateBuffer(outQueue,P2PBUF,outBuffer+i);
        if( stat ){
            printf("failed to allocate output buffers %d\n",(int)stat);
            return NO;
        }
        AudioOutputCallback(NULL, outQueue, outBuffer[i]);
    }
    
    stat=AudioQueueStart(outQueue, NULL);
    printf("output start %d\n",(int)stat);
    
    //マイク用キューの開始
    stat=AudioQueueNewInput(&dataFormat, AudioInputCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &inQueue);
    if( stat ){
        printf("failed to make input queue %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<3; i++){
        stat=AudioQueueAllocateBuffer(inQueue,P2PBUF,inBuffer+i);
        AudioQueueEnqueueBuffer(inQueue,inBuffer[i],0,NULL);
        if( stat ){
            printf("failed to allocate input buffers %d\n",(int)stat);
            return NO;
        }
    }
    
    stat=AudioQueueStart(inQueue, NULL);
    printf("input start %d\n",(int)stat);
    
    NSLog(@"audio started");
    isTalking=YES;
    return YES;
}

void AudioInputCallback(
                               void* inUserData,
                               AudioQueueRef inAQ,
                               AudioQueueBufferRef inBuffer,
                               const AudioTimeStamp *inStartTime,
                               UInt32 inNumberPacketDescriptions,
                               const AudioStreamPacketDescription *inPacketDescs){
    //マイク用バッファがいっぱいになったら相手に送る
    sendto(exP2PSocket, (char*)inBuffer->mAudioData, P2PBUF, 0, (struct sockaddr*)&expartAddr, sizeof(expartAddr));
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

void AudioOutputCallback (
                                 void                 *inUserData,
                                 AudioQueueRef        inAQ,
                                 AudioQueueBufferRef  inBuffer
                                 ){
    //スピーカ用バッファが空いたら相手からのデータを入れる
    char* datapt= (char *)(inBuffer->mAudioData);
    for(int i=0; i<P2PBUF; i++){
        datapt[i]=receivedData[i];
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(BOOL)hangUp{
    AudioQueueStop(inQueue, true);
    AudioQueueStop(outQueue, true);
    AudioQueueDispose(inQueue, true);
    AudioQueueDispose(outQueue, true);
    isTalking=NO;
    
    //通信切断を通知（#hup#を相手に送る)
    char* msg="#hup#";
    NSLog(@"hanging up...");
    if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
        NSLog(@"failed");
        return NO;
    }
    
    return YES;
}

@end
