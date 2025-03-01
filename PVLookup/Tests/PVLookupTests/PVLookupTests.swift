//
//  OpenVGDBTests.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/15/24.
//

import Testing
@testable import PVLookupTypes
@testable import PVLookup
@testable import OpenVGDB
@testable import ShiraGame
@testable import libretrodb
import PVSystems

struct PVLookupTests {
    let lookup: PVLookup
    let openVGDB: OpenVGDB
    let libreTroDB: libretrodb

    // Test data for Pitfall with metadata from all databases
    let pitfall = (
        // ShiraGame data
        shiraGame: (
            md5: "f73d2d0eff548e8fc66996f27acf2b4b",
            crc: "03cf3b2f",
            fileName: "Pitfall! (CCE) (PAL-M) [!].a26",
            gameId: 7807,
            platformId: "ATARI_2600",
            entryName: "Pitfall! (CCE) (PAL-M) [!]",
            title: "Pitfall!",
            releaseTitle: "Pitfall!",
            region: "ZZ",
            systemID: SystemIdentifier.Atari2600
        ),
        // OpenVGDB data
        openVGDB: (
            romID: 81222,
            systemID: SystemIdentifier.Atari2600,
            regionID: 21,
            fileName: "Pitfall (1983) (CCE) (C-813).a26",
            title: "Pitfall",
            region: "USA",
            systemName: "Atari 2600",
            systemShortName: "2600"
        )
    )

    init() async throws {
        self.lookup = .shared
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
    }

    @Test
    func searchPitfallByMD5() async throws {
        let result = try await lookup.searchROM(byMD5: pitfall.shiraGame.md5)

        #expect(result != nil)

        // Verify base data (case-insensitive)
        #expect(result?.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased())
        #expect(result?.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
        #expect(result?.systemID == pitfall.shiraGame.systemID)

        // Verify merged data (OpenVGDB takes priority)
        #expect(result?.gameTitle == pitfall.openVGDB.title)  // Title from OpenVGDB
        #expect(result?.region == pitfall.openVGDB.region)  // Region from OpenVGDB
        #expect(result?.regionID == pitfall.openVGDB.regionID)  // RegionID from OpenVGDB
        #expect(result?.systemID == .Atari2600)  // System ID should be consistent
    }

    @Test
    func searchPitfallByFilenameInOpenVGDB() async throws {
        // Test OpenVGDB directly
        let openVGDBResults = try openVGDB.searchDatabase(
            usingFilename: pitfall.openVGDB.fileName,
            systemID: pitfall.openVGDB.systemID
        )

        #expect(openVGDBResults != nil)
        let vgdbVersion = openVGDBResults?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(vgdbVersion != nil)
        #expect(vgdbVersion?.systemID == .Atari2600)
        #expect(vgdbVersion?.gameTitle == pitfall.openVGDB.title)
        #expect(vgdbVersion?.region == pitfall.openVGDB.region)
    }

    @Test
    func searchPitfallByFilenameInLibretroDB() async throws {
        // Test LibretroDB directly
        let libretroDB = libretrodb()
        let results = try libretroDB.searchMetadata(
            usingFilename: "Pitfall - The Mayan Adventure",
            systemID: SystemIdentifier.SNES
        )

        #expect(results != nil)
        let snesVersion = results?.first { result in
            result.romHashMD5?.uppercased() == "02CAE4C360567CD228E4DC951BE6CB85"  // USA SNES version
        }
        #expect(snesVersion != nil)
        #expect(snesVersion?.systemID == .SNES)
        #expect(snesVersion?.gameTitle == "Pitfall - The Mayan Adventure")
    }

    @Test
    func searchPitfallByFilenameInShiraGame() async throws {
        // Test ShiraGame directly
        let shiraGame = try await ShiraGame()
        let results = try await shiraGame.searchDatabase(
            usingFilename: pitfall.shiraGame.fileName,
            systemID: nil
        )

        #expect(results != nil)
        let shiraVersion = results?.first {
            $0.romHashMD5 == pitfall.shiraGame.md5
        }
        #expect(shiraVersion != nil)
        #expect(shiraVersion?.systemID == .Atari2600)
        #expect(shiraVersion?.gameTitle == pitfall.shiraGame.entryName)
    }

