//
//  TimeDataHandler.m
//  WebTest
//
//  Created by nariyuki on 7/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "TimeDataHandler.h"
#import "XMLDelegate.h"


@implementation TimeDataHandler


-(BOOL)uploadTime:(NSDate*)time toURL:(NSURL*)url withOption:(uploadOption)option{
    
    //時刻データの準備
    NSDateFormatter* formatter=[[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"YYYYMMddHHmmss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSString* timeStr=[@"time=" stringByAppendingString:[formatter stringFromDate:time]];
    if( option==SET ){
        timeStr=[timeStr stringByAppendingString:@"&option=1"];
    }else{
        timeStr=[timeStr stringByAppendingString:@"&option=0"];
    }
    NSData* timeData=[timeStr dataUsingEncoding:NSUTF8StringEncoding];
    
    
    //HTTPリクエストの作成
    NSMutableURLRequest* postRequest=[[NSMutableURLRequest alloc]init];
    [postRequest setHTTPMethod:@"POST"];
    [postRequest setURL:url];
    [postRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [postRequest setTimeoutInterval:20];
    [postRequest setHTTPShouldHandleCookies:FALSE];
    [postRequest setHTTPBody:timeData];
     
    //同期通信で送信
    NSURLResponse *response = nil;
    NSError *error = nil;
    [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
    if(error!=nil){
        NSLog(@"upload connection failed");
        return NO;
    }else{
        NSLog(@"upload connection succeeded");
        return YES;
    }
    
}

-(NSDictionary*)getDistributionOfTimeSettingFrom:(NSDate*)time1 To:(NSDate*)time2 FromURL:(NSURL *)url{
    
    //時刻データ・URLの準備
    NSDateFormatter* formatter=[[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"YYYYMMddHHmmss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSString* timeStr1=[@"?time1=" stringByAppendingString:[formatter stringFromDate:time1]];
    NSString* timeStr=[timeStr1 stringByAppendingString:[@"&time2=" stringByAppendingString:[formatter stringFromDate:time2]]];
    NSURL* getUrl=[NSURL URLWithString:[[url absoluteString] stringByAppendingString:timeStr]];

    //HTTPリクエストの作成
    NSMutableURLRequest* getRequest=[[NSMutableURLRequest alloc]init];
    [getRequest setHTTPMethod:@"GET"];
    [getRequest setURL:getUrl];
    [getRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [getRequest setTimeoutInterval:20];
    [getRequest setHTTPShouldHandleCookies:FALSE];
    [getRequest setHTTPBody:nil];
    
    //同期通信で送信,取得したXMLデータをNSMutableDictionaryに収納
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData* data=[NSURLConnection sendSynchronousRequest:getRequest returningResponse:&response error:&error];
    if(error!=nil){
        NSLog(@"download connection failed");
        return nil;
    }else{
        NSLog(@"download connection succeeded");
        NSXMLParser* parser=[[NSXMLParser alloc]initWithData:data];
        XMLDelegate* delegate=[[XMLDelegate alloc]init];
        parser.delegate=delegate;
        [parser parse];
        NSMutableDictionary* countDic=[delegate elements];
        
        //収納したカウント数を割合に変換
        int totalCount=[delegate totalCount];
        if(totalCount==0){
            return nil;
        }else{
            NSMutableDictionary* percentageDic=[NSMutableDictionary dictionary];
            id key;
            NSEnumerator* enumerator=[countDic keyEnumerator];
            while(key=[enumerator nextObject])
            {
                NSNumber* num=[NSNumber numberWithDouble:[[countDic objectForKey:key] doubleValue]*100.0/totalCount];
                [percentageDic setObject:num forKey:key];
            }
            return percentageDic;
        }
    }
}


@end
