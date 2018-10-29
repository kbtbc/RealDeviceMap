//
//  Account.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 15.10.18.
//

import Foundation
import PerfectLib
import PerfectMySQL

class Account {
    
    var username: String
    var password: String
    var level: UInt8
    var firstWarningTimestamp: UInt32?
    var failedTimestamp: UInt32?
    var failed: String?
    var lastEncounterLat: Double?
    var lastEncounterLon: Double?
    var lastEncounterTime: UInt32?
    
    init(username: String, password: String, level: UInt8, firstWarningTimestamp: UInt32?, failedTimestamp: UInt32?, failed: String?, lastEncounterLat: Double?, lastEncounterLon: Double?, lastEncounterTime: UInt32?) {
        self.username = username
        self.password = password
        self.level = level
        self.firstWarningTimestamp = firstWarningTimestamp
        self.failedTimestamp = failedTimestamp
        self.failed = failed
        self.lastEncounterLat = lastEncounterLat
        self.lastEncounterLon = lastEncounterLon
        self.lastEncounterTime = lastEncounterTime
    }
    
    public func save(update: Bool) throws {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let oldAccount: Account?
        do {
            oldAccount = try Account.getWithUsername(username: username)
        } catch {
            oldAccount = nil
        }
        let mysqlStmt = MySQLStmt(mysql)
        
        if oldAccount == nil {
            
            let sql = """
                INSERT INTO account (username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            _ = mysqlStmt.prepare(statement: sql)
            
            mysqlStmt.bindParam(username)
        } else if update {
            
            if lastEncounterLat == nil && oldAccount!.lastEncounterLat != nil {
                self.lastEncounterLat = oldAccount!.lastEncounterLat!
            }
            if lastEncounterLon == nil && oldAccount!.lastEncounterLon != nil {
                self.lastEncounterLon = oldAccount!.lastEncounterLon!
            }
            if lastEncounterTime == nil && oldAccount!.lastEncounterTime != nil {
                self.lastEncounterTime = oldAccount!.lastEncounterTime!
            }
            if failed == nil && oldAccount!.failed != nil {
                self.failed = oldAccount!.failed!
            }
            if firstWarningTimestamp == nil && oldAccount!.firstWarningTimestamp != nil {
                self.firstWarningTimestamp = oldAccount!.firstWarningTimestamp!
            }
            if failedTimestamp == nil && oldAccount!.failedTimestamp != nil {
                self.failedTimestamp = oldAccount!.failedTimestamp!
            }
            
            let sql = """
                UPDATE account
                SET password = ?, level = ?, first_warning_timestamp = ?, failed_timestamp = ?, failed = ?, last_encounter_lat = ?, last_encounter_lon = ?, last_encounter_time = ?
                WHERE username = ?
            """
            _ = mysqlStmt.prepare(statement: sql)
        } else {
            return
        }
        
        mysqlStmt.bindParam(password)
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(firstWarningTimestamp)
        mysqlStmt.bindParam(failedTimestamp)
        mysqlStmt.bindParam(failed)
        mysqlStmt.bindParam(lastEncounterLat)
        mysqlStmt.bindParam(lastEncounterLon)
        mysqlStmt.bindParam(lastEncounterTime)

        if oldAccount != nil {
            mysqlStmt.bindParam(username)
        }
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getNewAccount(minLevel: Int, maxLevel: Int) throws -> Account? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND level >= ? AND level <= ? AND failed IS NULL AND (last_encounter_time IS NULL OR UNIX_TIMESTAMP() -  CAST(last_encounter_time AS INTEGER) >= 7200)
            ORDER BY level DESC, RAND()
            LIMIT 1
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLevel)
        mysqlStmt.bindParam(maxLevel)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let username = result[0] as! String
        let password = result[1] as! String
        let level = result[2] as! UInt8
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        let lastEncounterLat = result[6] as? Double
        let lastEncounterLon = result[7] as? Double
        let lastEncounterTime = result[8] as? UInt32
        
        return Account(username: username, password: password, level: level, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed, lastEncounterLat: lastEncounterLat, lastEncounterLon: lastEncounterLon, lastEncounterTime: lastEncounterTime)
    }
    
    public static func getWithUsername(username: String) throws -> Account? {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT username, password, level, first_warning_timestamp, failed_timestamp, failed, last_encounter_lat, last_encounter_lon, last_encounter_time
            FROM account
            WHERE username = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(username)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        
        let username = result[0] as! String
        let password = result[1] as! String
        let level = result[2] as! UInt8
        let firstWarningTimestamp = result[3] as? UInt32
        let failedTimestamp = result[4] as? UInt32
        let failed = result[5] as? String
        let lastEncounterLat = result[6] as? Double
        let lastEncounterLon = result[7] as? Double
        let lastEncounterTime = result[8] as? UInt32
        
        return Account(username: username, password: password, level: level, firstWarningTimestamp: firstWarningTimestamp, failedTimestamp: failedTimestamp, failed: failed, lastEncounterLat: lastEncounterLat, lastEncounterLon: lastEncounterLon, lastEncounterTime: lastEncounterTime)
    }
    
    public static func getNewCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE first_warning_timestamp is NULL AND failed_timestamp is NULL and device.uuid IS NULL AND failed IS NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
    public static func getInUseCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            LEFT JOIN device ON username = account_username
            WHERE device.uuid IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }

    public static func getWarnedCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE failed IS NULL AND first_warning_timestamp IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
    public static func getFailedCount() throws -> Int64 {
        
        guard let mysql = DBController.global.mysql else {
            Log.error(message: "[ACCOUNT] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM account
            WHERE failed IS NOT NULL
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[ACCOUNT] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        let result = results.next()!
        let count = result[0] as! Int64
        
        return count
    }
    
}