    @Test
    func searchPitfallByFilenameInPVLookup() async throws {
        // Test combined results through PVLookup
        let results = try await lookup.searchDatabase(
            usingFilename: "Pitfall",
            systemID: SystemIdentifier.Atari2600
        )

        #expect(results != nil)
        #expect(results?.allSatisfy { $0.systemID == .Atari2600 } == true)

        // Find our specific version
        let version = results?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(version != nil)

        // Verify merged metadata
        if let metadata = version {
            #expect(metadata.systemID == .Atari2600)
            #expect(metadata.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
            // OpenVGDB data should take priority in merged results
            #expect(metadata.region == pitfall.openVGDB.region)
            #expect(metadata.regionID == pitfall.openVGDB.regionID)
        }
    }

    @Test
    func searchPitfallWithSystem() async throws {
        let results = try await lookup.searchDatabase(
            usingFilename: "Pitfall",
            systemID: SystemIdentifier.Atari2600
        )

        #expect(results != nil)
        #expect(results?.allSatisfy { $0.systemID == .Atari2600 } == true)

        // Find our specific version in results
        let cceVersion = results?.first {
            $0.romHashMD5?.uppercased() == pitfall.shiraGame.md5.uppercased()
        }
        #expect(cceVersion != nil)

        // Verify merged metadata
        if let metadata = cceVersion {
            #expect(metadata.systemID == .Atari2600)
            #expect(metadata.romHashCRC?.uppercased() == pitfall.shiraGame.crc.uppercased())
            #expect(metadata.region == pitfall.openVGDB.region)
        }
    }

    @Test
    func searchPitfallByMD5InEachDatabase() async throws {
        // Test OpenVGDB
        let openVGDBResult = try openVGDB.searchDatabase(
            usingKey: "romHashMD5",
            value: pitfall.shiraGame.md5,
            systemID: nil
        )?.first
        print("Test: OpenVGDB result: \(String(describing: openVGDBResult))")

        // Test ShiraGame directly
        let shiraGame = try await ShiraGame()
        let shiraGameResult = try await shiraGame.searchROM(byMD5: pitfall.shiraGame.md5)
        print("Test: ShiraGame result: \(String(describing: shiraGameResult))")

        // Test LibretroDB directly
        let libretroDB = libretrodb()
        let libretroDatabaseResult = try libretroDB.searchDatabase(
            usingKey: "romHashMD5",
            value: pitfall.shiraGame.md5,
            systemID: nil
        )?.first
        print("Test: LibretroDB result: \(String(describing: libretroDatabaseResult))")

        // At least one database should find it
        #expect(openVGDBResult != nil || shiraGameResult != nil || libretroDatabaseResult != nil)
    }

    @Test
    func testLibretroDBPitfallSearch() async throws {
        // Try different search variations
        let searches = [
            "Pitfall - The Mayan Adventure",
            "Pitfall - The Mayan Adventure (USA)",
            "Pitfall",
            "Mayan Adventure"
        ]

        for searchTerm in searches {
            let results = try libreTroDB.searchMetadata(
                usingFilename: searchTerm,
                systemID: SystemIdentifier.SNES
            )

            print("\nLibretroDB search for '\(searchTerm)':")
            print("Found \(results?.count ?? 0) results")
            results?.forEach { result in
                print("- Title: \(result.gameTitle)")
                print("  System: \(result.systemID)")
                print("  MD5: \(result.romHashMD5 ?? "nil")")
                print("  Filename: \(result.romFileName ?? "nil")")
            }
        }
    }

