//
//  ColabGrouActivity.swift
//  TaskColab
//
//  Created by Barath Balamurugan on 11/08/25.
//

import GroupActivities
import CoreTransferable

struct ColabGroupActivity: GroupActivity, Transferable, Sendable{
    static let activityIdentifier = "com.rds.taskcolab.colab"
    
    var metadata: GroupActivityMetadata{
        var meta = GroupActivityMetadata()
        meta.title = "Colab"
        meta.type = .generic
        
        return meta
    }
}
