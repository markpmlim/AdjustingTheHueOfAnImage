//
//  ViewController.swift
//  vImageLabHueAdjustment
//
//  Created by Mark Lim Pak Mun on 22/04/2024.
//  Copyright © 2024 com.incremental.innovation. All rights reserved.
//

import Cocoa

class ViewController: NSViewController
{

    @IBOutlet var imageView: NSImageView!

    var labHueRotate: LabHueRotate!
    var cgImage: CGImage!

    override func viewDidLoad() {
        
        super.viewDidLoad()

        let nsImage = NSImage(named: "Flowers_1.png")!
        labHueRotate = LabHueRotate(image: nsImage)
        labHueRotate.convertRGB2LAB()
        labHueRotate.applyHueAdjustment(hueAngle: 0)
        guard let cgImage = labHueRotate.convertLAB2RGB()
        else {
            return
        }
        self.cgImage = cgImage
        display()
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    @IBAction func actionSlider(_ slider: NSSlider)
    {
        let value = slider.floatValue
        labHueRotate.convertRGB2LAB()
        labHueRotate.applyHueAdjustment(hueAngle: value)
        self.cgImage = labHueRotate.convertLAB2RGB()
        display()
    }

    func display()
    {
        let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)
        imageView.image = nsImage
    }
}

