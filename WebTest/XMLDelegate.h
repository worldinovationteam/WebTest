//
//  XMLDelegate.h
//  WebTest
//
//  このクラスはTimeDataHandler内で勝手に呼び出されるだけなので、明示的に使う必要なない。
//
//  Created by nariyuki on 7/13/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XMLDelegate : NSObject<NSXMLParserDelegate>{
    NSMutableDictionary* elements; //取得した要素(time,count)
    NSDate* tmpTime;               //一時保存用
    NSNumber* tmpCount;            //一時保存用
    int totalCount;                //カウントの総和
}

@property NSMutableDictionary* elements;
@property NSDate* tmpTime;
@property NSNumber* tmpCount;
@property int totalCount;

@end
