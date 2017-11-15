//
//  CustomPresentation.swift
//  StackTransition
//
//  Created by Yariv on 11/15/17.
//  Copyright © 2017 ZipRecruiter. All rights reserved.
//

import UIKit

// MARK:- Custom Presentation -

class CustomPresentation: UIPresentationController {
    private var dimView: UIView!
    private var presentingView: UIView!

    // MARK: Layout

    // Use the presentingViewController so the Safe Area includes the Status Bar
    private var safeAreaInsets: UIEdgeInsets {
        return presentingViewController.view.safeAreaInsets
    }

    private var spacingInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 15, left: 10, bottom: 0, right: 10)
    }

    // presentedView will be animated automatically to this frame by the Transition object
    override var frameOfPresentedViewInContainerView: CGRect {
        let topInset = (safeAreaInsets.top + spacingInsets.top)/2
        return containerView!.bounds
            .insetBy(dx: safeAreaInsets.left, dy: topInset) // make smaller
            .offsetBy(dx: 0, dy: topInset) // push down
    }

    // We will set the frame manually using this property
    private var frameOfPresentingViewInContainerView: CGRect {
        return containerView!.bounds
            .insetBy(dx: safeAreaInsets.left + spacingInsets.left, dy: safeAreaInsets.top) // make smaller
    }

    // MARK: Presentation

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView
            , let presentedView = presentedView
            , let presentingViewSnapshot = presentingViewController.view.snapshotView(afterScreenUpdates: false)
            else { fatalError() }

        containerView.backgroundColor = .black
        presentedView.layer.masksToBounds = true
        presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        // Put a screenshot of the presenting view in the back
        presentingView = presentingViewSnapshot
        presentingView.frame = containerView.bounds
        presentingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        presentingView.layer.masksToBounds = true
        containerView.addSubview(presentingView)

        // Create transparent black background
        dimView = UIView(frame: containerView.bounds)
        dimView.backgroundColor = .black
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.alpha = 0
        containerView.addSubview(dimView)

        // Animate our custom animations alongside the existing transition
        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            presentedView.layer.cornerRadius = 10
            self.dimView.alpha = 0.5
            self.presentingView.frame = self.frameOfPresentingViewInContainerView
            self.presentingView.layer.cornerRadius = 10
        }, completion: nil)
    }

    // MARK: Dismissal

    // Revert everything back to normal
    // Since we support Interactive Transition, we must handle a cancellation event
    override func dismissalTransitionWillBegin() {
        guard let containerView = containerView else { fatalError() }

        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _  in
            self.dimView.alpha = 0
            self.presentingView.frame = containerView.frame
        }, completion: { context in
            if !context.isCancelled {
                self.presentingView.layer.cornerRadius = 0
            }
        })
    }

    // MARK: Layout

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        presentingView.frame = frameOfPresentingViewInContainerView
    }
}
