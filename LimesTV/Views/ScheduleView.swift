//
//  ScheduleView.swift
//  LimesTV
//
//  The channel schedule (palinsesto) shown as a vertical timeline, highlighting
//  the programme on air now and auto-scrolling to it.
//

import SwiftUI

struct ScheduleView: View {
    let viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(at: context.date)
            }
            .navigationTitle(viewModel.channelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        if viewModel.programmes.isEmpty {
            ContentUnavailableView("Nessun palinsesto", systemImage: "calendar.badge.exclamationmark")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.programmes, id: \.self) { programme in
                        ScheduleRow(
                            time: viewModel.timeString(programme),
                            title: programme.title,
                            description: programme.description,
                            isCurrent: viewModel.isCurrent(programme, at: date),
                            isPast: viewModel.isPast(programme, at: date),
                            progress: viewModel.progress(programme, at: date)
                        )
                        .id(programme)
                    }
                }
                .padding()
            }
        }
    }
}

/// A single timeline entry: time and dot on the left, programme details on the right.
private struct ScheduleRow: View {
    let time: String
    let title: String
    let description: String?
    let isCurrent: Bool
    let isPast: Bool
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(time)
                .font(.callout.monospacedDigit())
                .foregroundStyle(isCurrent ? Color.green : .secondary)
                .frame(width: 48, alignment: .leading)

            timelineIndicator

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(isCurrent ? .headline : .body)
                    .foregroundStyle(isPast ? .secondary : .primary)

                if let progress {
                    ProgressView(value: progress)
                        .tint(.green)
                }
                if let description, !isPast {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 16)

            Spacer(minLength: 0)
        }
        .opacity(isPast ? 0.5 : 1)
    }

    private var timelineIndicator: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(width: 2)
            Circle()
                .fill(isCurrent ? Color.green : (isPast ? .gray : .white))
                .frame(width: 11, height: 11)
                .padding(.top, 4)
        }
        .frame(width: 11)
    }
}
