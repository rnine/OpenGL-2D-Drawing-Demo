//
//  TLDVectorscopeLayer.m
//  OpenGL 2D Drawing Demo
//
//  Created by Ruben Nine on 15/03/14.
//  Copyright (c) 2014 Ruben Nine. All rights reserved.
//

#import "TLDOpenGLLayer.h"
#import "error.h"
#import <OpenGL/gl3.h>
#import <GLKit/GLKMath.h>

typedef NS_ENUM (NSUInteger, Uniforms)
{
    kMeterUniform = 0,
    kModelViewProjectionMatrixUniform,
    kNumUniforms
};

typedef NS_ENUM (NSUInteger, Textures)
{
    kBackgroundTexture = 0,
    kNumTextures
};

typedef struct
{
    GLfloat x, y;
} Vector2;

typedef struct
{
    Vector2 vertices;
    Vector2 textCoords;
} VertexTextCoords;

typedef struct
{
    GLuint index;
    CGSize dimensions;
} TextureInfo;

#pragma mark -

@interface TLDOpenGLLayer ()
{
    GLuint _shaderProgram;
    GLuint _vao;
    GLuint _vbo;

    GLint _uniforms[kNumUniforms];
    TextureInfo _textures[kNumTextures];

    GLint _colorAttribute;
    GLint _positionAttribute;
    GLint _textCoordAttribute;

    CGRect _oldBounds;
    GLKMatrix4 _orthoMat;

    CFTimeInterval _oldTimeInterval;
}
@end

#pragma mark -

@implementation TLDOpenGLLayer

