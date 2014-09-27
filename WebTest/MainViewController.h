//
//  MainViewController.h
//  WebTest
//
//  Created by nariyuki on 9/19/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimeDataHandler.h"
#import "XMLDelegate.h"
#import "P2PConnector.h"
#import "AudioHandler.h"

@interface MainViewController : UIViewController<UITextFieldDelegate, UIAlertViewDelegate, P2PConnectorDelegate>{
    P2PConnector* connector;
    UILabel* label;
    UILabel* isTalking;
    UIButton* call;
    UIButton* hangUp;
    CGSize screenSize;
}

@property P2PConnector* connector;

@end
