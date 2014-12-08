//
//  MainViewController.m
//  WebTest
//
//  Created by nariyuki on 9/19/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "MainViewController.h"
#import "AppDelegate.h"


@implementation MainViewController

@synthesize connector;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AppDelegate *appdelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appdelegate setViewController:self];
    
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
    [call setTitle:@"発信" forState:UIControlStateNormal];
    [call addTarget:self action:@selector(startCalling:) forControlEvents:UIControlEventTouchUpInside];
    [call setFrame:CGRectMake((screenSize.width-200)/2-100, 300, 200, 100)];
    [self.view addSubview:call];
    
    hangUp=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [hangUp setTitle:@"通話切断" forState:UIControlStateNormal];
    [hangUp addTarget:self action:@selector(stopCalling:) forControlEvents:UIControlEventTouchUpInside];
    [hangUp setFrame:CGRectMake((screenSize.width-200)/2+100, 300, 200, 100)];
    [self.view addSubview:hangUp];
    
    /*hand=[[AudioHandler alloc]init];
    [hand startReceivingVoice];
    [hand startSendingVoice];*/
    
    [NSThread detachNewThreadSelector:@selector(connect) toTarget:self withObject:nil];
}

-(void)connect{
    [NSThread sleepForTimeInterval:1.0f];
    connector=[[P2PConnector alloc]initWithServerAddr:@"153.121.70.32"
                                           serverPort:5000
                                           clientPort:6000
                                             delegate:self
                                                   ID:@"iiii"];
    for(int i=0; i<100; i++ ){
        if( [connector findPartner]==NO ){
            if( i==99 ){
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
    
    [connector startWaitingForPartner];
    [connector sendPartnerMessage:@"P2P通信開始！"];
    
}

-(IBAction)startCalling:(id)sender{
    if( [connector call]==YES ){
        isTalking.text=@"呼び出し中...";
    }
}

-(IBAction)stopCalling:(id)sender{
    if( [connector hangUp]==YES ){
        isTalking.text=@"通話していません";
    }
    [hand stop];
}

-(void)didReceiveMessage:(NSString *)message{
    label.text=message;
    NSLog(@"received message: %@",message);
}

-(void)didReceiveHangUp{
    isTalking.text=@"相手が通話切断しました";
    NSLog(@"partner has hung up");
}

-(void)didReceiveCall{
    UIAlertView *alert = [[UIAlertView alloc] init];
    alert.delegate = self;
    alert.title = nil;
    alert.message = @"音声通話着信";
    [alert addButtonWithTitle:@"応答"];
    [alert addButtonWithTitle:@"拒否"];
    [alert show];
    NSLog(@"received call");
}

-(void)didReceiveResponse{
    isTalking.text=@"通話中";
    NSLog(@"partner has responded to call");
}

-(void)didReceiveDisconnection{
    isTalking.text=@"相手との通信が切断されました";
    NSLog(@"partner has disconnected");
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    NSString* msg=textField.text;
    [connector sendPartnerMessage:msg];
    return YES;
}

-(void)alertView:(UIAlertView*)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (buttonIndex) {
        case 0:
            [connector respond];
            isTalking.text=@"通話中";
            break;
        case 1:
            [connector hangUp];
            break;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

//