- (id)init
{
    self = [super init];

    if (self)
    {
        self.needsDisplayOnBoundsChange = YES;
        self.asynchronous = YES;
        self.shouldUpdate = YES;
        self.limitFPS = NO;
    }

    return self;
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat
{
    CGLContextObj context = NULL;

    CGLCreateContext(pixelFormat, NULL, &context);

    if (context || (context = [super copyCGLContextForPixelFormat:pixelFormat]))
    {
        //Setup any OpenGL state, make sure to set the context before invoking OpenGL
        CGLContextObj currContext = CGLGetCurrentContext();
        CGLSetCurrentContext(context);

        [self loadShader];
        [self loadTextureData];

        glClearColor(0.0, 0.0, 0.2, 1.0);
        GetError();

        //Issue any calls that require the context here.
        CGLSetCurrentContext(currContext);
    }

    return context;
}

- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask
{
    CGLPixelFormatAttribute attribs[] =  {
        kCGLPFADisplayMask, 0,
        kCGLPFAColorSize, 24,
        kCGLPFAAlphaSize, 8,
        kCGLPFAAccelerated,
        kCGLPFADoubleBuffer,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };

    attribs[1] = mask;


    CGLPixelFormatObj pixFormatObj = NULL;
    GLint numPixFormats = 0;
    CGLChoosePixelFormat(attribs, &pixFormatObj, &numPixFormats);

    return pixFormatObj;
}

- (BOOL)canDrawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
{
    if (!self.shouldUpdate)
    {
        return NO;
    }

    if (self.limitFPS)
    {
        // We can control when to draw, by returning a BOOL here
        if (!_oldTimeInterval)
        {
            _oldTimeInterval = 0;
        }

        CGFloat dx = (timeInterval - _oldTimeInterval);

        // Limit to 30 FPS
        if (dx >= 0.033)
        {
            _oldTimeInterval = timeInterval;

            return YES;
        }
        else
        {
            return NO;
        }
    }
    else
    {
        return YES;
    }
}

- (void)drawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
{
    // Set the current context to the one given to us.

    CGLSetCurrentContext(glContext);

    // Clear buffer

    glClear(GL_COLOR_BUFFER_BIT);
    GetError();

    // Choose our shader program

    glUseProgram(_shaderProgram);
    GetError();

    // Draw two animated meters

    GLfloat sin = fabs(sinf(timeInterval));
    GLfloat cos = fabs(cosf(timeInterval));

    [self drawRectangle:CGRectMake(0, 0,
                                   sin * NSWidth(self.bounds),
                                   14)
        withContentRect:CGRectMake(0, 0,
                                   sin,
                                   1)];

    [self drawRectangle:CGRectMake(0, 15,
                                   cos * NSWidth(self.bounds),
                                   14)
        withContentRect:CGRectMake(0, 0,
                                   cos,
                                   1)];

    // Call super to finalize the drawing. By default all it does is call glFlush().

    [super drawInCGLContext:glContext pixelFormat:pixelFormat forLayerTime:timeInterval displayTime:timeStamp];
}

- (void)dealloc
{
    if (_shaderProgram)
    {
        glDeleteProgram(_shaderProgram);
        GetError();
    }

    if (_vbo)
    {
        glDeleteBuffers(1, &_vbo);
        GetError();
    }

    for (int i = 0; i < kNumTextures; i++)
    {
        if (_textures[i].index)
        {
            glDeleteTextures(1, &_textures[i].index);
            GetError();
        }
    }

    DLog(@"Dealloc'ing layer");
}

#pragma mark - Private

- (void)loadShader
{
    GLuint vertexShader;
    GLuint fragmentShader;

    vertexShader   = [self compileShaderOfType:GL_VERTEX_SHADER
                                          file:[[NSBundle mainBundle] pathForResource:@"Shader"
                                                                               ofType:@"vsh"]];
    fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER
                                          file:[[NSBundle mainBundle] pathForResource:@"Shader"
                                                                               ofType:@"fsh"]];

    if (0 != vertexShader && 0 != fragmentShader)
    {
        _shaderProgram = glCreateProgram();
        GetError();

        glAttachShader(_shaderProgram, vertexShader);
        GetError();
        glAttachShader(_shaderProgram, fragmentShader);
        GetError();

        glBindFragDataLocation(_shaderProgram, 0, "fragColor");

        [self linkProgram:_shaderProgram];

        _uniforms[kMeterUniform] = glGetUniformLocation(_shaderProgram, "meter");
        GetError();
        _uniforms[kModelViewProjectionMatrixUniform] = glGetUniformLocation(_shaderProgram, "TLD_MVPMatrix");
        GetError();

        for (int uniformNumber = 0; uniformNumber < kNumUniforms; uniformNumber++)
        {
            if (_uniforms[uniformNumber] < 0)
            {
                [NSException raise:kFailedToInitialiseGLException
                            format:@"Shader is missing a uniform."];
            }
        }

        _positionAttribute = glGetAttribLocation(_shaderProgram, "i_position");
        GetError();

        if (_positionAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException
                        format:@"Shader did not contain the 'i_position' attribute."];
        }

        _textCoordAttribute = glGetAttribLocation(_shaderProgram, "i_textCoord");
        GetError();

        if (_textCoordAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException
                        format:@"Shader did not contain the 'i_textCoord' attribute."];
        }

        glDeleteShader(vertexShader);
        GetError();
        glDeleteShader(fragmentShader);
        GetError();
    }
    else
    {
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Shader compilation failed."];
    }
}

- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file
{
    GLuint shader;
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file
                                                                encoding:NSASCIIStringEncoding
                                                                   error:nil] cStringUsingEncoding:NSASCIIStringEncoding];

    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to read shader file %@", file];
    }

    shader = glCreateShader(type);
    GetError();

    glShaderSource(shader, 1, &source, NULL);
    GetError();

    glCompileShader(shader);
    GetError();

#ifdef DEBUG
    GLint logLength;

    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    GetError();

    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader compilation failed with error:\n%s", log);
        free(log);
    }

#endif

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    GetError();

    if (0 == status)
    {
        glDeleteShader(shader);
        GetError();
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Shader compilation failed for file %@", file];
    }

    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);
    GetError();

#ifdef DEBUG
    GLint logLength;

    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();

    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader program linking failed with error:\n%s", log);
        free(log);
    }

#endif

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    GetError();

    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)validateProgram:(GLuint)program
{
    GLint logLength;

    glValidateProgram(program);
    GetError();

    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();

    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();

        NSLog(@"Program validation produced errors:\n%s", log);

        free(log);
    }

    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    GetError();

    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to link shader program"];
    }
}

