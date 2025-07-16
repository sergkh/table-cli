import Foundation

// Executes shell command
func shell(_ command: String, env: Dictionary<String, String> = [:]) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.environment = ProcessInfo.processInfo.environment.merging(env) { (_, new) in new }
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.standardInput = nil

    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .newlines)

    return output
}