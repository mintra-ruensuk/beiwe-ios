//
//  TestNotificationRequest.swift
//  Beiwe
//
//  Created by Tucker Jaenicke on 6/2/20.
//  Copyright © 2020 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct TestNotificationRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/send_survey_notification"
    typealias ApiReturnType = Survey;

    var surveyID: String?;

    init() {
    }

    init?(map: Map) {
    }

    // Mappable
    mutating func mapping(map: Map) {
    }

}
