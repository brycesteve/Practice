import SwiftUI
import Charts

struct TonnageWorkRestView: View {
    var xValues: [Date]
    var tonnage: [Double]       // main scale
    var ratio: [Double]         // 0...1
    
    var body: some View {
        let tonnageMax = tonnage.max() ?? 1
        let scaledRatios = ratio.map { $0 * tonnageMax }
        
        Chart {
            // Bars: tonnage
            ForEach(Array(zip(xValues, tonnage).enumerated()), id: \.offset) { _, item in
                BarMark(
                    x: .value("Date", item.0, unit: .weekOfYear),
                    y: .value("Tonnage", item.1),
                    width: .ratio(0.95)
                )
                .foregroundStyle(.green.gradient.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
            }
            
            // Line: scaled ratio
            ForEach(Array(zip(xValues, scaledRatios).enumerated()), id: \.offset) { _, item in
                LineMark(
                    x: .value("Date", item.0, unit: .weekOfYear),
                    y: .value("Ratio", item.1)
                )
                .foregroundStyle(.indigo)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            
                
        }
        .chartForegroundStyleScale(["Tonnage":Color.green, "Ratio":Color.indigo])
        .chartLegend(.visible)
        .chartLegend(position: .automatic, alignment: .center, spacing: 8, content: {
            HStack {
                Label("Tonnage", systemImage: "square.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    
                Label("Work", systemImage: "line.diagonal")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
                    
            }
            .padding(6)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
        })
        
        
        .chartYScale(domain: 0...tonnageMax + 50)
        .chartYAxis {
            let yValues = [0,0.25,0.50,0.75,1.0].map{ $0 * tonnageMax }
            AxisMarks(position: .trailing, values: yValues) { value in
                if let doubleValue = value.as(Double.self) {
                    // Map back to ratio
                    let ratioValue = doubleValue / tonnageMax
                    AxisValueLabel("\(Int(ratioValue * 100))%")
                }
            }
        }
        
        
    }
}


#Preview {
    TonnageWorkRestView(
        xValues: [Date().addingTimeInterval(24*3600 * -7),
                  Date().addingTimeInterval(24*3600 * -14)],
        tonnage: [2500, 3000],
        ratio: [0.7, 0.8])
    .frame(height: 250)
}
