//
//  UIMailDialog.swift
//  secant
//
//  Created by Michal Fousek on 28.02.2023.
//

import Foundation
import MessageUI
import UIKit
import SwiftUI

extension MFMailComposeViewController {
    /// Nonisolated wrapper around `canSendMail()`, which became `@MainActor`-isolated
    /// in Swift 6. TCA reducers always run inside `Store.send(_:)` (itself `@MainActor`),
    /// so asserting `MainActor` isolation from a reducer case is safe.
    nonisolated static func canSendMailFromReducer() -> Bool {
        MainActor.assumeIsolated { canSendMail() }
    }
}

class UIMailDialog: UIView {
    var completion: (() -> Void)?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
}

extension UIMailDialog {
    func doInitialSetup(supportData: SupportData, completion: @escaping () -> Void) {
        self.completion = completion
        DispatchQueue.main.async {
            let mailVC = MFMailComposeViewController()
            mailVC.mailComposeDelegate = self

            // Configure the fields of the interface.
            mailVC.setToRecipients([supportData.toAddress])
            mailVC.setSubject(supportData.subject)
            mailVC.setMessageBody("\n\n\(supportData.message)", isHTML: false)

            let rootVC = UIApplication.shared.connectedScenes
                .map { $0 as? UIWindowScene }
                .compactMap { $0 }
                .first?.windows.first?.rootViewController

            rootVC?.present(
                mailVC,
                animated: true,
                completion: nil
            )
        }
    }
}

extension UIMailDialog: @preconcurrency MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: completion)
    }
}

struct UIMailDialogView: UIViewRepresentable {
    let supportData: SupportData
    let completion: () -> Void

    init(supportData: SupportData, completion: @escaping () -> Void) {
        self.supportData = supportData
        self.completion = completion
    }
    
    func makeUIView(context: UIViewRepresentableContext<UIMailDialogView>) -> UIMailDialog {
        let view = UIMailDialog()
        view.doInitialSetup(supportData: supportData, completion: completion)
        return view
    }

    func updateUIView(_ uiView: UIMailDialog, context: UIViewRepresentableContext<UIMailDialogView>) {
        // We can leave it empty here because the view is just handler how to bridge UIKit's UIActivityViewController
        // presentation into SwiftUI. The view itself is not visible, only instantiated, therefore no updates needed.
    }

    typealias UIViewType = UIMailDialog
}