- (void)drawRectangle:(NSRect)rect withContentRect:(NSRect)contentRect
{
    // Initialize our rectangle vertices and texture coordinates

    VertexTextCoords vtc[4] = {
        {
            .vertices = { .x = NSMinX(rect), .y = NSMinY(rect) },
            .textCoords = { .x = NSMinX(contentRect), .y = NSMinY(contentRect) }
        },
        {
            .vertices = { .x = NSMaxX(rect), .y = NSMinY(rect) },
            .textCoords = { .x = NSWidth(contentRect), .y = NSMinY(contentRect) }
        },
        {
            .vertices = { .x = NSMaxX(rect), .y = NSMaxY(rect) },
            .textCoords = { .x = NSWidth(contentRect), .y = NSHeight(contentRect) }
        },
        {
            .vertices = { .x = NSMinX(rect), .y = NSMaxY(rect) },
            .textCoords = { .x = NSMinX(contentRect), .y = NSHeight(contentRect) }
        }
    };

    if (!_vao)
    {
        // Initialize vertex array object

        glGenVertexArrays(1, &_vao);

        GetError();

        glBindVertexArray(_vao);
        GetError();
    }

    if (!_vbo)
    {
        // Initialize vertex buffer object

        glGenBuffers(1, &_vbo);
        GetError();

        glBindBuffer(GL_ARRAY_BUFFER, _vbo);
        GetError();
    }

    if (!CGRectEqualToRect(self.bounds, _oldBounds))
    {
        // Recalculate orthographic projection based on current bounds
        _orthoMat = GLKMatrix4MakeOrtho(0, NSWidth(self.bounds), 0, NSHeight(self.bounds), -1, 1);
    }

    _oldBounds = self.bounds;


    // Setup MVP projection matrix uniform

    glUniformMatrix4fv(_uniforms[kModelViewProjectionMatrixUniform], 1, GL_FALSE, _orthoMat.m);
    GetError();


    glBufferData(GL_ARRAY_BUFFER, sizeof(vtc), vtc, GL_STATIC_DRAW);
    GetError();


    // Setup position

    glEnableVertexAttribArray(_positionAttribute);
    GetError();

    glVertexAttribPointer(_positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(VertexTextCoords), (GLvoid *)offsetof(VertexTextCoords, vertices));
    GetError();


    // Setup texture coordinates

    glEnableVertexAttribArray(_textCoordAttribute);
    GetError();

    glVertexAttribPointer(_textCoordAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(VertexTextCoords), (GLvoid *)offsetof(VertexTextCoords, textCoords));
    GetError();


    glUniform1i(_uniforms[kBackgroundTexture], _textures[kBackgroundTexture].index - 1);
    GetError();


    // Select meter texture
    //
    // NOTE: We only have one texture and it is already active,
    // so we don't actually have to switch texture again.
    //
    //    glActiveTexture(GL_TEXTURE0);
    //    GetError();
    //
    //    glBindTexture(GL_TEXTURE_2D, _textures[kBackgroundTexture].index);
    //    GetError();


    // Draw textured rectangle

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GetError();

    // Cleanup

    glDisableVertexAttribArray(_positionAttribute);
    glDisableVertexAttribArray(_textCoordAttribute);
}

- (void)loadTextureData
{
    _textures[kBackgroundTexture] = [self loadTextureNamed:@"HMeter480"];

    if (_textures[kBackgroundTexture].index)
    {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _textures[kBackgroundTexture].index);
    }
}

- (TextureInfo)loadTextureNamed:(NSString *)name
{
    TextureInfo textureInfo;

    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)[[NSBundle mainBundle] URLForImageResource:name], NULL);
    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);

    CFRelease(imageSource);
    size_t width  = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGRect rect = CGRectMake(0.0f, 0.0f, width, height);

    void *imageData = malloc(width * height * 4);

    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colourSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    CFRelease(colourSpace);

    CGContextTranslateCTM(ctx, 0, height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, rect, image);
    CGContextRelease(ctx);

    CFRelease(image);

    GLuint glName;
    glGenTextures(1, &glName);
    GetError();
    glBindTexture(GL_TEXTURE_2D, glName);
    GetError();

    glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint)width);
    GetError();
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    GetError();

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)width, (int)height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, imageData);
    GetError();

    free(imageData);

    textureInfo.index = glName;
    textureInfo.dimensions = CGSizeMake(width, height);

    return textureInfo;
}

@end
