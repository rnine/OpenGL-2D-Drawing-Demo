//
//  TLDAppDelegate.m
//  OpenGL 2D Drawing Demo
//
//  Created by Ruben Nine on 15/03/14.
//  Copyright (c) 2014 Ruben Nine. All rights reserved.
//

#import "TLDAppDelegate.h"
#import "TLDOpenGLLayer.h"

@interface TLDAppDelegate ()

@property (strong, nonatomic) TLDOpenGLLayer *openGLLayer;

@end

@implementation TLDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.openGLLayer = [TLDOpenGLLayer layer];
    self.layerHostView.wantsLayer = YES;
    self.layerHostView.layer = self.openGLLayer;
}

- (IBAction)shouldDraw:(id)sender
{
    self.openGLLayer.shouldUpdate = [sender state] == NSOnState;
}

@end