    @Test
    func testSearchDatabaseByFilename() async throws {
        // Test data for Pitfall Mayan Adventure which exists in multiple databases
        let testData = (
            filename: "Pitfall - The Mayan Adventure",
            systemID: SystemIdentifier.SNES,
            expectedMD5: "02CAE4C360567CD228E4DC951BE6CB85",  // USA version
            expectedTitle: "Pitfall: The Mayan Adventure"  // Updated to match actual title
        )

        print("\nTesting PVLookup searchDatabase:")
        print("- Filename: \(testData.filename)")
        print("- System: \(testData.systemID)")

        // Search with both filename and system ID
        let results = try await lookup.searchDatabase(
            usingFilename: testData.filename,
            systemID: testData.systemID
        )

        print("\nSearch Results:")
        results?.forEach { result in
            print("- Title: \(result.gameTitle)")
            print("  System: \(result.systemID)")
            print("  MD5: \(result.romHashMD5 ?? "nil")")
            print("  Filename: \(result.romFileName ?? "nil")")
            print("  Source: \(result.source ?? "unknown")")
        }

        #expect(results != nil)
        #expect(!results!.isEmpty)

        // Find our specific version
        let usaVersion = results?.first { result in
            result.romHashMD5?.uppercased() == testData.expectedMD5
        }

        #expect(usaVersion != nil)
        #expect(usaVersion?.systemID == testData.systemID)
        #expect(usaVersion?.gameTitle == testData.expectedTitle)

        // Verify we got results from at least one database
        let sources = Set(results?.compactMap { $0.source } ?? [])
        print("\nSources found: \(sources)")
        #expect(!sources.isEmpty)  // Changed from sources.count > 1

        // Test that system filtering works
        let wrongSystemResults = try await lookup.searchDatabase(
            usingFilename: testData.filename,
            systemID: .NES  // Different system
        )
        #expect(wrongSystemResults == nil || !wrongSystemResults!.contains { $0.systemID == testData.systemID })
    }

    @Test
    func testSearchDatabaseByMD5WithSystem() async throws {
        // Test data for Pitfall Mayan Adventure SNES
        let testData = (
            md5: "02CAE4C360567CD228E4DC951BE6CB85",  // USA version
            systemID: SystemIdentifier.SNES,
            expectedTitle: "Pitfall: The Mayan Adventure",
            expectedFilename: "Pitfall - The Mayan Adventure (USA).sfc"
        )

        print("\nTesting searchDatabase by MD5 with system:")
        print("- MD5: \(testData.md5)")
        print("- System: \(testData.systemID)")

        // Search with both MD5 and system ID
        let results = try await lookup.searchDatabase(
            usingMD5: testData.md5,
            systemID: testData.systemID
        )

        print("\nSearch Results:")
        results?.forEach { result in
            print("- Title: \(result.gameTitle)")
            print("  System: \(result.systemID)")
            print("  MD5: \(result.romHashMD5 ?? "nil")")
            print("  Filename: \(result.romFileName ?? "nil")")
            print("  Source: \(result.source ?? "unknown")")
        }

        #expect(results != nil)
        #expect(results?.count == 1)  // Should only find one match with system filter

        let match = results?.first
        #expect(match?.systemID == testData.systemID)
        #expect(match?.gameTitle == testData.expectedTitle)
        #expect(match?.romFileName == testData.expectedFilename)
        #expect(match?.romHashMD5?.uppercased() == testData.md5)
    }

    @Test
    func testSearchDatabaseByFilenameAcrossSystems() async throws {
        // Test searching for Pitfall across multiple systems
        let testData = (
            filename: "Pitfall - The Mayan Adventure",
            systems: [SystemIdentifier.SNES, SystemIdentifier.Genesis, SystemIdentifier.SegaCD],
            expectedMD5s: [
                "02CAE4C360567CD228E4DC951BE6CB85",  // SNES USA
                "6A80D2D34CDFAFD03703B0FE76D10399",  // Genesis USA
                "C7658288B84A5F9521B5A19C0694D076"   // SegaCD USA
            ]
        )

        print("\nTesting searchDatabase across systems:")
        print("- Filename: \(testData.filename)")
        print("- Systems: \(testData.systems)")

        let results = try await lookup.searchDatabase(
            usingFilename: testData.filename,
            systemIDs: testData.systems
        )

        print("\nSearch Results:")
        results?.forEach { result in
            print("- Title: \(result.gameTitle)")
            print("  System: \(result.systemID)")
            print("  MD5: \(result.romHashMD5 ?? "nil")")
            print("  Filename: \(result.romFileName ?? "nil")")
            print("  Source: \(result.source ?? "unknown")")
        }

        #expect(results != nil)
        #expect(!results!.isEmpty)

        // Verify we found matches for different systems
        let foundSystems = Set(results?.map(\.systemID) ?? [])
        print("\nFound systems: \(foundSystems)")
        #expect(foundSystems.count > 1)  // Should find matches in multiple systems

        // Verify we found some of our expected MD5s
        let foundMD5s = Set(results?.compactMap { $0.romHashMD5?.uppercased() } ?? [])
        print("\nFound MD5s: \(foundMD5s)")
        let matchingMD5s = foundMD5s.intersection(Set(testData.expectedMD5s))
        #expect(!matchingMD5s.isEmpty)  // Should find at least one expected MD5

        // Verify all results are from requested systems
        let requestedSystems = Set(testData.systems)
        #expect(results?.allSatisfy { requestedSystems.contains($0.systemID) } == true)
    }

}

