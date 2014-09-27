//
//  ADPCMEncoder.h
//  WebTest
//
//  Created by nariyuki on 9/26/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ADPCMEncoder : NSObject

-(void)decodeData:(char*)orgData withSize:(size_t)size toData:(int16_t *)decData;
-(void)encodeData:(int16_t *)orgData withSize:(size_t)size toData:(char *)encData;

@end
