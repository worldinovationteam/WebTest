//
//  AudioHandler.h
//  WebTest
//
//  Created by nariyuki on 9/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#define PPBUF 1024
#define PBUF 4096
#define NUMBUF 3

char data[PPBUF/2];

@interface AudioHandler : NSObject{
}

-(BOOL)startSendingVoice;
-(BOOL)startReceivingVoice;
-(BOOL)stop;

@end
