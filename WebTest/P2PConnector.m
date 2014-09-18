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

@synthesize cliAddr, servAddr, partAddr, P2PSocket, flg, receiveBuf, isTalking, ID;

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
    int sockfd;

    //UDPソケットをオープン
    sockfd=socket(AF_INET,SOCK_DGRAM,0);
    if(sockfd<0){
        NSLog(@"can't open datagram socket");
        return NO;
    }
    NSLog(@"sokcet opened, sockfd= %d",sockfd);
    
    //ローカルアドレスのbind
    if(bind(sockfd,(struct sockaddr*)&cliAddr,sizeof(cliAddr))<0){
        NSLog(@"can't bind local address");
        close(sockfd);
        return NO;
    }
    
    //IDをサーバに送出
    if( ID==nil ){
        NSLog(@"ID is not set");
        return NO;
    }
    NSString* ID2=[@"#mat#" stringByAppendingString:ID];
    char* msg=(char*)[ID2 UTF8String];
    const char* msg2=strcat(msg,"\0");
    
    NSLog(@"sending to server...");
    if(sendto(sockfd, msg2, strlen(msg2), 0, (struct sockaddr*)&servAddr, sizeof(servAddr))<0){
        NSLog(@"failed");
        close(sockfd);
        return NO;
    }else{
        NSLog(@"ok");
    }
    
    //タイムアウトTIMEOUT秒でサーバからの応答を待つ
    struct timeval timeout;
    timeout.tv_sec = TIMEOUT;
    timeout.tv_usec = 0;
    
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(sockfd, &readfds);
    
    int n=select(sockfd+1, &readfds, NULL, NULL, &timeout);
    if( n<0 ){
        NSLog(@"failed to select sockets");
        close(sockfd);
        return NO;
    }else if( n==0 ){
        NSLog(@"run out of time to wait for server");
        close(sockfd);
        return NO;
    }
    
    if( FD_ISSET(sockfd, &readfds) ){
        socklen_t addrlen = sizeof(servAddr);
        if( recvfrom(sockfd, buf, sizeof(buf), 0,
                     (struct sockaddr *)&servAddr, &addrlen)<0 ){
            NSLog(@"failed to receive from server");
            close(sockfd);
            return NO;
        }
    }

    //サーバからの情報を表示、パートナーのIPアドレスとポート番号を取得
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

-(BOOL)prepareP2PConnection{
    
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
    
    //P2P通信完全開通のため、ダミーのパケットをやり取りする
    //flg==1のときは相手に#ts1#をおくり、相手から応答の#ts2#がきたら終了
    //flg==2のときは相手からの#ts1#を待ち、こないときは#ts1#を送る。もし来たら応答の#ts2#を送って終了
    
    if( flg==1 ){
        if( [self confirmP2PConnectFlg1]==NO ){
            NSLog(@"failed to make P2P connection");
            return NO;
        }
    }else if( flg==2 ){
        if( [self confirmP2PConnectFlg2]==NO ){
            NSLog(@"failed to make P2P connection");
            return NO;
        }
    }
    
    return YES;
}

-(BOOL)confirmP2PConnectFlg1{
    
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 500000; //0.5秒でタイムアウト
    fd_set readfds;
    socklen_t addrlen = sizeof(partAddr);
    
    const char* msg1="#ts1#";

    for( int i=0; i<10; i++ ){
        
        if(sendto(P2PSocket, msg1, strlen(msg1)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
            NSLog(@"failed to send a dummy message");
            return NO;
        }
        
        FD_ZERO(&readfds);
        FD_SET(P2PSocket, &readfds);
        
        int n=select(P2PSocket+1, &readfds, NULL, NULL, &timeout);
        
        if( n<0 ){
            NSLog(@"failed to select sockets");
            close(P2PSocket);
            return NO;
            
        } else if( FD_ISSET(P2PSocket, &readfds) ){
            if( recvfrom(P2PSocket, receivedData, P2PBUF, 0,
                         (struct sockaddr *)&partAddr, &addrlen)<0 ){
                NSLog(@"failed to receive from partner");
                close(P2PSocket);
                return NO;
            }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='2' && receivedData[4]=='#' ){
                return YES;
            }
            
        } else {
        NSLog(@"retrying to make P2P connection...");
            
        }
    }
    return NO;
}

-(BOOL)confirmP2PConnectFlg2{
    
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 500000; //0.5秒でタイムアウト
    fd_set readfds;
    socklen_t addrlen = sizeof(partAddr);
    
    const char* msg1="#ts1#";
    const char* msg2="#ts2#";
    
    for( int i=0; i<10; i++ ){
        
        FD_ZERO(&readfds);
        FD_SET(P2PSocket, &readfds);
        
        int n=select(P2PSocket+1, &readfds, NULL, NULL, &timeout);
        
        if( n<0 ){
            NSLog(@"failed to select sockets");
            close(P2PSocket);
            return NO;
            
        } else if( FD_ISSET(P2PSocket, &readfds) ){
            if( recvfrom(P2PSocket, receivedData, P2PBUF, 0,
                         (struct sockaddr *)&partAddr, &addrlen)<0 ){
                NSLog(@"failed to receive from partner");
                close(P2PSocket);
                return NO;
            }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='1' && receivedData[4]=='#' ){
                if(sendto(P2PSocket, msg2, strlen(msg2)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
                    NSLog(@"failed to send a dummy message");
                    return NO;
                }
                return YES;
            }else{
                if(sendto(P2PSocket, msg1, strlen(msg1)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
                    NSLog(@"failed to send a dummy message");
                    return NO;
                }
            }
            
        } else {
            NSLog(@"retrying to make P2P connection...");
            if(sendto(P2PSocket, msg1, strlen(msg1)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
                NSLog(@"failed to send a dummy message");
                return NO;
            }
            
        }
        
    }
    return NO;
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
    
    //フォーマットの設定
    /*
    // Linear PCM 44100 Hz
    dataFormat.mSampleRate = 44100.0f;
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    dataFormat.mBytesPerPacket = 2;
    dataFormat.mFramesPerPacket = 1;
    dataFormat.mBytesPerFrame = 2;
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 16;
    dataFormat.mReserved = 0;
     */

    // IMA/ADPCM 16000 Hz
    dataFormat.mSampleRate = 16000.0f;
    dataFormat.mFormatID = kAudioFormatAppleIMA4;
    dataFormat.mBytesPerPacket = 34;
    dataFormat.mFormatFlags=0;
    dataFormat.mFramesPerPacket = 64;
    dataFormat.mBytesPerFrame = 0; //compressed dataにたいしては0
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 0; //compressed dataにたいしては0
    
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
    char* datapt= (char *)(inBuffer->mAudioData);
    sendto(exP2PSocket, datapt, P2PBUF, 0, (struct sockaddr*)&expartAddr, sizeof(expartAddr));
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

void AudioOutputCallback (
                                 void                 *inUserData,
                                 AudioQueueRef        inAQ,
                                 AudioQueueBufferRef  inBuffer
                                 ){
    //スピーカ用バッファが空いたら相手からのデータを入れる
    char* datapt= (char *)(inBuffer->mAudioData);
    inBuffer->mAudioDataByteSize=P2PBUF;
    for(int i=0; i<P2PBUF; i++){
        datapt[i]=receivedData[i];
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(BOOL)hangUp{
    if( isTalking==NO ){
        NSLog(@"not talking now");
        return NO;
    }
    
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
