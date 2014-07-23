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
#import "UDPConnector.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UITextField *textField = [[UITextField alloc]initWithFrame:CGRectMake(100, 100, 100, 40)];
    textField.delegate = self;
    textField.borderStyle=UITextBorderStyleBezel;
    [self.view addSubview:textField];
    
    label=[[UILabel alloc]init];
    label.frame=CGRectMake(100, 300, 150, 40);
    label.text=@"相手探索中";
    [self.view addSubview:label];
    
    [NSThread detachNewThreadSelector:@selector(connect) toTarget:self withObject:nil];
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.5f
                                                      target:self
                                                    selector:@selector(reloadText:)
                                                    userInfo:nil
                                                     repeats:YES];
    [timer fire];

}

-(void)connect{
    connector=[[UDPConnector alloc]init];
    [connector initServerSocketWithAddr:@"153.121.70.32" AndPort:5000];
    [connector initClientSocketWithPort:6000];
    [connector findPartner];
    [connector createP2PSocket];
    
    count=0;
    
    [NSThread detachNewThreadSelector:@selector(waitForPartner) toTarget:connector withObject:nil];
    
}

-(IBAction)reloadText:(id)sender{
    if(connector.receiveBuf!=nil){
        label.text=connector.receiveBuf;
    }else if(connector.flg==1||connector.flg==2){
        label.text=@"相手発見！";
    }else{
        label.text=@"相手探索中";
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
