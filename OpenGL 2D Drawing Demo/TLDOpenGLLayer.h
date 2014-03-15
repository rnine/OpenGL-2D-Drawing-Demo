//
//  TLDVectorscopeLayer.h
//  OpenGL 2D Drawing Demo
//
//  Created by Ruben Nine on 15/03/14.
//  Copyright (c) 2014 Ruben Nine. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

@interface TLDOpenGLLayer : CAOpenGLLayer

@property (assign, nonatomic) BOOL shouldUpdate;

@end
