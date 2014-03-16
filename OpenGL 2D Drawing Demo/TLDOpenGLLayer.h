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

/**
   Whether the content should be updated.

   @returns YES if content should be updated, NO otherwise.
 */
@property (assign, nonatomic) BOOL shouldUpdate;

/**
   Whether to limit the animation to ~30 FPS or let it run at max rate.

   @returns YES if limit is enforced, NO otherwise.
 */
@property (assign, nonatomic) BOOL limitFPS;

@end
