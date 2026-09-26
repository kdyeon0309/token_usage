import Foundation

struct ClaudeBridgeInstaller: Sendable {
    func install() async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let installerURL = Bundle.main.url(
                forResource: "install_claude_bridge",
                withExtension: "py"
            ), Bundle.main.url(
                forResource: "claude_statusline_bridge",
                withExtension: "py"
            ) != nil else {
                throw UsageProviderError.unavailable("앱 번들에서 Claude 연결 스크립트를 찾지 못했습니다.")
            }

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [installerURL.path]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw UsageProviderError.processFailed("Claude 연결 스크립트를 실행하지 못했습니다.")
            }
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard process.terminationStatus == 0 else {
                throw UsageProviderError.processFailed(
                    errorOutput?.isEmpty == false ? errorOutput! : "Claude 연결 설정에 실패했습니다."
                )
            }
            return output?.isEmpty == false
                ? output!
                : "Claude 연결 설정을 완료했습니다."
        }.value
    }
}

