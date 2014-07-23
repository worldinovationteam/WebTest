//
//  ViewController.h
//  WebTest
//
//  Created by nariyuki on 7/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimeDataHandler.h"
#import "XMLDelegate.h"
#import "UDPConnector.h"

@interface ViewController : UIViewController<UITextFieldDelegate>{
    UDPConnector* connector;
    UILabel* label;
    int count;
}

@end
