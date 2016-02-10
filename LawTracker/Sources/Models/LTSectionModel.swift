//
//  LTSectionModel.swift
//  LawTracker
//
//  Created by Varvara Mironova on 12/4/15.
//  Copyright © 2015 VarvaraMironova. All rights reserved.
//

import Foundation

class LTSectionModel: NSObject {
    var entities  : [LTEntityModel]!
    
    var changes = [LTChangeModel]()
    var filters = [LTFilterCellModel]()
    var title   = String()
    
    override init() {
        super.init()
        
        self.entities = [LTEntityModel]()
    }
    
    init(entities: [LTEntityModel]) {
        super.init()
        
        self.entities = entities
        var titles = [String]()
        for entity in entities {
            titles.append(entity.title)
        }
        
        self.title = titles.joinWithSeparator("\n")
    }
}