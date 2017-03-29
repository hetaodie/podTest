//
//  ViewController.m
//  RTCAVCaptureDemo
//
//  Created by weixu on 2017/3/29.
//  Copyright © 2017年 weixu. All rights reserved.
//

#import "ViewController.h"
#import "CustomCapture.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (nonatomic ,strong) CustomCapture *customCapture;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.customCapture = [[CustomCapture alloc] init];
    AVCaptureVideoPreviewLayer *previewLayer = [self.customCapture getShowVideoLayer];
    previewLayer.frame = self.videoView.bounds;
    [self.videoView.layer addSublayer:previewLayer];
}

- (void)viewDidLayoutSubviews{
    [super updateViewConstraints];
    AVCaptureVideoPreviewLayer *previewLayer = [self.customCapture getShowVideoLayer];
    previewLayer.frame = self.videoView.bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)startBtnPress:(id)sender {
    [self.customCapture start];
}

- (IBAction)stopBtnPress:(id)sender {
    [self.customCapture stop];
}
@end
