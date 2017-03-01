import UIKit

/*******************
 FirstViewController
 *******************/

class FirstViewController: UIViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.modalPresentationStyle = .custom
        segue.destination.modalPresentationCapturesStatusBarAppearance = true
        segue.destination.transitioningDelegate = transition
    }
    
    let transition = CustomTransition()
    
    @IBAction func unwindToFirst(_ segue: UIStoryboardSegue) {}
}

class CustomTransition: UIPercentDrivenInteractiveTransition, UIViewControllerTransitioningDelegate {
    enum Mode {
        case present, dismiss
    }
    var mode = Mode.present
    
    var isInteractive = false
    
    var panGesture: UIPanGestureRecognizer? {
        didSet {
            isInteractive = true
            panGesture?.addTarget(self, action: #selector(handleGesture(_:)))
        }
    }
    
    fileprivate var transitionContext: UIViewControllerContextTransitioning!
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CardPresentation(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .present
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .dismiss
        return self
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if isInteractive {
            return self
        }
        return nil
    }
}

/********************
 SecondViewController
 ********************/

class SecondViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction func pan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began, let transition = transitioningDelegate as? CustomTransition {
            transition.panGesture = gesture
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    
    @IBAction func unwindToSecond(_ segue: UIStoryboardSegue) {}
}

// MARK:- Custom Presentation -

class CardPresentation: UIPresentationController {
    private var dimView: UIView!
    private var presentingView: UIView!
    
    override var frameOfPresentedViewInContainerView: CGRect {
        return containerView!.bounds
            .insetBy(dx: 0, dy: 15) // shorter
            .offsetBy(dx: 0, dy: 15) // push down
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView
            , let presentedView = presentedView
            , let presentingViewSnapshow = presentingViewController.view.snapshotView(afterScreenUpdates: false)
            else { fatalError() }
        
        containerView.backgroundColor = .black
        
        presentingView = presentingViewSnapshow
        presentingView.frame = containerView.bounds
        presentingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        presentingView.layer.masksToBounds = true
        containerView.addSubview(presentingView)
        
        dimView = UIView(frame: containerView.bounds)
        dimView.backgroundColor = .black
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.alpha = 0
        containerView.addSubview(dimView)
        
        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimView.alpha = 0.5
            presentedView.layer.cornerRadius = 10
            self.presentingView.frame = containerView.bounds
                .insetBy(dx: 10, dy: 20)
            self.presentingView.layer.cornerRadius = 10
        }, completion: nil)
    }
    
    override func dismissalTransitionWillBegin() {
        presentingViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimView.alpha = 0
            self.presentingView.frame = self.containerView!.bounds
        }, completion: { context in
            if !context.isCancelled {
                self.presentingView.layer.cornerRadius = 0
            }
        })
    }
}

// MARK:- Custom Transition -

// Animated Transition
extension CustomTransition: UIViewControllerAnimatedTransitioning {
    
    var isPresenting: Bool { return mode == .present }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let view = transitionContext.view(forKey: isPresenting ? .to : .from)
            , let viewController = transitionContext.viewController(forKey: isPresenting ? .to : .from)
            else { return }
        
        transitionContext.containerView.addSubview(view)
        
        let frame = isPresenting ?
            transitionContext.finalFrame(for: viewController) :
            transitionContext.initialFrame(for: viewController)
        
        // Starting frame
        if isPresenting {
            view.frame = frame.offsetBy(dx: 0, dy: frame.height) // start offscreen
        } else {
            view.frame = frame // start onscreen
        }
        
        // End frame
        let animation = {
            if self.isPresenting {
                view.frame = frame // onscreen
            } else {
                view.frame = frame.offsetBy(dx: 0, dy: frame.height) // offscreen
            }
        }
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, delay: 0, options: [], animations: animation) { _ in
            let success = !transitionContext.transitionWasCancelled
            if !success && self.isPresenting || success && !self.isPresenting {
                view.removeFromSuperview()
            }
            transitionContext.completeTransition(success)
        }
    }
}

// Interactive Transition
extension CustomTransition {
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        super.startInteractiveTransition(transitionContext)
    }
    
    func handleGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: transitionContext.containerView)
        let percentage = translation.y / transitionContext.containerView.bounds.height
        let threshold: CGFloat = 0.2 // 20%
        
        switch gesture.state {
        case .began: break
        case .changed: self.update(percentage)
        case .ended:
            if percentage < threshold { fallthrough } // cancel
            self.finish()
            isInteractive = false
        case .failed, .possible, .cancelled:
            self.cancel()
            isInteractive = false
        }
    }
}





















/*********************************
 UINavigationController Transition
 *********************************/

class MyNavigationController: UINavigationController {
    
    let transition = GrowTransition()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = transition
    }
}

class GrowTransition: NSObject, UIViewControllerAnimatedTransitioning, UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.operation = operation
        return self
    }
    
    private var operation: UINavigationControllerOperation!
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: .from)
            , let toViewController = transitionContext.viewController(forKey: .to)
            , let fromView = transitionContext.view(forKey: .from)
            , let toView = transitionContext.view(forKey: .to)
            else { fatalError() }
        
        // Setup required frames
        fromView.frame = transitionContext.initialFrame(for: fromViewController)
        toView.frame = transitionContext.finalFrame(for: toViewController)
        
        // Use transform for animations
        let zeroScale = CGAffineTransform(scaleX: 0.01, y: 0.01)
        
        // Start scale
        if self.operation == .push {
            toView.transform = zeroScale // grow from center
            transitionContext.containerView.addSubview(toView)
        } else {
            fromView.transform = .identity // shrink from fullscreen
            transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
        }
        
        // End scale
        let animations = {
            if self.operation == .push {
                toView.transform = .identity // grow to fullscreen
            } else {
                fromView.transform = zeroScale // shrink to center
            }
        }
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [], animations: animations, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}

/*****************************
 UITabBarController Transition
 *****************************/

class MyTabBarController: UITabBarController {
    
    let transition = HorizonalSlideTransition()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        delegate = transition
    }
}

class HorizonalSlideTransition: NSObject, UIViewControllerAnimatedTransitioning, UITabBarControllerDelegate {
    
    enum Direction {
        case forward, backwards
    }
    var direction = Direction.forward
    
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        guard let fromIndex = tabBarController.viewControllers?.index(of: fromVC)
            , let toIndex = tabBarController.viewControllers?.index(of: toVC)
            else { fatalError() }
        
        if toIndex > fromIndex { direction = .forward }
        else { direction = .backwards }
        
        return self
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: .from)
            , let toViewController = transitionContext.viewController(forKey: .to)
            , let fromView = transitionContext.view(forKey: .from)
            , let toView = transitionContext.view(forKey: .to)
            else { fatalError() }
        
        transitionContext.containerView.addSubview(toView)
        
        // Setup required frames
        fromView.frame = transitionContext.initialFrame(for: fromViewController)
        toView.frame = transitionContext.finalFrame(for: toViewController)
        
        let width = transitionContext.containerView.bounds.width
        let transform: CGAffineTransform
        
        // Starting location
        if direction == .forward {
            transform = CGAffineTransform(translationX: -width, y: 0)
        } else {
            transform = CGAffineTransform(translationX: width, y: 0)
        }
        
        // Start location
        toView.transform = transform.inverted() // start offscreen
        fromView.transform = .identity // start onscreen
        
        // End location
        let animations = {
            toView.transform = .identity // end onscreen
            fromView.transform = transform // end offscreen
        }
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [], animations: animations, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
            fromView.transform = .identity
        })
    }
}
