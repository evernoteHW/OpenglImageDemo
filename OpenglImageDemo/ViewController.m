//
//  ViewController.m
//  OpenglImageDemo
//
//  Created by WeiHu on 16/7/20.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    OpenGLView *glView = [[OpenGLView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height )];
    [self.view addSubview:glView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
