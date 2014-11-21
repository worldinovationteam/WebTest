//
//  RespondViewController.h
//  WebTest
//
//  Created by nariyuki on 11/22/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "P2PConnector.h"

@interface RespondViewController : UIViewController<P2PConnectorDelegate>{
    P2PConnector* connector;
    UIImageView* fr;
    UILabel* label;
    UILabel* isTalking;
    UIButton* call;
    UIButton* hangUp;
    CGSize screenSize;
}

@property P2PConnector* connector;

@end
