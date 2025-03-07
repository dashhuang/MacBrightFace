//
//  ContentView.swift
//  LIght
//
//  Created by Dash Huang on 03/03/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isLightOn = false
    @State private var brightness: Double = 0.75
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isLightOn ? "lightbulb.fill" : "lightbulb")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(isLightOn ? .yellow : .gray)
                .padding()
            
            Text("Mac屏幕补光灯")
                .font(.largeTitle)
                .bold()
            
            Text("使用Mac屏幕作为视频会议补光灯")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            Toggle("开启补光灯", isOn: $isLightOn)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("亮度: \(Int(brightness * 100))%")
                
                Slider(value: $brightness, in: 0.25...1.0, step: 0.25)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("请使用菜单栏图标控制补光灯")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350, height: 500)
    }
}

#Preview {
    ContentView()
}
