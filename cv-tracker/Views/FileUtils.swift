import Foundation
import AppKit // Required for NSOpenPanel and NSWorkspace

struct FileUtils {
    
    /// Opens a file selection panel and returns the URL and Security Bookmark
    static func selectFile() -> (url: URL, bookmark: Data)? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                // Create the security bookmark for persistent access
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                return (url, bookmark)
            } catch {
                print("Failed to create bookmark: \(error)")
                return nil
            }
        }
        return nil
    }

    /// Resolves a bookmark and opens the file in its default application
    static func openFile(url: URL?, bookmark: Data?) {
        guard let bookmark = bookmark else {
            // Fallback: if no bookmark, try opening URL directly (works for web links)
            if let url = url { NSWorkspace.shared.open(url) }
            return
        }
        
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if resolvedURL.startAccessingSecurityScopedResource() {
                NSWorkspace.shared.open(resolvedURL)
                // Always stop accessing when the action is triggered
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        } catch {
            print("Failed to resolve bookmark: \(error)")
        }
    }
}
