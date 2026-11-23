import AppKit
import CorkboardCore

enum UpdatePrompt {
    private static var checking = false

    static func check() {
        guard !checking else { return }
        checking = true
        UpdateClient.fetch { report in
            DispatchQueue.main.async {
                checking = false
                present(report)
            }
        }
    }

    private static func present(_ report: UpdateReport) {
        let alert = NSAlert()
        alert.alertStyle = report.isFailure ? .warning : .informational
        switch report {
        case .upToDate(let current):
            alert.messageText = "Corkboard is up to date"
            alert.informativeText = "You're running \(current)."
        case .ahead(let current, let latest):
            alert.messageText = "Corkboard \(current) is newer than the latest release"
            alert.informativeText = "The latest published release is \(latest)."
        case .available(let current, let latest, let page):
            alert.messageText = "Corkboard \(latest) is available"
            alert.informativeText = "You're running \(current)."
            alert.addButton(withTitle: "View Release")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(page)
            }
            return
        case .failed(let message):
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = message
        }
        alert.runModal()
    }
}

enum UpdateClient {
    static func fetch(completion: @escaping (UpdateReport) -> Void) {
        let current = CorkboardVersion.current
        URLSession.shared.dataTask(with: UpdateChecker.request(current: current)) {
            data, response, error in
            completion(
                UpdateChecker.report(current: current, data: data, response: response, error: error)
            )
        }.resume()
    }

    static func checkBlocking() -> UpdateReport {
        let box = ReportBox()
        let semaphore = DispatchSemaphore(value: 0)
        fetch { report in
            box.report = report
            semaphore.signal()
        }
        semaphore.wait()
        return box.report
    }

    private final class ReportBox {
        var report = UpdateReport.failed("Couldn't check for updates.")
    }
}
