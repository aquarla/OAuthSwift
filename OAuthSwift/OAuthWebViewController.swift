//
//  OAuthWebViewController.swift
//  OAuthSwift
//
//  Created by Dongri Jin on 2/11/15.
//  Copyright (c) 2015 Dongri Jin. All rights reserved.
//

import Foundation

#if os(iOS)  || os(tvOS)
    import UIKit
    public typealias OAuthViewController = UIViewController
#elseif os(watchOS)
    import WatchKit
    public typealias OAuthViewController = WKInterfaceController
#elseif os(OSX)
    import AppKit
    public typealias OAuthViewController = NSViewController
#endif

// Delegate for OAuthWebViewController
public protocol OAuthWebViewControllerDelegate {
    // Did web view presented (work only without navigation controller)
    func didPresent()
    // Did web view dismiss (work only without navigation controller)
    func didDismiss()
}

// A web view controller, which handler OAuthSwift authentification.
public class OAuthWebViewController: OAuthViewController, OAuthSwiftURLHandlerType {
    
    #if os(iOS) || os(tvOS)
    public var delegate: OAuthWebViewControllerDelegate?
    // If controller have an navigation controller, application top view controller could be used if true
    public var useTopViewControlerInsteadOfNavigation = false
    
    public var topViewController: UIViewController? {
        #if !OAUTH_APP_EXTENSIONS
            return UIApplication.topViewController
        #endif
        return nil
    }
    #elseif os(OSX)
    // How to present this view controller if parent view controller set
    public enum Present {
        case AsModalWindow
        case AsSheet
        case AsPopover(relativeToRect: NSRect, ofView : NSView, preferredEdge: NSRectEdge, behavior: NSPopoverBehavior)
        case TransitionFrom(fromViewController: NSViewController, options: NSViewControllerTransitionOptions)
        case Animator(animator: NSViewControllerPresentationAnimator)
        case Segue(segueIdentifier: String)
    }
    public var present: Present = .AsModalWindow
    #endif
    
    public func handle(url: NSURL) {
        // do UI in main thread
        OAuthSwift.main { [unowned self] in
             self.doHandle(url)
        }
    }

    #if os(watchOS)
    public static var userActivityType: String = "org.github.dongri.oauthswift.connect"
    #endif

    public func doHandle(url: NSURL) {
        #if os(iOS) || os(tvOS)
            let completion: () -> Void = { [unowned self] in
                self.delegate?.didPresent()
            }
            let animated = true
            if let navigationController = self.navigationController where (!useTopViewControlerInsteadOfNavigation || self.topViewController == nil) {
                navigationController.pushViewController(self, animated: animated)
            }
            else if let p = self.parentViewController {
                p.presentViewController(self, animated: animated, completion: completion)
            }
            else if let topViewController = topViewController {
                topViewController.presentViewController(self, animated: animated, completion: completion)
            }
            else {
                // assert no presentation
            }
        #elseif os(watchOS)
            if (url.scheme == "http" || url.scheme == "https") {
                self.updateUserActivity(OAuthWebViewController.userActivityType, userInfo: nil, webpageURL: url)
            }
        #elseif os(OSX)
            if let p = self.parentViewController { // default behaviour if this controller affected as child controller
                switch self.present {
                case .AsSheet:
                    p.presentViewControllerAsSheet(self)
                    break
                case .AsModalWindow:
                    p.presentViewControllerAsModalWindow(self)
                    // FIXME: if we present as window, window close must detected and oauthswift.cancel() must be called...
                    break
                case .AsPopover(let positioningRect, let positioningView, let preferredEdge, let behavior):
                    p.presentViewController(self, asPopoverRelativeToRect: positioningRect, ofView : positioningView, preferredEdge: preferredEdge, behavior: behavior)
                    break
                case .TransitionFrom(let fromViewController, let options):
                    p.transitionFromViewController(fromViewController, toViewController: self, options: options, completionHandler: nil)
                    break
                case .Animator(let animator):
                    p.presentViewController(self, animator: animator)
                case .Segue(let segueIdentifier):
                    p.performSegueWithIdentifier(segueIdentifier, sender: self) // The segue must display self.view
                    break
                }
            }
            else if let window = self.view.window {
                window.makeKeyAndOrderFront(nil)
            }
            // or create an NSWindow or NSWindowController (/!\ keep a strong reference on it)
        #endif
    }

    public func dismissWebViewController() {
        #if os(iOS) || os(tvOS)
            let completion: () -> Void = { [unowned self] in
                self.delegate?.didDismiss()
            }
            let animated = true
            if let navigationController = self.navigationController where (!useTopViewControlerInsteadOfNavigation || self.topViewController == nil){
                navigationController.popViewControllerAnimated(animated)
            }
            else if let parentViewController = self.parentViewController {
                // The presenting view controller is responsible for dismissing the view controller it presented
                parentViewController.dismissViewControllerAnimated(animated, completion: completion)
            }
            else if let topViewController = topViewController {
                topViewController.dismissViewControllerAnimated(animated, completion: completion)
            }
            else {
                // keep old code...
                self.dismissViewControllerAnimated(animated, completion: completion)
            }
        #elseif os(watchOS)
            self.dismissController()
        #elseif os(OSX)
            if self.presentingViewController != nil { // if presentViewControllerAsModalWindow
                self.dismissController(nil)
                if self.parentViewController != nil {
                    self.removeFromParentViewController()
                }
            }
            else if let window = self.view.window {
                window.performClose(nil)
            }
        #endif
    }
}