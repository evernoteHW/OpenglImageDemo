//
//  OpenGLView.m
//  Tutorial10
//
//  Created by kesalin@gmail.com on 12-12-24.
//  Copyright (c) 2012 年 http://blog.csdn.net/kesalin/. All rights reserved.
//

#import "OpenGLView.h"
#import "GLESUtils.h"

@interface OpenGLView()
{
    NSMutableArray * _vboArray;
    KSMatrix4 _rotationMatrix;
}


@end

@implementation OpenGLView

#pragma mark- Initilize GL

+ (Class)layerClass {
    // Support for OpenGL ES
    return [CAEAGLLayer class];
}

- (void)setupLayer
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    
    // Make CALayer visibale
    _eaglLayer.opaque = YES;
    
    // Set drawable properties
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
}

- (void)setupContext
{
    // Set OpenGL version, here is OpenGL ES 2.0 
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@" >> Error: Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    // Set OpenGL context
    if (![EAGLContext setCurrentContext:_context]) {
        _context = nil;
        NSLog(@" >> Error: Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupBuffers
{
    // Setup color render buffer
    //
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    
    // Setup depth render buffer
    //
    int width, height;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    
    // Create a depth buffer that has the same size as the color buffer.
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    
    // Setup frame buffer
    //
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    // Attach color render buffer and depth render buffer to frameBuffer
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER, _depthRenderBuffer);
    
    // Set color render buffer as current render buffer
    //
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
}

- (void)destoryBuffer:(GLuint *)buffer
{
    if (buffer && *buffer != 0) {
        glDeleteRenderbuffers(1, buffer);
        *buffer = 0;
    }
}

- (void)destoryBuffers
{
    [self destoryBuffer: &_depthRenderBuffer];
    [self destoryBuffer: &_colorRenderBuffer];
    [self destoryBuffer: &_frameBuffer];
}

- (void)cleanup
{

    [self destoryBuffers];
    
    if (_programHandle != 0) {
        glDeleteProgram(_programHandle);
        _programHandle = 0;
    }

    if (_context && [EAGLContext currentContext] == _context)
        [EAGLContext setCurrentContext:nil];
    
    _context = nil;
}

- (void)setupProgram
{
    // Load shaders
    //
    NSString * vertexShaderPath = [[NSBundle mainBundle] pathForResource:@"VertexShader"
                                                                  ofType:@"glsl"];
    NSString * fragmentShaderPath = [[NSBundle mainBundle] pathForResource:@"FragmentShader"
                                                                    ofType:@"glsl"];
    
    _programHandle = [GLESUtils loadProgram:vertexShaderPath
                 withFragmentShaderFilepath:fragmentShaderPath];
    if (_programHandle == 0) {
        NSLog(@" >> Error: Failed to setup program.");
        return;
    }
    
    glUseProgram(_programHandle);
    
    [self getSlotsFromProgram];
}

#pragma mark - Light

- (void)setupLights
{
    // Set up some default material parameters.
    //
    glUniform3f(_ambientSlot, 0.04f, 0.04f, 0.04f);
    glUniform3f(_specularSlot, 0.5, 0.5, 0.5);
    glUniform1f(_shininessSlot, 50);

    // Initialize various state.
    //
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_normalSlot);
    
    glUniform3f(_lightPositionSlot, 1.0, 1.0, 5.0);
    
    glVertexAttrib3f(_diffuseSlot, 0.8, 0.8, 0.8);
}

#pragma mark - Texture

- (void)updateTextureParameter
{
    // It can be GL_NICEST or GL_FASTEST or GL_DONT_CARE. GL_DONT_CARE by default.
    //
    glHint(GL_GENERATE_MIPMAP_HINT, GL_NICEST);
    
    //单独为纹理缩放指定不同的过滤算法
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    //为纹理坐标系中每条坐标轴设定不同的wrapping模式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
}

- (void)setupTextures
{
	glActiveTexture(GL_TEXTURE0);
    glEnableVertexAttribArray(_textureCoordSlot);
    glUniform1i(_samplerSlot, 0);
}


#pragma mark - Draw object

- (void)getSlotsFromProgram
{
    // Get the attribute and uniform slot from program
    //
    _projectionSlot = glGetUniformLocation(_programHandle, "projection");
    _modelViewSlot = glGetUniformLocation(_programHandle, "modelView");
    _normalMatrixSlot = glGetUniformLocation(_programHandle, "normalMatrix");
    _lightPositionSlot = glGetUniformLocation(_programHandle, "vLightPosition");
    _ambientSlot = glGetUniformLocation(_programHandle, "vAmbientMaterial");
    _specularSlot = glGetUniformLocation(_programHandle, "vSpecularMaterial");
    _shininessSlot = glGetUniformLocation(_programHandle, "shininess");
    
    _positionSlot = glGetAttribLocation(_programHandle, "vPosition");
    _normalSlot = glGetAttribLocation(_programHandle, "vNormal");
    _diffuseSlot = glGetAttribLocation(_programHandle, "vDiffuseMaterial");
    
    _textureCoordSlot = glGetAttribLocation(_programHandle, "vTextureCoord");
    _samplerSlot = glGetUniformLocation(_programHandle, "Sampler");
}

- (void)setupProjection
{
    float width = self.frame.size.width;
    float height = self.frame.size.height;
    
    // Generate a perspective matrix with a 60 degree FOV
    //
    ksMatrixLoadIdentity(&_projectionMatrix);
    float aspect = width / height;
    ksPerspective(&_projectionMatrix, 60.0, aspect, 4.0f, 12.0f);
    
    // Load projection matrix
    glUniformMatrix4fv(_projectionSlot, 1, GL_FALSE, (GLfloat*)&_projectionMatrix.m[0][0]);
    
    //glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
}

- (void)resetRotation
{
    ksMatrixLoadIdentity(&_rotationMatrix);
}

- (void)updateSurface
{
    ksMatrixLoadIdentity(&_modelViewMatrix);
    
    ksTranslate(&_modelViewMatrix, 0.0, 0.0, -8);
    
    ksMatrixMultiply(&_modelViewMatrix, &_rotationMatrix, &_modelViewMatrix);
    
    // Load the model-view matrix
    glUniformMatrix4fv(_modelViewSlot, 1, GL_FALSE, (GLfloat*)&_modelViewMatrix.m[0][0]);
    
    // Load the normal matrix.
    // It's orthogonal, so its Inverse-Transpose is itself!
    //
    KSMatrix3 normalMatrix3;
    ksMatrix4ToMatrix3(&normalMatrix3, &_modelViewMatrix);
    glUniformMatrix3fv(_normalMatrixSlot, 1, GL_FALSE, (GLfloat*)&normalMatrix3.m[0][0]);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, [self createTexture:@"flower.jpg"]);
    [self updateTextureParameter];
}
- (GLuint)createTexture:(NSString *)textureFile
{
    
    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString* fullPath = [resourcePath stringByAppendingPathComponent:textureFile];
    
    UIImage* uiImage = [UIImage imageWithContentsOfFile:fullPath];
    CGImageRef cgImage = uiImage.CGImage;
    CGSize originalSize = CGSizeZero;
    
    originalSize.width = CGImageGetWidth(cgImage);
    originalSize.height = CGImageGetHeight(cgImage);
    
    int byteCount = originalSize.width * originalSize.height * 4;
    unsigned char* data = (unsigned char*) calloc(byteCount, 1);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    CGContextRef context = CGBitmapContextCreate(data,
                                                 originalSize.width,
                                                 originalSize.height,
                                                 8,
                                                 4 * originalSize.width,
                                                 colorSpace,
                                                 bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    CGRect rect = CGRectMake(0, 0, originalSize.width, originalSize.height);
    CGContextDrawImage(context, rect, uiImage.CGImage);
    CGContextRelease(context);
    
    NSData *imageData = [NSData dataWithBytesNoCopy:data length:byteCount freeWhenDone:YES];
    
    
    GLuint textureHandle = 0;
    
    glGenTextures(1, &textureHandle);
    glBindTexture(GL_TEXTURE_2D, textureHandle);
    
    
    void* pixels = (void*) [imageData bytes];
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, originalSize.width, originalSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    
    glGenerateMipmap(GL_TEXTURE_2D);
    
    return textureHandle;
}

- (void)drawSurface
{

    const GLfloat vertices[] = {
        -2.0, -2.0, 2.0, 0, 0, 1, 0, 1,
        -2.0, 2.0, 2.0, 0, 0, 1, 0, 0,
        2.0, 2.0, 2.0, 0, 0, 1, 1, 0,
        2.0, -2.0, 2.0, 0, 0, 1, 1, 1,
    };
    
    const GLushort indices[] = {
        // Front face
        0, 3, 1, 3, 2, 1
    };
    
    // Create the VBO for the vertice.
    //
    int vertexSize = 8;
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    // Create the VBO for the triangle indice
    //
    int triangleIndexCount = sizeof(indices)/sizeof(indices[0]);
    GLuint triangleIndexBuffer;
    glGenBuffers(1, &triangleIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, triangleIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, triangleIndexCount * sizeof(GLushort), indices, GL_STATIC_DRAW);

    //////////////////////////
    
    int stride = vertexSize * sizeof(GLfloat);
    const GLvoid* normalOffset = (const GLvoid*)(3 * sizeof(GLfloat));
    const GLvoid* texCoordOffset = (const GLvoid*)(6 * sizeof(GLfloat));
    
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, stride, 0);
    glVertexAttribPointer(_normalSlot, 3, GL_FLOAT, GL_FALSE, stride, normalOffset);
    
    glVertexAttribPointer(_textureCoordSlot, 2, GL_FLOAT, GL_FALSE, stride, texCoordOffset);
    
    // Draw the triangles.
    //
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, triangleIndexBuffer);
    glDrawElements(GL_TRIANGLES, triangleIndexCount, GL_UNSIGNED_SHORT, 0);
}

- (void)render
{
    if (_context == nil)
        return;
    
    glClearColor(0.0f, 1.0f, 0.0f, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Setup viewport
    //
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);    
    
    [self updateSurface];
    [self drawSurface];

    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark
- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayer];
        [self setupContext];
        [self setupProgram];
        
        [self setupProjection];
        
        [self setupLights];
        
        [self setupTextures];
        
        [self resetRotation];
        
        [GLESUtils printExtensions];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupLayer];        
        [self setupContext];
        [self setupProgram];
        
        [self setupProjection];
        
        [self setupLights];
        
        [self setupTextures];
        
        [self resetRotation];
        
        [GLESUtils printExtensions];
    }

    return self;
}

- (void)layoutSubviews
{
    [EAGLContext setCurrentContext:_context];
    glUseProgram(_programHandle);

    [self destoryBuffers];
    
    [self setupBuffers];
    
    [self render];
}


@end
