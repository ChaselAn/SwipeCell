import UIKit
import AsyncDisplayKit

public protocol ASTableNodeSwipableDelegate: class {
    func swipe_tableNode(_ tableNode: ASTableNode, editActionsOptionsForRowAt indexPath: IndexPath) -> [SwipedAction]

    func swipe_tableNode(_ tableNode: ASTableNode, canEditRowAt indexPath: IndexPath) -> Bool
}

public class SwipedAction {

    public enum ConfirmStyle {
        case none
        case custom(title: String)
    }

    public var title: String
    public var backgroundColor: UIColor = UIColor.red
    public var titleColor: UIColor = UIColor.white
    public var titleFont: UIFont = UIFont.systemFont(ofSize: 14)
    public var preferredWidth: CGFloat?
    public var handler: ((SwipedAction) -> Void)?
    public var needConfirm = ConfirmStyle.none
    public var horizontalMargin: CGFloat = 10

    public init(title: String, handler: ((SwipedAction) -> Void)?) {
        self.title = title
        self.handler = handler
    }

    public init(title: String, backgroundColor: UIColor, titleColor: UIColor, titleFont: UIFont, preferredWidth: CGFloat?, handler: ((SwipedAction) -> Void)?) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.preferredWidth = preferredWidth
        self.handler = handler
    }
}

open class SwipableCellNode: ASCellNode {

    public var scale: CGFloat = 0.75

    private var originalX: CGFloat = 0
    private weak var tableNode: ASTableNode?
    private var actionsView: ActionsView?

    private var isActionShowing = false
    private var isHideSwiping = false
    private var isPanning = false
    private var animator: SwipeAnimator?

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        gesture.delegate = self
        return gesture
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        gesture.delegate = self
        return gesture
    }()

    public init(tableNode: ASTableNode) {
        self.tableNode = tableNode
        super.init()

        clipsToBounds = false

        view.backgroundColor = UIColor.green

        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(tapGestureRecognizer)

        tableNode.view.panGestureRecognizer.removeTarget(self, action: nil)
        tableNode.view.panGestureRecognizer.addTarget(self, action: #selector(tableViewDidPan))
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {

        return contains(point: point)
    }

    private func contains(point: CGPoint) -> Bool {
        return point.y > frame.minY && point.y < frame.maxY
    }

    deinit {
        tableNode?.view.panGestureRecognizer.removeTarget(self, action: nil)
    }

    @objc private func didPan(gesture: UIPanGestureRecognizer) {

        guard let target = gesture.view else { return }

        switch gesture.state {
        case .began:
            isPanning = true
            stopAnimatorIfNeeded()

            originalX = frame.origin.x

            if !isActionShowing {
                if gesture.velocity(in: target).x > 0 { return }
                isActionShowing = true
                showActionsView()
            }
        case .changed:

            guard let actionsView = actionsView, let tableNode = tableNode else { return }

            let translationX = gesture.translation(in: target).x * scale
            var offsetX = originalX + translationX
            if offsetX > 0 {
                target.frame.origin.x = 0
            } else {
                if offsetX < -tableNode.bounds.width * 3 {
                    offsetX = -tableNode.bounds.width * 3
                }
                target.frame.origin.x = offsetX
                let progress = abs(offsetX) / actionsView.preferredWidth

                if !actionsView.isConfirming {
                    actionsView.setProgress(progress)
                }
            }

        case .ended:

            isPanning = false
            guard let actionsView = actionsView else {
                reset()
                return
            }
            let translationX = gesture.translation(in: target).x * scale
            if originalX + translationX >= 0 {
                reset()
                return
            }

            let offSetX = translationX < 0 ? -actionsView.preferredWidth : 0
            let velocity = gesture.velocity(in: target)

            let distance = -frame.origin.x
            let normalizedVelocity = velocity.x / distance

            animate(duration: 0.4, toOffset: offSetX, withInitialVelocity: normalizedVelocity * 0.4, isConfirming: actionsView.isConfirming) { [weak self] _ in
                guard let strongSelf = self else { return }
                if strongSelf.isActionShowing && translationX >= 0 {
                    strongSelf.reset()
                }
            }
        case .cancelled:
            isPanning = false
            hideSwipe(animated: false)
        default:
            break
        }
    }

    @objc private func didTap(gesture: UITapGestureRecognizer) {
        hideSwipe(animated: true)
    }

    @objc private func tableViewDidPan(gesture: UIPanGestureRecognizer) {
        hideSwipe(animated: true)
    }

    public func hideSwipe(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard !isPanning else { return }
        guard isActionShowing else { return }
        guard !isHideSwiping else { return }
        isHideSwiping = true
        isActionShowing = false
        if animated {
            animate(duration: 0.5, toOffset: 0, isConfirming: actionsView?.isConfirming == true, fromHideAction: true) { [weak self] complete in
                completion?(complete)
                self?.reset()
            }
        } else {
            self.frame.origin = CGPoint(x: 0, y: self.frame.origin.y)

            self.layoutIfNeeded()
            reset()
        }
    }

    private func reset() {
        isActionShowing = false
        clipsToBounds = false
        isHideSwiping = false
        actionsView?.removeFromSuperview()
        actionsView = nil
    }

    @discardableResult
    private func showActionsView() -> Bool {

        guard let tableNode = tableNode else { return false }

        super.isHighlighted = false

        let selectedIndexPaths = tableNode.indexPathsForSelectedRows
        selectedIndexPaths?.forEach { tableNode.deselectRow(at: $0, animated: false) }

        self.actionsView?.removeFromSuperview()
        self.actionsView = nil

        guard let indexPath = tableNode.indexPath(for: self),
            let source = tableNode.circle_swipeDelegate,
            source.swipe_tableNode(tableNode, canEditRowAt: indexPath) else { return false }

        let actions = source.swipe_tableNode(tableNode, editActionsOptionsForRowAt: indexPath)
        let actionsView = ActionsView(actions: actions)
        actionsView.leftMoveWhenConfirm = { [weak self] in

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.frame.origin.x = -actionsView.preferredWidth
            })
        }

        view.addSubview(actionsView)

        actionsView.translatesAutoresizingMaskIntoConstraints = false
        actionsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        actionsView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 3).isActive = true
        actionsView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        actionsView.leftAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        actionsView.setNeedsUpdateConstraints()

        self.actionsView = actionsView

        return true
    }

    private func animate(duration: Double = 0.7, toOffset offset: CGFloat, withInitialVelocity velocity: CGFloat = 0, isConfirming: Bool = false, fromHideAction: Bool = false, completion: ((Bool) -> Void)? = nil) {

        stopAnimatorIfNeeded()

        if isHideSwiping && !fromHideAction {
            isHideSwiping = false
        }
        layoutIfNeeded()

        if offset == 0, frame.origin.x >= -30 {
            frame.origin.x = 0
            if !isConfirming {
                self.actionsView?.setProgress(offset <= 0 ? 1 : 0)
            }
            completion?(true)
            return
        }

        let animator: SwipeAnimator = {
            if velocity > 0 {

                return UIViewSpringAnimator(duration: duration, damping: 1.0, initialVelocity: velocity)

            } else {

                return UIViewSpringAnimator(duration: duration, damping: 1.0)

            }
        }()

        animator.addAnimations({

            self.frame.origin = CGPoint(x: offset, y: self.frame.origin.y)

            if !isConfirming {
                self.actionsView?.setProgress(offset <= 0 ? 1 : 0)
            }

            self.layoutIfNeeded()
        })

        if let completion = completion {
            animator.addCompletion(completion: completion)
        }

        self.animator = animator

        animator.startAnimation()
    }

    private func stopAnimatorIfNeeded() {
        if animator?.isRunning == true {
            animator?.stopAnimation(true)
        }
    }

}

