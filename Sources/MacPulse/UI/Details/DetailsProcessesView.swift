import SwiftUI
import MacPulseCore

private enum ProcessSortField {
    case cpu
    case memory
    case name
}

struct DetailsProcessesView: View {
    let processes: [ProcessReading]
    let isDetailed: Bool
    let interval: TimeInterval

    @State private var query = ""
    @State private var sortField: ProcessSortField = .cpu
    @State private var sortAscending = false

    private var visibleProcesses: [ProcessReading] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ProcessReading]
        if trimmed.isEmpty {
            filtered = processes
        } else {
            let needle = trimmed.lowercased()
            filtered = processes.filter { process in
                process.name.lowercased().contains(needle) || String(process.pid).contains(needle)
            }
        }

        return filtered.sorted { lhs, rhs in
            let result: Bool
            switch sortField {
            case .cpu:
                result = lhs.cpuLoad == rhs.cpuLoad
                    ? lhs.memoryBytes < rhs.memoryBytes
                    : lhs.cpuLoad < rhs.cpuLoad
            case .memory:
                result = lhs.memoryBytes == rhs.memoryBytes
                    ? lhs.cpuLoad < rhs.cpuLoad
                    : lhs.memoryBytes < rhs.memoryBytes
            case .name:
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                result = comparison == .orderedSame ? lhs.pid < rhs.pid : comparison == .orderedAscending
            }
            return sortAscending ? result : !result
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Hairline()

            columnHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            Hairline()

            if processes.isEmpty {
                emptyState
            } else if visibleProcesses.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("没有匹配的进程")
                        .font(.label(11))
                        .foregroundStyle(.secondary)
                    Text("试试名称片段或 PID")
                        .font(.label(9.5))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleProcesses) { process in
                            DetailProcessRow(process: process)
                            Hairline()
                                .opacity(0.55)
                                .padding(.leading, 16)
                        }
                    }
                }
            }

            Hairline()
            footer
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.memory)
            Text("进程")
                .font(.label(13, weight: .semibold))
            Text(isDetailed ? "全量 \(processes.count) 个 · 每 3 秒采样" : "等待采样")
                .font(.label(9.5))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("按名称或 PID 筛选", text: $query)
                    .textFieldStyle(.plain)
                    .font(.label(11))
                    .frame(maxWidth: .infinity)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("清除筛选")
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 220, height: 26)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(isDetailed ? Palette.network : Color.secondary.opacity(0.5))
                    .frame(width: 4.5, height: 4.5)
                Text(detailedIntervalText)
                    .font(.label(9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var columnHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Color.clear.frame(width: 20, height: 1)
                sortButton("进程", field: .name, trailing: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("PID")
                .frame(width: 64, alignment: .trailing)

            sortButton("CPU", field: .cpu, trailing: true)
                .frame(width: 110, alignment: .trailing)

            sortButton("内存", field: .memory, trailing: true)
                .frame(width: 80, alignment: .trailing)
        }
        .font(.label(9, weight: .medium))
        .foregroundStyle(.tertiary)
    }

    private func sortButton(
        _ title: String,
        field: ProcessSortField,
        trailing: Bool
    ) -> some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = field == .name
            }
        } label: {
            HStack(spacing: 2) {
                if trailing {
                    Spacer(minLength: 0)
                }
                Text(title)
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 6.5, weight: .bold))
                }
                if !trailing {
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(sortField == field ? .secondary : .tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("按\(title)排序")
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(isDetailed ? "正在采集进程数据…" : "打开详情后开始采样")
                .font(.label(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("CPU 为单核占比，超过 100% 表示多线程并行")
            Spacer(minLength: 4)
            Text("点击表头切换排序")
        }
        .font(.label(8.5))
        .foregroundStyle(.quaternary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var detailedIntervalText: String {
        let value = interval < 1 ? String(format: "%.1f", interval) : String(format: "%.0f", interval)
        return "每 \(value) 秒刷新"
    }
}

private struct DetailProcessRow: View {
    let process: ProcessReading

    @State private var hovering = false

    private var cpuColor: Color {
        if process.cpuLoad >= 1 { return Palette.danger }
        if process.cpuLoad >= 0.4 { return Palette.cpu }
        return .secondary
    }

    private var cpuText: String {
        String(format: "%.1f%%", max(0, process.cpuLoad) * 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ProcessIconView(process: process, size: 20)
                Text(process.name)
                    .font(.label(11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.mono(9.5))
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .trailing)

            HStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                        Capsule(style: .continuous)
                            .fill(cpuColor.opacity(0.7))
                            .frame(width: proxy.size.width * CGFloat(clamp(process.cpuLoad)))
                    }
                }
                .frame(width: 44, height: 3)

                Text(cpuText)
                    .font(.mono(10, weight: .medium))
                    .foregroundStyle(cpuColor)
                    .frame(width: 56, alignment: .trailing)
            }
            .frame(width: 110, alignment: .trailing)

            Text(MetricFormat.memory(process.memoryBytes))
                .font(.mono(10))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color.primary.opacity(hovering ? 0.035 : 0))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help("\(process.name) · PID \(process.pid)\nCPU \(cpuText) · 内存 \(MetricFormat.memory(process.memoryBytes))")
    }
}
