//
//  MarketingScreenShotView.swift
//  HealthLens
//
//  Created by William Kaiser on 1/31/25.
//


import SwiftUI

struct MarketingScreenshotView: View {
    let screenshot: UIImage  // the screenshot you captured programmatically

    // Example desired size
    var targetWidth: CGFloat = 460
    var targetHeight: CGFloat = 997

    var body: some View {
        ZStack {
            // 1) A background color or gradient
            Color("BackgroundColor")
                .ignoresSafeArea()

            // 2) Optionally add marketing text at the top
            VStack(alignment: .leading, spacing: 16) {
                Text("Export your health data as a CSV")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // 3) Show the screenshot in a phone frame or by itself
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(radius: 10)
                    .padding()

                Spacer()
            }
        }
        // 4) Force the view to a specific “marketing” size
        .frame(width: targetWidth, height: targetHeight)
    }
}
