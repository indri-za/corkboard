import CorkboardCore
import Darwin
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
        if arguments.contains("--init") {
            let positional = arguments.first { argument in
                !argument.hasPrefix("-") && argument != "--"
            }
            let directory: URL
            if let positional {
                directory = URL(fileURLWithPath: positional).standardizedFileURL
            } else {
                directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            do {
                let root = try TicketBoard.create(in: directory)
                print("Created a tickets folder at \(root.path)")
                fflush(stdout)
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        CorkboardApp.main()
    }
}
