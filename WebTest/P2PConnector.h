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
//3. setID: で自分のIDナンバーを設定
//4. findPartner で通信相手探索（このときスレッドの処理は相手が見つかるまで停止）見つかったらpartAddrに値が書き込まれ、flgが1か2になる
//5. prepareP2PConnection でP2P通信用の準備をする
//6. waitForPartner で相手からのパケットを待つ。受信したものがメッセージだったらreceiveBufに格納(最大サイズP2PBUF)
//7. sendPartnerMessage: で相手にメッセージを送る。
//7. call で相手にコールのパケットを送る。
//8. startSendingVoice で音声の送受信を開始。(isTalkingがYESになる)
//9. hangUp で音声通話を切る。(isTalkingがNOになる。相手が切ってもNOになる)
//10. 通信が終わったらcloseP2PSocketをする。

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#define SERVBUF 128
#define P2PBUF 340
#define TIMEOUT 12 //マッチングタイムアウトの秒数。(サーバー側は10秒でタイムアウトする)
#define CALLOUT 12 //コールのタイムアウトの秒数。

@interface P2PConnector : NSObject{
    struct sockaddr_in cliAddr;
    struct sockaddr_in servAddr;
    struct sockaddr_in partAddr;
    int       P2PSocket;
    int       flg;
    NSString* receiveBuf;
    BOOL isCalling;
    BOOL isCalled;
    BOOL isTalking;
    NSString* ID;
}

@property struct sockaddr_in cliAddr;
@property struct sockaddr_in servAddr;
@property struct sockaddr_in partAddr;
@property int       P2PSocket;
@property int       flg;
@property NSString* receiveBuf;
@property BOOL isTalking;
@property NSString* ID;

-(void)initServerSocketWithAddr:(NSString*)addr AndPort:(int)port;
-(void)initClientSocketWithPort:(int)port;
-(BOOL)findPartner;
-(BOOL)sendPartnerMessage:(NSString*)message;
-(BOOL)startSendingVoice;
-(BOOL)hangUp;
-(BOOL)prepareP2PConnection;
-(BOOL)closeP2PSocket;
-(BOOL)waitForPartner;

@end
