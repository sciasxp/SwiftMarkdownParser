import Testing
import Foundation
@testable import SwiftMarkdownParser

@Suite struct ReadmeDiagnosticTests {

    let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // Test blockquote with pipes
    @Test func blockquoteWithPipes() async throws {
        let md = """
        > **Versão**: 3.24.4 | **iOS**: 15.0+ | **Swift**: 5.x
        """
        let html = try await parser.parseToHTML(md)
        print("=== BLOCKQUOTE WITH PIPES ===")
        print(html)
        print("===")
        #expect(html.contains("<blockquote>"), "Should contain blockquote tag")
        #expect(html.contains("<strong>"), "Should contain strong tag for bold")
    }

    // Test table
    @Test func simpleTable() async throws {
        let md = """
        | Funcionalidade | Descrição |
        |----------------|-----------|
        | **Modo Offline** | Trabalhar sem conexão |
        | **Planos de Ação** | Criar e gerenciar ações |
        """
        let html = try await parser.parseToHTML(md)
        print("=== SIMPLE TABLE ===")
        print(html)
        print("===")
        #expect(html.contains("<table"), "Should contain table tag")
        #expect(html.contains("<th"), "Should contain th tag")
        #expect(html.contains("<td"), "Should contain td tag")
    }

    // Test large table (more than 10 rows)
    @Test func largeTable() async throws {
        let md = """
        | Funcionalidade | Descrição |
        |----------------|-----------|
        | **Aplicação de Checklists** | Responder perguntas |
        | **Modo Offline** | Trabalhar sem conexão |
        | **Planos de Ação** | Criar ações corretivas |
        | **Agendamentos** | Visualizar avaliações |
        | **Captura de Mídia** | Fotos, vídeos, áudio |
        | **Leitura de QR Code** | Identificar unidades |
        | **Geolocalização** | Validar presença |
        | **Biometria** | Face ID/Touch ID |
        | **SSO/ADFS** | Login corporativo |
        """
        let html = try await parser.parseToHTML(md)
        print("=== LARGE TABLE ===")
        print(html)
        print("===")
        #expect(html.contains("<table"), "Should contain table tag")
        // Check all 9 rows are present
        let tdCount = html.components(separatedBy: "<tr").count - 1
        #expect(tdCount == 10, "Should have 10 rows (1 header + 9 body)")
    }

    // Test horizontal rule between sections
    @Test func horizontalRuleBetweenSections() async throws {
        let md = """
        ## Section 1

        Some content here.

        ---

        ## Section 2

        More content here.
        """
        let html = try await parser.parseToHTML(md)
        print("=== HR BETWEEN SECTIONS ===")
        print(html)
        print("===")
        #expect(html.contains("<hr"), "Should contain hr tag")
        #expect(html.contains("<h2"), "Should contain h2 tags")
    }

    // Test the readme file structure with mixed elements
    @Test func mixedContent() async throws {
        let md = """
        # Checklist Fácil iOS

        > **Versão**: 3.24.4 | **iOS**: 15.0+ | **Swift**: 5.x

        ## Índice

        - [Quick Start](#-quick-start)
        - [Sobre o Projeto](#sobre-o-projeto)

        ---

        ## Quick Start

        ```bash
        git clone git@example.com:repo.git
        cd repo
        ```

        ---

        ## Funcionalidades

        | Funcionalidade | Descrição |
        |----------------|-----------|
        | **Modo Offline** | Trabalhar sem conexão |
        | **Planos de Ação** | Criar ações |

        ---

        ## Arquitetura

        ### Padrões Utilizados

        - **Coordinator Pattern**: Gerencia navegação
        - **Repository Pattern**: Abstrai acesso ao banco
        """
        let html = try await parser.parseToHTML(md)
        print("=== MIXED CONTENT ===")
        print(html)
        print("===")
        #expect(html.contains("<h1"), "Should contain h1")
        #expect(html.contains("<blockquote>"), "Should contain blockquote")
        #expect(html.contains("<hr"), "Should contain hr")
        #expect(html.contains("<table"), "Should contain table")
        #expect(html.contains("<code"), "Should contain code")
    }

    // Test the actual readme file
    @Test func actualReadme() async throws {
        let readmePath = "/Users/sciasxp/Downloads/readme.md"
        guard let data = FileManager.default.contents(atPath: readmePath),
              let content = String(data: data, encoding: .utf8) else {
            Issue.record("Could not read readme.md")
            return
        }

        let html = try await parser.parseToHTML(content)
        print("=== ACTUAL README (first 3000 chars) ===")
        print(String(html.prefix(3000)))
        print("=== ... ===")

        // Check for key elements
        #expect(html.contains("<h1"), "Should contain h1 heading")
        #expect(html.contains("<h2"), "Should contain h2 headings")
        #expect(html.contains("<blockquote>"), "Should contain blockquote")
        #expect(html.contains("<table"), "Should contain tables")
        #expect(html.contains("<hr"), "Should contain horizontal rules")
        #expect(html.contains("<pre"), "Should contain code blocks")

        // Count tables - readme has at least 6 tables
        let tableCount = html.components(separatedBy: "<table").count - 1
        print("Table count: \(tableCount)")
        #expect(tableCount >= 6, "Should have at least 6 tables")

        // Count horizontal rules
        let hrCount = html.components(separatedBy: "<hr").count - 1
        print("HR count: \(hrCount)")
        #expect(hrCount >= 5, "Should have multiple horizontal rules")
    }
}
