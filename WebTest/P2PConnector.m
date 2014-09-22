//
//  P2PConnector.m
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "P2PConnector.h"

#define SERVBUF 128  //サーバとの通信に使うデータ容量
#define P2PBUF 340   //P2P通信で一度に送れるデータ容量
#define TIMEOUT 4    //マッチングタイムアウトの秒数。(サーバー側は10秒でタイムアウトする)
#define INTERVAL 20.0  //P2P通信確保のためにダミーのパケットを送る時間間隔

@interface P2PConnector()

@property (readwrite) int  P2PSocket;
@property (readwrite) int  flg;
@property (readwrite) BOOL isConnected;
@property (readwrite) BOOL isCalling;
@property (readwrite) BOOL isCalled;
@property (readwrite) BOOL isTalking;

@end

@implementation P2PConnector

struct sockaddr_in expartAddr;
int exP2PSocket;
char receivedData[P2PBUF];
AudioQueueRef inQueue,outQueue;

@synthesize delegate, cliAddr, servAddr, partAddr, P2PSocket, flg, isConnected, isCalling, isCalled, isTalking, ID;

-(id)initWithServerAddr:(NSString *)addr serverPort:(int)sport clientPort:(int)cport delegate:(id<P2PConnectorDelegate>)object ID:(NSString *)idstr{
    
    self=[super init];
    
    //サーバのアドレスを設定
    bzero((char*) &servAddr, sizeof(servAddr));
    servAddr.sin_family=AF_INET;
    servAddr.sin_addr.s_addr=inet_addr([addr UTF8String]);
    servAddr.sin_port=htons(sport);

    //ローカルアドレスを設定
    bzero((char*)&cliAddr, sizeof(cliAddr));
    cliAddr.sin_family=AF_INET;
    cliAddr.sin_addr.s_addr=htonl(INADDR_ANY);
    cliAddr.sin_port=htons(cport);
    
    delegate=object;
    ID=idstr;
    P2PSocket=0;
    flg=0;
    isConnected=NO;
    isCalled=NO;
    isCalling=NO;
    isTalking=NO;
    
    return self;
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
    
    //P2P通信完全開通のため、テストパケットをやり取りする
    //flg==1のときは相手に#ts1#をおくり、相手から応答の#ts2#がきたら終了
    //flg==2のときは相手からの#ts1#を待ち、こないときは#ts1#を送る。もし来たら応答の#ts2#を送って終了
    
    /*
    if( flg==1 ){
        if( [self confirmP2PConnectFlg1]==NO ){
            NSLog(@"failed to make P2P connection, flg=1");
            return NO;
        }
    }else if( flg==2 ){
        if( [self confirmP2PConnectFlg2]==NO ){
            NSLog(@"failed to make P2P connection, flg=2");
            return NO;
        }
    }
    */
    isConnected=YES;
    
    //P2P通信の確保のため、#tst#をINTERVAL秒ごとに送る。
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:INTERVAL
                                                      target:self
                                                    selector:@selector(sendTestPacket:)
                                                    userInfo:nil
                                                     repeats:YES];
    [timer fire];
    
    return YES;
}

-(BOOL)confirmP2PConnectFlg1{
    
    struct timeval timeout;
    timeout.tv_sec = 5000;
    timeout.tv_usec = 0; //0.5秒でタイムアウト
    
    fd_set readfds;
    struct sockaddr_in tmpAddr;
    bzero((char*)&tmpAddr, sizeof(tmpAddr));
    socklen_t addrlen = sizeof(tmpAddr);
    
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
                         (struct sockaddr *)&tmpAddr, &addrlen)<0 ){
                NSLog(@"failed to receive from partner");
                close(P2PSocket);
                return NO;
            }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='2' && receivedData[4]=='#' ){
                partAddr.sin_addr=tmpAddr.sin_addr;
                partAddr.sin_port=tmpAddr.sin_port;
                NSLog(@"received msg2 from partner");
                return YES;
            }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='1' && receivedData[4]=='#' ){
                partAddr.sin_addr=tmpAddr.sin_addr;
                partAddr.sin_port=tmpAddr.sin_port;
                NSLog(@"received msg1 from partner");
            }
            
        } else {
        NSLog(@"retrying to make P2P connection...");
            
        }
    }
    return NO;
}