extension SwipableCellNode: UIGestureRecognizerDelegate {

    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        let swipeCells = tableNode?.visibleNodes.compactMap({ $0 as? SwipableCellNode }).filter({ $0.isActionShowing || $0.isHideSwiping })
        if gestureRecognizer == panGestureRecognizer,
            let view = gestureRecognizer.view,
            let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            if !isActionShowing {
                swipeCells?.forEach({ $0.hideSwipe(animated: true) })
            }
            let translation = gestureRecognizer.translation(in: view)
            return abs(translation.y) <= abs(translation.x)
        }

        if gestureRecognizer == tapGestureRecognizer {
            if isActionShowing {
                return true
            }
            if swipeCells?.count != 0 {
                swipeCells?.forEach({ $0.hideSwipe(animated: true) })
                return true
            }
            return false
        }

        return true
    }
}

class ActionsView: UIView {

    private var actionViews: [ActionView] = []

    var preferredWidth: CGFloat = 0
    var isConfirming = false

    var leftMoveWhenConfirm: (() -> Void)?

    init(actions: [SwipedAction]) {

        super.init(frame: .zero)

        clipsToBounds = true

        for action in actions {
            let actionView = ActionView(action: action)

            actionView.beConfirm = { [weak self] in
                self?.isConfirming = true
            }

            actionView.confirmAnimationCompleted = { [weak self] in
                self?.actionViews.filter({ !$0.isConfirming }).forEach({ $0.isHidden = true })
            }
            addSubview(actionView)

            actionViews.append(actionView)
            actionView.toX = preferredWidth
            preferredWidth += actionView.widthConst
        }
    }

