import WidgetKit
import SwiftUI

@main
struct LovelyWidgetBundle: WidgetBundle {
    var body: some Widget {
        LovelyWidget()
        DateNightWidget()
        AnniversaryWidget()
        TravelWidget()
    }
}