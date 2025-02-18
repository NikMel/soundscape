//
//  UseCaseLogger.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-02-18.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

//flow: https://tinyurl.com/2unc3j6v and sequence: https://tinyurl.com/4jnnd5mc

import CocoaLumberjack

class UseCaseLogger: DDLogFileManagerDefault {
    override var logsDirectory: String {
        return "/your/custom/path"  // Set this to the desired directory
    }
}
