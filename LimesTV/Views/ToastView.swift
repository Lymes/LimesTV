//
//  ToastView.swift
//  LimesTV
//
//  A small, transient message shown at the bottom of the screen (e.g. after the
//  programme guide finishes refreshing).
//

import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.85), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(radius: 8)
    }
}
