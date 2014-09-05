//
//  P2PConnector.h
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//
//<使い方>
//1. initServerSocketWithAddr:AndPort: でまずマッチングサーバーのIPアドレスとポート番号を指定
//2. initClientSocketWithPort:　で自分のiPhoneの通信用ポート番号を指定
//3. findPartner で通信相手探索（このときスレッドの処理は相手が見つかるまで停止）見つかったらpartAddrに値が書き込まれる
//4. createP2PSocket でP2P通信用の準備をする
//5. waitForPartner で相手からのパケットを待つ。受信したものがメッセージだったらreceiveBufに格納(最大サイズP2PBUF)
//6. startSendingVoice で音声の送受信を開始。(talkingがYESになる)
//7. sendPartnerMessage: で相手にメッセージを送る。
//8. hangUp で音声通話を切る。(talkingがNOになる。相手が切ってもNOになる)
//8. 通信が終わったらcloseP2PSocketをする。

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#define SERVBUF 128
#define P2PBUF  8192


@interface P2PConnector : NSObject{
    struct sockaddr_in cliAddr;
    struct sockaddr_in servAddr;
    struct sockaddr_in partAddr;
    int       P2PSocket;
    int       flg;
    char receivedData[P2PBUF];
    NSString* receiveBuf;
    BOOL isTalking;
}

@property struct sockaddr_in cliAddr;
@property struct sockaddr_in servAddr;
@property struct sockaddr_in partAddr;
@property int       P2PSocket;
@property int       flg;
@property NSString* receiveBuf;
@property BOOL isTalking;

-(void)initServerSocketWithAddr:(NSString*)addr AndPort:(int)port;
-(void)initClientSocketWithPort:(int)port;
-(BOOL)findPartner;
-(BOOL)sendPartnerMessage:(NSString*)message;
-(BOOL)startSendingVoice;
-(BOOL)hangUp;
-(BOOL)createP2PSocket;
-(void)closeP2PSocket;
-(BOOL)waitForPartner;

@end
