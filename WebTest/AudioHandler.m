//
//  AudioHandler.m
//  WebTest
//
//  Created by nariyuki on 9/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "AudioHandler.h"

@implementation AudioHandler

int stepsizeTable[89] = {7, 8, 9, 10, 11, 12, 13, 14,
    16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60,
    66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209,
    230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
    724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878,
    2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871,
    5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635,
    13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
    32767};

int stepsizetable[89] = {7, 8, 9, 10, 11, 12, 13, 14,
    16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60,
    66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209,
    230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
    724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878,
    2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871,
    5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635,
    13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
    32767};

int indexTable[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};

int indextable[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};

void AudioInputtCallback(
                                void* inUserData,
                                AudioQueueRef inAQ,
                                AudioQueueBufferRef inBuffer,
                                const AudioTimeStamp *inStartTime,
                                UInt32 inNumberPacketDescriptions,
                                const AudioStreamPacketDescription *inPacketDescs){

    int16_t tmpdata[PPBUF];
    int16_t *datapt=(int16_t *)inBuffer->mAudioData;
    
    int predictedSample = 0;
    int index = 0;
    unsigned int stepsize = 7;
    int difference, tempStepsize;
    unsigned char newSample;
    int i;

    for(i=0; i<PPBUF; i++){
        tmpdata[i] = datapt[4*i];
    }
        
    for( int j=0; j<PPBUF; j++){
        difference = tmpdata[j]-predictedSample;
        
        //newSampleの符号を決定
        if (difference >= 0)
        {
            newSample = 0b00000000;
        } else {
            newSample = 0b00001000;
            difference = -difference;
        }
        
        //newSampleの計算
        tempStepsize = stepsize;
        
        if(difference>=tempStepsize){
            newSample |= 0b00000100;
            difference-=tempStepsize;
        }
        tempStepsize>>=1;
        if(difference>=tempStepsize){
            newSample |= 0b00000010;
            difference-=tempStepsize;
        }
        tempStepsize>>=1;
        if(difference>=tempStepsize){
            newSample |= 0b00000001;
        }

        /* 4-bit newSample can be stored at this point */
        if( j%2==1 ){
            data[(j-1)/2] |= newSample;
        }else{
            data[j/2] = newSample<<4;
        }
        
        /* compute new sample estimate predictedSample */
        difference = stepsize >> 3;; // calculate difference = (newSample + 1⁄2) * stepsize/4 if (newSample & 4) // perform multiplication through repetitive addition
        if (newSample & 0b00000100)
            difference += stepsize;
        if (newSample & 0b00000010)
            difference += stepsize >> 1;
        if (newSample & 0b00000001)
            difference += stepsize >> 2;

        /* (newSample + 1⁄2) * stepsize/4 = newSample * stepsize/4 + stepsize/8 */
        if (newSample & 0b00001000 ) /* account for sign bit */
            difference = -difference;
        /* adjust predicted sample based on calculated difference: */
        predictedSample += difference;
        if (predictedSample > 32767) /* check for overflow */
            predictedSample = 32767;
        else if (predictedSample < -32768)
            predictedSample = -32768;
        
        /* compute new stepsize */
        /* adjust index into stepsize lookup table using newSample */
        int diffindex=indexTable[newSample];
        index += diffindex;
        if (index < 0) /* check for index underflow */
            index = 0;
        else if (index > 88) /* check for index overflow */
            index = 88;
        stepsize = stepsizeTable[index]; /* find new quantizer stepsize */
        
        if( j>1015 || j<2 )NSLog(@"j = %d, index = %d, orgdata = %d ",j,index,datapt[j]);
        if( j==1023 )NSLog(@" ");
    }
    
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

void AudioOutputtCallback (
                                  void                 *inUserData,
                                  AudioQueueRef        inAQ,
                                  AudioQueueBufferRef  inBuffer
                                  ){
    inBuffer->mAudioDataByteSize=PPBUF;
    int16_t* datapt= (int16_t *)(inBuffer->mAudioData);
    
    int newSample=0;
    int index = 0;
    int stepsize = 7;
    int difference;
    char originalSample,tmpdata;
 
    for( int j=0; j<PPBUF; j++ ){
        
        tmpdata=data[j/2];
        
        if( j%2==1 ){
            originalSample = tmpdata & 0b00001111;
        }else{
            originalSample = tmpdata >> 4;
        }
        
        difference = 0b00000000;
        if (originalSample & 0b00000100) /* perform multiplication through repetitive addition */
            difference += stepsize;
        if (originalSample & 0b00000010)
            difference += stepsize >> 1;
        if (originalSample & 0b00000001)
            difference += stepsize >> 2;
        difference += stepsize >> 3;
        
        if (originalSample & 0b00001000) /* account for sign bit */
            difference = -difference;
        
        /* adjust predicted sample based on calculated difference: */
        newSample += difference;
        
        if (newSample > 32767) /* check for overflow */
            newSample = 32767;
        else if (newSample < -32768)
            newSample = -32768;
        /* 16-bit newSample can be stored at this point */
        
        datapt[j]=newSample;
        
        /* compute new stepsize */
        /*adjust index into stepsize lookup table using originalSample: */
        index += indextable[originalSample];
        if (index < 0){
            index = 0;
        }else if (index > 88){
            index = 88;
        }
        
        stepsize = stepsizetable[index];
        
        if( j>1015 || j<2 )NSLog(@"j = %d, index = %d, outdata = %d ",j,index,datapt[j]);
        if( j==1023 )NSLog(@" ");

    }
    
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    
}

-(BOOL)startSendingVoice{
    AudioStreamBasicDescription dataFormat;
    AudioQueueRef inQueue,outQueue;
    AudioQueueBufferRef inBuffer[NUMBUF];
    AudioQueueBufferRef outBuffer[NUMBUF];
    
    
     // Linear PCM 16000 Hz
     dataFormat.mSampleRate = 16000.0f;
     dataFormat.mFormatID = kAudioFormatLinearPCM;
     dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
     dataFormat.mBytesPerPacket = 2;
     dataFormat.mFramesPerPacket = 1;
     dataFormat.mBytesPerFrame = 2;
     dataFormat.mChannelsPerFrame = 1;
     dataFormat.mBitsPerChannel = 16;
     dataFormat.mReserved = 0;
    
    /*
    dataFormat.mSampleRate = 16000.0f;
    dataFormat.mFormatID = kAudioFormatAppleIMA4;
    dataFormat.mBytesPerPacket = 34;
    dataFormat.mFormatFlags=0;
    dataFormat.mFramesPerPacket = 64;
    dataFormat.mBytesPerFrame = 0; //compressed dataにたいしては0
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 0; //compressed dataにたいしては0
    */
    OSStatus stat;
    
    
    
    for(int i=0; i<PPBUF; i++){
        data[i]=0;
    }
    
    stat=AudioQueueNewOutput(&dataFormat, AudioOutputtCallback, NULL, NULL, NULL, 0, &outQueue);
    if( stat ){
        printf("new %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<NUMBUF; i++){
        AudioQueueAllocateBuffer(outQueue,PPBUF*2,outBuffer+i);
        AudioOutputtCallback(NULL, outQueue, outBuffer[i]);
    }
    
    /*
    stat=AudioQueueNewInput(&dataFormat, AudioInputtCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &inQueue);
    if( stat ){
        printf("new %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<NUMBUF; i++){
        stat=AudioQueueAllocateBuffer(inQueue,PPBUF,inBuffer+i);
        stat=AudioQueueEnqueueBuffer(inQueue,inBuffer[i],0,NULL);
        if( stat ){
            printf("input enqueue %d\n",(int)stat);
            return NO;
        }
    }
    
    stat=AudioQueueStart(inQueue, NULL);
    printf("input start %d\n",(int)stat);*/
    stat=AudioQueueStart(outQueue, NULL);
    printf("output start %d\n",(int)stat);
    
    NSLog(@"audio started");
    return YES;
}

-(BOOL)startReceivingVoice{
    AudioStreamBasicDescription dataFormat;
    AudioQueueRef inQueue,outQueue;
    AudioQueueBufferRef inBuffer[NUMBUF];
    AudioQueueBufferRef outBuffer[NUMBUF];
    
    
     // Linear PCM 44100 Hz
     dataFormat.mSampleRate = 64000.0f;
     dataFormat.mFormatID = kAudioFormatLinearPCM;
     dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
     dataFormat.mBytesPerPacket = 2;
     dataFormat.mFramesPerPacket = 1;
     dataFormat.mBytesPerFrame = 2;
     dataFormat.mChannelsPerFrame = 1;
     dataFormat.mBitsPerChannel = 16;
     dataFormat.mReserved = 0;
    
    /*
    dataFormat.mSampleRate = 64000.0f;
    dataFormat.mFormatID = kAudioFormatAppleIMA4;
    dataFormat.mBytesPerPacket = 34;
    dataFormat.mFormatFlags=0;
    dataFormat.mFramesPerPacket = 64;
    dataFormat.mBytesPerFrame = 0; //compressed dataにたいしては0
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 0; //compressed dataにたいしては0
    */
    OSStatus stat;
    
    stat=AudioQueueNewInput(&dataFormat, AudioInputtCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &inQueue);
    if( stat ){
        printf("new %d\n",(int)stat);
        return NO;
    }
    
    for(int i=0; i<NUMBUF; i++){
        stat=AudioQueueAllocateBuffer(inQueue,PBUF*2,inBuffer+i);
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