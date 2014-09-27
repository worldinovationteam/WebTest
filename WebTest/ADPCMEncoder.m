//
//  ADPCMEncoder.m
//  WebTest
//
//  Created by nariyuki on 9/26/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "ADPCMEncoder.h"

@implementation ADPCMEncoder

const int StepsizeTable[89] = {7, 8, 9, 10, 11, 12, 13, 14,
                               16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60,
                               66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209,
                               230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
                               724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878,
                               2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871,
                               5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635,
                               13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
                               32767};

const int IndexTale[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};

-(void)decodeData:(char*)orgData withSize:(size_t)size toData:(int16_t *)decData{
    
    int16_t newSample=0;
    int index = 0;
    int stepsize = 7;
    int difference;
    char originalSample;
    
    /* compute predicted sample estimate newSample */
    /* calculate difference = (originalSample + 1⁄2) * stepsize/4: */
    for( int j=0; j<size*2; j++ ){
        
        if( j%2 ){
            originalSample = orgData[j] & 0b00001111;
        }else{
            originalSample = orgData[j] >> 4;
        }
        
        difference = 0b00000000;
        if (originalSample & 0b00000100) /* perform multiplication through repetitive addition */
            difference += stepsize;
        if (originalSample & 0b00000010)
            difference += stepsize >> 1;
        if (originalSample & 0b00000001)
            difference += stepsize >> 2;
        /* (originalSample + 1⁄2) * stepsize/4 =originalSample * stepsize/4 + stepsize/8: */
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
        decData[j]=newSample;
        /* compute new stepsize */
        /*adjust index into stepsize lookup table using originalSample: */
        index += IndexTale[originalSample];
        if (index < 0)
            index = 0;
        else if (index > 88)
            index = 88;
        stepsize = StepsizeTable[index];
    }
}

-(void)encodeData:(int16_t *)orgData withSize:(size_t)size toData:(char *)encData{
    
    int16_t predictedSample = 0;
    int index = 0;
    int stepsize = 7;
    int difference, mask, tempStepsize;
    char newSample;
    int i;
    
    for( int j=0; j<size/2; j++){
        difference = orgData[j]-predictedSample;
        
        //newSampleの符号を決定
        if (difference >= 0)
        {
            newSample = 0b00000000;
        } else {
            newSample = 0b00001000;
            difference = -difference;
        }
        
        mask = 0b00000100;
        tempStepsize = stepsize;
        
        for (i = 0; i < 3; i++) {
            
            if (difference >= tempStepsize)
            { /* newSample[2:0] = 4 * (difference/stepsize) */
                newSample |= mask; /* perform division ... */
                difference -= tempStepsize; /* ... through repeated subtraction */
            }
            tempStepsize >>=1; /* adjust comparator for next iteration */
            mask >>=1; /* adjust bit-set mask for next iteration */
        }
        
        /* 4-bit newSample can be stored at this point */
        if( j%2 ){
            encData[(j-1)/2]=1;//newSample;
        }else{
            newSample <<=4;
            encData[j/2] |= 1;//newSample;
        }
        
        /* compute new sample estimate predictedSample */
        difference = 0; // calculate difference = (newSample + 1⁄2) * stepsize/4 if (newSample & 4) // perform multiplication through repetitive addition
        if (newSample & 0b00000100)
            difference += stepsize;
        if (newSample & 0b00000010)
            difference += stepsize >> 1;
        if (newSample & 0b00000001)
                difference += stepsize >> 2;
        difference +=stepsize >> 3;
        /* (newSample + 1⁄2) * stepsize/4 = newSample * stepsize/4 + stepsize/8 */
        if (newSample & 8) /* account for sign bit */
            difference = -difference;
        /* adjust predicted sample based on calculated difference: */
        predictedSample += difference;
        if (predictedSample > 32767) /* check for overflow */
            predictedSample = 32767;
        else if (predictedSample < -32768)
            predictedSample = -32768;
        /* compute new stepsize */
        /* adjust index into stepsize lookup table using newSample */
        index += IndexTale[newSample];
        if (index < 0) /* check for index underflow */
            index = 0;
        else if (index > 88) /* check for index overflow */
            index = 88;
        stepsize = StepsizeTable[index]; /* find new quantizer stepsize */
    }
   
}

@end
