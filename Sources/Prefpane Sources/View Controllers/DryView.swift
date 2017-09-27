//
//  DryView.swift
//  CocoaBindingDryView-ReusableViews
//
//  Created by AMTourky on 6/25/16.
//
//  Copyright © 2016 AMTourky. All rights reserved.
//  www.amtourky.me
//  Modified by Gregorio Litenstein for use on SwiftDefaultApps.

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0


import Cocoa

@IBDesignable class DRYView: NSView {
    private let dRYViewKVOContext = UnsafeMutableRawPointer(bitPattern: 1)
    @IBOutlet weak var descriptionControl: NSTextField?
    @IBOutlet weak var titleControl: NSTextField?
    
    @IBInspectable var nibName: String?
        {
        didSet
        {
            guard let theNibName = self.nibName
                else { return }
            
            var objects: NSArray? = NSArray()
            self.bundle?.loadNibNamed(NSNib.Name(rawValue: theNibName), owner: self, topLevelObjects: &objects)
            if let theObjects = objects
            {
                for view in theObjects
                {
                    if let theView = view as? NSView
                    {
                        self.addSubview(theView)
                        theView.translatesAutoresizingMaskIntoConstraints = false
                        self.selfViewConstraintsToBeFollowedByView(theView)
                        break
                    }
                }
            }
        }
    }
    
    lazy var bundle: Bundle? =
        {
            guard let theNibName = self.nibName
                else {return nil}
            
            var objects: NSArray? = NSArray()
            var isLoaded = Bundle.main.loadNibNamed(NSNib.Name(rawValue: theNibName), owner: self, topLevelObjects: &objects)
            if isLoaded
            {
                return Bundle.main
            }
            else
            {
                return Bundle(for: self.classForCoder)
            }
    }()
    
    func selfViewConstraintsToBeFollowedByView(_ view: NSView)
    {
        let widthConstraint     = NSLayoutConstraint(item: self, attribute: .width      , relatedBy: .equal, toItem: view, attribute: .width    , multiplier: 1, constant: 0)
        let centerXConstraint     = NSLayoutConstraint(item: self, attribute: .centerX      , relatedBy: .equal, toItem: view, attribute: .centerX    , multiplier: 1, constant: 0)
        centerXConstraint.identifier = "DRYView Auto CenterX"
        let centerYConstraint     = NSLayoutConstraint(item: self, attribute: .centerY      , relatedBy: .equal, toItem: view, attribute: .centerY    , multiplier: 1, constant: 0)
        centerYConstraint.identifier = "DRYView Auto CenterY"
        widthConstraint.identifier = "DRYView Auto Width"
        let heightConstraint    = NSLayoutConstraint(item: self, attribute: .height     , relatedBy: .equal, toItem: view, attribute: .height   , multiplier: 1, constant: 0)
        heightConstraint.identifier = "DRYView Auto Height"
        self.addConstraints([centerXConstraint, centerYConstraint, widthConstraint, heightConstraint])
    }
    
    
    
    @objc var inspectedObject: NSObject? {
        didSet {
            self.willChangeValue(forKey: "inspectedObject")
            self.didChangeValue(forKey: "inspectedObject")
            
            self.titleControl?.fitWidth()
            self.descriptionControl?.fitWidth()
        }
    }
    
    
    @IBOutlet var inspectedObjectControllerReference: NSObjectController? {
        didSet {
            self.inspectedObject = self.inspectedObjectControllerReference?.content as? NSObject
            addObserver(self, forKeyPath: #keyPath(inspectedObjectControllerReference.content), options: .new, context: dRYViewKVOContext)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard (dRYViewKVOContext == context) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if (dRYViewKVOContext == context) {
            self.inspectedObject = self.inspectedObjectControllerReference?.content as? NSObject
        }
    }
    
    deinit
    {
        if let _ = inspectedObject {
            removeObserver(self, forKeyPath: #keyPath(inspectedObjectControllerReference.content), context: dRYViewKVOContext)
        }
    }
}
