//
//  RespondViewController.m
//  WebTest
//
//  Created by nariyuki on 11/22/14.
//  Copyright (c) 2014 Nariyuki Saito. All rights reserved.
//

#import "RespondViewController.h"

@interface RespondViewController ()

@end

@implementation RespondViewController

@synthesize connector;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    screenSize=[[UIScreen mainScreen] bounds].size;
    self.view.backgroundColor=[UIColor blackColor];
    int buttonheight=screenSize.height*0.1;
    int buttonwidth=buttonheight*3;
    int dropheight=screenSize.height*0.3;
    
    fr=[[UIImageView alloc]init];
    fr.image = [UIImage imageNamed:@"drop.png"];
    fr.frame = CGRectMake((screenSize.width-dropheight)*0.5,screenSize.height*0.2,dropheight,dropheight);
    [self.view addSubview:fr];
    
    call=[UIButton buttonWithType:UIButtonTypeCustom];
    [call setBackgroundImage:[UIImage imageNamed:@"respond.png"] forState:UIControlStateNormal];
    [call addTarget:self action:@selector(startCalling:) forControlEvents:UIControlEventTouchUpInside];
    [call setFrame:CGRectMake((screenSize.width-buttonwidth)*0.5,screenSize.height*0.2+dropheight+10,buttonwidth,buttonheight)];
    [self.view addSubview:call];
    
    hangUp=[UIButton buttonWithType:UIButtonTypeCustom];
    [hangUp setBackgroundImage:[UIImage imageNamed:@"exit.png"] forState:UIControlStateNormal];
    [hangUp addTarget:self action:@selector(stopCalling:) forControlEvents:UIControlEventTouchUpInside];
    [hangUp setFrame:CGRectMake((screenSize.width-buttonwidth)*0.5,screenSize.height*0.2+dropheight+10,buttonwidth,buttonheight)];
    
    label=[[UILabel alloc]init];
    label.textColor=[UIColor whiteColor];
    label.textAlignment=NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth=YES;
    label.font=[UIFont systemFontOfSize:100.0f];
    label.frame=CGRectMake(screenSize.width*0.2,screenSize.height*0.25,screenSize.width*0.6,screenSize.height*0.1);
    label.text=@"お待ちください...";
    
}

-(void)connect{
    [NSThread sleepForTimeInterval:1.0f];
    int port=(arc4random()%40000)+1024;
    connector=[[P2PConnector alloc]initWithServerAddr:@"153.121.70.32"
                                           serverPort:5000
                                           clientPort:port
                                             delegate:self
                                                   ID:@"法月"];
    for(int i=0; i<100; i++ ){
        if( [connector findPartner]==NO ){
            if( i==99 ){
                return;
            }else{
                continue;
            }
        }else{
            break;
        }
    }
    
    if( [connector prepareP2PConnection]==NO ){
        return;
    }
    
    [connector startWaitingForPartner];
    if([connector flg]==1){
        [connector call];
    }
    
    [connector sendPartnerMessage:@"P2P通信開始！"];
    
    fr.alpha=0.0f;
    NSString* tmp=@"通話中: ";
    label.text=[tmp stringByAppendingString:[connector partnerID]];
    
    [self.view addSubview:hangUp];
}

-(IBAction)startCalling:(id)sender{
    [NSThread detachNewThreadSelector:@selector(connect) toTarget:self withObject:nil];
    [call removeFromSuperview];
    fr.alpha=0.5f;
    [self.view addSubview:label];
}

-(IBAction)stopCalling:(id)sender{
    if( [connector hangUp]==YES ){
        [hangUp removeFromSuperview];
        label.text=@"通話終了しました";
    }
}

-(void)didReceiveMessage:(NSString *)message{
    NSLog(@"received message: %@",message);
}

-(void)didReceiveHangUp{
    NSLog(@"partner has hung up");
    [hangUp removeFromSuperview];
    label.text=@"通話終了しました";
}

-(void)didReceiveCall{
    NSLog(@"received call");
    [connector respond];
}

-(void)didReceiveResponse{
    NSLog(@"partner has responded to call");
}

-(void)didReceiveDisconnection{
    NSLog(@"partner has disconnected");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
