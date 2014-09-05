//
//  AudioHandler.m
//  WebTest
//
//  Created by nariyuki on 9/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "AudioHandler.h"

@implementation AudioHandler

void AudioInputtCallback(
                                void* inUserData,
                                AudioQueueRef inAQ,
                                AudioQueueBufferRef inBuffer,
                                const AudioTimeStamp *inStartTime,
                                UInt32 inNumberPacketDescriptions,
                                const AudioStreamPacketDescription *inPacketDescs){
    //printf("audio input\n");
    char *datapt=(char *)inBuffer->mAudioData;
    for(int i=0; i<PPBUF; i++){
        data[i] = datapt[i]*3;
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

void AudioOutputtCallback (
                                  void                 *inUserData,
                                  AudioQueueRef        inAQ,
                                  AudioQueueBufferRef  inBuffer
                                  ){
    //printf("audio output\n");
    inBuffer->mAudioDataByteSize=PPBUF;
    char* datapt= (char *)(inBuffer->mAudioData);
    for(int i=0; i<PPBUF; i++){
        datapt[i]=data[i];
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    //printf("out queue %d\n",(int)stat);
}

-(BOOL)startSendingVoice{
    AudioStreamBasicDescription dataFormat;
    AudioQueueRef inQueue,outQueue;
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
    
    for(int i=0; i<PPBUF; i++){
        data[i]=0;
    }
    
    stat=AudioQueueNewOutput(&dataFormat, AudioOutputtCallback, NULL, NULL, NULL, 0, &outQueue);
    if( stat ){
        printf("new %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<3; i++){
        AudioQueueAllocateBuffer(outQueue,PPBUF,outBuffer+i);
        AudioOutputtCallback(NULL, outQueue, outBuffer[i]);
    }
    
    stat=AudioQueueStart(outQueue, NULL);
    printf("output start %d\n",(int)stat);
    
    stat=AudioQueueNewInput(&dataFormat, AudioInputtCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &inQueue);
    if( stat ){
        printf("new %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<3; i++){
        stat=AudioQueueAllocateBuffer(inQueue,PPBUF,inBuffer+i);
        stat=AudioQueueEnqueueBuffer(inQueue,inBuffer[i],0,NULL);
        if( stat ){
            printf("input enqueue %d\n",(int)stat);
            return NO;
        }
    }
    
    stat=AudioQueueStart(inQueue, NULL);
    printf("input start %d\n",(int)stat);
    
    NSLog(@"audio started");
    return YES;
}

@end