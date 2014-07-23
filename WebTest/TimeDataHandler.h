//
//  TimeDataHandler.h
//  WebTest
//
//  設定時刻の登録・削除および設定時刻の人数割合の取得をしたいとき、このクラスを呼び出してメソッドを実行する。
//
//  Created by nariyuki on 7/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum{ SET , CANCEL }uploadOption;

@interface TimeDataHandler : NSObject{
}

-(BOOL)uploadTime:(NSDate*)time toURL:(NSURL*)url withOption:(uploadOption)option;
/*
 設定時刻をサーバに登録・およびサーバから削除するメソッド。

 登録したいとき: timeに登録したい設定時刻,optionにSETを入れて実行。
 削除したいとき: timeに削除したい設定時刻,optionにCANCELを入れて実行。
 
 urlはサーバ側で処理するphpファイル(info_upload.php)のURLを入れる。
 返り値は登録成功したらYES,失敗したらNO。
 */

-(NSDictionary*)getDistributionOfTimeSettingFrom:(NSDate*)time1 To:(NSDate*)time2 FromURL:(NSURL*)url;
/*
 サーバに登録されている時刻ごとの人数割合を取得するメソッド。
 
 取得する時刻範囲はtime1からtime2まで。
 urlはサーバ側で処理するphpファイル(info_distribution.php)のURLを入れる。
 返り値は 「キー:時刻　オブジェクト:その時刻の人数割合（パーセント）」の形のNSDictionary。
 ただし、取得に失敗したり、time1からtime2までに誰も登録していなかったりしたらnilが返ってくる。
 */

@end