-(BOOL)confirmP2PConnectFlg2{
    
    struct timeval timeout;
    timeout.tv_sec = 5000;
    timeout.tv_usec = 0; //0.5秒でタイムアウト
    
    fd_set readfds;
    struct sockaddr_in tmpAddr;
    bzero((char*)&tmpAddr, sizeof(tmpAddr));
    socklen_t addrlen = sizeof(tmpAddr);
    
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
                         (struct sockaddr *)&tmpAddr, &addrlen)<0 ){
                NSLog(@"failed to receive from partner");
                close(P2PSocket);
                return NO;
            }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='1' && receivedData[4]=='#' ){
                partAddr.sin_addr=tmpAddr.sin_addr;
                partAddr.sin_port=tmpAddr.sin_port;
                if(sendto(P2PSocket, msg2, strlen(msg2)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
                    NSLog(@"failed to send a dummy message");
                    return NO;
                }
                NSLog(@"received msg1 from partner");
                return YES;
            }
            
        }
        
        NSLog(@"retrying to make P2P connection...");
        if(sendto(P2PSocket, msg1, strlen(msg1)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
            NSLog(@"failed to send a dummy message");
            return NO;
        }
        
    }
    return NO;
}


-(void)sendTestPacket:(NSTimer*)timer{
    
    if( isConnected==NO ){
        [timer invalidate];
    }else{
        char* msg="#tst#";
        if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
            NSLog(@"failed to confirm P2P connection");
        }
    }
}

