//
//  ViewController.m
//  WebTest
//
//  Created by nariyuki on 7/4/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "ViewController.h"
#import "TimeDataHandler.h"
#import "XMLDelegate.h"
#import "P2PConnector.h"
#import "AudioHandler.h"

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    screenSize=[[UIScreen mainScreen] bounds].size;
    
    UITextField *textField = [[UITextField alloc]initWithFrame:CGRectMake((screenSize.width-300)/2, 100, 300, 40)];
    textField.delegate = self;
    textField.borderStyle=UITextBorderStyleBezel;
    [self.view addSubview:textField];
    
    label=[[UILabel alloc]init];
    label.textAlignment=NSTextAlignmentCenter;
    label.frame=CGRectMake((screenSize.width-300)/2, 150, 300, 40);
    label.text=@"相手探索中";
    [self.view addSubview:label];
    
    isTalking=[[UILabel alloc]init];
    isTalking.textAlignment=NSTextAlignmentCenter;
    isTalking.frame=CGRectMake((screenSize.width-300)/2, 250, 300, 40);
    isTalking.text=@"通話していません";
    [self.view addSubview:isTalking];
    
    call=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [call setTitle:@"通話開始" forState:UIControlStateNormal];
    [call addTarget:self action:@selector(startCalling:) forControlEvents:UIControlEventTouchUpInside];
    [call setFrame:CGRectMake((screenSize.width-200)/2, 300, 200, 100)];
    
    hangUp=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [hangUp setTitle:@"通話切断" forState:UIControlStateNormal];
    [hangUp addTarget:self action:@selector(stopCalling:) forControlEvents:UIControlEventTouchUpInside];
    [hangUp setFrame:CGRectMake((screenSize.width-200)/2, 300, 200, 100)];
    
    [NSThread detachNewThreadSelector:@selector(connect) toTarget:self withObject:nil];
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.5f
                                                      target:self
                                                    selector:@selector(reloadText:)
                                                    userInfo:nil
                                                     repeats:YES];
    [timer fire];

}

-(void)connect{
    connector=[[P2PConnector alloc]init];
    [connector initServerSocketWithAddr:@"153.121.70.32" AndPort:5000];
    [connector initClientSocketWithPort:6000];
    
    //俺はこれを設定する
    //[connector setID:@"NoridukiVeryHappy"];
    //君はこれを設定してくれ
    [connector setID:@"SaitoReallyLucky"];
    
    for(int i=0; i<3; i++ ){
        if( [connector findPartner]==NO ){
            if( i==2 ){
                [label setText:@"だめでした。やり直してください"];
                return;
            }else{
                continue;
            }
        }else{
            break;
        }
    }
    
    if( [connector prepareP2PConnection]==NO ){
        label.text = @"パートナーとの接続に失敗しました";
        return;
    }
    
    [NSThread detachNewThreadSelector:@selector(waitForPartner) toTarget:connector withObject:nil];
    [connector sendPartnerMessage:@"P2P通信開始！"];
    [self.view addSubview:call];
}

-(IBAction)startCalling:(id)sender{
    [connector startSendingVoice];
    [call removeFromSuperview];
    [self.view addSubview:hangUp];
}

-(IBAction)stopCalling:(id)sender{
    [connector hangUp];
    [hangUp removeFromSuperview];
    [self.view addSubview:call];
}

-(IBAction)reloadText:(id)sender{
    if(connector.receiveBuf!=nil){
        label.text=connector.receiveBuf;
    }
    
    if( connector.isTalking ){
        isTalking.text=@"通話中";
    }else{
        isTalking.text=@"通話していません";
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    NSString* msg=textField.text;
    [connector sendPartnerMessage:msg];
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
