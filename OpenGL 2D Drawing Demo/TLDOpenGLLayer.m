//
//  TLDVectorscopeLayer.m
//  OpenGL 2D Drawing Demo
//
//  Created by Ruben Nine on 15/03/14.
//  Copyright (c) 2014 Ruben Nine. All rights reserved.
//

#import "TLDOpenGLLayer.h"
#import "error.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/gl3.h>

enum Uniforms
{
    kPositionUniform = 0,
    kBackgroundUniform,
    kHoleUniform,
    kNumUniforms
};

enum Textures
{
    kBackgroundTexture = 0,
    kHoleTexture,
    kNumTextures
};

typedef struct
{
    GLfloat x, y;
} Vector2;

typedef struct
{
    GLfloat x, y, z, w;
} Vector4;

typedef struct
{
    GLfloat r, g, b, a;
} Color;

typedef struct
{
    Vector4 position;
    Color color;
} Vertex;

#pragma mark -

@interface TLDOpenGLLayer ()
{
    GLuint _shaderProgram;
    GLuint _vao;
    GLuint _vbo;

    GLint _uniforms[kNumUniforms];
    GLuint _textures[kNumTextures];

    GLint _colorAttribute;
    GLint _positionAttribute;
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
        [self loadBufferData];
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
    // We can control when to draw, by returning a BOOL here
    return self.shouldUpdate;
}

- (void)drawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
{
    // Set the current context to the one given to us.
    CGLSetCurrentContext(glContext);

    glClear(GL_COLOR_BUFFER_BIT);
    GetError();

    glUseProgram(_shaderProgram);
    GetError();

    Vector2 p = { .x = 0.5f * sinf(timeInterval), .y = 0.5f * cosf(timeInterval) };

    glUniform2fv(_uniforms[kPositionUniform], 1, (const GLfloat *)&p);
    GetError();
    glUniform1i(_uniforms[kBackgroundUniform], 0);
    GetError();
    glUniform1i(_uniforms[kHoleUniform], 1);
    GetError();

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GetError();

    Vector2 p2 = { .x = -p.x, .y = -p.y };

    glUniform2fv(_uniforms[kPositionUniform], 1, (const GLfloat *)&p2);
    GetError();

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GetError();

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
        if (_textures[i])
        {
            glDeleteTextures(1, &_textures[i]);
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

        _uniforms[kPositionUniform] = glGetUniformLocation(_shaderProgram, "p");
        GetError();
        _uniforms[kBackgroundUniform] = glGetUniformLocation(_shaderProgram, "background");
        GetError();
        _uniforms[kHoleUniform]       = glGetUniformLocation(_shaderProgram, "hole");
        GetError();

        for (int uniformNumber = 0; uniformNumber < kNumUniforms; uniformNumber++)
        {
            if (_uniforms[uniformNumber] < 0)
            {
                [NSException raise:kFailedToInitialiseGLException
                            format:@"Shader is missing a uniform."];
            }
        }

        _colorAttribute = glGetAttribLocation(_shaderProgram, "color");
        GetError();

        if (_colorAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException
                        format:@"Shader did not contain the 'color' attribute."];
        }

        _positionAttribute = glGetAttribLocation(_shaderProgram, "position");
        GetError();

        if (_positionAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException
                        format:@"Shader did not contain the 'position' attribute."];
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

- (void)loadBufferData
{
    Vertex vertexData[4] = {
        { .position = { .x = -0.5, .y = -0.5, .z = 0.0, .w = 1.0 },
          .color = { .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 }},

        { .position = { .x = -0.5, .y = 0.5, .z = 0.0, .w = 1.0 },
          .color = { .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 }},

        { .position = { .x = 0.5, .y = 0.5, .z = 0.0, .w = 1.0 },
          .color = { .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 }},

        { .position = { .x = 0.5, .y = -0.5, .z = 0.0, .w = 1.0 },
          .color = { .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }}
    };

    glGenVertexArrays(1, &_vao);
    GetError();

    glBindVertexArray(_vao);
    GetError();

    glGenBuffers(1, &_vbo);
    GetError();

    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    GetError();

    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
    GetError();

    glEnableVertexAttribArray((GLuint)_positionAttribute);
    GetError();

    glEnableVertexAttribArray((GLuint)_colorAttribute);
    GetError();

    glVertexAttribPointer((GLuint)_positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
    GetError();

    glVertexAttribPointer((GLuint)_colorAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, color));
    GetError();
}

- (void)loadTextureData
{
    _textures[kBackgroundTexture] = [self loadTextureNamed:@"background"];
    _textures[kHoleTexture] = [self loadTextureNamed:@"hole"];

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textures[kBackgroundTexture]);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _textures[kHoleTexture]);
}

- (GLuint)loadTextureNamed:(NSString *)name
{
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

    return glName;
}

@end
