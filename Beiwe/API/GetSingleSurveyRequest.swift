//
//  GetSingleSurveyRequest.swift
//  Beiwe
//
//  Created by Tucker Jaenicke on 5/15/20.
//  Copyright © 2020 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct GetSingleSurveyRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/download_survey"
    typealias ApiReturnType = Survey;

    var surveyID: String?;

    init(surveyID: String) {
        self.surveyID = surveyID;
    }

    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        surveyID <- map["survey_id"];
    }

}
