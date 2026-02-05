//
//  ViewSelectorView.swift
//  EV Info
//
//  Created by Jason on 8/31/25.
//

import SwiftUI

struct ViewSelectorView: View {
    @Binding var selectedView: AppView
    
    var body: some View {
        HStack {
            ForEach(AppView.allCases, id: \.self) { view in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedView = view
                    }
                }) {
                    Text(view.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            selectedView == view
                                ? Color.blue.opacity(0.2)
                                : Color.clear
                        )
                        .foregroundColor(
                            selectedView == view
                                ? .blue
                                : .secondary
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedView == view
                                        ? Color.blue
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