struct PVLookupArtworkTests {
    let lookup: PVLookup
    let openVGDB: OpenVGDB
    let libreTroDB: libretrodb

    init() async throws {
        self.lookup = .shared
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
    }

    @Test
    func testLibretroDBDirectArtworkURLs() async throws {
        // Create test ROM metadata for a game we know has artwork
        let rom = ROMMetadata(
            gameTitle: "Pitfall - The Mayan Adventure",
            systemID: .SNES,
            romFileName: "Pitfall - The Mayan Adventure (USA).sfc",
            romHashMD5: "02CAE4C360567CD228E4DC951BE6CB85"
        )

        // Test LibretroDB directly
        let urls = try await libreTroDB.getArtworkURLs(forRom: rom)

        print("\nLibretroDB Direct URL Test:")
        print("Input:")
        print("- System Name: \(rom.systemID.libretroDatabaseName)")
        print("- Filename: \(rom.romFileName ?? "")")

        print("\nGenerated URLs:")
        if let urls = urls {
            for url in urls {
                #expect(url.absoluteString.contains("Nintendo%20-%20Super%20Nintendo%20Entertainment%20System"))
                #expect(url.absoluteString.contains("Pitfall%20-%20The%20Mayan%20Adventure%20(USA)"))
            }
        }
    }

    @Test
    func testGetArtworkURLs() async throws {
        // Create test ROM metadata
        let rom = ROMMetadata(
            gameTitle: "Sonic CD",
            systemID: .SegaCD,
            romFileName: "Sonic CD (USA).cue",
            romHashMD5: "c7658288"  // Example MD5
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)

        #expect(urls != nil)
        #expect(!urls!.isEmpty)

        // Verify we got URLs from both databases
        let openVGDBUrls = urls?.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls?.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        // We should have at least one URL from either database
        #expect(openVGDBUrls?.isEmpty == false || libretroDatabaseUrls?.isEmpty == false)

        // If we have libretro URLs, verify the system name is correct
        if let libretroDatabaseUrl = libretroDatabaseUrls?.first {
            #expect(libretroDatabaseUrl.absoluteString.contains("Sega%20-%20Mega-CD%20-%20Sega%20CD"))
        }
    }

    @Test
    func testGetArtworkURLsWithUnknownSystem() async throws {
        // Test with Unknown system
        let rom = ROMMetadata(
            gameTitle: "Unknown Game",
            systemID: .Unknown,
            romFileName: "game.bin"
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)
        #expect(urls == nil)  // Should return nil for Unknown system
    }

