//
//  ViewController.swift
//  Vertigo
//
//  Created by Simon Gladman on 20/02/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//


import UIKit
import CoreImage
import GLKit

class ViewController: UIViewController
{
    var imageAccumulator: CIImageAccumulator!
    var sideLength: CGFloat!
    var hue = CGFloat(0)
    
    let label: UILabel =
    {
        let label = UILabel()
        
        label.textColor = UIColor.whiteColor()
        label.text = "Touch near the center of the screen to experience colorful vertigo..."
        label.textAlignment = .Center
        
        return label
    }()
    
    lazy var imageView: GLKView =
    {
        [unowned self] in
        
        let imageView = GLKView()
        
        imageView.context = self.eaglContext
        imageView.delegate = self
        
        return imageView
        }()
    
    let eaglContext = EAGLContext(API: .OpenGLES2)
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(EAGLContext: self.eaglContext,
            options: [kCIContextWorkingColorSpace: NSNull()])
        }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        
        sideLength = min(view.frame.width, view.frame.height)
        
        imageAccumulator = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: sideLength, height: sideLength),
            format: kCIFormatARGB8)
        
        let image = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
            .imageByCroppingToRect(CGRect(x: 0, y: 0, width: sideLength, height: sideLength))
        
        imageAccumulator.setImage(image)
        
        view.addSubview(imageView)
        label.frame = view.bounds
        
        view.addSubview(label)
        
        let displayLink = CADisplayLink(target: self, selector: Selector("step"))
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(x: view.frame.midX - sideLength / 2,
            y: view.frame.midY - sideLength / 2,
            width: sideLength,
            height: sideLength)
    }
    
    override func prefersStatusBarHidden() -> Bool
    {
        return true
    }
    
    func step()
    {
        imageView.setNeedsDisplay()
    }
    
    var touchLocations: [CGPoint]?
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first else
        {
            return
        }
        
        label.hidden = true
        
        touchLocations = [CGPoint(x: touch.locationInView(imageView).x,
            y: sideLength - touch.locationInView(imageView).y)]
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first,
            coalescedTouches = event?.coalescedTouchesForTouch(touch)
            else
        {
            return
        }
        
        touchLocations = coalescedTouches.map
            {
                CGPoint(x: $0.locationInView(imageView).x,
                    y: sideLength - $0.locationInView(imageView).y)
        }
        
    }
    
}

extension ViewController: GLKViewDelegate
{
    func glkView(view: GLKView, drawInRect rect: CGRect)
    {
        let image = imageAccumulator.image()
            .imageByApplyingFilter("CIExposureAdjust", withInputParameters: [kCIInputEVKey: -0.0025])
        
        var tx = CGAffineTransformMakeTranslation(sideLength / 2, sideLength / 2)
        tx = CGAffineTransformRotate(tx, -0.15)
        tx = CGAffineTransformTranslate(tx, -sideLength / 2, -sideLength / 2)
        
        var transformImage = CIFilter(name: "CIAffineTransform",
            withInputParameters: [kCIInputImageKey: image,
            kCIInputTransformKey: NSValue(CGAffineTransform: tx)])!.outputImage!
        
        if let touchLocations = touchLocations
            {
                for touchLocation in touchLocations
        {
            let color = CIColor(color: UIColor(hue: hue % 1.0, saturation: 1, brightness: 1, alpha: 1))
            hue += 0.01
            
            let gradient = CIFilter(name: "CIGaussianGradient",
                withInputParameters: [
                kCIInputCenterKey: CIVector(CGPoint: touchLocation),
                kCIInputRadiusKey: 15,
                "inputColor0": color,
                "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
                ])!.outputImage!
            
            transformImage = gradient.imageByCompositingOverImage(transformImage)
                }
                self.touchLocations = nil
        }
        
        let finalImage = transformImage
        
        
        imageAccumulator.setImage(finalImage)
        
        ciContext.drawImage(imageAccumulator.image(),
            inRect: CGRect(x: 0, y: 0,
            width: imageView.drawableWidth,
            height: imageView.drawableHeight),
            fromRect: CGRect(x: 0, y: 0, width: sideLength, height: sideLength))
    }
}