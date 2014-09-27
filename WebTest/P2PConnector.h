//
//  P2PConnector.h
//  WebTest
//
//  Created by nariyuki on 7/16/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//
//<使い方>
//1. イニシャライザで必要なパラメータ(マッチングサーバのアドレスとポート、自分のポート、P2P通信の受信時に通知するデリゲート、自分のID)を設定する。
//   デリゲートには必ずP2PConnectorDelegateプロトコルを採用する。
//2. findPartner で通信相手探索（このときスレッドの処理は相手が見つかるまで停止）見つかったらpartAddrに値が書き込まれ、flgが1か2になる
//3. prepareP2PConnection でP2P通信用の準備をする。成功するとisConnectedがYESになる。
//4. startWaitingForPartner で相手からのパケットの受信を開始する。
//   受信したものが#msg#から始まるメッセージだったらデリゲートのdidReceiveMessage:が呼ばれてメッセージが渡される(最大サイズP2PBUF)
//   受信したものが#hup#だったらisTalking, isCalling, isCalledをすべてNOにする。さらに通話中の場合は音声送受信を停止(切断通知)。デリゲートのdidReceiveHangUpが呼ばれる
//   受信したものが#cal#だったら, isTalking=isCalling=isCalled=NOの場合に限りisCalledをYESにする(着信)。デリゲートのdidReceiveCallが呼ばれる
//   受信したものが#cok#だったら, isCalling=YES, isCalled=isTalking=NOの場合に限り, 音声通話を開始、isTalkingをYES, isCallingをNOにする(通話承諾)。デリゲートのdidReceiveResponseが呼ばれる
//   受信したものが#dis#だったら、 isCalling, isTalking, isCalled, isConnectedをすべてNOにし、P2PSocketをcloseする。デリゲートのdidReceiveDisconnectionが呼ばれる
//5. sendPartnerMessage: で相手にメッセージを送る。
//5. call でisCalling=isTalking=isCalled=NOの場合に限り、相手に#cal#を送り、通話を発信する。isCallingをYESにする。
//5. respond でisCalled=YES, isCalling=isTalking=NOの場合に限り、相手に#cok#を送り、音声通話を開始、isTalkingをYES, isCalledをNOにする。
//5. hangUp で音声送受信を停止/着信拒否/発信中止。isTalking, isCalling, isCalledがNOになる。相手に#hup#を送る。
//6. 通信が終わったらcloseP2PSocketをする。相手に#dis#を送り、通信切断を通知。この後はパケットの受信が停止し、送信もできなくなる。
//
//*音声通信にはIMA/ADPCMで圧縮した64 kbit/sの信号を用いる。サンプリング周波数16000 Hz, フレーム長64 ms.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@protocol P2PConnectorDelegate;

@interface P2PConnector : NSObject{
    id <P2PConnectorDelegate> delegate;
    struct sockaddr_in cliAddr;
    struct sockaddr_in servAddr;
    struct sockaddr_in partAddr;
    int  P2PSocket;
    int  flg;
    BOOL isConnected;
    BOOL isCalling;
    BOOL isCalled;
    BOOL isTalking;
    NSString* ID;
}

@property id <P2PConnectorDelegate> delegate;
@property struct sockaddr_in cliAddr;
@property struct sockaddr_in servAddr;
@property struct sockaddr_in partAddr;
@property (readonly) int  P2PSocket;
@property (readonly) int  flg;
@property (readonly) BOOL isConnected;
@property (readonly) BOOL isCalling;
@property (readonly) BOOL isCalled;
@property (readonly) BOOL isTalking;
@property NSString* ID;

-(id)initWithServerAddr:(NSString*)addr serverPort:(int)sport clientPort:(int)cport delegate:(id <P2PConnectorDelegate>)object ID:(NSString*)idstr;
-(BOOL)findPartner;
-(BOOL)sendPartnerMessage:(NSString*)message;
-(BOOL)call;
-(BOOL)respond;
-(BOOL)hangUp;
-(BOOL)prepareP2PConnection;
-(BOOL)closeP2PSocket;
-(BOOL)startWaitingForPartner;

@end

@protocol P2PConnectorDelegate <NSObject>

@required
-(void)didReceiveMessage:(NSString*)message;
-(void)didReceiveHangUp;
-(void)didReceiveCall;
-(void)didReceiveResponse;
-(void)didReceiveDisconnection;

@end