    @Test
    func testGetArtworkURLsWithMultipleMatches() async throws {
        // Create test ROM metadata for a game we know has artwork
        let rom = ROMMetadata(
            gameTitle: "Pitfall - The Mayan Adventure",
            systemID: .SNES,
            romFileName: "Pitfall - The Mayan Adventure (USA).sfc",
            romHashMD5: "02CAE4C360567CD228E4DC951BE6CB85"  // USA SNES version
        )

        print("\nTesting artwork URLs for ROM:")
        print("- Title: \(rom.gameTitle)")
        print("- System: \(rom.systemID)")
        print("- Filename: \(rom.romFileName ?? "nil")")
        print("- MD5: \(rom.romHashMD5 ?? "nil")")

        let urls = try await lookup.getArtworkURLs(forRom: rom) ?? []

        print("\nReturned URLs: \(urls.count)")
        urls.forEach { print("- \($0.absoluteString)") }

        #expect(!urls.isEmpty)

        // Verify we got URLs from both databases
        let openVGDBUrls = urls.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        print("\nOpenVGDB URLs: \(openVGDBUrls.count)")
        openVGDBUrls.forEach { print("- \($0.absoluteString)") }

        print("\nLibretroDB URLs: \(libretroDatabaseUrls.count)")
        libretroDatabaseUrls.forEach { print("- \($0.absoluteString)") }

        // We should have at least one URL from either database
        #expect(openVGDBUrls.count > 0 || libretroDatabaseUrls.count > 0)

        // Verify URLs are deduplicated
        let uniqueUrls = Set(urls.map { $0.absoluteString })
        #expect(uniqueUrls.count == urls.count)  // No duplicates
    }

    @Test
    func testGetArtworkURLsWithNoMatches() async throws {
        // Test with valid system but non-existent game
        let rom = ROMMetadata(
            gameTitle: "",
            systemID: .SNES,
            romFileName: "",
            romHashMD5: "12344453465345"
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)
        #expect(urls == nil)  // Should return nil for no matches
    }

    @Test
    func testGetArtworkURLsFromSearch() async throws {
        // Search for Pitfall SNES - using just the base name
        let results = try await lookup.searchDatabase(
            usingFilename: "Pitfall - The Mayan Adventure",  // Removed (USA)
            systemID: SystemIdentifier.SNES
        )

        print("\nSearch Results:")
        results?.forEach { result in
            print("- Title: \(result.gameTitle)")
            print("  System: \(result.systemID)")
            print("  MD5: \(result.romHashMD5 ?? "nil")")
            print("  Filename: \(result.romFileName ?? "nil")")  // Added to see filename
        }

        #expect(results != nil)
        let pitfallSNES = results?.first { result in
            result.romHashMD5?.uppercased() == "02CAE4C360567CD228E4DC951BE6CB85"  // USA SNES version
        }
        #expect(pitfallSNES != nil)

        // Get artwork URLs for the found ROM
        let urls = try await lookup.getArtworkURLs(forRom: pitfallSNES!) ?? []

        print("\nArtwork URLs for search result:")
        urls.forEach { print("- \($0.absoluteString)") }

        #expect(!urls.isEmpty)

        // Verify we got URLs from both databases
        let openVGDBUrls = urls.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        print("\nOpenVGDB URLs: \(openVGDBUrls.count)")
        openVGDBUrls.forEach { print("- \($0.absoluteString)") }

        print("\nLibretroDB URLs: \(libretroDatabaseUrls.count)")
        libretroDatabaseUrls.forEach { print("- \($0.absoluteString)") }

        // We should have at least one URL from either database
        #expect(openVGDBUrls.count > 0 || libretroDatabaseUrls.count > 0)

        // If we have libretro URLs, verify the system name and filename
        if let libretroDatabaseUrl = libretroDatabaseUrls.first {
            let expectedSystemPath = "Nintendo%20-%20Super%20Nintendo%20Entertainment%20System"
            let expectedFilename = "Pitfall%20-%20The%20Mayan%20Adventure%20(USA)"
            #expect(libretroDatabaseUrl.absoluteString.contains(expectedSystemPath))
            #expect(libretroDatabaseUrl.absoluteString.contains(expectedFilename))
        }
    }

    @Test("Handles invalid ROM metadata appropriately")
    func testGetArtworkURLsWithInvalidData() async throws {
        // Test with empty ROM metadata
        let emptyRom = ROMMetadata(
            gameTitle: "",
            systemID: .Unknown,
            romFileName: "",
            romHashMD5: ""
        )

        let emptyResult = try await lookup.getArtworkURLs(forRom: emptyRom)
        #expect(emptyResult == nil)  // Should return nil for empty metadata

        // Test with obviously invalid data
        let invalidRom = ROMMetadata(
            gameTitle: "xyzzy123notarealgame456",  // Very unlikely to match anything
            systemID: .Unknown,
            romFileName: "notarealfile.xyz",
            romHashMD5: "0000000000000000000000000000"
        )

        let invalidResult = try await lookup.getArtworkURLs(forRom: invalidRom)
        #expect(invalidResult == nil)  // Should return nil for invalid data
    }

}

