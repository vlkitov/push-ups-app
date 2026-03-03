//
//  ContentView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Иконка приложения
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 100))
                    .foregroundStyle(.blue.gradient)
                
                Text("Push-ups Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Автоматический подсчет отжиманий\nс помощью Face ID камеры")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Кнопка начала тренировки
                NavigationLink {
                    WorkoutView()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Начать тренировку")
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
