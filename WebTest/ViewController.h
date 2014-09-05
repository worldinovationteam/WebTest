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
#import "P2PConnector.h"

@interface ViewController : UIViewController<UITextFieldDelegate>{
    P2PConnector* connector;
    UILabel* label;
    UILabel* isTalking;
    UIButton* call;
    UIButton* hangUp;
    CGSize screenSize;
}

@end