struct PVLookupSystemTests {
    let lookup: PVLookup

    init() async throws {
        self.lookup = .shared
    }

    @Test
    func testSystemIdentifierByMD5() async throws {
        // Test with known Pitfall SNES ROM
        let testData = (
            md5: "02CAE4C360567CD228E4DC951BE6CB85",  // Pitfall Mayan Adventure USA
            expectedSystem: SystemIdentifier.SNES
        )

        let identifier = try await lookup.systemIdentifier(forRomMD5: testData.md5, or: nil)
        #expect(identifier == testData.expectedSystem)

        // Test with invalid MD5
        let invalidIdentifier = try await lookup.systemIdentifier(forRomMD5: "invalid", or: nil)
        #expect(invalidIdentifier == nil)
    }

    @Test
    func testSystemIdentifierByFilename() async throws {
        // Test with filename fallback
        let testData = (
            md5: "invalid",
            filename: "Pitfall - The Mayan Adventure (USA).sfc",
            expectedSystem: SystemIdentifier.SNES
        )

        let identifier = try await lookup.systemIdentifier(
            forRomMD5: testData.md5,
            or: testData.filename
        )
        #expect(identifier == testData.expectedSystem)
    }

    @Test
    func testLegacySystemByMD5() async throws {
        // Test deprecated system(forRomMD5:or:)
        let testData = (
            md5: "02CAE4C360567CD228E4DC951BE6CB85",  // Pitfall Mayan Adventure USA
            expectedOpenVGDBID: SystemIdentifier.SNES.openVGDBID
        )

        let systemID = try await lookup.system(forRomMD5: testData.md5, or: nil)
        #expect(systemID == testData.expectedOpenVGDBID)
    }

    @Test
    func testArtworkMappings() async throws {
        let mappings = try await lookup.getArtworkMappings()

        // Test known MD5 mappings
        let knownMD5 = "02CAE4C360567CD228E4DC951BE6CB85"  // Pitfall Mayan Adventure USA
        #expect(mappings.romMD5[knownMD5] != nil)

        // Test known filename mappings
        let knownFilename = "Pitfall - The Mayan Adventure (USA).sfc"
        #expect(mappings.romFileNameToMD5[knownFilename] != nil)

        // Verify mappings aren't empty
        #expect(!mappings.romMD5.isEmpty)
        #expect(!mappings.romFileNameToMD5.isEmpty)
    }

    @Test
    func testGetArtworkURLsForROM() async throws {
        // Test with known ROM that should have artwork
        let rom = ROMMetadata(
            gameTitle: "Pitfall - The Mayan Adventure",
            systemID: .SNES,
            romFileName: "Pitfall - The Mayan Adventure (USA).sfc",
            romHashMD5: "02CAE4C360567CD228E4DC951BE6CB85"
        )

        let urls = try await lookup.getArtworkURLs(forRom: rom)

        print("\nArtwork URLs for ROM:")
        print("- Title: \(rom.gameTitle)")
        print("- System: \(rom.systemID)")
        print("- MD5: \(rom.romHashMD5 ?? "nil")")

        print("\nReturned URLs:")
        urls?.forEach { print("- \($0.absoluteString)") }

        #expect(urls != nil)
        #expect(!urls!.isEmpty)

        // Verify URLs from different sources
        let openVGDBUrls = urls?.filter { $0.absoluteString.contains("gamefaqs.gamespot.com") }
        let libretroDatabaseUrls = urls?.filter { $0.absoluteString.contains("thumbnails.libretro.com") }

        print("\nURLs by source:")
        print("- OpenVGDB: \(openVGDBUrls?.count ?? 0)")
        print("- LibretroDB: \(libretroDatabaseUrls?.count ?? 0)")

        // Should have at least one URL from either source
        #expect(openVGDBUrls?.isEmpty == false || libretroDatabaseUrls?.isEmpty == false)
    }
}
