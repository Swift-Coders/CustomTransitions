//
//  CardTransitionController.swift
//  Stack Transition
//
//  Created by Yariv Nissim on 1/6/17.
//  Copyright © 2017 Yariv Nissim. All rights reserved.
//

import UIKit

// MARK:- TransitionController -

class CardTransitionController: NSObject {
    
    var interactive = false
    let panGesture = UIPanGestureRecognizer()
    let slideTransition = SlideTransition()
    
    private(set) weak var viewController: UIViewController!
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self
        viewController.modalPresentationCapturesStatusBarAppearance = true
        configurePanGestureRecognizer(for: viewController)
    }
    
    func configurePanGestureRecognizer(for viewController: UIViewController) {
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        panGesture.addTarget(self, action: #selector(initiateTransitionInteractively(_:)))
        
        if let navigationController = viewController as? UINavigationController {
            navigationController.view.addGestureRecognizer(panGesture)
            guard let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer else { return }
            panGesture.require(toFail: interactivePopGestureRecognizer)
        } else {
            viewController.view.addGestureRecognizer(panGesture)
        }
    }
    
    func initiateTransitionInteractively(_ panGesture: UIPanGestureRecognizer) {
        if panGesture.state == .began {
            interactive = true
            slideTransition.panGesture = panGesture
            viewController.presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            interactive = false
        }
    }
}

// MARK:- UIGestureRecognizerDelegate

extension CardTransitionController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if let otherPanGesture = otherGestureRecognizer as? UIPanGestureRecognizer,
            let scrollView = otherPanGesture.view as? UIScrollView {
            return scrollView.contentOffset.y <= 0
        }
        
        return !otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self)
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let translation = panGesture.translation(in: panGesture.view)
        let translationIsVertical = (translation.y > 0) && (abs(translation.y) > abs(translation.x))
        return translationIsVertical
    }
}

// MARK:- UIViewControllerTransitioningDelegate

extension CardTransitionController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CardPresentation(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        slideTransition.presenting = true
        return slideTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        slideTransition.presenting = false
        return slideTransition
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if interactive {
            slideTransition.presenting = false
            return slideTransition
        }
        return nil
    }
}

// MARK:- Card Presentation -

private let cornerRadius: CGFloat = 10

class CardPresentation: UIPresentationController {
    private var dimView: UIView!
    private var presentingView: UIView!
    private var mask: CAShapeLayer!
    
    // MARK: Presentation

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView
            , let presentedView = presentedView
            , let presentingViewSnapshot = presentingViewController.view.snapshotView(afterScreenUpdates: false)
            else { return }
        
        (presentedViewController as? UINavigationController)?.navigationBar.barStyle = .black
        containerView.backgroundColor = .black
        
        // Rounded top corners
        mask = CAShapeLayer()
        mask.path = UIBezierPath(roundedTopRect: presentedView.bounds, cornerRadius: cornerRadius).cgPath
        presentedView.layer.mask = mask
        presentedView.layer.masksToBounds = true
        
        presentingView = presentingViewSnapshot
        presentingView.frame = containerView.bounds
        presentingView.layer.masksToBounds = true
        containerView.addSubview(presentingView)
        
        dimView = UIView(frame: containerView.bounds)
        dimView.backgroundColor = .black
        dimView.alpha = 0
        dimView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        containerView.addSubview(dimView)
        
        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimView.alpha = 0.5
            self.presentingView.layer.cornerRadius = cornerRadius
            self.presentingView.frame = containerView.frame.insetBy(dx: 10, dy: 20)
        }, completion: nil)
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        if !completed {
            dimView.removeFromSuperview()
            presentingView.removeFromSuperview()
        }
    }
    
    override func dismissalTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        refreshSnapshot() // Keep the background view updated
        
        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimView.alpha = 0
            self.presentingView.frame = containerView.frame
        }, completion: { context in
            if !context.isCancelled {
                self.presentingView.layer.cornerRadius = 0
            }
        })
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            dimView.removeFromSuperview()
            presentingView.removeFromSuperview()
        }
    }
    
    // MARK: Layout
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        
        UIView.animate(withDuration: 0.1) {
            guard let containerView = self.containerView, let presentedView = self.presentedView else { return }
            presentedView.frame = self.frameOfPresentedViewInContainerView
            self.presentingView.frame = containerView.frame.insetBy(dx: 10, dy: 20)
            self.mask.path = UIBezierPath(roundedTopRect: presentedView.bounds, cornerRadius: cornerRadius).cgPath
        }
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        if let container = container as? UIViewController, container == presentedViewController {
            return CGRect(origin: .zero, size: parentSize).insetBy(dx: 0, dy: 15).size
        }
        return super.size(forChildContentContainer: container, withParentContainerSize: parentSize)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        var frame = containerView!.bounds
        frame.size = self.size(forChildContentContainer: presentedViewController, withParentContainerSize: frame.size)
        frame = frame.offsetBy(dx: 0, dy: 30)
        return frame
    }
    
    // MARK: Presented Snapshot
    
    private func refreshSnapshot() {
        guard let containerView = containerView
            , let presentingViewSnapshot = presentingViewController.view.snapshotView(afterScreenUpdates: true)
            else { return }
        
        presentingViewSnapshot.frame = presentingView.frame
        presentingViewSnapshot.layer.masksToBounds = true
        presentingViewSnapshot.layer.cornerRadius = presentingView.layer.cornerRadius
        containerView.insertSubview(presentingViewSnapshot, belowSubview: presentingView)
        presentingView.removeFromSuperview()
        presentingView = presentingViewSnapshot
    }
}

