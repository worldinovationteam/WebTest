//
//  XMLDelegate.m
//  WebTest
//
//  Created by nariyuki on 7/13/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "XMLDelegate.h"

@implementation XMLDelegate

@synthesize elements,tmpTime,tmpCount,totalCount;

-(void)parserDidStartDocument:(NSXMLParser *)parser{
    //XMLパース開始
    [self setElements:[NSMutableDictionary dictionary]];
    [self setTotalCount:0];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    //XMLパース終了
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict{
    //エレメント読み込み開始
    if([elementName isEqualToString:@"Count"]){
        NSString* timeStr=[attributeDict objectForKey:@"Time"];
        NSDateFormatter* formatter=[[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"YYYYMMddHHmmss"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        NSDate* time=[formatter dateFromString:timeStr];
        [self setTmpTime:time];
        
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    //エレメントの取得,dictionaryに追加
    if(tmpTime!=nil){
        [self setTmpCount:[NSNumber numberWithInt:[string intValue]]];
        [elements setObject:tmpCount forKey:tmpTime];
        [self setTmpTime:nil];
        [self setTmpCount:nil];
        totalCount+=[string intValue];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
    NSLog(@"an error has occurred while parsing an XML file");
}


@end
