/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// CustomButton.swift
//
// Reusable button component used throughout the TurboMeta app for consistent styling.
//

import SwiftUI

struct CustomButton: View {
  let title: String
  let style: ButtonStyle
  let isDisabled: Bool
  let action: () -> Void

  enum ButtonStyle {
    case primary, destructive

    var backgroundColor: Color {
      switch self {
      case .primary:
        return .appPrimary
      case .destructive:
        return .destructiveBackground
      }
    }

    var foregroundColor: Color {
      switch self {
      case .primary:
        return .white
      case .destructive:
        return .destructiveForeground
      }
    }
  }

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(style.foregroundColor)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(style.backgroundColor)
        .cornerRadius(30)
    }
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.6 : 1.0)
  }
}
