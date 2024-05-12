## Convert an RGB image to Lab color space and apply hue adjustment
<br />
<br />

Based on Apple's `Adjusting the hue of an image` distributed with XCode 11.6
<br />
<br />

**Observation:**
<br />

The colours of the rendered image are not correct for -90, 90, 180 degrees; only a rotation of 0 degree is correct. 
<br />

![](Documentation/Rotation-90.png)

![](Documentation/Rotation90.png)

![](Documentation/Rotation180.png)

<br />
<br />

Applying the call `vImagePermuteChannels_ARGB8888` to change the ordering of the colour channels does not help.

We  also tried create the `rgbImageFormat` in 2 different ways.

Method 1: Use the initializer of vImage_CGImageFormat 

**init(cgImage:)** 

to create the RGB image format from the source image.

    rgbImageFormat = vImage_CGImageFormat(cgImage: sourceCGImage)!

Method 2: Use the initializer of vImage_CGImageFormat 

**init(bitsPerComponent:bitsPerPixel:colorSpace:bitmapInfo:version:decode:renderingIntent:)**

to create the RGB image format from the source image.

    let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
    )
    rgbImageFormat = vImage_CGImageFormat(
    bitsPerComponent: 8,
    bitsPerPixel: 8*4,
    colorSpace: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: bitmapInfo,
    renderingIntent: .defaultIntent)!


The same set of results are obtained for the hueAngles -90, 0, 90, 180 degrees.

<br />
<br />

## Development Plaftorm
<br />
<br />

XCode 11.6, Swift 5.0
<br />
<br />

Deployment target is set at macOS 10.15.x

<br />
<br />

**WebLinks**

Latest version:

https://developer.apple.com/documentation/accelerate/adjusting_the_hue_of_an_image
