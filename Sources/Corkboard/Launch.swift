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
        CorkboardApp.main()
    }
}
