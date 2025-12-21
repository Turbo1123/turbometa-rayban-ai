/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// TimeUtils.swift
//
// Utility for managing streaming time limits in the TurboMeta app.
//

import Foundation
import SwiftUI

enum StreamTimeLimit: String, CaseIterable {
  case oneMinute = "1min"
  case fiveMinutes = "5min"
  case tenMinutes = "10min"
  case fifteenMinutes = "15min"
  case noLimit = "noLimit"

  var displayText: String {
    switch self {
    case .oneMinute:
      return "1m"
    case .fiveMinutes:
      return "5m"
    case .tenMinutes:
      return "10m"
    case .fifteenMinutes:
      return "15m"
    case .noLimit:
      return "No limit"
    }
  }

  var durationInSeconds: TimeInterval? {
    switch self {
    case .oneMinute:
      return 60
    case .fiveMinutes:
      return 300
    case .tenMinutes:
      return 600
    case .fifteenMinutes:
      return 900
    case .noLimit:
      return nil
    }
  }

  var isTimeLimited: Bool {
    switch self {
    case .noLimit:
      return false
    default:
      return true
    }
  }

  var next: StreamTimeLimit {
    switch self {
    case .oneMinute:
      return .fiveMinutes
    case .fiveMinutes:
      return .tenMinutes
    case .tenMinutes:
      return .fifteenMinutes
    case .fifteenMinutes:
      return .noLimit
    case .noLimit:
      return .oneMinute
    }
  }
}

extension TimeInterval {
  var formattedCountdown: String {
    let minutes = Int(self) / 60
    let seconds = Int(self) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
