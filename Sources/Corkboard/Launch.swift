import CorkboardCore
import Foundation

@main
enum CorkboardMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--version") {
            print("corkboard \(CorkboardVersion.current)")
            return
        }
        if arguments.contains("--update") {
            let report = UpdateClient.checkBlocking()
            print(report.text)
            if report.isFailure {
                exit(1)
            }
            return
        }
        CorkboardApp.main()
    }
}