-(BOOL)sendPartnerMessage:(NSString *)message{

    if( isConnected==NO ){
        return NO;
    }
    
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

-(BOOL)startWaitingForPartner{
    
    if( isConnected==NO ){
        NSLog(@"connection is not established");
        return NO;
    }
    
    [NSThread detachNewThreadSelector:@selector(waitForPartner) toTarget:self withObject:nil];
    return YES;
}

-(BOOL)waitForPartner{
    
    struct sockaddr_in tmpAddr;
    bzero((char*)&tmpAddr, sizeof(tmpAddr));
    socklen_t addrlen = sizeof(tmpAddr);
    
    //データを受信
    while (1) {
        
        if( isConnected==NO ){
            break;
        }
        
        recvfrom(P2PSocket, receivedData, sizeof(receivedData) - 1, 0,
                 (struct sockaddr *)&tmpAddr, &addrlen);
        
        //パートナー以外からのパケットは無視
        if( tmpAddr.sin_addr.s_addr!=partAddr.sin_addr.s_addr || tmpAddr.sin_port!=partAddr.sin_port ){
            continue;
        }
        
        //データの種類を識別
        
        //メッセージの場合
        if( receivedData[0]=='#' && receivedData[1]=='m' && receivedData[2]=='s' && receivedData[3]=='g' && receivedData[4]=='#' ){
            NSString* receiveBuf = [[NSString stringWithUTF8String:receivedData] substringFromIndex:5];
            [delegate didReceiveMessage:receiveBuf];
            NSLog(@"received message: %@",receiveBuf);
            
        //切断通知の場合
        }else if( receivedData[0]=='#' && receivedData[1]=='h' && receivedData[2]=='u' && receivedData[3]=='p' && receivedData[4]=='#' ){
            if( isTalking==NO && isCalling==NO && isCalled==NO ){
                NSLog(@"received hang up when not talking/calling/being called");
                continue;
            }
            if( isTalking==YES ){
                AudioQueueStop(inQueue, true);
                AudioQueueStop(outQueue, true);
                AudioQueueDispose(inQueue, true);
                AudioQueueDispose(outQueue, true);
                NSLog(@"stopped talking");
            }
            isTalking=NO;
            isCalling=NO;
            isCalled=NO;
            [delegate didReceiveHangUp];
            NSLog(@"partner has hung up");
            
        //着信の場合
        }else if( receivedData[0]=='#' && receivedData[1]=='c' && receivedData[2]=='a' && receivedData[3]=='l' && receivedData[4]=='#' ){
            if( isTalking==YES || isCalling==YES || isCalled==YES ){
                NSLog(@"received call when talking/calling/being called");
                continue;
            }
            isCalled=YES;
            [delegate didReceiveCall];
            NSLog(@"received call");
        
        //通話承諾通知の場合
        }else if( receivedData[0]=='#' && receivedData[1]=='c' && receivedData[2]=='o' && receivedData[3]=='k' && receivedData[4]=='#' ){
            if( isTalking==YES || isCalling==NO || isCalled==YES ){
                NSLog(@"received responce when talking/not calling/being called");
                continue;
            }
            isCalling=NO;
            isTalking=YES;
            [self startSendingVoice];
            [delegate didReceiveResponse];
            NSLog(@"partner has responded to call");
            
        //通信切断通知の場合
        }else if( receivedData[0]=='#' && receivedData[1]=='d' && receivedData[2]=='i' && receivedData[3]=='s' && receivedData[4]=='#' ){
            if( isTalking==YES ){
                AudioQueueStop(inQueue, true);
                AudioQueueStop(outQueue, true);
                AudioQueueDispose(inQueue, true);
                AudioQueueDispose(outQueue, true);
                NSLog(@"stopped talking");
            }
            isConnected=NO;
            isTalking=NO;
            isCalling=NO;
            isCalled=NO;
            close(P2PSocket);
            [delegate didReceiveDisconnection];
            NSLog(@"partner has disconnected");
        
        //P2P通信確保用のテストパケットの場合
        }else if( receivedData[0]=='#' && receivedData[1]=='t' && receivedData[2]=='s' && receivedData[3]=='t' && receivedData[4]=='#' ){
            NSLog(@"received test packet");
        }
    }
    return YES;
}

-(BOOL)startSendingVoice{
    
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

-(BOOL)call{
    
    if( isConnected==NO ){
        return NO;
    }
    
    if( isTalking==YES || isCalling==YES || isCalled==YES ){
        NSLog(@"you cannot call when you are talking/calling/being called");
        return NO;
    }else{
        //発信を通知（#cal#を相手に送る)
        char* msg="#cal#";
        NSLog(@"calling...");
        if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
            NSLog(@"failed");
            return NO;
        }
        isCalling=YES;
    }
    
    return YES;
}

-(BOOL)respond{
    
    if( isConnected==NO ){
        return NO;
    }
    
    if( isTalking==YES || isCalling==YES || isCalled==NO ){
        NSLog(@"you cannot respond when you are talking/calling/not being called");
        return NO;
    }else{
        //応答を通知（#cok#を相手に送る)
        char* msg="#cok#";
        NSLog(@"responded to call");
        if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
            NSLog(@"failed");
            return NO;
        }
        isCalled=NO;
        isTalking=YES;
        [self startSendingVoice];
    }
    
    return YES;
}

-(BOOL)hangUp{
    
    if( isConnected==NO ){
        return NO;
    }
    
    if( isTalking==YES ){
        AudioQueueStop(inQueue, true);
        AudioQueueStop(outQueue, true);
        AudioQueueDispose(inQueue, true);
        AudioQueueDispose(outQueue, true);
        NSLog(@"stopped talking");
    }

    isTalking=NO;
    isCalling=NO;
    isCalled=NO;
    
    //通話切断を通知（#hup#を相手に送る)
    char* msg="#hup#";
    NSLog(@"hanging up...");
    if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
        NSLog(@"failed");
        return NO;
    }
    
    return YES;
}

-(BOOL)closeP2PSocket{
    
    if( isConnected==NO ){
        return NO;
    }
    
    //通信切断を通知（#dis#を相手に送る)
    char* msg="#dis#";
    NSLog(@"disconnecting...");
    if(sendto(P2PSocket, msg, strlen(msg)+1, 0, (struct sockaddr*)&partAddr, sizeof(partAddr))<0){
        NSLog(@"failed");
        return NO;
    }
    
    close(P2PSocket);
    
    isConnected=NO;
    isCalling=NO;
    isCalled=NO;
    isTalking=NO;
    
    return YES;
}

@end