    func setProgress(_ progress: CGFloat) {
        for actionView in actionViews {
            actionView.frame.origin.x = actionView.toX * progress
            actionView.frame.size = bounds.size
            actionView.leftMoveWhenConfirm = leftMoveWhenConfirm
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ActionView: UIView {

    var margin: CGFloat = 10

    var beConfirm: (() -> Void)?
    var leftMoveWhenConfirm: (() -> Void)?
    var confirmAnimationCompleted: (() -> Void)?

    var widthConst: CGFloat {
        return action.preferredWidth ?? (action.title.getWidth(withFont: action.titleFont) + 2 * margin)
    }

    var toX: CGFloat = 0

    private var titleLabel = UILabel()
    private let action: SwipedAction
    private var widthConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?

    private(set) var isConfirming = false

    init(action: SwipedAction) {
        self.action = action
        super.init(frame: CGRect.zero)

        margin = action.horizontalMargin
        backgroundColor = action.backgroundColor

        titleLabel.textColor = action.titleColor
        titleLabel.textAlignment = .center
        titleLabel.text = action.title
        titleLabel.numberOfLines = 0
        titleLabel.font = action.titleFont

        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        leadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin)
        leadingConstraint?.isActive = true
        titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        widthConstraint = titleLabel.widthAnchor.constraint(equalToConstant: widthConst - 2 * margin)
        widthConstraint?.isActive = true

        titleLabel.isUserInteractionEnabled = false

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTap() {
        if case .custom(let title) = action.needConfirm, !isConfirming {

            isConfirming = true
            beConfirm?()
            titleLabel.text = title
            superview?.bringSubview(toFront: self)

            UIView.animate(withDuration: 0.15, animations: {
                [weak self] in
                guard let strongSelf = self else { return }
                self?.frame.origin.x = 0
                self?.widthConstraint?.constant = title.getWidth(withFont: strongSelf.action.titleFont)
                if let superView = strongSelf.superview as? ActionsView {
                    let deleteWidth = title.getWidth(withFont: strongSelf.action.titleFont) + 2 * strongSelf.margin
                    if superView.preferredWidth < deleteWidth {
                        superView.preferredWidth = deleteWidth
                        strongSelf.leftMoveWhenConfirm?()
                    } else {
                        strongSelf.leadingConstraint?.constant = (superView.preferredWidth - title.getWidth(withFont: strongSelf.action.titleFont)) / 2
                    }
                }
                strongSelf.layoutIfNeeded()
            }, completion: { [weak self] (_) in
                    self?.confirmAnimationCompleted?()
            })
        } else {
            action.handler?(action)
        }
    }

}

protocol SwipeAnimator {
    /// A Boolean value indicating whether the animation is currently running.
    var isRunning: Bool { get }

    /**
     The animation to be run by the SwipeAnimator

     - parameter animation: The closure to be executed by the animator
     */
    func addAnimations(_ animation: @escaping () -> Void)

    /**
     Completion handler for the animation that is going to be started

     - parameter completion: The closure to be execute on completion of the animator
     */
    func addCompletion(completion: @escaping (Bool) -> Void)

    /**
     Starts the defined animation
     */
    func startAnimation()

    /**
     Starts the defined animation after the given delay

     - parameter delay: Delay of the animation
     */
    func startAnimation(afterDelay delay: TimeInterval)

    /**
     Stops the animations at their current positions.

     - parameter withoutFinishing: A Boolean indicating whether any final actions should be performed.
     */
    func stopAnimation(_ withoutFinishing: Bool)
}

class UIViewSpringAnimator: SwipeAnimator {
    var isRunning: Bool = false

    let duration: TimeInterval
    let damping: CGFloat
    let velocity: CGFloat

    var animations: (() -> Void)?
    var completion: ((Bool) -> Void)?

    required init(duration: TimeInterval,
                  damping: CGFloat,
                  initialVelocity velocity: CGFloat = 0) {
        self.duration = duration
        self.damping = damping
        self.velocity = velocity
    }

    func addAnimations(_ animations: @escaping () -> Void) {
        self.animations = animations
    }

    func addCompletion(completion: @escaping (Bool) -> Void) {
        self.completion = { [weak self] finished in
            guard self?.isRunning == true else { return }

            self?.isRunning = false
            self?.animations = nil
            self?.completion = nil

            completion(finished)
        }
    }

    func startAnimation() {
        self.startAnimation(afterDelay: 0)
    }

    func startAnimation(afterDelay delay: TimeInterval) {
        guard let animations = animations else { return }

        isRunning = true

        UIView.animate(withDuration: duration,
                       delay: delay,
                       usingSpringWithDamping: damping,
                       initialSpringVelocity: velocity,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: animations,
                       completion: completion)
    }

    func stopAnimation(_ withoutFinishing: Bool) {
        isRunning = false
    }
}

extension ASTableNode {

    private static var circle_swipeDelegateKey: Character!

    public weak var circle_swipeDelegate: ASTableNodeSwipableDelegate? {
        set {
            objc_setAssociatedObject(self, &ASTableNode.circle_swipeDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &ASTableNode.circle_swipeDelegateKey) as? ASTableNodeSwipableDelegate
        }
    }

}
