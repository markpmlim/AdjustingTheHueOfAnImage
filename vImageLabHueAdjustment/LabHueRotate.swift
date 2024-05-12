//
//  LabHueRotate.swift
//  vImageLabHueAdjustment
//
//  Created by Mark Lim Pak Mun on 22/04/2024.
//  Copyright © 2024 com.incremental.innovation. All rights reserved.
//

import AppKit
import Accelerate.vImage

class LabHueRotate
{
    private let rgbToLab: vImageConverter
    private let labToRGB: vImageConverter
    private var labSource: vImage_Buffer
    private var argbSourceBuffer: vImage_Buffer

    private var lDestination: vImage_Buffer?
    private var aDestination: vImage_Buffer?
    private var bDestination: vImage_Buffer?

    private let sourceCGImage: CGImage
    private let image: NSImage

    // 2. Create L*a*b* Image Format
    // labImageFormat describes the interleaved L*a*b* pixels
    // channel 0 - lightness, channel 1 - a*, channel 2 - b*
    // LAB colorspace supports RGB
    var labImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 8 * 3,
        colorSpace: CGColorSpace(name: CGColorSpace.genericLab)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        renderingIntent: .defaultIntent)!

    let rgbImageFormat: vImage_CGImageFormat

    init?(image: NSImage)
    {
        self.image = image
        // 1. Derive RGB Image Format from Source Image
        var rect = CGRect(origin: .zero,
                          size: image.size)
        guard
            let sourceCGImage = image.cgImage(forProposedRect: &rect,
                                              context: nil,
                                              hints: nil)

        else {
            print("Unable to generate a `CGImage` from the `NSImage`.")
            return nil
        }
        // Use the vImage_CGImageFormat init(cgImage:) to create the RGB format from
        // the source image.
        // bitmapInfo is CGImageAlphaInfo.last.rawValue (non-premultiplied RGBA)
        self.sourceCGImage = sourceCGImage
        rgbImageFormat = vImage_CGImageFormat(cgImage: sourceCGImage)!
/*
        // XRGB
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        rgbImageFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8*4,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            renderingIntent: .defaultIntent)!
*/

        // 3. Create RGB-to-L*a*b* and L*a*b*-to-RGB Converters
        do {
            // macOS 10.15 or later
            rgbToLab = try vImageConverter.make(sourceFormat: rgbImageFormat,
                                                destinationFormat: labImageFormat)
            
            labToRGB = try vImageConverter.make(sourceFormat: labImageFormat,
                                                destinationFormat: rgbImageFormat)
        }
        catch {
            fatalError("Any-to-any conversion failed.")
        }

        // Initialize a vImage buffer that’s the same size as the source image
        // and the L*a*b* image format’s bitsPerPixel
        do {
            labSource = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: labImageFormat.bitsPerPixel)
        }
        catch {
            fatalError("Unable to create the lab source failed.")
        }

        // 4. Create a vImage buffer from the source image.
        do {
            // The bitmapInfo of the sourceCGImage should be CGImageAlphaInfo.none.rawValue
            // Populate the buffer with the pixels of the Core Graphics image.
            argbSourceBuffer = try vImage_Buffer(cgImage: sourceCGImage,
                                                 format: rgbImageFormat)
            // On return, argbSourceBuffer contains the image.
        }
        catch {
            fatalError("Unable to create the argbSourceBuffer source failed.")
        }

        // Debugging
        let rawPtr = argbSourceBuffer.data
        var bufferPtr = rawPtr?.assumingMemoryBound(to: UInt8.self)
        for _ in 0..<2 * rgbImageFormat.componentCount {
            print(bufferPtr?.pointee)
            bufferPtr = bufferPtr?.advanced(by: 1)
        }
    }

    deinit {
        do {
            // macOS 10.15 or later.
            argbSourceBuffer.free()
            labSource.free()
            lDestination!.free()
            aDestination!.free()
            bDestination!.free()
        }
    }

    func convertRGB2LAB()
    {
        // 5. Convert RGB to L*a*b*..
        do {
            // The converter’s convert(source:destination:flags:) function performs the conversion.
            try rgbToLab.convert(source: argbSourceBuffer,
                                 destination: &labSource)
        }
        catch {
            print("Convert to lab failed.")
            return
        }
        // On return, the labSource contains the L*a*b* representation of the source image.

        // On first call, lDestination, aDestination and bDestination are nil objects.
        // If they are not nil objects, then we have to free the memory allocated
        if lDestination != nil {
            // Frees the resoures associated with the vImage buffer.
            lDestination!.free()
        }
        if aDestination != nil {
            aDestination!.free()
        }
        if bDestination != nil {
            bDestination!.free()
        }

        // 6. Convert the Interleaved L*a*b* buffer to 3 Planar Buffers
        do {
            // Lightness
            lDestination = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: labImageFormat.bitsPerComponent)
            // red-green (a*)
            aDestination = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: labImageFormat.bitsPerComponent)
            // blue-yellow (b*)
            bDestination = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: labImageFormat.bitsPerComponent)
        }
        catch {
            print("Convert to planar buffers failed")
        }

        // Populate the 3 planar buffers with the contents of the interleaved buffer
        let error = vImageConvert_RGB888toPlanar8(
            &labSource,
            &lDestination!,
            &aDestination!,
            &bDestination!,
            vImage_Flags(kvImageNoFlags))
        if error != vImage_Error(0) {
            print("Convert to planar buffers failed")
        }
    }

    // 7. Apply the Hue Adjustment
    // Hue adjustment is achieved by rotating a two-element vector, described by a* and b*
    func applyHueAdjustment(hueAngle: Float)
    {
        // Use the hueAngle to generate the rotation matrix
        let divisor: Int32 = 0x1000
        
        let rotationMatrix = [
            cos(hueAngle), -sin(hueAngle),
            sin(hueAngle),  cos(hueAngle)
            ].map {
                return Int16($0 * Float(divisor))
        }

        let preBias = [Int16](repeating: -128, count: 2)
        let postBias = [Int32](repeating: 128 * divisor, count: 2)

        [bDestination!, aDestination!].withUnsafeBufferPointer {
            (bufferPointer: UnsafeBufferPointer<vImage_Buffer>) in
            
            var src: [UnsafePointer<vImage_Buffer>?] = (0...1).map {
                bufferPointer.baseAddress! + $0
            }

            var dst: [UnsafePointer<vImage_Buffer>?] = (0...1).map {
                bufferPointer.baseAddress! + $0
            }

            // The function below multiplies each pixel in the source buffers
            // by the matrix and writes the result to the destination buffers
            vImageMatrixMultiply_Planar8(&src,
                                         &dst,
                                         2, 2,
                                         rotationMatrix,
                                         divisor,
                                         preBias,
                                         postBias,
                                         0)
            // On return, aDestination and bDestination buffers contain the hue adjusted
            // a* and b* channels
        }
    }

    // 9. Convert L*a*b* to RGB
    func convertLAB2RGB() -> CGImage?
    {
        var labDestination = vImage_Buffer()
        var rgbDestination = vImage_Buffer()
        do {
            labDestination = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: 8*3
            )
            rgbDestination = try vImage_Buffer(
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerPixel: 8*4
            )
        }
        catch {
            print ("Can't create LAB and RGB destination buffers!")
            return nil
        }

        defer {
            labDestination.free()
            rgbDestination.free()
        }

        // 8. Convert the planar L*a*b* buffers to an interleaved RGB buffer
        vImageConvert_Planar8toRGB888(&lDestination!,
                                      &aDestination!,
                                      &bDestination!,
                                      &labDestination,
                                      vImage_Flags(kvImageNoFlags))

        // 0. Convert L*a*b* to RGB.
        do {
            try labToRGB.convert(source: labDestination,
                                 destination: &rgbDestination)
        }
        catch {
            print("Conversion from LAB to RGB failed")
            return nil
        }

        var outputImage: CGImage?
        do {
            outputImage = try rgbDestination.createCGImage(format: rgbImageFormat)
        }
        catch {
            print("Can't create the output CGImage")
            return nil
        }
        return outputImage
    }
}
