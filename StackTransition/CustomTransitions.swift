import UIKit

/*******************
 FirstViewController
 *******************/

class FirstViewController: UIViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.modalPresentationStyle = .custom // Mandatory for custom presentations
        segue.destination.modalPresentationCapturesStatusBarAppearance = true // Handover control of the status bar to over full screen presentation
        segue.destination.transitioningDelegate = slideTransition
    }
    
    @IBAction func unwindToFirst(_ segue: UIStoryboardSegue) {}
    
    let slideTransition = VerticalSlideTransition()
}

/********************
 SecondViewController
 ********************/

class SecondViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.modalPresentationCapturesStatusBarAppearance = true
    }
    
    @IBAction func pan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began, let slideTransition = transitioningDelegate as? VerticalSlideTransition {
            slideTransition.panGesture = gesture
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func unwindToSecond(_ segue: UIStoryboardSegue) {}
}

// MARK:- Custom Presentation -

class CustomPresentation: UIPresentationController {
    private var dimView: UIView!
    private var presentingView: UIView!
    
    // MARK: Layout
    
    // presentedView will be animated automatically to this frame by the Transition object
    override var frameOfPresentedViewInContainerView: CGRect {
        return containerView!.bounds
            .insetBy(dx: 0, dy: 15) // make shorter
            .offsetBy(dx: 0, dy: 15) // push down
    }
    
    // MARK: Presentation
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView
            , let presentedView = presentedView
            , let presentingViewSnapshot = presentingViewController.view.snapshotView(afterScreenUpdates: false)
            else { fatalError() }
        
        containerView.backgroundColor = .black
        
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
            self.presentingView.frame = containerView.frame
                .insetBy(dx: 10, dy: 20)
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
}

// MARK:- Custom Transition -

// MARK: VerticalSlideTransition

// MARK: Properties
class VerticalSlideTransition: UIPercentDrivenInteractiveTransition {
    
    enum Mode {
        case present, dismiss
    }
    var mode = Mode.present
    
    var isPresenting: Bool { return mode == .present }
    
    var panGesture: UIPanGestureRecognizer? {
        didSet {
            isInteractive = true
            panGesture?.addTarget(self, action: #selector(handlePanGesture(_:)))
        }
    }
    
    var isInteractive = false
    
    fileprivate var transitionContext: UIViewControllerContextTransitioning?
}

// MARK: Animated Transition
extension VerticalSlideTransition: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // toView is presented
        // fromView is dismissed
        guard let view = transitionContext.view(forKey: isPresenting ? .to : .from)
            , let viewController = transitionContext.viewController(forKey: isPresenting ? .to : .from)
            else { fatalError() }
        
        // We're required to add the view manually before the transition begins
        transitionContext.containerView.addSubview(view)
        
        // finalFrame is presented
        // initialFrame is dismissed
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
        let animations = {
            if self.isPresenting {
                view.frame = frame // end onscreen
            } else {
                view.frame = frame.offsetBy(dx: 0, dy: frame.height) // end offscreen
            }
        }
        
        let completion: ((Bool) -> Void) = { _ in
            let success = !transitionContext.transitionWasCancelled
            
            // Remove the view if presentation failed, or
            // if dismissal succeeded
            if !success && self.isPresenting || success && !self.isPresenting {
                view.removeFromSuperview()
            }
            
            // Make sure we call this everytime!
            transitionContext.completeTransition(success)
        }
        
        let duration = transitionDuration(using: transitionContext)
        
        UIView.animate(withDuration: duration, delay: 0, options: [], animations: animations, completion: completion)
    }
}

extension VerticalSlideTransition: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CustomPresentation(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .present
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .dismiss
        return self
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if isInteractive {
            return self
        }
        return nil
    }
}

// MARK: Interactive transition
extension VerticalSlideTransition {
    
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        super.startInteractiveTransition(transitionContext)
    }
    
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let transitionContext = transitionContext else { return }
        let translation = gesture.translation(in: transitionContext.containerView) // How much the finger moved
        let percentage = translation.y / transitionContext.containerView.bounds.height
        let threshold: CGFloat = 0.2 // 20% down
        
        switch gesture.state {
        case .began: break // Handeled by view controller
        case .changed: update(percentage)
        case .ended:
            if percentage < threshold { fallthrough } // cancel
            
            finish()
            isInteractive = false
        default:
            cancel()
            isInteractive = false
        }
    }
}

// NARK:- GrowTransition

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

// MARK:- HorizonalSlideTransition

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
        
        let width = transitionContext.containerView.bounds.width + 10
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
