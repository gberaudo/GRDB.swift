import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationMapTests: GRDBTestCase {
    func testMap() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            // The base reducer
            var count = 0
            let reducer = AnyValueReducer(
                fetch: { _ in /* don't fetch anything */ },
                value: { _ -> Int? in
                    count += 1
                    return count
            })
            
            // Create an observation
            var observation = ValueObservation
                .tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
                .map { count -> String in return "\(count)" }
            observation.extent = .databaseLifetime
            
            // Start observation
            _ = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
            
            try dbWriter.writeWithoutTransaction { db in
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(counts, ["1", "2", "3"])
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testMapPreservesConfiguration() {
        var observation = ValueObservation.tracking(DatabaseRegion(), fetch: { _ in })
        observation.extent = .nextTransaction
        observation.requiresWriteAccess = true
        observation.scheduling = .unsafe(startImmediately: true)
        
        let mappedObservation = observation.map { _ in }
        XCTAssertEqual(mappedObservation.extent, observation.extent)
        XCTAssertEqual(mappedObservation.requiresWriteAccess, observation.requiresWriteAccess)
        switch mappedObservation.scheduling {
        case .unsafe:
            break
        default:
            XCTFail()
        }
    }
}
