//import WidgetKit
import SwiftUI

struct HomeScreenWidgetView: View {
     let entry: CountdownProvider.Entry
     
     var body: some View {
         VStack(spacing: 6) {
            Text(
                entry.isEstimateAvailable
                    ? "Approx. remaining"
                    : "Screen Time estimate"
            )
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if entry.isEstimateAvailable {
                GlassText(value: entry.remainingTime.formatted(), size: 48)
            } else {
                Text("Waiting for data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
     }
 }

 struct LockScreenRectangularView: View {
     let entry: CountdownProvider.Entry
     
     var body: some View {
        if entry.isEstimateAvailable {
            Text("Mujø · \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
     }
 }


struct LockScreenCircularView: View {
     let entry: CountdownProvider.Entry
     
     var body: some View {
         if entry.isEstimateAvailable {
            Text(entry.remainingTime.formatted())
        } else {
            Text("-:-")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
     }
 }

 struct LockScreenInlineView: View {
     let entry: CountdownProvider.Entry
     
     var body: some View {
         if entry.isEstimateAvailable {
            Text("Remaining: \(entry.remainingTime.formatted())")
        } else {
            Text("Waiting for data")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
     }
 }