// MARK:- Slide Transition -

class SlideTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    var panGesture: UIPanGestureRecognizer? {
        didSet {
            panGesture?.addTarget(self, action: #selector(handleSwipeUpdate(_:)))
        }
    }
    
    var presenting: Bool = true
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        animate(using: transitionContext)
    }
    
    // MARK: Helper methods
    
    private var viewKey: UITransitionContextViewKey { return presenting ? .to : .from }
    private var vcKey: UITransitionContextViewControllerKey { return presenting ? .to : .from }
    
    private func view(with context: UIViewControllerContextTransitioning) -> UIView {
        return context.view(forKey: viewKey)!
    }
    
    private func viewController(with context: UIViewControllerContextTransitioning) -> UIViewController {
        return context.viewController(forKey: vcKey)!
    }
    
    private func frame(with context: UIViewControllerContextTransitioning) -> CGRect {
        let viewController = self.viewController(with: context)
        return presenting ?
            context.finalFrame(for: viewController) :
            context.initialFrame(for: viewController)
    }
    
    private func animate(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        
        let view = self.view(with: transitionContext)
        let frame = self.frame(with: transitionContext)
        
        container.addSubview(view)
        
        if presenting {
            view.frame = frame.offsetBy(dx: 0, dy: frame.height) // start offscreen
        } else {
            view.frame = frame // start onscreen
        }
        
        let animations = {
            if self.presenting {
                view.frame = frame // end onscreen
            } else {
                view.frame = frame.offsetBy(dx: 0, dy: frame.height) // end offscreen
            }
        }
        
        let completion: ((Bool) -> Void) = { _ in
            let success = !transitionContext.transitionWasCancelled
            
            // Remove the view if presentation failed, or if dismissal succeeded
            if !success && self.presenting || success && !self.presenting {
                view.removeFromSuperview()
            }
            transitionContext.completeTransition(success)
        }
        
        let options: UIViewAnimationOptions = transitionContext.isInteractive ? [.curveLinear] : []
        
        if transitionContext.isInteractive {
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: options, animations: animations, completion: completion)
        } else {
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: options, animations: animations, completion: completion)
        }
    }
    
    private var transitionContext: UIViewControllerContextTransitioning?
    
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        super.startInteractiveTransition(transitionContext)
    }
    
    func handleSwipeUpdate(_ gesture: UIPanGestureRecognizer) {
        guard let transitionContext = transitionContext else { return }
        let translation = gesture.translation(in: transitionContext.containerView)
        let percentage = translation.y / transitionContext.containerView.bounds.height
        
        switch gesture.state {
        case .began: break
        case .changed: update(percentage)
        case .ended:
            let flickMagnitude: CGFloat = 1200 //pts/sec
            let threshold: CGFloat = 0.2
            let velocity = panGesture!.velocity(in: transitionContext.containerView).vector
            let isFlick = (velocity.magnitude > flickMagnitude)
            let isFlickDown = isFlick && (velocity.dy > 0.0)
            let isFlickUp = isFlick && (velocity.dy < 0.0)
            
            if percentage < threshold && !isFlickDown || percentage >= threshold && isFlickUp {
                fallthrough // cancel
            }
            
            completionSpeed = (1-percentage) / CGFloat(transitionDuration(using: transitionContext))
            
            finish()
        case .cancelled, .possible, .failed:
            cancel()
        }
    }
}

extension CGPoint {
    var vector: CGVector { return CGVector(dx: x, dy: y) }
}

extension CGVector {
    var magnitude: CGFloat { return sqrt(dx*dx + dy*dy) }
}

extension UIBezierPath {
    convenience init(roundedTopRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    }
}
